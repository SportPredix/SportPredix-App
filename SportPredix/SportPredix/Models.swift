import Foundation

struct Bookmaker: Decodable {
    let title: String
    let markets: [Market]
}

struct Market: Decodable {
    let outcomes: [Outcome]
}

struct Outcome: Decodable {
    let name: String
    let price: Double
}
