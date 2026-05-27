// OnboardingViewModel.swift
import SwiftUI
import UIKit

enum OnboardingStep { case welcome, interests, refine, identity }

enum DocumentType: String, CaseIterable {
    case dpi           = "DPI"
    case passport      = "PASSPORT"
    case residenceCard = "RESIDENCE_CARD"

    var label: String {
        switch self {
        case .dpi:           return "DPI"
        case .passport:      return "Pasaporte"
        case .residenceCard: return "Residencia"
        }
    }
}

@Observable
@MainActor
final class OnboardingViewModel {

    // ── Paso actual ───────────────────────────────────────
    var step: OnboardingStep = .welcome

    // ── Intereses ─────────────────────────────────────────
    var selectedCategories: Set<String> = []
    var selectedTags: [String: Set<String>] = [:]

    // ── Identidad ─────────────────────────────────────────
    var documentType: DocumentType = .dpi
    var documentNumber: String = ""
    var ciudad: String = ""
    var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    var docFrontUrl: String?
    var docBackUrl: String?
    var docSelfieUrl: String?
    var docFrontImage: UIImage?
    var docBackImage: UIImage?
    var docSelfieImage: UIImage?
    var isUploadingFront  = false
    var isUploadingBack   = false
    var isUploadingSelfie = false

    // ── Estado de red ─────────────────────────────────────
    var isFinishing = false
    var errorMessage: String?

    // ── Navegación ────────────────────────────────────────
    var onFinished: (() -> Void)?

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

    var categoriesToRefine: [OnboardingCategory] {
        let ids = selectedCategories.isEmpty
            ? OnboardingCategory.all.map(\.id)
            : Array(selectedCategories)
        return OnboardingCategory.all.filter { ids.contains($0.id) }
    }

    // MARK: - Navegación

    func goToInterests() { withAnimation(.easeInOut(duration: 0.3)) { step = .interests  } }
    func goToRefine()    { withAnimation(.easeInOut(duration: 0.3)) { step = .refine     } }
    func goToIdentity()  { withAnimation(.easeInOut(duration: 0.3)) { step = .identity   } }

    func goBack() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch step {
            case .identity:  step = .refine
            case .refine:    step = .interests
            case .interests: step = .welcome
            case .welcome:   break
            }
        }
    }

    // MARK: - Upload de documentos

    func uploadFront(_ data: Data) async {
        docFrontImage = UIImage(data: data)
        isUploadingFront = true
        defer { isUploadingFront = false }
        docFrontUrl = await uploadDoc(data, folder: "front")
    }

    func uploadBack(_ data: Data) async {
        docBackImage = UIImage(data: data)
        isUploadingBack = true
        defer { isUploadingBack = false }
        docBackUrl = await uploadDoc(data, folder: "back")
    }

    func uploadSelfie(_ data: Data) async {
        docSelfieImage = UIImage(data: data)
        isUploadingSelfie = true
        defer { isUploadingSelfie = false }
        docSelfieUrl = await uploadDoc(data, folder: "selfie")
    }

    private func uploadDoc(_ data: Data, folder: String) async -> String? {
        do {
            let resp: AvatarUploadResponseDTO = try await APIClient.uploadMultipart(
                .uploadDocument(folder: folder), imageData: data
            )
            return resp.resolvedURL
        } catch {
            return nil
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

        // 2 — Marcar onboarding completado
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")

        // 3 — Guardar identidad si fue completada (no bloquea si falla)
        if !skip, let frontUrl = docFrontUrl, let selfieUrl = docSelfieUrl,
           !documentNumber.trimmingCharacters(in: .whitespaces).isEmpty {
            let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
            var payload: [String: Any] = [
                "documentType": documentType.rawValue,
                "documentNumber": documentNumber.trimmingCharacters(in: .whitespaces),
                "documentFrontUrl": frontUrl,
                "documentSelfieUrl": selfieUrl,
                "birthDate": formatter.string(from: birthDate),
            ]
            if let backUrl = docBackUrl { payload["documentBackUrl"] = backUrl }
            let c = ciudad.trimmingCharacters(in: .whitespaces)
            if !c.isEmpty { payload["ciudad"] = c }
            do {
                let _: AuthUser = try await APIClient.request(.updateMyProfile(payload: payload))
                UserDefaults.standard.set(true, forKey: "identityVerificationSubmitted")
            } catch {}
        }

        // 4 — Notificar al backend (no bloquea si falla)
        do {
            let _: VoidResponse = try await APIClient.request(.completeOnboarding)
        } catch {}

        // 5 — Cerrar onboarding
        onFinished?()
    }
}
