// HomeView.swift
import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var selectedArtist: Artist?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Saludo
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hola 👋")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Descubre artistas")
                        .font(.title.bold())
                }
                .padding(.horizontal)

                // Categorías
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        CategoryChip(
                            title: "Todos",
                            systemImage: "square.grid.2x2",
                            isSelected: viewModel.selectedCategory == nil
                        ) {
                            Task { await viewModel.selectCategory(nil) }
                        }
                        ForEach(viewModel.categories, id: \.self) { cat in
                            CategoryChip(
                                title: cat.displayName,
                                systemImage: cat.systemImage,
                                isSelected: viewModel.selectedCategory == cat
                            ) {
                                Task { await viewModel.selectCategory(cat) }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Error banner
                if let msg = viewModel.errorMessage {
                    ErrorBannerView(message: msg)
                        .padding(.horizontal)
                }

                // Lista de artistas
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
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.artists) { artist in
                            ArtistCardView(artist: artist)
                                .padding(.horizontal)
                                .onTapGesture { selectedArtist = artist }
                                .task { await viewModel.loadNextIfNeeded(currentItem: artist) }
                        }
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.loadInitial() }
        .navigationDestination(item: $selectedArtist) { artist in
            ArtistProfileView(artist: artist)
        }
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
                Image(systemName: systemImage)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.weight(.medium))
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
