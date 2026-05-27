// MyTicketsView.swift — Mis boletos comprados con código QR
import SwiftUI
import CoreImage.CIFilterBuiltins

struct MyTicketsView: View {
    @State private var vm = TicketsViewModel()
    @State private var selectedPurchase: TicketPurchase?

    private var upcoming: [TicketPurchase] {
        vm.myPurchases.filter { $0.isPaid && $0.isUpcoming }
    }
    private var past: [TicketPurchase] {
        vm.myPurchases.filter { !$0.isUpcoming || !$0.isPaid }
    }

    var body: some View {
        Group {
            if vm.isLoadingPurchases && vm.myPurchases.isEmpty {
                LoadingView()
            } else if vm.myPurchases.isEmpty {
                EmptyStateView(
                    systemImage: "ticket",
                    title: "Sin boletos",
                    description: "Aún no has comprado ningún boleto."
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !upcoming.isEmpty {
                            sectionHeader("Próximos")
                            ForEach(upcoming) { purchase in
                                TicketPurchaseRow(purchase: purchase)
                                    .onTapGesture { selectedPurchase = purchase }
                            }
                        }
                        if !past.isEmpty {
                            sectionHeader("Pasados / Cancelados")
                            ForEach(past) { purchase in
                                TicketPurchaseRow(purchase: purchase, dimmed: true)
                                    .onTapGesture { selectedPurchase = purchase }
                            }
                        }
                        Color.clear.frame(height: 12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .refreshable { await vm.loadMyPurchases() }
            }
        }
        .task { await vm.loadMyPurchases() }
        .sheet(item: $selectedPurchase) { purchase in
            TicketQRSheet(purchase: purchase)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 4)
    }
}

// MARK: - TicketPurchaseRow

private struct TicketPurchaseRow: View {
    let purchase: TicketPurchase
    var dimmed = false

    private var eventName: String { purchase.ticketEvent?.name ?? "Evento" }
    private var tierName: String { purchase.tier?.name ?? purchase.tierId }
    private var eventDate: String {
        guard let d = purchase.ticketEvent?.eventDate else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()
        guard let date = iso.date(from: d) ?? iso2.date(from: d) else { return String(d.prefix(10)) }
        let f = DateFormatter(); f.dateStyle = .medium; f.locale = Locale(identifier: "es_ES")
        return f.string(from: date)
    }
    private var statusColor: Color {
        switch purchase.status {
        case "PAGADO": return .green
        case "USADO":  return .secondary
        case "REEMBOLSADO": return .purple
        case "EXPIRADO": return .red
        default: return .orange
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail del evento
            Group {
                if let url = purchase.ticketEvent?.imageUrl, let imgURL = URL(string: url) {
                    AsyncImage(url: imgURL) { ph in
                        switch ph {
                        case .success(let img): img.resizable().scaledToFill()
                        default: ticketIcon
                        }
                    }
                } else {
                    ticketIcon
                }
            }
            .frame(width: 62, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(eventName).font(.subheadline.bold()).lineLimit(1)
                Text(tierName).font(.caption).foregroundStyle(.secondary)
                if !eventDate.isEmpty {
                    Label(eventDate, systemImage: "calendar")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                    Text(purchase.status.capitalized)
                        .font(.caption2).foregroundStyle(statusColor)
                    Text("·").foregroundStyle(.secondary).font(.caption2)
                    Text("\(purchase.quantity) boleto\(purchase.quantity > 1 ? "s" : "")")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "qrcode").font(.title3).foregroundStyle(Color.piumsOrange)
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .opacity(dimmed ? 0.6 : 1)
    }

    private var ticketIcon: some View {
        LinearGradient(
            colors: [Color.piumsOrange.opacity(0.6), Color(hex: "#E91E8C").opacity(0.4)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay { Image(systemName: "ticket.fill").foregroundStyle(.white.opacity(0.7)) }
    }
}

// MARK: - TicketQRSheet

private struct TicketQRSheet: View {
    let purchase: TicketPurchase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Nombre del evento
                    VStack(spacing: 6) {
                        Text(purchase.ticketEvent?.name ?? "Evento")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text(purchase.tier?.name ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // QR Code
                    if let qr = generateQR(from: purchase.code) {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    }

                    // Código en texto
                    VStack(spacing: 4) {
                        Text("CÓDIGO").font(.caption2.bold()).foregroundStyle(.secondary).tracking(2)
                        Text(purchase.code)
                            .font(.title3.bold().monospaced())
                            .foregroundStyle(Color.piumsOrange)
                    }

                    // Info comprador
                    VStack(spacing: 8) {
                        infoRow("Comprador", value: purchase.buyerName)
                        infoRow("Cantidad", value: "\(purchase.quantity) boleto\(purchase.quantity > 1 ? "s" : "")")
                        infoRow("Total", value: purchase.totalCents.piumsFormatted)
                        if let venue = purchase.ticketEvent?.venue {
                            infoRow("Venue", value: venue)
                        }
                    }
                    .padding(16)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    // Aviso
                    Label("Presenta este código QR en la entrada del evento.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Color.clear.frame(height: 20)
                }
                .padding(.top, 20)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Mi Boleto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.bold())
        }
    }

    private func generateQR(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
