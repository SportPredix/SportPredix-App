//
//  ContentView.swift
//  SportPredix
//
//  Created by Formatiks Team on 12/01/26.
//


import SwiftUI
import PhotosUI

// MARK: - MODELS

enum Outcome: String, Codable, CaseIterable {
    case home = "1"
    case draw = "X"
    case away = "2"
}

struct Match: Identifiable, Codable {
    var id = UUID()
    let home: String
    let away: String
    let date: Date
    let odds: [Outcome: Double]
}

struct Prediction: Identifiable, Codable {
    var id = UUID()
    let match: Match
    let outcome: Outcome
}

enum SlipResult: String, Codable {
    case pending
    case won
    case lost
}

struct BetSlip: Identifiable, Codable {
    var id = UUID()
    let predictions: [Prediction]
    let stake: Double
    let totalOdds: Double
    let potentialWin: Double
    let date: Date
    let result: SlipResult
}

// MARK: - STORAGE (SAFE)

enum Storage {

    static func save<T: Codable>(_ value: T, key: String) {
        let data = try? JSONEncoder().encode(value)
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load<T: Codable>(_ key: String, as type: T.Type) -> T? {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode(type, from: data)
        else { return nil }
        return decoded
    }

    // IMMAGINI (SAFE)
    static func saveImage(_ image: UIImage, key: String) {
        UserDefaults.standard.set(image.pngData(), forKey: key)
    }

    static func loadImage(key: String) -> UIImage? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - MAIN VIEW

struct ContentView: View {

    @State private var balance: Double = Storage.load("balance", as: Double.self) ?? 1000
    @State private var predictions: [Prediction] = []
    @State private var slips: [BetSlip] = Storage.load("slips", as: [BetSlip].self) ?? []

    @State private var selectedDate: Date = Date()
    @State private var showBetSheet = false

    // PROFILO
    @State private var profileName: String = Storage.load("profileName", as: String.self) ?? ""
    @State private var profileImage: UIImage? = Storage.loadImage(key: "profileImage")
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        TabView {

            calendarTab
                .tabItem { Label("Oggi", systemImage: "calendar") }

            slipsTab
                .tabItem { Label("Piazzate", systemImage: "list.bullet.rectangle") }

            profileTab
                .tabItem { Label("Profilo", systemImage: "person.crop.circle") }
        }
        .tint(Color(hex: "#44E0CB"))
        .overlay(alignment: .bottomTrailing) {
            floatingBetButton
        }
        .sheet(isPresented: $showBetSheet) {
            BetSheet(predictions: $predictions, balance: $balance, slips: $slips)
        }
        .onChange(of: slips) { Storage.save(slips, key: "slips") }
        .onChange(of: balance) { Storage.save(balance, key: "balance") }
        .onChange(of: profileName) { Storage.save(profileName, key: "profileName") }
        .onChange(of: photoItem) {
            Task {
                if let data = try? await photoItem?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    profileImage = img
                    Storage.saveImage(img, key: "profileImage")
                }
            }
        }
    }

    // MARK: - CALENDAR

    var calendarTab: some View {
        NavigationView {
            VStack(spacing: 8) {

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
                                    VStack {
                                        Text(outcome.rawValue)
                                        Text(match.odds[outcome]!, specifier: "%.2f")
                                    }
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

    var calendarStrip: some View {
        HStack {
            ForEach(-1...1, id: \.self) { offset in
                let day = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate)!
                Button {
                    selectedDate = day
                } label: {
                    Text(day, style: .date)
                        .font(.caption)
                        .padding(8)
                        .background(day.isSameDay(as: selectedDate) ? Color(hex: "#44E0CB") : .clear)
                        .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - SLIPS

    var slipsTab: some View {
        NavigationView {
            List(slips) { slip in
                NavigationLink {
                    SlipDetailView(slip: slip)
                } label: {
                    VStack(alignment: .leading) {
                        Text("Multipla \(slip.predictions.count) eventi")
                        Text("€\(slip.stake, specifier: "%.2f") → €\(slip.potentialWin, specifier: "%.2f")")
                        Text(slip.result.rawValue.uppercased())
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Storico")
        }
    }

    // MARK: - PROFILE

    var profileTab: some View {
        NavigationView {
            VStack(spacing: 20) {

                if let img = profileImage {
                    Image(uiImage: img)
                        .resizable()
                        .clipShape(Circle())
                        .frame(width: 120, height: 120)
                } else {
                    Circle().fill(.gray.opacity(0.3))
                        .frame(width: 120, height: 120)
                }

                PhotosPicker("Carica foto", selection: $photoItem, matching: .images)

                TextField("Il tuo nome", text: $profileName)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                Text("Saldo: €\(balance, specifier: "%.2f")")
                    .font(.title2)

                Spacer()
            }
            .navigationTitle("Profilo")
        }
    }

    // MARK: - BUTTON

    var floatingBetButton: some View {
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

    // MARK: - MATCH GENERATION

    func generateMatches(for date: Date) -> [Match] {
        [
            Match(home: "Napoli", away: "Roma", date: date, odds: [.home: 1.6, .draw: 3.9, .away: 5.5]),
            Match(home: "Inter", away: "Lecce", date: date, odds: [.home: 1.3, .draw: 4.6, .away: 8.2])
        ]
    }
}

// MARK: - BET SHEET

struct BetSheet: View {

    @Binding var predictions: [Prediction]
    @Binding var balance: Double
    @Binding var slips: [BetSlip]

    @State private var stake: Double = 1

    var body: some View {
        VStack {
            List {
                ForEach(predictions) { p in
                    HStack {
                        Text("\(p.match.home) – \(p.match.away)")
                        Spacer()
                        Text(p.outcome.rawValue)
                    }
                }
                .onDelete {
                    predictions.remove(atOffsets: $0)
                }
            }

            Stepper("Importo €\(stake, specifier: "%.2f")", value: $stake, in: 1...balance)

            Button("Conferma") {
                let odds = predictions.reduce(1) { $0 * ($1.match.odds[$1.outcome] ?? 1) }
                let win = stake * odds

                balance -= stake

                slips.insert(
                    BetSlip(
                        predictions: predictions,
                        stake: stake,
                        totalOdds: odds,
                        potentialWin: win,
                        date: Date(),
                        result: .pending
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
        .navigationTitle("Schedina")
    }
}

// MARK: - UTIL

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
