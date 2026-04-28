// ArtistCardView.swift — card estilo web: cover gradiente + avatar iniciales + matched service
import SwiftUI

struct ArtistCardView: View {
    let artist: Artist
    var matchedService: MatchedService? = nil

    // Gradientes por índice, igual que los colores violeta/rosa de la web
    private static let gradients: [[Color]] = [
        [Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.96, green: 0.36, blue: 0.55)],
        [Color(red: 0.36, green: 0.55, blue: 0.96), Color(red: 0.96, green: 0.55, blue: 0.36)],
        [Color(red: 0.70, green: 0.30, blue: 0.90), Color(red: 0.90, green: 0.50, blue: 0.70)],
        [Color(red: 0.40, green: 0.60, blue: 0.90), Color(red: 0.80, green: 0.40, blue: 0.90)],
    ]

    private var gradient: [Color] {
        let idx = abs(artist.id.hashValue) % Self.gradients.count
        return Self.gradients[idx]
    }

    private var initials: String {
        artist.artistName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map { String($0) } }
            .joined()
            .uppercased()
    }

    private var displayPrice: (label: String, value: Int)? {
        if let svc = matchedService { return (svc.name, svc.price) }
        if let p = artist.mainServicePrice, let n = artist.mainServiceName, p > 0 { return (n, p) }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Cover ─────────────────────────────────────
            ZStack(alignment: .bottomLeading) {
                // Gradiente de fondo siempre presente
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 130)

                // Portada real (coverUrl) o avatar como fallback de portada
                if let url = artist.coverUrl ?? artist.avatarUrl, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        }
                    }
                    .frame(height: 130)
                    .clipped()
                }

                // Availability badge — top right
                HStack {
                    Spacer()
                    Label(artist.isAvailable ? "Disponible" : "Ocupado",
                          systemImage: artist.isAvailable ? "circle.fill" : "circle")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(artist.isAvailable ? Color.green : Color.gray)
                        .clipShape(Capsule())
                        .padding(10)
                }
                .frame(maxHeight: .infinity, alignment: .top)

                // Verified badge — top left
                if artist.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.green.opacity(0.85))
                        .clipShape(Circle())
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                // Avatar — foto real o iniciales solapado abajo izquierda
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(red:0.85,green:0.30,blue:0.50),
                                                      Color(red:0.96,green:0.36,blue:0.36)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    if let url = artist.avatarUrl, let imageURL = URL(string: url) {
                        AsyncImage(url: imageURL) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                            } else {
                                Text(initials).font(.subheadline.bold()).foregroundStyle(.white)
                            }
                        }
                    } else {
                        Text(initials).font(.subheadline.bold()).foregroundStyle(.white)
                    }
                }
                .offset(x: 14, y: 22)
            }
            .frame(height: 130)
            .clipped()

            // ── Info ──────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                // Nombre — dejamos espacio para el avatar que sobresale
                Text(artist.artistName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.top, 26)   // espacio para el avatar solapado

                // Especialidad
                if let spec = artist.specialties?.first {
                    Text(spec)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Rating + ciudad
                HStack(spacing: 8) {
                    if let rating = artist.averageRating, rating > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption.bold())
                            Text("(\(artist.totalReviews))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Sin reseñas")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let city = artist.city {
                        HStack(spacing: 2) {
                            Image(systemName: "mappin.circle")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(city)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                // MatchedService / precio badge
                if let svc = displayPrice {
                    HStack {
                        if matchedService != nil {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundStyle(Color.piumsOrange)
                        }
                        Text(svc.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text(svc.value.piumsFormatted)
                            .font(.caption.bold())
                            .foregroundStyle(Color.piumsOrange)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.piumsOrange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Botón Ver Perfil
                Text("Ver Perfil")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.piumsOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            ForEach(Artist.mockList) { ArtistCardView(artist: $0) }
        }
        .padding()
    }
}
