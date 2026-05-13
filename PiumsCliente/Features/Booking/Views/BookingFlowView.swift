// BookingFlowView.swift — 4 pasos reales: Servicio → Fecha/Hora → Detalles → Resumen
import SwiftUI
import CoreLocation
import MapKit

// Haversine distance (km) between two coordinates
private func haversineKm(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
    let R = 6371.0
    let dLat = (lat2 - lat1) * .pi / 180
    let dLon = (lon2 - lon1) * .pi / 180
    let a = sin(dLat/2)*sin(dLat/2) + cos(lat1 * .pi/180)*cos(lat2 * .pi/180)*sin(dLon/2)*sin(dLon/2)
    return R * 2 * atan2(sqrt(a), sqrt(1-a))
}

// Coordenadas aproximadas por ciudad (fallback cuando el artista no tiene coords exactas)
private let ARTIST_CITY_COORDS: [String: (Double, Double)] = [
    "Guatemala":              (14.6349, -90.5069),
    "Ciudad de Guatemala":    (14.6349, -90.5069),
    "Antigua Guatemala":      (14.5586, -90.7295),
    "Antigua":                (14.5586, -90.7295),
    "Quetzaltenango":         (14.8444, -91.5183),
    "Cobán":                  (15.4736, -90.3789),
    "Escuintla":              (14.3057, -90.7861),
    "Huehuetenango":          (15.3197, -91.4737),
    "Flores":                 (16.9328, -89.8929),
    "Chiquimula":             (14.7981, -89.5433),
    "Zacapa":                 (14.9717, -89.5344),
    "Jalapa":                 (14.6339, -89.9881),
    "Jutiapa":                (14.2934, -89.8964),
    "Santa Rosa":             (14.2800, -90.2750),
    "Retalhuleu":             (14.5397, -91.6864),
    "San Marcos":             (14.9658, -91.7953),
    "Totonicapán":            (14.9108, -91.3606),
    "Sololá":                 (14.7764, -91.1822),
    "Chimaltenango":          (14.6631, -90.8197),
    "Sacatepéquez":           (14.5586, -90.7295),
    "El Progreso":            (14.9428, -89.8650),
    "Baja Verapaz":           (15.1136, -90.1822),
    "Alta Verapaz":           (15.4736, -90.3789),
    "Izabal":                 (15.7356, -88.6014),
    "Petén":                  (16.9328, -89.8929),
]

enum BFlowStep: Int, CaseIterable {
    case service=0, datetime=1, details=2, review=3
    var label: String { ["Servicio","Fecha","Detalles","Resumen"][rawValue] }
}

// MARK: - ViewModel

@Observable @MainActor
final class BookingFlowViewModel {
    var context: BookingFlowContext
    var step: BFlowStep = .service
    var services: [ArtistService] = []
    var disabledDates: [Date] = []
    var slots: [TimeSlot] = []
    var isLoading = false
    var isSubmitting = false
    var priceQuote: PriceQuote?
    var priceError: String?
    var errorMessage: String?
    var bookingResult: Booking?
    var didComplete = false

    // Events
    var events: [EventSummary] = []
    var isLoadingEvents = false

    // Coupon
    var couponCode = ""
    var couponResult: CouponValidationResult?
    var isValidatingCoupon = false
    var couponError: String?

    var appliedDiscount: Int { couponResult?.valid == true ? (couponResult?.discount ?? 0) : 0 }
    var finalTotal: Int { (priceQuote?.totalCents ?? 0) - appliedDiscount }

    init(context: BookingFlowContext) { self.context = context }

    func loadServices() async {
        guard services.isEmpty else { return }
        isLoading = true; defer { isLoading = false }
        do {
            let res: _BFServicesRes = try await APIClient.request(.listServices(artistId: context.artist.id))
            services = res.services.filter { $0.status == "ACTIVE" && ($0.isAvailable ?? true) }
        } catch { errorMessage = AppError(from: error).errorDescription }
    }

    func loadEvents() async {
        guard events.isEmpty else { return }
        isLoadingEvents = true; defer { isLoadingEvents = false }
        do {
            let res: EventsResponse = try await APIClient.request(.listEvents)
            events = res.data.filter { $0.status != .cancelled }
        } catch {}
    }

    func loadCalendar() async {
        guard let date = context.selectedDate else { return }
        let cal = Calendar.current
        let yr = cal.component(.year, from: date), mo = cal.component(.month, from: date)
        do {
            let res: ArtistCalendar = try await APIClient.request(
                .getArtistCalendar(artistId: context.artist.id, year: yr, month: mo))
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            disabledDates = (res.occupiedDates + res.blockedDates).compactMap { f.date(from: $0) }
        } catch {}
    }

    func loadSlots(for date: Date) async {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        do {
            let res: TimeSlotsResponse = try await APIClient.request(
                .getAvailableSlots(artistId: context.artist.id, date: f.string(from: date)))
            slots = res.slots.filter { $0.available }
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func calculatePrice() async {
        guard let svc = context.service else { return }
        priceError = nil
        var payload: [String: Any] = ["serviceId": svc.id, "durationMinutes": context.durationMinutes]

        // Calcular distanceKm entre el cliente y la ciudad base del artista
        if let clientLat = context.locationLat, let clientLng = context.locationLng {
            payload["locationLat"] = clientLat
            payload["locationLng"] = clientLng

            // Intentar coords exactas del artista, luego fallback por ciudad
            let artistLat: Double?
            let artistLng: Double?
            if let aLat = context.artist.baseLocationLat, let aLng = context.artist.baseLocationLng {
                artistLat = aLat; artistLng = aLng
            } else if let city = context.artist.city,
                      let cityCoords = ARTIST_CITY_COORDS[city] {
                artistLat = cityCoords.0; artistLng = cityCoords.1
            } else {
                artistLat = nil; artistLng = nil
            }
            if let aLat = artistLat, let aLng = artistLng {
                let distKm = haversineKm(clientLat, clientLng, aLat, aLng)
                payload["distanceKm"] = distKm
            }
        }

        if context.isMultiDay { payload["numDays"] = context.numDays }
        do {
            priceQuote = try await APIClient.request(.calculatePrice(payload: payload))
            context.priceQuote = priceQuote
        } catch {
            print("💰 calculatePrice error (\(type(of: error))): \(error)")
            print("💰 payload was: \(payload)")
            priceQuote = buildLocalQuote(svc: svc, distanceKm: payload["distanceKm"] as? Double)
            context.priceQuote = priceQuote
            priceError = "Precio estimado"
        }
    }

    // Mirrors backend pricing.service.ts logic for offline fallback
    // - 10 km included; Q20/km per extra km (single day)
    // - Multi-day: Q150/day food + Q400/day lodging + Q200 flat transport
    func buildLocalQuote(svc: ArtistService, distanceKm: Double?) -> PriceQuote {
        let baseCents = svc.basePrice
        var travelCents = 0

        if let dist = distanceKm, dist > 10 {
            if context.isMultiDay {
                // Q550/day (food+lodging) + Q200 flat transport
                travelCents = (context.numDays * 55_000) + 20_000
            } else {
                // Q20 per extra km
                travelCents = Int((dist - 10) * 2_000)
            }
        }

        var items: [PriceQuoteItem] = [
            PriceQuoteItem(type: "BASE", name: svc.name, qty: 1,
                           unitPriceCents: baseCents, totalPriceCents: baseCents, metadata: nil)
        ]
        if travelCents > 0 {
            items.append(PriceQuoteItem(
                type: "TRAVEL",
                name: context.isMultiDay ? "Viáticos" : "Traslado",
                qty: context.isMultiDay ? context.numDays : 1,
                unitPriceCents: nil,
                totalPriceCents: travelCents,
                metadata: nil
            ))
        }

        let total = baseCents + travelCents
        return PriceQuote(
            serviceId: svc.id,
            currency: svc.currency,
            items: items,
            subtotalCents: total,
            totalCents: total,
            breakdown: PriceQuoteBreakdown(
                baseCents: baseCents,
                addonsCents: 0,
                travelCents: travelCents,
                discountsCents: nil
            )
        )
    }

    func validateCoupon(clientId: String) async {
        let trimmed = couponCode.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmed.isEmpty else { return }
        isValidatingCoupon = true
        couponError = nil
        couponResult = nil
        defer { isValidatingCoupon = false }
        let payload: [String: Any] = [
            "code": trimmed,
            "userId": clientId,
            "bookingId": "",
            "bookingTotal": priceQuote?.totalCents ?? 0,
            "artistId": context.artist.id,
            "serviceId": context.service?.id ?? ""
        ]
        do {
            let result: CouponValidationResult = try await APIClient.request(.validateCoupon(payload: payload))
            couponResult = result
            if !result.valid { couponError = result.error ?? "Cupón no válido" }
        } catch {
            couponError = AppError(from: error).errorDescription ?? "Error al validar el cupón"
        }
    }

    func clearCoupon() {
        couponCode = ""
        couponResult = nil
        couponError = nil
    }

    func submitBooking(clientId: String) async {
        guard let isoDate = context.scheduledDateISO else { errorMessage = "Selecciona fecha y hora."; return }
        guard let svc = context.service else { errorMessage = "Selecciona un servicio."; return }
        isSubmitting = true; errorMessage = nil; defer { isSubmitting = false }
        var payload: [String: Any] = [
            "artistId": context.artist.id, "serviceId": svc.id, "clientId": clientId,
            "scheduledDate": isoDate, "durationMinutes": context.durationMinutes,
        ]
        if !context.location.isEmpty          { payload["location"] = context.location }
        if let lat = context.locationLat      { payload["locationLat"] = lat }
        if let lng = context.locationLng      { payload["locationLng"] = lng }
        if !context.clientNotes.isEmpty       { payload["clientNotes"] = context.clientNotes }
        if let eventId = context.eventId      { payload["eventId"] = eventId }
        if let et = context.eventType         { payload["eventType"] = et.rawValue }
        if !context.selectedAddons.isEmpty    { payload["selectedAddons"] = context.selectedAddons }
        if couponResult?.valid == true {
            let trimmed = couponCode.trimmingCharacters(in: .whitespaces).uppercased()
            if !trimmed.isEmpty { payload["couponCode"] = trimmed }
        }
        do {
            bookingResult = try await APIClient.request(.createBooking(payload: payload))
            didComplete = true
        } catch { errorMessage = AppError(from: error).errorDescription }
    }

    func next() { if let n = BFlowStep(rawValue: step.rawValue+1) { withAnimation { step = n } } }
    func back() { if let p = BFlowStep(rawValue: step.rawValue-1) { withAnimation { step = p } } }
}

private struct _BFServicesRes: Codable { let services: [ArtistService] }

// MARK: - BookingFlowView

struct BookingFlowView: View {
    var context: BookingFlowContext
    @State private var vm: BookingFlowViewModel
    @State private var showConfirmModal = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locationStore) private var locationStore

    private var locationCoordBinding: Binding<CLLocationCoordinate2D?> {
        Binding {
            guard let lat = vm.context.locationLat, let lng = vm.context.locationLng else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } set: { coord in
            vm.context.locationLat = coord?.latitude
            vm.context.locationLng = coord?.longitude
        }
    }

    init(context: BookingFlowContext) {
        self.context = context
        _vm = State(initialValue: BookingFlowViewModel(context: context))
    }

    var body: some View {
        VStack(spacing: 0) {
            stepBar
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch vm.step {
                    case .service:  serviceStep
                    case .datetime: datetimeStep
                    case .details:  detailsStep
                    case .review:   reviewStep
                    }
                }
                .padding(20).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            bottomBar
        }
        .navigationTitle("Reservar Servicio")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbarBackground(Color(.secondarySystemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { if vm.step == .service { dismiss() } else { vm.back() } } label: {
                    HStack(spacing:4) {
                        Image(systemName: "chevron.left")
                        Text(vm.step == .service ? "Cancelar" : "Atrás")
                    }.foregroundStyle(Color.piumsOrange)
                }
            }
        }
        .task { await vm.loadServices() }
        .onAppear {
            // Pre-fill location coords from shared store if not already set
            if vm.context.locationLat == nil, let coord = locationStore.coordinate {
                vm.context.locationLat = coord.latitude
                vm.context.locationLng = coord.longitude
                if vm.context.location.isEmpty { vm.context.location = locationStore.cityName }
            }
            // If already on review step and coords just arrived, recalculate
            if vm.step == .review, vm.context.locationLat != nil {
                Task { await vm.calculatePrice() }
            }
            // Keep requesting if we still don't have location
            if locationStore.coordinate == nil { locationStore.requestIfNeeded() }
        }
        .onChange(of: vm.context.locationLat) { _, newLat in
            guard vm.step == .review, newLat != nil else { return }
            Task { await vm.calculatePrice() }
        }
        .onChange(of: vm.context.numDays) { _, _ in
            guard vm.step == .review else { return }
            Task { await vm.calculatePrice() }
        }
        .onChange(of: vm.step) { _, newStep in
            if newStep == .details { Task { await vm.loadEvents() } }
        }
        .onChange(of: locationStore.coordinate?.latitude) { _, _ in
            guard let coord = locationStore.coordinate else { return }
            if vm.context.locationLat == nil {
                vm.context.locationLat = coord.latitude
                vm.context.locationLng = coord.longitude
                if vm.context.location.isEmpty { vm.context.location = locationStore.cityName }
            }
        }
        .sheet(isPresented: $showConfirmModal) {
            BookingConfirmModalView(vm: vm) {
                showConfirmModal = false
                guard let id = AuthManager.shared.currentUser?.id else { return }
                Task { await vm.submitBooking(clientId: id) }
            } onCancel: {
                showConfirmModal = false
            }
            .presentationDetents([.height(580)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
            .presentationBackground(Color(.systemBackground))
        }
        .sheet(isPresented: Binding(get: { vm.didComplete }, set: { if !$0 { dismiss() } })) {
            BookingSuccessView(booking: vm.bookingResult, artist: context.artist) {
                NotificationCenter.default.post(name: .navigateToMySpace, object: nil)
                dismiss()
            }
        }
    }

    // MARK: Step bar

    private var stepBar: some View {
        HStack(spacing: 0) {
            ForEach(BFlowStep.allCases, id: \.rawValue) { s in
                HStack(spacing: 0) {
                    VStack(spacing: 3) {
                        ZStack {
                            Circle().fill(s.rawValue <= vm.step.rawValue ? Color.piumsOrange : Color(.tertiarySystemBackground))
                                .frame(width: 28, height: 28)
                            if s.rawValue < vm.step.rawValue {
                                Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                            } else {
                                Text("\(s.rawValue+1)").font(.caption.bold())
                                    .foregroundStyle(s.rawValue <= vm.step.rawValue ? .white : .secondary)
                            }
                        }
                        Text(s.label).font(.system(size: 9, weight: .medium))
                            .foregroundStyle(s == vm.step ? Color.piumsOrange : .secondary)
                    }
                    if s != BFlowStep.allCases.last {
                        Rectangle().fill(s.rawValue < vm.step.rawValue ? Color.piumsOrange : Color(.tertiarySystemBackground))
                            .frame(maxWidth: .infinity).frame(height: 2).padding(.bottom, 16)
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if let q = vm.priceQuote {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Total").font(.caption2).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            if vm.appliedDiscount > 0 {
                                Text(q.totalCents.piumsFormatted)
                                    .font(.caption)
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                            }
                            Text(vm.finalTotal.piumsFormatted)
                                .font(.title3.bold())
                                .foregroundStyle(vm.appliedDiscount > 0 ? .green : Color.piumsOrange)
                        }
                    }
                }
                Spacer()
                Button(action: handleNext) {
                    HStack(spacing: 5) {
                        if vm.isSubmitting { ProgressView().tint(.white) }
                        Text(vm.step == .review ? "Confirmar" : "Continuar").font(.subheadline.bold())
                        if vm.step != .review { Image(systemName: "chevron.right").font(.caption.bold()) }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(canProceed ? Color.piumsOrange : Color(.systemGray4))
                    .clipShape(Capsule())
                }
                .disabled(!canProceed || vm.isSubmitting)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(.bar)
    }

    private var canProceed: Bool {
        switch vm.step {
        case .service:  return vm.context.service != nil
        case .datetime: return vm.context.selectedDate != nil && vm.context.selectedSlot != nil
        case .details:  return true
        case .review:   return !vm.isSubmitting
        }
    }

    private func handleNext() {
        if vm.step == .review {
            showConfirmModal = true
        } else {
            vm.next()
            if vm.step == .datetime { Task { await vm.loadCalendar(); if let d = vm.context.selectedDate { await vm.loadSlots(for: d) } } }
            if vm.step == .review {
                // Make sure we have the latest coords before calculating price
                if vm.context.locationLat == nil, let coord = locationStore.coordinate {
                    vm.context.locationLat = coord.latitude
                    vm.context.locationLng = coord.longitude
                    if vm.context.location.isEmpty { vm.context.location = locationStore.cityName }
                }
                Task { await vm.calculatePrice() }
            }
        }
    }

    // MARK: Step 1 — Servicio

    private var serviceStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            header("Selecciona un Servicio", sub: "Elige el servicio para tu evento.")
            if vm.isLoading {
                ForEach(0..<3, id:\.self) { _ in
                    RoundedRectangle(cornerRadius: 16).fill(Color(.tertiarySystemGroupedBackground))
                        .frame(height: 90).redacted(reason: .placeholder)
                }
            } else {
                ForEach(vm.services) { svc in
                    BFSvcCard(
                        service: svc,
                        artist: vm.context.artist,
                        isSelected: vm.context.service?.id == svc.id
                    ) { vm.context.service = svc }
                }
            }
            if let e = vm.errorMessage { ErrorBannerView(message: e) }
        }
    }

    // MARK: Step 2 — Fecha/Hora

    private var datetimeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            header("Fecha y Hora", sub: "Elige el día del evento y el horario.")
            BFCalendarView(disabled: vm.disabledDates, selected: $vm.context.selectedDate) { d in
                Task { await vm.loadSlots(for: d) }
            }
            if !vm.slots.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Horarios disponibles").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 85))], spacing: 8) {
                        ForEach(vm.slots) { s in
                            Button { vm.context.selectedSlot = s } label: {
                                Text(s.time).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(vm.context.selectedSlot?.time == s.time ? Color.piumsOrange : Color(.tertiarySystemGroupedBackground))
                                    .foregroundStyle(vm.context.selectedSlot?.time == s.time ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $vm.context.isMultiDay) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Evento multi-día").font(.subheadline.weight(.semibold))
                        Text("El evento se extiende por más de un día.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tint(.piumsOrange)
                .onChange(of: vm.context.isMultiDay) { _, on in
                    if on && vm.context.numDays < 2 { vm.context.numDays = 2 }
                    if !on { vm.context.numDays = 1 }
                }
                if vm.context.isMultiDay {
                    Divider()
                    HStack {
                        Text("Duración del evento")
                            .font(.subheadline)
                        Spacer()
                        HStack(spacing: 14) {
                            Button {
                                if vm.context.numDays > 2 { vm.context.numDays -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(vm.context.numDays <= 2 ? Color(.systemGray4) : Color.piumsOrange)
                            }
                            .disabled(vm.context.numDays <= 2)
                            Text("\(vm.context.numDays) días")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.piumsOrange)
                                .frame(minWidth: 52)
                                .multilineTextAlignment(.center)
                            Button {
                                if vm.context.numDays < 30 { vm.context.numDays += 1 }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.piumsOrange)
                            }
                            .disabled(vm.context.numDays >= 30)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: Step 3 — Detalles

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            header("Detalles del Evento", sub: "Ubicación e indicaciones especiales.")
            VStack(alignment: .leading, spacing: 10) {
                Label("Ubicación del Evento", systemImage: "mappin.circle.fill").font(.headline)
                LocationSearchField(
                    placeholder: "Ej. Salón Los Jardines, Zona 15",
                    text: $vm.context.location,
                    coordinate: locationCoordBinding
                )
                Button {
                    if let coord = locationStore.coordinate {
                        vm.context.locationLat = coord.latitude
                        vm.context.locationLng = coord.longitude
                        if vm.context.location.isEmpty { vm.context.location = locationStore.cityName }
                    } else {
                        locationStore.refresh()
                    }
                } label: {
                    Label(vm.context.locationLat != nil ? "Ubicación detectada" : "Usar mi ubicación",
                          systemImage: vm.context.locationLat != nil ? "location.fill" : "location")
                        .font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(Color(.tertiarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(vm.context.locationLat != nil ? .green : Color.piumsOrange)
                }.buttonStyle(.plain)
                .onChange(of: locationStore.coordinate?.latitude) { _, _ in
                    if vm.context.locationLat == nil, let coord = locationStore.coordinate {
                        vm.context.locationLat = coord.latitude
                        vm.context.locationLng = coord.longitude
                        if vm.context.location.isEmpty { vm.context.location = locationStore.cityName }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Label("Notas para el artista", systemImage: "note.text").font(.headline)
                TextEditor(text: $vm.context.clientNotes)
                    .frame(minHeight: 90).padding(10)
                    .background(Color(.tertiarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            eventPickerSection
        }
    }

    // MARK: - Event picker

    private var eventPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Label("Asociar a un Evento", systemImage: "calendar.badge.plus").font(.headline)
                Text("(Opcional)").font(.subheadline).foregroundStyle(.secondary)
            }
            if vm.isLoadingEvents {
                HStack { ProgressView().scaleEffect(0.8); Text("Cargando eventos…").font(.subheadline).foregroundStyle(.secondary) }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if vm.events.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark").foregroundStyle(.secondary)
                    Text("No tienes eventos activos.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let selectedId = vm.context.eventId,
                      let ev = vm.events.first(where: { $0.id == selectedId }) {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.circle.fill")
                        .font(.title3).foregroundStyle(Color.piumsOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ev.name).font(.subheadline.bold())
                        Text("\(ev.status.displayName) · \((ev.bookings ?? []).count) reservas")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        vm.context.eventId = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color(.tertiaryLabel))
                    }
                }
                .padding(12)
                .background(Color.piumsOrange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.piumsOrange.opacity(0.25), lineWidth: 1))
            } else {
                Menu {
                    Button("Sin evento") { vm.context.eventId = nil }
                    Divider()
                    ForEach(vm.events) { ev in
                        Button {
                            vm.context.eventId = ev.id
                        } label: {
                            Label("\(ev.name) · \(ev.status.displayName)", systemImage: "calendar")
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.plus").foregroundStyle(Color.piumsOrange)
                        Text("Seleccionar evento…").foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(Color(.tertiaryLabel))
                    }
                    .font(.subheadline)
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Step 4 — Resumen

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            header("Resumen de Reserva", sub: "Revisa los detalles antes de confirmar.")
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.piumsOrange.opacity(0.12)).frame(width: 44, height: 44)
                    Text(String(vm.context.artist.artistName.prefix(2)).uppercased()).font(.subheadline.bold()).foregroundStyle(Color.piumsOrange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.context.artist.artistName).font(.headline)
                    Text(vm.context.service?.name ?? "").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14).background(Color(.tertiarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 14))

            detailRows

            if let q = vm.priceQuote {
                priceView(q)
            } else {
                ProgressView("Calculando precio…")
            }
            couponSection
            if let e = vm.errorMessage { ErrorBannerView(message: e) }
        }
    }

    // MARK: - Coupon section

    private var couponSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("¿Tienes un cupón?").font(.headline)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "tag.fill").foregroundStyle(Color.piumsOrange).font(.subheadline)
                    TextField("Código de cupón", text: $vm.couponCode)
                        .textCase(.uppercase)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .onChange(of: vm.couponCode) { _, _ in
                            if vm.couponResult != nil { vm.clearCoupon() }
                        }
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if vm.couponResult?.valid == true {
                    Button { vm.clearCoupon() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.title3)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        guard let uid = AuthManager.shared.currentUser?.id else { return }
                        Task { await vm.validateCoupon(clientId: uid) }
                    } label: {
                        Group {
                            if vm.isValidatingCoupon {
                                ProgressView().tint(.white)
                            } else {
                                Text("Aplicar").font(.subheadline.bold())
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(vm.couponCode.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color(.systemGray4) : Color.piumsOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.couponCode.trimmingCharacters(in: .whitespaces).isEmpty || vm.isValidatingCoupon)
                }
            }

            if let result = vm.couponResult, result.valid {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Cupón aplicado: \(result.coupon?.discountLabel ?? "")").font(.subheadline.bold()).foregroundStyle(.green)
                        if let name = result.coupon?.name {
                            Text(name).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("-\(result.discount.piumsFormatted)").font(.subheadline.bold()).foregroundStyle(.green)
                }
                .padding(12)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let err = vm.couponError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var detailRows: some View {
        VStack(spacing: 1) {
            if let d = vm.context.selectedDate, let s = vm.context.selectedSlot {
                let f = buildDateFormatter()
                reviewRow("calendar", "Fecha", f.string(from: d).capitalized)
                reviewRow("clock", "Hora", s.time)
            }
            if vm.context.isMultiDay { reviewRow("calendar.badge.plus", "Días", "\(vm.context.numDays) días") }
            if !vm.context.location.isEmpty { reviewRow("mappin.circle", "Lugar", vm.context.location) }
            if !vm.context.clientNotes.isEmpty { reviewRow("note.text", "Notas", vm.context.clientNotes) }
        }
        .background(Color(.tertiarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func buildDateFormatter() -> DateFormatter {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMM yyyy"; f.locale = Locale(identifier: "es_ES"); return f
    }

    private func reviewRow(_ icon: String, _ lbl: String, _ val: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(Color.piumsOrange).frame(width: 20)
            Text(lbl).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(val).font(.subheadline.weight(.medium)).multilineTextAlignment(.trailing).lineLimit(2)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func priceView(_ q: PriceQuote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Desglose de Precio").font(.headline)

            // If no location yet, show an actionable nudge
            if vm.context.locationLat == nil {
                Button {
                    if let coord = locationStore.coordinate {
                        vm.context.locationLat = coord.latitude
                        vm.context.locationLng = coord.longitude
                        if vm.context.location.isEmpty { vm.context.location = locationStore.cityName }
                        Task { await vm.calculatePrice() }
                    } else {
                        locationStore.refresh()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "location.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.piumsOrange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Agrega tu ubicación")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Necesaria para calcular el costo de traslado del artista.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if locationStore.isLocating {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.piumsOrange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.piumsOrange.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .onChange(of: locationStore.coordinate?.latitude) { _, _ in
                    guard let coord = locationStore.coordinate, vm.context.locationLat == nil else { return }
                    vm.context.locationLat = coord.latitude
                    vm.context.locationLng = coord.longitude
                    if vm.context.location.isEmpty { vm.context.location = locationStore.cityName }
                    Task { await vm.calculatePrice() }
                }
            }

            VStack(spacing: 8) {
                ForEach(q.items, id: \.type) { item in
                    if item.type == "TRAVEL" && vm.context.locationLat == nil { EmptyView() }
                    else {
                        HStack(alignment: .center) {
                            HStack(spacing: 6) {
                                if item.type == "TRAVEL" {
                                    Image(systemName: "car.fill").foregroundStyle(.orange)
                                    if vm.context.isMultiDay, let unit = item.unitPriceCents, unit > 0 {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Viáticos (\(vm.context.numDays) días)").font(.subheadline)
                                            Text("\(unit.piumsFormatted) / día").font(.caption).foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text(item.name).font(.subheadline)
                                    }
                                } else {
                                    Text(item.name).font(.subheadline)
                                }
                            }
                            Spacer()
                            Text(item.totalPriceCents.piumsFormatted).font(.subheadline.bold())
                                .foregroundStyle(item.type == "TRAVEL" ? .orange : .primary)
                        }
                    }
                }
                Divider()
                HStack {
                    Text("Total").font(.headline)
                    Spacer()
                    Text(q.totalCents.piumsFormatted).font(.title3.bold()).foregroundStyle(Color.piumsOrange)
                }
            }
            .padding(14).background(Color(.tertiarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 14))

            if q.hasTravel {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundStyle(.orange)
                    Text(vm.context.isMultiDay
                         ? "Los viáticos cubren transporte, hospedaje y alimentación del artista por los \(vm.context.numDays) días del evento."
                         : "Los viáticos cubren transporte, alimentación y hospedaje del artista.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(12).background(Color.orange.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if let pe = vm.priceError { Text(pe).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func header(_ t: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t).font(.title2.bold())
            Text(sub).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

// MARK: - BFSvcCard

private struct BFSvcCard: View {
    let service: ArtistService
    let artist: Artist
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isExpanded = false
    @State private var showArtistProfile = false

    private var includes: [String] { service.whatIsIncluded ?? [] }

    private func icon() -> String {
        let n = service.name.lowercased()
        if n.contains("boda")   { return "heart.fill" }
        if n.contains("foto")   { return "camera.fill" }
        if n.contains("quince") { return "sparkles" }
        if n.contains("coord") || n.contains("asesor") { return "calendar.badge.checkmark" }
        return "music.note"
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Fila principal — selecciona el servicio ──────────────
            Button(action: onTap) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.piumsOrange : Color.piumsOrange.opacity(0.10))
                            .frame(width: 44, height: 44)
                        Image(systemName: icon())
                            .font(.title3)
                            .foregroundStyle(isSelected ? .white : Color.piumsOrange)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(service.name).font(.subheadline.bold()).lineLimit(1)
                        if let d = service.description {
                            Text(d).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(service.basePrice.piumsFormatted)
                            .font(.headline.bold()).foregroundStyle(Color.piumsOrange)
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.piumsOrange)
                        }
                    }
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // ── Toggle despliegue ────────────────────────────────────
            Divider().padding(.horizontal, 14)
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(isExpanded ? "Ocultar detalles" : "Ver detalles")
                        .font(.caption.weight(.medium))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Color.piumsOrange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            // ── Contenido expandido ──────────────────────────────────
            if isExpanded {
                Divider().padding(.horizontal, 14)
                VStack(alignment: .leading, spacing: 14) {

                    // Qué incluye
                    if !includes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Qué incluye")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(includes, id: \.self) { item in
                                HStack(alignment: .top, spacing: 7) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.piumsOrange)
                                        .padding(.top, 1)
                                    Text(item).font(.caption)
                                }
                            }
                        }
                    }

                    // Botón ver perfil del artista
                    Button { showArtistProfile = true } label: {
                        HStack(spacing: 10) {
                            AsyncImage(url: URL(string: artist.avatar ?? "")) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(artist.name).font(.caption.weight(.semibold))
                                if let spec = artist.specialties?.first {
                                    Text(spec).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Label("Ver perfil", systemImage: "arrow.right")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.piumsOrange)
                        }
                        .padding(10)
                        .background(Color.piumsOrange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.tertiarySystemGroupedBackground))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.piumsOrange : Color.clear, lineWidth: 2))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .sheet(isPresented: $showArtistProfile) {
            NavigationStack {
                ArtistProfileView(artist: artist)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cerrar") { showArtistProfile = false }
                                .foregroundStyle(Color.piumsOrange)
                        }
                    }
            }
        }
    }
}

// MARK: - BFCalendarView

private struct BFCalendarView: View {
    let disabled: [Date]
    @Binding var selected: Date?
    let onSelect: (Date) -> Void
    @State private var display = Date()
    private let cal = Calendar.current
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let wdays = ["L","M","X","J","V","S","D"]

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(monthLabel).font(.headline.bold())
                Spacer()
                Button { change(-1) } label: { Image(systemName: "chevron.left").foregroundStyle(Color.piumsOrange) }
                Button { change(1)  } label: { Image(systemName: "chevron.right").foregroundStyle(Color.piumsOrange) }
            }
            HStack(spacing: 0) {
                ForEach(wdays, id: \.self) { Text($0).font(.caption.bold()).foregroundStyle(.secondary).frame(maxWidth: .infinity) }
            }
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(days, id: \.self) { day in
                    let isOff = isDisabled(day)
                    let isPast = day < cal.startOfDay(for: Date())
                    let isCurrent = cal.component(.month, from: day) == cal.component(.month, from: display)
                    let isSel = selected.map { cal.isDate(day, inSameDayAs: $0) } ?? false
                    Button {
                        guard !isOff && !isPast && isCurrent else { return }
                        selected = day; onSelect(day)
                    } label: {
                        ZStack {
                            if isSel      { Circle().fill(Color.piumsOrange) }
                            else if isOff { Circle().fill(Color.red.opacity(0.08)) }
                            Text("\(cal.component(.day, from: day))")
                                .font(.system(size: 13, weight: isSel ? .bold : .regular))
                                .foregroundStyle(isSel ? .white : isOff ? Color.red.opacity(0.5) : isPast || !isCurrent ? Color(.systemGray4) : .primary)
                        }
                        .frame(height: 34)
                    }
                    .buttonStyle(.plain).disabled(isOff || isPast || !isCurrent)
                }
            }
        }
        .padding(14).background(Color(.tertiarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var monthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.locale = Locale(identifier: "es_ES")
        return f.string(from: display).capitalized
    }
    private func change(_ d: Int) {
        if let n = cal.date(byAdding: .month, value: d, to: display) { withAnimation { display = n } }
    }
    private func isDisabled(_ d: Date) -> Bool { disabled.contains { cal.isDate($0, inSameDayAs: d) } }
    private var days: [Date] {
        guard let start = cal.date(from: cal.dateComponents([.year,.month], from: display)),
              let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        let wd = cal.component(.weekday, from: start); let off = (wd-2+7)%7
        return (-off..<(range.count + (7-(range.count+off)%7)%7)).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }
}

// MARK: - BookingConfirmModalView

struct BookingConfirmModalView: View {
    let vm: BookingFlowViewModel
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var dateLabel: String {
        guard let d = vm.context.selectedDate else { return "—" }
        let f = DateFormatter(); f.dateFormat = "EEEE d 'de' MMMM"; f.locale = Locale(identifier: "es_ES")
        return f.string(from: d).capitalized
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule().fill(Color(.systemGray4)).frame(width: 36, height: 4).padding(.top, 14).padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Confirmar Reserva")
                        .font(.title2.bold())
                    Rectangle()
                        .fill(Color.piumsOrange)
                        .frame(width: 40, height: 3)
                        .clipShape(Capsule())
                }

                // Artista card
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.piumsOrange.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Text(String(vm.context.artist.artistName.prefix(2)).uppercased())
                            .font(.title3.bold()).foregroundStyle(Color.piumsOrange)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ARTISTA").font(.caption2.weight(.semibold)).foregroundStyle(.secondary).tracking(0.8)
                        Text(vm.context.artist.artistName).font(.title3.bold())
                        if let specialties = vm.context.artist.specialties?.first {
                            Text(specialties).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.piumsOrange.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Detalles
                VStack(spacing: 0) {
                    confirmRow(icon: "sparkles", label: "Servicio", value: vm.context.service?.name ?? "—")
                    Divider().padding(.leading, 44)
                    confirmRow(icon: "calendar", label: "Fecha", value: dateLabel)
                    Divider().padding(.leading, 44)
                    confirmRow(icon: "clock", label: "Hora", value: vm.context.selectedSlot?.time ?? "—")
                    if vm.context.isMultiDay {
                        Divider().padding(.leading, 44)
                        confirmRow(icon: "calendar.badge.plus", label: "Días", value: "\(vm.context.numDays) días")
                    }
                    if let q = vm.priceQuote {
                        Divider().padding(.leading, 44)
                        confirmRow(icon: "banknote", label: "Total", value: q.totalCents.piumsFormatted, highlight: true)
                    }
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Aviso legal
                Text("Al confirmar, aceptas nuestras políticas de cancelación y términos de servicio. El cargo se realizará de forma inmediata.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                // Botones
                VStack(spacing: 10) {
                    Button(action: onConfirm) {
                        Text("Sí, confirmar")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.piumsOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    Button(action: onCancel) {
                        Text("Cancelar")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.piumsOrange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
    }

    private func confirmRow(icon: String, label: String, value: String, highlight: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.piumsOrange)
                .frame(width: 20)
                .padding(.leading, 12)
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(highlight ? .title3.bold() : .subheadline.weight(.semibold))
                .foregroundStyle(highlight ? Color.piumsOrange : .primary)
                .padding(.trailing, 12)
        }
        .padding(.vertical, 13)
    }
}

struct BookingSuccessView: View {
    let booking: Booking?
    let artist: Artist
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showCheckout = false

    private var paymentPending: Bool {
        booking?.paymentStatus == .pending
    }

    private var formattedDate: String {
        guard let dateStr = booking?.scheduledDate else { return "—" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()
        guard let date = iso.date(from: dateStr) ?? iso2.date(from: dateStr) else {
            // scheduledDate may just be "YYYY-MM-DD"
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            if let d = df.date(from: String(dateStr.prefix(10))) {
                let out = DateFormatter(); out.dateFormat = "d 'de' MMMM, yyyy"; out.locale = Locale(identifier: "es_ES")
                return out.string(from: d)
            }
            return dateStr
        }
        let f = DateFormatter(); f.dateFormat = "d 'de' MMMM, yyyy"; f.locale = Locale(identifier: "es_ES")
        return f.string(from: date)
    }

    private var formattedTime: String {
        guard let t = booking?.scheduledTime else { return "" }
        let df24 = DateFormatter()
        df24.dateFormat = t.count > 5 ? "HH:mm:ss" : "HH:mm"
        guard let date = df24.date(from: t) else { return t }
        let df12 = DateFormatter()
        df12.dateFormat = "h:mm a"
        return df12.string(from: date)
    }

    private var initials: String {
        artist.artistName.split(separator: " ").prefix(2)
            .compactMap { $0.first.map { String($0) } }.joined().uppercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // ── Check + Título ──────────────────────
                    VStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color.green.opacity(0.15)).frame(width: 88, height: 88)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50)).foregroundStyle(.green)
                        }
                        VStack(spacing: 6) {
                            Text("¡Reserva Confirmada!").font(.title.bold())
                            Text("Tu reserva ha sido creada exitosamente. El profesional revisará tu solicitud en breve.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center).padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 32)

                    // ── CTA de pago (si el pago está pendiente) ──────
                    if paymentPending, let b = booking {
                        PaymentCtaCard(
                            anticipoRequired: b.anticipoRequired ?? false,
                            anticipoAmount: b.anticipoAmount,
                            totalPrice: b.totalPrice,
                            currency: b.currency ?? "USD"
                        ) { showCheckout = true }
                    }

                    // ── Código de reserva ───────────────────
                    if let code = booking?.code {
                        VStack(spacing: 8) {
                            Text("CÓDIGO DE RESERVA")
                                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary).tracking(1.2)
                            Text(code).font(.title2.bold().monospaced())
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                        .background(Color.piumsOrange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.piumsOrange.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal, 24)
                    }

                    // ── Detalles del servicio ───────────────
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Detalles del Servicio").font(.headline)
                        Divider()

                        // Artista row
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.piumsOrange.opacity(0.15)).frame(width: 52, height: 52)
                                Text(initials).font(.subheadline.bold()).foregroundStyle(Color.piumsOrange)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(artist.artistName).font(.headline)
                                Text(artist.specialties?.first ?? "Artista")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }

                        // Info grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            SuccessInfoCell(label: "INFORMACIÓN DEL EVENTO") {
                                Text(formattedDate).font(.subheadline.bold())
                                if !formattedTime.isEmpty {
                                    Text(formattedTime).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            SuccessInfoCell(label: "UBICACIÓN") {
                                Text(booking?.location ?? "No especificada").font(.subheadline.bold())
                                Text("Modalidad Presencial").font(.caption).foregroundStyle(.secondary)
                            }
                            SuccessInfoCell(label: "ESTADO") {
                                HStack(spacing: 6) {
                                    Circle().fill(Color.orange).frame(width: 8, height: 8)
                                    Text(booking?.status.displayName.uppercased() ?? "PENDIENTE")
                                        .font(.caption.weight(.semibold))
                                }
                            }
                            SuccessInfoCell(label: "RESUMEN DE PAGO") {
                                if let b = booking, b.anticipoRequired == true, let anticipo = b.anticipoAmount {
                                    Text(anticipo.piumsFormatted)
                                        .font(.title3.bold()).foregroundStyle(Color.piumsOrange)
                                    Text("Anticipo · Total \(b.totalPrice.piumsFormatted)")
                                        .font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Text((booking?.totalPrice ?? 0).piumsFormatted)
                                        .font(.title3.bold()).foregroundStyle(Color.piumsOrange)
                                    if let discount = booking?.couponDiscountAmount, discount > 0,
                                       let code = booking?.couponCode {
                                        Label("\(code) · -\(discount.piumsFormatted)", systemImage: "tag.fill")
                                            .font(.caption).foregroundStyle(.green)
                                    } else {
                                        Text("USD Total").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(18)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 20)

                    // ── Próximos Pasos ──────────────────────
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Próximos Pasos").font(.headline)
                        let steps: [String] = paymentPending ? [
                            "Completa el pago del anticipo para confirmar tu reserva.",
                            "\(artist.artistName) será notificado cuando el pago sea recibido.",
                            "El saldo restante se cobra automáticamente 72h antes del evento."
                        ] : [
                            "\(artist.artistName) revisará tu solicitud de reserva en las próximas 24 horas.",
                            "Recibirás una notificación por correo una vez sea confirmada.",
                            "Podrás chatear con el profesional directamente desde tu panel."
                        ]
                        ForEach(Array(steps.enumerated()), id: \.0) { idx, text in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(idx == 0 ? Color.piumsOrange : Color.piumsOrange.opacity(0.15))
                                        .frame(width: 28, height: 28)
                                    Text("\(idx + 1)").font(.caption.bold())
                                        .foregroundStyle(idx == 0 ? .white : Color.piumsOrange)
                                }
                                Text(text).font(.subheadline).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                        }
                    }
                    .padding(18)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 20)

                    // ── Botones ─────────────────────────────
                    VStack(spacing: 10) {
                        if paymentPending {
                            Button { showCheckout = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "creditcard.fill")
                                    Text("Pagar ahora").font(.headline)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(Color.piumsOrange).clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.piumsOrange.opacity(0.35), radius: 10, y: 4)
                            }
                        }
                        Button(action: onDone) {
                            Text("Ver Mis Reservas")
                                .font(.headline)
                                .foregroundStyle(paymentPending ? Color.piumsOrange : .white)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(paymentPending
                                    ? Color.piumsOrange.opacity(0.08)
                                    : Color.piumsOrange)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        Button { dismiss() } label: {
                            Text("Ir al Dashboard").font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 40)
                }
            }
            .scrollIndicators(.hidden)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.piumsOrange)
                }
            }
        }
        .sheet(isPresented: $showCheckout) {
            if let b = booking {
                PaymentCheckoutView(booking: b, artist: artist) {
                    showCheckout = false
                    onDone()
                }
            }
        }
    }
}

// MARK: - PaymentCtaCard

private struct PaymentCtaCard: View {
    let anticipoRequired: Bool
    let anticipoAmount: Int?
    let totalPrice: Int
    let currency: String
    let onTap: () -> Void

    private var amountLabel: String {
        let cents = anticipoRequired ? (anticipoAmount ?? totalPrice) : totalPrice
        let amount = Double(cents) / 100.0
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency; fmt.currencyCode = currency; fmt.locale = Locale(identifier: "en_US")
        return fmt.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.piumsOrange.opacity(0.15)).frame(width: 48, height: 48)
                    Image(systemName: "creditcard.fill")
                        .font(.title3).foregroundStyle(Color.piumsOrange)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(anticipoRequired ? "Pagar anticipo" : "Confirmar pago")
                        .font(.headline).foregroundStyle(.primary)
                    Text("\(amountLabel) · Seguro con Tilopay")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.piumsOrange.opacity(0.3), lineWidth: 1.5))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
    }
}

// MARK: - SuccessInfoCell

private struct SuccessInfoCell<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).tracking(0.8)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
