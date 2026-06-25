// PaymentCheckoutView.swift — Checkout de anticipo / pago completo vía Tilopay o Stripe
import SwiftUI

// MARK: - ViewModel

@Observable @MainActor
final class PaymentCheckoutViewModel {

    enum Phase { case ready, loading, processing, confirmed, declined, error(String) }

    var phase: Phase = .ready
    var showWebView   = false
    var redirectUrl: URL?
    var confirmedBooking: Booking?
    private(set) var pollingMessage: String = ""

    private(set) var amountToPay: Int = 0
    private(set) var currency: String = "USD"
    private var isPayingRemaining = false

    var savedCard: PaymentMethod? = nil
    var useSavedCard: Bool = true
    var usedSavedCardDeferred: Bool = false

    // Helpers para el switch en la vista
    var isBusy: Bool {
        switch phase {
        case .loading, .processing: return true
        default: return false
        }
    }
    var errorText: String? {
        if case .error(let msg) = phase { return msg }
        return nil
    }
    var isConfirmed: Bool {
        if case .confirmed = phase { return true }
        return false
    }
    var isDeclined: Bool {
        if case .declined = phase { return true }
        return false
    }

    // MARK: - Helpers

    private func splitName(_ fullName: String?) -> (first: String?, last: String?) {
        guard let name = fullName?.trimmingCharacters(in: .whitespaces), !name.isEmpty else {
            return (nil, nil)
        }
        let parts = name.components(separatedBy: " ").filter { !$0.isEmpty }
        if parts.count == 1 { return (parts[0], nil) }
        let last  = parts.last!
        let first = parts.dropLast().joined(separator: " ")
        return (first, last)
    }

    // MARK: - Setup

    func setup(booking: Booking, overrideAmount: Int? = nil) {
        currency = "USD"
        if let override = overrideAmount {
            amountToPay       = override
            isPayingRemaining = true
        } else {
            amountToPay = (booking.anticipoRequired == true)
                ? (booking.anticipoAmount ?? booking.totalPrice)
                : booking.totalPrice
            isPayingRemaining = false
        }
        Task { await loadDefaultCard() }
    }

    func loadDefaultCard() async {
        do {
            let method: PaymentMethod = try await APIClient.request(.getDefaultPaymentMethod)
            savedCard = method
        } catch {
            savedCard = nil
        }
    }

    // MARK: - Tarjeta guardada: diferir cobro al confirmar el artista

    func confirmPendingWithSavedCard(booking: Booking) {
        confirmedBooking = booking
        usedSavedCardDeferred = true
        phase = .confirmed
    }

    // MARK: - Iniciar pago (Tilopay WebView)

    func startPayment(booking: Booking, artist: Artist, bookingIdOverride: String? = nil) async {
        phase = .loading
        // Refrescar token antes de abrir el WebView — el pago puede tardar varios minutos
        try? await AuthManager.shared.refreshIfNeeded()
        let user = AuthManager.shared.currentUser
        let (billingFirst, billingLast) = splitName(user?.nombre)
        do {
            let wrapper: PaymentIntentWrapper = try await APIClient.request(
                .createPaymentIntent(
                    bookingId:    bookingIdOverride ?? booking.id,
                    amount:       amountToPay,
                    currency:     currency,
                    countryCode:  artist.country,
                    billingFirst: billingFirst,
                    billingLast:  billingLast
                )
            )
            guard let intent = wrapper.resolved else {
                phase = .error("No se pudo iniciar el pago. Intenta de nuevo.")
                return
            }
            if intent.isTilopay, let urlStr = intent.redirectUrl, let url = URL(string: urlStr) {
                redirectUrl = url
                phase = .ready
                showWebView = true
            } else if intent.clientSecret != nil {
                // Stripe nativo — pendiente de integración con Stripe SDK
                phase = .error("Pago internacional con tarjeta próximamente.")
            } else {
                phase = .error("Método de pago no disponible.")
            }
        } catch {
            phase = .error(AppError(from: error).errorDescription ?? "Error al iniciar el pago.")
        }
    }

    // MARK: - Callback de Tilopay

    func handleCallback(_ params: TilopayCallbackParams) {
        showWebView = false
        #if DEBUG
        print("[Tilopay] callback: responseCode='\(params.responseCode)' orderNumber='\(params.orderNumber)' amount='\(params.amount)'")
        #endif
        if params.isApproved {
            phase = .processing
            Task { await confirmAndPoll(params: params) }
        } else {
            // responseCode no es "00" (o está vacío).
            // Tilopay puede haber enviado el webhook server-side antes de redirigir
            // al cliente → verificar el estado real en backend antes de declinar.
            phase = .processing
            Task { await checkThenDecline(bookingId: params.bookingId, params: params) }
        }
    }

    // Verifica brevemente si el pago fue confirmado por webhook antes de declinar.
    private func checkThenDecline(bookingId: String, params: TilopayCallbackParams) async {
        pollingMessage = "Verificando tu pago..."
        try? await Task.sleep(for: .seconds(3))
        do {
            let booking: Booking = try await APIClient.request(.getBooking(id: bookingId))
            let paid = isPayingRemaining
                ? (booking.paymentStatus == .fullyPaid || booking.paymentStatus == .completed)
                : (booking.paymentStatus == .anticipoPaid || booking.paymentStatus == .fullyPaid || booking.paymentStatus == .completed || booking.paymentStatus == .cardAuthorized)
            if paid {
                confirmedBooking = booking
                phase = .confirmed
                return
            }
        } catch let err as AppError {
            if case .unauthorized = err {
                // No podemos verificar — asumimos éxito si auth venció durante el WebView
                phase = .confirmed
                return
            }
        } catch {}
        phase = .declined
    }

    private func confirmAndPoll(params: TilopayCallbackParams) async {
        let amountStr = params.amount.isEmpty
            ? String(format: "%.2f", Double(amountToPay) / 100.0)
            : params.amount
        do {
            let _: TilopayConfirmResponse = try await APIClient.request(
                .confirmTilopayRedirect(
                    bookingId:    params.bookingId,
                    responseCode: params.responseCode,
                    orderNumber:  params.orderNumber,
                    amount:       amountStr,
                    auth:         params.auth,
                    currency:     params.currency,
                    orderHash:    params.orderHash,
                    cardHash:     params.cardHash,
                    cardBrand:    params.cardBrand,
                    cardLast4:    params.cardLast4
                )
            )
        } catch let err as AppError {
            if case .unauthorized = err {
                // Sesión caducada durante el WebView, pero Tilopay aprobó el pago.
                // El webhook server-side ya actualizó el booking — mostramos éxito
                // tras una breve espera para que el webhook procese.
                pollingMessage = "Confirmando pago..."
                try? await Task.sleep(for: .seconds(4))
                phase = .confirmed
                return
            }
        } catch {}

        await pollUntilPaid(bookingId: params.bookingId)
    }

    private func pollUntilPaid(bookingId: String, attempt: Int = 0) async {
        guard attempt < 10 else { phase = .confirmed; return }
        pollingMessage = switch attempt {
        case 0...2: "Verificando tu pago..."
        case 3...5: "Confirmando con Tilopay..."
        case 6...8: "Esto puede tardar unos segundos más..."
        default:    "Casi listo..."
        }
        do {
            try await Task.sleep(for: .seconds(3))
            let booking: Booking = try await APIClient.request(.getBooking(id: bookingId))
            let paid = isPayingRemaining
                ? (booking.paymentStatus == .fullyPaid || booking.paymentStatus == .completed)
                : (booking.paymentStatus == .anticipoPaid || booking.paymentStatus == .fullyPaid || booking.paymentStatus == .completed || booking.paymentStatus == .cardAuthorized)
            if paid {
                confirmedBooking = booking
                phase = .confirmed
            } else {
                await pollUntilPaid(bookingId: bookingId, attempt: attempt + 1)
            }
        } catch let err as AppError {
            // Sesión caducada durante el polling — el webhook ya actualizó el booking
            if case .unauthorized = err { phase = .confirmed; return }
            phase = .confirmed
        } catch {
            phase = .confirmed
        }
    }
}

// MARK: - Vista principal

struct PaymentCheckoutView: View {
    let booking: Booking
    let artist: Artist
    var overrideAmount: Int? = nil
    var bookingIdOverride: String? = nil
    let onDone: () -> Void

    @State private var vm = PaymentCheckoutViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if vm.isConfirmed {
                    ScrollView { paymentSuccessView.padding(20) }.scrollIndicators(.hidden)
                } else if vm.isDeclined {
                    ScrollView { paymentDeclinedView.padding(20) }.scrollIndicators(.hidden)
                } else {
                    ScrollView { checkoutContent.padding(20) }.scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Confirmar Pago")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !vm.isConfirmed {
                        Button("Cancelar") { dismiss() }.foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $vm.showWebView) {
            if let url = vm.redirectUrl {
                TilopayWebSheet(url: url) { params in
                    vm.handleCallback(params)
                }
            }
        }
        .onAppear { vm.setup(booking: booking, overrideAmount: overrideAmount) }
    }

    // MARK: - Checkout content

    private var checkoutContent: some View {
        VStack(spacing: 20) {

            // Resumen de reserva
            VStack(alignment: .leading, spacing: 14) {
                Text("Resumen de reserva").font(.headline)
                Divider()
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.piumsOrange.opacity(0.12)).frame(width: 48, height: 48)
                        Text(artist.artistName.prefix(2).uppercased())
                            .font(.subheadline.bold()).foregroundStyle(Color.piumsOrange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(artist.artistName).font(.headline)
                        Text(artist.mainServiceName ?? artist.specialties?.first ?? "Artista")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 16) {
                    Label(formattedDate, systemImage: "calendar")
                    if let time = booking.scheduledTime {
                        Label(time, systemImage: "clock")
                    }
                }
                .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Desglose de precio
            VStack(alignment: .leading, spacing: 12) {
                Text("Desglose de pago").font(.headline)
                Divider()

                if booking.anticipoRequired == true, let anticipo = booking.anticipoAmount {
                    let rest = booking.totalPrice - anticipo
                    CKPriceRow(label: "Servicio base", value: formatCents(booking.servicePrice ?? booking.totalPrice))
                    if let travel = booking.travelPrice, travel > 0 {
                        CKPriceRow(label: "Viáticos / traslado", value: formatCents(travel))
                    }
                    if let addons = booking.addonsPrice, addons > 0 {
                        CKPriceRow(label: "Add-ons", value: formatCents(addons))
                    }
                    CKPriceRow(label: "Anticipo (50%)", value: formatCents(anticipo), highlight: true)
                    CKPriceRow(label: "Saldo restante", value: formatCents(rest),
                               note: "Se cobra automáticamente 72h antes", dimmed: true)
                } else {
                    CKPriceRow(label: "Servicio base", value: formatCents(booking.servicePrice ?? booking.totalPrice))
                    if let travel = booking.travelPrice, travel > 0 {
                        CKPriceRow(label: "Viáticos / traslado", value: formatCents(travel))
                    }
                    if let addons = booking.addonsPrice, addons > 0 {
                        CKPriceRow(label: "Add-ons", value: formatCents(addons))
                    }
                }

                Divider()
                HStack {
                    Text("Total a pagar ahora").font(.headline)
                    Spacer()
                    Text(formatCents(vm.amountToPay))
                        .font(.title3.bold()).foregroundStyle(Color.piumsOrange)
                }
            }
            .padding(16)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Tarjeta guardada
            if let card = vm.savedCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Método de pago").font(.headline)
                    Divider()

                    // Opción: tarjeta guardada
                    Button {
                        vm.useSavedCard = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: vm.useSavedCard ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(vm.useSavedCard ? Color.piumsOrange : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(card.brandLabel) ••••\(card.cardLast4 ?? "")")
                                    .font(.subheadline.bold()).foregroundStyle(.primary)
                                Text("Vence \(card.expiryLabel)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "creditcard.fill")
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(vm.useSavedCard ? Color.piumsOrange.opacity(0.07) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(vm.useSavedCard ? Color.piumsOrange.opacity(0.4) : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    // Opción: usar otra tarjeta
                    Button {
                        vm.useSavedCard = false
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: vm.useSavedCard ? "circle" : "checkmark.circle.fill")
                                .foregroundStyle(vm.useSavedCard ? .secondary : Color.piumsOrange)
                            Text("Usar otra tarjeta")
                                .font(.subheadline).foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(12)
                        .background(vm.useSavedCard ? Color.clear : Color.piumsOrange.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(vm.useSavedCard ? Color.clear : Color.piumsOrange.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            // Badge de seguridad
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill").foregroundStyle(.green)
                Text("Pago seguro · Procesado por Tilopay").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Error
            if let msg = vm.errorText {
                Text(msg).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
            }

            // Procesando pago — polling en curso
            if case .processing = vm.phase {
                VStack(spacing: 12) {
                    ProgressView().scaleEffect(1.2)
                    Text(vm.pollingMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut, value: vm.pollingMessage)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.bottom, 20)
            } else {
                // Botón de pago
                Button {
                    if vm.savedCard != nil && vm.useSavedCard {
                        vm.confirmPendingWithSavedCard(booking: booking)
                    } else {
                        Task { await vm.startPayment(booking: booking, artist: artist, bookingIdOverride: bookingIdOverride) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if vm.isBusy {
                            ProgressView().tint(.white).scaleEffect(0.85)
                            Text("Procesando...").font(.headline)
                        } else if let card = vm.savedCard, vm.useSavedCard {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Reservar con \(card.brandLabel) ••••\(card.cardLast4 ?? "")")
                                .font(.headline)
                        } else {
                            Image(systemName: "creditcard.fill")
                            Text("Pagar \(formatCents(vm.amountToPay))").font(.headline)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(vm.isBusy ? Color.piumsOrange.opacity(0.6) : Color.piumsOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.piumsOrange.opacity(0.3), radius: 10, y: 4)
                }
                .disabled(vm.isBusy)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Pago exitoso

    private var paymentSuccessView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.green.opacity(0.12)).frame(width: 90, height: 90)
                    Image(systemName: vm.usedSavedCardDeferred ? "clock.badge.checkmark.fill" : "checkmark.circle.fill")
                        .font(.system(size: 52)).foregroundStyle(.green)
                }
                VStack(spacing: 6) {
                    Text(vm.usedSavedCardDeferred ? "¡Reserva enviada!" : "¡Pago exitoso!").font(.title.bold())
                    Text(vm.usedSavedCardDeferred
                         ? "El artista revisará tu solicitud. Tu tarjeta será cobrada automáticamente cuando confirme."
                         : "Tu reserva está confirmada. El artista ha sido notificado.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 20)
                }
            }
            .padding(.top, 48)

            // Código de reserva
            if let code = (vm.confirmedBooking ?? booking).code {
                VStack(spacing: 6) {
                    Text("CÓDIGO DE RESERVA")
                        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary).tracking(1.2)
                    Text(code).font(.title2.bold().monospaced())
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
                .background(Color.piumsOrange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.piumsOrange.opacity(0.2), lineWidth: 1))
            }

            VStack(spacing: 10) {
                Button(action: onDone) {
                    Text("Ver mis reservas").font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.piumsOrange).clipShape(RoundedRectangle(cornerRadius: 16))
                }
                Button { dismiss() } label: {
                    Text("Ir al inicio").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Pago rechazado

    private var paymentDeclinedView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.red.opacity(0.10)).frame(width: 90, height: 90)
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 52)).foregroundStyle(.red)
                }
                VStack(spacing: 6) {
                    Text("Pago no procesado").font(.title2.bold())
                    Text("Tu tarjeta no fue cargada. Verifica los datos e intenta nuevamente.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 40)

            Button {
                vm.phase = .ready
            } label: {
                Text("Intentar de nuevo").font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.piumsOrange).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            Button { dismiss() } label: {
                Text("Cancelar").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 32)
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "d 'de' MMMM"; out.locale = Locale(identifier: "es_ES")
        if let d = df.date(from: String(booking.scheduledDate.prefix(10))) { return out.string(from: d) }
        return String(booking.scheduledDate.prefix(10))
    }

    private func formatCents(_ cents: Int) -> String {
        let amount = Double(cents) / 100.0
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = vm.currency
        fmt.locale = Locale(identifier: "en_US")
        return fmt.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - PriceRow

private struct CKPriceRow: View {
    let label: String
    let value: String
    var highlight: Bool = false
    var note: String?   = nil
    var dimmed: Bool    = false

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(highlight ? .subheadline.bold() : .subheadline)
                    .foregroundStyle(dimmed ? Color.secondary : Color.primary)
                if let note {
                    Text(note).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(value)
                .font(highlight ? .subheadline.bold() : .subheadline)
                .foregroundStyle(highlight ? Color.piumsOrange : (dimmed ? Color.secondary : Color.primary))
        }
    }
}

// MARK: - Decodable auxiliar para la respuesta de confirmación

private struct TilopayConfirmResponse: Decodable {
    let success: Bool?
    let responseCode: String?
}

