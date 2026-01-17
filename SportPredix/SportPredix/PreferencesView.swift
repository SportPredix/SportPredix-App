//
//  PreferencesView.swift
//  SportPredix
//
//  Created by Francesco on 16/01/26.
//

import SwiftUI

struct PreferencesView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var vm: BettingViewModel
    
    @State private var soundEnabled = true
    @State private var vibrationEnabled = true
    @State private var darkModeEnabled = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.gray)
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                
                Text("Preferenze App")
                    .font(.title2.bold())
                    .foregroundColor(.accentCyan)
                
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Suoni")
                                    .foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: $soundEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: .accentCyan))
                            }
                            
                            HStack {
                                Text("Vibrazioni")
                                    .foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: $vibrationEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: .accentCyan))
                            }
                            
                            HStack {
                                Text("Modalità Scura")
                                    .foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: $darkModeEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: .accentCyan))
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(14)
                        
                        Text("Queste impostazioni influenzano l'esperienza utente nell'app.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Chiudi")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentCyan)
                        .foregroundColor(.black)
                        .cornerRadius(16)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
    }
}
