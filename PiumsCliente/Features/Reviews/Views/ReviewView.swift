// ReviewView.swift — pantalla para dejar reseña post-servicio
import SwiftUI

struct ReviewView: View {
    let booking: Booking
    @State private var viewModel: ReviewViewModel
    @Environment(\.dismiss) private var dismiss

    init(booking: Booking) {
        self.booking = booking
        _viewModel = State(initialValue: ReviewViewModel(booking: booking))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "star.bubble.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(Color.piumsOrange)
                        Text("¿Cómo fue tu experiencia?")
                            .font(.title2.bold())
                        Text("Tu reseña ayuda a otros clientes a elegir al artista ideal.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Selector de estrellas
                    VStack(spacing: 12) {
                        Text("Calificación")
                            .font(.headline)
                        InteractiveStarRating(rating: $viewModel.rating)
                        Text(ratingLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .animation(.easeInOut, value: viewModel.rating)
                    }

                    // Comentario
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Comentario (opcional)")
                            .font(.headline)
                        TextEditor(text: $viewModel.comment)
                            .frame(minHeight: 120)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(alignment: .topLeading) {
                                if viewModel.comment.isEmpty {
                                    Text("Cuéntanos tu experiencia con el artista...")
                                        .foregroundStyle(.tertiary)
                                        .font(.subheadline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 20)
                                        .allowsHitTesting(false)
                                }
                            }
                    }

                    if let msg = viewModel.errorMessage {
                        ErrorBannerView(message: msg)
                    }

                    PiumsButton(title: "Publicar reseña", isLoading: viewModel.isLoading) {
                        Task { await viewModel.submitReview() }
                    }
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Dejar reseña")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .sheet(isPresented: $viewModel.isSuccess) {
                ReviewSuccessView { dismiss() }
            }
        }
    }

    private var ratingLabel: String {
        switch viewModel.rating {
        case 1: return "Muy malo"
        case 2: return "Regular"
        case 3: return "Bueno"
        case 4: return "Muy bueno"
        case 5: return "¡Excelente!"
        default: return ""
        }
    }
}

// MARK: - InteractiveStarRating

private struct InteractiveStarRating: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: 38))
                    .foregroundStyle(index <= rating ? Color.yellow : Color.secondary.opacity(0.3))
                    .onTapGesture { withAnimation(.spring(duration: 0.2)) { rating = index } }
                    .scaleEffect(index <= rating ? 1.15 : 1.0)
                    .animation(.spring(duration: 0.2), value: rating)
            }
        }
    }
}

// MARK: - ReviewSuccessView

private struct ReviewSuccessView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "star.fill")
                .font(.system(size: 70))
                .foregroundStyle(.yellow)
            Text("¡Gracias por tu reseña!")
                .font(.title.bold())
            Text("Tu opinión ayuda a la comunidad de Piums.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            PiumsButton(title: "Listo", action: onDone)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
        .interactiveDismissDisabled()
    }
}

#Preview {
    ReviewView(booking: .mock)
}
