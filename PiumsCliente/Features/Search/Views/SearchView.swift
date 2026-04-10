// SearchView.swift
import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var selectedArtist: Artist?
    @State private var showFilters = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading && viewModel.results.isEmpty {
                    LoadingView().frame(maxWidth: .infinity, minHeight: 300)

                } else if !viewModel.hasSearched {
                    TalentPickerView(
                        selectedTalentId: $viewModel.selectedTalentId,
                        onSelect: { talent in searchFocused = false; viewModel.selectTalent(talent) },
                        onClear: { viewModel.clearTalent() }
                    )
                    .padding(.top, 8)

                } else if viewModel.results.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "Sin resultados",
                        description: "Intenta con otro término o ajusta los filtros."
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .padding(.top, 40)

                } else {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(viewModel.results.count) resultado(s)")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            if viewModel.isSmartSearch {
                                Label("SmartSearch", systemImage: "sparkles")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.piumsOrange)
                            } else if viewModel.sortOption != .relevance {
                                Text(viewModel.sortOption.displayName)
                                    .font(.caption).foregroundStyle(Color.piumsOrange)
                            }
                        }
                        if !viewModel.expandedTerms.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    Text("También buscamos:")
                                        .font(.caption).foregroundStyle(.secondary)
                                    ForEach(viewModel.expandedTerms, id: \.self) { term in
                                        Text(term)
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 8).padding(.vertical, 4)
                                            .background(Color.piumsOrange.opacity(0.10))
                                            .foregroundStyle(Color.piumsOrange)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Grid 2 columnas — igual que la web
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(viewModel.results) { artist in
                            let matched = viewModel.isSmartSearch
                                ? viewModel.smartResults.first(where: { $0.id == artist.id })?.matchedService
                                : nil
                            ArtistCardView(artist: artist, matchedService: matched)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedArtist = artist }
                                .task { await viewModel.loadNextIfNeeded(currentItem: artist) }
                        }
                    }
                    .padding(.horizontal)

                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    }
                    Color.clear.frame(height: 12)
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                searchBar.padding(.horizontal).padding(.vertical, 10)
                if viewModel.hasActiveFilters { activeFiltersBar.padding(.bottom, 6) }
                Divider()
            }
            .background(.bar)
        }
        .navigationTitle("Explorar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .navigationDestination(item: $selectedArtist) { ArtistProfileView(artist: $0) }
        .sheet(isPresented: $showFilters) {
            SearchFiltersSheet(viewModel: viewModel) { Task { await viewModel.search() } }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Buscar artistas...", text: $viewModel.query)
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit { Task { await viewModel.search() } }
                    .onChange(of: viewModel.query) { _, v in if v.isEmpty { viewModel.clearTalent() } }
                if !viewModel.query.isEmpty {
                    Button { viewModel.clearTalent(); searchFocused = false } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button { searchFocused = false; showFilters = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3).padding(12)
                        .background(viewModel.hasActiveFilters ? Color.piumsOrange.opacity(0.15) : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    if viewModel.hasActiveFilters {
                        Circle().fill(Color.piumsOrange).frame(width: 10, height: 10).offset(x: 2, y: -2)
                    }
                }
            }
            .foregroundStyle(viewModel.hasActiveFilters ? Color.piumsOrange : .primary)
        }
    }

    private var activeFiltersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let sp = viewModel.selectedSpecialty {
                    FilterChip(label: sp.rawValue) { viewModel.selectedSpecialty = nil; Task { await viewModel.search() } }
                }
                if viewModel.minRating > 0 {
                    FilterChip(label: "★ \(String(format: "%.1f", viewModel.minRating))+") { viewModel.minRating = 0; Task { await viewModel.search() } }
                }
                if viewModel.minPrice > 0 {
                    FilterChip(label: "Desde Q\(Int(viewModel.minPrice))") { viewModel.minPrice = 0; Task { await viewModel.search() } }
                }
                if viewModel.maxPrice < 50000 {
                    FilterChip(label: "Hasta Q\(Int(viewModel.maxPrice))") { viewModel.maxPrice = 50000; Task { await viewModel.search() } }
                }
                if let city = viewModel.selectedCity {
                    FilterChip(label: city) { viewModel.selectedCity = nil; Task { await viewModel.search() } }
                }
                if viewModel.isVerified {
                    FilterChip(label: "✓ Verificados") { viewModel.isVerified = false; Task { await viewModel.search() } }
                }
                if viewModel.sortOption != .relevance {
                    FilterChip(label: viewModel.sortOption.displayName) { viewModel.sortOption = .relevance; Task { await viewModel.search() } }
                }
                Button("Limpiar todo") { viewModel.clearFilters(); Task { await viewModel.search() } }
                    .font(.caption).foregroundStyle(Color.piumsOrange)
            }
            .padding(.horizontal)
        }
    }
}

private struct FilterChip: View {
    let label: String; let onRemove: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.caption.weight(.medium))
            Button(action: onRemove) { Image(systemName: "xmark").font(.caption2) }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.piumsOrange.opacity(0.12))
        .foregroundStyle(Color.piumsOrange)
        .clipShape(Capsule())
    }
}

struct SearchFiltersSheet: View {
    @Bindable var viewModel: SearchViewModel
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    filterSection(title: "Especialidad") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                            ForEach(SpecialtyOption.allCases) { sp in
                                Button {
                                    viewModel.selectedSpecialty = viewModel.selectedSpecialty == sp ? nil : sp
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: sp.icon).font(.title3)
                                        Text(sp.rawValue).font(.caption2).lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(viewModel.selectedSpecialty == sp ? Color.piumsOrange : Color(.tertiarySystemBackground))
                                    .foregroundStyle(viewModel.selectedSpecialty == sp ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Divider()
                    filterSection(title: "Rango de precio (Q)") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Mínimo: Q\(Int(viewModel.minPrice))").font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Text("Máximo: Q\(viewModel.maxPrice >= 50000 ? "Sin límite" : String(Int(viewModel.maxPrice)))").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Slider(value: $viewModel.minPrice, in: 0...49000, step: 100).tint(.piumsOrange)
                            Slider(value: $viewModel.maxPrice, in: 1000...50000, step: 100).tint(.piumsOrange)
                        }
                    }
                    Divider()
                    filterSection(title: "Calificación mínima") {
                        HStack(spacing: 6) {
                            ForEach([0.0, 3.0, 3.5, 4.0, 4.5, 5.0], id: \.self) { r in
                                Button {
                                    viewModel.minRating = viewModel.minRating == r ? 0 : r
                                } label: {
                                    Text(r == 0 ? "Todos" : "\(String(format: "%.1f", r))★")
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 10).padding(.vertical, 7)
                                        .background(viewModel.minRating == r ? Color.piumsOrange : Color(.tertiarySystemBackground))
                                        .foregroundStyle(viewModel.minRating == r ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Divider()
                    filterSection(title: "Ciudad") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                            ForEach(viewModel.cities, id: \.self) { city in
                                Button {
                                    viewModel.selectedCity = viewModel.selectedCity == city ? nil : city
                                } label: {
                                    Text(city).font(.subheadline).lineLimit(1)
                                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                                        .background(viewModel.selectedCity == city ? Color.piumsOrange : Color(.tertiarySystemBackground))
                                        .foregroundStyle(viewModel.selectedCity == city ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Divider()
                    filterSection(title: "Ordenar por") {
                        VStack(spacing: 0) {
                            ForEach(SearchSortOption.allCases, id: \.self) { opt in
                                Button {
                                    viewModel.sortOption = opt
                                } label: {
                                    HStack {
                                        Text(opt.displayName).font(.subheadline)
                                        Spacer()
                                        if viewModel.sortOption == opt {
                                            Image(systemName: "checkmark").foregroundStyle(Color.piumsOrange)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                if opt != SearchSortOption.allCases.last { Divider() }
                            }
                        }
                    }
                    Divider()
                    filterSection(title: "Solo verificados") {
                        Toggle("Mostrar solo artistas verificados", isOn: $viewModel.isVerified).tint(.piumsOrange)
                    }
                    Button(role: .destructive) { viewModel.clearFilters() } label: {
                        Text("Limpiar todos los filtros")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") { onApply(); dismiss() }
                        .fontWeight(.bold).foregroundStyle(Color.piumsOrange)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func filterSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content()
        }
    }
}

#Preview { NavigationStack { SearchView() } }
