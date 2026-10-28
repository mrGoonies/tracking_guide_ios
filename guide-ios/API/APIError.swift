import Foundation

enum APIError: LocalizedError {
    case red(URLError)
    /// 401 en login o refresh: credenciales o token de refresco no válidos.
    case noAutorizado
    /// El token de refresco ya no sirve; la sesión se cerró y hay que volver al login.
    case sesionExpirada
    /// 403: el usuario no tiene el rol Transportista.
    case sinPermiso
    /// 404: la guía no existe o no está asignada al usuario.
    case noEncontrado
    /// 400: transición no permitida, estado no válido o faltan fotos.
    case rechazado(String?)
    case servidor(Int, String?)
    case respuestaInvalida

    init(status: Int, data: Data) {
        let mensaje = (try? JSONDecoder().decode(CuerpoError.self, from: data))?.mensaje
        switch status {
        case 400: self = .rechazado(mensaje)
        case 401: self = .noAutorizado
        case 403: self = .sinPermiso
        case 404: self = .noEncontrado
        default: self = .servidor(status, mensaje)
        }
    }

    var errorDescription: String? {
        switch self {
        case .red(let error):
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                "Sin conexión a internet. Revisa tu señal e inténtalo de nuevo."
            case .timedOut:
                "El servidor tardó demasiado en responder. Inténtalo de nuevo."
            default:
                "No se pudo conectar con el servidor."
            }
        case .noAutorizado:
            "Usuario o contraseña incorrectos."
        case .sesionExpirada:
            "Tu sesión expiró. Vuelve a iniciar sesión."
        case .sinPermiso:
            "Tu cuenta no tiene acceso a la app. Pide a un coordinador que te asigne el rol Transportista."
        case .noEncontrado:
            "La guía no existe o ya no está asignada a ti."
        case .rechazado(let mensaje):
            mensaje ?? "El servidor rechazó la solicitud."
        case .servidor(let status, let mensaje):
            mensaje.map { "Error del servidor: \($0)" } ?? "Error del servidor (\(status)). Inténtalo de nuevo más tarde."
        case .respuestaInvalida:
            "Respuesta inesperada del servidor."
        }
    }
}

/// DRF responde `{"detail": "..."}` en errores de autenticación y permisos,
/// y la vista de cambio de estado `{"error": "..."}` en errores de validación.
nonisolated private struct CuerpoError: Decodable {
    let detail: String?
    let error: String?

    var mensaje: String? { error ?? detail }
}

extension Error {
    /// La tarea se canceló (la vista desapareció o se repitió la carga): no hay que mostrar error.
    var esCancelacion: Bool {
        if self is CancellationError { return true }
        if case .red(let error)? = self as? APIError, error.code == .cancelled { return true }
        return false
    }
}
