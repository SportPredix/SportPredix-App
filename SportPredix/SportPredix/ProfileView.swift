//
//  ProfileView.swift
//  SportPredix
//
//  Created by Francesco on 16/01/26.
//

import SwiftUI

struct ProfileView: View {
    
    @EnvironmentObject var vm: BettingViewModel
    @State private var showNameField = false
    @State private var showResetAlert = false
    @State private var showPreferences = false
    @State private var showAppInfoAlert = false
    @State private var tempUserName: String = ""
    
    // Semplifichiamo l'espressione complessa
    var initials: String {
        guard !vm.userName.isEmpty else { return "?" }
        
        let parts = vm.userName.split(separator: " ")
        
        // Prima lettera del primo nome
        guard let firstPart = parts.first, let firstChar = firstPart.first else {
            return "?"
        }
        
        // Se c'è un cognome, prendi la prima lettera
        if parts.count >= 2, let lastPart = parts.last, let lastChar = lastPart.first {
            return "\(firstChar)\(lastChar)".uppercased()
        }
        
        // Solo un nome
        return String(firstChar).uppercased()
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    
                    // MARK: - HEADER CARD
                    headerCard
                    
                    // MARK: - QUICK SETTINGS (FUNZIONANTI)
                    quickSettings
                    
                    // MARK: - USER STATS
                    userStats
                    
                    // MARK: - ACCOUNT ACTIONS
                    accountActions
                    
                    Spacer()
                        .frame(height: 30)
                }
                .padding(.top, 20)
            }
        }
        .alert("Reset Account", isPresented: $showResetAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Reset", role: .destructive) {
                vm.resetAccount()
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } message: {
            Text("Vuoi davvero resettare il tuo account? Perderai tutte le scommesse piazzate e il saldo tornerà a €1000.")
        }
        .alert("SportPredix Info", isPresented: $showAppInfoAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Versione 1.0\nSviluppato per dimostrazione\n© 2024 SportPredix")
        }
        .sheet(isPresented: $showPreferences) {
            PreferencesView()
        }
        .onAppear {
            tempUserName = vm.userName
        }
    }
    
    // MARK: - COMPONENTI SEPARATI PER SEMPLIFICARE IL TYPE-CHECKING
    
    private var headerCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentCyan.opacity(0.25))
                    .frame(width: 90, height: 90)
                
                Text(initials)
                    .font(.largeTitle.bold())
                    .foregroundColor(.accentCyan)
            }
            .padding(.top, 20)
            
            Text(vm.userName.isEmpty ? "Utente" : vm.userName)
                .font(.title.bold())
                .foregroundColor(.white)
            
            Text("Saldo: €\(vm.balance, specifier: "%.2f")")
                .font(.title3.bold())
                .foregroundColor(.accentCyan)
            
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    showNameField.toggle()
                    tempUserName = vm.userName
                }
            } label: {
                Text(showNameField ? "Chiudi" : "Modifica nome")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(.white)
            }
            
            if showNameField {
                nameFieldView
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
        .padding(.horizontal)
    }
    
    private var nameFieldView: some View {
        VStack(spacing: 12) {
            TextField("Inserisci nome", text: $tempUserName)
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            Button("Salva") {
                vm.userName = tempUserName
                showNameField = false
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.accentCyan)
            .foregroundColor(.black)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var quickSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Impostazioni rapide")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                toggleRow(
                    icon: "bell",
                    title: "Notifiche",
                    isOn: $vm.notificationsEnabled
                )
                
                toggleRow(
                    icon: "lock",
                    title: "Privacy",
                    isOn: $vm.privacyEnabled
                )
                
                Button {
                    showPreferences = true
                } label: {
                    HStack {
                        Image(systemName: "gearshape")
                            .foregroundColor(.accentCyan)
                            .frame(width: 28)
                        
                        Text("Preferenze app")
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }
    
    private var userStats: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistiche utente")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                statRow(title: "Scommesse piazzate", value: "\(vm.totalBetsCount)")
                statRow(title: "Vinte", value: "\(vm.totalWins)")
                statRow(title: "Perse", value: "\(vm.totalLosses)")
                
                if vm.totalBetsCount > 0 {
                    let winRate = Double(vm.totalWins) / Double(vm.totalBetsCount) * 100
                    let formattedWinRate = String(format: "%.1f%%", winRate)
                    statRow(title: "Percentuale vittorie", value: formattedWinRate)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }
    
    private var accountActions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Azioni account")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                actionButton(
                    icon: "arrow.counterclockwise",
                    title: "Reset account",
                    color: .red,
                    action: { showResetAlert = true }
                )
                
                actionButton(
                    icon: "plus.circle",
                    title: "Deposita €100",
                    color: .green,
                    action: depositFunds
                )
                
                actionButton(
                    icon: "info.circle",
                    title: "Info app",
                    color: .accentCyan,
                    action: { showAppInfoAlert = true },
                    showsChevron: true
                )
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }
    
    // MARK: - FUNZIONI PROFILO
    
    private func depositFunds() {
        vm.balance += 100
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // MARK: - FUNZIONI HELPER
    
    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentCyan)
                .frame(width: 28)
            
            Text(title)
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .toggleStyle(SwitchToggleStyle(tint: .accentCyan))
                .labelsHidden()
                .onChange(of: isOn.wrappedValue) { _, newValue in
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
        }
        .padding(.vertical, 6)
    }
    
    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.accentCyan)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
    
    private func actionButton(
        icon: String,
        title: String,
        color: Color,
        action: @escaping () -> Void,
        showsChevron: Bool = false
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 28)
                
                Text(title)
                    .foregroundColor(color)
                
                Spacer()
                
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 10)
        }
    }
}