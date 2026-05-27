// WalletView.swift — Métodos de pago guardados
import SwiftUI

// MARK: - ViewModel

@Observable @MainActor
final class WalletViewModel {
    var methods: [PaymentMethod] = []
    var isLoading = false
    var errorMessage: String?
    var deletingId: String?
    var settingDefaultId: String?
    var addingCard = false

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let res: PaymentMethodsResponse = try await APIClient.request(.listPaymentMethods)
            methods = res.all
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func setDefault(_ method: PaymentMethod) async {
        settingDefaultId = method.id
        defer { settingDefaultId = nil }
        do {
            let _: VoidResponse = try await APIClient.request(.setDefaultPaymentMethod(id: method.id))
            methods = methods.map { m in
                PaymentMethod(
                    id: m.id, provider: m.provider, type: m.type,
                    cardBrand: m.cardBrand, cardLast4: m.cardLast4,
                    cardExpMonth: m.cardExpMonth, cardExpYear: m.cardExpYear,
                    isDefault: m.id == method.id, createdAt: m.createdAt
                )
            }
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func delete(_ method: PaymentMethod) async {
        deletingId = method.id
        defer { deletingId = nil }
        do {
            let _: VoidResponse = try await APIClient.request(.deletePaymentMethod(id: method.id))
            methods.removeAll { $0.id == method.id }
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    // Called after Stripe returns a pm_xxx
    func saveMethod(stripePaymentMethodId: String, setAsDefault: Bool) async throws {
        addingCard = true
        defer { addingCard = false }
        struct SaveResp: Decodable { let method: PaymentMethod }
        let res: SaveResp = try await APIClient.request(
            .addPaymentMethod(stripePaymentMethodId: stripePaymentMethodId, setAsDefault: setAsDefault)
        )
        if setAsDefault {
            methods = methods.map { m in
                PaymentMethod(
                    id: m.id, provider: m.provider, type: m.type,
                    cardBrand: m.cardBrand, cardLast4: m.cardLast4,
                    cardExpMonth: m.cardExpMonth, cardExpYear: m.cardExpYear,
                    isDefault: false, createdAt: m.createdAt
                )
            }
        }
        methods.insert(res.method, at: 0)
    }
}

// MARK: - View

struct WalletView: View {
    @State private var vm = WalletViewModel()
    @State private var confirmDelete: PaymentMethod?
    @State private var showAddCard = false

    var body: some View {
        Group {
            if vm.isLoading && vm.methods.isEmpty {
                LoadingView()
            } else if let err = vm.errorMessage, vm.methods.isEmpty {
                EmptyStateView(
                    systemImage: "creditcard.trianglebadge.exclamationmark",
                    title: "Error al cargar",
                    description: err,
                    actionTitle: "Reintentar"
                ) { Task { await vm.load() } }
            } else if vm.methods.isEmpty {
                emptyWallet
            } else {
                cardList
            }
        }
        .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Mis Tarjetas")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddCard = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddCard) {
            HowToAddCardSheet()
        }
        .alert("Eliminar tarjeta", isPresented: Binding(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } }
        )) {
            Button("Eliminar", role: .destructive) {
                guard let m = confirmDelete else { return }
                confirmDelete = nil
                Task { await vm.delete(m) }
            }
            Button("Cancelar", role: .cancel) { confirmDelete = nil }
        } message: {
            if let m = confirmDelete {
                Text("¿Eliminar la tarjeta \(m.brandLabel) •••• \(m.cardLast4 ?? "")?")
            }
        }
        .overlay {
            if let err = vm.errorMessage, !vm.methods.isEmpty {
                VStack {
                    Spacer()
                    ErrorBannerView(message: err)
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(), value: vm.errorMessage)
            }
        }
    }

    // MARK: - Card List

    private var cardList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(vm.methods) { method in
                            CardTile(
                                method: method,
                                isSettingDefault: vm.settingDefaultId == method.id
                            ) {
                                Task { await vm.setDefault(method) }
                            }
                        }
                        AddCardPlaceholder { showAddCard = true }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }

                VStack(spacing: 0) {
                    ForEach(vm.methods) { method in
                        MethodRow(
                            method: method,
                            isDeleting: vm.deletingId == method.id,
                            isSettingDefault: vm.settingDefaultId == method.id,
                            canDelete: vm.methods.count > 1
                        ) {
                            Task { await vm.setDefault(method) }
                        } onDelete: {
                            confirmDelete = method
                        }
                        if method.id != vm.methods.last?.id {
                            Divider().padding(.leading, 72)
                        }
                    }
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)

                infoSection
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                Color.clear.frame(height: 40)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Empty

    private var emptyWallet: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color(.systemGray4), Color(.systemGray5)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 300, height: 180)
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 8)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .font(.title).foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text("PIUMS").font(.caption.bold()).foregroundStyle(.white.opacity(0.5)).tracking(3)
                    }
                    Spacer()
                    Text("•••• •••• •••• ••••")
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Sin tarjetas guardadas")
                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                .padding(24)
            }
            .padding(.top, 48)

            VStack(spacing: 8) {
                Text("Sin tarjetas guardadas").font(.title3.bold()).padding(.top, 28)
                Text("Aquí verás tus tarjetas guardadas para realizar pagos rápidos.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            infoSection
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Spacer()
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 10) {
            InfoRow(icon: "lock.shield.fill", color: .green,
                    title: "Pagos seguros",
                    subtitle: "Aceptamos Visa y Mastercard. Tus datos son procesados por Tilopay de forma segura y encriptada.")
            InfoRow(icon: "bolt.circle.fill", color: Color.piumsOrange,
                    title: "Pagos rápidos",
                    subtitle: "Administra tus métodos de pago para realizar reservas de forma segura con Tilopay.")
            InfoRow(icon: "star.circle.fill", color: .blue,
                    title: "Tarjeta principal",
                    subtitle: "Toca cualquier tarjeta en el carrusel o usa «Predeterminar» para cambiar cuál se usa primero.")
            InfoRow(icon: "trash.circle.fill", color: .red,
                    title: "Control total",
                    subtitle: "Puedes eliminar tarjetas en cualquier momento.")
        }
        .padding(16)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - How To Add Card Sheet

private struct HowToAddCardSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Ilustración
                    ZStack {
                        Circle()
                            .fill(Color.piumsOrange.opacity(0.10))
                            .frame(width: 100, height: 100)
                        Image(systemName: "creditcard.and.123")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.piumsOrange)
                    }
                    .padding(.top, 32)

                    VStack(spacing: 8) {
                        Text("¿Cómo pagar con tarjeta?")
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                        Text("Paga de forma segura a través de Tilopay con tu tarjeta Visa o Mastercard.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    VStack(spacing: 0) {
                        StepRow(number: "1", icon: "calendar.badge.plus",
                                title: "Reserva un servicio",
                                subtitle: "Encuentra un artista y crea tu reserva.")
                        Divider().padding(.leading, 56)
                        StepRow(number: "2", icon: "lock.shield.fill",
                                title: "Paga con Tilopay",
                                subtitle: "Ingresa los datos de tu tarjeta Visa o Mastercard en el formulario seguro de Tilopay.")
                        Divider().padding(.leading, 56)
                        StepRow(number: "3", icon: "checkmark.seal.fill",
                                title: "Pago confirmado",
                                subtitle: "Recibirás confirmación de tu reserva una vez procesado el pago.")
                    }
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill").foregroundStyle(.green)
                            Text("Datos procesados de forma segura por Tilopay")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Solo se aceptan Visa y Mastercard")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.bottom, 16)
                }
            }
            .scrollIndicators(.hidden)
            .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Agregar tarjeta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct StepRow: View {
    let number: String
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(Color.piumsOrange.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: icon).font(.subheadline).foregroundStyle(Color.piumsOrange)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineSpacing(2)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}



// MARK: - CardTile

private struct CardTile: View {
    let method: PaymentMethod
    let isSettingDefault: Bool
    let onSetDefault: () -> Void

    private var gradient: LinearGradient {
        switch method.cardBrand?.lowercased() {
        case "visa":
            return LinearGradient(colors: [Color(hex: "#1A1F71"), Color(hex: "#2B35AF")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "mastercard":
            return LinearGradient(colors: [Color(hex: "#1D2434"), Color(hex: "#3D1C1C")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "amex":
            return LinearGradient(colors: [Color(hex: "#006FCF"), Color(hex: "#004A8F")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [Color(hex: "#1C1C1E"), Color(hex: "#2C2C2E")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var brandIcon: String {
        switch method.cardBrand?.lowercased() {
        case "visa":       return "v.circle.fill"
        case "mastercard": return "m.circle.fill"
        case "amex":       return "a.circle.fill"
        default:           return "creditcard.fill"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(gradient)
                .frame(width: 280, height: 170)
                .shadow(color: .black.opacity(0.22), radius: 14, y: 8)

            Circle().fill(.white.opacity(0.06)).frame(width: 160).offset(x: 80, y: -60)
            Circle().fill(.white.opacity(0.04)).frame(width: 120).offset(x: -60, y: 70)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: brandIcon)
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    if method.isDefault {
                        Text("Principal")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                Text("•••• •••• •••• \(method.cardLast4 ?? "••••")")
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VENCE").font(.system(size: 9).bold()).foregroundStyle(.white.opacity(0.6)).tracking(1)
                        Text(method.expiryLabel)
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text(method.brandLabel.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(1)
                }
            }
            .padding(20)
        }
        .frame(width: 280, height: 170)
        .onTapGesture {
            if !method.isDefault { onSetDefault() }
        }
        .overlay(alignment: .bottom) {
            if isSettingDefault {
                ProgressView().tint(.white).padding(.bottom, 8)
            }
        }
    }
}

// MARK: - AddCardPlaceholder

private struct AddCardPlaceholder: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundStyle(Color(.systemGray4))
                    .frame(width: 280, height: 170)

                VStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.piumsOrange.opacity(0.7))
                    Text("Nueva tarjeta")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.systemGray2))
                    Text("Agrega una tarjeta de crédito\no débito de forma segura")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray3))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(width: 280, height: 170)
    }
}

// MARK: - MethodRow

private struct MethodRow: View {
    let method: PaymentMethod
    let isDeleting: Bool
    let isSettingDefault: Bool
    let canDelete: Bool
    let onSetDefault: () -> Void
    let onDelete: () -> Void

    private var brandColor: Color {
        switch method.cardBrand?.lowercased() {
        case "visa":       return Color(hex: "#1A1F71")
        case "mastercard": return Color(hex: "#EB001B")
        case "amex":       return Color(hex: "#006FCF")
        default:           return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(brandColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "creditcard.fill")
                    .font(.subheadline)
                    .foregroundStyle(brandColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(method.brandLabel) •••• \(method.cardLast4 ?? "••••")")
                        .font(.subheadline.bold())
                    if method.isDefault {
                        Text("Principal")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.piumsOrange)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.piumsOrange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text("Vence \(method.expiryLabel)")
                    .font(.caption).foregroundStyle(.secondary)
                if !canDelete {
                    Text("Mínimo 1 tarjeta requerida")
                        .font(.caption2).foregroundStyle(.orange)
                }
            }

            Spacer()

            if isDeleting || isSettingDefault {
                ProgressView().scaleEffect(0.8)
            } else {
                Menu {
                    if !method.isDefault {
                        Button {
                            onSetDefault()
                        } label: {
                            Label("Establecer como principal", systemImage: "star.fill")
                        }
                    }
                    if canDelete {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Eliminar tarjeta", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: canDelete ? "ellipsis.circle" : "lock.circle")
                        .font(.title3)
                        .foregroundStyle(canDelete ? Color.secondary : Color.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - InfoRow

private struct InfoRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineSpacing(2)
            }
        }
    }
}

#Preview {
    NavigationStack { WalletView() }
}
