// TicketsView.swift — Explorar eventos de conciertos/shows
import SwiftUI

struct TicketsView: View {
    @State private var vm = TicketsViewModel()
    @State private var selectedEvent: TicketEvent?
    @State private var showMyTickets = false

    var body: some View {
        Group {
            if vm.isLoading && vm.events.isEmpty {
                LoadingView()
            } else if vm.events.isEmpty && !vm.isLoading {
                EmptyStateView(
                    systemImage: "ticket",
                    title: "Sin eventos próximos",
                    description: "No hay conciertos o shows publicados por el momento."
                )
            } else {
                ScrollView {
                    if let err = vm.errorMessage {
                        ErrorBannerView(message: err).padding(.horizontal)
                    }
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 16
                    ) {
                        ForEach(vm.events) { event in
                            TicketEventCard(event: event)
                                .onTapGesture { selectedEvent = event }
                                .task { await vm.loadNextIfNeeded(item: event) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if vm.isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    }
                    Color.clear.frame(height: 12)
                }
                .scrollIndicators(.hidden)
                .refreshable { await vm.loadInitial() }
            }
        }
        .task { await vm.loadInitial() }
        .navigationDestination(item: $selectedEvent) { event in
            TicketDetailView(event: event)
        }
    }
}

// MARK: - TicketEventCard

private struct TicketEventCard: View {
    let event: TicketEvent

    private var formattedDate: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()
        guard let date = iso.date(from: event.eventDate) ?? iso2.date(from: event.eventDate) else {
            return String(event.eventDate.prefix(10))
        }
        let f = DateFormatter(); f.dateStyle = .medium; f.locale = Locale(identifier: "es_ES")
        return f.string(from: date)
    }

    private var minPriceLabel: String {
        event.minPriceCents.piumsFormatted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Imagen hero
            ZStack(alignment: .topTrailing) {
                Group {
                    if let url = event.imageUrl, let imgURL = URL(string: url) {
                        AsyncImage(url: imgURL) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            default:
                                ticketPlaceholder
                            }
                        }
                    } else {
                        ticketPlaceholder
                    }
                }
                .frame(height: 120)
                .clipped()

                // Badge de estado
                if event.isSoldOut {
                    Text("AGOTADO")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .padding(6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .clipped()

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.caption.bold())
                    .lineLimit(2)

                HStack(spacing: 3) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.piumsOrange)
                    Text(event.venue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 3) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Desde")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(minPriceLabel)
                        .font(.caption.bold())
                        .foregroundStyle(Color.piumsOrange)
                }
                .padding(.top, 2)
            }
            .padding(10)
        }
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator).opacity(0.3), lineWidth: 0.5))
        .opacity(event.isSoldOut ? 0.7 : 1)
    }

    private var ticketPlaceholder: some View {
        LinearGradient(
            colors: [Color.piumsOrange.opacity(0.7), Color(hex: "#E91E8C").opacity(0.5)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
