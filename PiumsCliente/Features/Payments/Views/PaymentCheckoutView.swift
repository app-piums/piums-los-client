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

    private(set) var amountToPay: Int = 0
    private(set) var currency: String = "USD"

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

    func setup(booking: Booking) {
        currency    = booking.currency ?? "USD"
        amountToPay = (booking.anticipoRequired == true)
            ? (booking.anticipoAmount ?? booking.totalPrice)
            : booking.totalPrice
    }

    // MARK: - Iniciar pago

    func startPayment(booking: Booking, artist: Artist) async {
        phase = .loading
        let user = AuthManager.shared.currentUser
        let (billingFirst, billingLast) = splitName(user?.nombre)
        do {
            let wrapper: PaymentIntentWrapper = try await APIClient.request(
                .createPaymentIntent(
                    bookingId:    booking.id,
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
        if params.isApproved {
            phase = .processing
            Task { await confirmAndPoll(params: params) }
        } else {
            phase = .declined
        }
    }

    private func confirmAndPoll(params: TilopayCallbackParams) async {
        // Confirmar en el backend (no bloquea aunque falle)
        do {
            let _: TilopayConfirmResponse = try await APIClient.request(
                .confirmTilopayRedirect(
                    bookingId:    params.bookingId,
                    responseCode: params.responseCode,
                    orderNumber:  params.orderNumber,
                    amount:       params.amount,
                    auth:         params.auth,
                    currency:     params.currency,
                    orderHash:    params.orderHash
                )
            )
        } catch {}

        // Sondear cada 3s hasta que paymentStatus refleje el pago
        await pollUntilPaid(bookingId: params.bookingId)
    }

    private func pollUntilPaid(bookingId: String, attempt: Int = 0) async {
        guard attempt < 10 else { phase = .confirmed; return }
        do {
            try await Task.sleep(for: .seconds(3))
            let booking: Booking = try await APIClient.request(.getBooking(id: bookingId))
            let paid = booking.paymentStatus == .anticipoPaid
                    || booking.paymentStatus == .fullyPaid
                    || booking.paymentStatus == .completed
            if paid {
                confirmedBooking = booking
                phase = .confirmed
            } else {
                await pollUntilPaid(bookingId: bookingId, attempt: attempt + 1)
            }
        } catch {
            phase = .confirmed
        }
    }
}

// MARK: - Vista principal

struct PaymentCheckoutView: View {
    let booking: Booking
    let artist: Artist
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
        .onAppear { vm.setup(booking: booking) }
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
                    CKPriceRow(label: "Servicio", value: formatCents(booking.totalPrice))
                    CKPriceRow(label: "Anticipo (50%)", value: formatCents(anticipo), highlight: true)
                    CKPriceRow(label: "Saldo restante", value: formatCents(rest),
                               note: "Se cobra automáticamente 72h antes", dimmed: true)
                } else {
                    CKPriceRow(label: "Servicio", value: formatCents(booking.totalPrice))
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

            // Botón de pago
            Button {
                Task { await vm.startPayment(booking: booking, artist: artist) }
            } label: {
                HStack(spacing: 8) {
                    if vm.isBusy {
                        ProgressView().tint(.white).scaleEffect(0.85)
                        Text("Iniciando...").font(.headline)
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

    // MARK: - Pago exitoso

    private var paymentSuccessView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.green.opacity(0.12)).frame(width: 90, height: 90)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52)).foregroundStyle(.green)
                }
                VStack(spacing: 6) {
                    Text("¡Pago exitoso!").font(.title.bold())
                    Text("Tu reserva está confirmada. El artista ha sido notificado.")
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
                Task { await vm.startPayment(booking: booking, artist: artist) }
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
