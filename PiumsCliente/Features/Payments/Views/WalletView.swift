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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddCard = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(Color.piumsOrange)
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $showAddCard) {
            AddCardSheet(vm: vm)
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
                Text("Sin métodos de pago").font(.title3.bold()).padding(.top, 28)
                Text("Agrega una tarjeta para pagar tus reservas más rápido.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button { showAddCard = true } label: {
                Label("Agregar tarjeta", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.piumsOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.piumsOrange.opacity(0.3), radius: 10, y: 4)
            }
            .padding(.horizontal, 40)
            .padding(.top, 24)

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
                    subtitle: "Tus datos de tarjeta son procesados por Stripe y nunca se almacenan en nuestros servidores.")
            InfoRow(icon: "star.circle.fill", color: Color.piumsOrange,
                    title: "Tarjeta principal",
                    subtitle: "Toca cualquier tarjeta en el carrusel o usa «Predeterminar» para cambiar cuál se usa primero.")
            InfoRow(icon: "trash.circle.fill", color: .red,
                    title: "Control total",
                    subtitle: "Puedes eliminar tarjetas en cualquier momento. Se requiere al menos 1 tarjeta guardada.")
        }
        .padding(16)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Add Card Sheet

private struct AddCardSheet: View {
    let vm: WalletViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var cardNumber = ""
    @State private var expiry = ""
    @State private var cvc = ""
    @State private var cardholderName = ""
    @State private var setAsDefault = true
    @State private var isLoading = false
    @State private var errorMsg: String?

    private var formattedNumber: String {
        let digits = cardNumber.filter(\.isNumber).prefix(16)
        return stride(from: 0, to: digits.count, by: 4)
            .map { String(digits[$0..<min($0+4, digits.endIndex)]) }
            .joined(separator: " ")
    }

    private var isValid: Bool {
        let digits = cardNumber.filter(\.isNumber)
        let expParts = expiry.split(separator: "/")
        return digits.count >= 15 && expParts.count == 2
            && (expParts[0].count == 2) && (expParts[1].count == 2 || expParts[1].count == 4)
            && cvc.count >= 3 && !cardholderName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Live card preview
                    cardPreview
                        .padding(.top, 8)

                    // Form
                    VStack(spacing: 0) {
                        TextField("Nombre en la tarjeta", text: $cardholderName,
                                  prompt: Text("JUAN PÉREZ").foregroundStyle(Color(.placeholderText)))
                            .textInputAutocapitalization(.characters)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        Divider().padding(.leading, 16)

                        HStack(spacing: 0) {
                            TextField("Número de tarjeta", text: Binding(
                                get: { formattedNumber },
                                set: { raw in
                                    let digits = raw.filter(\.isNumber)
                                    cardNumber = String(digits.prefix(16))
                                }
                            ))
                            .keyboardType(.numberPad)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)

                            // Brand hint
                            if !cardNumber.isEmpty {
                                Image(systemName: brandIcon)
                                    .font(.title3)
                                    .foregroundStyle(brandColor)
                                    .padding(.trailing, 16)
                                    .transition(.scale.combined(with: .opacity))
                                    .animation(.spring(duration: 0.25), value: detectedBrand)
                            }
                        }

                        Divider().padding(.leading, 16)

                        HStack(spacing: 0) {
                            TextField("MM/AA", text: $expiry)
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .onChange(of: expiry) { _, new in expiry = formatExpiry(new) }

                            Rectangle().fill(Color(.separator)).frame(width: 1, height: 44)

                            TextField("CVC", text: $cvc)
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .onChange(of: cvc) { _, new in cvc = String(new.filter(\.isNumber).prefix(4)) }
                        }
                    }
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Default toggle
                    Toggle(isOn: $setAsDefault) {
                        Label("Establecer como tarjeta principal", systemImage: "star.fill")
                            .font(.subheadline)
                    }
                    .tint(Color.piumsOrange)
                    .padding(16)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Error
                    if let err = errorMsg {
                        Text(err)
                            .font(.caption).foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    // Submit
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().tint(.white).scaleEffect(0.85)
                                Text("Guardando...").font(.headline)
                            } else {
                                Image(systemName: "lock.fill")
                                Text("Guardar tarjeta").font(.headline)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isValid && !isLoading ? Color.piumsOrange : Color(.systemGray3))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: (isValid ? Color.piumsOrange : .clear).opacity(0.3), radius: 10, y: 4)
                    }
                    .disabled(!isValid || isLoading)

                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill").foregroundStyle(.green).font(.caption)
                        Text("Datos procesados de forma segura por Stripe")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Nueva tarjeta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Card Preview

    private var cardPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(previewGradient)
                .frame(height: 170)
                .shadow(color: .black.opacity(0.2), radius: 14, y: 8)

            Circle().fill(.white.opacity(0.06)).frame(width: 160).offset(x: 80, y: -60)
            Circle().fill(.white.opacity(0.04)).frame(width: 120).offset(x: -60, y: 70)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: brandIcon).font(.title2).foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    if setAsDefault {
                        Text("Principal")
                            .font(.caption2.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.white.opacity(0.2)).clipShape(Capsule())
                    }
                }
                Spacer()
                let digits = cardNumber.filter(\.isNumber)
                let display = digits.isEmpty ? "•••• •••• •••• ••••" :
                    (formattedNumber + String(repeating: " ••••", count: max(0, 4 - formattedNumber.split(separator: " ").count)))
                Text(display)
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)
                    .animation(.none, value: display)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TITULAR").font(.system(size: 9).bold()).foregroundStyle(.white.opacity(0.6)).tracking(1)
                        Text(cardholderName.isEmpty ? "NOMBRE APELLIDO" : cardholderName.uppercased())
                            .font(.system(.caption, design: .monospaced).bold()).foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("VENCE").font(.system(size: 9).bold()).foregroundStyle(.white.opacity(0.6)).tracking(1)
                        Text(expiry.isEmpty ? "MM/AA" : expiry)
                            .font(.system(.caption, design: .monospaced).bold()).foregroundStyle(.white)
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Helpers

    private var detectedBrand: String {
        let digits = cardNumber.filter(\.isNumber)
        if digits.hasPrefix("4") { return "visa" }
        if digits.hasPrefix("5") || digits.hasPrefix("2") { return "mastercard" }
        if digits.hasPrefix("34") || digits.hasPrefix("37") { return "amex" }
        return "unknown"
    }

    private var brandIcon: String {
        switch detectedBrand {
        case "visa":       return "v.circle.fill"
        case "mastercard": return "m.circle.fill"
        case "amex":       return "a.circle.fill"
        default:           return "creditcard.fill"
        }
    }

    private var brandColor: Color {
        switch detectedBrand {
        case "visa":       return Color(hex: "#1A1F71")
        case "mastercard": return Color(hex: "#EB001B")
        case "amex":       return Color(hex: "#006FCF")
        default:           return .secondary
        }
    }

    private var previewGradient: LinearGradient {
        switch detectedBrand {
        case "visa":       return LinearGradient(colors: [Color(hex: "#1A1F71"), Color(hex: "#2B35AF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "mastercard": return LinearGradient(colors: [Color(hex: "#1D2434"), Color(hex: "#3D1C1C")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "amex":       return LinearGradient(colors: [Color(hex: "#006FCF"), Color(hex: "#004A8F")], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:           return LinearGradient(colors: [Color(hex: "#1C1C1E"), Color(hex: "#2C2C2E")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func formatExpiry(_ raw: String) -> String {
        var digits = raw.filter(\.isNumber)
        if digits.count > 4 { digits = String(digits.prefix(4)) }
        if digits.count > 2 {
            return String(digits.prefix(2)) + "/" + String(digits.dropFirst(2))
        }
        return digits
    }

    // MARK: - Submit

    private func submit() async {
        errorMsg = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let pmId = try await createStripePaymentMethod()
            try await vm.saveMethod(stripePaymentMethodId: pmId, setAsDefault: setAsDefault)
            dismiss()
        } catch {
            errorMsg = AppError(from: error).errorDescription ?? "No se pudo guardar la tarjeta"
        }
    }

    private func createStripePaymentMethod() async throws -> String {
        guard let key = Bundle.main.infoDictionary?["STRIPE_PUBLISHABLE_KEY"] as? String,
              !key.isEmpty, !key.contains("REPLACE_ME") else {
            throw AppError.http(statusCode: 0, message: "Configuración de pagos no disponible")
        }

        let expiryParts = expiry.split(separator: "/")
        guard expiryParts.count == 2,
              let expMonth = Int(expiryParts[0]),
              let expYearRaw = Int(expiryParts[1]) else {
            throw AppError.http(statusCode: 0, message: "Fecha de expiración inválida")
        }
        let expYear = expYearRaw < 100 ? 2000 + expYearRaw : expYearRaw
        let digits = cardNumber.filter(\.isNumber)

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "type", value: "card"),
            URLQueryItem(name: "card[number]", value: String(digits)),
            URLQueryItem(name: "card[exp_month]", value: "\(expMonth)"),
            URLQueryItem(name: "card[exp_year]", value: "\(expYear)"),
            URLQueryItem(name: "card[cvc]", value: cvc),
            URLQueryItem(name: "billing_details[name]", value: cardholderName),
        ]
        let body = components.percentEncodedQuery?.data(using: .utf8)

        var req = URLRequest(url: URL(string: "https://api.stripe.com/v1/payment_methods")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.network(URLError(.badServerResponse))
        }

        struct StripeError: Decodable {
            struct Err: Decodable { let message: String }
            let error: Err
        }
        struct StripePM: Decodable { let id: String }

        if http.statusCode == 200 {
            return try JSONDecoder().decode(StripePM.self, from: data).id
        } else {
            let msg = (try? JSONDecoder().decode(StripeError.self, from: data))?.error.message ?? "Tarjeta rechazada"
            throw AppError.http(statusCode: http.statusCode, message: msg)
        }
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
