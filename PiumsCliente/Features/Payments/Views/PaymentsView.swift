// PaymentsView.swift
import SwiftUI

struct PaymentsView: View {
    @State private var viewModel = PaymentsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.payments.isEmpty {
                LoadingView()
            } else if let error = viewModel.errorMessage, viewModel.payments.isEmpty {
                EmptyStateView(
                    systemImage: "creditcard.slash",
                    title: "Error al cargar",
                    description: error,
                    actionTitle: "Reintentar"
                ) { Task { await viewModel.loadInitial() } }
            } else if viewModel.payments.isEmpty {
                EmptyStateView(
                    systemImage: "creditcard",
                    title: "Sin transacciones",
                    description: "Aquí verás el historial de tus pagos una vez que realices una reserva."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.payments) { payment in
                            PaymentRowView(payment: payment, viewModel: viewModel)
                                .task { await viewModel.loadNextIfNeeded(item: payment) }
                            Divider().padding(.leading, 72)
                        }
                        if viewModel.isLoading {
                            ProgressView().frame(maxWidth: .infinity).padding()
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .refreshable { await viewModel.loadInitial() }
            }
        }
        .navigationTitle("Mis Pagos")
        .task { await viewModel.loadInitial() }
    }
}

// MARK: - PaymentRowView

struct PaymentRowView: View {
    let payment: Payment
    let viewModel: PaymentsViewModel

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: payment.status.systemImage)
                    .foregroundStyle(statusColor)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(payment.description ?? "Pago de reserva")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(payment.status.displayName)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                    Text(formattedDate(payment.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(viewModel.formattedAmount(payment.amount, currency: payment.currency))
                .font(.subheadline.bold())
                .foregroundStyle(payment.status == .refunded ? .purple : .primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private var statusColor: Color {
        switch payment.status {
        case .pending:    return .orange
        case .processing: return .blue
        case .succeeded:  return .green
        case .failed:     return .red
        case .cancelled:  return .gray
        case .refunded:   return .purple
        }
    }

    private func formattedDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) else { return iso.prefix(10).description }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.locale = Locale(identifier: "es_GT")
        return out.string(from: date)
    }
}

#Preview {
    NavigationStack { PaymentsView() }
}
