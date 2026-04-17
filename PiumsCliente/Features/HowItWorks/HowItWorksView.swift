// HowItWorksView.swift — Tutorial "Cómo funciona Piums"
import SwiftUI

struct HowItWorksView: View {
    var onDismiss: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    private let steps: [HowItWorksStep] = [
        .init(
            icon: "magnifyingglass.circle.fill",
            color: Color(hex: "#FF6B2B"),
            title: "Explora el talento",
            description: "Busca artistas por especialidad, ciudad y precio. Filtra por disponibilidad y calificación para encontrar al artista perfecto para tu evento.",
            badge: "Paso 1 de 5"
        ),
        .init(
            icon: "calendar.badge.checkmark",
            color: Color(hex: "#F59E0B"),
            title: "Elige tu fecha",
            description: "Selecciona el día y hora que necesitas. Verás la disponibilidad del artista en tiempo real para que puedas planificar sin sorpresas.",
            badge: "Paso 2 de 5"
        ),
        .init(
            icon: "checkmark.seal.fill",
            color: Color(hex: "#10B981"),
            title: "Reserva en segundos",
            description: "Envía tu solicitud de reserva con todos los detalles de tu evento. El artista la revisará y confirmará tu fecha a la brevedad.",
            badge: "Paso 3 de 5"
        ),
        .init(
            icon: "bubble.left.and.bubble.right.fill",
            color: Color(hex: "#6366F1"),
            title: "Chatea y coordina",
            description: "Comunícate directamente con el artista antes del evento para afinar los últimos detalles y asegurarte de que todo salga perfecto.",
            badge: "Paso 4 de 5"
        ),
        .init(
            icon: "star.fill",
            color: Color(hex: "#EC4899"),
            title: "Disfruta y califica",
            description: "Vive la experiencia y, al finalizar, comparte tu opinión. Tus reseñas ayudan a otros usuarios a encontrar los mejores artistas.",
            badge: "Paso 5 de 5"
        ),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress bar
                    ProgressBar(value: Double(currentStep + 1) / Double(steps.count))
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 32)

                    // Step card
                    TabView(selection: $currentStep) {
                        ForEach(steps.indices, id: \.self) { i in
                            StepCard(step: steps[i])
                                .tag(i)
                                .padding(.horizontal, 24)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.35), value: currentStep)

                    // Dots
                    HStack(spacing: 8) {
                        ForEach(steps.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == currentStep ? Color.piumsOrange : Color(.systemGray4))
                                .frame(width: i == currentStep ? 22 : 8, height: 8)
                                .animation(.spring(response: 0.4), value: currentStep)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 32)

                    // Buttons
                    VStack(spacing: 12) {
                        Button {
                            if currentStep < steps.count - 1 {
                                withAnimation { currentStep += 1 }
                            } else {
                                closeView()
                            }
                        } label: {
                            Text(currentStep < steps.count - 1 ? "Siguiente →" : "¡Empezar ahora!")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.piumsOrange)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.piumsOrange.opacity(0.3), radius: 8, y: 4)
                        }

                        if currentStep < steps.count - 1 {
                            Button("Omitir tutorial") { closeView() }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Cómo funciona")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { closeView() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color(.systemGray3))
                    }
                }
            }
        }
    }

    private func closeView() {
        if let onDismiss { onDismiss() } else { dismiss() }
    }
}

// MARK: - Step Card

private struct StepCard: View {
    let step: HowItWorksStep

    var body: some View {
        VStack(spacing: 0) {
            // Icon
            ZStack {
                Circle()
                    .fill(step.color.opacity(0.12))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(step.color.opacity(0.18))
                    .frame(width: 90, height: 90)
                Image(systemName: step.icon)
                    .font(.system(size: 44))
                    .foregroundStyle(step.color)
            }
            .padding(.bottom, 32)

            // Badge
            Text(step.badge)
                .font(.caption.bold())
                .tracking(1.5)
                .foregroundStyle(step.color)
                .padding(.bottom, 12)

            // Title
            Text(step.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)

            // Description
            Text(step.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)

            Spacer()
        }
        .padding(.top, 8)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Progress Bar

private struct ProgressBar: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule().fill(Color.piumsOrange)
                    .frame(width: geo.size.width * value)
                    .animation(.easeInOut(duration: 0.4), value: value)
            }
        }
        .frame(height: 5)
    }
}

// MARK: - Model

private struct HowItWorksStep {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let badge: String
}

#Preview { HowItWorksView() }
