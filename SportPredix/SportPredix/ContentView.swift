//
//  ContentView.swift
//  SportPredix
//

import SwiftUI

// MARK: - THEME

extension Color {
    static let accentCyan = Color(red: 68/255, green: 224/255, blue: 203/255)
}

// MARK: - VIEW MODEL CON BETSTACK INTEGRATION

final class BettingViewModel: ObservableObject {
    
    @Published var selectedTab = 0
    @Published var selectedDayIndex = 1
    @Published var selectedSport: String {
        didSet {
            UserDefaults.standard.set(selectedSport, forKey: "selectedSport")
        }
    }
    
    @Published var showSportPicker = false
    @Published var showSheet = false
    @Published var showSlipDetail: BetSlip?
    
    @Published var balance: Double {
        didSet { UserDefaults.standard.set(balance, forKey: "balance") }
    }
    
    @Published var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: "userName") }
    }
    
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    
    @Published var privacyEnabled: Bool {
        didSet { UserDefaults.standard.set(privacyEnabled, forKey: "privacyEnabled") }
    }
    
    @Published var currentPicks: [BetPick] = []
    @Published var slips: [BetSlip] = []
    
    @Published var dailyMatches: [String: [Match]] = [:]
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    
    private let slipsKey = "savedSlips"
    private let matchesKey = "savedMatches"
    private let lastFetchKey = "lastBetstackFetch"
    
    init() {
        let savedBalance = UserDefaults.standard.double(forKey: "balance")
        self.balance = savedBalance == 0 ? 1000 : savedBalance
        
        self.userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.privacyEnabled = UserDefaults.standard.object(forKey: "privacyEnabled") as? Bool ?? false
        
        // Carica sport selezionato o imposta "Calcio" come default
        self.selectedSport = UserDefaults.standard.string(forKey: "selectedSport") ?? "Calcio"
        
        self.slips = loadSlips()
        self.dailyMatches = loadMatches()
        
        // Carica ora ultimo fetch
        if let savedDate = UserDefaults.standard.object(forKey: lastFetchKey) as? Date {
            self.lastUpdateTime = savedDate
        }
        
        // Verifica se dobbiamo fetchare nuove partite
        checkAndFetchMatches()
    }
    
    // MARK: - BETSTACK API INTEGRATION
    
    func checkAndFetchMatches() {
        // Se non è calcio, usa partite simulate per tennis
        guard selectedSport == "Calcio" else {
            generateTodayIfNeeded()
            return
        }
        
        let todayKey = keyForDate(Date())
        
        // Se non abbiamo partite per oggi O l'ultimo fetch è stato più di 1 ora fa
        let shouldFetch = dailyMatches[todayKey] == nil ||
                         lastUpdateTime == nil ||
                         Date().timeIntervalSince(lastUpdateTime!) > 3600
        
        if shouldFetch {
            fetchMatchesFromBetstack(for: selectedSport)
        }
    }
    
    func fetchMatchesFromBetstack(for sport: String) {
        guard !isLoading, sport == "Calcio" else { return }
        
        isLoading = true
        
        OddsService.shared.fetchSerieAOdds { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let matches):
                    print("✅ Betstack matches fetched successfully: \(matches.count) matches")
                    
                    let todayKey = self?.keyForDate(Date()) ?? ""
                    self?.dailyMatches[todayKey] = matches
                    self?.lastUpdateTime = Date()
                    
                    // Salva in UserDefaults
                    self?.saveMatches()
                    UserDefaults.standard.set(self?.lastUpdateTime, forKey: self?.lastFetchKey ?? "lastBetstackFetch")
                    
                    // Aggiorna UI
                    self?.objectWillChange.send()
                    
                case .failure(let error):
                    print("❌ Betstack fetch failed: \(error.localizedDescription)")
                    // Usa partite simulate come fallback
                    self?.generateTodayIfNeeded()
                }
            }
        }
    }
    
    // MARK: - DATE HELPERS
    
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
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "MMM"
        return f.string(from: date).capitalized
    }
    
    // MARK: - MATCH GENERATION FUNCTIONS (fallback)
    
    func generateTodayIfNeeded() {
        let todayKey = keyForDate(Date())
        
        if dailyMatches[todayKey] == nil {
            print("🔄 Generating simulated matches for today")
            
            if selectedSport == "Tennis" {
                dailyMatches[todayKey] = generateTennisMatches()
            } else {
                dailyMatches[todayKey] = generateFootballMatches()
            }
            
            saveMatches()
        }
    }
    
    func generateTennisMatchesIfNeeded() {
        let todayKey = keyForDate(Date())
        
        if dailyMatches[todayKey] == nil {
            print("🔄 Generating tennis matches")
            dailyMatches[todayKey] = generateTennisMatches()
            saveMatches()
        }
    }
    
    func generateFootballMatches() -> [Match] {
        let competitions = [
            ("Serie A", ["Milan", "Inter", "Juventus", "Napoli", "Roma", "Lazio", "Atalanta", "Fiorentina"]),
            ("Premier League", ["Arsenal", "Chelsea", "Liverpool", "Man City", "Man United", "Tottenham"]),
            ("La Liga", ["Barcelona", "Real Madrid", "Atletico", "Sevilla", "Valencia", "Villarreal"]),
            ("Bundesliga", ["Bayern", "Dortmund", "Leipzig", "Leverkusen", "Frankfurt", "Wolfsburg"]),
            ("Ligue 1", ["PSG", "Marseille", "Lyon", "Monaco", "Lille", "Nice"])
        ]
        
        var matches: [Match] = []
        
        for (competition, teams) in competitions {
            for _ in 0..<2 {
                let home = teams.randomElement()!
                var away = teams.randomElement()!
                while away == home { away = teams.randomElement()! }
                
                let hour = Int.random(in: 15...21)
                let minute = ["00", "15", "30", "45"].randomElement()!
                let time = "\(hour):\(minute)"
                
                let (homeOdd, drawOdd, awayOdd) = generateRealisticOdds(home: home, away: away)
                let odds = createRealisticOdds(home: homeOdd, draw: drawOdd, away: awayOdd)
                
                let (result, goals) = generateRealisticResult(homeOdd: homeOdd, drawOdd: drawOdd, awayOdd: awayOdd)
                
                let match = Match(
                    id: UUID(),
                    home: home,
                    away: away,
                    time: time,
                    odds: odds,
                    result: result,
                    goals: goals,
                    competition: competition,
                    status: "FINISHED",
                    actualResult: result == .home ? "2-1" : result == .away ? "0-2" : "1-1"
                )
                
                matches.append(match)
            }
        }
        
        return matches.shuffled()
    }
    
    func generateTennisMatches() -> [Match] {
        let tournaments = [
            ("ATP Australian Open", ["Djokovic", "Alcaraz", "Sinner", "Medvedev", "Zverev", "Rublev"]),
            ("ATP French Open", ["Nadal", "Djokovic", "Alcaraz", "Tsitsipas", "Ruud", "Rune"]),
            ("Wimbledon", ["Djokovic", "Alcaraz", "Murray", "Berrettini", "Kyrgios", "Federer"]),
            ("US Open", ["Djokovic", "Alcaraz", "Medvedev", "Sinner", "Fritz", "Tiafoe"]),
            ("ATP Masters 1000", ["Djokovic", "Alcaraz", "Sinner", "Medvedev", "Zverev", "Tsitsipas"])
        ]
        
        var matches: [Match] = []
        
        for (tournament, players) in tournaments {
            for _ in 0..<3 {
                let player1 = players.randomElement()!
                var player2 = players.randomElement()!
                while player2 == player1 { player2 = players.randomElement()! }
                
                let hour = Int.random(in: 10...22)
                let minute = ["00", "15", "30", "45"].randomElement()!
                let time = "\(hour):\(minute)"
                
                // Per il tennis, usiamo solo home/away (senza pareggio)
                let (homeOdd, _, awayOdd) = generateRealisticTennisOdds(player1: player1, player2: player2)
                let odds = createTennisOdds(home: homeOdd, away: awayOdd)
                
                // Per il tennis, generiamo un risultato realistico
                let (result, sets) = generateTennisResult(homeOdd: homeOdd, awayOdd: awayOdd)
                
                let match = Match(
                    id: UUID(),
                    home: player1,
                    away: player2,
                    time: time,
                    odds: odds,
                    result: result,
                    goals: sets, // Usiamo goals per indicare i set giocati
                    competition: tournament,
                    status: "FINISHED",
                    actualResult: result == .home ? "3-1" : result == .away ? "2-3" : "N/A"
                )
                
                matches.append(match)
            }
        }
        
        return matches.shuffled()
    }
    
    private func generateRealisticTennisOdds(player1: String, player2: String) -> (Double, Double, Double) {
        let diff = Double(player1.hash % 100 - player2.hash % 100) / 100.0
        
        if diff > 0.3 {
            return (1.30, 0.0, 3.50) // Forte favorito
        } else if diff > 0.1 {
            return (1.60, 0.0, 2.40)
        } else if diff > -0.1 {
            return (1.90, 0.0, 1.90) // Partita equilibrata
        } else if diff > -0.3 {
            return (2.40, 0.0, 1.60)
        } else {
            return (3.50, 0.0, 1.30) // Forte favorito
        }
    }
    
    private func createTennisOdds(home: Double, away: Double) -> Odds {
        return Odds(
            home: home,
            draw: 1.0, // Non usato nel tennis
            away: away,
            homeDraw: 1.0 / ((1.0/home) + (1.0/1.0)),
            homeAway: 1.0 / ((1.0/home) + (1.0/away)),
            drawAway: 1.0 / ((1.0/1.0) + (1.0/away)),
            over05: 1.12,
            under05: 6.50,
            over15: 1.45,
            under15: 2.65,
            over25: 1.95,
            under25: 1.85,
            over35: 2.80,
            under35: 1.40,
            over45: 4.50,
            under45: 1.18
        )
    }
    
    private func generateTennisResult(homeOdd: Double, awayOdd: Double) -> (MatchOutcome?, Int?) {
        let homeProb = 1 / homeOdd
        let awayProb = 1 / awayOdd
        let totalProb = homeProb + awayProb
        
        let normHomeProb = homeProb / totalProb
        
        let random = Double.random(in: 0...1)
        
        if random < normHomeProb {
            let sets = Int.random(in: 3...5) // 3-0, 3-1, 3-2
            return (.home, sets)
        } else {
            let sets = Int.random(in: 3...5) // 3-0, 3-1, 3-2
            return (.away, sets)
        }
    }
    
    private func createRealisticOdds(home: Double, draw: Double, away: Double) -> Odds {
        let homeDraw = 1.0 / ((1.0/home) + (1.0/draw))
        let homeAway = 1.0 / ((1.0/home) + (1.0/away))
        let drawAway = 1.0 / ((1.0/draw) + (1.0/away))
        
        return Odds(
            home: home,
            draw: draw,
            away: away,
            homeDraw: homeDraw,
            homeAway: homeAway,
            drawAway: drawAway,
            over05: 1.12,
            under05: 6.50,
            over15: 1.45,
            under15: 2.65,
            over25: 1.95,
            under25: 1.85,
            over35: 2.80,
            under35: 1.40,
            over45: 4.50,
            under45: 1.18
        )
    }
    
    private func generateRealisticOdds(home: String, away: String) -> (Double, Double, Double) {
        let diff = Double(home.hash % 100 - away.hash % 100) / 100.0
        
        if diff > 0.3 {
            return (1.45, 4.50, 7.00)
        } else if diff > 0.1 {
            return (1.85, 3.60, 4.20)
        } else if diff > -0.1 {
            return (2.40, 3.30, 2.90)
        } else if diff > -0.3 {
            return (3.10, 3.40, 2.25)
        } else {
            return (5.50, 4.00, 1.55)
        }
    }
    
    private func generateRealisticResult(homeOdd: Double, drawOdd: Double, awayOdd: Double) -> (MatchOutcome?, Int?) {
        let homeProb = 1 / homeOdd
        let drawProb = 1 / drawOdd
        let awayProb = 1 / awayOdd
        let totalProb = homeProb + drawProb + awayProb
        
        let normHomeProb = homeProb / totalProb
        let normDrawProb = drawProb / totalProb
        
        let random = Double.random(in: 0...1)
        
        if random < normHomeProb {
            let goals = Int.random(in: 1...4)
            let awayGoals = Int.random(in: 0...goals-1)
            return (.home, goals + awayGoals)
        } else if random < normHomeProb + normDrawProb {
            let goals = Int.random(in: 0...3)
            return (.draw, goals * 2)
        } else {
            let goals = Int.random(in: 1...4)
            let homeGoals = Int.random(in: 0...goals-1)
            return (.away, goals + homeGoals)
        }
    }
    
    func matchesForSelectedDay() -> [String: [Match]] {
        let date = dateForIndex(selectedDayIndex)
        let key = keyForDate(date)
        
        if let existing = dailyMatches[key] {
            let grouped = Dictionary(grouping: existing) { $0.time }
            return grouped
        }
        
        // Se è oggi, genera partite
        if Calendar.current.isDateInToday(date) {
            if selectedSport == "Calcio" {
                fetchMatchesFromBetstack(for: selectedSport)
            } else {
                generateTennisMatchesIfNeeded()
            }
        }
        
        let newMatches = selectedSport == "Calcio" ? generateFootballMatches() : generateTennisMatches()
        dailyMatches[key] = newMatches
        saveMatches()
        let grouped = Dictionary(grouping: newMatches) { $0.time }
        return grouped
    }
    
    // MARK: - SAVE / LOAD
    
    func saveMatches() {
        if let data = try? JSONEncoder().encode(dailyMatches) {
            UserDefaults.standard.set(data, forKey: matchesKey)
        }
    }
    
    func loadMatches() -> [String: [Match]] {
        guard let data = UserDefaults.standard.data(forKey: matchesKey),
              let decoded = try? JSONDecoder().decode([String: [Match]].self, from: data) else {
            return [:]
        }
        return decoded
    }
    
    // MARK: - BETTING
    
    var totalOdd: Double { currentPicks.map { $0.odd }.reduce(1, *) }
    
    func addPick(match: Match, outcome: MatchOutcome, odd: Double) {
        let selectedOutcomeSection = getSectionForOutcome(outcome)
        
        currentPicks.removeAll { pick in
            pick.match.id == match.id && getSectionForOutcome(pick.outcome) == selectedOutcomeSection
        }
        
        currentPicks.append(BetPick(id: UUID(), match: match, outcome: outcome, odd: odd))
    }
    
    private func getSectionForOutcome(_ outcome: MatchOutcome) -> String {
        switch outcome {
        case .home, .draw, .away:
            return "1X2"
        case .homeDraw, .homeAway, .drawAway:
            return "DoppiaChance"
        case .over05, .under05, .over15, .under15, .over25, .under25, .over35, .under35, .over45, .under45:
            return "OverUnder"
        }
    }
    
    func removePick(_ pick: BetPick) {
        currentPicks.removeAll { $0.id == pick.id }
    }
    
    func confirmSlip(stake: Double) {
        guard stake > 0, stake <= balance else { return }
        
        let slip = BetSlip(
            id: UUID(),
            picks: currentPicks,
            stake: stake,
            totalOdd: totalOdd,
            potentialWin: stake * totalOdd,
            date: Date(),
            isWon: nil,
            isEvaluated: false
        )
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
    
    // MARK: - VALUTAZIONE SCHEDINE
    
    func evaluateSlip(_ slip: BetSlip) -> BetSlip {
        var updatedSlip = slip
        
        if slip.isEvaluated { return slip }
        
        let allCorrect = slip.picks.allSatisfy { pick in
            switch pick.outcome {
            case .home, .draw, .away:
                return pick.match.result == pick.outcome
            case .homeDraw:
                return pick.match.result == .home || pick.match.result == .draw
            case .homeAway:
                return pick.match.result == .home || pick.match.result == .away
            case .drawAway:
                return pick.match.result == .draw || pick.match.result == .away
            case .over05:
                return (pick.match.goals ?? 0) > 0
            case .under05:
                return (pick.match.goals ?? 0) == 0
            case .over15:
                return (pick.match.goals ?? 0) > 1
            case .under15:
                return (pick.match.goals ?? 0) <= 1
            case .over25:
                return (pick.match.goals ?? 0) > 2
            case .under25:
                return (pick.match.goals ?? 0) <= 2
            case .over35:
                return (pick.match.goals ?? 0) > 3
            case .under35:
                return (pick.match.goals ?? 0) <= 3
            case .over45:
                return (pick.match.goals ?? 0) > 4
            case .under45:
                return (pick.match.goals ?? 0) <= 4
            }
        }
        
        updatedSlip.isWon = allCorrect
        updatedSlip.isEvaluated = true
        
        if allCorrect {
            balance += slip.potentialWin
        }
        
        return updatedSlip
    }
    
    func evaluateAllSlips() {
        slips = slips.map { evaluateSlip($0) }
        saveSlips()
    }
    
    // MARK: - STATISTICHE
    
    var totalBetsCount: Int {
        slips.count
    }
    
    var totalWins: Int {
        slips.filter { $0.isWon == true }.count
    }
    
    var totalLosses: Int {
        slips.filter { $0.isWon == false }.count
    }
    
    // MARK: - FUNZIONI PROFILO
    
    func resetAccount() {
        balance = 1000
        slips.removeAll()
        currentPicks.removeAll()
        saveSlips()
    }
    
    func toggleNotifications() {
        notificationsEnabled.toggle()
    }
    
    func togglePrivacy() {
        privacyEnabled.toggle()
    }
}

// MARK: - MAIN VIEW (PULITO, CON BETSTACK)

struct ContentView: View {
    
    @StateObject private var vm = BettingViewModel()
    @Namespace private var animationNamespace
    @State private var showSportMenu = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    headerView
                    
                    if vm.selectedTab == 0 {
                        calendarBarView
                        
                        if vm.isLoading {
                            loadingView
                        } else {
                            matchListView
                        }
                    } else if vm.selectedTab == 1 {
                        GamesView()
                            .environmentObject(vm)
                    } else if vm.selectedTab == 2 {
                        placedBetsView
                    } else {
                        ProfileView()
                            .environmentObject(vm)
                    }
                    
                    bottomBarView
                }
                
                floatingButtonView
                
                // Overlay per chiudere menu sport quando si tocca fuori
                if vm.showSportPicker {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            vm.showSportPicker = false
                        }
                }
            }
            .sheet(isPresented: $vm.showSheet) {
                BetSheet(
                    picks: $vm.currentPicks,
                    balance: $vm.balance,
                    totalOdd: vm.totalOdd
                ) { stake in vm.confirmSlip(stake: stake) }
            }
            .sheet(item: $vm.showSlipDetail) { SlipDetailView(slip: $0) }
        }
    }
    
    // MARK: - HEADER
    
    private var headerView: some View {
        HStack {
            if vm.selectedTab == 0 {
                // Header con selettore sport per la tab Calendario
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Sport")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                        
                        Button(action: {
                            // Mostra/nascondi menu sport
                            vm.showSportPicker.toggle()
                        }) {
                            Image(systemName: "chevron.down")
                                .foregroundColor(.accentCyan)
                                .rotationEffect(.degrees(vm.showSportPicker ? 180 : 0))
                                .animation(.easeInOut(duration: 0.3), value: vm.showSportPicker)
                        }
                        
                        // Mostra il nome dello sport selezionato
                        Text(vm.selectedSport)
                            .font(.title3)
                            .foregroundColor(.accentCyan)
                            .padding(.leading, 8)
                    }
                    
                    if vm.selectedTab == 0 && vm.lastUpdateTime != nil {
                        Text("Ultimo aggiornamento: \(formattedUpdateTime)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("€\(vm.balance, specifier: "%.2f")")
                        .foregroundColor(.accentCyan)
                        .bold()
                    
                    if vm.selectedTab == 0 {
                        Button(action: {
                            if vm.selectedSport == "Calcio" {
                                vm.fetchMatchesFromBetstack(for: vm.selectedSport)
                            } else {
                                // Per tennis, ricarica le partite simulate
                                vm.generateTennisMatchesIfNeeded()
                                vm.objectWillChange.send()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.accentCyan)
                                .font(.system(size: 16))
                        }
                        .disabled(vm.isLoading)
                    }
                }
            } else {
                // Header standard per altre tab
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.selectedTab == 1 ? "Giochi" :
                         vm.selectedTab == 2 ? "Piazzate" : "Profilo")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("€\(vm.balance, specifier: "%.2f")")
                        .foregroundColor(.accentCyan)
                        .bold()
                }
            }
        }
        .padding()
        .overlay(
            // Menu sport dropdown (posizionato sotto header)
            Group {
                if vm.showSportPicker && vm.selectedTab == 0 {
                    VStack(spacing: 0) {
                        Button {
                            vm.selectedSport = "Calcio"
                            vm.showSportPicker = false
                            vm.fetchMatchesFromBetstack(for: "Calcio")
                        } label: {
                            HStack {
                                Image(systemName: "soccerball")
                                    .foregroundColor(vm.selectedSport == "Calcio" ? .accentCyan : .white)
                                Text("Calcio")
                                    .foregroundColor(vm.selectedSport == "Calcio" ? .accentCyan : .white)
                                Spacer()
                                if vm.selectedSport == "Calcio" {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentCyan)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(width: 200)
                        }
                        .background(vm.selectedSport == "Calcio" ? Color.accentCyan.opacity(0.2) : Color.black.opacity(0.95))
                        
                        Button {
                            vm.selectedSport = "Tennis"
                            vm.showSportPicker = false
                            vm.generateTennisMatchesIfNeeded()
                        } label: {
                            HStack {
                                Image(systemName: "tennis.racket")
                                    .foregroundColor(vm.selectedSport == "Tennis" ? .accentCyan : .white)
                                Text("Tennis")
                                    .foregroundColor(vm.selectedSport == "Tennis" ? .accentCyan : .white)
                                Spacer()
                                if vm.selectedSport == "Tennis" {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentCyan)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(width: 200)
                        }
                        .background(vm.selectedSport == "Tennis" ? Color.accentCyan.opacity(0.2) : Color.black.opacity(0.95))
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.95))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.accentCyan.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    )
                    .offset(y: 60)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            },
            alignment: .topLeading
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.showSportPicker)
    }
    
    private var formattedUpdateTime: String {
        guard let date = vm.lastUpdateTime else { return "--" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: LOADING VIEW
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentCyan))
                .scaleEffect(1.5)
            
            Text("Caricamento partite...")
                .foregroundColor(.accentCyan)
                .font(.headline)
            
            Text("Sto recuperando le quote più recenti")
                .foregroundColor(.gray)
                .font(.caption)
            
            Spacer()
        }
    }
    
    // MARK: CALENDAR BAR
    
    private var calendarBarView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                ForEach(0..<3) { index in
                    let date = vm.dateForIndex(index)
                    
                    VStack(spacing: 4) {
                        Text(vm.formattedDay(date))
                            .font(.title2.bold())
                        Text(vm.formattedMonth(date))
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 90, height: 70)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(vm.selectedDayIndex == index ? Color.accentCyan : Color.white.opacity(0.2), lineWidth: 3)
                    )
                    .onTapGesture { vm.selectedDayIndex = index }
                    .animation(.easeInOut, value: vm.selectedDayIndex)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: MATCH LIST
    
    private var matchListView: some View {
        let groupedMatches = vm.matchesForSelectedDay()
        let isYesterday = vm.selectedDayIndex == 0
        
        return ScrollView {
            VStack(spacing: 16) {
                if groupedMatches.isEmpty && !vm.isLoading {
                    emptyMatchesView
                } else {
                    ForEach(groupedMatches.keys.sorted(), id: \.self) { time in
                        VStack(spacing: 10) {
                            HStack {
                                Text(time)
                                    .font(.headline)
                                    .foregroundColor(.accentCyan)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            
                            ForEach(groupedMatches[time]!) { match in
                                NavigationLink(destination: MatchDetailView(match: match, vm: vm)) {
                                    matchCardView(match: match, disabled: isYesterday)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .id("\(vm.selectedDayIndex)-\(vm.selectedSport)") // Aggiorna quando cambia sport
        .transition(.opacity)
        .refreshable {
            if vm.selectedTab == 0 && vm.selectedDayIndex == 1 { // Solo per oggi
                if vm.selectedSport == "Calcio" {
                    vm.fetchMatchesFromBetstack(for: vm.selectedSport)
                } else {
                    vm.generateTennisMatchesIfNeeded()
                    vm.objectWillChange.send()
                }
            }
        }
    }
    
    private var emptyMatchesView: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 50)
            
            Image(systemName: vm.selectedSport == "Calcio" ? "soccerball" : "tennis.racket")
                .font(.system(size: 60))
                .foregroundColor(.accentCyan)
            
            Text("Nessuna partita disponibile")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Premi il pulsante di aggiornamento per caricare nuove partite")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Aggiorna") {
                if vm.selectedSport == "Calcio" {
                    vm.fetchMatchesFromBetstack(for: vm.selectedSport)
                } else {
                    vm.generateTennisMatchesIfNeeded()
                    vm.objectWillChange.send()
                }
            }
            .padding()
            .background(Color.accentCyan)
            .foregroundColor(.black)
            .cornerRadius(12)
            
            Spacer()
        }
    }
    
    private func matchCardView(match: Match, disabled: Bool) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.home)
                        .font(.headline)
                        .foregroundColor(disabled ? .gray : .white)
                        .lineLimit(1)
                    
                    Text(match.competition)
                        .font(.caption2)
                        .foregroundColor(.accentCyan)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(match.away)
                        .font(.headline)
                        .foregroundColor(disabled ? .gray : .white)
                        .lineLimit(1)
                    
                    if let actualResult = match.actualResult {
                        Text(actualResult)
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else {
                        Text(match.status)
                            .font(.caption2)
                            .foregroundColor(match.status == "FINISHED" ? .green : 
                                           match.status == "LIVE" ? .red : .orange)
                    }
                }
            }
            
            // Per il tennis, mostriamo solo 1 e 2 (non c'è X)
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("1")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(match.odds.home, specifier: "%.2f")")
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                
                if vm.selectedSport == "Calcio" {
                    Divider()
                        .frame(height: 30)
                        .background(Color.gray.opacity(0.3))
                    
                    VStack(spacing: 4) {
                        Text("X")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(match.odds.draw, specifier: "%.2f")")
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Divider()
                    .frame(height: 30)
                    .background(Color.gray.opacity(0.3))
                
                VStack(spacing: 4) {
                    Text("2")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(match.odds.away, specifier: "%.2f")")
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 10)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(disabled ? Color.gray.opacity(0.1) : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(disabled ? Color.gray.opacity(0.2) : Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: PLACED BETS
    
    private var placedBetsView: some View {
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
        .onAppear { vm.evaluateAllSlips() }
    }
    
    // MARK: - FLOATING BUTTON
    
    private var floatingButtonView: some View {
        Group {
            if !vm.currentPicks.isEmpty && vm.selectedTab != 3 {
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
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
    
    // MARK: - BOTTOM BAR
    
    private var bottomBarView: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: 70)
                .cornerRadius(26)
                .padding(.horizontal)
                .shadow(color: .black.opacity(0.25), radius: 10, y: -2)
            
            HStack(spacing: 50) {
                ForEach(0..<4) { index in
                    bottomItemView(index: index)
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    private func bottomItemView(index: Int) -> some View {
        let icon: String
        switch index {
        case 0: icon = "calendar"
        case 1: icon = "dice.fill"
        case 2: icon = "list.bullet"
        case 3: icon = "person.crop.circle"
        default: icon = "circle"
        }
        
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                vm.selectedTab = index
                if index != 0 {
                    vm.showSportPicker = false
                }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if vm.selectedTab == index {
                        Circle()
                            .fill(Color.accentCyan.opacity(0.25))
                            .frame(width: 44, height: 44)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(vm.selectedTab == index ? .accentCyan : .white.opacity(0.7))
                }
                
                if vm.selectedTab == index {
                    Capsule()
                        .fill(Color.accentCyan)
                        .frame(width: 22, height: 4)
                        .matchedGeometryEffect(id: "tab", in: animationNamespace)
                } else {
                    Capsule()
                        .fill(Color.clear)
                        .frame(width: 22, height: 4)
                }
            }
        }
    }
}