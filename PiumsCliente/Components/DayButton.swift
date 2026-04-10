// DayButton.swift — botón de día del selector de fecha horizontal
import SwiftUI

struct DayButton: View {
    let date: Date
    let isSelected: Bool
    let onTap: () -> Void

    private var dayNum: String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }
    private var dayName: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        f.locale = Locale(identifier: "es_ES")
        return f.string(from: date).uppercased()
    }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(dayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .secondary)
                Text(dayNum)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? .white : isToday ? Color.piumsOrange : .primary)
            }
            .frame(width: 48, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.piumsOrange : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isToday && !isSelected ? Color.piumsOrange.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
