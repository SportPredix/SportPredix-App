//
//  ContentView.swift
//  SportPredix
//

import SwiftUI

// MARK: - THEME

extension Color {
    static let accentCyan = Color(red: 68/255, green: 224/255, blue: 203/255)
    static let accentYellow = Color(red: 255/255, green: 214/255, blue: 10/255)
    static let accentPink = Color(red: 255/255, green: 45/255, blue: 85/255)
}

// MARK: - MODELS

enum MatchOutcome: String, Codable {
    case home = "1"
    case draw = "X"
    case away = "2"
    case homeDraw = "1X"
    case homeAway = "12"
    case drawAway = "X2"
    case over25 = "Over 2.5"
    case under25 = "Under 2.5"
}

struct Odds: Codable {
    let home: Double
    let draw: Double
    let away: Double
    let homeDraw: Double
    let homeAway: Double
    let drawAway: Double
    let over25: Double
    let under25: Double
}

struct Match: Identifiable, Codable {
    let id: UUID
    let home: String
    let away: String
    let time: String
    let odds: Odds
    var result: MatchOutcome?
    var goals: Int?
}

struct BetPick: Identifiable, Codable {
    let id: UUID
    let match: Match
    let outcome: MatchOutcome
    let odd: Double
}

struct BetSlip: Identifiable, Codable {
    let id: UUID
    let picks: [BetPick]
    let stake: Double
    let totalOdd: Double
    let potentialWin: Double
    let date: Date
    var isWon: Bool? = nil
    var isEvaluated: Bool = false
    var impliedProbability: Double { 1 / totalOdd }
    var expectedValue: Double { potentialWin * impliedProbability - stake }
}

// MARK: - VIEW MODEL

final class BettingViewModel: ObservableObject {
    @Published var selectedTab = 0
    @Published var selectedDayIndex = 1
    @Published var showSheet = false
    @Published var showSlipDetail: BetSlip?
    @Published var balance: Double {
        didSet { UserDefaults.standard.set(balance, forKey: "balance") }
    }
    @Published var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: "userName") }
    }
    @Published var currentPicks: [BetPick] = []
    @Published var slips: [BetSlip] = []
    @Published var dailyMatches: [String: [Match]] = [:]
    @Published var upcomingGame: String? = nil // Per mostrare "Presto in arrivo!"
    
    private let slipsKey = "savedSlips"
    private let matchesKey = "savedMatches"
    private let teams = ["Napoli","Inter","Milan","Juventus","Roma","Lazio","Liverpool","Chelsea","Arsenal","Man City","Tottenham","Real Madrid","Barcellona","Atletico","Valencia","Bayern","Dortmund","Leipzig","Leverkusen"]
    
    init() {
        let savedBalance = UserDefaults.standard.double(forKey: "balance")
        self.balance = savedBalance == 0 ? 1000 : savedBalance
        self.userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        self.slips = loadSlips()
        self.dailyMatches = loadMatches()
        generateTodayIfNeeded()
    }
    
    func dateForIndex(_ index: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: index - 1, to: Date())!
    }
    
    func keyForDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    
    func formattedDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }
    
    func formattedMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }
    
    func generateMatchesForDate(_ date: Date) -> [Match] {
        var result: [Match] = []
        for _ in 0..<12 {
            let home = teams.randomElement()!
            var away = teams.randomElement()!
            while away == home { away = teams.randomElement()! }
            let hour = Int.random(in: 12...22)
            let minute = ["00","15","30","45"].randomElement()!
            let time = "\(hour):\(minute)"
            let odds = Odds(home: Double.random(in: 1.20...2.50), draw: Double.random(in: 2.80...4.50), away: Double.random(in: 2.50...7.00), homeDraw: Double.random(in: 1.10...1.50), homeAway: Double.random(in: 1.15...1.30), drawAway: Double.random(in: 1.20...1.60), over25: Double.random(in: 1.70...2.20), under25: Double.random(in: 1.70...2.20))
            let goals = Int.random(in: 0...6)
            let possibleResults: [MatchOutcome] = [.home, .draw, .away]
            let randomResult = possibleResults.randomElement()!
            result.append(Match(id: UUID(), home: home, away: away, time: time, odds: odds, result: randomResult, goals: goals))
        }
        return result
    }
    
    func generateTodayIfNeeded() {
        let todayKey = keyForDate(Date())
        if dailyMatches[todayKey] == nil {
            dailyMatches[todayKey] = generateMatchesForDate(Date())
            saveMatches()
        }
    }
    
    func matchesForSelectedDay() -> [String: [Match]] {
        let date = dateForIndex(selectedDayIndex)
        let key = keyForDate(date)
        if let existing = dailyMatches[key] {
            return Dictionary(grouping: existing) { $0.time }
        }
        let newMatches = generateMatchesForDate(date)
        dailyMatches[key] = newMatches
        saveMatches()
        return Dictionary(grouping: newMatches) { $0.time }
    }
    
    func saveMatches() {
        if let data = try? JSONEncoder().encode(dailyMatches) {
            UserDefaults.standard.set(data, forKey: matchesKey)
        }
    }
    
    func loadMatches() -> [String: [Match]] {
        guard let data = UserDefaults.standard.data(forKey: matchesKey),
              let decoded = try? JSONDecoder().decode([String: [Match]].self, from: data) else { return [:] }
        return decoded
    }
    
    var totalOdd: Double { currentPicks.map { $0.odd }.reduce(1, *) }
    
    func addPick(match: Match, outcome: MatchOutcome, odd: Double) {
        if let index = currentPicks.firstIndex(where: { $0.match.id == match.id && $0.outcome == outcome }) {
            currentPicks.remove(at: index)
        } else {
            currentPicks.append(BetPick(id: UUID(), match: match, outcome: outcome, odd: odd))
        }
    }
    
    func removePick(_ pick: BetPick) {
        currentPicks.removeAll { $0.id == pick.id }
    }
    
    func confirmSlip(stake: Double) {
        let slip = BetSlip(id: UUID(), picks: currentPicks, stake: stake, totalOdd: totalOdd, potentialWin: stake * totalOdd, date: Date(), isWon: nil, isEvaluated: false)
        balance -= stake
        currentPicks.removeAll()
        slips.insert(slip, at: 0)
        saveSlips()
    }
    
    private func saveSlips() {
        if let data = try? JSONEncoder().encode(slips) {
            UserDefaults.standard.set(data, forKey: slipsKey)
        }
    }
    
    private func loadSlips() -> [BetSlip] {
        guard let data = UserDefaults.standard.data(forKey: slipsKey),
              let decoded = try? JSONDecoder().decode([BetSlip].self, from: data) else { return [] }
        return decoded
    }
    
    func evaluateSlip(_ slip: BetSlip) -> BetSlip {
        var updatedSlip = slip
        if slip.isEvaluated { return slip }
        let allCorrect = slip.picks.allSatisfy { pick in
            switch pick.outcome {
            case .home, .draw, .away: return pick.match.result == pick.outcome
            case .homeDraw: return pick.match.result == .home || pick.match.result == .draw
            case .homeAway: return pick.match.result == .home || pick.match.result == .away
            case .drawAway: return pick.match.result == .draw || pick.match.result == .away
            case .over25: return (pick.match.goals ?? 0) > 2
            case .under25: return (pick.match.goals ?? 0) <= 2
            }
        }
        updatedSlip.isWon = allCorrect
        updatedSlip.isEvaluated = true
        if allCorrect { balance += slip.potentialWin }
        return updatedSlip
    }
    
    func evaluateAllSlips() {
        slips = slips.map { evaluateSlip($0) }
        saveSlips()
    }
    
    var totalBetsCount: Int { slips.count }
    var totalWins: Int { slips.filter { $0.isWon == true }.count }
    var totalLosses: Int { slips.filter { $0.isWon == false }.count }
}

// MARK: - MAIN VIEW

struct ContentView: View {
    @StateObject private var vm = BettingViewModel()
    @Namespace private var animationNamespace
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    if vm.selectedTab == 0 {
                        calendarBar
                        matchList
                    } else if vm.selectedTab == 1 {
                        placedBets.onAppear { vm.evaluateAllSlips() }
                    } else if vm.selectedTab == 2 {
                        gamesView
                    } else {
                        ProfileView(userName: $vm.userName, balance: $vm.balance).environmentObject(vm)
                    }
                    bottomBar
                }
                if !vm.currentPicks.isEmpty {
                    floatingButton.transition(.scale.combined(with: .opacity))
                }
            }
            .sheet(isPresented: $vm.showSheet) {
                BetSheet(picks: $vm.currentPicks, balance: $vm.balance, totalOdd: vm.totalOdd) { stake in vm.confirmSlip(stake: stake) }
            }
            .sheet(item: $vm.showSlipDetail) { SlipDetailView(slip: $0) }
            .sheet(item: $vm.upcomingGame) { gameName in
                UpcomingGameView(gameName: gameName)
            }
        }
    }
    
    private var header: some View {
        HStack {
            Text(vm.selectedTab == 0 ? "Calendario" : vm.selectedTab == 1 ? "Piazzate" : vm.selectedTab == 2 ? "Giochi" : "Profilo")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Spacer()
            Text("€\(vm.balance, specifier: "%.2f")")
                .foregroundColor(.accentCyan)
                .bold()
        }
        .padding()
    }
    
    private var gamesView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Crazy Time Button
                Button {
                    vm.upcomingGame = "Crazy Time"
                } label: {
                    gameCard(
                        title: "🎡 Crazy Time",
                        description: "Gira la ruota e vinci fino a €200!",
                        gradientColors: [.yellow, .orange, .red, .pink],
                        icon1: "trophy.fill",
                        icon2: "sparkles",
                        betAmount: "€10"
                    )
                }
                
                // Gratta e Vinci Button
                Button {
                    vm.upcomingGame = "Gratta e Vinci"
                } label: {
                    gameCard(
                        title: "✨ Gratta e Vinci",
                        description: "Scopri i simboli fortunati!",
                        gradientColors: [.green, .mint, .teal],
                        icon1: "sparkles",
                        icon2: "trophy.fill",
                        betAmount: "€5"
                    )
                }
                
                // Blackjack Button
                Button {
                    vm.upcomingGame = "Blackjack"
                } label: {
                    gameCard(
                        title: "♠️ Blackjack",
                        description: "Sfida il banco e vinci il 21!",
                        gradientColors: [.black, .gray, .black],
                        icon1: "suit.spade.fill",
                        icon2: "suit.heart.fill",
                        betAmount: "€20"
                    )
                }
                
                // Slot Machine Button
                Button {
                    vm.upcomingGame = "Slot Machine"
                } label: {
                    gameCard(
                        title: "🎰 Slot Machine",
                        description: "Allinea i simboli per vincere!",
                        gradientColors: [.purple, .blue, .purple],
                        icon1: "dollarsign.circle.fill",
                        icon2: "crown.fill",
                        betAmount: "€5"
                    )
                }
                
                // Poker Button
                Button {
                    vm.upcomingGame = "Poker"
                } label: {
                    gameCard(
                        title: "🃏 Poker",
                        description: "Sfida altri giocatori in tempo reale!",
                        gradientColors: [.blue, .green, .blue],
                        icon1: "person.2.fill",
                        icon2: "flag.fill",
                        betAmount: "€50"
                    )
                }
                
                // Roulette Button
                Button {
                    vm.upcomingGame = "Roulette"
                } label: {
                    gameCard(
                        title: "🎲 Roulette",
                        description: "Scegli il numero fortunato!",
                        gradientColors: [.red, .black, .red],
                        icon1: "circle.grid.cross.fill",
                        icon2: "number.circle.fill",
                        betAmount: "€10"
                    )
                }
            }
            .padding()
        }
    }
    
    private func gameCard(
        title: String,
        description: String,
        gradientColors: [Color],
        icon1: String,
        icon2: String,
        betAmount: String
    ) -> some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(Color.black.opacity(0.2))
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: icon1)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: icon2)
                        .font(.system(size: 30))
                        .foregroundColor(.yellow)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                    
                    HStack {
                        Text("Puntata: \(betAmount)")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(20)
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
            }
            .padding(24)
        }
        .frame(height: 220)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.accentCyan.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var calendarBar: some View {
        HStack(spacing: 16) {
            ForEach(0..<3) { index in
                let date = vm.dateForIndex(index)
                VStack(spacing: 4) {
                    Text(vm.formattedDay(date)).font(.title2.bold())
                    Text(vm.formattedMonth(date)).font(.caption)
                }
                .foregroundColor(.white)
                .frame(width: 90, height: 70)
                .background(RoundedRectangle(cornerRadius: 14).stroke(vm.selectedDayIndex == index ? Color.accentCyan : Color.white.opacity(0.2), lineWidth: 3))
                .onTapGesture { vm.selectedDayIndex = index }
                .animation(.easeInOut, value: vm.selectedDayIndex)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private var matchList: some View {
        let groupedMatches = vm.matchesForSelectedDay()
        let isYesterday = vm.selectedDayIndex == 0
        return ScrollView {
            VStack(spacing: 16) {
                ForEach(groupedMatches.keys.sorted(), id: \.self) { time in
                    VStack(spacing: 10) {
                        HStack {
                            Spacer()
                            Text(time).font(.headline).foregroundColor(.accentCyan)
                        }
                        ForEach(groupedMatches[time]!) { match in
                            matchCard(match, disabled: isYesterday)
                        }
                    }
                }
            }
            .padding()
        }
        .id(vm.selectedDayIndex)
        .transition(.opacity)
    }
    
    private func matchCard(_ match: Match, disabled: Bool) -> some View {
        NavigationLink(destination: MatchDetailView(match: match, vm: vm)) {
            VStack(spacing: 10) {
                HStack {
                    Text(match.home).font(.headline)
                    Spacer()
                    Text(match.away).font(.headline)
                }
                .foregroundColor(disabled ? .gray : .white)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(disabled ? Color.gray.opacity(0.1) : Color.white.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 16).stroke(disabled ? Color.gray.opacity(0.2) : Color.white.opacity(0.08), lineWidth: 1)))
        }
        .disabled(disabled)
    }
    
    private var placedBets: some View {
        ScrollView {
            VStack(spacing: 12) {
                if vm.slips.isEmpty {
                    Text("Nessuna scommessa piazzata")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(vm.slips) { slip in
                        Button { vm.showSlipDetail = slip } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quota \(slip.totalOdd, specifier: "%.2f")")
                                    .foregroundColor(.accentCyan)
                                Text("Puntata €\(slip.stake, specifier: "%.2f")")
                                    .foregroundColor(.white)
                                Text("Vincita potenziale €\(slip.potentialWin, specifier: "%.2f")")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                if let won = slip.isWon {
                                    Text(won ? "ESITO: VINTA" : "ESITO: PERSA")
                                        .foregroundColor(won ? .green : .red)
                                        .font(.headline)
                                }
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
    
    private var floatingButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ZStack(alignment: .topTrailing) {
                    Button { vm.showSheet = true } label: {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundColor(.black)
                            .padding(16)
                            .background(Color.accentCyan)
                            .clipShape(Circle())
                            .shadow(radius: 10)
                    }
                    if !vm.currentPicks.isEmpty {
                        Text("\(vm.currentPicks.count)")
                            .font(.caption2.bold())
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .foregroundColor(.white)
                            .offset(x: 8, y: -8)
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 90)
            }
        }
    }
    
    private var bottomBar: some View {
        ZStack {
            VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                .frame(height: 85)
                .cornerRadius(30)
                .padding(.horizontal, 12)
                .shadow(color: .black.opacity(0.3), radius: 15, y: -5)
            HStack(spacing: 0) {
                ForEach(0..<4) { index in
                    Spacer()
                    bottomItem(index: index)
                    Spacer()
                }
            }
            .padding(.horizontal, 8)
            VStack {
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 120, height: 4)
                    .padding(.bottom, 8)
            }
        }
        .frame(height: 85)
        .padding(.bottom, 4)
    }
    
    private func bottomItem(index: Int) -> some View {
        let isSelected = vm.selectedTab == index
        let icons = ["calendar", "list.bullet", "gamepad.fill", "person.crop.circle"]
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                vm.selectedTab = index
                vm.upcomingGame = nil
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.accentCyan.opacity(0.25))
                            .frame(width: 52, height: 52)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Image(systemName: icons[index])
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(isSelected ? .accentCyan : .white.opacity(0.6))
                        .scaleEffect(isSelected ? 1.2 : 1.0)
                }
                .frame(height: 52)
                if isSelected {
                    Capsule()
                        .fill(Color.accentCyan)
                        .frame(width: 28, height: 4)
                        .matchedGeometryEffect(id: "tabIndicator", in: animationNamespace)
                } else {
                    Capsule()
                        .fill(Color.clear)
                        .frame(width: 28, height: 4)
                }
            }
        }
    }
}

// MARK: - UPCOMING GAME VIEW (Sheet)

struct UpcomingGameView: View {
    let gameName: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Draggable indicator
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                Spacer()
                
                // Animated icon
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 100))
                    .foregroundColor(.accentCyan)
                    .symbolEffect(.pulse, options: .repeating)
                
                // Title
                Text("Presto in arrivo!")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Game name
                Text(gameName)
                    .font(.title)
                    .foregroundColor(.accentYellow)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(15)
                
                // Description
                Text("Stiamo lavorando per portarti\nun'esperienza di gioco eccezionale!")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                // Coming soon text with animation
                VStack(spacing: 15) {
                    Text("🎮 Nuove funzionalità")
                        .font(.headline)
                        .foregroundColor(.accentCyan)
                    
                    HStack(spacing: 20) {
                        FeatureBadge(icon: "trophy.fill", text: "Vincite")
                        FeatureBadge(icon: "person.2.fill", text: "Multiplayer")
                        FeatureBadge(icon: "sparkles", text: "Bonus")
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(20)
                .padding(.horizontal, 30)
                
                Spacer()
                Spacer()
                
                // Back button
                Button(action: {
                    dismiss()
                }) {
                    Text("Torna ai giochi")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentCyan)
                        .cornerRadius(15)
                        .padding(.horizontal, 40)
                }
                
                // Swipe hint
                Text("👆 Puoi anche scorrere verso il basso per chiudere")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            }
            .padding()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
    }
}

struct FeatureBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentYellow)
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct BetSheet: View {
    @Binding var picks: [BetPick]
    @Binding var balance: Double
    let totalOdd: Double
    let onConfirm: (Double) -> Void
    @State private var stakeText: String = "1"
    @Environment(\.dismiss) var dismiss
    
    var stake: Double {
        Double(stakeText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    var impliedProbability: Double { 1 / totalOdd }
    var expectedValue: Double { (stake * totalOdd * impliedProbability) - stake }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Capsule().fill(Color.gray).frame(width: 40, height: 5).padding(.top, 8)
                Text("Schedina selezionata").font(.title2.bold()).foregroundColor(.accentCyan)
                if picks.isEmpty {
                    Text("Devi selezionare un pronostico").foregroundColor(.accentCyan).font(.title2).padding()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(picks) { pick in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(pick.match.home) - \(pick.match.away)").font(.headline).foregroundColor(.white)
                                        Text("Esito: \(pick.outcome.rawValue) | Quota: \(pick.odd, specifier: "%.2f")").font(.subheadline).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Button {
                                        picks.removeAll { $0.id == pick.id }
                                    } label: {
                                        Image(systemName: "trash").foregroundColor(.red)
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
                        Text("Expected Value: €\(expectedValue, specifier: "%.2f")").foregroundColor(expectedValue >= 0 ? .green : .red)
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentCyan)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Importo:").foregroundColor(.white)
                        TextField("Inserisci importo", text: $stakeText).keyboardType(.decimalPad).padding().background(Color.white.opacity(0.08)).cornerRadius(12).foregroundColor(.white)
                        Text("€\(stake, specifier: "%.2f")").foregroundColor(.accentCyan)
                    }
                    Button(action: {
                        guard stake > 0, stake <= balance else { return }
                        onConfirm(stake)
                        dismiss()
                    }) {
                        Text("Conferma schedina").bold().frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.black).cornerRadius(16)
                    }
                    .disabled(stake <= 0 || stake > balance)
                    .opacity(stake <= 0 || stake > balance ? 0.5 : 1)
                }
                Spacer()
            }
            .padding()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct SlipDetailView: View {
    let slip: BetSlip
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Capsule().fill(Color.gray).frame(width: 40, height: 5).padding(.top, 8)
                Text("Dettaglio scommessa").font(.title2.bold()).foregroundColor(.accentCyan)
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(slip.picks) { pick in
                            VStack(spacing: 10) {
                                Text("\(pick.match.home) - \(pick.match.away)").font(.headline).foregroundColor(.white)
                                Text("Orario: \(pick.match.time)").font(.subheadline).foregroundColor(.gray)
                                Text("Esito giocato: \(pick.outcome.rawValue)").font(.subheadline).foregroundColor(.accentCyan)
                                if let result = pick.match.result {
                                    Text("Risultato reale: \(result.rawValue)").foregroundColor(.white)
                                }
                                if let goals = pick.match.goals {
                                    Text("Gol totali: \(goals)").foregroundColor(.gray)
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
                                    Text(won ? "VINTA" : "PERSA").foregroundColor(won ? .green : .red).bold()
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
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Chiudi")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentCyan)
                        .cornerRadius(15)
                        .padding(.horizontal)
                }
                .padding(.top, 10)
            }
            .padding(.top)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct MatchDetailView: View {
    let match: Match
    @ObservedObject var vm: BettingViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("\(match.home) vs \(match.away)").font(.largeTitle.bold()).foregroundColor(.white)
                Text("Orario: \(match.time)").foregroundColor(.accentCyan)
                ScrollView {
                    VStack(spacing: 16) {
                        oddsSection(title: "1X2", odds: [("1", .home, match.odds.home), ("X", .draw, match.odds.draw), ("2", .away, match.odds.away)])
                        oddsSection(title: "Doppie Chance", odds: [("1X", .homeDraw, match.odds.homeDraw), ("12", .homeAway, match.odds.homeAway), ("X2", .drawAway, match.odds.drawAway)])
                        oddsSection(title: "Over/Under 2.5", odds: [("Over 2.5", .over25, match.odds.over25), ("Under 2.5", .under25, match.odds.under25)])
                    }
                    .padding(.horizontal)
                }
                Spacer()
            }
            .padding()
        }
        .overlay(
            Group {
                if !vm.currentPicks.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ZStack(alignment: .topTrailing) {
                                Button { vm.showSheet = true } label: {
                                    Image(systemName: "list.bullet.rectangle").foregroundColor(.black).padding(16).background(Color.accentCyan).clipShape(Circle()).shadow(radius: 10)
                                }
                                if !vm.currentPicks.isEmpty {
                                    Text("\(vm.currentPicks.count)").font(.caption2.bold()).padding(4).background(Color.red).clipShape(Circle()).foregroundColor(.white).offset(x: 8, y: -8)
                                }
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 90)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        )
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left").foregroundColor(.accentCyan).font(.system(size: 20, weight: .semibold))
                }
            }
        }
        .navigationTitle("Dettagli Partita")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func oddsSection(title: String, odds: [(String, MatchOutcome, Double)]) -> some View {
        VStack(spacing: 10) {
            Text(title).font(.headline).foregroundColor(.white)
            HStack(spacing: 10) {
                ForEach(odds, id: \.0) { label, outcome, odd in
                    oddButton(label, outcome, odd)
                }
            }
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
            VStack {
                Text(label).bold()
                Text(String(format: "%.2f", odd)).font(.caption)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Color.accentCyan : Color.white.opacity(0.2), lineWidth: 3))
            .cornerRadius(14)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct ProfileView: View {
    @EnvironmentObject var vm: BettingViewModel
    @Binding var userName: String
    @Binding var balance: Double
    @State private var showNameField = false
    
    var initials: String {
        let parts = userName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts.first!.first!)\(parts.last!.first!)".uppercased()
        } else if let first = userName.first {
            return String(first).uppercased()
        }
        return "?"
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle().fill(Color.accentCyan.opacity(0.25)).frame(width: 90, height: 90)
                            Text(initials).font(.largeTitle.bold()).foregroundColor(.accentCyan)
                        }
                        .padding(.top, 20)
                        Text(userName.isEmpty ? "Utente" : userName).font(.title.bold()).foregroundColor(.white)
                        Text("Saldo: €\(balance, specifier: "%.2f")").font(.title3.bold()).foregroundColor(.accentCyan)
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                showNameField.toggle()
                            }
                        } label: {
                            Text("Modifica nome").font(.subheadline.bold()).padding(.horizontal, 16).padding(.vertical, 8).background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                        }
                        if showNameField {
                            TextField("Inserisci nome", text: $userName).padding().background(Color.white.opacity(0.08)).cornerRadius(12).foregroundColor(.white).padding(.horizontal).transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Impostazioni rapide").font(.headline).foregroundColor(.white)
                        VStack(spacing: 12) {
                            settingRow(icon: "bell", title: "Notifiche")
                            settingRow(icon: "lock", title: "Privacy")
                            settingRow(icon: "gearshape", title: "Preferenze app")
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Statistiche utente").font(.headline).foregroundColor(.white)
                        VStack(spacing: 12) {
                            statRow(title: "Scommesse piazzate", value: "\(vm.totalBetsCount)")
                            statRow(title: "Vinte", value: "\(vm.totalWins)")
                            statRow(title: "Perse", value: "\(vm.totalLosses)")
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    Spacer()
                }
                .padding(.top, 20)
            }
        }
    }
    
    private func settingRow(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(.accentCyan).frame(width: 28)
            Text(title).foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray)
        }
        .padding(.vertical, 6)
    }
    
    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundColor(.white)
            Spacer()
            Text(value).foregroundColor(.accentCyan)
        }
        .padding(.vertical, 4)
    }
}