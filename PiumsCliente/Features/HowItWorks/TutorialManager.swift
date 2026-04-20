// TutorialManager.swift — Gestiona el tour interactivo del cliente
import SwiftUI
import Combine

@MainActor
final class TutorialManager: ObservableObject {
    static let shared = TutorialManager()

    @Published var isActive = false
    @Published var currentStep = 0

    struct TourStep {
        let tab: Int
        let icon: String
        let color: Color
        let title: String
        let description: String
        let tip: String
    }

    let steps: [TourStep] = [
        TourStep(
            tab: 0, icon: "house.fill", color: .piumsOrange,
            title: "Panel Principal",
            description: "Aquí encuentras artistas destacados, tus próximas reservas y recomendaciones personalizadas para tu evento.",
            tip: "Desliza hacia abajo para actualizar tus reservas activas en tiempo real."
        ),
        TourStep(
            tab: 1, icon: "magnifyingglass", color: Color(hex: "#6366F1"),
            title: "Explorar Artistas",
            description: "Busca artistas por especialidad, ciudad y precio. Filtra por disponibilidad y calificación para encontrar el perfil ideal.",
            tip: "Usa el filtro de fecha para ver únicamente artistas libres cuando lo necesitas."
        ),
        TourStep(
            tab: 1, icon: "mappin.and.ellipse", color: Color(hex: "#10B981"),
            title: "Buscar por Fecha y Lugar",
            description: "Ingresa la fecha de tu evento y tu ubicación para ver de inmediato qué artistas están disponibles cerca de ti.",
            tip: "Activa la ubicación para obtener resultados más precisos en tu área."
        ),
        TourStep(
            tab: 2, icon: "square.grid.2x2.fill", color: Color(hex: "#F59E0B"),
            title: "Mi Espacio",
            description: "Tu centro de control: gestiona Reservas activas y pasadas, revisa tus Eventos programados y accede a tus Favoritos para contratar rápido.",
            tip: "Cambia entre Reservas, Eventos y Favoritos con las pestañas de la parte superior."
        ),
        TourStep(
            tab: 3, icon: "bubble.left.and.bubble.right.fill", color: Color(hex: "#3B82F6"),
            title: "Mensajes",
            description: "Comunícate directamente con los artistas. Las conversaciones con mensajes no leídos muestran un badge en el ícono.",
            tip: "Escribe antes del evento para coordinar los detalles finales sin sorpresas."
        ),
        TourStep(
            tab: 4, icon: "person.fill", color: Color(hex: "#8B5CF6"),
            title: "Tu Perfil",
            description: "Gestiona tu cuenta, revisa tu historial de reseñas y personaliza tus preferencias. También puedes volver a ver este tour cuando quieras.",
            tip: "Desde Perfil también puedes acceder a este tutorial en cualquier momento."
        ),
    ]

    var currentTabTarget: Int {
        guard currentStep < steps.count else { return 0 }
        return steps[currentStep].tab
    }

    var currentStepData: TourStep? {
        guard currentStep < steps.count else { return nil }
        return steps[currentStep]
    }

    var isLastStep: Bool { currentStep == steps.count - 1 }

    func start() {
        currentStep = 0
        isActive = true
    }

    func next() {
        if isLastStep { end() } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { currentStep += 1 }
        }
    }

    func previous() {
        guard currentStep > 0 else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { currentStep -= 1 }
    }

    func end() {
        withAnimation(.easeOut(duration: 0.25)) { isActive = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.currentStep = 0 }
    }
}
