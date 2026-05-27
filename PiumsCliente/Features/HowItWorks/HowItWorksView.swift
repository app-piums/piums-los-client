// HowItWorksView.swift — Tutorial "Cómo funciona Piums"
import SwiftUI

struct HowItWorksView: View {
    var onDismiss: (() -> Void)? = nil
    /// Called with the tab index when the user taps "Go to section".
    /// Caller should dismiss the sheet then switch tab.
    var onNavigate: ((Int) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showSteps = false
    @State private var currentStep = 0
    @State private var animateIn = false

    private struct Feature {
        let icon: String
        let label: String
        let color: Color
        let tab: Int
    }

    private let features: [Feature] = [
        Feature(icon: "house.fill",                       label: "Panel principal",   color: Color(hex: "#FF6A00"), tab: 0),
        Feature(icon: "calendar.badge.checkmark",         label: "Reservas",          color: Color(hex: "#F59E0B"), tab: 2),
        Feature(icon: "mappin.and.ellipse",               label: "Buscar por fecha",  color: Color(hex: "#10B981"), tab: 1),
        Feature(icon: "magnifyingglass",                  label: "Explorar artistas", color: Color(hex: "#6366F1"), tab: 1),
        Feature(icon: "sparkles",                         label: "Eventos",           color: Color(hex: "#EC4899"), tab: 2),
        Feature(icon: "heart.fill",                       label: "Favoritos",         color: Color(hex: "#EF4444"), tab: 2),
        Feature(icon: "bubble.left.and.bubble.right.fill",label: "Mensajes",          color: Color(hex: "#3B82F6"), tab: 3),
        Feature(icon: "gearshape.fill",                   label: "Configuración",     color: Color(hex: "#8B5CF6"), tab: 4),
    ]

    private let steps: [HowItWorksStep] = [
        .init(icon: "magnifyingglass.circle.fill", color: Color(hex: "#FF6B2B"), tab: 1,
              title: "Explora el talento",
              description: "Busca artistas por especialidad, ciudad y precio. Filtra por disponibilidad y calificación para encontrar al artista perfecto.",
              badge: "Paso 1 de 5", section: "Explorar"),
        .init(icon: "calendar.badge.checkmark",    color: Color(hex: "#F59E0B"), tab: 1,
              title: "Elige tu fecha",
              description: "Selecciona el día y hora que necesitas. Verás la disponibilidad del artista en tiempo real para planificar sin sorpresas.",
              badge: "Paso 2 de 5", section: "Buscar por fecha"),
        .init(icon: "checkmark.seal.fill",         color: Color(hex: "#10B981"), tab: 2,
              title: "Reserva en segundos",
              description: "Envía tu solicitud con todos los detalles del evento. El artista la revisará y confirmará tu fecha a la brevedad.",
              badge: "Paso 3 de 5", section: "Mi Espacio"),
        .init(icon: "bubble.left.and.bubble.right.fill", color: Color(hex: "#6366F1"), tab: 3,
              title: "Chatea y coordina",
              description: "Comunícate directamente con el artista para afinar los últimos detalles y asegurarte de que todo salga perfecto.",
              badge: "Paso 4 de 5", section: "Mensajes"),
        .init(icon: "star.fill",                   color: Color(hex: "#EC4899"), tab: 4,
              title: "Disfruta y califica",
              description: "Vive la experiencia y comparte tu opinión. Tus reseñas ayudan a otros usuarios a encontrar los mejores artistas.",
              badge: "Paso 5 de 5", section: "Perfil"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                if showSteps {
                    stepsView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal:   .move(edge: .leading)
                        ))
                } else {
                    introView
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal:   .move(edge: .trailing)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.35), value: showSteps)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { closeView() }
                        .foregroundStyle(Color(.systemGray3))
                }
            }
        }
    }

    // MARK: - Intro

    private var introView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // Header icon
                ZStack {
                    Circle().fill(Color.piumsOrange.opacity(0.12)).frame(width: 96, height: 96)
                    Circle().fill(Color.piumsOrange.opacity(0.18)).frame(width: 72, height: 72)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.piumsOrange)
                }
                .padding(.top, 32)
                .scaleEffect(animateIn ? 1 : 0.7)
                .opacity(animateIn ? 1 : 0)

                VStack(spacing: 8) {
                    Text("Tour guiado de Piums")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("Conoce cada sección de la app en\n**5 pasos** diseñados para ti.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.top, 20)
                .padding(.horizontal, 32)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 12)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Tiempo estimado: ~2 minutos")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.top, 10)
                .opacity(animateIn ? 1 : 0)

                // Feature grid — cada tarjeta navega a su sección
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(features.indices, id: \.self) { i in
                        let f = features[i]
                        Button {
                            navigate(to: f.tab)
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(f.color.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: f.icon)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(f.color)
                                }
                                Text(f.label)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color(.systemGray4))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 16)
                        .animation(.easeOut(duration: 0.4).delay(0.05 * Double(i)), value: animateIn)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // CTA
                VStack(spacing: 12) {
                    Button {
                        closeView()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            TutorialManager.shared.start()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Iniciar tour interactivo")
                                .font(.body.weight(.semibold))
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.body)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.piumsOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.piumsOrange.opacity(0.4), radius: 10, y: 4)
                    }

                    Button("Omitir") { closeView() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Navega por la app real mientras aprendes")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray3))
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 40)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 16)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.1)) {
                animateIn = true
            }
        }
        .onDisappear { animateIn = false }
    }

    // MARK: - Steps carousel

    private var stepsView: some View {
        VStack(spacing: 0) {
            // Back + progress
            HStack(spacing: 12) {
                Button {
                    withAnimation { showSteps = false; currentStep = 0 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.piumsOrange)
                }
                ProgressBar(value: Double(currentStep + 1) / Double(steps.count))
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 28)

            TabView(selection: $currentStep) {
                ForEach(steps.indices, id: \.self) { i in
                    StepCard(step: steps[i]) {
                        navigate(to: steps[i].tab)
                    }
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
            .padding(.top, 20)
            .padding(.bottom, 28)

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

    // MARK: - Helpers

    private func navigate(to tab: Int) {
        onNavigate?(tab)
        closeView()
    }

    private func closeView() {
        if let onDismiss { onDismiss() } else { dismiss() }
    }
}

// MARK: - Step Card

private struct StepCard: View {
    let step: HowItWorksStep
    let onGoToSection: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(step.color.opacity(0.10)).frame(width: 120, height: 120)
                Circle().fill(step.color.opacity(0.17)).frame(width: 90,  height: 90)
                Image(systemName: step.icon)
                    .font(.system(size: 44))
                    .foregroundStyle(step.color)
            }
            .padding(.bottom, 28)

            Text(step.badge)
                .font(.caption.bold())
                .tracking(1.5)
                .foregroundStyle(step.color)
                .padding(.bottom, 10)

            Text(step.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 14)

            Text(step.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)

            // Navigate to section
            Button {
                onGoToSection()
            } label: {
                HStack(spacing: 6) {
                    Text("Ir a \(step.section)")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(step.color)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(step.color.opacity(0.10))
                .clipShape(Capsule())
            }
            .padding(.top, 22)

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
    let tab: Int
    let title: String
    let description: String
    let badge: String
    let section: String
}

#Preview { HowItWorksView() }
