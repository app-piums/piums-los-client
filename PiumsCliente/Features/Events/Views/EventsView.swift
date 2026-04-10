// EventsView.swift
import SwiftUI

struct EventsView: View {
    @State private var viewModel = EventsViewModel()
    @State private var showCreate = false
    @State private var selectedEvent: EventSummary?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.events.isEmpty {
                LoadingView()
            } else if viewModel.events.isEmpty {
                EmptyStateView(
                    systemImage: "ticket.fill",
                    title: "Sin eventos",
                    description: "Todavía no has creado eventos."
                )
            } else {
                List {
                    ForEach(viewModel.events) { event in
                        EventRow(event: event)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .onTapGesture { selectedEvent = event }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await viewModel.loadEvents() }
            }
        }
        .navigationTitle("Eventos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .task { await viewModel.loadEvents() }
        .sheet(isPresented: $showCreate) {
            EventFormView(onSave: { name, date, location, notes, description in
                Task { await viewModel.createEvent(name: name, date: date, location: location, notes: notes, description: description) }
                showCreate = false
            })
        }
        .navigationDestination(item: $selectedEvent) {
            EventDetailView(event: $0, viewModel: viewModel)
        }
    }
}

private struct EventRow: View {
    let event: EventSummary

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.piumsOrange.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "ticket.fill").foregroundStyle(Color.piumsOrange))

            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.subheadline.bold())
                Text(event.eventDate ?? "Sin fecha")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(event.status.rawValue)
                .font(.caption2.bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Event Detail

private struct EventDetailView: View {
    let event: EventSummary
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State var viewModel: EventsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(event.name)
                    .font(.title2.bold())
                if let date = event.eventDate {
                    Label(date, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let loc = event.location {
                    Label(loc, systemImage: "mappin.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let desc = event.description {
                    Text(desc).font(.subheadline).foregroundStyle(.secondary)
                }
                if let notes = event.notes {
                    Text(notes).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .navigationTitle("Evento")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar") { showEdit = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { showDeleteConfirm = true } label: { Image(systemName: "trash") }
            }
        }
        .confirmationDialog("¿Eliminar evento?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { Task { await viewModel.deleteEvent(event) } }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $showEdit) {
            EventFormView(event: event, onSave: { name, date, location, notes, description in
                Task { await viewModel.updateEvent(event, name: name, date: date, location: location, notes: notes, description: description) }
                showEdit = false
            })
        }
    }
}

// MARK: - Event Form

private struct EventFormView: View {
    var event: EventSummary? = nil
    var onSave: (String, Date?, String?, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var date: Date? = nil
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var descriptionText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") { TextField("Nombre del evento", text: $name) }
                Section("Fecha") {
                    DatePicker("Selecciona fecha", selection: Binding(get: { date ?? Date() }, set: { date = $0 }), displayedComponents: .date)
                }
                Section("Ubicación") { TextField("Lugar", text: $location) }
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

#Preview { NavigationStack { EventsView() } }
