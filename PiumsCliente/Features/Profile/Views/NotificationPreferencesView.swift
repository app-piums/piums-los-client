// NotificationPreferencesView.swift
import SwiftUI

// MARK: - Model

struct NotifPreferences: Codable {
    var emailEnabled:         Bool
    var smsEnabled:           Bool
    var pushEnabled:          Bool
    var bookingNotifications: Bool
    var paymentNotifications: Bool
    var reviewNotifications:  Bool
    var marketingNotifications: Bool
    var dndEnabled:           Bool
    var dndStartHour:         Int
    var dndEndHour:           Int

    static let defaults = NotifPreferences(
        emailEnabled: true,
        smsEnabled: true,
        pushEnabled: true,
        bookingNotifications: true,
        paymentNotifications: true,
        reviewNotifications: true,
        marketingNotifications: false,
        dndEnabled: false,
        dndStartHour: 22,
        dndEndHour: 8
    )

    func asPayload() -> [String: Any] {
        [
            "emailEnabled":           emailEnabled,
            "smsEnabled":             smsEnabled,
            "pushEnabled":            pushEnabled,
            "bookingNotifications":   bookingNotifications,
            "paymentNotifications":   paymentNotifications,
            "reviewNotifications":    reviewNotifications,
            "marketingNotifications": marketingNotifications,
            "dndEnabled":             dndEnabled,
            "dndStartHour":           dndStartHour,
            "dndEndHour":             dndEndHour
        ]
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class NotifPreferencesViewModel {
    var prefs:          NotifPreferences = .defaults
    var savedPrefs:     NotifPreferences = .defaults
    var isLoading       = false
    var isSaving        = false
    var errorMessage:   String?
    var successMessage: String?

    var hasChanges: Bool {
        let e = prefs
        let s = savedPrefs
        return e.emailEnabled         != s.emailEnabled
            || e.smsEnabled           != s.smsEnabled
            || e.pushEnabled          != s.pushEnabled
            || e.bookingNotifications != s.bookingNotifications
            || e.paymentNotifications != s.paymentNotifications
            || e.reviewNotifications  != s.reviewNotifications
            || e.marketingNotifications != s.marketingNotifications
            || e.dndEnabled           != s.dndEnabled
            || e.dndStartHour         != s.dndStartHour
            || e.dndEndHour           != s.dndEndHour
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let p: NotifPreferences = try await APIClient.request(.getNotifPreferences)
            prefs = p
            savedPrefs = p
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }

    func save() async {
        guard hasChanges, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }
        do {
            let p: NotifPreferences = try await APIClient.request(
                .updateNotifPreferences(payload: prefs.asPayload())
            )
            prefs = p
            savedPrefs = p
            successMessage = "Preferencias guardadas"
        } catch {
            errorMessage = AppError(from: error).errorDescription
        }
    }
}

// MARK: - View

struct NotificationPreferencesView: View {
    @State private var vm = NotifPreferencesViewModel()

    var body: some View {
        List {
            if let msg = vm.errorMessage {
                Section { ErrorBannerView(message: msg) }.listRowSeparator(.hidden)
            }
            if let msg = vm.successMessage {
                Section { SuccessBannerView(message: msg) }.listRowSeparator(.hidden)
            }

            // Canales
            Section {
                toggleRow(
                    label: "Email",
                    icon: "envelope.fill",
                    color: .blue,
                    binding: Binding(get: { vm.prefs.emailEnabled }, set: { vm.prefs.emailEnabled = $0 })
                )
                toggleRow(
                    label: "SMS",
                    icon: "message.fill",
                    color: .green,
                    binding: Binding(get: { vm.prefs.smsEnabled }, set: { vm.prefs.smsEnabled = $0 })
                )
                toggleRow(
                    label: "Push",
                    icon: "bell.badge.fill",
                    color: Color.piumsOrange,
                    binding: Binding(get: { vm.prefs.pushEnabled }, set: { vm.prefs.pushEnabled = $0 })
                )
            } header: {
                Text("Canales")
            } footer: {
                Text("Controla por qué medio recibes las notificaciones.")
            }

            // Categorías
            Section {
                toggleRow(
                    label: "Reservas",
                    icon: "calendar",
                    color: Color.piumsOrange,
                    binding: Binding(get: { vm.prefs.bookingNotifications }, set: { vm.prefs.bookingNotifications = $0 })
                )
                toggleRow(
                    label: "Pagos",
                    icon: "creditcard.fill",
                    color: .green,
                    binding: Binding(get: { vm.prefs.paymentNotifications }, set: { vm.prefs.paymentNotifications = $0 })
                )
                toggleRow(
                    label: "Reseñas",
                    icon: "star.fill",
                    color: .yellow,
                    binding: Binding(get: { vm.prefs.reviewNotifications }, set: { vm.prefs.reviewNotifications = $0 })
                )
                toggleRow(
                    label: "Promociones",
                    icon: "tag.fill",
                    color: .purple,
                    binding: Binding(get: { vm.prefs.marketingNotifications }, set: { vm.prefs.marketingNotifications = $0 })
                )
            } header: {
                Text("Tipos de notificación")
            } footer: {
                Text("Las notificaciones de seguridad siempre se enviarán independientemente de estas preferencias.")
            }

            // No molestar
            Section {
                toggleRow(
                    label: "No molestar",
                    icon: "moon.fill",
                    color: .indigo,
                    binding: Binding(get: { vm.prefs.dndEnabled }, set: { vm.prefs.dndEnabled = $0 })
                )
                if vm.prefs.dndEnabled {
                    HStack {
                        Label("Desde", systemImage: "clock")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { vm.prefs.dndStartHour },
                            set: { vm.prefs.dndStartHour = $0 }
                        )) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(hourLabel(h)).tag(h)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.piumsOrange)
                    }
                    HStack {
                        Label("Hasta", systemImage: "clock.badge.checkmark")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { vm.prefs.dndEndHour },
                            set: { vm.prefs.dndEndHour = $0 }
                        )) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(hourLabel(h)).tag(h)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.piumsOrange)
                    }
                }
            } header: {
                Text("No molestar")
            } footer: {
                if vm.prefs.dndEnabled {
                    Text("No recibirás notificaciones entre las \(hourLabel(vm.prefs.dndStartHour)) y las \(hourLabel(vm.prefs.dndEndHour)).")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Notificaciones")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.secondarySystemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if vm.isSaving {
                    ProgressView().tint(Color.piumsOrange)
                } else {
                    Button("Guardar") { Task { await vm.save() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.piumsOrange)
                        .disabled(!vm.hasChanges)
                }
            }
        }
        .task { await vm.load() }
        .overlay {
            if vm.isLoading { ProgressView() }
        }
    }

    @ViewBuilder
    private func toggleRow(label: String, icon: String, color: Color, binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Label {
                Text(label)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
        }
        .tint(Color.piumsOrange)
        .listRowBackground(Color(.tertiarySystemGroupedBackground))
    }

    private func hourLabel(_ h: Int) -> String {
        let period = h < 12 ? "AM" : "PM"
        let display = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return "\(display):00 \(period)"
    }
}

#Preview {
    NavigationStack { NotificationPreferencesView() }
}
