// OnboardingViewModel.swift
import SwiftUI

enum OnboardingStep { case welcome, interests, refine }

@Observable
@MainActor
final class OnboardingViewModel {

    // ── Paso actual ───────────────────────────────────────
    var step: OnboardingStep = .welcome

    // ── Selecciones ───────────────────────────────────────
    var selectedCategories: Set<String> = []
    var selectedTags: [String: Set<String>] = [:]

    // ── Estado de red ─────────────────────────────────────
    var isFinishing = false
    var errorMessage: String?

    // ── Navegación ────────────────────────────────────────
    var onFinished: (() -> Void)?   // callback que cierra el onboarding

    // MARK: - Categorías helpers

    func toggleCategory(_ id: String) {
        if selectedCategories.contains(id) {
            selectedCategories.remove(id)
        } else {
            selectedCategories.insert(id)
        }
    }

    func isSelected(_ id: String) -> Bool { selectedCategories.contains(id) }
    var canContinueFromInterests: Bool { !selectedCategories.isEmpty }

    // MARK: - Tags helpers

    func toggleTag(catId: String, tag: String) {
        var set = selectedTags[catId] ?? []
        if set.contains(tag) { set.remove(tag) } else { set.insert(tag) }
        selectedTags[catId] = set
    }

    func isTagSelected(catId: String, tag: String) -> Bool {
        selectedTags[catId]?.contains(tag) ?? false
    }

    func tagCount(catId: String) -> Int { selectedTags[catId]?.count ?? 0 }

    // Categorías a mostrar en Step 3 (si eligió alguna, mostrar esas; si no, todas)
    var categoriesToRefine: [OnboardingCategory] {
        let ids = selectedCategories.isEmpty
            ? OnboardingCategory.all.map(\.id)
            : Array(selectedCategories)
        return OnboardingCategory.all.filter { ids.contains($0.id) }
    }

    // MARK: - Navegación

    func goToInterests() { withAnimation(.easeInOut(duration: 0.3)) { step = .interests } }
    func goToRefine()     { withAnimation(.easeInOut(duration: 0.3)) { step = .refine    } }
    func goBack() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch step {
            case .refine:    step = .interests
            case .interests: step = .welcome
            case .welcome:   break
            }
        }
    }

    // MARK: - Finish / Skip

    func finish() async { await complete(skip: false) }
    func skip()   async { await complete(skip: true)  }

    private func complete(skip: Bool) async {
        isFinishing = true
        defer { isFinishing = false }

        // 1 — Guardar preferencias localmente
        if !skip {
            let interests = UserInterests(
                categories: Array(selectedCategories),
                tags: selectedTags.mapValues { Array($0) }
            )
            interests.save()
        }

        // 2 — Marcar onboarding completado en UserDefaults (ya existente)
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")

        // 3 — Notificar al backend (no bloquear si falla)
        do {
            let _: VoidResponse = try await APIClient.request(.completeOnboarding)
        } catch {
            // No bloqueamos la navegación si el backend falla
        }

        // 4 — Cerrar onboarding
        onFinished?()
    }
}
