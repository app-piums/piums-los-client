// SharedComponents.swift — componentes reutilizables en toda la app
import SwiftUI

// MARK: - PiumsTextField

struct PiumsTextField: View {
    let title: String
    @Binding var text: String
    var systemImage: String? = nil
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let icon = systemImage {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }
            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - PiumsSecureField

struct PiumsSecureField: View {
    let title: String
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Group {
                if isVisible {
                    TextField(title, text: $text)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField(title, text: $text)
                        .textContentType(.password)
                }
            }
            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - PiumsButton

struct PiumsButton: View {
    let title: String
    var isLoading: Bool = false
    var style: ButtonStyle = .primary
    let action: () -> Void

    enum ButtonStyle { case primary, secondary, destructive }

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(style == .primary ? .white : .piumsOrange)
                        .scaleEffect(0.85)
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:     return .piumsOrange
        case .secondary:   return .piumsOrange.opacity(0.1)
        case .destructive: return .red.opacity(0.1)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:     return .white
        case .secondary:   return .piumsOrange
        case .destructive: return .red
        }
    }
}

// MARK: - ErrorBannerView

struct ErrorBannerView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)
            Spacer()
        }
        .padding(12)
        .background(.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - SuccessBannerView

struct SuccessBannerView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.green)
            Spacer()
        }
        .padding(12)
        .background(.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - LoadingView

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Cargando...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let description: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.bold())
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let title = actionTitle, let action = action {
                Button(title, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(.piumsOrange)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - StarRatingView

struct StarRatingView: View {
    let rating: Double
    var maxRating: Int = 5
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: starImage(for: index))
                    .font(.system(size: size))
                    .foregroundStyle(index <= Int(rating.rounded()) ? Color.yellow : Color.secondary.opacity(0.3))
            }
        }
    }

    private func starImage(for index: Int) -> String {
        if Double(index) <= rating { return "star.fill" }
        if Double(index) - 0.5 <= rating { return "star.leadinghalf.filled" }
        return "star"
    }
}

// MARK: - PriceText helper

extension Int {
    /// Convierte centavos a texto formateado, ej: 15000 → "$ 150.00"
    var piumsFormatted: String {
        let value = Double(self) / 100.0
        return String(format: "$ %.2f", value)
    }
}
