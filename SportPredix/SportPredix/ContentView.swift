//
//  ContentView.swift
//  SportPredix
//
//  Created by Formatiks Team on 12/01/26.
//

import SwiftUI

// MARK: - MODELS

struct Match: Identifiable {
    let id = UUID()
    let home: String
    let away: String
    let odds: [Double] // 1X2
}

// MARK: - MAIN VIEW

struct ContentView: View {

    @State private var selectedDate: Date = Date()

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {

                // 🔹 CALENDARIO PICCOLO
                SmallCalendarView(selectedDate: $selectedDate)

                // 🔹 PARTITE FAKE DEL GIORNO
                List {
                    ForEach(generateMatches(for: selectedDate), id: \.id) { match in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(match.home) - \(match.away)")
                                .font(.headline)

                            HStack(spacing: 12) {
                                ForEach(0..<3, id: \.self) { index in
                                    Button {
                                        // in futuro: aggiunta pronostico
                                    } label: {
                                        Text(match.odds[index], specifier: "%.2f")
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color(hex: "44E0CB").opacity(0.15))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.plain)

                Spacer()
            }
            .padding(.top, 8)
            .navigationTitle("Serie A")
        }
    }

    // MARK: - MATCH GENERATOR (FAKE)

    func generateMatches(for date: Date) -> [Match] {
        // Cambiano automaticamente in base al giorno
        let day = Calendar.current.component(.day, from: date)

        return [
            Match(home: "Napoli", away: "Roma", odds: randomOdds(seed: day)),
            Match(home: "Milan", away: "Inter", odds: randomOdds(seed: day + 1)),
            Match(home: "Juventus", away: "Atalanta", odds: randomOdds(seed: day + 2))
        ]
    }

    func randomOdds(seed: Int) -> [Double] {
        srand48(seed)
        return [
            Double(drand48() * 1.5 + 1.5),
            Double(drand48() * 1.2 + 2.8),
            Double(drand48() * 2.5 + 2.0)
        ]
    }
}

// MARK: - SMALL CALENDAR

struct SmallCalendarView: View {

    @Binding var selectedDate: Date

    private let calendar = Calendar.current
    private let range = -1...1

    var body: some View {
        HStack(spacing: 16) {
            ForEach(range, id: \.self) { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: selectedDate)!

                VStack(spacing: 6) {
                    Text(dayName(from: date))
                        .font(.caption2)
                        .foregroundColor(.gray)

                    Text(dayNumber(from: date))
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(isSameDay(date) ? Color(hex: "44E0CB") : .clear)
                        )
                        .foregroundColor(isSameDay(date) ? .white : .primary)
                }
                .onTapGesture {
                    selectedDate = date
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func isSameDay(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func dayNumber(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func dayName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - COLOR EXTENSION

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - PREVIEW

#Preview {
    ContentView()
}