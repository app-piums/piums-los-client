// EventsView.swift
import SwiftUI

struct EventsView: View {
    @State private var viewModel = EventsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.events.isEmpty {
                LoadingView()
            } else if viewModel.events.isEmpty {
                EmptyStateView(
                    systemImage: "ticket.fill",
                    title: "Sin eventos",
                    description: "Todavía no has creado eventos."
                )
            } else {
                List {
                    ForEach(viewModel.events) { event in
                        EventRow(event: event)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await viewModel.loadEvents() }
            }
        }
        .task { await viewModel.loadEvents() }
    }
}

private struct EventRow: View {
    let event: EventSummary

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.piumsOrange.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "ticket.fill").foregroundStyle(Color.piumsOrange))

            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.subheadline.bold())
                Text(event.eventDate ?? "Sin fecha")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(event.status.rawValue)
                .font(.caption2.bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview { NavigationStack { EventsView() } }
