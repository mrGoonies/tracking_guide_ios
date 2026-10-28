import Foundation
import Observation

/// Estado de la sesión del transportista. Decide si se muestra el login o las guías.
@Observable
final class SessionStore {
    enum Estado {
        /// Hay tokens guardados y se está validando la sesión al abrir la app.
        case cargando
        case sinSesion
        case activa(nombre: String?)
    }

    private(set) var estado: Estado
    /// Motivo por el que se cerró la sesión sin que el usuario lo pidiera; se muestra en el login.
    private(set) var aviso: String?

    let api: APIClient
    private let tokens: TokenStore

    init(tokens: TokenStore = TokenStore()) {
        self.tokens = tokens
        api = APIClient(tokens: tokens)
        estado = tokens.haySesion ? .cargando : .sinSesion
        api.onSesionExpirada = { [weak self] in
            self?.estado = .sinSesion
            self?.aviso = APIError.sesionExpirada.errorDescription
        }
    }

    var nombre: String? {
        if case .activa(let nombre) = estado { nombre } else { nil }
    }

    /// Valida la sesión guardada. Sin conexión se entra igual: las pantallas reintentarán.
    func restaurar() async {
        guard case .cargando = estado else { return }
        do {
            estado = .activa(nombre: try await api.perfil().nombre)
        } catch APIError.sesionExpirada {
            // `onSesionExpirada` ya cambió el estado.
        } catch APIError.sinPermiso {
            cerrarSesion(aviso: APIError.sinPermiso.errorDescription)
        } catch {
            estado = .activa(nombre: nil)
        }
    }

    func iniciarSesion(usuario: String, contraseña: String) async throws {
        let respuesta = try await api.login(usuario: usuario, contraseña: contraseña)
        guard respuesta.esTransportista else { throw APIError.sinPermiso }
        tokens.guardar(access: respuesta.access, refresh: respuesta.refresh)
        aviso = nil
        estado = .activa(nombre: respuesta.nombre)
    }

    func cerrarSesion(aviso: String? = nil) {
        tokens.borrar()
        self.aviso = aviso
        estado = .sinSesion
    }
}
