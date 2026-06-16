// OnboardingModels.swift — Modelos del onboarding, espejo exacto de la web
import Foundation

// MARK: - Categoría de interés

struct OnboardingCategory: Identifiable, Hashable {
    let id: String
    let label: String
    let subtitle: String
    let systemImage: String
}

// MARK: - Catálogo de categorías (igual que la web)

extension OnboardingCategory {
    static let all: [OnboardingCategory] = [
        OnboardingCategory(id: "live-music",       label: "Música en Vivo",         subtitle: "Bandas, solistas, acústico",            systemImage: "music.microphone"),
        OnboardingCategory(id: "dj",               label: "DJs & Electrónica",      subtitle: "Fiestas, clubs, bodas",                 systemImage: "hifispeaker.fill"),
        OnboardingCategory(id: "photography",      label: "Fotografía",             subtitle: "Eventos, retratos, bodas",              systemImage: "camera.fill"),
        OnboardingCategory(id: "video",            label: "Video & Contenido",      subtitle: "Clips, documentales, redes",            systemImage: "video.fill"),
        OnboardingCategory(id: "music-production", label: "Producción Musical",     subtitle: "Beats, mezcla, grabación",              systemImage: "waveform"),
        OnboardingCategory(id: "dance",            label: "Danza & Performance",    subtitle: "Urbano, clásico, shows",                systemImage: "figure.dance"),
        OnboardingCategory(id: "magic",            label: "Magia & Entretenimiento",subtitle: "Ilusionistas, malabaristas, circo",     systemImage: "sparkles"),
    ]
}

// MARK: - Sub-tags por categoría

struct OnboardingSubcategory {
    let sectionLabel: String
    let tags: [String]
}

extension OnboardingSubcategory {
    static let all: [String: OnboardingSubcategory] = [
        "live-music":       .init(sectionLabel: "Estilo Musical",           tags: ["Banda de Rock", "Jazz & Blues", "Pop Acústico", "Cantautor", "Clásica", "Folklore & Regional"]),
        "dj":               .init(sectionLabel: "Géneros & Ocasiones",      tags: ["House & Tech", "Reggaeton & Urban", "Pop & Comercial", "Hip-Hop & Trap", "DJ para Bodas", "Festival & Club"]),
        "photography":      .init(sectionLabel: "Estilos de Fotografía",    tags: ["Eventos", "Retratos", "Editorial", "Bodas", "Producto", "Urbana & Street"]),
        "video":            .init(sectionLabel: "Tipos de Video",           tags: ["Clips Musicales", "Bodas & Celebraciones", "Redes Sociales", "Documental", "Comercial", "Cortometraje"]),
        "music-production": .init(sectionLabel: "Servicios de Estudio",     tags: ["Beat Making", "Mezcla & Mastering", "Grabación en Estudio", "Composición", "Arreglos", "Jingle & Publicidad"]),
        "dance":            .init(sectionLabel: "Estilos de Danza",         tags: ["Urbano & Hip-Hop", "Ballet Clásico", "Contemporáneo", "Latino & Salsa", "Folklore", "Show & Entretenimiento"]),
        "magic":            .init(sectionLabel: "Tipos de Show",            tags: ["Magia de Cerca", "Gran Ilusionismo", "Malabares", "Acrobacia", "Circo", "Fuego & Pirotecnia"]),
    ]
}

// MARK: - Preferencias del usuario (se guardan localmente + se envían al backend)

struct UserInterests: Codable {
    var categories: [String]
    var tags: [String: [String]]   // catId → [tag, ...]

    static let storageKey = "piums_interests"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    static func load() -> UserInterests? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(UserInterests.self, from: data)
    }
}
