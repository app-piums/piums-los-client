// ArtistProfileView.swift
import SwiftUI
import CoreLocation

struct ArtistProfileView: View {
    let artist: Artist
    @State private var viewModel: ArtistProfileViewModel
    @State private var selectedTab: ProfileTab = .services
    @State private var bookingService: ArtistService?
    @State private var showBooking = false
    @State private var favorites = FavoritesStore.shared
    @State private var showFavError = false
    @Environment(\.locationStore) private var locationStore

    enum ProfileTab: String, CaseIterable {
        case services  = "Servicios"
        case portfolio = "Portafolio"
        case reviews   = "Reseñas"
        case about     = "Acerca de"
    }

    init(artist: Artist) {
        self.artist = artist
        _viewModel = State(initialValue: ArtistProfileViewModel(artist: artist))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                coverAndAvatar
                artistInfo
                tabSelector
                Divider()
                tabContent
                    .padding(.top, 4)
                Spacer().frame(height: 30)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await favorites.toggle(artist: artist) }
                } label: {
                    Image(systemName: favorites.isFavorite(artist.id) ? "heart.fill" : "heart")
                        .foregroundStyle(Color.piumsOrange)
                }
            }
        }
        .task { await viewModel.loadAll() }
        .onChange(of: favorites.errorMessage) { _, msg in showFavError = msg != nil }
        .alert("No se pudo actualizar favoritos", isPresented: $showFavError) {
            Button("OK") { favorites.errorMessage = nil }
        } message: {
            Text(favorites.errorMessage ?? "")
        }
        .sheet(isPresented: $showBooking) {
            if let svc = bookingService {
                let coord = locationStore.coordinate
                NavigationStack {
                    BookingFlowView(context: BookingFlowContext(
                        artist: artist,
                        service: svc,
                        location: locationStore.cityName,
                        locationLat: coord?.latitude,
                        locationLng: coord?.longitude
                    ))
                }
            }
        }
    }

    // MARK: - Cover + Avatar

    private var coverAndAvatar: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.piumsOrange, Color(red: 0.80, green: 0.28, blue: 0.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 190)

            Group {
                let url = viewModel.avatarURL ?? artist.avatarUrl
                if let url, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: avatarPlaceholder
                        }
                    }
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            .offset(x: 20, y: 44)
        }
        .frame(height: 190)
        .clipped()
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Color.piumsOrange.opacity(0.25)
            Text(String(artist.artistName.prefix(2)).uppercased())
                .font(.title2.bold())
                .foregroundStyle(Color.piumsOrange)
        }
    }

    // MARK: - Artist info

    private var artistInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer().frame(height: 52)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(artist.artistName)
                    .font(.title2.bold())
                if artist.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.piumsOrange)
                        .font(.headline)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                if let specialty = artist.specialties?.first {
                    Text(specialty.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.piumsOrange)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.piumsOrange.opacity(0.12))
                        .clipShape(Capsule())
                }
                if let city = artist.city {
                    Label(city, systemImage: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                Text(String(format: "%.1f", artist.rating ?? 0.0)).font(.subheadline.bold())
                Text("(\(artist.reviewsCount) reseñas)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if artist.totalBookings > 0 {
                    Label("\(artist.totalBookings) reservas", systemImage: "calendar.badge.checkmark")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button {
                    if let first = viewModel.services.first {
                        bookingService = first
                        showBooking = true
                    } else {
                        withAnimation { selectedTab = .services }
                    }
                } label: {
                    Label("Reservar Ahora", systemImage: "calendar.badge.plus")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.piumsOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    Task { await favorites.toggle(artist: artist) }
                } label: {
                    Image(systemName: favorites.isFavorite(artist.id) ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(Color.piumsOrange)
                        .frame(width: 44, height: 44)
                        .background(Color.piumsOrange.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Color(.systemBackground))
    }

    // MARK: - Tab selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                    } label: {
                        VStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                                .foregroundStyle(selectedTab == tab ? Color.piumsOrange : .secondary)
                                .padding(.horizontal, 18)
                                .padding(.top, 10)
                            Rectangle()
                                .fill(selectedTab == tab ? Color.piumsOrange : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .services:  servicesContent
        case .portfolio: portfolioContent
        case .reviews:   reviewsContent
        case .about:     aboutContent
        }
    }

    // MARK: Servicios

    private var servicesContent: some View {
        VStack(spacing: 12) {
            if viewModel.isLoadingServices {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(height: 120)
                        .redacted(reason: .placeholder)
                }
            } else if viewModel.services.isEmpty {
                emptyState("No hay servicios publicados aún", icon: "music.note.list")
            } else {
                ForEach(viewModel.services) { svc in serviceCard(svc) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func serviceCard(_ svc: ArtistService) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(svc.name).font(.subheadline.bold())
                    if let desc = svc.description {
                        Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Label("\(svc.duration) min", systemImage: "clock")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(svc.price.piumsFormatted)
                    .font(.headline.bold())
                    .foregroundStyle(Color.piumsOrange)
            }

            Button {
                bookingService = svc
                showBooking = true
            } label: {
                Text("Reservar")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.piumsOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Portafolio

    private var portfolioContent: some View {
        Group {
            if viewModel.isLoadingPortfolio {
                ProgressView().frame(maxWidth: .infinity).padding(40)
            } else if viewModel.portfolio.isEmpty {
                emptyState("Aún no hay portafolio publicado", icon: "photo.on.rectangle.angled")
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)],
                    spacing: 3
                ) {
                    ForEach(viewModel.portfolio) { item in
                        AsyncImage(url: URL(string: item.url)) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                                    .frame(minHeight: 160).clipped()
                            default:
                                Color(.tertiarySystemGroupedBackground).frame(height: 160)
                                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 160).clipped()
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: Reseñas

    private var reviewsContent: some View {
        VStack(spacing: 12) {
            if viewModel.isLoadingReviews {
                ProgressView().frame(maxWidth: .infinity).padding(40)
            } else if viewModel.reviews.isEmpty {
                emptyState("Aún no hay reseñas", icon: "star.bubble")
            } else {
                ratingsSummary
                ForEach(viewModel.reviews) { review in reviewCard(review) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var ratingsSummary: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(spacing: 4) {
                Text(String(format: "%.1f", artist.rating ?? 0))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.piumsOrange)
                StarRatingView(rating: artist.rating ?? 0)
                Text("\(artist.reviewsCount) reseñas")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider().frame(height: 64)

            VStack(alignment: .leading, spacing: 5) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { n in
                    let count = viewModel.reviews.filter { $0.rating == n }.count
                    let total = max(viewModel.reviews.count, 1)
                    HStack(spacing: 6) {
                        Text("\(n)").font(.caption2).foregroundStyle(.secondary).frame(width: 10)
                        Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(.yellow)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray5))
                                RoundedRectangle(cornerRadius: 3).fill(Color.piumsOrange)
                                    .frame(width: geo.size.width * CGFloat(count) / CGFloat(total))
                            }
                        }
                        .frame(height: 5)
                        Text("\(count)").font(.caption2).foregroundStyle(.secondary)
                            .frame(width: 18, alignment: .trailing)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func reviewCard(_ r: Review) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.piumsOrange.opacity(0.15)).frame(width: 36, height: 36)
                    Text(String((r.clientName ?? "?").prefix(1)).uppercased())
                        .font(.subheadline.bold()).foregroundStyle(Color.piumsOrange)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(r.clientName ?? "Cliente").font(.subheadline.bold())
                    Text(r.createdAt.prefix(10)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                StarRatingView(rating: Double(r.rating))
            }
            if let comment = r.comment {
                Text(comment).font(.subheadline).foregroundStyle(.secondary).lineLimit(4)
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Acerca de

    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let bio = artist.bio {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sobre el artista").font(.headline)
                    Text(bio).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Estadísticas").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    statCard(value: String(format: "%.1f", artist.rating ?? 0),
                             label: "Calificación", icon: "star.fill", iconColor: .yellow)
                    statCard(value: "\(artist.reviewsCount)",
                             label: "Reseñas", icon: "bubble.left.fill", iconColor: Color.piumsOrange)
                    statCard(value: "\(artist.totalBookings)",
                             label: "Reservas", icon: "calendar.badge.checkmark", iconColor: .green)
                    statCard(value: artist.isVerified ? "Verificado" : "No verificado",
                             label: "Estado", icon: "checkmark.seal.fill", iconColor: Color.piumsOrange)
                }
            }

            if let city = artist.city {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ubicación").font(.headline)
                    Label(city, systemImage: "mappin.circle.fill")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Helpers

    private func statCard(value: String, label: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(iconColor).frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.subheadline.bold()).lineLimit(1)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func emptyState(_ msg: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(Color(.systemGray3))
            Text(msg).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(50)
    }
}

#Preview {
    NavigationStack {
        ArtistProfileView(artist: .mock)
    }
}
