//
//  BetSheet.swift
//  SportPredix
//
//  Created by Francesco on 16/01/26.
//

import SwiftUI

struct BetSheet: View {
    
    @Binding var picks: [BetPick]
    @Binding var balance: Double
    let totalOdd: Double
    let onConfirm: (Double) -> Void
    
    @State private var stakeText: String = "1"
    @Environment(\.presentationMode) var presentationMode
    
    var stake: Double {
        Double(stakeText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    var impliedProbability: Double {
        1 / totalOdd
    }
    
    var expectedValue: Double {
        (stake * totalOdd * impliedProbability) - stake
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                
                Capsule()
                    .fill(Color.gray)
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                
                Text("Schedina selezionata")
                    .font(.title2.bold())
                    .foregroundColor(.accentCyan)
                
                if picks.isEmpty {
                    Text("Devi selezionare un pronostico")
                        .foregroundColor(.accentCyan)
                        .font(.title2)
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(picks) { pick in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(pick.match.home) - \(pick.match.away)")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text("Esito: \(pick.outcome.rawValue) | Quota: \(pick.odd, specifier: "%.2f")")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        picks.removeAll { $0.id == pick.id }
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    VStack(spacing: 8) {
                        Text("Quota totale: \(totalOdd, specifier: "%.2f")")
                        Text("Probabilità implicita: \((impliedProbability * 100), specifier: "%.1f")%")
                        Text("Expected Value: €\(expectedValue, specifier: "%.2f")")
                            .foregroundColor(expectedValue >= 0 ? .green : .red)
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentCyan)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Importo:")
                            .foregroundColor(.white)
                        
                        TextField("Inserisci importo", text: $stakeText)
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                        
                        Text("€\(stake, specifier: "%.2f")")
                            .foregroundColor(.accentCyan)
                    }
                    
                    Button(action: {
                        guard stake > 0, stake <= balance else { return }
                        onConfirm(stake)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Conferma scommessa")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.black)
                            .cornerRadius(16)
                    }
                }
                
                Spacer()
            }
            .padding()
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width > 100 {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
            )
        }
    }
}
