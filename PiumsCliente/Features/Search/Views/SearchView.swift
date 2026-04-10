// SearchView.swift
import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var selectedArtist: Artist?
    @State private var showFilters = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // ── Barra de búsqueda — FUERA del ScrollView para que no se mueva ──
            searchBar
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)  // blur material igual que toolbar

            // Chips de filtros activos
            if viewModel.hasActiveFilters {
                activeFiltersBar
                    .padding(.bottom, 6)
                    .background(.bar)
            }

            Divider()

            // ── Contenido scrollable ──
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.isLoading && viewModel.results.isEmpty {
                        LoadingView()
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else if !viewModel.hasSearched {
                        SearchSuggestionsView { suggestion in
                            viewModel.query = suggestion
                            Task { await viewModel.search() }
                        }
                        .padding(.top, 8)
                    } else if viewModel.results.isEmpty {
                        EmptyStateView(
                            systemImage: "magnifyingglass",
                            title: "Sin resultados",
                            description: "No encontramos artistas con ese término."
                        )
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .padding(.top, 40)
                    } else {
                        Text("\(viewModel.results.count) resultado(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        ForEach(viewModel.results) { artist in
                            ArtistCardView(artist: artist)
                                .padding(.horizontal)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedArtist = artist }
                                .task { await viewModel.loadNextIfNeeded(currentItem: artist) }
                        }

                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        }

                        Color.clear.frame(height: 12)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Buscar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .navigationDestination(item: $selectedArtist) { ArtistProfileView(artist: $0) }
        .sheet(isPresented: $showFilters) {
            SearchFiltersSheet(viewModel: viewModel) {
                Task { await viewModel.search() }
            }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Buscar artistas...", text: $viewModel.query)
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit { Task { await viewModel.search() } }
                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.query = ""
                        viewModel.results = []
                        viewModel.hasSearched = false
                        searchFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                searchFocused = false
                showFilters = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    if viewModel.hasActiveFilters {
                        Circle()
                            .fill(Color.piumsOrange)
                            .frame(width: 10, height: 10)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
    }

    // MARK: - Active filters bar

    private var activeFiltersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let cat = viewModel.selectedCategory {
                    FilterChip(label: cat.displayName) { viewModel.selectedCategory = nil }
                }
                if viewModel.minRating > 0 {
                    FilterChip(label: "★ \(String(format: "%.1f", viewModel.minRating))+") {
                        viewModel.minRating = 0
                    }
                }
                if viewModel.maxPrice < 5000 {
                    FilterChip(label: "Hasta Q\(Int(viewModel.maxPrice))") {
                        viewModel.maxPrice = 5000
                    }
                }
                if let city = viewModel.selectedCity {
                    FilterChip(label: city) { viewModel.selectedCity = nil }
                }
                Button("Limpiar todo") { viewModel.clearFilters() }
                    .font(.caption)
                    .foregroundStyle(Color.piumsOrange)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - FilterChip

private struct FilterChip: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.caption.weight(.medium))
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.caption2)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.piumsOrange.opacity(0.12))
        .foregroundStyle(Color.piumsOrange)
        .clipShape(Capsule())
    }
}

// MARK: - SearchSuggestionsView

private struct SearchSuggestionsView: View {
    let onSelect: (String) -> Void
    private let suggestions = ["Músico", "Bailarín", "DJ", "Fotógrafo", "Mago", "Animador"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sugerencias")
                .font(.headline)
                .padding(.horizontal)
            FlowLayout(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Button(s) { onSelect(s) }
                        .buttonStyle(.bordered)
                        .tint(.piumsOrange)
                }
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical)
    }
}

// MARK: - FlowLayout simple

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: ProposedViewSize(bounds.size), subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        let maxW = proposal.width ?? .infinity
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxW && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        return (CGSize(width: maxW, height: y + rowH), frames)
    }
}

// MARK: - SearchFiltersSheet

struct SearchFiltersSheet: View {
    @Bindable var viewModel: SearchViewModel
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Categoría") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ArtistCategory.allCases, id: \.self) { cat in
                                Button(cat.displayName) {
                                    viewModel.selectedCategory = viewModel.selectedCategory == cat ? nil : cat
                                }
                                .buttonStyle(.bordered)
                                .tint(viewModel.selectedCategory == cat ? .piumsOrange : .secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("Precio máximo: Q\(Int(viewModel.maxPrice))") {
                    Slider(value: $viewModel.maxPrice, in: 100...5000, step: 100)
                        .tint(.piumsOrange)
                }
                Section("Rating mínimo: \(String(format: "%.1f", viewModel.minRating)) ★") {
                    Slider(value: $viewModel.minRating, in: 0...5, step: 0.5)
                        .tint(.piumsOrange)
                }
                Section("Ciudad") {
                    Picker("Ciudad", selection: $viewModel.selectedCity) {
                        Text("Todas").tag(String?.none)
                        ForEach(viewModel.cities, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                }
                Section {
                    Button("Limpiar filtros", role: .destructive) { viewModel.clearFilters() }
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") { onApply(); dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.piumsOrange)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { SearchView() }
}
