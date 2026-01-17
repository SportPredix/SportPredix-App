//
//  GameView.swift
//  SportPredix
//
//  Created by Francesco on 16/01/26.
//

import SwiftUI

struct GamesView: View {
    let games = [
        ("Gratta e Vinci", "square.grid.3x3.fill"),
        ("Crazy Time", "clock"),
        ("Slot Machine", "play.square"),
        ("Roulette", "circle.grid.cross"),
        ("Blackjack", "suit.club"),
        ("Poker", "suit.spade")
    ]
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    @EnvironmentObject var vm: BettingViewModel
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(games, id: \.0) { game in
                            GameButton(title: game.0, icon: game.1)
                                .environmentObject(vm)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct GameButton: View {
    let title: String
    let icon: String
    @State private var showGame = false
    @EnvironmentObject var vm: BettingViewModel
    
    var body: some View {
        Button {
            showGame = true
        } label: {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(.accentCyan)
                    .padding(.bottom, 8)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 160, height: 160)
            .background(Color.white.opacity(0.08))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.accentCyan.opacity(0.3), lineWidth: 2)
            )
        }
        .sheet(isPresented: $showGame) {
            if title == "Gratta e Vinci" {
                ScratchCardView(balance: $vm.balance)
            } else {
                ComingSoonView()
            }
        }
    }
}

struct ScratchCardView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var balance: Double
    
    @State private var scratchedPoints: [CGPoint] = []
    @State private var isScratched = false
    @State private var prize: Int = 0
    @State private var showPrize = false
    @State private var opacity: Double = 1.0
    @State private var showResult = false
    @State private var scratchesNeeded = 50
    @State private var currentScratches = 0
    
    let prizes = [0, 0, 0, 50, 0, 100, 0, 0, 250, 0, 500, 1000, 0, 0, 0, 0, 500, 0, 50, 0, 100, 0, 250, 0, 0, 0, 100, 0, 500, 0, 1000, 0, 50, 0, 0, 250]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.accentCyan)
                            .font(.system(size: 22))
                    }
                    
                    Spacer()
                    
                    Text("Gratta e Vinci")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Spazio per bilanciare
                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(.horizontal)
                .padding(.top)
                
                if !showResult {
                    // Instructions
                    VStack(spacing: 8) {
                        Text("Gratta l'area grigia per scoprire il premio!")
                            .font(.headline)
                            .foregroundColor(.accentCyan)
                        
                        Text("Premi: €0, €50, €100, €250, €500, €1000")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("Gratta \(currentScratches)/\(scratchesNeeded) per rivelare")
                            .font(.caption)
                            .foregroundColor(.accentCyan)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal)
                    
                    // Scratch Card Area
                    ZStack {
                        // Hidden prize (sotto)
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.accentCyan.opacity(0.3))
                            .frame(width: 300, height: 300)
                            .overlay(
                                VStack {
                                    if prize > 0 {
                                        Text("€\(prize)")
                                            .font(.system(size: 48, weight: .bold))
                                            .foregroundColor(.black)
                                        Text("HAI VINTO!")
                                            .font(.title2.bold())
                                            .foregroundColor(.black)
                                    } else {
                                        Text("Nessun Premio")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.black)
                                        Text("Ritenta!")
                                            .font(.title2)
                                            .foregroundColor(.black)
                                    }
                                }
                            )
                        
                        // Scratchable layer (sopra)
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray)
                            .frame(width: 300, height: 300)
                            .overlay(
                                ZStack {
                                    LinearGradient(
                                        gradient: Gradient(colors: [.gray.opacity(0.8), .gray.opacity(0.6)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    
                                    Image(systemName: "hand.tap.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.3))
                                    
                                    Text("Gratta qui!")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.5))
                                        .padding(.top, 80)
                                }
                            )
                            .opacity(opacity)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if !isScratched && opacity > 0 {
                                            let newPoint = value.location
                                            scratchedPoints.append(newPoint)
                                            currentScratches += 1
                                            
                                            // Diminuisci opacità quando gratti
                                            opacity = max(0.0, opacity - 0.015)
                                            
                                            // Se grattato abbastanza, rivela
                                            if currentScratches >= scratchesNeeded {
                                                revealPrize()
                                            }
                                        }
                                    }
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.accentCyan.opacity(0.3), lineWidth: 3)
                    )
                    
                    // Action buttons
                    HStack(spacing: 20) {
                        Button("Reset") {
                            resetScratchCard()
                        }
                        .padding()
                        .background(Color.red.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        
                        Button("Rivela Ora") {
                            revealPrize()
                        }
                        .padding()
                        .background(Color.accentCyan)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                        .disabled(isScratched)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                } else {
                    // Result Screen
                    VStack(spacing: 25) {
                        Image(systemName: prize > 0 ? "gift.fill" : "xmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(prize > 0 ? .accentCyan : .red)
                        
                        Text(prize > 0 ? "COMPLIMENTI!" : "MI DISPIACE")
                            .font(.largeTitle.bold())
                            .foregroundColor(prize > 0 ? .accentCyan : .white)
                        
                        Text(prize > 0 ? "€\(prize)" : "Ritenta, sarai più fortunato!")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(prize > 0 ? .yellow : .gray)
                        
                        if prize > 0 {
                            Text("+ €\(prize) aggiunti al tuo saldo")
                                .font(.body)
                                .foregroundColor(.green)
                                .padding(.top, 5)
                        }
                        
                        Button {
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Text(prize > 0 ? "Gioca Ancora" : "Riprova")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentCyan)
                                .cornerRadius(16)
                        }
                        .padding(.top, 20)
                        
                        Button {
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Text("Torna ai Giochi")
                                .font(.headline)
                                .foregroundColor(.accentCyan)
                                .padding(.top, 10)
                        }
                    }
                    .padding(30)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(25)
                    .padding(.horizontal, 20)
                }
            }
            .padding()
        }
        .onAppear {
            // Seleziona premio casuale all'avvio
            prize = prizes.randomElement() ?? 0
        }
    }
    
    private func revealPrize() {
        withAnimation(.easeInOut(duration: 0.8)) {
            isScratched = true
            opacity = 0.0
            
            // Aspetta un po' poi mostra il risultato
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showResult = true
                
                // Aggiungi premio al saldo
                if prize > 0 {
                    balance += Double(prize)
                }
            }
        }
    }
    
    private func resetScratchCard() {
        scratchedPoints = []
        isScratched = false
        opacity = 1.0
        currentScratches = 0
        showResult = false
        // Seleziona nuovo premio casuale
        prize = prizes.randomElement() ?? 0
    }
}

struct ComingSoonView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.gray)
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                
                Image(systemName: "clock")
                    .font(.system(size: 60))
                    .foregroundColor(.accentCyan)
                
                Text("Presto in arrivo!")
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                Text("Questa funzionalità è attualmente in sviluppo.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Chiudi") {
                    // Dismiss sheet
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        rootViewController.dismiss(animated: true)
                    }
                }
                .padding()
                .background(Color.accentCyan)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
            .padding()
        }
    }
}