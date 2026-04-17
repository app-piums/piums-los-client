// HomeView.swift — rediseño según mockup
import SwiftUI
import CoreLocation

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var selectedArtist: Artist?
    @State private var selectedDate: Date? = nil
    @State private var showArtistSearch = false
    @Environment(\.locationStore) private var locationStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ── Saludo ──────────────────────────────────
                greetingSection
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                // ── Error ───────────────────────────────────
                if let msg = viewModel.errorMessage {
                    ErrorBannerView(message: msg)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }

                // ── Mini calendario ─────────────────────────
                HomeCalendarView(
                    bookingDates: viewModel.upcomingBookingDates,
                    nextBooking: viewModel.nextBooking
                ) { tappedDay in
                    selectedDate = tappedDay
                    showArtistSearch = true
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)

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
        .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
        .refreshable { await viewModel.loadInitial() }
        .task { await viewModel.loadInitial() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { topBar }
        .toolbarBackground(Color(.secondarySystemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(item: $selectedArtist) { ArtistProfileView(artist: $0) }
        .navigationDestination(isPresented: $showArtistSearch) {
            if let date = selectedDate {
                ArtistSearchByDateView(
                    selectedDate: date,
                    userLocation: locationStore.coordinate,
                    locationName: locationStore.cityName
                )
            }
        }
        .onAppear { locationStore.requestIfNeeded() }
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
            Text("Hola, \(viewModel.firstName) 👋")
                .font(.system(size: 28, weight: .bold))
            Text("¿Qué artista necesitas para tu próximo evento?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Recommended

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recomendados para ti")
                    .font(.title3.bold())
                Spacer()
                Button("Ver todos") {
                    selectedDate = selectedDate ?? Calendar.current.startOfDay(for: Date())
                    showArtistSearch = true
                }
                .font(.subheadline.bold())
                .foregroundStyle(Color.piumsOrange)
            }
            .padding(.horizontal, 20)

            if viewModel.isLoading && viewModel.artists.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(0..<3, id: \.self) { _ in ArtistCardSkeletonView() }
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
    var onDayTap: ((Date) -> Void)? = nil

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
                        isCurrentMonth: isCurrentMonth(day),
                        onTap: isCurrentMonth(day) ? { onDayTap?(day) } : nil
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
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    // Helpers
    private var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.locale = Locale(identifier: "es_ES")
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
    var onTap: (() -> Void)? = nil

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                if isToday {
                    Circle().fill(Color.piumsOrange).frame(width: 32, height: 32)
                } else if onTap != nil && isCurrentMonth {
                    Circle().fill(Color.piumsOrange.opacity(0.0)).frame(width: 32, height: 32)
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
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - Recommended Artist Card (vertical, foto grande)
// ══════════════════════════════════════════════════════════════

struct RecommendedArtistCard: View {
    let artist: Artist

    private static let gradients: [[Color]] = [
        [Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.96, green: 0.36, blue: 0.55)],
        [Color(red: 0.36, green: 0.55, blue: 0.96), Color(red: 0.96, green: 0.55, blue: 0.36)],
        [Color(red: 0.70, green: 0.30, blue: 0.90), Color(red: 0.90, green: 0.50, blue: 0.70)],
        [Color(red: 0.40, green: 0.60, blue: 0.90), Color(red: 0.80, green: 0.40, blue: 0.90)],
    ]
    private var gradient: [Color] {
        Self.gradients[abs(artist.id.hashValue) % Self.gradients.count]
    }
    private var initials: String {
        artist.artistName.split(separator: " ").prefix(2)
            .compactMap { $0.first.map { String($0) } }.joined().uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 160, height: 120)

                if let rating = artist.rating, rating >= 4.8 {
                    Text("TOP RATED")
                        .font(.system(size: 9, weight: .black)).tracking(0.5)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(.white))
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }

                // Avatar iniciales solapado
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(red:0.85,green:0.30,blue:0.50),
                                                      Color(red:0.96,green:0.36,blue:0.36)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    Text(initials).font(.caption.bold()).foregroundStyle(.white)
                }
                .offset(x: 10, y: 18)
            }
            .frame(width: 160, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(artist.artistName).font(.subheadline.bold()).lineLimit(1).padding(.top, 22)
                Text("\(artist.specialties?.first ?? "Artista") · \(artist.city ?? "")")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if let price = artist.mainServicePrice, price > 0 {
                    Text(price.piumsFormatted)
                        .font(.caption.bold()).foregroundStyle(Color.piumsOrange)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .frame(width: 160)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 5, y: 2)
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
