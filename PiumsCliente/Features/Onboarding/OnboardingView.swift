// OnboardingView.swift — 4 pasos: Bienvenida · Intereses · Afinar gustos · Identidad
import SwiftUI
import PhotosUI

// MARK: - Contenedor principal

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var vm = OnboardingViewModel()

    var body: some View {
        ZStack {
            switch vm.step {
            case .welcome:
                OnboardingWelcomeStep(vm: vm)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal:   .move(edge: .leading)
                    ))
            case .interests:
                OnboardingInterestsStep(vm: vm)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .leading)
                    ))
            case .refine:
                OnboardingRefineStep(vm: vm)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .leading)
                    ))
            case .identity:
                OnboardingIdentityStep(vm: vm)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .trailing)
                    ))
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.35), value: vm.step)
        .onAppear { vm.onFinished = onFinish }
    }
}

// ══════════════════════════════════════════════════════════════════════════
// MARK: - Step 1 — Bienvenida
// ══════════════════════════════════════════════════════════════════════════

private struct OnboardingWelcomeStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.piumsOrange.opacity(0.06), Color(.systemBackground), Color(.systemBackground)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Barra superior
                HStack {
                    HStack(spacing: 8) {
                        Image("PiumsLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 40)
                    }
                    Spacer()
                    Button("Omitir") { Task { await vm.skip() } }
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 28).padding(.top, 16)

                Spacer()

                // Hero
                VStack(alignment: .leading, spacing: 0) {
                    Text("Bienvenido · Paso 1")
                        .font(.caption.bold()).tracking(2)
                        .foregroundStyle(Color.piumsOrange)
                        .padding(.bottom, 12)

                    Text("Bienvenido a\n**Piums**")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundStyle(.primary)
                        .padding(.bottom, 16)

                    Text("El ecosistema donde el talento creativo encontrará oportunidades. Conecta con músicos, diseñadores y visionarios.")
                        .font(.body).foregroundStyle(.secondary).lineSpacing(4)
                        .padding(.bottom, 36)

                    HStack(spacing: 16) {
                        Button {
                            vm.goToInterests()
                        } label: {
                            HStack(spacing: 8) {
                                Text("Comenzar").fontWeight(.semibold)
                                Image(systemName: "arrow.right").font(.subheadline.bold())
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28).padding(.vertical, 14)
                            .background(Color.piumsOrange)
                            .clipShape(Capsule())
                            .shadow(color: Color.piumsOrange.opacity(0.35), radius: 12, y: 6)
                        }
                        Button("Omitir") { Task { await vm.skip() } }
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 40)

                    SocialProofRow()
                }
                .padding(.horizontal, 28)

                Spacer()

                ArtistFloatingCard().padding(.horizontal, 28).padding(.bottom, 8)

                Spacer(minLength: 12)

                OnboardingDots(current: 0, total: 4).padding(.bottom, 40)
            }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════
// MARK: - Step 2 — Intereses
// ══════════════════════════════════════════════════════════════════════════

private struct OnboardingInterestsStep: View {
    @Bindable var vm: OnboardingViewModel
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(step: "Paso 2 de 4", onBack: { vm.goBack() }, onSkip: { Task { await vm.skip() } })

            ProgressBar(value: 0.5)
                .padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 6) {
                Text("Cuéntanos qué te apasiona").font(.title2.bold())
                Text("Selecciona las áreas que te interesan.\nPersonalizaremos tu experiencia.")
                    .font(.subheadline).foregroundStyle(.secondary).lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24).padding(.bottom, 20)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(OnboardingCategory.all) { cat in
                        CategoryCard(category: cat, isSelected: vm.isSelected(cat.id)) {
                            vm.toggleCategory(cat.id)
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    vm.goToRefine()
                } label: {
                    Text("Continuar →").font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(vm.canContinueFromInterests ? Color.piumsOrange : Color(.systemGray4))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: vm.canContinueFromInterests ? Color.piumsOrange.opacity(0.3) : .clear, radius: 8, y: 4)
                }
                .disabled(!vm.canContinueFromInterests)
                .animation(.easeInOut(duration: 0.2), value: vm.canContinueFromInterests)

                Button("Omitir por ahora") { Task { await vm.skip() } }
                    .font(.subheadline).foregroundStyle(.secondary)

                OnboardingDots(current: 1, total: 4).padding(.top, 4)
            }
            .padding(.horizontal, 24).padding(.vertical, 16).background(.bar)
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════
// MARK: - Step 3 — Afinar gustos
// ══════════════════════════════════════════════════════════════════════════

private struct OnboardingRefineStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(step: "Paso 3 de 4", onBack: { vm.goBack() }, onSkip: { Task { await vm.skip() } })

            ProgressBar(value: 0.75)
                .padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 6) {
                Text("Afina tus gustos").font(.title2.bold())
                Text("Elige géneros y estilos específicos que más te inspiran.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24).padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(vm.categoriesToRefine) { cat in
                        if let sub = OnboardingSubcategory.all[cat.id] {
                            SubcategorySection(
                                category: cat, subcategory: sub,
                                selectedTags: vm.selectedTags[cat.id] ?? [],
                                tagCount: vm.tagCount(catId: cat.id)
                            ) { tag in vm.toggleTag(catId: cat.id, tag: tag) }
                        }
                    }
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    vm.goToIdentity()
                } label: {
                    Text("Continuar →").font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.piumsOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.piumsOrange.opacity(0.3), radius: 8, y: 4)
                }

                Button("Omitir por ahora") { Task { await vm.skip() } }
                    .font(.subheadline).foregroundStyle(.secondary)

                OnboardingDots(current: 2, total: 4).padding(.top, 2)
            }
            .padding(.horizontal, 24).padding(.vertical, 16).background(.bar)
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════
// MARK: - Step 4 — Verificación de identidad
// ══════════════════════════════════════════════════════════════════════════

private struct OnboardingIdentityStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(step: "Paso 4 de 4", onBack: { vm.goBack() }, onSkip: { Task { await vm.skip() } })

            ProgressBar(value: 1.0)
                .padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 6) {
                Text("Verifica tu identidad").font(.title2.bold())
                Text("Requerida para crear reservas. Puedes completarla después desde tu perfil.")
                    .font(.subheadline).foregroundStyle(.secondary).lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24).padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Tipo de documento
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tipo de documento").font(.subheadline.bold())
                        Picker("Tipo", selection: $vm.documentType) {
                            ForEach(DocumentType.allCases, id: \.self) { t in
                                Text(t.label).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Número
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Número de documento").font(.subheadline.bold())
                        TextField("Ej. 2456789012345", text: $vm.documentNumber)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Ciudad
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ciudad de residencia").font(.subheadline.bold())
                        TextField("Ej. Ciudad de Guatemala", text: $vm.ciudad)
                            .padding(12)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Fecha de nacimiento
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fecha de nacimiento").font(.subheadline.bold())
                        DatePicker(
                            "",
                            selection: $vm.birthDate,
                            in: ...Calendar.current.date(byAdding: .year, value: -18, to: Date())!,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(Color.piumsOrange)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Fotografías
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Fotografías").font(.subheadline.bold())

                        HStack(spacing: 10) {
                            DocPhotoButton(
                                label: "Frente",
                                icon: "doc.text.fill",
                                image: vm.docFrontImage,
                                url: vm.docFrontUrl,
                                isLoading: vm.isUploadingFront,
                                isRequired: true
                            ) { data in await vm.uploadFront(data) }

                            if vm.documentType == .dpi {
                                DocPhotoButton(
                                    label: "Dorso",
                                    icon: "doc.fill",
                                    image: vm.docBackImage,
                                    url: vm.docBackUrl,
                                    isLoading: vm.isUploadingBack,
                                    isRequired: false
                                ) { data in await vm.uploadBack(data) }
                            }

                            DocPhotoButton(
                                label: "Selfie",
                                icon: "person.fill.viewfinder",
                                image: vm.docSelfieImage,
                                url: vm.docSelfieUrl,
                                isLoading: vm.isUploadingSelfie,
                                isRequired: true
                            ) { data in await vm.uploadSelfie(data) }
                        }

                        Text("Foto clara del documento. La selfie debe mostrar tu rostro junto al documento.")
                            .font(.caption).foregroundStyle(.secondary).lineSpacing(3)
                    }

                    Color.clear.frame(height: 60)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    Task { await vm.finish() }
                } label: {
                    HStack(spacing: 8) {
                        if vm.isFinishing {
                            ProgressView().tint(.white).scaleEffect(0.85)
                        } else {
                            Text("Ir a la app →").font(.headline)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.piumsOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.piumsOrange.opacity(0.3), radius: 8, y: 4)
                }
                .disabled(vm.isFinishing)

                Button("Completar después") { Task { await vm.skip() } }
                    .font(.subheadline).foregroundStyle(.secondary)

                Text("Puedes cambiar estas preferencias en cualquier momento desde tu perfil.")
                    .font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)

                OnboardingDots(current: 3, total: 4).padding(.top, 2)
            }
            .padding(.horizontal, 24).padding(.vertical, 16).background(.bar)
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════
// MARK: - DocPhotoButton
// ══════════════════════════════════════════════════════════════════════════

private struct DocPhotoButton: View {
    let label: String
    let icon: String
    let image: UIImage?
    let url: String?
    let isLoading: Bool
    let isRequired: Bool
    let onSelect: (Data) async -> Void

    @State private var pickerItem: PhotosPickerItem?

    var isUploaded: Bool { url != nil }

    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(height: 100)
                    .overlay {
                        if let img = image {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text(label)
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                                if isRequired {
                                    Image(systemName: "asterisk")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isUploaded ? Color.piumsOrange.opacity(0.6) :
                                (isRequired ? Color.piumsOrange.opacity(0.3) : Color(.systemGray5)),
                                lineWidth: 1.5
                            )
                    )

                // Badge de estado
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.75)
                        .padding(5)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(6)
                } else if isUploaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 18))
                        .background(Circle().fill(Color(.systemBackground)).padding(2))
                        .padding(6)
                }
            }
            // Label debajo si hay imagen
            if image != nil {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await onSelect(data)
                }
                pickerItem = nil
            }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════
// MARK: - Componentes compartidos
// ══════════════════════════════════════════════════════════════════════════

private struct OnboardingDots: View {
    let current: Int
    let total: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.piumsOrange : Color(.systemGray5))
                    .frame(width: i == current ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.4), value: current)
            }
        }
    }
}

private struct ProgressBar: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray6))
                Capsule().fill(Color.piumsOrange)
                    .frame(width: geo.size.width * value)
                    .animation(.easeInOut(duration: 0.4), value: value)
            }
        }
        .frame(height: 5)
    }
}

private struct OnboardingTopBar: View {
    let step: String
    let onBack: () -> Void
    let onSkip: () -> Void
    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left").font(.title3.bold()).foregroundStyle(.primary)
                    .padding(10).background(Color(.tertiarySystemGroupedBackground)).clipShape(Circle())
            }
            Spacer()
            Text(step).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            Spacer()
            Button("Omitir", action: onSkip).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }
}

private struct CategoryCard: View {
    let category: OnboardingCategory
    let isSelected: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? Color.piumsOrange : Color(.tertiarySystemGroupedBackground))
                            .frame(width: 40, height: 40)
                        Image(systemName: category.systemImage)
                            .font(.system(size: 18))
                            .foregroundStyle(isSelected ? .white : .secondary)
                    }
                    Spacer()
                    if isSelected {
                        ZStack {
                            Circle().fill(Color.piumsOrange).frame(width: 22, height: 22)
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.bottom, 10)
                Text(category.label).font(.subheadline.bold()).foregroundStyle(.primary).lineLimit(2)
                Text(category.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2).padding(.top, 2)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.piumsOrange.opacity(0.08) : Color(.tertiarySystemGroupedBackground))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.piumsOrange : Color.clear, lineWidth: 2))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

private struct SubcategorySection: View {
    let category: OnboardingCategory
    let subcategory: OnboardingSubcategory
    let selectedTags: Set<String>
    let tagCount: Int
    let onToggle: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(Color.piumsOrange.opacity(0.12)).frame(width: 34, height: 34)
                        Image(systemName: category.systemImage).font(.system(size: 16)).foregroundStyle(Color.piumsOrange)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(category.label).font(.caption).foregroundStyle(.secondary)
                        Text(subcategory.sectionLabel).font(.subheadline.bold())
                    }
                }
                Spacer()
                if tagCount > 0 {
                    Text("\(tagCount)").font(.caption.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.piumsOrange).clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
            }
            FlowLayout(spacing: 8) {
                ForEach(subcategory.tags, id: \.self) { tag in
                    let active = selectedTags.contains(tag)
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { onToggle(tag) }
                    } label: {
                        Text(tag).font(.subheadline.weight(.medium))
                            .foregroundStyle(active ? .white : .primary)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(active ? Color.piumsOrange : Color(.tertiarySystemGroupedBackground)))
                            .overlay(Capsule().stroke(active ? Color.clear : Color(.systemGray4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.tertiarySystemGroupedBackground).opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 1))
        )
        .animation(.easeInOut(duration: 0.18), value: tagCount)
    }
}

private struct SocialProofRow: View {
    private let gradients: [[Color]] = [
        [Color(hex: "#f472b6"), Color(hex: "#ec4899")],
        [Color(hex: "#a78bfa"), Color(hex: "#8b5cf6")],
        [Color(hex: "#fb923c"), Color(hex: "#f97316")],
    ]
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: -10) {
                ForEach(0..<3, id: \.self) { i in
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: gradients[i], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        Text(["A","B","C"][i]).font(.caption.bold()).foregroundStyle(.white)
                    }
                }
            }
            Text("Más de **10,000** creativos ya crecen con nosotros")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct ArtistFloatingCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                Image(systemName: "guitars.fill").font(.title2).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Carlos M.").font(.subheadline.bold())
                Text("Música en Vivo · Guatemala").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                    Text("4.9").font(.caption.bold())
                }
            }
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.piumsOrange)
                Text("Verificado").font(.caption2).foregroundStyle(Color.piumsOrange)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.tertiarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
        )
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            rowH = max(rowH, size.height); x += size.width + spacing
        }
        return CGSize(width: width, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowH = max(rowH, size.height); x += size.width + spacing
        }
    }
}

#Preview { OnboardingView { } }
