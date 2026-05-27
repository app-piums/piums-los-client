// EventsViewModel.swift
import Foundation

@Observable
@MainActor
final class EventsViewModel {
    var events: [EventSummary] = []
    var isLoading = false
    var errorMessage: String?

    func loadEvents() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let res: EventsResponse = try await APIClient.request(.listEvents)
            events = res.data
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func createEvent(name: String, date: Date?, location: String?, notes: String?, description: String?) async {
        var payload: [String: Any] = ["name": name]
        if let date { payload["eventDate"] = isoString(date) }
        if let location, !location.isEmpty { payload["location"] = location }
        if let notes, !notes.isEmpty { payload["notes"] = notes }
        if let description, !description.isEmpty { payload["description"] = description }

        do {
            let res: EventResponse = try await APIClient.request(.createEvent(payload: payload))
            events.insert(res.data, at: 0)
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func updateEvent(_ event: EventSummary, name: String, date: Date?, location: String?, notes: String?, description: String?) async {
        var payload: [String: Any] = ["name": name]
        if let date { payload["eventDate"] = isoString(date) }
        if let location, !location.isEmpty { payload["location"] = location }
        if let notes, !notes.isEmpty { payload["notes"] = notes }
        if let description, !description.isEmpty { payload["description"] = description }

        do {
            let res: EventResponse = try await APIClient.request(.updateEvent(id: event.id, payload: payload))
            if let idx = events.firstIndex(where: { $0.id == event.id }) {
                events[idx] = res.data
            }
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func deleteEvent(_ event: EventSummary) async {
        do {
            let _: VoidResponse = try await APIClient.request(.deleteEvent(id: event.id))
            events.removeAll { $0.id == event.id }
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    private func isoString(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }
}
