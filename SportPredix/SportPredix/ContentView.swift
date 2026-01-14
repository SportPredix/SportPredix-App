//
//  ContentView.swift
//  SportPredix
//
//  Created by Formatiks Team on 12/01/26.
//


import SwiftUI

// MARK: - MODELS

enum MatchOutcome: String, CaseIterable, Identifiable {
    case homeWin = "Home"
    case draw = "Draw"
    case awayWin = "Away"

    var id: String { rawValue }

    var index: Int {
        switch self {
        case .homeWin: return 0
        case .draw: return 1
        case .awayWin: return 1
        }
    }
}

struct Match: Identifiable {
    let id = UUID()
    let homeTeam: String
    let awayTeam: String
    let odds: [Double]
}

struct Bet: Identifiable {
    let id = UUID()
    let match: Match
    let outcome: MatchOutcome
    let amount: Double
}

// MARK: - VIEW

struct ContentView: View {

    // MARK: - PERSISTED STATE
    @State private var balance: Double = UserDefaults.standard.double(forKey: "balance") == 0
        ? 1000
        : UserDefaults.standard.double(forKey: "balance")

    @State private var placedBets: [Bet] = []

    private let matches: [Match] = [
        Match(homeTeam: "Team A", awayTeam: "Team B", odds: [2.0, 3.5, 4.0]),
        Match(homeTeam: "Team C", awayTeam: "Team D", odds: [1.8, 3.2, 5.0]),
        Match(homeTeam: "Team E", awayTeam: "Team F", odds: [2.5, 3.0, 3.5])
    ]

    var body: some View {
        TabView {

            // MARK: - OGGI
            NavigationView {
                ZStack(alignment: .top) {
                    VStack {
                        List(matches) { match in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(match.homeTeam) vs \(match.awayTeam)")
                                    .font(.headline)

                                HStack {
                                    Button("Home (\(match.odds[0], specifier: "%.1f"))") {
                                        placeBet(match: match, outcome: .homeWin)
                                    }
                                    Button("Draw (\(match.odds[1], specifier: "%.1f"))") {
                                        placeBet(match: match, outcome: .draw)
                                    }
                                    Button("Away (\(match.odds[2], specifier: "%.1f"))") {
                                        placeBet(match: match, outcome: .awayWin)
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        Button("Simulate Results") {
                            simulateResults()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }

                    glassToolbar
                }
                .navigationBarHidden(true)
            }
            .tabItem {
                Label("Oggi", systemImage: "calendar")
            }

            // MARK: - PIAZZATE
            NavigationView {
                ZStack(alignment: .top) {
                    VStack {
                        if placedBets.isEmpty {
                            Text("Nessuna scommessa piazzata")
                                .font(.headline)
                                .padding()
                        } else {
                            List(placedBets) { bet in
                                Text(
                                    "\(bet.match.homeTeam) vs \(bet.match.awayTeam) – \(bet.outcome.rawValue) – $\(bet.amount)"
                                )
                            }
                        }
                    }
                    glassToolbar
                }
                .navigationBarHidden(true)
            }
            .tabItem {
                Label("Piazzate", systemImage: "list.bullet")
            }

            // MARK: - PROFILO
            NavigationView {
                ZStack(alignment: .top) {
                    VStack(spacing: 16) {
                        Text("Profilo")
                            .font(.largeTitle)

                        Text("Saldo: $\(balance, specifier: "%.2f")")
                            .font(.title2)

                        Text("Scommesse piazzate: \(placedBets.count)")
                    }
                    glassToolbar
                }
                .navigationBarHidden(true)
            }
            .tabItem {
                Label("Profilo", systemImage: "person")
            }
        }
        .onChange(of: balance) { newValue in
            UserDefaults.standard.set(newValue, forKey: "balance")
        }
    }

    // MARK: - GLASS TOOLBAR

    private var glassToolbar: some View {
        VStack {
            HStack {
                Text("SportPredix")
                    .font(.headline)

                Spacer()

                Text("$\(balance, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(.horizontal)
            .shadow(radius: 10)

            Spacer()
        }
    }

    // MARK: - LOGIC

    private func placeBet(match: Match, outcome: MatchOutcome) {
        let betAmount = 10.0
        guard balance >= betAmount else { return }

        balance -= betAmount
        placedBets.append(Bet(match: match, outcome: outcome, amount: betAmount))
    }

    private func simulateResults() {
        for bet in placedBets {
            let result = MatchOutcome.allCases.randomElement()!
            if result == bet.outcome {
                let winnings = bet.amount * bet.match.odds[bet.outcome.index]
                balance += winnings
            }
        }
        placedBets.removeAll()
    }
}

// MARK: - PREVIEW

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
