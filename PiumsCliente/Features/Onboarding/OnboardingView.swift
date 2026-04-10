// OnboardingView.swift — 3 pasos: Bienvenida · Intereses · Afinar gustos
import SwiftUI

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
                        removal:   .move(edge: .trailing)
                    ))
            }
        }
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
                        Image(systemName: "music.note.house.fill")
                            .font(.title3)
                            .foregroundStyle(Color.piumsOrange)
                        Text("Piums").font(.title3.bold())
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

                OnboardingDots(current: 0, total: 3).padding(.bottom, 40)
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
            OnboardingTopBar(step: "Paso 2 de 3", onBack: { vm.goBack() }, onSkip: { Task { await vm.skip() } })

            ProgressBar(value: 0.66)
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

                OnboardingDots(current: 1, total: 3).padding(.top, 4)
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
            OnboardingTopBar(step: "Paso 3 de 3", onBack: { vm.goBack() }, onSkip: { Task { await vm.skip() } })

            ProgressBar(value: 1.0)
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

                Button("Omitir por ahora") { Task { await vm.skip() } }
                    .font(.subheadline).foregroundStyle(.secondary)

                Text("Puedes cambiar estas preferencias en cualquier momento desde Configuración.")
                    .font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)

                OnboardingDots(current: 2, total: 3).padding(.top, 2)
            }
            .padding(.horizontal, 24).padding(.vertical, 16).background(.bar)
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
                    .padding(10).background(Color(.secondarySystemBackground)).clipShape(Circle())
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
                            .fill(isSelected ? Color.piumsOrange : Color(.secondarySystemBackground))
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
                    .fill(isSelected ? Color.piumsOrange.opacity(0.08) : Color(.secondarySystemBackground))
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
                            .background(Capsule().fill(active ? Color.piumsOrange : Color(.secondarySystemBackground)))
                            .overlay(Capsule().stroke(active ? Color.clear : Color(.systemGray4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground).opacity(0.5))
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
                Text("🎸").font(.title2)
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
                .fill(Color(.secondarySystemBackground))
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
