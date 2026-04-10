// BookingViewModel.swift — wizard de 3 pasos: fecha/hora → detalles → confirmación
import Foundation
import SwiftUI

// MARK: - TimeSlot model

struct TimeSlot: Identifiable, Equatable {
    let id: String      // "HH:mm"
    let time: String
    let available: Bool
    let startTime: String
    let endTime: String
}

struct AvailabilityResponse: Decodable {
    let artistId: String
    let date: String
    let slots: [SlotDTO]

    struct SlotDTO: Decodable {
        let time: String
        let available: Bool
        let startTime: String
        let endTime: String
    }

    var timeSlots: [TimeSlot] {
        slots.map { TimeSlot(id: $0.time, time: $0.time, available: $0.available,
                             startTime: $0.startTime, endTime: $0.endTime) }
    }
}

// MARK: - BookingStep

enum BookingStep: Int, CaseIterable {
    case datetime = 0, details = 1, confirm = 2
    var title: String {
        switch self {
        case .datetime: return "Fecha y hora"
        case .details:  return "Detalles"
        case .confirm:  return "Confirmar"
        }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class BookingViewModel {
    let artist: Artist
    let service: ArtistService

    // Wizard
    var currentStep: BookingStep = .datetime

    // Paso 1 — fecha y slots
    var selectedDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    var selectedSlot: TimeSlot?
    var availableSlots: [TimeSlot] = []
    var isLoadingSlots = false
    var slotsError: String?

    // Paso 2 — detalles
    var location = ""
    var notes    = ""

    // Estado final
    var isLoading     = false
    var errorMessage: String?
    var bookingCreated: Booking?
    var isSuccess     = false

    init(artist: Artist, service: ArtistService) {
        self.artist  = artist
        self.service = service
    }

    // MARK: - Navegación wizard

    func next() {
        guard let next = BookingStep(rawValue: currentStep.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.25)) { currentStep = next }
    }

    func back() {
        guard let prev = BookingStep(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation(.easeInOut(duration: 0.25)) { currentStep = prev }
    }

    var canAdvance: Bool {
        switch currentStep {
        case .datetime: return selectedSlot != nil
        case .details:  return !location.trimmingCharacters(in: .whitespaces).isEmpty
        case .confirm:  return true
        }
    }

    // MARK: - Cargar slots disponibles

    func loadSlots() async {
        isLoadingSlots = true
        slotsError = nil
        selectedSlot = nil
        defer { isLoadingSlots = false }

        let dateStr = formatDate(selectedDate)
        do {
            let res: AvailabilityResponse = try await APIClient.request(
                .getAvailableSlots(artistId: artist.id, date: dateStr)
            )
            availableSlots = res.timeSlots
        } catch {
            slotsError = "No se pudo cargar la disponibilidad"
            // Fallback: slots genéricos cada hora 8am-8pm
            availableSlots = (8...20).map { h in
                let t = String(format: "%02d:00", h)
                return TimeSlot(id: t, time: t, available: true,
                                startTime: "\(dateStr)T\(t):00.000Z",
                                endTime:   "\(dateStr)T\(String(format: "%02d", h+1)):00:00.000Z")
            }
        }
    }

    // MARK: - Confirmar reserva

    func confirmBooking() async {
        guard let slot = selectedSlot else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let payload: [String: Any] = [
            "artistId":      artist.id,
            "serviceId":     service.id,
            "scheduledDate": formatDate(selectedDate),
            "scheduledTime": slot.time,
            "startTime":     slot.startTime,
            "endTime":       slot.endTime,
            "location":      location.trimmingCharacters(in: .whitespaces),
            "notes":         notes.trimmingCharacters(in: .whitespaces).isEmpty
                             ? NSNull() : notes.trimmingCharacters(in: .whitespaces),
            "totalPrice":    service.price
        ]

        do {
            let booking: Booking = try await APIClient.request(.createBooking(payload: payload))
            bookingCreated = booking
            isSuccess = true
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    // MARK: - Helpers

    var formattedDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_GT")
        f.dateStyle = .full
        return f.string(from: selectedDate)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}
