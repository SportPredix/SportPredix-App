//
//  MatchDetailsView.swift
//  SportPredix
//
//  Created by Francesco on 16/01/26.
//

import SwiftUI

struct MatchDetailView: View {
    let match: Match
    @ObservedObject var vm: BettingViewModel
    
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab = 0
    
    let tabOptions = ["Tutti", "1X2", "Doppia chance", "U/O", "1X2 Hard"]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // HEADER
                VStack(spacing: 12) {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.accentCyan)
                                .font(.system(size: 20, weight: .semibold))
                        }
                        
                        Spacer()
                        
                        Text(match.time)
                            .font(.subheadline)
                            .foregroundColor(.accentCyan)
                        
                        Spacer()
                        
                        // Spazio vuoto per bilanciare
                        Color.clear.frame(width: 24, height: 24)
                    }
                    .padding(.horizontal)
                    
                    Text("\(match.home) - \(match.away)")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // TAB BAR ORIZZONTALE
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(0..<tabOptions.count, id: \.self) { index in
                                VStack(spacing: 8) {
                                    Text(tabOptions[index])
                                        .font(.subheadline)
                                        .foregroundColor(selectedTab == index ? .accentCyan : .gray)
                                    
                                    if selectedTab == index {
                                        Rectangle()
                                            .fill(Color.accentCyan)
                                            .frame(height: 2)
                                            .frame(width: 60)
                                    }
                                }
                                .padding(.vertical, 8)
                                .onTapGesture {
                                    withAnimation {
                                        selectedTab = index
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)
                }
                .padding(.top)
                
                // CONTENUTO BASATO SUL TAB SELEZIONATO
                ScrollView {
                    VStack(spacing: 20) {
                        if selectedTab == 0 { // Tutti
                            odds1X2Section
                            oddsDoubleChanceSection
                            oddsOverUnderSection
                        } else if selectedTab == 1 { // 1X2
                            odds1X2Section
                        } else if selectedTab == 2 { // Doppia chance
                            oddsDoubleChanceSection
                        } else if selectedTab == 3 { // U/O
                            oddsOverUnderSection
                        } else if selectedTab == 4 { // 1X2 Hard
                            odds1X2HardSection
                        }
                    }
                    .padding()
                }
            }
            
            // FLOATING BUTTON (SOLO QUI, PIÙ IN BASSO)
            if !vm.currentPicks.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack(alignment: .topTrailing) {
                            Button { vm.showSheet = true } label: {
                                Image(systemName: "rectangle.stack.fill")
                                    .foregroundColor(.black)
                                    .padding(16)
                                    .background(Color.accentCyan)
                                    .clipShape(Circle())
                                    .shadow(radius: 10)
                            }
                            
                            Text("\(vm.currentPicks.count)")
                                .font(.caption2.bold())
                                .padding(4)
                                .background(Color.red)
                                .clipShape(Circle())
                                .foregroundColor(.white)
                                .offset(x: 8, y: -8)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20) // POSIZIONE PIÙ IN BASSO SULLA TOOLBAR
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 100 {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
    }
    
    // MARK: - SEZIONI QUOTE
    
    private var odds1X2Section: some View {
        VStack(spacing: 12) {
            Text("1X2")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            
            HStack(spacing: 10) {
                oddButton("1", .home, match.odds.home)
                oddButton("X", .draw, match.odds.draw)
                oddButton("2", .away, match.odds.away)
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
    
    private var oddsDoubleChanceSection: some View {
        VStack(spacing: 12) {
            Text("Doppia Chance")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            
            HStack(spacing: 10) {
                oddButton("1X", .homeDraw, match.odds.homeDraw)
                oddButton("X2", .drawAway, match.odds.drawAway)
                oddButton("12", .homeAway, match.odds.homeAway)
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
    
    private var oddsOverUnderSection: some View {
        VStack(spacing: 16) {
            Text("Over/Under")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    oddButton("U 0.5", .under05, match.odds.under05)
                    oddButton("O 0.5", .over05, match.odds.over05)
                }
                
                HStack(spacing: 10) {
                    oddButton("U 1.5", .under15, match.odds.under15)
                    oddButton("O 1.5", .over15, match.odds.over15)
                }
                
                HStack(spacing: 10) {
                    oddButton("U 2.5", .under25, match.odds.under25)
                    oddButton("O 2.5", .over25, match.odds.over25)
                }
                
                HStack(spacing: 10) {
                    oddButton("U 3.5", .under35, match.odds.under35)
                    oddButton("O 3.5", .over35, match.odds.over35)
                }
                
                HStack(spacing: 10) {
                    oddButton("U 4.5", .under45, match.odds.under45)
                    oddButton("O 4.5", .over45, match.odds.over45)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
    
    private var odds1X2HardSection: some View {
        VStack(spacing: 16) {
            Text("1X2 Hard")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            
            Text("Disponibile a breve")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding()
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
    
    private func oddButton(_ label: String, _ outcome: MatchOutcome, _ odd: Double) -> some View {
        let isSelected = vm.currentPicks.contains { $0.match.id == match.id && $0.outcome == outcome }
        
        return Button {
            vm.addPick(match: match, outcome: outcome, odd: odd)
        } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 16, weight: .bold))
                Text(String(format: "%.2f", odd))
                    .font(.system(size: 14))
            }
            .foregroundColor(isSelected ? .accentCyan : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentCyan : Color.white.opacity(0.2), lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
