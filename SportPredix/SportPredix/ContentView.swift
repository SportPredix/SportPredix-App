//
//  ContentView.swift
//  SportPredix
//
//  Created by Formatiks Team on 12/01/26.
//


import SwiftUI

// MARK: - MODELS

enum Outcome: String, Codable, CaseIterable {
    case home = "1"
    case draw = "X"
    case away = "2"
}

struct Match: Identifiable, Codable {
    var id: UUID = UUID()
    let home: String
    let away: String
    let date: Date
    let odds: [Outcome: Double]
}

struct Prediction: Identifiable, Codable {
    var id: UUID = UUID()
    let match: Match
    let outcome: Outcome
}

struct BetSlip: Identifiable, Codable {
    var id: UUID = UUID()
    let predictions: [Prediction]
    let stake: Double
    let totalOdds: Double
    let potentialWin: Double
    let date: Date
}

// MARK: - STORAGE

enum Storage {

    static func save<T: Codable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load<T: Codable>(_ key: String, as type: T.Type) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(type, from: data) else {
            return nil
        }
        return value
    }
}

// MARK: - CONTENT VIEW

struct ContentView: View {

    @State private var balance: Double = Storage.load("balance", as: Double.self) ?? 1000
    @State private var predictions: [Prediction] = []
    @State private var slips: [BetSlip] = Storage.load("slips", as: [BetSlip].self) ?? []

    @State private var selectedDate: Date = Date()
    @State private var showBetSheet = false

    @State private var profileName: String = Storage.load("profileName", as: String.self) ?? ""

    var body: some View {
        TabView {

            calendarTab
                .tabItem { Label("Calendario", systemImage: "calendar") }

            slipsTab
                .tabItem { Label("Piazzate", systemImage: "list.bullet.rectangle") }

            profileTab
                .tabItem { Label("Profilo", systemImage: "person.crop.circle") }
        }
        .accentColor(Color(hex: "#44E0CB"))
        .overlay(alignment: .bottomTrailing) {
            betFloatingButton
        }
        .sheet(isPresented: $showBetSheet) {
            BetSheet(
                predictions: $predictions,
                balance: $balance,
                slips: $slips
            )
        }
        .onChange(of: slips) {
            Storage.save(slips, key: "slips")
        }
        .onChange(of: balance) {
            Storage.save(balance, key: "balance")
        }
    }

    // MARK: - CALENDAR TAB

    var calendarTab: some View {
        NavigationView {
            VStack {

                calendarStrip

                List(generateMatches(for: selectedDate)) { match in
                    VStack(alignment: .leading) {
                        Text("\(match.home) – \(match.away)")
                            .font(.headline)
                        HStack {
                            ForEach(Outcome.allCases, id: \.self) { outcome in
                                Button {
                                    predictions.append(
                                        Prediction(match: match, outcome: outcome)
                                    )
                                } label: {
                                    Text("\(outcome.rawValue)\n\(match.odds[outcome]!, specifier: "%.2f")")
                                        .padding(8)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Serie A")
        }
    }

    // MARK: - SLIPS TAB

    var slipsTab: some View {
        NavigationView {
            List(slips) { slip in
                NavigationLink {
                    SlipDetailView(slip: slip)
                } label: {
                    VStack(alignment: .leading) {
                        Text("Multipla \(slip.predictions.count) eventi")
                        Text("€\(slip.stake, specifier: "%.2f") → €\(slip.potentialWin, specifier: "%.2f")")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Storico")
        }
    }

    // MARK: - PROFILE TAB (SOLO NOME)

    var profileTab: some View {
        NavigationView {
            VStack(spacing: 20) {

                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 120, height: 120)
                    .foregroundColor(.gray.opacity(0.5))

                TextField("Il tuo nome", text: $profileName)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: profileName) {
                        Storage.save(profileName, key: "profileName")
                    }

                Text("Saldo: €\(balance, specifier: "%.2f")")
                    .font(.title2)

                Spacer()
            }
            .navigationTitle("Profilo")
        }
    }

    // MARK: - COMPONENTS

    var betFloatingButton: some View {
        Button {
            showBetSheet = true
        } label: {
            Image(systemName: "bookmark.fill")
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .padding()
    }

    var calendarStrip: some View {
        HStack {
            ForEach(-1...1, id: \.self) { offset in
                let date = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate)!
                Button {
                    selectedDate = date
                } label: {
                    Text(date, style: .date)
                        .font(.caption)
                        .padding(8)
                        .background(date.isSameDay(as: selectedDate) ? Color(hex: "#44E0CB") : .clear)
                        .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - FAKE MATCHES

    func generateMatches(for date: Date) -> [Match] {
        [
            Match(home: "Napoli", away: "Roma", date: date, odds: [.home: 1.45, .draw: 3.8, .away: 6.2]),
            Match(home: "Inter", away: "Lecce", date: date, odds: [.home: 1.25, .draw: 4.5, .away: 8.0])
        ]
    }
}

// MARK: - BET SHEET

struct BetSheet: View {

    @Binding var predictions: [Prediction]
    @Binding var balance: Double
    @Binding var slips: [BetSlip]

    @State private var stake: Double = 1.0

    var body: some View {
        VStack {

            Text("La tua selezione").font(.headline)

            List {
                ForEach(predictions) { p in
                    HStack {
                        Text("\(p.match.home) – \(p.match.away)")
                        Spacer()
                        Text(p.outcome.rawValue)
                        Button(role: .destructive) {
                            predictions.removeAll { $0.id == p.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }

            Stepper("Importo €\(stake, specifier: "%.2f")", value: $stake, in: 1...balance)

            Button("Conferma selezione") {
                let totalOdds = predictions.reduce(1) { $0 * ($1.match.odds[$1.outcome] ?? 1) }
                let win = stake * totalOdds

                balance -= stake
                slips.insert(
                    BetSlip(
                        predictions: predictions,
                        stake: stake,
                        totalOdds: totalOdds,
                        potentialWin: win,
                        date: Date()
                    ),
                    at: 0
                )
                predictions.removeAll()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - DETAIL

struct SlipDetailView: View {
    let slip: BetSlip

    var body: some View {
        List {
            ForEach(slip.predictions) {
                Text("\($0.match.home) – \($0.match.away) | \($0.outcome.rawValue)")
            }
        }
        .navigationTitle("Dettaglio")
    }
}

// MARK: - UTILS

extension Date {
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}

extension Color {
    init(hex: String) {
        let v = Int(hex.dropFirst(), radix: 16) ?? 0
        self.init(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
        
    }
}
