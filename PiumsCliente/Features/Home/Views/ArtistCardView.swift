// ArtistCardView.swift — card estilo web: cover gradiente por especialidad + avatar iniciales + matched service
import SwiftUI

struct ArtistCardView: View {
    let artist: Artist
    var matchedService: MatchedService? = nil

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

    private var specialtyCoverGradient: LinearGradient {
        let spec = artist.specialties?.first?.lowercased() ?? ""
        let colors: [Color]
        switch true {
        case spec.contains("músic") || spec.contains("music"):
            colors = [Color(hex: "#FF6A00"), Color(hex: "#F59E0B")]
        case spec.contains("dj"):
            colors = [Color(hex: "#FF6A00"), Color(hex: "#E91E8C")]
        case spec.contains("fotograf"):
            colors = [Color(hex: "#00AEEF"), Color(hex: "#1E3A8A")]
        case spec.contains("video"):
            colors = [Color(hex: "#4F46E5"), Color(hex: "#E91E8C")]
        case spec.contains("diseñ") || spec.contains("disen"):
            colors = [Color(hex: "#00AEEF"), Color(hex: "#10B981")]
        case spec.contains("bail"):
            colors = [Color(hex: "#FF6A00"), Color(hex: "#EF4444")]
        case spec.contains("maquillaj"):
            colors = [Color(hex: "#F472B6"), Color(hex: "#7C2D12")]
        case spec.contains("tatua"):
            colors = [Color(hex: "#1E40AF"), Color(hex: "#7C3AED")]
        case spec.contains("pintur") || spec.contains("pintor"):
            colors = [Color(hex: "#06B6D4"), Color(hex: "#10B981")]
        case spec.contains("mag"):
            colors = [Color(hex: "#7C3AED"), Color(hex: "#4F46E5")]
        default:
            colors = [Color(hex: "#FF6A00"), Color(hex: "#00AEEF")]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // ── Card content ─────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                // Cover
                ZStack {
                    if let url = artist.coverUrl, let imageURL = URL(string: url) {
                        // Neutral background while photo loads
                        Color(.systemGray5).frame(height: 130)

                        AsyncImage(url: imageURL) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            }
                        }
                        .frame(height: 130)
                        .clipped()
                    } else {
                        // No cover photo — show specialty gradient with texture
                        specialtyCoverGradient
                            .frame(height: 130)

                        Canvas { context, size in
                            let spacing: CGFloat = 16
                            let r: CGFloat = 1.5
                            var y = spacing / 2
                            while y < size.height {
                                var x = spacing / 2
                                while x < size.width {
                                    context.fill(
                                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                        with: .color(.white.opacity(0.25))
                                    )
                                    x += spacing
                                }
                                y += spacing
                            }
                        }
                        .frame(height: 130)
                        .allowsHitTesting(false)

                        Text(String(initials.prefix(1)))
                            .font(.system(size: 90, weight: .black))
                            .foregroundStyle(.white.opacity(0.12))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(.trailing, 6)
                            .offset(y: 20)
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
                }
                .frame(height: 130)
                .clipped()

                // Info section
                VStack(alignment: .leading, spacing: 8) {
                    Text(artist.artistName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .padding(.top, 26) // space for overlapping avatar

                    if let spec = artist.specialties?.first {
                        Text(spec)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

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

            // ── Avatar — outside card clip, straddling the cover/info seam ──
            ZStack {
                Circle()
                    .fill(specialtyCoverGradient)
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
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Text(initials).font(.subheadline.bold()).foregroundStyle(.white)
                }
            }
            .offset(x: 14, y: 108) // center avatar at the cover/info seam (130 - 22 = 108)
        }
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
