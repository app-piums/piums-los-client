// PaymentsView.swift — Historial de pagos en tarjetas
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
                emptyState
            } else {
                cardHistory
            }
        }
        .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Mis Pagos")
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.loadInitial() }
    }

    // MARK: - Card History

    private var cardHistory: some View {
        ScrollView {
            LazyVStack(spacing: 20, pinnedViews: .sectionHeaders) {
                // Créditos disponibles
                if let credits = viewModel.credits, credits.totalAmount > 0 {
                    CreditsCard(credits: credits)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }

                // Resumen rápido
                summaryRow
                    .padding(.horizontal, 20)

                // Pagos agrupados por mes
                ForEach(groupedPayments, id: \.month) { group in
                    Section {
                        VStack(spacing: 12) {
                            ForEach(group.payments) { payment in
                                PaymentCard(payment: payment, viewModel: viewModel)
                                    .task { await viewModel.loadNextIfNeeded(item: payment) }
                            }
                        }
                        .padding(.horizontal, 20)
                    } header: {
                        Text(group.month)
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemGroupedBackground))
                    }
                }

                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                }

                Color.clear.frame(height: 24)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.loadInitial() }
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        let succeeded = viewModel.payments.filter { $0.status == .succeeded }
        let total = succeeded.reduce(0) { $0 + $1.amount }
        return HStack(spacing: 12) {
            SummaryChip(
                icon: "checkmark.circle.fill",
                color: .green,
                label: "Completados",
                value: "\(succeeded.count)"
            )
            SummaryChip(
                icon: "banknote.fill",
                color: Color.piumsOrange,
                label: "Total pagado",
                value: viewModel.formattedAmount(total)
            )
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.piumsOrange.opacity(0.08)).frame(width: 90, height: 90)
                Image(systemName: "creditcard").font(.system(size: 40)).foregroundStyle(Color.piumsOrange.opacity(0.5))
            }
            VStack(spacing: 6) {
                Text("Sin transacciones").font(.title3.bold())
                Text("Aquí verás el historial de tus pagos una vez que realices una reserva.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Grouped payments

    private var groupedPayments: [(month: String, payments: [Payment])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let display = DateFormatter()
        display.dateFormat = "MMMM yyyy"
        display.locale = Locale(identifier: "es_GT")

        var groups: [(month: String, key: String, payments: [Payment])] = []
        for payment in viewModel.payments {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let date = iso.date(from: payment.createdAt) ?? Date()
            let key = formatter.string(from: date)
            let label = display.string(from: date).capitalized

            if let idx = groups.firstIndex(where: { $0.key == key }) {
                groups[idx].payments.append(payment)
            } else {
                groups.append((month: label, key: key, payments: [payment]))
            }
        }
        return groups.map { (month: $0.month, payments: $0.payments) }
    }
}

// MARK: - PaymentCard

private struct PaymentCard: View {
    let payment: Payment
    let viewModel: PaymentsViewModel

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

    var body: some View {
        HStack(spacing: 0) {
            // Barra de color lateral
            RoundedRectangle(cornerRadius: 3)
                .fill(statusColor)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 12)

            VStack(spacing: 0) {
                // Fila superior: descripción + monto
                HStack(alignment: .top, spacing: 12) {
                    // Ícono
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(statusColor.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: payment.status.systemImage)
                            .font(.system(size: 18))
                            .foregroundStyle(statusColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(payment.description ?? "Pago de reserva")
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            // Estado
                            Text(payment.status.displayName)
                                .font(.caption2.bold())
                                .foregroundStyle(statusColor)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(statusColor.opacity(0.12))
                                .clipShape(Capsule())
                            // Proveedor
                            if let provider = payment.provider {
                                Text(providerLabel(provider))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Color(.systemGray5))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    // Monto
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(viewModel.formattedAmount(payment.amount, currency: payment.currency))
                            .font(.headline.bold())
                            .foregroundStyle(payment.status == .refunded ? .purple : .primary)
                        Text(formattedDate(payment.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 14).padding(.bottom, 12)
                .padding(.horizontal, 14)

                // Booking ID si existe
                if let bookingId = payment.bookingId {
                    Divider().padding(.horizontal, 14)
                    HStack {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Reserva \(bookingId.prefix(8).uppercased())")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let pid = payment.providerPaymentId ?? payment.stripePaymentIntentId {
                            Text(pid.prefix(16) + "…")
                                .font(.caption2)
                                .foregroundStyle(Color(.systemGray4))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
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
        guard let date = f.date(from: iso) else { return String(iso.prefix(10)) }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.locale = Locale(identifier: "es_GT")
        return out.string(from: date)
    }
}

// MARK: - CreditsCard

private struct CreditsCard: View {
    let credits: MyCreditsResponse

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.piumsOrange.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "banknote.fill")
                    .foregroundStyle(Color.piumsOrange)
                    .font(.system(size: 22))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Créditos disponibles").font(.subheadline.bold())
                Text("Se aplican automáticamente en tu próxima reserva")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Text(credits.formattedAmount)
                .font(.title3.bold())
                .foregroundStyle(Color.piumsOrange)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.piumsOrange.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.piumsOrange.opacity(0.2), lineWidth: 1))
        )
    }
}

// MARK: - SummaryChip

private struct SummaryChip: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.subheadline.bold())
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack { PaymentsView() }
}
