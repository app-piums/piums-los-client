// ArtistCardView.swift — card reutilizable en Home y Search
import SwiftUI

struct ArtistCardView: View {
    let artist: Artist

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            Group {
                if let url = artist.avatarUrl, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        avatarPlaceholder
                    }
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(artist.artistName)
                        .font(.headline)
                        .lineLimit(1)
                    if artist.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Color.piumsOrange)
                    }
                }

                Text(artist.category.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    if let rating = artist.rating {
                        StarRatingView(rating: rating, size: 12)
                        Text(String(format: "%.1f", rating))
                            .font(.caption.bold())
                        Text("(\(artist.reviewsCount))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let city = artist.city {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(city)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Precio
            VStack(alignment: .trailing, spacing: 2) {
                if let price = artist.basePrice {
                    Text("Desde")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(price.piumsFormatted)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.piumsOrange)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Color.piumsOrange.opacity(0.15)
            Image(systemName: artist.category.systemImage)
                .font(.title2)
                .foregroundStyle(Color.piumsOrange)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(Artist.mockList) { ArtistCardView(artist: $0) }
    }
    .padding()
}
