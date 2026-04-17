// CreateQuejaView.swift — formulario para abrir una queja desde una reserva
import SwiftUI

struct CreateQuejaView: View {
    let booking: Booking
    @State private var viewModel: CreateQuejaViewModel
    @Environment(\.dismiss) private var dismiss
    let onCreated: ((Dispute) -> Void)?

    init(booking: Booking, onCreated: ((Dispute) -> Void)? = nil) {
        self.booking = booking
        self.onCreated = onCreated
        _viewModel = State(initialValue: CreateQuejaViewModel(booking: booking))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Aviso
                    infoCard

                    // Tipo
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tipo de queja")
                            .font(.headline)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(DisputeType.allCases, id: \.self) { type in
                                TypeCard(
                                    type: type,
                                    isSelected: viewModel.disputeType == type
                                ) { viewModel.disputeType = type }
                            }
                        }
                    }

                    // Asunto
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Asunto")
                            .font(.headline)
                        PiumsTextField(
                            title: "Resumen breve del problema",
                            text: $viewModel.subject
                        )
                    }

                    // Descripción
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Descripción")
                            .font(.headline)
                        Text("Describe detalladamente lo ocurrido")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $viewModel.description)
                            .frame(minHeight: 140)
                            .padding(12)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }

                    // Error
                    if let msg = viewModel.errorMessage {
                        ErrorBannerView(message: msg)
                    }

                    // Espacio para el botón flotante
                    Color.clear.frame(height: 80)
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                PiumsButton(
                    title: "Enviar queja",
                    isLoading: viewModel.isLoading
                ) {
                    Task { await viewModel.submit() }
                }
                .disabled(!viewModel.canSubmit)
                .opacity(viewModel.canSubmit ? 1 : 0.5)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .navigationTitle("Nueva queja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onChange(of: viewModel.isSuccess) { _, success in
                if success, let dispute = viewModel.createdDispute {
                    onCreated?(dispute)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Info card

    private var infoCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.piumsOrange)
            VStack(alignment: .leading, spacing: 4) {
                Text("¿Tuviste un problema?")
                    .font(.subheadline.bold())
                Text("Nuestro equipo revisará tu caso en un plazo de 24-48 horas hábiles.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.piumsOrange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - TypeCard

private struct TypeCard: View {
    let type: DisputeType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.systemImage)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : Color.piumsOrange)
                Text(type.displayName)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? Color.piumsOrange : Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    CreateQuejaView(booking: .mock)
}
