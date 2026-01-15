//
//  ContentView.swift
//  SportPredix
//
//  Versione unica con MVVM, EV, persistenza schedine + PROFILO + CALENDARIO DINAMICO PERSISTENTE
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

    var impliedProbability: Double { 1 / totalOdd }
    var expectedValue: Double { potentialWin * impliedProbability - stake }
}

// MARK: - VIEW MODEL

final class BettingViewModel: ObservableObject {

    @Published var selectedTab = 0
    @Published var selectedDayIndex = 1   // 0 = ieri, 1 = oggi, 2 = domani

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

    // Partite salvate per ogni giorno
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
    // MARK: - MATCH GENERATION (PERSISTENT)

    func generateMatchesForDate(_ date: Date) -> [Match] {
        var result: [Match] = []

        for _ in 0..<12 {
            let home = teams.randomElement()!
            var away = teams.randomElement()!
            while away == home { away = teams.randomElement()! }

            let hour = Int.random(in: 12...22)
            let minute = ["00","15","30","45"].randomElement()!
            let time = "\(hour):\(minute)"

            let odds = [
                Double.random(in: 1.20...2.50),
                Double.random(in: 2.80...4.50),
                Double.random(in: 2.50...7.00)
            ]

            result.append(Match(id: UUID(), home: home, away: away, time: time, odds: odds))
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

    func matchesForSelectedDay() -> [Match] {
        let date = dateForIndex(selectedDayIndex)
        let key = keyForDate(date)

        if let existing = dailyMatches[key] {
            return existing
        }

        let newMatches = generateMatchesForDate(date)
        dailyMatches[key] = newMatches
        saveMatches()
        return newMatches
    }

    // MARK: - SAVE / LOAD MATCHES

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

    // MARK: - SCOMMESSE

    var totalOdd: Double { currentPicks.map { $0.odd }.reduce(1, *) }

    func addPick(match: Match, outcome: MatchOutcome, odd: Double) {
        guard !currentPicks.contains(where: { $0.match.id == match.id }) else { return }
        currentPicks.append(BetPick(id: UUID(), match: match, outcome: outcome, odd: odd))
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
            date: Date()
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
                    calendarBar
                    matchList
                } else if vm.selectedTab == 1 {
                    placedBets
                } else {
                    ProfileView(userName: $vm.userName, balance: $vm.balance)
                }

                bottomBar
            }

            if !vm.currentPicks.isEmpty {
                floatingButton
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

    // MARK: HEADER

    private var header: some View {
        HStack {
            Text(vm.selectedTab == 0 ? "Calendario" :
                 vm.selectedTab == 1 ? "Piazzate" : "Profilo")
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
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: MATCH LIST

    private var matchList: some View {
        let matches = vm.matchesForSelectedDay()
        let isYesterday = vm.selectedDayIndex == 0

        return ScrollView {
            VStack(spacing: 16) {
                ForEach(matches) { match in
                    matchCard(match, disabled: isYesterday)
                }
            }
            .padding()
        }
    }

    private func matchCard(_ match: Match, disabled: Bool) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(match.home).font(.headline)
                Spacer()
                Text(match.time)
                    .font(.subheadline.bold())
                    .foregroundColor(.accentCyan)
                Spacer()
                Text(match.away).font(.headline)
            }
            .foregroundColor(.white)

            HStack(spacing: 10) {
                oddButton("1", match, .home, match.odds[0], disabled)
                oddButton("X", match, .draw, match.odds[1], disabled)
                oddButton("2", match, .away, match.odds[2], disabled)
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
        private func oddButton(_ label: String, _ match: Match, _ outcome: MatchOutcome, _ odd: Double, _ disabled: Bool) -> some View {

        Button {
            if !disabled {
                vm.addPick(match: match, outcome: outcome, odd: odd)
            }
        } label: {
            VStack {
                Text(label).bold()
                Text(String(format: "%.2f", odd)).font(.caption)
            }
            .foregroundColor(disabled ? .gray : .black)
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(disabled ? Color.white.opacity(0.15) : Color.accentCyan)
            .cornerRadius(14)
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
        Button { vm.selectedTab = index } label: {
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
}

// MARK: - BET SHEET (VERSIONE MIGLIORATA)

struct BetSheet: View {

    @Binding var picks: [BetPick]
    @Binding var balance: Double
    let totalOdd: Double
    let onConfirm: (Double) -> Void

    @State private var stake: Double = 1

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

                VStack(spacing: 8) {
                    HStack {
                        Text("Importo:")
                        Spacer()
                        Text("€\(stake, specifier: "%.2f")")
                    }
                    .foregroundColor(.white)

                    Slider(value: $stake, in: 1...min(balance, 500), step: 1)
                        .accentColor(.accentCyan)
                }

                Button(action: {
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

            VStack(alignment: .leading, spacing: 24) {

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