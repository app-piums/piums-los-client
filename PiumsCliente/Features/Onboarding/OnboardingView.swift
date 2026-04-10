// OnboardingView.swift
import SwiftUI

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let systemImage: String
    let imageColor: Color
    let title: String
    let subtitle: String
}

// MARK: - OnboardingView

struct OnboardingView: View {
    var onFinish: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "music.microphone",
            imageColor: Color.piumsOrange,
            title: "Encuentra tu artista ideal",
            subtitle: "Músicos, fotógrafos, animadores y más — para cualquier evento o momento especial."
        ),
        OnboardingPage(
            systemImage: "calendar.badge.checkmark",
            imageColor: .blue,
            title: "Reserva en minutos",
            subtitle: "Elige el servicio, la fecha y confirma. Así de simple."
        ),
        OnboardingPage(
            systemImage: "lock.shield",
            imageColor: .green,
            title: "Pagos seguros",
            subtitle: "Tu dinero está protegido. Solo se libera al artista cuando el evento concluye."
        ),
        OnboardingPage(
            systemImage: "star.fill",
            imageColor: .yellow,
            title: "Califica y mejora",
            subtitle: "Tu opinión ayuda a otros a elegir mejor y motiva a los artistas a dar lo mejor."
        )
    ]

    @State private var currentIndex = 0

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip
                HStack {
                    Spacer()
                    if currentIndex < pages.count - 1 {
                        Button("Omitir") { onFinish() }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }

                // Pager
                TabView(selection: $currentIndex) {
                    ForEach(pages.indices, id: \.self) { idx in
                        OnboardingPageView(page: pages[idx])
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentIndex)

                // Indicadores
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { idx in
                        Capsule()
                            .fill(idx == currentIndex ? Color.piumsOrange : Color(.systemGray4))
                            .frame(width: idx == currentIndex ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.4), value: currentIndex)
                    }
                }
                .padding(.bottom, 32)

                // Botón
                Button {
                    if currentIndex < pages.count - 1 {
                        withAnimation { currentIndex += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(currentIndex < pages.count - 1 ? "Siguiente" : "Comenzar")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.piumsOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - OnboardingPageView

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.imageColor.opacity(0.12))
                    .frame(width: 160, height: 160)
                Image(systemName: page.systemImage)
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(page.imageColor)
            }

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

#Preview {
    OnboardingView { }
}
