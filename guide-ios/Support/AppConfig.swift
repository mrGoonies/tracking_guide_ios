import Foundation

enum AppConfig {
    /// URL base de la API de Tracking Guide (servicio `tracking-guide` en Render).
    /// Debe terminar en `/`: las rutas de DRF se resuelven relativas a ella.
    static let apiBaseURL = URL(string: "https://tracking-guide.onrender.com/api/v1/")!
}
