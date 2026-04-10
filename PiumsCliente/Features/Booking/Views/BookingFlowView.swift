// BookingFlowView.swift — wizard de reserva presentado como sheet
import SwiftUI

struct BookingFlowView: View {
    let artist: Artist
    let service: ArtistService
    @State private var viewModel: BookingViewModel
    @Environment(\.dismiss) private var dismiss

    init(artist: Artist, service: ArtistService) {
        self.artist  = artist
        self.service = service
        _viewModel = State(initialValue: BookingViewModel(artist: artist, service: service))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Indicador de pasos
                StepIndicator(currentStep: viewModel.currentStep)
                    .padding()

                // Contenido del paso
                Group {
                    switch viewModel.currentStep {
                    case .datetime:
                        BookingDateTimeStep(viewModel: viewModel)
                    case .details:
                        BookingDetailsStep(viewModel: viewModel)
                    case .confirm:
                        BookingConfirmStep(viewModel: viewModel)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
                .animation(.easeInOut(duration: 0.25), value: viewModel.currentStep)

                Spacer()

                // Botones de navegación
                HStack(spacing: 12) {
                    if viewModel.currentStep != .datetime {
                        Button("Atrás") { viewModel.back() }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    }

                    if viewModel.currentStep == .confirm {
                        PiumsButton(
                            title: "Confirmar reserva",
                            isLoading: viewModel.isLoading
                        ) {
                            Task { await viewModel.confirmBooking() }
                        }
                    } else {
                        PiumsButton(title: "Siguiente") {
                            viewModel.next()
                        }
                        .disabled(!viewModel.canAdvance)
                        .opacity(viewModel.canAdvance ? 1 : 0.5)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle(viewModel.currentStep.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .sheet(isPresented: $viewModel.isSuccess) {
                BookingSuccessView(booking: viewModel.bookingCreated) { dismiss() }
            }
            // Error
            .overlay(alignment: .top) {
                if let msg = viewModel.errorMessage {
                    ErrorBannerView(message: msg)
                        .padding()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: viewModel.errorMessage)
        }
    }
}

// MARK: - StepIndicator

private struct StepIndicator: View {
    let currentStep: BookingStep

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BookingStep.allCases, id: \.self) { step in
                HStack(spacing: 0) {
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.piumsOrange : Color.secondary.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text("\(step.rawValue + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        )
                    if step != BookingStep.allCases.last {
                        Rectangle()
                            .fill(step.rawValue < currentStep.rawValue ? Color.piumsOrange : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

// MARK: - Paso 1: Fecha y Slots

private struct BookingDateTimeStep: View {
    @Bindable var viewModel: BookingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Resumen del servicio seleccionado
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.service.name).font(.headline)
                        Text(viewModel.artist.artistName).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(viewModel.service.price.piumsFormatted)
                        .font(.title3.bold())
                        .foregroundStyle(Color.piumsOrange)
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Selector de fecha
                VStack(alignment: .leading, spacing: 8) {
                    Label("Fecha del evento", systemImage: "calendar")
                        .font(.headline)
                    DatePicker(
                        "Fecha",
                        selection: $viewModel.selectedDate,
                        in: Calendar.current.date(byAdding: .day, value: 1, to: Date())!...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(.piumsOrange)
                    .onChange(of: viewModel.selectedDate) { _, _ in
                        Task { await viewModel.loadSlots() }
                    }
                }

                // Slots disponibles
                VStack(alignment: .leading, spacing: 12) {
                    Label("Horarios disponibles", systemImage: "clock")
                        .font(.headline)

                    if viewModel.isLoadingSlots {
                        HStack { Spacer(); ProgressView(); Spacer() }.padding()
                    } else if viewModel.availableSlots.isEmpty {
                        Text("Sin horarios disponibles para esta fecha")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        if let err = viewModel.slotsError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                            spacing: 10
                        ) {
                            ForEach(viewModel.availableSlots) { slot in
                                SlotButton(
                                    slot: slot,
                                    isSelected: viewModel.selectedSlot == slot
                                ) {
                                    if slot.available {
                                        viewModel.selectedSlot = slot
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .task { await viewModel.loadSlots() }
    }
}

// MARK: - SlotButton

private struct SlotButton: View {
    let slot: TimeSlot
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(slot.time)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(background)
                .foregroundStyle(foregroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderColor, lineWidth: 1.5)
                )
        }
        .disabled(!slot.available)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var background: Color {
        if isSelected { return .piumsOrange }
        if !slot.available { return Color(.tertiarySystemBackground) }
        return Color(.secondarySystemBackground)
    }

    private var foregroundColor: Color {
        if isSelected { return .white }
        if !slot.available { return .secondary.opacity(0.4) }
        return .primary
    }

    private var borderColor: Color {
        if isSelected { return .piumsOrange }
        return .clear
    }
}

// MARK: - Paso 2: Detalles

private struct BookingDetailsStep: View {
    @Bindable var viewModel: BookingViewModel
    @FocusState private var focused: Field?
    enum Field { case location, notes }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Ubicación del evento *", systemImage: "mappin.circle")
                        .font(.headline)
                    PiumsTextField(title: "Ej: Salón El Roble, Zona 10", text: $viewModel.location, systemImage: "location")
                        .focused($focused, equals: .location)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Notas adicionales (opcional)", systemImage: "note.text")
                        .font(.headline)
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 100)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .focused($focused, equals: .notes)
                        .overlay(alignment: .topLeading) {
                            if viewModel.notes.isEmpty {
                                Text("Instrucciones para el artista, tipo de evento, etc.")
                                    .foregroundStyle(.tertiary)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 20)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Paso 3: Confirmación

private struct BookingConfirmStep: View {
    let viewModel: BookingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Resumen
                VStack(alignment: .leading, spacing: 0) {
                    Text("Resumen de la reserva")
                        .font(.headline)
                        .padding()

                    Divider()

                    ConfirmRow(icon: "person.fill",      label: "Artista",    value: viewModel.artist.artistName)
                    ConfirmRow(icon: "music.note",       label: "Servicio",   value: viewModel.service.name)
                    ConfirmRow(icon: "calendar",         label: "Fecha",      value: viewModel.formattedDate)
                    ConfirmRow(icon: "clock",            label: "Hora",       value: viewModel.selectedSlot?.time ?? "—")
                    ConfirmRow(icon: "hourglass",        label: "Duración",   value: "\(viewModel.service.duration) min")
                    ConfirmRow(icon: "mappin.circle",    label: "Ubicación",  value: viewModel.location)
                    if !viewModel.notes.isEmpty {
                        ConfirmRow(icon: "note.text",   label: "Notas",      value: viewModel.notes)
                    }

                    Divider()

                    HStack {
                        Text("Total").font(.headline)
                        Spacer()
                        Text(viewModel.service.price.piumsFormatted)
                            .font(.title3.bold())
                            .foregroundStyle(Color.piumsOrange)
                    }
                    .padding()
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Text("Al confirmar, el artista recibirá tu solicitud y tendrá 24h para aceptarla.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
        }
    }
}

private struct ConfirmRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 10)
        Divider().padding(.leading, 52)
    }
}

// MARK: - Éxito

struct BookingSuccessView: View {
    let booking: Booking?
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("¡Reserva enviada!")
                .font(.title.bold())

            Text("Tu solicitud fue enviada al artista.\nRecibirás una notificación cuando la acepte.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let code = booking?.code {
                Text("Código: \(code)")
                    .font(.headline)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Spacer()

            PiumsButton(title: "Entendido", action: onDone)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
        .interactiveDismissDisabled()
    }
}

#Preview {
    BookingFlowView(artist: .mock, service: ArtistService.mockList(artistId: "1")[0])
}
