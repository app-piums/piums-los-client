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
                        // Credits summary card
                        if let credits = viewModel.credits {
                            CreditsCard(credits: credits)
                                .padding(.horizontal).padding(.top, 16).padding(.bottom, 8)
                        }

                        ForEach(viewModel.payments) { payment in
                            PaymentRowView(payment: payment, viewModel: viewModel)
                                .task { await viewModel.loadNextIfNeeded(item: payment) }
                            Divider().padding(.leading, 72)
                        }
                        if viewModel.isLoading {
                            ProgressView().frame(maxWidth: .infinity).padding()
                        }
                        Color.clear.frame(height: 20)
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

// MARK: - CreditsCard

private struct CreditsCard: View {
    let credits: MyCreditsResponse

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.piumsOrange.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: "banknote").foregroundStyle(Color.piumsOrange).font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Créditos disponibles").font(.subheadline.bold())
                Text("Aplicados automáticamente en tu próxima reserva")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(credits.formattedAmount)
                .font(.headline.bold())
                .foregroundStyle(Color.piumsOrange)
        }
        .padding(14)
        .background(Color.piumsOrange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.piumsOrange.opacity(0.15), lineWidth: 1))
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
                    if let provider = payment.provider {
                        Text(providerLabel(provider))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
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

    private func providerLabel(_ provider: String) -> String {
        switch provider.uppercased() {
        case "TILOPAY": return "Tilopay"
        case "STRIPE":  return "Stripe"
        default:        return provider.capitalized
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
