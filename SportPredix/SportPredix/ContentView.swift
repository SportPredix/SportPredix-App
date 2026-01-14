//
//  ContentView.swift
//  SportPredix
//
//  Created by Formatiks Team on 12/01/26.
//


import SwiftUI

// MARK: - THEME

extension Color {
    static let accentCyan = Color(red: 68/255, green: 224/255, blue: 203/255)
}

// MARK: - MODELS

enum MatchOutcome: String {
    case home = "1"
    case draw = "X"
    case away = "2"
}

struct Match: Identifiable {
    let id = UUID()
    let home: String
    let away: String
    let time: String
    let odds: [Double]
}

struct BetPick: Identifiable {
    let id = UUID()
    let match: Match
    let outcome: MatchOutcome
    let odd: Double
}

struct BetSlip: Identifiable {
    let id = UUID()
    let picks: [BetPick]
    let stake: Double
    let totalOdd: Double
    let potentialWin: Double
    let date = Date()
}

// MARK: - MAIN VIEW

struct ContentView: View {

    @State private var selectedTab = 0
    @State private var showSheet = false
    @State private var showSlipDetail: BetSlip?

    @State private var balance: Double =
        UserDefaults.standard.double(forKey: "balance") == 0 ? 1000 :
        UserDefaults.standard.double(forKey: "balance")

    @State private var currentPicks: [BetPick] = []
    @State private var slips: [BetSlip] = []

    private let matches: [Match] = [
        Match(home: "Napoli", away: "Parma", time: "18:30", odds: [1.33, 4.20, 7.00]),
        Match(home: "Inter", away: "Lecce", time: "20:45", odds: [1.19, 5.00, 10.0]),
        Match(home: "Colonia", away: "Bayern Monaco", time: "20:30", odds: [6.50, 4.80, 1.24]),
        Match(home: "Albacete", away: "Real Madrid", time: "21:00", odds: [9.00, 6.20, 1.24])
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if selectedTab == 0 {
                    matchList
                } else {
                    placedBets
                }

                bottomBar
            }

            if !currentPicks.isEmpty {
                floatingButton
            }
        }
        .sheet(isPresented: $showSheet) {
            BetSheet(
                picks: $currentPicks,
                balance: $balance
            ) { slip in
                slips.insert(slip, at: 0)
            }
        }
        .sheet(item: $showSlipDetail) { slip in
            SlipDetailView(slip: slip)
        }
        .onChange(of: balance) {
            UserDefaults.standard.set($0, forKey: "balance")
        }
    }

    // MARK: HEADER

    private var header: some View {
        HStack {
            Text(selectedTab == 0 ? "Calendario" : "Piazzate")
                .font(.largeTitle.bold())
                .foregroundColor(.white)

            Spacer()

            Text("€\(balance, specifier: "%.2f")")
                .foregroundColor(.accentCyan)
                .bold()
        }
        .padding()
    }

    // MARK: MATCH LIST

    private var matchList: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(matches) { match in
                    VStack(spacing: 10) {
                        HStack {
                            Text(match.home)
                            Spacer()
                            Text(match.time).bold()
                            Spacer()
                            Text(match.away)
                        }
                        .foregroundColor(.white)

                        HStack(spacing: 10) {
                            oddButton("1", match, .home, match.odds[0])
                            oddButton("X", match, .draw, match.odds[1])
                            oddButton("2", match, .away, match.odds[2])
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(16)
                }
            }
            .padding()
        }
    }

    private func oddButton(_ label: String, _ match: Match, _ outcome: MatchOutcome, _ odd: Double) -> some View {
        Button {
            if !currentPicks.contains(where: { $0.match.id == match.id }) {
                currentPicks.append(BetPick(match: match, outcome: outcome, odd: odd))
            }
        } label: {
            VStack {
                Text(label).bold()
                Text(String(format: "%.2f", odd)).font(.caption)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Color.accentCyan)
            .cornerRadius(12)
        }
    }

    // MARK: PLACED BETS

    private var placedBets: some View {
        ScrollView {
            VStack(spacing: 12) {
                if slips.isEmpty {
                    Text("Nessuna scommessa piazzata")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(slips) { slip in
                        Button {
                            showSlipDetail = slip
                        } label: {
                            VStack(alignment: .leading) {
                                Text("Quota \(slip.totalOdd, specifier: "%.2f")")
                                    .foregroundColor(.accentCyan)
                                Text("Puntata €\(slip.stake, specifier: "%.2f")")
                                    .foregroundColor(.white)
                                Text("Vincita potenziale €\(slip.potentialWin, specifier: "%.2f")")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(14)
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: BOTTOM BAR

    private var bottomBar: some View {
        HStack {
            bottomItem("calendar", "Calendario", 0)
            Spacer()
            bottomItem("list.bullet", "Piazzate", 1)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(26)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func bottomItem(_ icon: String, _ title: String, _ index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack {
                Image(systemName: icon)
                Text(title).font(.caption)
            }
            .foregroundColor(selectedTab == index ? .accentCyan : .white)
        }
    }

    // MARK: FLOATING BUTTON

    private var floatingButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showSheet = true
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundColor(.black)
                        .padding(16)
                        .background(Color.accentCyan)
                        .clipShape(Circle())
                        .shadow(radius: 10)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 90)
            }
        }
    }
}

// MARK: - BET SHEET

struct BetSheet: View {

    @Binding var picks: [BetPick]
    @Binding var balance: Double
    let onConfirm: (BetSlip) -> Void

    @State private var stake: Double = 1

    private var totalOdd: Double {
        picks.map { $0.odd }.reduce(1, *)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Capsule().fill(Color.gray).frame(width: 40, height: 5)

                ForEach(picks) { pick in
                    HStack {
                        Text("\(pick.match.home) - \(pick.match.away)")
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            picks.removeAll { $0.id == pick.id }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }

                Text("Importo €\(stake, specifier: "%.2f")")
                    .foregroundColor(.white)

                Slider(value: $stake, in: 1...min(balance, 500), step: 1)
                    .accentColor(.accentCyan)

                Button("Conferma selezione") {
                    let slip = BetSlip(
                        picks: picks,
                        stake: stake,
                        totalOdd: totalOdd,
                        potentialWin: stake * totalOdd
                    )
                    balance -= stake
                    picks.removeAll()
                    onConfirm(slip)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .foregroundColor(.black)
                .cornerRadius(16)

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - SLIP DETAIL

struct SlipDetailView: View {
    let slip: BetSlip

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Dettaglio scommessa")
                    .foregroundColor(.white)
                    .font(.headline)

                ForEach(slip.picks) { pick in
                    Text("\(pick.match.home) - \(pick.match.away) | \(pick.outcome.rawValue)")
                        .foregroundColor(.white)
                }

                Text("Quota: \(slip.totalOdd, specifier: "%.2f")")
                Text("Puntata: €\(slip.stake, specifier: "%.2f")")
                Text("Vincita potenziale: €\(slip.potentialWin, specifier: "%.2f")")
            }
            .foregroundColor(.accentCyan)
            .padding()
        }
    }
}
