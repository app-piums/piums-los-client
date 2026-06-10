// EventFormView.swift
import SwiftUI
import CoreLocation

// MARK: - Event Form

struct EventFormView: View {
    var event: EventSummary? = nil
    var onSave: (String, Date?, String?, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var date: Date? = nil
    @State private var location: String = ""
    @State private var locationCoord: CLLocationCoordinate2D? = nil
    @State private var showLocationPicker = false
    @State private var notes: String = ""
    @State private var descriptionText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") { TextField("Nombre del evento", text: $name) }
                Section("Fecha") {
                    DatePicker("Selecciona fecha", selection: Binding(get: { date ?? Date() }, set: { date = $0 }), displayedComponents: .date)
                }
                Section("Ubicación") {
                    Button {
                        showLocationPicker = true
                    } label: {
                        HStack {
                            Image(systemName: locationCoord != nil ? "mappin.circle.fill" : "mappin.and.ellipse")
                                .foregroundStyle(locationCoord != nil ? Color.piumsOrange : .secondary)
                            Text(location.isEmpty ? "Busca el lugar del evento" : location)
                                .foregroundStyle(location.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary).font(.footnote)
                        }
                    }
                    .sheet(isPresented: $showLocationPicker) {
                        EventLocationPickerSheet(locationName: $location, coordinate: $locationCoord)
                    }
                }
                Section("Descripción") { TextField("Descripción", text: $descriptionText) }
                Section("Notas") { TextField("Notas", text: $notes) }
            }
            .navigationTitle(event == nil ? "Nuevo evento" : "Editar evento")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(name, date, location, notes, descriptionText)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .onAppear {
            if let event {
                name = event.name
                location = event.location ?? ""
                notes = event.notes ?? ""
                descriptionText = event.description ?? ""
            }
        }
    }
}

// MARK: - Event Location Picker Sheet

struct EventLocationPickerSheet: View {
    @Binding var locationName: String
    @Binding var coordinate: CLLocationCoordinate2D?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                LocationSearchField(
                    placeholder: "Busca el lugar del evento",
                    text: $locationName,
                    coordinate: $coordinate,
                    onSelect: { _ in dismiss() }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if coordinate != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Ubicación seleccionada")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()
            }
            .navigationTitle("Ubicación del evento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
