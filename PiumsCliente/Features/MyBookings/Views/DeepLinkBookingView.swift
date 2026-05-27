// DeepLinkBookingView.swift — carga una reserva por ID desde un deep link
import SwiftUI

struct DeepLinkBookingView: View {
    let bookingId: String
    @State private var booking: Booking?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if let booking {
                BookingDetailView(booking: booking)
            } else {
                EmptyStateView(
                    systemImage: "calendar.badge.exclamationmark",
                    title: "Reserva no encontrada",
                    description: errorMessage ?? "No pudimos cargar esta reserva.",
                    actionTitle: "Reintentar"
                ) { Task { await load() } }
            }
        }
        .navigationTitle("Detalle de reserva")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            booking = try await APIClient.request(.getBooking(id: bookingId))
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
        isLoading = false
    }
}
