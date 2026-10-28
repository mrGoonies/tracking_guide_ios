import Foundation

/// Cliente de la API REST de Tracking Guide. Añade el token de acceso a cada
/// petición y, ante un 401, renueva los tokens una vez y reintenta.
final class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokens: TokenStore
    private var renovacion: Task<Void, Error>?

    /// Se llama cuando el token de refresco ya no sirve y hay que volver al login.
    var onSesionExpirada: (() -> Void)?

    init(tokens: TokenStore, baseURL: URL = AppConfig.apiBaseURL, session: URLSession = .shared) {
        self.tokens = tokens
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Endpoints

    func login(usuario: String, contraseña: String) async throws -> LoginResponse {
        var request = crearRequest("auth/login/", metodo: "POST")
        try request.ponerJSON(["username": usuario, "password": contraseña])
        return try await enviar(request, autenticada: false)
    }

    func perfil() async throws -> Perfil {
        try await enviar(crearRequest("auth/me/"))
    }

    func misGuias(estado: EstadoGuia? = nil) async throws -> [GuiaResumen] {
        let query = estado.map { [URLQueryItem(name: "estado", value: $0.rawValue)] } ?? []
        return try await enviar(crearRequest("mis-guias/", query: query))
    }

    func guia(id: Int) async throws -> GuiaDetalle {
        try await enviar(crearRequest("guias/\(id)/"))
    }

    /// Registra una nueva etapa. Las fotos deben venir ya en JPEG.
    func cambiarEstado(
        guiaID: Int,
        a estado: EstadoGuia,
        observaciones: String?,
        fotoGuia: Data?,
        fotosCliente: [Data]
    ) async throws -> GuiaDetalle {
        var form = MultipartForm()
        form.agregarCampo("estado", estado.rawValue)
        if let observaciones, !observaciones.isEmpty {
            form.agregarCampo("observaciones", observaciones)
        }
        if let fotoGuia {
            form.agregarArchivo("foto_guia", nombreArchivo: "guia.jpg", mimeType: "image/jpeg", datos: fotoGuia)
        }
        for (indice, foto) in fotosCliente.enumerated() {
            form.agregarArchivo("fotos_cliente", nombreArchivo: "cliente-\(indice + 1).jpg", mimeType: "image/jpeg", datos: foto)
        }

        var request = crearRequest("guias/\(guiaID)/estado/", metodo: "POST")
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = form.datos()
        // Varias fotos por datos móviles pueden tardar bastante más que una consulta.
        request.timeoutInterval = 180
        return try await enviar(request)
    }

    // MARK: - Transporte

    private func crearRequest(_ ruta: String, metodo: String = "GET", query: [URLQueryItem] = []) -> URLRequest {
        var componentes = URLComponents(url: URL(string: ruta, relativeTo: baseURL)!, resolvingAgainstBaseURL: true)!
        if !query.isEmpty {
            componentes.queryItems = query
        }
        var request = URLRequest(url: componentes.url!)
        request.httpMethod = metodo
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func enviar<T: Decodable>(_ request: URLRequest, autenticada: Bool = true) async throws -> T {
        let datos = try await ejecutar(request, autenticada: autenticada)
        do {
            return try JSONDecoder.api.decode(T.self, from: datos)
        } catch {
            #if DEBUG
            print("No se pudo decodificar \(T.self) de \(request.url?.path ?? ""): \(error)")
            #endif
            throw APIError.respuestaInvalida
        }
    }

    private func ejecutar(_ request: URLRequest, autenticada: Bool, reintentar: Bool = true) async throws -> Data {
        var request = request
        if autenticada {
            if tokens.access == nil {
                try await renovarTokens()
            }
            guard let access = tokens.access else { throw sesionExpirada() }
            request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        }

        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIError.red(error)
        }
        guard let http = respuesta as? HTTPURLResponse else { throw APIError.respuestaInvalida }

        if http.statusCode == 401, autenticada {
            guard reintentar else { throw sesionExpirada() }
            try await renovarTokens()
            return try await ejecutar(request, autenticada: true, reintentar: false)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError(status: http.statusCode, data: datos)
        }
        return datos
    }

    /// Renueva los tokens. Si varias peticiones reciben 401 a la vez, comparten una sola
    /// renovación: el refresco rota, así que dos renovaciones en paralelo invalidarían una.
    private func renovarTokens() async throws {
        if let renovacion {
            return try await renovacion.value
        }
        let tarea = Task { try await solicitarRenovacion() }
        renovacion = tarea
        defer { renovacion = nil }
        try await tarea.value
    }

    private func solicitarRenovacion() async throws {
        guard let refresh = tokens.refresh else { throw sesionExpirada() }
        var request = crearRequest("auth/refresh/", metodo: "POST")
        try request.ponerJSON(["refresh": refresh])
        do {
            let par: TokenPair = try await enviar(request, autenticada: false)
            tokens.guardar(access: par.access, refresh: par.refresh)
        } catch APIError.red(let error) {
            // Sin conexión la sesión sigue siendo válida: se reintentará después.
            throw APIError.red(error)
        } catch {
            // Un refresh rechazado (401) o que falla en el servidor (5xx) deja la sesión sin salida;
            // el login sí permite obtener tokens nuevos.
            throw sesionExpirada()
        }
    }

    private func sesionExpirada() -> APIError {
        tokens.borrar()
        onSesionExpirada?()
        return .sesionExpirada
    }
}

private extension URLRequest {
    mutating func ponerJSON(_ cuerpo: [String: String]) throws {
        httpBody = try JSONEncoder().encode(cuerpo)
        setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
}
