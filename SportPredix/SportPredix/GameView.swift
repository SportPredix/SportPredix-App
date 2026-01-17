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
                
                if title == "Gratta e Vinci" {
                    Text("€50")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .padding(.top, 2)
                }
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
                ScratchCardView(balance: $vm.balance, isPresented: $showGame)
            } else {
                ComingSoonView(isPresented: $showGame)
            }
        }
    }
}

struct ScratchCardView: View {
    @Binding var balance: Double
    @Binding var isPresented: Bool
    
    @State private var scratchedPoints: [CGPoint] = []
    @State private var isScratched = false
    @State private var prize: Int = 0
    @State private var opacity: Double = 1.0
    @State private var showResult = false
    @State private var scratchesNeeded = 40
    @State private var currentScratches = 0
    @State private var isPlaying = true
    @State private var showCantPlayAlert = false
    
    // Premi migliori - meno "0"
    let prizes = [50, 100, 0, 250, 50, 100, 0, 500, 1000, 50, 0, 250, 100, 0, 500, 50, 1000, 250, 100, 50]
    
    // Costo fisso del biglietto
    let ticketPrice = 50.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header con saldo e costo
                HStack {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.accentCyan)
                            .font(.system(size: 22))
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("Gratta e Vinci")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text("Costo: €\(Int(ticketPrice))")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Saldo")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("€\(balance, specifier: "%.0f")")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.accentCyan)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                if !showResult && isPlaying {
                    // Schermata di gioco
                    gameView
                } else if showResult {
                    // Schermata risultato
                    resultView
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            // Controlla se può pagare il biglietto
            if balance >= ticketPrice {
                startNewGame()
            } else {
                showCantPlayAlert = true
            }
        }
        .alert("Saldo insufficiente", isPresented: $showCantPlayAlert) {
            Button("OK") {
                isPresented = false
            }
        } message: {
            Text("Ti servono €\(Int(ticketPrice)) per giocare a Gratta e Vinci.\nIl tuo saldo è €\(balance, specifier: "%.0f")")
        }
    }
    
    private var gameView: some View {
        VStack(spacing: 25) {
            // Instructions
            VStack(spacing: 8) {
                Text("Gratta per scoprire il premio!")
                    .font(.headline)
                    .foregroundColor(.accentCyan)
                
                Text("Premi: €50, €100, €250, €500, €1000")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Text("Gratta \(currentScratches)/\(scratchesNeeded) per rivelare")
                    .font(.caption)
                    .foregroundColor(currentScratches >= scratchesNeeded ? .green : .accentCyan)
                    .padding(.top, 4)
            }
            .padding(.horizontal)
            
            // Scratch Card Area
            ZStack {
                // Premio nascosto (sotto)
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: 
                                prize > 0 ? 
                                [Color.yellow.opacity(0.4), Color.orange.opacity(0.6)] :
                                [Color.gray.opacity(0.3), Color.gray.opacity(0.5)]
                            ),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 300, height: 300)
                    .overlay(
                        VStack(spacing: 15) {
                            if prize > 0 {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.yellow)
                                    .shadow(color: .yellow, radius: 10)
                                
                                Text("€\(prize)")
                                    .font(.system(size: 52, weight: .bold))
                                    .foregroundColor(.black)
                                    .shadow(color: .white, radius: 2)
                                
                                Text("HAI VINTO!")
                                    .font(.title2.bold())
                                    .foregroundColor(.black)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                                Text("RITENTA")
                                    .font(.system(size: 38, weight: .bold))
                                    .foregroundColor(.black)
                                
                                Text("La prossima volta\nsarai più fortunato!")
                                    .font(.caption)
                                    .foregroundColor(.black.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                        }
                    )
                
                // Layer grattabile (sopra)
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray)
                    .frame(width: 300, height: 300)
                    .overlay(
                        ZStack {
                            // Texture scratch
                            LinearGradient(
                                gradient: Gradient(colors: [.gray.opacity(0.9), .gray.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            // Pattern di gratta
                            Image(systemName: "scissors")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.2))
                                .rotationEffect(.degrees(45))
                            
                            VStack(spacing: 10) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.4))
                                
                                Text("GRATTA QUI")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.top, 20)
                            }
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
                                    opacity = max(0.0, opacity - 0.02)
                                    
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
                    .stroke(Color.accentCyan.opacity(0.4), lineWidth: 3)
            )
            
            // Pulsanti azione
            HStack(spacing: 20) {
                Button {
                    resetScratchCard()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Ricomincia")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button {
                    revealPrize()
                } label: {
                    HStack {
                        Image(systemName: "eye.fill")
                        Text("Rivela")
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.accentCyan)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .disabled(isScratched)
            }
            .padding(.top, 10)
        }
    }
    
    private var resultView: some View {
        VStack(spacing: 30) {
            // Icona risultato
            Image(systemName: prize > 0 ? "trophy.fill" : "hourglass")
                .font(.system(size: 80))
                .foregroundColor(prize > 0 ? .yellow : .gray)
                .scaleEffect(1.2)
            
            // Titolo risultato
            Text(prize > 0 ? "COMPLIMENTI!" : "PECCATO...")
                .font(.largeTitle.bold())
                .foregroundColor(prize > 0 ? .accentCyan : .white)
            
            // Importo
            Text(prize > 0 ? "+ €\(prize)" : "€0")
                .font(.system(size: 56, weight: .heavy))
                .foregroundColor(prize > 0 ? .yellow : .gray)
                .padding(.vertical, 10)
            
            // Messaggio
            VStack(spacing: 8) {
                if prize > 0 {
                    Text("Hai vinto €\(prize)!")
                        .font(.title3)
                        .foregroundColor(.green)
                    
                    Text("Il premio è stato aggiunto al tuo saldo")
                        .font(.body)
                        .foregroundColor(.gray)
                } else {
                    Text("Il biglietto non era vincente")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("Costo biglietto: -€\(Int(ticketPrice))")
                        .font(.body)
                        .foregroundColor(.red)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            
            // Nuovo saldo
            VStack(spacing: 4) {
                Text("Nuovo saldo:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("€\(balance, specifier: "%.0f")")
                    .font(.title2.bold())
                    .foregroundColor(.accentCyan)
            }
            .padding(.vertical, 10)
            
            // Pulsanti azione
            VStack(spacing: 15) {
                Button {
                    // Controlla se può pagare un nuovo biglietto
                    if balance >= ticketPrice {
                        startNewGame()
                    } else {
                        isPresented = false
                    }
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("GIOCA ANCORA (€\(Int(ticketPrice)))")
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(balance >= ticketPrice ? Color.accentCyan : Color.gray)
                    .cornerRadius(16)
                }
                .disabled(balance < ticketPrice)
                
                Button {
                    isPresented = false
                } label: {
                    Text("TORNA AI GIOCHI")
                        .font(.headline)
                        .foregroundColor(.accentCyan)
                        .padding(.top, 5)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(30)
        .background(Color.white.opacity(0.08))
        .cornerRadius(25)
        .padding(.horizontal, 20)
    }
    
    private func startNewGame() {
        // Sottrai il costo del biglietto
        balance -= ticketPrice
        
        // Reset gioco
        scratchedPoints = []
        isScratched = false
        opacity = 1.0
        currentScratches = 0
        showResult = false
        isPlaying = true
        
        // Seleziona nuovo premio casuale
        prize = prizes.randomElement() ?? 0
    }
    
    private func revealPrize() {
        withAnimation(.easeInOut(duration: 0.8)) {
            isScratched = true
            opacity = 0.0
            
            // Aspetta un po' poi mostra il risultato
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    showResult = true
                    isPlaying = false
                }
                
                // Aggiungi premio al saldo (se c'è)
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
        isPlaying = true
        
        // Seleziona nuovo premio casuale
        prize = prizes.randomElement() ?? 0
    }
}

struct ComingSoonView: View {
    @Binding var isPresented: Bool
    
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
                    isPresented = false
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