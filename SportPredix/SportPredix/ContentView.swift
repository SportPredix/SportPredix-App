//
//  ContentView.swift
//  SportPredix
//

import SwiftUI

// MARK: - THEME

extension Color {
    static let accentCyan = Color(red: 68/255, green: 224/255, blue: 203/255)
}

// MARK: - MODELS

enum MatchOutcome: String, Codable {
    case home = "1"
    case draw = "X"
    case away = "2"
    case homeDraw = "1X"
    case homeAway = "12"
    case drawAway = "X2"
    case over05 = "O 0.5"
    case under05 = "U 0.5"
    case over15 = "O 1.5"
    case under15 = "U 1.5"
    case over25 = "O 2.5"
    case under25 = "U 2.5"
    case over35 = "O 3.5"
    case under35 = "U 3.5"
    case over45 = "O 4.5"
    case under45 = "U 4.5"
}

struct Odds: Codable {
    let home: Double
    let draw: Double
    let away: Double
    let homeDraw: Double
    let homeAway: Double
    let drawAway: Double
    let over05: Double
    let under05: Double
    let over15: Double
    let under15: Double
    let over25: Double
    let under25: Double
    let over35: Double
    let under35: Double
    let over45: Double
    let under45: Double
}

struct Match: Identifiable, Codable {
    let id: UUID
    let home: String
    let away: String
    let time: String
    let odds: Odds
    var result: MatchOutcome?
    var goals: Int?
    var competition: String? // Nuovo campo per l'API
    var status: String? // Nuovo campo per l'API
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

// MARK: - API MODELS

struct APIMatch: Codable {
    let id: Int
    let utcDate: String
    let status: String
    let homeTeam: APITeam
    let awayTeam: APITeam
    let score: APIScore
    let competition: APICompetition
    
    enum CodingKeys: String, CodingKey {
        case id, utcDate, status, homeTeam, awayTeam, score, competition
    }
}

struct APITeam: Codable {
    let id: Int
    let name: String
    let shortName: String?
    let tla: String?
}

struct APIScore: Codable {
    let winner: String?
    let fullTime: APITimeScore?
}

struct APITimeScore: Codable {
    let home: Int?
    let away: Int?
}

struct APICompetition: Codable {
    let id: Int
    let name: String
    let code: String
}

struct MatchesResponse: Codable {
    let matches: [APIMatch]
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
    
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    
    @Published var privacyEnabled: Bool {
        didSet { UserDefaults.standard.set(privacyEnabled, forKey: "privacyEnabled") }
    }
    
    @Published var currentPicks: [BetPick] = []
    @Published var slips: [BetSlip] = []
    
    @Published var dailyMatches: [String: [Match]] = [:]
    
    // API Properties
    @Published var isLoading = false
    @Published var apiError: String?
    @Published var useRealMatches = false
    
    private let slipsKey = "savedSlips"
    private let matchesKey = "savedMatches"
    private let useRealMatchesKey = "useRealMatches"
    
    private let teams = [
        "Napoli","Inter","Milan","Juventus","Roma","Lazio",
        "Liverpool","Chelsea","Arsenal","Man City","Tottenham",
        "Real Madrid","Barcellona","Atletico","Valencia",
        "Bayern","Dortmund","Leipzig","Leverkusen"
    ]
    
    // API Config - INSERISCI LA TUA API KEY QUI
    private let apiKey = "1509673c3a344745b0159b18dfbc0d1c" // Ottienila da https://www.football-data.org/
    private let baseURL = "https://api.football-data.org/v4"
    
    // Proprietà pubblica per verificare se l'API key è configurata
    var hasAPIKey: Bool {
        return !apiKey.isEmpty
    }
    
    init() {
        let savedBalance = UserDefaults.standard.double(forKey: "balance")
        self.balance = savedBalance == 0 ? 1000 : savedBalance
        
        self.userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.privacyEnabled = UserDefaults.standard.object(forKey: "privacyEnabled") as? Bool ?? false
        
        self.useRealMatches = UserDefaults.standard.object(forKey: useRealMatchesKey) as? Bool ?? false
        
        self.slips = loadSlips()
        self.dailyMatches = loadMatches()
        
        generateTodayIfNeeded()
        
        // Se l'API key è presente e l'opzione è attiva, carica le partite reali
        if useRealMatches && hasAPIKey {
            fetchTodaysRealMatches()
        }
    }
    
    // MARK: - API FUNCTIONS
    
    func toggleRealMatches() {
        useRealMatches.toggle()
        UserDefaults.standard.set(useRealMatches, forKey: useRealMatchesKey)
        
        if useRealMatches && hasAPIKey {
            fetchTodaysRealMatches()
        } else if !useRealMatches {
            // Torna alle partite simulate
            generateTodayIfNeeded()
        } else if useRealMatches && !hasAPIKey {
            apiError = "API key mancante. Ottienila da football-data.org"
        }
    }
    
    func fetchTodaysRealMatches() {
        guard hasAPIKey else {
            apiError = "API key mancante. Ottienila da football-data.org"
            return
        }
        
        isLoading = true
        apiError = nil
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        
        // URL per le partite di oggi
        let urlString = "\(baseURL)/matches?dateFrom=\(today)&dateTo=\(today)"
        
        guard let url = URL(string: urlString) else {
            apiError = "URL non valido"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Auth-Token")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.apiError = "Errore: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.apiError = "Nessun dato ricevuto"
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(MatchesResponse.self, from: data)
                    self?.processAPIMatches(response.matches)
                } catch {
                    self?.apiError = "Errore decodifica: \(error.localizedDescription)"
                    print("JSON error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("JSON ricevuto: \(jsonString)")
                    }
                }
            }
        }
        
        task.resume()
    }
    
    private func processAPIMatches(_ apiMatches: [APIMatch]) {
        let todayKey = keyForDate(Date())
        var convertedMatches: [Match] = []
        
        for apiMatch in apiMatches {
            // Converte la data UTC in orario locale
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            var timeString = "TBD"
            if let date = dateFormatter.date(from: apiMatch.utcDate) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                timeFormatter.timeZone = TimeZone.current
                timeString = timeFormatter.string(from: date)
            }
            
            // Crea quote casuali (l'API non fornisce quote reali nella versione gratuita)
            let odds = Odds(
                home: Double.random(in: 1.20...2.50),
                draw: Double.random(in: 2.80...4.50),
                away: Double.random(in: 2.50...7.00),
                homeDraw: Double.random(in: 1.10...1.50),
                homeAway: Double.random(in: 1.15...1.30),
                drawAway: Double.random(in: 1.20...1.60),
                over05: Double.random(in: 1.05...1.30),
                under05: Double.random(in: 3.00...9.00),
                over15: Double.random(in: 1.30...2.00),
                under15: Double.random(in: 1.30...3.45),
                over25: Double.random(in: 1.70...2.20),
                under25: Double.random(in: 1.70...2.20),
                over35: Double.random(in: 2.50...4.00),
                under35: Double.random(in: 1.10...1.50),
                over45: Double.random(in: 4.00...8.00),
                under45: Double.random(in: 1.05...1.30)
            )
            
            // Determina il risultato basato sul punteggio
            var result: MatchOutcome?
            var goals: Int?
            
            if let score = apiMatch.score.fullTime {
                let homeGoals = score.home ?? 0
                let awayGoals = score.away ?? 0
                goals = homeGoals + awayGoals
                
                if homeGoals > awayGoals {
                    result = .home
                } else if awayGoals > homeGoals {
                    result = .away
                } else {
                    result = .draw
                }
            }
            
            let match = Match(
                id: UUID(),
                home: apiMatch.homeTeam.name,
                away: apiMatch.awayTeam.name,
                time: timeString,
                odds: odds,
                result: result,
                goals: goals,
                competition: apiMatch.competition.name,
                status: apiMatch.status
            )
            
            convertedMatches.append(match)
        }
        
        // Salva le partite
        dailyMatches[todayKey] = convertedMatches
        saveMatches()
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
        f.dateFormat = "MMM"
        return f.string(from: date)
    }
    
    // MARK: - MATCH GENERATION (CON RISULTATO CASUALE)
    
    func generateMatchesForDate(_ date: Date) -> [Match] {
        var result: [Match] = []
        
        for _ in 0..<12 {
            let home = teams.randomElement()!
            var away = teams.randomElement()!
            while away == home { away = teams.randomElement()! }
            
            let hour = Int.random(in: 12...22)
            let minute = ["00","15","30","45"].randomElement()!
            let time = "\(hour):\(minute)"
            
            let odds = Odds(
                home: Double.random(in: 1.20...2.50),
                draw: Double.random(in: 2.80...4.50),
                away: Double.random(in: 2.50...7.00),
                homeDraw: Double.random(in: 1.10...1.50),
                homeAway: Double.random(in: 1.15...1.30),
                drawAway: Double.random(in: 1.20...1.60),
                over05: Double.random(in: 1.05...1.30),
                under05: Double.random(in: 3.00...9.00),
                over15: Double.random(in: 1.30...2.00),
                under15: Double.random(in: 1.30...3.45),
                over25: Double.random(in: 1.70...2.20),
                under25: Double.random(in: 1.70...2.20),
                over35: Double.random(in: 2.50...4.00),
                under35: Double.random(in: 1.10...1.50),
                over45: Double.random(in: 4.00...8.00),
                under45: Double.random(in: 1.05...1.30)
            )
            
            let goals = Int.random(in: 0...6)
            
            let possibleResults: [MatchOutcome] = [.home, .draw, .away]
            let randomResult = possibleResults.randomElement()!
            
            result.append(Match(
                id: UUID(),
                home: home,
                away: away,
                time: time,
                odds: odds,
                result: randomResult,
                goals: goals,
                competition: "Serie A",
                status: "FINISHED"
            ))
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
            let grouped = Dictionary(grouping: existing) { $0.time }
            return grouped
        }
        
        let newMatches = generateMatchesForDate(date)
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
        // Controlla se esiste già una pick per questa partita
        _ = currentPicks.firstIndex(where: { $0.match.id == match.id })
        
        // Determina a quale sezione appartiene l'outcome selezionato
        let selectedOutcomeSection = getSectionForOutcome(outcome)
        
        // Rimuovi tutte le pick della stessa sezione per questa partita
        currentPicks.removeAll { pick in
            pick.match.id == match.id && getSectionForOutcome(pick.outcome) == selectedOutcomeSection
        }
        
        // Aggiungi la nuova pick
        currentPicks.append(BetPick(id: UUID(), match: match, outcome: outcome, odd: odd))
    }
    
    // Funzione per determinare la sezione di un outcome
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
        
        // già valutata → non tocco saldo né stato
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
                        
                        // Aggiungi toggle per API
                        if vm.isLoading {
                            loadingView
                        } else if let error = vm.apiError {
                            errorView(error: error)
                        } else {
                            matchList
                        }
                    } else if vm.selectedTab == 1 {
                        GamesView()
                    } else if vm.selectedTab == 2 {
                        placedBets
                            .onAppear { vm.evaluateAllSlips() }
                    } else {
                        ProfileView()
                            .environmentObject(vm)
                    }
                    
                    bottomBar
                }
                
                // FLOATING BUTTON PER LE SCHEDINE
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
    
    private var header: some View {
        HStack {
            Text(vm.selectedTab == 0 ? "Calendario" :
                    vm.selectedTab == 1 ? "Giochi" :
                    vm.selectedTab == 2 ? "Piazzate" : "Profilo")
            .font(.largeTitle.bold())
            .foregroundColor(.white)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("€\(vm.balance, specifier: "%.2f")")
                    .foregroundColor(.accentCyan)
                    .bold()
                
                // Toggle per API
                if vm.selectedTab == 0 {
                    HStack {
                        Text("API")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Toggle("", isOn: Binding(
                            get: { vm.useRealMatches },
                            set: { _ in vm.toggleRealMatches() }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .accentCyan))
                        .labelsHidden()
                        .scaleEffect(0.8)
                    }
                }
            }
        }
        .padding()
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(.accentCyan)
            Text("Caricamento partite in corso...")
                .foregroundColor(.white)
            Spacer()
        }
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Errore API")
                .font(.title2)
                .foregroundColor(.white)
            
            Text(error)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Riprova") {
                vm.fetchTodaysRealMatches()
            }
            .padding()
            .background(Color.accentCyan)
            .foregroundColor(.black)
            .cornerRadius(12)
            
            Button("Usa partite simulate") {
                vm.useRealMatches = false
            }
            .padding()
            .foregroundColor(.gray)
            
            Spacer()
        }
    }
    
    // MARK: CALENDAR BAR
    
    private var calendarBar: some View {
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
            
            // Info API
            if vm.useRealMatches {
                if vm.hasAPIKey {
                    Text("Partite reali da Football-Data.org")
                        .font(.caption)
                        .foregroundColor(.accentCyan)
                } else {
                    Text("API key mancante - Usa partite simulate")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else {
                Text("Partite simulate")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: MATCH LIST
    
    private var matchList: some View {
        let groupedMatches = vm.matchesForSelectedDay()
        let isYesterday = vm.selectedDayIndex == 0
        
        return ScrollView {
            VStack(spacing: 16) {
                if groupedMatches.isEmpty {
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
                                matchCard(match, disabled: isYesterday)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .id(vm.selectedDayIndex)
        .transition(.opacity)
    }
    
    private var emptyMatchesView: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 50)
            
            Image(systemName: "soccerball")
                .font(.system(size: 60))
                .foregroundColor(.accentCyan)
            
            Text("Nessuna partita oggi")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Prova con le partite simulate o verifica la tua API key")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if !vm.hasAPIKey && vm.useRealMatches {
                Button("Configura API Key") {
                    // Apri il sito per ottenere l'API key
                    if let url = URL(string: "https://www.football-data.org/") {
                        UIApplication.shared.open(url)
                    }
                }
                .padding()
                .background(Color.accentCyan)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
            
            Spacer()
        }
    }
    
    private func matchCard(_ match: Match, disabled: Bool) -> some View {
        NavigationLink(destination: MatchDetailView(match: match, vm: vm)) {
            VStack(spacing: 12) {
                HStack {
                    Text(match.home)
                        .font(.headline)
                        .foregroundColor(disabled ? .gray : .white)
                    Spacer()
                    Text(match.away)
                        .font(.headline)
                        .foregroundColor(disabled ? .gray : .white)
                }
                
                if let competition = match.competition {
                    HStack {
                        Text(competition)
                            .font(.caption)
                            .foregroundColor(.accentCyan)
                        Spacer()
                        if let status = match.status {
                            Text(status)
                                .font(.caption)
                                .foregroundColor(status == "FINISHED" ? .green : .orange)
                        }
                    }
                }
                
                HStack {
                    Text("1: \(String(format: "%.2f", match.odds.home))")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("X: \(String(format: "%.2f", match.odds.draw))")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("2: \(String(format: "%.2f", match.odds.away))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(disabled ? Color.gray.opacity(0.1) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(disabled ? Color.gray.opacity(0.2) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .disabled(disabled)
    }
    
    // MARK: PLACED BETS
    
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
    
    // MARK: - BOTTOM BAR
    
    private var bottomBar: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: 70)
                .cornerRadius(26)
                .padding(.horizontal)
                .shadow(color: .black.opacity(0.25), radius: 10, y: -2)
            
            HStack(spacing: 50) {
                bottomItem(icon: "calendar", index: 0)
                bottomItem(icon: "dice.fill", index: 1)
                bottomItem(icon: "list.bullet", index: 2)
                bottomItem(icon: "person.crop.circle", index: 3)
            }
        }
        .padding(.bottom, 8)
    }
    
    private func bottomItem(icon: String, index: Int) -> some View {
        let isSelected = vm.selectedTab == index
        
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                vm.selectedTab = index
            }
        } label: {
            VStack(spacing: 6) {
                
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.accentCyan.opacity(0.25))
                            .frame(width: 44, height: 44)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .accentCyan : .white.opacity(0.7))
                        .scaleEffect(isSelected ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                }
                
                if isSelected {
                    Capsule()
                        .fill(Color.accentCyan)
                        .frame(width: 22, height: 4)
                        .matchedGeometryEffect(id: "tabIndicator", in: animationNamespace)
                } else {
                    Capsule()
                        .fill(Color.clear)
                        .frame(width: 22, height: 4)
                }
            }
        }
    }
}