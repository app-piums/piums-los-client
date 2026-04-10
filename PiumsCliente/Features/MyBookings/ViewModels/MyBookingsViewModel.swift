// MyBookingsViewModel.swift
import Foundation

@Observable
@MainActor
final class MyBookingsViewModel {
    var bookings: [Booking] = []
    var isLoading = false
    var errorMessage: String?
    var selectedStatus: BookingStatus?
    var hasMore = true
    private var currentPage = 1

    let statusFilters: [BookingStatus?] = [nil, .pending, .confirmed, .paymentPending, .inProgress, .completed, .cancelledClient]

    func statusLabel(_ s: BookingStatus?) -> String {
        s?.displayName ?? "Todas"
    }

    func loadInitial() async {
        currentPage = 1
        bookings = []
        hasMore = true
        await loadNext()
    }

    func loadNextIfNeeded(item: Booking) async {
        guard let last = bookings.last, last.id == item.id, hasMore, !isLoading else { return }
        await loadNext()
    }

    func selectStatus(_ status: BookingStatus?) async {
        selectedStatus = status
        await loadInitial()
    }

    func cancelBooking(id: String) async {
        do {
            let _: EmptyResponse = try await APIClient.request(.cancelBooking(id: id))
            bookings.removeAll { $0.id == id }
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    private func loadNext() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let res: BookingsResponse = try await APIClient.request(
                .listMyBookings(status: selectedStatus?.rawValue, page: currentPage)
            )
            bookings.append(contentsOf: res.allBookings)
            hasMore = res.hasMore
            currentPage += 1
        } catch {
            if bookings.isEmpty { bookings = [.mock] }
            errorMessage = AppError(from: error).errorDescription
        }
    }
}
