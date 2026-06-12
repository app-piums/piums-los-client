import SwiftUI

// ══════════════════════════════════════════════════════════════
// MARK: - MonthYearPickerSheet
// Permite saltar directamente a un mes/año sin navegar mes a mes.
// ══════════════════════════════════════════════════════════════

struct MonthYearPickerSheet: View {
    @Binding var selection: Date
    @Environment(\.dismiss) private var dismiss

    @State private var year: Int

    private let calendar = Calendar.current
    private let monthNames = ["Ene", "Feb", "Mar", "Abr", "May", "Jun",
                              "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]

    init(selection: Binding<Date>) {
        _selection = selection
        _year = State(initialValue: Calendar.current.component(.year, from: selection.wrappedValue))
    }

    private var selectedMonth: Int { calendar.component(.month, from: selection) }
    private var selectedYear: Int { calendar.component(.year, from: selection) }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                yearRow
                monthGrid
                Spacer()
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .navigationTitle("Ir a mes").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hoy") { select(Date()) }
                        .font(.body.bold())
                        .foregroundStyle(Color.piumsOrange)
                }
            }
        }
    }

    private var yearRow: some View {
        HStack {
            Button { year -= 1 } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.bold())
                    .foregroundStyle(Color.piumsOrange)
                    .frame(width: 36, height: 36)
            }
            Spacer()
            Text(String(year))
                .font(.title2.bold())
            Spacer()
            Button { year += 1 } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.bold())
                    .foregroundStyle(Color.piumsOrange)
                    .frame(width: 36, height: 36)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(1...12, id: \.self) { m in
                let isCurrent = m == selectedMonth && year == selectedYear
                Button {
                    if let date = calendar.date(from: DateComponents(year: year, month: m, day: 1)) {
                        select(date)
                    }
                } label: {
                    Text(monthNames[m - 1])
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(isCurrent ? Color.piumsOrange : Color(.tertiarySystemGroupedBackground))
                        .foregroundStyle(isCurrent ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func select(_ date: Date) {
        withAnimation(.easeInOut(duration: 0.2)) { selection = date }
        dismiss()
    }
}
