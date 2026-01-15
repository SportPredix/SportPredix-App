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

    private let slipsKey = "savedSlips"
    private let matchesKey = "savedMatches"

    private let teams = [
        "Napoli","Inter","Milan","Juventus","Roma","Lazio",
        "Liverpool","Chelsea","Arsenal","Man City","Tottenham",
        "Real Madrid","Barcellona","Atletico","Valencia",
        "Bayern","Dortmund","Leipzig","Leverkusen"
    ]

    init() {
        let savedBalance = UserDefaults.standard.double(forKey: "balance")
        self.balance = savedBalance == 0 ? 1000 : savedBalance

        self.userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        self.slips = loadSlips()
        self.dailyMatches = loadMatches()

        generateTodayIfNeeded()
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
                over25: Double.random(in: 1.70...2.20),
                under25: Double.random(in: 1.70...2.20)
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
                goals: goals
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
            case .over25:
                return (pick.match.goals ?? 0) > 2
            case .under25:
                return (pick.match.goals ?? 0) <= 2
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
                    GamesView()
                } else if vm.selectedTab == 2 {
                    placedBets
                        .onAppear { vm.evaluateAllSlips() }
                } else {
                    ProfileView(userName: $vm.userName, balance: $vm.balance)
                        .environmentObject(vm)
                }

                bottomBar
            }

            if !vm.currentPicks.isEmpty {
                floatingButton
                    .transition(.scale.combined(with: .opacity))
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

            Text("€\(vm.balance, specifier: "%.2f")")
                .foregroundColor(.accentCyan)
                .bold()
        }
        .padding()
    }

    // MARK: CALENDAR BAR

    private var calendarBar: some View {
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
        .padding(.bottom, 8)
    }

    // MARK: MATCH LIST

    private var matchList: some View {
        let groupedMatches = vm.matchesForSelectedDay()
        let isYesterday = vm.selectedDayIndex == 0

        return ScrollView {
            VStack(spacing: 16) {
                ForEach(groupedMatches.keys.sorted(), id: \.self) { time in
                    VStack(spacing: 10) {
                        HStack {
                            Spacer()
                            Text(time)
                                .font(.headline)
                                .foregroundColor(.accentCyan)
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

    // MARK: FLOATING BUTTON

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

    // MARK: - BOTTOM BAR (CON SFOCATURA COME NELL'IMMAGINE)

    private var bottomBar: some View {
        ZStack {
            Rectangle()
                .background(.ultraThinMaterial)
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

// MARK: - GAMES VIEW

struct GamesView: View {
    let games = [
        ("Gratta e Vinci", "scrubber"),
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
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    Text("Giochi")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(games, id: \.0) { game in
                            GameButton(title: game.0, icon: game.1)
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
    @State private var showComingSoon = false
    
    var body: some View {
        Button {
            showComingSoon = true
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
        .sheet(isPresented: $showComingSoon) {
            ComingSoonView()
        }
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
            }
            .padding()
        }
    }
}

// MARK: - BET SHEET

struct BetSheet: View {

    @Binding var picks: [BetPick]
    @Binding var balance: Double
    let totalOdd: Double
    let onConfirm: (Double) -> Void

    @State private var stakeText: String = "1"

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
                    }) {
                        Text("Conferma schedina")
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
        }
    }
}

// MARK: - SLIP DETAIL VIEW

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

// MARK: - MATCH DETAIL VIEW

struct MatchDetailView: View {
    let match: Match
    @ObservedObject var vm: BettingViewModel

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("\(match.home) vs \(match.away)")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                Text("Orario: \(match.time)")
                    .foregroundColor(.accentCyan)

                ScrollView {
                    VStack(spacing: 16) {
                        oddsSection(title: "1X2", odds: [
                            ("1", .home, match.odds.home),
                            ("X", .draw, match.odds.draw),
                            ("2", .away, match.odds.away)
                        ])

                        oddsSection(title: "Doppie Chance", odds: [
                            ("1X", .homeDraw, match.odds.homeDraw),
                            ("12", .homeAway, match.odds.homeAway),
                            ("X2", .drawAway, match.odds.drawAway)
                        ])

                        oddsSection(title: "Over/Under 2.5", odds: [
                            ("Over 2.5", .over25, match.odds.over25),
                            ("Under 2.5", .under25, match.odds.under25)
                        ])
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
                    .transition(.scale.combined(with: .opacity))
                }
            }
        )
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.accentCyan)
                        .font(.system(size: 20, weight: .semibold))
                }
            }
        }
        .navigationTitle("Dettagli Partita")
        .navigationBarTitleDisplayMode(.inline)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 100 { // swipe destra per tornare indietro
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
    }

    private func oddsSection(title: String, odds: [(String, MatchOutcome, Double)]) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)

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
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentCyan : Color.white.opacity(0.2), lineWidth: 3)
            )
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

                    // MARK: - HEADER CARD
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

                        Text(userName.isEmpty ? "Utente" : userName)
                            .font(.title.bold())
                            .foregroundColor(.white)

                        Text("Saldo: €\(balance, specifier: "%.2f")")
                            .font(.title3.bold())
                            .foregroundColor(.accentCyan)

                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                showNameField.toggle()
                            }
                        } label: {
                            Text("Modifica nome")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                        }

                        if showNameField {
                            TextField("Inserisci nome", text: $userName)
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .padding(.horizontal)

                    // MARK: - QUICK SETTINGS
                    VStack(alignment: .leading, spacing: 16) {

                        Text("Impostazioni rapide")
                            .font(.headline)
                            .foregroundColor(.white)

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

                    // MARK: - USER STATS
                    VStack(alignment: .leading, spacing: 16) {

                        Text("Statistiche utente")
                            .font(.headline)
                            .foregroundColor(.white)

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
            Image(systemName: icon)
                .foregroundColor(.accentCyan)
                .frame(width: 28)

            Text(title)
                .foregroundColor(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
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
        }
        .padding(.vertical, 4)
    }
}