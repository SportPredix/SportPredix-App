//
//  ContentView.swift
//  SportPredix
//
//  Tutto in un unico file, con:
//  - MVVM
//  - Calendario 3 giorni (ieri/oggi/domani) selezionabile
//  - 12 partite al giorno generate da Serie A, Premier, Liga, Bundesliga
//  - Toolbar con 3 tab: Calendario, Piazzate, Profilo
//  - Pagina profilo con nome salvato in UserDefaults
//  - Saluto "Ciao <nome>" in home
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
}

struct Match: Identifiable, Codable {
    let id: UUID
    let home: String
    let away: String
    let time: String
    let odds: [Double]

    init(id: UUID = UUID(), home: String, away: String, time: String, odds: [Double]) {
        self.id = id
        self.home = home
        self.away = away
        self.time = time
        self.odds = odds
    }
}

struct BetPick: Identifiable, Codable {
    let id: UUID
    let match: Match
    let outcome: MatchOutcome
    let odd: Double

    init(id: UUID = UUID(), match: Match, outcome: MatchOutcome, odd: Double) {
        self.id = id
        self.match = match
        self.outcome = outcome
        self.odd = odd
    }
}

struct BetSlip: Identifiable, Codable {
    let id: UUID
    let picks: [BetPick]
    let stake: Double
    let totalOdd: Double
    let potentialWin: Double
    let date: Date

    init(id: UUID = UUID(), picks: [BetPick], stake: Double, totalOdd: Double, potentialWin: Double, date: Date = Date()) {
        self.id = id
        self.picks = picks
        self.stake = stake
        self.totalOdd = totalOdd
        self.potentialWin = potentialWin
        self.date = date
    }

    var impliedProbability: Double {
        1 / totalOdd
    }

    var expectedValue: Double {
        potentialWin * impliedProbability - stake
    }
}

// MARK: - VIEW MODEL

final class BettingViewModel: ObservableObject {
    @Published var selectedTab = 0
    @Published var showSheet = false
    @Published var showSlipDetail: BetSlip?

    @Published var balance: Double {
        didSet {
            UserDefaults.standard.set(balance, forKey: "balance")
        }
    }

    @Published var currentPicks: [BetPick] = []
    @Published var slips: [BetSlip] = []

    // Calendario: 0 = ieri, 1 = oggi, 2 = domani
    @Published var selectedDayIndex: Int = 1
    @Published var days: [Date] = []

    // Partite per giorno
    @Published private(set) var matchesByDate: [Date: [Match]] = [:]

    // Nome utente
    @Published var userName: String {
        didSet {
            UserDefaults.standard.set(userName, forKey: "userName")
        }
    }

    private let slipsKey = "savedSlips"

    // Squadre per campionati
    private let serieA = ["Inter", "Milan", "Juventus", "Napoli", "Roma", "Lazio", "Atalanta", "Fiorentina", "Bologna", "Torino"]
    private let premierLeague = ["Manchester City", "Liverpool", "Arsenal", "Chelsea", "Manchester United", "Tottenham", "Newcastle", "Aston Villa"]
    private let liga = ["Real Madrid", "Barcelona", "Atletico Madrid", "Sevilla", "Valencia", "Villarreal", "Real Sociedad", "Betis"]
    private let bundesliga = ["Bayern Monaco", "Borussia Dortmund", "RB Lipsia", "Leverkusen", "Union Berlin", "Eintracht Francoforte", "Wolfsburg", "Stoccarda"]

    init() {
        let savedBalance = UserDefaults.standard.double(forKey: "balance")
        self.balance = savedBalance == 0 ? 1000 : savedBalance

        self.slips = loadSlips()
        self.userName = UserDefaults.standard.string(forKey: "userName") ?? ""

        setupDays()
        generateMatchesForAllDays()
    }

    // MARK: - Calendario

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func setupDays() {
        let today = startOfDay(Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        self.days = [yesterday, today, tomorrow]
        self.selectedDayIndex = 1
    }

    var selectedDate: Date {
        days[selectedDayIndex]
    }

    var matchesForSelectedDay: [Match] {
        matchesByDate[startOfDay(selectedDate)] ?? []
    }

    func refreshIfNeeded() {
        // Se il "oggi" salvato non è più oggi, rigenera i giorni
        let today = startOfDay(Date())
        if startOfDay(days[1]) != today {
            setupDays()
            generateMatchesForAllDays()
        }
    }

    private func generateMatchesForAllDays() {
        for day in days {
            matchesByDate[startOfDay(day)] = generateMatches(for: day)
        }
    }

    private func generateMatches(for date: Date) -> [Match] {
        var allTeams = serieA + premierLeague + liga + bundesliga
        allTeams.shuffle()

        var matches: [Match] = []
        let numberOfMatches = 12

        for i in 0..<numberOfMatches {
            if allTeams.count < 2 { break }
            let home = allTeams.removeFirst()
            let away = allTeams.removeFirst()

            let hour = 18 + (i % 5) // tra 18 e 22
            let minute = (i * 15) % 60
            let timeString = String(format: "%02d:%02d", hour, minute)

            let odds = generateOdds()
            let match = Match(home: home, away: away, time: timeString, odds: odds)
            matches.append(match)
        }

        return matches
    }

    private func generateOdds() -> [Double] {
        // Quote realistiche 1X2
        let base = Double.random(in: 1.20...2.20)
        let draw = Double.random(in: 2.80...4.50)
        let away = Double.random(in: 2.00...6.50)

        let odds = [base, draw, away].shuffled()
        return odds.map { Double(round(100 * $0) / 100) }
    }

    // MARK: - Logica scommesse

    var totalOdd: Double {
        currentPicks.map { $0.odd }.reduce(1, *)
    }

    func addPick(match: Match, outcome: MatchOutcome, odd: Double) {
        guard !currentPicks.contains(where: { $0.match.id == match.id }) else { return }
        currentPicks.append(BetPick(match: match, outcome: outcome, odd: odd))
    }

    func removePick(_ pick: BetPick) {
        currentPicks.removeAll { $0.id == pick.id }
    }

    func confirmSlip(stake: Double) {
        let slip = BetSlip(
            picks: currentPicks,
            stake: stake,
            totalOdd: totalOdd,
            potentialWin: stake * totalOdd
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
              let decoded = try? JSONDecoder().decode([BetSlip].self, from: data) else {
            return []
        }
        return decoded
    }
}

// MARK: - MAIN VIEW

struct ContentView: View {

    @StateObject private var vm = BettingViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if vm.selectedTab == 0 {
                    matchList
                } else if vm.selectedTab == 1 {
                    placedBets
                } else {
                    profileView
                }

                bottomBar
            }

            if !vm.currentPicks.isEmpty && vm.selectedTab == 0 {
                floatingButton
            }
        }
        .onAppear {
            vm.refreshIfNeeded()
        }
        .sheet(isPresented: $vm.showSheet) {
            BetSheet(
                picks: $vm.currentPicks,
                balance: $vm.balance,
                totalOdd: vm.totalOdd
            ) { stake in
                vm.confirmSlip(stake: stake)
            }
        }
        .sheet(item: $vm.showSlipDetail) { slip in
            SlipDetailView(slip: slip)
        }
    }

    // MARK: HEADER

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(vm.selectedTab == 0 ? "Calendario" : (vm.selectedTab == 1 ? "Piazzate" : "Profilo"))
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                Spacer()

                Text("€\(vm.balance, specifier: "%.2f")")
                    .foregroundColor(.accentCyan)
                    .bold()
            }

            if vm.selectedTab == 0 {
                Text("Ciao \(vm.userName.isEmpty ? "Scommettitore" : vm.userName)")
                    .foregroundColor(.gray)
                    .font(.subheadline)

                smallCalendar
            }

        }
        .padding()
    }

    // MARK: SMALL CALENDAR

    private var smallCalendar: some View {
        HStack(spacing: 8) {
            ForEach(0..<vm.days.count, id: \.self) { index in
                let date = vm.days[index]
                Button {
                    vm.selectedDayIndex = index
                } label: {
                    VStack(spacing: 2) {
                        Text(dayLabel(for: date, index: index))
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(dayNumber(for: date))
                            .font(.headline)
                        Text(monthShort(for: date))
                            .font(.caption2)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(vm.selectedDayIndex == index ? Color.accentCyan.opacity(0.2) : Color.white.opacity(0.06))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(vm.selectedDayIndex == index ? Color.accentCyan : Color.clear, lineWidth: 1)
                    )
                    .foregroundColor(.white)
                }
            }
        }
    }

    private func dayLabel(for date: Date, index: Int) -> String {
        switch index {
        case 0: return "Ieri"
        case 1: return "Oggi"
        case 2: return "Domani"
        default: return ""
        }
    }

    private func dayNumber(for date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "d"
        return df.string(from: date)
    }

    private func monthShort(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "it_IT")
        df.dateFormat = "MMM"
        return df.string(from: date)
    }

    // MARK: MATCH LIST

    private var matchList: some View {
        ScrollView {
            VStack(spacing: 16) {
                if vm.matchesForSelectedDay.isEmpty {
                    Text("Nessuna partita per questo giorno")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(vm.matchesForSelectedDay) { match in
                        matchCard(match)
                    }
                }
            }
            .padding()
        }
    }

    private func matchCard(_ match: Match) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(match.home)
                    .font(.headline)
                Spacer()
                Text(match.time)
                    .font(.subheadline.bold())
                    .foregroundColor(.accentCyan)
                Spacer()
                Text(match.away)
                    .font(.headline)
            }
            .foregroundColor(.white)

            HStack(spacing: 10) {
                oddButton("1", match, .home, match.odds[0])
                oddButton("X", match, .draw, match.odds[1])
                oddButton("2", match, .away, match.odds[2])
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func oddButton(_ label: String, _ match: Match, _ outcome: MatchOutcome, _ odd: Double) -> some View {
        Button {
            vm.addPick(match: match, outcome: outcome, odd: odd)
        } label: {
            VStack {
                Text(label).bold()
                Text(String(format: "%.2f", odd)).font(.caption)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Color.accentCyan)
            .cornerRadius(12)
        }
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
                        Button {
                            vm.showSlipDetail = slip
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quota \(slip.totalOdd, specifier: "%.2f")")
                                    .foregroundColor(.accentCyan)
                                Text("Puntata €\(slip.stake, specifier: "%.2f")")
                                    .foregroundColor(.white)
                                Text("Vincita potenziale €\(slip.potentialWin, specifier: "%.2f")")
                                    .foregroundColor(.gray)
                                    .font(.caption)
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

    // MARK: PROFILE VIEW

    private var profileView: some View {
        ProfileView(userName: $vm.userName, balance: $vm.balance)
    }

    // MARK: BOTTOM BAR

    private var bottomBar: some View {
        HStack {
            bottomItem("calendar", "Calendario", 0)
            Spacer()
            bottomItem("list.bullet", "Piazzate", 1)
            Spacer()
            bottomItem("person.crop.circle", "Profilo", 2)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(26)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func bottomItem(_ icon: String, _ title: String, _ index: Int) -> some View {
        Button {
            vm.selectedTab = index
        } label: {
            VStack {
                Image(systemName: icon)
                Text(title).font(.caption)
            }
            .foregroundColor(vm.selectedTab == index ? .accentCyan : .white)
        }
    }

    // MARK: FLOATING BUTTON

    private var floatingButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ZStack(alignment: .topTrailing) {
                    Button {
                        vm.showSheet = true
                    } label: {
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
}

// MARK: - BET SHEET

struct BetSheet: View {

    @Binding var picks: [BetPick]
    @Binding var balance: Double
    let totalOdd: Double
    let onConfirm: (Double) -> Void

    @State private var stake: Double = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Capsule().fill(Color.gray).frame(width: 40, height: 5)

                ForEach(picks) { pick in
                    HStack {
                        Text("\(pick.match.home) - \(pick.match.away)")
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            picks.removeAll { $0.id == pick.id }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }

                Text("Quota totale \(totalOdd, specifier: "%.2f")")
                    .foregroundColor(.accentCyan)

                Text("Importo €\(stake, specifier: "%.2f")")
                    .foregroundColor(.white)

                Slider(value: $stake, in: 1...min(balance, 500), step: 1)
                    .accentColor(.accentCyan)

                Button("Conferma selezione") {
                    onConfirm(stake)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .foregroundColor(.black)
                .cornerRadius(16)

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - SLIP DETAIL

struct SlipDetailView: View {
    let slip: BetSlip

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Dettaglio scommessa")
                    .foregroundColor(.white)
                    .font(.headline)

                ForEach(slip.picks) { pick in
                    Text("\(pick.match.home) - \(pick.match.away) | \(pick.outcome.rawValue)")
                        .foregroundColor(.white)
                }

                Text("Quota: \(slip.totalOdd, specifier: "%.2f")")
                Text("Puntata: €\(slip.stake, specifier: "%.2f")")
                Text("Vincita potenziale: €\(slip.potentialWin, specifier: "%.2f")")

                Text("Probabilità implicita: \((slip.impliedProbability * 100), specifier: "%.1f")%")
                Text("Expected Value: €\(slip.expectedValue, specifier: "%.2f")")
                    .foregroundColor(slip.expectedValue >= 0 ? .green : .red)
            }
            .foregroundColor(.accentCyan)
            .padding()
        }
    }
}

// MARK: - PROFILE VIEW

struct ProfileView: View {
    @Binding var userName: String
    @Binding var balance: Double

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Text("Profilo")
                    .font(.title.bold())
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nome utente")
                        .foregroundColor(.gray)
                        .font(.subheadline)

                    TextField("Inserisci il tuo nome", text: $userName)
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Saldo attuale")
                        .foregroundColor(.gray)
                        .font(.subheadline)

                    Text("€\(balance, specifier: "%.2f")")
                        .foregroundColor(.accentCyan)
                        .font(.title2.bold())
                }

                Spacer()
            }
            .padding()
        }
    }
}