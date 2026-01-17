//
//  SlipDetailView.swift
//  SportPredix
//
//  Created by Francesco on 16/01/26.
//

import SwiftUI

struct SlipDetailView: View {
    let slip: BetSlip
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                
                Capsule()
                    .fill(Color.gray)
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                
                Text("Dettaglio scommessa")
                    .font(.title2.bold())
                    .foregroundColor(.accentCyan)
                
                ScrollView {
                    VStack(spacing: 16) {
                        
                        ForEach(slip.picks) { pick in
                            VStack(spacing: 10) {
                                
                                Text("\(pick.match.home) - \(pick.match.away)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Orario: \(pick.match.time)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Text("Esito giocato: \(pick.outcome.rawValue)")
                                    .font(.subheadline)
                                    .foregroundColor(.accentCyan)
                                
                                if let result = pick.match.result {
                                    Text("Risultato reale: \(result.rawValue)")
                                        .foregroundColor(.white)
                                }
                                
                                if let goals = pick.match.goals {
                                    Text("Gol totali: \(goals)")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(14)
                        }
                        
                        VStack(spacing: 12) {
                            
                            HStack {
                                Text("Quota totale:")
                                Spacer()
                                Text("\(slip.totalOdd, specifier: "%.2f")")
                            }
                            
                            HStack {
                                Text("Puntata:")
                                Spacer()
                                Text("€\(slip.stake, specifier: "%.2f")")
                            }
                            
                            HStack {
                                Text("Vincita potenziale:")
                                Spacer()
                                Text("€\(slip.potentialWin, specifier: "%.2f")")
                            }
                            
                            if let won = slip.isWon {
                                HStack {
                                    Text("Esito schedina:")
                                    Spacer()
                                    Text(won ? "VINTA" : "PERSA")
                                        .foregroundColor(won ? .green : .red)
                                        .bold()
                                }
                            }
                        }
                        .font(.body)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }
    }
}
