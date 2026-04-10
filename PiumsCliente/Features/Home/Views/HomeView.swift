// HomeView.swift
import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var selectedArtist: Artist?
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ScrollView {
            // Tracking de scroll offset
            GeometryReader { geo in
                Color.clear
                    .preference(key: ScrollOffsetKey.self,
                                value: geo.frame(in: .named("homeScroll")).minY)
            }
            .frame(height: 0)

            VStack(alignment: .leading, spacing: 0) {
                // Header — se encoge al hacer scroll
                headerSection
                    .padding(.bottom, 12)

                // Categorías — sticky bajo el header
                categoryBar
                    .padding(.bottom, 12)

                // Error
                if let msg = viewModel.errorMessage {
                    ErrorBannerView(message: msg)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                // Lista
                artistList
            }
        }
        .coordinateSpace(name: "homeScroll")
        .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.loadInitial() }
        .task { await viewModel.loadInitial() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Piums")
                    .font(.headline.bold())
                    .opacity(scrollOffset < -60 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: scrollOffset)
            }
        }
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .navigationDestination(item: $selectedArtist) { ArtistProfileView(artist: $0) }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hola 👋")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Descubre artistas")
                .font(.title.bold())
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .opacity(scrollOffset < -60 ? max(0, 1 + (scrollOffset + 60) / 40) : 1)
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryChip(
                    title: "Todos",
                    systemImage: "square.grid.2x2",
                    isSelected: viewModel.selectedCategory == nil
                ) { Task { await viewModel.selectCategory(nil) } }

                ForEach(viewModel.categories, id: \.self) { cat in
                    CategoryChip(
                        title: cat.displayName,
                        systemImage: cat.systemImage,
                        isSelected: viewModel.selectedCategory == cat
                    ) { Task { await viewModel.selectCategory(cat) } }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var artistList: some View {
        if viewModel.isLoading && viewModel.artists.isEmpty {
            LoadingView()
                .frame(height: 300)
        } else if viewModel.artists.isEmpty {
            EmptyStateView(
                systemImage: "person.2.slash",
                title: "Sin artistas",
                description: "No encontramos artistas en esta categoría."
            )
            .frame(height: 300)
        } else {
            LazyVStack(spacing: 14) {
                ForEach(viewModel.artists) { artist in
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
                // Espacio para tab bar
                Color.clear.frame(height: 12)
            }
        }
    }
}

// MARK: - ScrollOffsetKey

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - CategoryChip

private struct CategoryChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.caption)
                Text(title).font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.piumsOrange : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    NavigationStack { HomeView() }
}
