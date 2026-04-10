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
}
