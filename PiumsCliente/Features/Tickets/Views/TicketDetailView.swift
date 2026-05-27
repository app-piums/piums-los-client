// TicketDetailView.swift
import SwiftUI

struct TicketDetailView: View {
    let event: TicketEvent
    @State private var vm = TicketsViewModel()
    @State private var selectedTier: TicketTier?
    @State private var quantity = 1
    @State private var showPurchaseSheet = false
    @State private var showWebView = false
    @State private var showSuccessAlert = false

    private var formattedDate: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()
        guard let date = iso.date(from: event.eventDate) ?? iso2.date(from: event.eventDate) else {
            return String(event.eventDate.prefix(10))
        }
        let f = DateFormatter()
        f.dateFormat = "EEEE d 'de' MMMM, yyyy — HH:mm"
        f.locale = Locale(identifier: "es_ES")
        return f.string(from: date).capitalized
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Hero image ───────────────────────────────
                Group {
                    if let url = event.imageUrl, let imgURL = URL(string: url) {
                        AsyncImage(url: imgURL) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            default:
                                heroPlaceholder
                            }
                        }
                    } else {
                        heroPlaceholder
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipped()

                VStack(alignment: .leading, spacing: 20) {

                    // ── Info principal ───────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        if event.isSoldOut {
                            Label("Agotado", systemImage: "ticket.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }

                        Text(event.name).font(.title2.bold())

                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill").foregroundStyle(Color.piumsOrange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.venue).font(.subheadline.bold())
                                Text(event.address).font(.caption).foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "calendar").foregroundStyle(Color.piumsOrange)
                            Text(formattedDate).font(.subheadline).foregroundStyle(.secondary)
                        }

                        if let doors = event.doorsOpen {
                            HStack(spacing: 6) {
                                Image(systemName: "door.left.hand.open").foregroundStyle(.secondary)
                                Text("Puertas abren: \(String(doors.prefix(5)))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()

                    // ── Descripción ──────────────────────────
                    if let desc = event.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Descripción").font(.headline)
                            Text(desc).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Divider()
                    }

                    // ── Tiers ────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Selecciona tu entrada").font(.headline)
                        ForEach(event.tiers) { tier in
                            TierRow(
                                tier: tier,
                                isSelected: selectedTier?.id == tier.id,
                                onSelect: {
                                    if !tier.isSoldOut { selectedTier = tier }
                                }
                            )
                        }
                    }

                    // ── Cantidad ─────────────────────────────
                    if let tier = selectedTier, !tier.isSoldOut {
                        HStack {
                            Text("Cantidad").font(.subheadline.bold())
                            Spacer()
                            Stepper("\(quantity)", value: $quantity, in: 1...min(tier.available, 10))
                                .labelsHidden()
                            Text("\(quantity)").font(.subheadline.bold()).frame(width: 30)
                        }
                        .padding(14)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Total
                        HStack {
                            Text("Total")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text((tier.priceCents * quantity).piumsFormatted)
                                .font(.title3.bold())
                                .foregroundStyle(Color.piumsOrange)
                        }
                    }

                    // ── Botón comprar ────────────────────────
                    Button {
                        guard selectedTier != nil else { return }
                        showPurchaseSheet = true
                    } label: {
                        Group {
                            if vm.isPurchasing {
                                ProgressView().tint(.white)
                            } else {
                                Text(event.isSoldOut ? "Agotado"
                                     : selectedTier == nil ? "Selecciona una entrada"
                                     : "Comprar boleto")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            event.isSoldOut || selectedTier == nil
                            ? Color.gray : Color.piumsOrange
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(event.isSoldOut || selectedTier == nil || vm.isPurchasing)
                }
                .padding(20)
            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Evento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.secondarySystemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showPurchaseSheet) {
            TicketPurchaseSheet(
                event: event,
                tier: selectedTier!,
                quantity: quantity,
                vm: vm,
                onPaid: {
                    showPurchaseSheet = false
                    showSuccessAlert = true
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("¡Pago exitoso!", isPresented: $showSuccessAlert) {
            Button("Ver mis boletos", role: .cancel) {}
        } message: {
            Text("Tu boleto fue confirmado. Encuéntralo en la sección Boletos de Mi Espacio.")
        }
        .onChange(of: vm.redirectUrl) { _, url in
            if url != nil { showWebView = true }
        }
        .fullScreenCover(isPresented: $showWebView) {
            if let url = vm.redirectUrl {
                TicketPaymentWebView(redirectUrl: url, vm: vm) {
                    showWebView = false
                    if vm.purchaseCompleted {
                        showPurchaseSheet = false
                        showSuccessAlert = true
                    }
                }
            }
        }
    }

    private var heroPlaceholder: some View {
        LinearGradient(
            colors: [Color.piumsOrange.opacity(0.7), Color(hex: "#E91E8C").opacity(0.5)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - TierRow

private struct TierRow: View {
    let tier: TicketTier
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.piumsOrange : Color(.separator), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color.piumsOrange).frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(tier.name).font(.subheadline.bold())
                        if tier.isSoldOut {
                            Text("AGOTADO")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                    if let desc = tier.description {
                        Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Text("\(tier.available) disponibles")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text(tier.formattedPrice)
                    .font(.subheadline.bold())
                    .foregroundStyle(tier.isSoldOut ? .secondary : Color.piumsOrange)
            }
            .padding(14)
            .background(
                isSelected
                ? Color.piumsOrange.opacity(0.07)
                : Color(.tertiarySystemGroupedBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.piumsOrange.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(tier.isSoldOut)
        .opacity(tier.isSoldOut ? 0.55 : 1)
    }
}

// MARK: - TicketPurchaseSheet (datos del comprador)

private struct TicketPurchaseSheet: View {
    let event: TicketEvent
    let tier: TicketTier
    let quantity: Int
    let vm: TicketsViewModel
    let onPaid: () -> Void

    @State private var buyerName = ""
    @State private var buyerEmail = ""
    @State private var couponCode = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Resumen") {
                    LabeledContent("Evento", value: event.name)
                    LabeledContent("Entrada", value: tier.name)
                    LabeledContent("Cantidad", value: "\(quantity)")
                    LabeledContent("Total") {
                        Text((tier.priceCents * quantity).piumsFormatted)
                            .font(.subheadline.bold()).foregroundStyle(Color.piumsOrange)
                    }
                }

                Section("Datos del comprador") {
                    TextField("Nombre completo", text: $buyerName)
                        .autocorrectionDisabled()
                    TextField("Correo electrónico", text: $buyerEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                Section("Cupón (opcional)") {
                    TextField("Código de cupón", text: $couponCode)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                }

                if let err = vm.purchaseErrorMessage {
                    Section {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }

                Section {
                    Button {
                        Task { await doPurchase() }
                    } label: {
                        HStack {
                            Spacer()
                            if vm.isPurchasing {
                                ProgressView().tint(.white)
                            } else {
                                Text("Proceder al pago")
                                    .font(.headline).foregroundStyle(.white)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .background(canSubmit ? Color.piumsOrange : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(!canSubmit || vm.isPurchasing)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Confirmar compra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .onChange(of: vm.purchaseCompleted) { _, done in
            if done { onPaid() }
        }
    }

    private var canSubmit: Bool {
        !buyerName.trimmingCharacters(in: .whitespaces).isEmpty &&
        buyerEmail.contains("@")
    }

    private func doPurchase() async {
        let name = buyerName.trimmingCharacters(in: .whitespaces)
        let email = buyerEmail.trimmingCharacters(in: .whitespaces)
        let coupon = couponCode.trimmingCharacters(in: .whitespaces)
        await vm.purchaseTicket(
            event: event, tier: tier, quantity: quantity,
            buyerName: name, buyerEmail: email,
            couponCode: coupon.isEmpty ? nil : coupon
        )
    }
}

// MARK: - TicketPaymentWebView (Tilopay)

private struct TicketPaymentWebView: View {
    let redirectUrl: String
    let vm: TicketsViewModel
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            TilopayTicketWebBridge(urlString: redirectUrl, vm: vm, onDismiss: onDismiss)
                .ignoresSafeArea()
                .navigationTitle("Pago seguro")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { onDismiss() }
                    }
                }
        }
    }
}

// MARK: - UIKit bridge para WKWebView de tickets

import WebKit

private struct TilopayTicketWebBridge: UIViewRepresentable {
    let urlString: String
    let vm: TicketsViewModel
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(vm: vm, onDismiss: onDismiss) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        if let url = URL(string: urlString) {
            wv.load(URLRequest(url: url))
        }
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let vm: TicketsViewModel
        let onDismiss: () -> Void
        init(vm: TicketsViewModel, onDismiss: @escaping () -> Void) {
            self.vm = vm; self.onDismiss = onDismiss
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            if let url = action.request.url?.absoluteString,
               url.contains("piums://tickets") || url.contains("confirmacion") {
                Task { @MainActor in
                    await vm.pollPurchaseStatus()
                    onDismiss()
                }
                return .cancel
            }
            return .allow
        }
    }
}
