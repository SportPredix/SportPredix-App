//
//  ContentView.swift
//  SportPredix
//
//  Created by Francesco on 12/01/26.
//

import SwiftUI

struct ContentView: View {
    @State private var balance: Double = 1000.0
    @State private var matches: [Match] = [
        Match(homeTeam: "Team A", awayTeam: "Team B", odds: [2.0, 3.5, 4.0]),
        Match(homeTeam: "Team C", awayTeam: "Team D", odds: [1.8, 3.2, 5.0]),
        Match(homeTeam: "Team E", awayTeam: "Team F", odds: [2.5, 3.0, 3.5])
    ]
    @State private var placedBets: [Bet] = []

    var body: some View {
        TabView {
            // Oggi Tab
            NavigationView {
                VStack {
                    List(matches) { match in
                        VStack(alignment: .leading) {
                            Text("\(match.homeTeam) vs \(match.awayTeam)")
                                .font(.headline)
                            HStack {
                                Button("Home Win (\(match.odds[0], specifier: "%.1f"))") {
                                    placeBet(match: match, outcome: .homeWin)
                                }
                                .buttonStyle(.bordered)
                                Spacer()
                                Button("Draw (\(match.odds[1], specifier: "%.1f"))") {
                                    placeBet(match: match, outcome: .draw)
                                }
                                .buttonStyle(.bordered)
                                Spacer()
                                Button("Away Win (\(match.odds[2], specifier: "%.1f"))") {
                                    placeBet(match: match, outcome: .awayWin)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    Button("Simulate Results") {
                        simulateResults()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
                .navigationTitle("")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Text("SportPredix")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("$\(balance, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
            }
            .tabItem {
                Label("Oggi", systemImage: "calendar")
            }

            // Piazzate Tab
            NavigationView {
                VStack {
                    if placedBets.isEmpty {
                        Text("Nessuna scommessa piazzata")
                            .font(.headline)
                            .padding()
                    } else {
                        List(placedBets) { bet in
                            Text("\(bet.match.homeTeam) vs \(bet.match.awayTeam) - \(bet.outcome.rawValue) - $\(bet.amount)")
                        }
                    }
                }
                .navigationTitle("")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Text("SportPredix")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("$\(balance, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
            }
            .tabItem {
                Label("Piazzate", systemImage: "list.bullet")
            }

            // Leghe Tab
            NavigationView {
                VStack {
                    Text("Leghe")
                        .font(.largeTitle)
                        .padding()
                    Text("Funzionalità in arrivo...")
                        .foregroundColor(.gray)
                }
                .navigationTitle("")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Text("SportPredix")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("$\(balance, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
            }
            .tabItem {
                Label("Leghe", systemImage: "trophy")
            }

            // Profilo Tab
            NavigationView {
                VStack {
                    Text("Profilo")
                        .font(.largeTitle)
                        .padding()
                    Text("Scommesse piazzate: \(placedBets.count)")
                        .font(.title)
                        .padding()
                }
                .navigationTitle("")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Text("SportPredix")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("$\(balance, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
            }
            .tabItem {
                Label("Profilo", systemImage: "person")
            }
        }
    }

    private func placeBet(match: Match, outcome: MatchOutcome) {
        // Simple bet placement - in a real app, you'd have amount input
        let betAmount = 10.0
        if balance >= betAmount {
            balance -= betAmount
            placedBets.append(Bet(match: match, outcome: outcome, amount: betAmount))
        }
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
        // In a real app, you'd update match results and show them
    }
}

#Preview {
    ContentView()
}
