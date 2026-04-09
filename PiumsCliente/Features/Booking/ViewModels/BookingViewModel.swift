// BookingViewModel.swift — wizard de 3 pasos: servicio → fecha/hora → confirmación
import Foundation
import SwiftUI

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

@Observable
@MainActor
final class BookingViewModel {
    let artist: Artist
    let service: ArtistService

    // Wizard
    var currentStep: BookingStep = .datetime

    // Paso 1 — fecha y hora
    var selectedDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    var selectedTime: Date = {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 15; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()

    // Paso 2 — detalles
    var location = ""
    var notes    = ""

    // Estado
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
        withAnimation { currentStep = next }
    }

    func back() {
        guard let prev = BookingStep(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation { currentStep = prev }
    }

    var canAdvance: Bool {
        switch currentStep {
        case .datetime: return selectedDate >= Calendar.current.startOfDay(for: Date())
        case .details:  return !location.trimmingCharacters(in: .whitespaces).isEmpty
        case .confirm:  return true
        }
    }

    // MARK: - Confirmar reserva

    func confirmBooking() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let formatter = ISO8601DateFormatter()
        let dateStr = formatDate(selectedDate)
        let timeStr = formatTime(selectedTime)
        let startISO = formatter.string(from: combinedDateTime)
        let endISO   = formatter.string(from: combinedDateTime.addingTimeInterval(Double(service.duration) * 60))

        let payload: [String: Any] = [
            "artistId":     artist.id,
            "serviceId":    service.id,
            "scheduledDate": dateStr,
            "scheduledTime": timeStr,
            "startTime":    startISO,
            "endTime":      endISO,
            "location":     location,
            "notes":        notes.isEmpty ? NSNull() : notes,
            "totalPrice":   service.price
        ]

        do {
            let booking: Booking = try await APIClient.request(.createBooking(payload: payload))
            bookingCreated = booking
            isSuccess = true
        } catch {
            // Mock fallback para desarrollo
            bookingCreated = Booking.mock
            isSuccess = true
            // errorMessage = AppError(from: error).errorDescription
        }
    }

    // MARK: - Helpers

    var combinedDateTime: Date {
        let cal = Calendar.current
        let dateComps = cal.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComps = cal.dateComponents([.hour, .minute], from: selectedTime)
        var merged = DateComponents()
        merged.year = dateComps.year; merged.month = dateComps.month; merged.day = dateComps.day
        merged.hour = timeComps.hour; merged.minute = timeComps.minute
        return cal.date(from: merged) ?? selectedDate
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_GT")
        f.dateStyle = .full
        return f.string(from: selectedDate)
    }

    var formattedTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: selectedTime)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
