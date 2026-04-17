// TalentPickerView.swift — Taxonomía de talentos idéntica a la web
import SwiftUI

// MARK: - Models

struct Talent: Identifiable {
    let id: String
    let label: String
    let category: String
}

struct TalentSubCategory: Identifiable {
    let id: String
    let label: String
    let talents: [Talent]
}

struct TalentGroup: Identifiable {
    let id: String
    let label: String
    let icon: String   // SF Symbol name
    let subCategories: [TalentSubCategory]
}

// MARK: - Taxonomy (same as web TalentPicker.tsx)

let TALENT_GROUPS: [TalentGroup] = [
    TalentGroup(id: "musica_audio", label: "Música & Audio", icon: "music.note.list", subCategories: [
        TalentSubCategory(id: "musico", label: "Músico", talents: [
            Talent(id: "cantante_solista",  label: "Cantante Solista",    category: "MUSICO"),
            Talent(id: "banda_musical",     label: "Banda Musical",       category: "MUSICO"),
            Talent(id: "mariachi",          label: "Mariachi",            category: "MUSICO"),
            Talent(id: "grupo_acustico",    label: "Grupo Acústico",      category: "MUSICO"),
            Talent(id: "trio_cuarteto",     label: "Trío / Cuarteto",     category: "MUSICO"),
            Talent(id: "pianista",          label: "Pianista",            category: "MUSICO"),
            Talent(id: "guitarrista",       label: "Guitarrista",         category: "MUSICO"),
            Talent(id: "violinista",        label: "Violinista",          category: "MUSICO"),
            Talent(id: "baterista",         label: "Baterista",           category: "MUSICO"),
            Talent(id: "saxofonista",       label: "Saxofonista",         category: "MUSICO"),
            Talent(id: "marimba",           label: "Marimba",             category: "MUSICO"),
        ]),
        TalentSubCategory(id: "produccion_audio", label: "Producción & Audio", talents: [
            Talent(id: "productor_musical", label: "Productor Musical",   category: "MUSICO"),
            Talent(id: "beatmaker",         label: "Beatmaker",           category: "DJ"),
            Talent(id: "rapero_freestyle",  label: "Rapero / Freestyle",  category: "MUSICO"),
            Talent(id: "ingeniero_sonido",  label: "Ingeniero de Sonido", category: "MUSICO"),
            Talent(id: "locutor_voiceover", label: "Locutor / Voice Over",category: "MUSICO"),
        ]),
        TalentSubCategory(id: "dj", label: "DJ", talents: [
            Talent(id: "dj_bodas",      label: "DJ para Bodas",   category: "DJ"),
            Talent(id: "dj_corporativo",label: "DJ Corporativo",  category: "DJ"),
            Talent(id: "dj_electronica",label: "DJ Electrónica",  category: "DJ"),
            Talent(id: "dj_generalista",label: "DJ Eventos",      category: "DJ"),
        ]),
    ]),
    TalentGroup(id: "audiovisual", label: "Producción Audiovisual", icon: "camera.fill", subCategories: [
        TalentSubCategory(id: "fotografia", label: "Fotografía", talents: [
            Talent(id: "fotografo_eventos",  label: "Fotógrafo de Eventos",  category: "FOTOGRAFO"),
            Talent(id: "fotografo_retrato",  label: "Fotógrafo de Retrato",  category: "FOTOGRAFO"),
            Talent(id: "fotografo_producto", label: "Fotógrafo de Producto", category: "FOTOGRAFO"),
            Talent(id: "fotografo_boda",     label: "Fotógrafo de Bodas",    category: "FOTOGRAFO"),
        ]),
        TalentSubCategory(id: "video", label: "Video", talents: [
            Talent(id: "videografo",           label: "Videógrafo",           category: "VIDEOGRAFO"),
            Talent(id: "editor_video",         label: "Editor de Video",      category: "VIDEOGRAFO"),
            Talent(id: "director_audiovisual", label: "Director Audiovisual", category: "VIDEOGRAFO"),
            Talent(id: "drone_operator",       label: "Drone Operator",       category: "VIDEOGRAFO"),
            Talent(id: "streaming",            label: "Streaming / En Vivo",  category: "VIDEOGRAFO"),
        ]),
    ]),
    TalentGroup(id: "diseno_arte", label: "Diseño & Arte Visual", icon: "paintpalette.fill", subCategories: [
        TalentSubCategory(id: "diseno_grafico", label: "Diseño Gráfico", talents: [
            Talent(id: "disenador_grafico", label: "Diseñador Gráfico",    category: "DISENADOR"),
            Talent(id: "disenador_uxui",    label: "Diseñador UX/UI",      category: "DISENADOR"),
            Talent(id: "branding",          label: "Branding / Identidad", category: "DISENADOR"),
            Talent(id: "ilustrador",        label: "Ilustrador",           category: "PINTOR"),
            Talent(id: "motion_graphics",   label: "Motion Graphics",      category: "DISENADOR"),
        ]),
        TalentSubCategory(id: "arte_fisico", label: "Arte Físico", talents: [
            Talent(id: "pintor",    label: "Pintor / Artista", category: "PINTOR"),
            Talent(id: "escultor",  label: "Escultor",         category: "ESCULTOR"),
            Talent(id: "caligrafo", label: "Calígrafo",        category: "PINTOR"),
            Talent(id: "artesano",  label: "Artesano",         category: "PINTOR"),
        ]),
    ]),
    TalentGroup(id: "artes_escenicas", label: "Artes Escénicas", icon: "theatermasks.fill", subCategories: [
        TalentSubCategory(id: "danza", label: "Danza", talents: [
            Talent(id: "bailarin_urbano",   label: "Bailarín Urbano",    category: "BAILARIN"),
            Talent(id: "bailarin_clasico",  label: "Bailarín Clásico",   category: "BAILARIN"),
            Talent(id: "coreografo",        label: "Coreógrafo",         category: "BAILARIN"),
            Talent(id: "danza_folklorica",  label: "Danza Folklórica",   category: "BAILARIN"),
        ]),
        TalentSubCategory(id: "actuacion", label: "Actuación", talents: [
            Talent(id: "actor_actriz", label: "Actor / Actriz",    category: "ANIMADOR"),
            Talent(id: "teatro",       label: "Teatro",            category: "ANIMADOR"),
            Talent(id: "mimo",         label: "Mimo / Performance",category: "ANIMADOR"),
        ]),
    ]),
    TalentGroup(id: "eventos_entretenimiento", label: "Eventos & Entretenimiento", icon: "party.popper.fill", subCategories: [
        TalentSubCategory(id: "hosting", label: "Hosting & Animación", talents: [
            Talent(id: "animador_mc",      label: "Animador / MC",      category: "ANIMADOR"),
            Talent(id: "host_eventos",     label: "Host de Eventos",    category: "ANIMADOR"),
            Talent(id: "comedian_standup", label: "Stand-up Comedian",  category: "ANIMADOR"),
            Talent(id: "show_infantil",    label: "Shows Infantiles",   category: "ANIMADOR"),
        ]),
        TalentSubCategory(id: "shows_especiales", label: "Shows Especiales", talents: [
            Talent(id: "mago_ilusionista",  label: "Mago / Ilusionista",    category: "MAGO"),
            Talent(id: "acrobata",          label: "Acróbata",              category: "ACROBATA"),
            Talent(id: "show_fuego",        label: "Show de Fuego",         category: "ACROBATA"),
            Talent(id: "animacion_fiestas", label: "Animación de Fiestas",  category: "ANIMADOR"),
        ]),
    ]),
    TalentGroup(id: "cultura_tradicion", label: "Cultura & Tradición", icon: "building.columns.fill", subCategories: [
        TalentSubCategory(id: "musica_tradicional", label: "Música Tradicional", talents: [
            Talent(id: "marimba_orquesta",      label: "Marimba Orquesta",     category: "MUSICO"),
            Talent(id: "mariachi_tradicional",  label: "Mariachi Tradicional", category: "MUSICO"),
            Talent(id: "musico_regional",       label: "Músico Regional",      category: "MUSICO"),
        ]),
        TalentSubCategory(id: "danza_cultural", label: "Danza Cultural", talents: [
            Talent(id: "danza_folklorica_trad", label: "Danza Folklórica", category: "BAILARIN"),
            Talent(id: "danza_indigena",        label: "Danza Indígena",   category: "BAILARIN"),
        ]),
    ]),
    TalentGroup(id: "educacion_creativa", label: "Educación Creativa", icon: "graduationcap.fill", subCategories: [
        TalentSubCategory(id: "docencia_artistica", label: "Docencia Artística", talents: [
            Talent(id: "profesor_musica",  label: "Profesor de Música",  category: "MUSICO"),
            Talent(id: "clases_canto",     label: "Clases de Canto",     category: "MUSICO"),
            Talent(id: "clases_pintura",   label: "Clases de Pintura",   category: "PINTOR"),
            Talent(id: "taller_creativo",  label: "Talleres Creativos",  category: "OTRO"),
            Talent(id: "coaching_vocal",   label: "Coaching Vocal",      category: "MUSICO"),
        ]),
    ]),
    TalentGroup(id: "contenido_digital", label: "Contenido Digital", icon: "iphone.gen3", subCategories: [
        TalentSubCategory(id: "escritura", label: "Escritura & Guiones", talents: [
            Talent(id: "escritor",      label: "Escritor",         category: "ESCRITOR"),
            Talent(id: "guionista",     label: "Guionista",        category: "ESCRITOR"),
            Talent(id: "letrista",      label: "Letrista",         category: "ESCRITOR"),
            Talent(id: "copywriter",    label: "Copy Creativo",    category: "ESCRITOR"),
            Talent(id: "storyteller",   label: "Storyteller",      category: "ESCRITOR"),
        ]),
        TalentSubCategory(id: "social_media", label: "Social Media", talents: [
            Talent(id: "creador_contenido", label: "Creador de Contenido", category: "OTRO"),
            Talent(id: "tiktoker",          label: "TikToker / Reels",     category: "OTRO"),
            Talent(id: "youtuber",          label: "YouTuber",             category: "VIDEOGRAFO"),
        ]),
    ]),
    TalentGroup(id: "belleza_estilo", label: "Belleza & Estilo", icon: "sparkles", subCategories: [
        TalentSubCategory(id: "maquillaje", label: "Maquillaje & Beauty", talents: [
            Talent(id: "maquillador_eventos", label: "Maquillador/a Eventos",   category: "MAQUILLADOR"),
            Talent(id: "maquillaje_novia",    label: "Especialista en Novias",  category: "MAQUILLADOR"),
            Talent(id: "body_paint",          label: "Body Paint Artist",       category: "MAQUILLADOR"),
            Talent(id: "estilista",           label: "Estilista",               category: "MAQUILLADOR"),
            Talent(id: "barbero_pro",         label: "Barbero Profesional",     category: "MAQUILLADOR"),
        ]),
        TalentSubCategory(id: "tatuaje", label: "Tatuaje & Body Art", talents: [
            Talent(id: "tatuador",           label: "Tatuador",             category: "TATUADOR"),
            Talent(id: "tattoo_realista",    label: "Tattoo Realista",      category: "TATUADOR"),
            Talent(id: "tattoo_minimalista", label: "Tattoo Minimalista",   category: "TATUADOR"),
            Talent(id: "piercing_artist",    label: "Piercing Artist",      category: "TATUADOR"),
        ]),
    ]),
    TalentGroup(id: "experiencias_creativas", label: "Experiencias Creativas", icon: "star.fill", subCategories: [
        TalentSubCategory(id: "eventos_especiales", label: "Eventos Especiales", talents: [
            Talent(id: "chef_creativo",        label: "Chef Creativo",           category: "OTRO"),
            Talent(id: "bartender_show",       label: "Bartender Show",          category: "OTRO"),
            Talent(id: "decorador_eventos",    label: "Decorador de Eventos",    category: "OTRO"),
            Talent(id: "wedding_planner",      label: "Wedding Planner",         category: "OTRO"),
            Talent(id: "banda_boda",           label: "Banda para Bodas",        category: "MUSICO"),
        ]),
    ]),
]

// MARK: - TalentPickerView

struct TalentPickerView: View {
    @Binding var selectedTalentId: String?
    let onSelect: (Talent) -> Void
    let onClear: () -> Void

    @State private var expandedGroupId: String? = TALENT_GROUPS.first?.id

    private var selectedTalent: Talent? {
        guard let id = selectedTalentId else { return nil }
        return TALENT_GROUPS.flatMap { $0.subCategories.flatMap { $0.talents } }.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Título
            VStack(alignment: .leading, spacing: 4) {
                Text("¿Cuál es tu superpoder creativo?")
                    .font(.title3.bold())
                Text("Elige un talento para encontrar al profesional perfecto")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Badge del talento seleccionado
            if let talent = selectedTalent {
                HStack(spacing: 8) {
                    Text("Seleccionado:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(talent.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Button(action: onClear) {
                            Image(systemName: "xmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.piumsOrange)
                    .clipShape(Capsule())
                }
                .padding(.horizontal)
            }

            // Grupos acordeón
            VStack(spacing: 6) {
                ForEach(TALENT_GROUPS) { group in
                    TalentGroupRow(
                        group: group,
                        isExpanded: expandedGroupId == group.id,
                        selectedTalentId: selectedTalentId,
                        onTapHeader: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedGroupId = expandedGroupId == group.id ? nil : group.id
                            }
                        },
                        onSelectTalent: { talent in
                            selectedTalentId = talent.id
                            onSelect(talent)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - TalentGroupRow

private struct TalentGroupRow: View {
    let group: TalentGroup
    let isExpanded: Bool
    let selectedTalentId: String?
    let onTapHeader: () -> Void
    let onSelectTalent: (Talent) -> Void

    private var hasSelected: Bool {
        guard let id = selectedTalentId else { return false }
        return group.subCategories.flatMap { $0.talents }.contains { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onTapHeader) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(hasSelected ? Color.piumsOrange : Color.piumsOrange.opacity(0.12))
                            .frame(width: 30, height: 30)
                        Image(systemName: group.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(hasSelected ? .white : Color.piumsOrange)
                    }
                    Text(group.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if hasSelected {
                        Circle()
                            .fill(Color.piumsOrange)
                            .frame(width: 7, height: 7)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 0 : 12,
                                            style: .continuous))
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(group.subCategories) { sub in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(sub.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            FlexWrap(items: sub.talents, id: \.id) { talent in
                                TalentChip(
                                    label: talent.label,
                                    isSelected: selectedTalentId == talent.id,
                                    onTap: { onSelectTalent(talent) }
                                )
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color(.tertiarySystemBackground))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(hasSelected ? Color.piumsOrange.opacity(0.4) : Color(.separator).opacity(0.3), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

// MARK: - TalentChip

private struct TalentChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(isSelected ? Color.piumsOrange : Color(.tertiarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? Color.piumsOrange : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - FlexWrap layout (same as FlowLayout)

private struct FlexWrap<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let id: KeyPath<Item, String>
    let content: (Item) -> Content

    var body: some View {
        _FlexLayout(items: items, id: id, content: content)
    }
}

private struct _FlexLayout<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let id: KeyPath<Item, String>
    let content: (Item) -> Content

    var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func generateContent(in geo: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        var lastHeight = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                content(item)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geo.size.width {
                            width = 0
                            height -= lastHeight
                        }
                        lastHeight = d.height
                        let result = width
                        if item[keyPath: id] == items.last?[keyPath: id] { width = 0 }
                        else { width -= d.width + 6 }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item[keyPath: id] == items.last?[keyPath: id] { height = 0 }
                        return result
                    }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            TalentPickerView(selectedTalentId: .constant(nil), onSelect: { _ in }, onClear: {})
        }
    }
}
