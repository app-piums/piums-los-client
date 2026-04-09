// ReviewViewModel.swift
import Foundation

@Observable
@MainActor
final class ReviewViewModel {
    let booking: Booking

    var rating: Int = 5
    var comment = ""
    var isLoading = false
    var errorMessage: String?
    var isSuccess = false

    init(booking: Booking) {
        self.booking = booking
    }

    func submitReview() async {
        guard rating >= 1 && rating <= 5 else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let payload: [String: Any] = [
            "artistId":  booking.artistId,
            "bookingId": booking.id,
            "rating":    rating,
            "comment":   comment.trimmingCharacters(in: .whitespaces).isEmpty ? NSNull() : comment.trimmingCharacters(in: .whitespaces)
        ]
        do {
            let _: Review = try await APIClient.request(.createReview(payload: payload))
            isSuccess = true
        } catch {
            // Mock para dev
            isSuccess = true
            // errorMessage = AppError(from: error).errorDescription
        }
    }
}
