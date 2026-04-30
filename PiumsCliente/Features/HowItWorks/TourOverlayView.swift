// TourOverlayView.swift — Overlay interactivo del tour sobre la app real
import SwiftUI

struct TourOverlayView: View {
    @ObservedObject private var tutorial = TutorialManager.shared
    private var step: TutorialManager.TourStep? { tutorial.currentStepData }

    var body: some View {
        guard let step else { return AnyView(EmptyView()) }
        return AnyView(
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // Backdrop semitransparente (deja el tab bar expuesto)
                    Color.black.opacity(0.55)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)

                    VStack(spacing: 0) {
                        Spacer()

                        // Flecha apuntando al tab activo
                        HStack(spacing: 0) {
                            Spacer()
                                .frame(width: tabArrowLeading(geo: geo, tab: step.tab))
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(.tertiarySystemGroupedBackground))
                                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                            Spacer()
                        }
                        .padding(.bottom, -1)

                        // Card principal
                        VStack(spacing: 0) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 36, height: 4)
                                .padding(.top, 10)
                                .padding(.bottom, 14)

                            VStack(alignment: .leading, spacing: 14) {
                                // Header
                                HStack(alignment: .top, spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(step.color.opacity(0.15))
                                            .frame(width: 46, height: 46)
                                        Image(systemName: step.icon)
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundStyle(step.color)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Paso \(tutorial.currentStep + 1) de \(tutorial.steps.count)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(step.color)
                                        Text(step.title)
                                            .font(.headline.weight(.bold))
                                    }

                                    Spacer()

                                    Button("Cerrar") { tutorial.end() }
                                        .foregroundStyle(.secondary)
                                }

                                // Descripción
                                Text(step.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                // Tip
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(step.color)
                                        .padding(.top, 1)
                                    Text(step.tip)
                                        .font(.caption)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(12)
                                .background(step.color.opacity(0.09))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(step.color.opacity(0.2), lineWidth: 1)
                                )

                                // Dots + botones
                                HStack(spacing: 12) {
                                    HStack(spacing: 5) {
                                        ForEach(0..<tutorial.steps.count, id: \.self) { i in
                                            let active = i == tutorial.currentStep
                                            Capsule()
                                                .fill(active ? step.color : Color.secondary.opacity(0.25))
                                                .frame(width: active ? 18 : 6, height: 6)
                                                .animation(.spring(response: 0.3), value: tutorial.currentStep)
                                        }
                                    }

                                    Spacer()

                                    if tutorial.currentStep > 0 {
                                        Button { tutorial.previous() } label: {
                                            Image(systemName: "arrow.left")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                                .frame(width: 38, height: 38)
                                                .background(Color(.systemFill))
                                                .clipShape(Circle())
                                        }
                                    }

                                    Button { tutorial.next() } label: {
                                        HStack(spacing: 6) {
                                            Text(tutorial.isLastStep ? "¡Listo!" : "Siguiente")
                                                .font(.subheadline.weight(.semibold))
                                            Image(systemName: tutorial.isLastStep ? "checkmark" : "arrow.right")
                                                .font(.subheadline.weight(.bold))
                                        }
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 10)
                                        .background(step.color)
                                        .clipShape(Capsule())
                                        .shadow(color: step.color.opacity(0.35), radius: 6, y: 3)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)
                        }
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .padding(.horizontal, 10)
                        .padding(.bottom, tabBarHeight(geo: geo))
                        .shadow(color: .black.opacity(0.18), radius: 20, y: -4)
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .id(tutorial.currentStep)
        )
    }

    private func tabArrowLeading(geo: GeometryProxy, tab: Int) -> CGFloat {
        let tabWidth = geo.size.width / CGFloat(5)
        let center   = tabWidth * CGFloat(tab) + tabWidth / 2
        return max(10, center - 6)
    }

    private func tabBarHeight(geo: GeometryProxy) -> CGFloat {
        geo.safeAreaInsets.bottom + 49
    }
}
