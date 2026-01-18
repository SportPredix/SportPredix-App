
import Foundation

final class OddsService {
    static let shared = OddsService()
    private init() {}

    private let apiKey = "0ac9385827d0715595c889fc0e341f57"

    func fetchSerieAOdds(completion: @escaping (Result<[Match], Error>) -> Void) {
        let urlString =
        "https://api.the-odds-api.com/v4/sports/soccer_italy_serie_a/odds?regions=eu&markets=h2h&apiKey=\(apiKey)"

        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let data = data else { return }

            do {
                let matches = try JSONDecoder().decode([Match].self, from: data)
                DispatchQueue.main.async {
                    completion(.success(matches))
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
}
