// QuejasView.swift — lista de quejas/disputas del cliente
import SwiftUI

struct QuejasView: View {
    @State private var viewModel = QuejasViewModel()
    @State private var selectedDispute: Dispute?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.disputes.isEmpty {
                LoadingView()
            } else if viewModel.disputes.isEmpty {
                EmptyStateView(
                    systemImage: "bubble.left.and.exclamationmark.bubble.right",
                    title: "Sin quejas",
                    description: "No has abierto ninguna queja. Si tuviste un problema con un servicio, puedes reportarlo desde el detalle de tu reserva."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let msg = viewModel.errorMessage {
                            ErrorBannerView(message: msg)
                                .padding(.horizontal)
                        }
                        ForEach(viewModel.disputes) { dispute in
                            DisputeRowView(dispute: dispute)
                                .padding(.horizontal)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedDispute = dispute }
                        }
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        }
                        Color.clear.frame(height: 12)
                    }
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
                .refreshable { await viewModel.loadInitial() }
            }
        }
        .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Mis Quejas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.secondarySystemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await viewModel.loadInitial() }
        .navigationDestination(item: $selectedDispute) { DisputeDetailView(dispute: $0) }
    }
}

// MARK: - DisputeRowView

struct DisputeRowView: View {
    let dispute: Dispute

    var body: some View {
        HStack(spacing: 14) {
            // Icono tipo
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "exclamationmark.bubble")
                        .foregroundStyle(statusColor)
                        .font(.system(size: 18))
                )

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(dispute.subject)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Spacer()
                    StatusPill(status: dispute.status)
                }

                Text(dispute.type.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.caption2)
                    Text(dispute.createdAt.shortDate)
                    if let p = dispute.priority, p >= 2 {
                        Text("·")
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("Alta prioridad")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var statusColor: Color {
        switch dispute.status {
        case .open:         return .orange
        case .inReview:     return .blue
        case .awaitingInfo: return .yellow
        case .resolved:     return .green
        case .closed:       return .gray
        case .escalated:    return .red
        }
    }
}

// MARK: - StatusPill

private struct StatusPill: View {
    let status: DisputeStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(pillColor.opacity(0.15))
            .foregroundStyle(pillColor)
            .clipShape(Capsule())
    }

    private var pillColor: Color {
        switch status {
        case .open:         return .orange
        case .inReview:     return .blue
        case .awaitingInfo: return .yellow
        case .resolved:     return .green
        case .closed:       return .gray
        case .escalated:    return .red
        }
    }
}

// MARK: - String helper

private extension String {
    var shortDate: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()
        guard let date = iso.date(from: self) ?? iso2.date(from: self) else { return self }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "es_GT")
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack { QuejasView() }
}
