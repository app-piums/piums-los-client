// HomeView.swift — rediseño según mockup
import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var selectedArtist: Artist?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ── Saludo ──────────────────────────────────
                greetingSection
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                // ── Mini calendario ─────────────────────────
                HomeCalendarView(
                    bookingDates: viewModel.upcomingBookingDates,
                    nextBooking: viewModel.nextBooking
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 28)

                // ── Error ───────────────────────────────────
                if let msg = viewModel.errorMessage {
                    ErrorBannerView(message: msg)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }

                // ── Recommended for you ─────────────────────
                recommendedSection
                    .padding(.bottom, 28)

                // ── Banner promocional ──────────────────────
                PromoBannerView()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                Color.clear.frame(height: 20)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.loadInitial() }
        .task { await viewModel.loadInitial() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { topBar }
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .navigationDestination(item: $selectedArtist) { ArtistProfileView(artist: $0) }
    }

    // MARK: - Top bar

    @ToolbarContentBuilder
    private var topBar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 10) {
                // Avatar usuario
                Circle()
                    .fill(Color.piumsOrange.opacity(0.15))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.piumsOrange)
                    )
                Text("Piums")
                    .font(.headline.bold())
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                // notificaciones
            } label: {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.primary)
                    .overlay(alignment: .topTrailing) {
                        Circle().fill(Color.piumsOrange)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
            }
        }
    }

    // MARK: - Saludo

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hello, \(viewModel.firstName) 👋")
                .font(.system(size: 28, weight: .bold))
            Text("Ready to curate your next masterpiece?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Recommended

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recommended for you")
                    .font(.title3.bold())
                Spacer()
                Button("View all") { }
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.piumsOrange)
            }
            .padding(.horizontal, 20)

            if viewModel.isLoading && viewModel.artists.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(0..<3, id: \.self) { _ in
                            ArtistCardSkeletonView()
                        }
                    }
                    .padding(.horizontal, 20)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(viewModel.artists) { artist in
                            RecommendedArtistCard(artist: artist)
                                .onTapGesture { selectedArtist = artist }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - Mini Calendario
// ══════════════════════════════════════════════════════════════

struct HomeCalendarView: View {
    let bookingDates: Set<String>
    var nextBooking: Booking? = nil

    @State private var displayMonth = Date()
    private let calendar = Calendar.current
    private let dayColumns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["MON","TUE","WED","THU","FRI","SAT","SUN"]

    var body: some View {
        VStack(spacing: 12) {
            // Header mes
            HStack {
                Text(monthTitle)
                    .font(.headline.bold())
                Spacer()
                Button { changeMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.piumsOrange)
                }
                Button { changeMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.piumsOrange)
                }
            }

            // Días de la semana
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { d in
                    Text(d)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Días del mes
            LazyVGrid(columns: dayColumns, spacing: 6) {
                ForEach(calendarDays, id: \.self) { day in
                    DayCell(
                        day: day,
                        isToday: isToday(day),
                        hasBooking: hasBooking(day),
                        isCurrentMonth: isCurrentMonth(day)
                    )
                }
            }

            // Próxima reserva
            if let next = nextBookingLabel {
                Divider()
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.piumsOrange.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.piumsOrange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(next.title)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Text(next.subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.piumsOrange)
                    }
                    Spacer()
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // Helpers
    private var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.locale = Locale(identifier: "en_US")
        return f.string(from: displayMonth)
    }

    private func changeMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: displayMonth) {
            withAnimation(.easeInOut(duration: 0.2)) { displayMonth = d }
        }
    }

    // Genera los días del grid (lunes-inicio, relleno de mes anterior/siguiente)
    private var calendarDays: [Date] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year,.month], from: displayMonth)),
              let range = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }

        // Primer día de la semana (lunes=2 en gregorian)
        var comps = calendar.dateComponents([.year,.month,.day,.weekday], from: monthStart)
        let weekday = comps.weekday ?? 2
        let offset = (weekday - 2 + 7) % 7  // cuántos días antes del 1 necesitamos

        var days: [Date] = []
        for i in (-offset)..<(range.count + (7 - (range.count + offset) % 7) % 7) {
            if let d = calendar.date(byAdding: .day, value: i, to: monthStart) {
                days.append(d)
            }
        }
        return days
    }

    private func isToday(_ date: Date) -> Bool { calendar.isDateInToday(date) }
    private func isCurrentMonth(_ date: Date) -> Bool {
        calendar.component(.month, from: date) == calendar.component(.month, from: displayMonth)
    }
    private func hasBooking(_ date: Date) -> Bool {
        let s = isoString(date)
        return bookingDates.contains(s)
    }
    private func isoString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    private var nextBookingLabel: (title: String, subtitle: String)? {
        guard let b = nextBooking else { return nil }
        let title = b.code ?? "Reserva confirmada"
        let time = b.scheduledTime.map { "\(b.scheduledDate) · \($0)" } ?? b.scheduledDate
        return (title, time)
    }
}

private struct DayCell: View {
    let day: Date
    let isToday: Bool
    let hasBooking: Bool
    let isCurrentMonth: Bool

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                if isToday {
                    Circle().fill(Color.piumsOrange).frame(width: 32, height: 32)
                }
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 13, weight: isToday ? .bold : .regular))
                    .foregroundStyle(
                        isToday ? .white :
                        isCurrentMonth ? .primary : Color(.systemGray4)
                    )
            }
            // Dot de reserva
            Circle()
                .fill(hasBooking ? Color.piumsOrange : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(height: 42)
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - Recommended Artist Card (vertical, foto grande)
// ══════════════════════════════════════════════════════════════

struct RecommendedArtistCard: View {
    let artist: Artist

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Foto
            ZStack(alignment: .topTrailing) {
                Group {
                    if let url = artist.avatarUrl.flatMap(URL.init) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            photoPlaceholder
                        }
                    } else {
                        photoPlaceholder
                    }
                }
                .frame(width: 160, height: 200)
                .clipped()

                // Badge TOP RATED
                if let rating = artist.rating, rating >= 4.8 {
                    Text("TOP RATED")
                        .font(.system(size: 9, weight: .black))
                        .tracking(0.5)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(.white)
                        )
                        .padding(10)
                }
            }
            .frame(width: 160, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(artist.artistName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text("\(artist.specialties?.first ?? "Artista") · \(artist.city ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.top, 8)
            .padding(.horizontal, 2)
        }
        .frame(width: 160)
    }

    private var photoPlaceholder: some View {
        LinearGradient(
            colors: [Color(.systemGray4), Color(.systemGray5)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - Skeleton card
// ══════════════════════════════════════════════════════════════

private struct ArtistCardSkeletonView: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray5))
                .frame(width: 160, height: 200)
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.3), Color.clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .offset(x: shimmer ? 200 : -200)
                    .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: shimmer)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Capsule().fill(Color(.systemGray5)).frame(width: 100, height: 12).padding(.top, 10)
            Capsule().fill(Color(.systemGray6)).frame(width: 70, height: 10).padding(.top, 5)
        }
        .frame(width: 160)
        .onAppear { shimmer = true }
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - Promo Banner
// ══════════════════════════════════════════════════════════════

struct PromoBannerView: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Fondo naranja
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.piumsOrange)
                .frame(maxWidth: .infinity)
                .frame(height: 160)

            // Círculos decorativos
            Circle().fill(Color.white.opacity(0.08))
                .frame(width: 160, height: 160)
                .offset(x: 180, y: -30)
            Circle().fill(Color.white.opacity(0.06))
                .frame(width: 100, height: 100)
                .offset(x: 230, y: 30)

            VStack(alignment: .leading, spacing: 8) {
                Text("Master the Art of\nComposition")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                Text("Join our upcoming workshop with\nleading curators from the MoMA.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(2)

                Button {
                    // acción
                } label: {
                    Text("Register Now")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.piumsOrange)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(.white))
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
    }
}

#Preview {
    NavigationStack { HomeView() }
}
