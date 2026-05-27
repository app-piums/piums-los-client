// CouponsView.swift — cupones disponibles del usuario
import SwiftUI
import UIKit

// MARK: - ViewModel

@Observable @MainActor
final class CouponsViewModel {
    var coupons: [Coupon] = []
    var isLoading = false
    var errorMessage: String?
    var copiedCode: String?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let res: MyCouponsResponse = try await APIClient.request(.getMyCoupons)
            coupons = res.allCoupons.filter { $0.status == .active && !$0.isExpired }
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func copy(_ code: String) {
        UIPasteboard.general.string = code
        copiedCode = code
        Task {
            try? await Task.sleep(for: .seconds(2))
            if copiedCode == code { copiedCode = nil }
        }
    }
}

// MARK: - View

struct CouponsView: View {
    @State private var vm = CouponsViewModel()

    var body: some View {
        Group {
            if vm.isLoading && vm.coupons.isEmpty {
                LoadingView()
            } else if let err = vm.errorMessage, vm.coupons.isEmpty {
                EmptyStateView(
                    systemImage: "ticket.fill",
                    title: "Error al cargar",
                    description: err,
                    actionTitle: "Reintentar"
                ) { Task { await vm.load() } }
            } else if vm.coupons.isEmpty {
                EmptyStateView(
                    systemImage: "ticket.fill",
                    title: "Sin cupones",
                    description: "Aquí aparecerán los cupones de descuento disponibles para tus reservas."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(vm.coupons) { coupon in
                            CouponCard(coupon: coupon, isCopied: vm.copiedCode == coupon.code) {
                                vm.copy(coupon.code)
                            }
                            .padding(.horizontal)
                        }
                        Color.clear.frame(height: 12)
                    }
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .refreshable { await vm.load() }
            }
        }
        .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
        .task { await vm.load() }
    }
}

// MARK: - CouponCard

struct CouponCard: View {
    let coupon: Coupon
    let isCopied: Bool
    let onCopy: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header con descuento
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(coupon.name)
                        .font(.headline)
                        .lineLimit(1)
                    if let desc = coupon.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Text(coupon.discountLabel)
                    .font(.title2.bold())
                    .foregroundStyle(Color.piumsOrange)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 16)
                .overlay(alignment: .center) {
                    // Notches estilo ticket
                    HStack {
                        Circle().fill(Color(.secondarySystemGroupedBackground))
                            .frame(width: 16, height: 16)
                            .offset(x: -8)
                        Spacer()
                        Circle().fill(Color(.secondarySystemGroupedBackground))
                            .frame(width: 16, height: 16)
                            .offset(x: 8)
                    }
                }

            // Código + info
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(coupon.code)
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundStyle(Color.piumsOrange)
                    HStack(spacing: 10) {
                        if let min = coupon.minimumAmount {
                            Label("Mín. \(Int(Double(min)/100).piumsFormatted)", systemImage: "arrow.up")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let expiry = coupon.expiryLabel {
                            Label(expiry, systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if coupon.maxUses == 1 || coupon.maxUsesPerUser == 1 {
                            Label("1 uso", systemImage: "ticket")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Button(action: onCopy) {
                    Label(isCopied ? "Copiado" : "Copiar",
                          systemImage: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.caption.bold())
                        .foregroundStyle(isCopied ? .green : Color.piumsOrange)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background((isCopied ? Color.green : Color.piumsOrange).opacity(0.10))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: isCopied)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

#Preview {
    NavigationStack { CouponsView() }
}
