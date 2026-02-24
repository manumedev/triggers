import Foundation
import WeatherKit
import CoreLocation
import OSLog

private let logger = Logger(subsystem: "com.triggers.app", category: "WeatherService")

@MainActor
final class WeatherService: ObservableObject {

    static let shared = WeatherService()

    private let service = WeatherService_()
    @Published var currentWeather: CurrentWeather?

    /// Fires after a weather fetch with the latest CurrentWeather
    var onWeatherUpdated: ((CurrentWeather) -> Void)?

    private init() {}

    // MARK: - Fetch

    func fetchWeather(for location: CLLocation) async {
        do {
            let weather = try await service.weather(for: location)
            currentWeather = weather.currentWeather
            logger.info("Weather fetched: \(weather.currentWeather.condition.description), \(weather.currentWeather.temperature)")
            onWeatherUpdated?(weather.currentWeather)
        } catch {
            logger.error("WeatherKit fetch failed: \(error)")
        }
    }

    // MARK: - Condition helpers

    var isRaining: Bool {
        guard let w = currentWeather else { return false }
        switch w.condition {
        case .rain, .heavyRain, .freezingRain,
             .sleet, .freezingDrizzle, .drizzle,
             .blizzard, .blowingSnow,
             .snow, .heavySnow, .flurries:
            return true
        default:
            return false
        }
    }

    var temperatureCelsius: Double? {
        currentWeather?.temperature.converted(to: .celsius).value
    }
}

// Alias to avoid name collision with this class
private typealias WeatherService_ = WeatherKit.WeatherService
