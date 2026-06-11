import SwiftUI

/// Barra de rango con dos extremos (min/max) sobre un solo track.
/// SwiftUI no trae RangeSlider nativo; este componente replica el estilo
/// de Slider con tinte de la app. Valores redondeados a `step` y con una
/// separación mínima `minimumGap` entre ambos extremos.
struct PiumsRangeSlider: View {
    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    let range: ClosedRange<Double>
    var step: Double = 100
    var minimumGap: Double = 500
    var tint: Color = .piumsOrange

    private let thumbSize: CGFloat = 26
    private let trackHeight: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width - thumbSize
            let span = range.upperBound - range.lowerBound
            let lowerX = CGFloat((lowerValue - range.lowerBound) / span) * width
            let upperX = CGFloat((upperValue - range.lowerBound) / span) * width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbSize / 2)

                Capsule()
                    .fill(tint)
                    .frame(width: max(0, upperX - lowerX), height: trackHeight)
                    .offset(x: lowerX + thumbSize / 2)

                thumb
                    .offset(x: lowerX)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { g in
                                let raw = value(atX: g.location.x - thumbSize / 2, width: width, span: span)
                                lowerValue = min(max(raw, range.lowerBound), upperValue - minimumGap)
                            }
                    )
                    .accessibilityLabel("Precio mínimo")
                    .accessibilityValue("\(Int(lowerValue))")
                    .accessibilityAdjustableAction { direction in
                        let delta = direction == .increment ? step : -step
                        lowerValue = min(max(lowerValue + delta, range.lowerBound), upperValue - minimumGap)
                    }

                thumb
                    .offset(x: upperX)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { g in
                                let raw = value(atX: g.location.x - thumbSize / 2, width: width, span: span)
                                upperValue = max(min(raw, range.upperBound), lowerValue + minimumGap)
                            }
                    )
                    .accessibilityLabel("Precio máximo")
                    .accessibilityValue("\(Int(upperValue))")
                    .accessibilityAdjustableAction { direction in
                        let delta = direction == .increment ? step : -step
                        upperValue = max(min(upperValue + delta, range.upperBound), lowerValue + minimumGap)
                    }
            }
        }
        .frame(height: thumbSize + 4)
    }

    private var thumb: some View {
        Circle()
            .fill(.white)
            .frame(width: thumbSize, height: thumbSize)
            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
    }

    private func value(atX x: CGFloat, width: CGFloat, span: Double) -> Double {
        let fraction = Double(min(max(x / width, 0), 1))
        let raw = range.lowerBound + fraction * span
        return (raw / step).rounded() * step
    }
}

#Preview {
    struct PreviewHost: View {
        @State var lower: Double = 5000
        @State var upper: Double = 30000
        var body: some View {
            VStack(spacing: 16) {
                Text("Mínimo: \(Int(lower)) — Máximo: \(Int(upper))")
                PiumsRangeSlider(lowerValue: $lower, upperValue: $upper, range: 0...50000)
            }
            .padding()
        }
    }
    return PreviewHost()
}
