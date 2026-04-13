// BookingFlowView.swift — 4 pasos reales: Servicio → Fecha/Hora → Detalles → Resumen
import SwiftUI
import CoreLocation

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

    init(context: BookingFlowContext) { self.context = context }

    func loadServices() async {
        guard services.isEmpty else { return }
        isLoading = true; defer { isLoading = false }
        do {
            let res: _BFServicesRes = try await APIClient.request(.listServices(artistId: context.artist.id))
            services = res.services.filter { $0.status == "ACTIVE" && ($0.isAvailable ?? true) }
        } catch { errorMessage = AppError(from: error).errorDescription }
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
            slots = ["09:00","11:00","14:00","17:00"].map { TimeSlot(time: $0, available: true, startTime: nil, endTime: nil) }
        }
    }

    func calculatePrice() async {
        guard let svc = context.service else { return }
        priceError = nil
        var payload: [String: Any] = ["serviceId": svc.id, "durationMinutes": context.durationMinutes]
        if let lat = context.locationLat { payload["locationLat"] = lat }
        if let lng = context.locationLng { payload["locationLng"] = lng }
        do {
            priceQuote = try await APIClient.request(.calculatePrice(payload: payload))
            context.priceQuote = priceQuote
        } catch {
            let base = svc.basePrice
            priceQuote = PriceQuote(serviceId: svc.id, currency: svc.currency,
                items: [PriceQuoteItem(type:"BASE", name:svc.name, qty:1, unitPriceCents:base, totalPriceCents:base, metadata:nil)],
                subtotalCents: base, totalCents: base,
                breakdown: PriceQuoteBreakdown(baseCents: base, addonsCents: 0, travelCents: 0, discountsCents: 0))
            context.priceQuote = priceQuote
            priceError = "Precio estimado"
        }
    }

    func submitBooking(clientId: String) async {
        guard let isoDate = context.scheduledDateISO else { errorMessage = "Selecciona fecha y hora."; return }
        guard let svc = context.service else { errorMessage = "Selecciona un servicio."; return }
        isSubmitting = true; errorMessage = nil; defer { isSubmitting = false }
        var payload: [String: Any] = [
            "artistId": context.artist.id, "serviceId": svc.id, "clientId": clientId,
            "scheduledDate": isoDate, "durationMinutes": context.durationMinutes,
        ]
        if !context.location.isEmpty     { payload["location"] = context.location }
        if let lat = context.locationLat { payload["locationLat"] = lat }
        if let lng = context.locationLng { payload["locationLng"] = lng }
        if !context.clientNotes.isEmpty  { payload["clientNotes"] = context.clientNotes }
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locationStore) private var locationStore

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
        .navigationTitle("Book Service")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
        }
        .sheet(isPresented: Binding(get: { vm.didComplete }, set: { if !$0 { dismiss() } })) {
            BookingSuccessView(booking: vm.bookingResult, artist: context.artist) { dismiss() }
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
                        Text(q.totalCents.piumsFormatted).font(.title3.bold()).foregroundStyle(Color.piumsOrange)
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
            guard let id = AuthManager.shared.currentUser?.id else { return }
            Task { await vm.submitBooking(clientId: id) }
        } else {
            vm.next()
            if vm.step == .datetime { Task { await vm.loadCalendar(); if let d = vm.context.selectedDate { await vm.loadSlots(for: d) } } }
            if vm.step == .review   { Task { await vm.calculatePrice() } }
        }
    }

    // MARK: Step 1 — Servicio

    private var serviceStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            header("Selecciona un Servicio", sub: "Elige el servicio para tu evento.")
            if vm.isLoading {
                ForEach(0..<3, id:\.self) { _ in
                    RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground))
                        .frame(height: 90).redacted(reason: .placeholder)
                }
            } else {
                ForEach(vm.services) { svc in
                    BFSvcCard(service: svc, isSelected: vm.context.service?.id == svc.id) { vm.context.service = svc }
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
                                    .background(vm.context.selectedSlot?.time == s.time ? Color.piumsOrange : Color(.secondarySystemBackground))
                                    .foregroundStyle(vm.context.selectedSlot?.time == s.time ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            if let svc = vm.context.service, (svc.durationMin ?? 0) >= 480 {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $vm.context.isMultiDay) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Evento multi-día").font(.subheadline.weight(.semibold))
                            Text("Activa viáticos para artistas fuera del área.").font(.caption).foregroundStyle(.secondary)
                        }
                    }.tint(.piumsOrange)
                    if vm.context.isMultiDay {
                        Stepper("Días: \(vm.context.numDays)", value: $vm.context.numDays, in: 1...30).font(.subheadline)
                    }
                }
                .padding(14).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: Step 3 — Detalles

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            header("Detalles del Evento", sub: "Ubicación e indicaciones especiales.")
            VStack(alignment: .leading, spacing: 10) {
                Label("Ubicación del Evento", systemImage: "mappin.circle.fill").font(.headline)
                TextField("Ej. Salón Los Jardines, Zona 15", text: $vm.context.location)
                    .padding(12).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
                Button {
                    if let coord = locationStore.coordinate {
                        vm.context.locationLat = coord.latitude
                        vm.context.locationLng = coord.longitude
                        if vm.context.location.isEmpty { vm.context.location = locationStore.cityName }
                    } else {
                        locationStore.refresh()
                    }
                } label: {
                    Label(vm.context.locationLat != nil ? "Ubicación detectada ✓" : "Usar mi ubicación",
                          systemImage: vm.context.locationLat != nil ? "location.fill" : "location")
                        .font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(vm.context.locationLat != nil ? .green : Color.piumsOrange)
                }.buttonStyle(.plain)
                .onChange(of: locationStore.coordinate?.latitude) { _, _ in
                    // Auto-fill when store gets a new fix and we don't have coords yet
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
                    .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
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
            .padding(14).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 14))

            detailRows

            if let q = vm.priceQuote {
                priceView(q)
            } else {
                ProgressView("Calculando precio…")
            }
            if let e = vm.errorMessage { ErrorBannerView(message: e) }
        }
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
        .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
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
            VStack(spacing: 8) {
                ForEach(q.items, id: \.type) { item in
                    HStack {
                        HStack(spacing: 6) {
                            if item.type == "TRAVEL" { Image(systemName: "car.fill").foregroundStyle(.orange) }
                            Text(item.name).font(.subheadline)
                        }
                        Spacer()
                        Text(item.totalPriceCents.piumsFormatted).font(.subheadline.bold())
                            .foregroundStyle(item.type == "TRAVEL" ? .orange : .primary)
                    }
                }
                Divider()
                HStack {
                    Text("Total").font(.headline)
                    Spacer()
                    Text(q.totalCents.piumsFormatted).font(.title3.bold()).foregroundStyle(Color.piumsOrange)
                }
            }
            .padding(14).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
            if q.hasTravel {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundStyle(.orange)
                    Text("Los viáticos cubren transporte, alimentación y hospedaje del artista.").font(.caption).foregroundStyle(.secondary)
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
    let service: ArtistService; let isSelected: Bool; let onTap: () -> Void
    private func icon() -> String {
        let n = service.name.lowercased()
        if n.contains("boda") { return "heart.fill" }
        if n.contains("foto") { return "camera.fill" }
        if n.contains("quince") { return "sparkles" }
        if n.contains("coord") || n.contains("asesor") { return "calendar.badge.checkmark" }
        return "music.note"
    }
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.piumsOrange : Color.piumsOrange.opacity(0.10)).frame(width: 44, height: 44)
                    Image(systemName: icon()).font(.title3).foregroundStyle(isSelected ? .white : Color.piumsOrange)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.name).font(.subheadline.bold()).lineLimit(1)
                    if let d = service.description { Text(d).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(service.basePrice.piumsFormatted).font(.headline.bold()).foregroundStyle(Color.piumsOrange)
                    if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.piumsOrange) }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.piumsOrange : Color.clear, lineWidth: 2)))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
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
        .padding(14).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
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

// MARK: - BookingSuccessView

struct BookingSuccessView: View {
    let booking: Booking?; let artist: Artist; let onDone: () -> Void
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().fill(Color.green.opacity(0.12)).frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(.green)
            }
            VStack(spacing: 10) {
                Text("¡Reserva Enviada!").font(.title.bold())
                Text("Tu solicitud fue enviada a \(artist.artistName). Recibirás confirmación pronto.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 30)
                if let code = booking?.code {
                    Text("Código: \(code)").font(.headline.bold()).foregroundStyle(Color.piumsOrange)
                        .padding(.horizontal, 20).padding(.vertical, 10).background(Color.piumsOrange.opacity(0.08)).clipShape(Capsule())
                }
            }
            Spacer()
            Button(action: onDone) {
                Text("Ver mis Reservas").font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(Color.piumsOrange).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 30).padding(.bottom, 30)
        }
        .presentationDetents([.medium, .large])
    }
}
