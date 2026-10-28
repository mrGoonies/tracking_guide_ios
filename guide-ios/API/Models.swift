import Foundation

/// Estados de una guía de despacho. La API los envía como texto; los campos
/// `estado` de los modelos se guardan como `String` para no fallar si el
/// backend agrega uno nuevo.
enum EstadoGuia: String, CaseIterable, Identifiable {
    case emitida
    case asignada
    case enRuta = "en_ruta"
    case entregada
    case rechazada
    case cerrada

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .emitida: "Emitida"
        case .asignada: "Asignada"
        case .enRuta: "En Ruta"
        case .entregada: "Entregada"
        case .rechazada: "Rechazada"
        case .cerrada: "Cerrada"
        }
    }

    /// Entregar o rechazar exige la foto de la guía firmada y al menos una foto del cliente.
    var requiereFotos: Bool { self == .entregada || self == .rechazada }
}

struct LoginResponse: Decodable {
    let refresh: String
    let access: String
    let username: String
    let nombre: String
    let esTransportista: Bool
}

struct TokenPair: Decodable {
    let access: String
    let refresh: String
}

struct Perfil: Decodable {
    let id: Int
    let username: String
    let nombre: String
    let email: String?
}

/// Elemento de `GET mis-guias/`.
struct GuiaResumen: Decodable, Identifiable {
    let id: Int
    let numeroGuia: String
    let nv: String?
    let estado: String
    let estadoDisplay: String
    let clienteNombre: String
    let clienteRut: String
    let direccionEntrega: String
    let mapLink: URL?
    let fechaDespacho: Date?
    let fechaCreacion: Date
}

/// Respuesta de `GET guias/{id}/` y de `POST guias/{id}/estado/`.
struct GuiaDetalle: Decodable, Identifiable {
    let id: Int
    let numeroGuia: String
    let nv: String?
    let nvFechaCreacion: Date?
    let estado: String
    let estadoDisplay: String
    let proximosEstados: [String]
    let cliente: Cliente
    let direccionEntrega: String
    let mapLink: URL?
    let vendedorDisplay: String?
    let fechaEnvio: Date?
    let fechaDespacho: Date?
    let notas: String?
    let fechaCreacion: Date
    let fechaActualizacion: Date
    /// De la más reciente a la más antigua.
    let etapas: [Etapa]

    /// Transiciones que el transportista puede hacer ahora, en el orden que da el servidor.
    var transiciones: [EstadoGuia] { proximosEstados.compactMap(EstadoGuia.init(rawValue:)) }
}

struct Cliente: Decodable {
    let rut: String
    let nombre: String
    let direccionFacturacion: String?
    let direccionEntregaPreferida: String?
}

struct Etapa: Decodable, Identifiable {
    let id: Int
    let estado: String
    let timestamp: Date
    let observaciones: String?
    let fotos: [Foto]
    /// Foto de registros anteriores al modelo `Foto`.
    let fotoLegacy: URL?

    /// Fotos en el orden en que se muestran: guía firmada, cliente, generales y la antigua al final.
    var urlsFotos: [URL] {
        let ordenadas = fotos.sorted { ($0.prioridad, $0.orden) < ($1.prioridad, $1.orden) }
        return ordenadas.map(\.url) + (fotoLegacy.map { [$0] } ?? [])
    }
}

struct Foto: Decodable, Identifiable {
    let id: Int
    let url: URL
    let orden: Int
    /// `guia`, `cliente` o `general`.
    let categoria: String

    fileprivate var prioridad: Int {
        switch categoria {
        case "guia": 0
        case "cliente": 1
        default: 2
        }
    }
}

extension JSONDecoder {
    /// Decodificador para las respuestas de la API: claves en snake_case y fechas ISO 8601,
    /// con hora y zona (`2026-10-27T15:02:11-03:00`, con o sin fracción) o solo fecha (`2026-10-28`).
    static let api: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let texto = try container.decode(String.self)

            let conHora = ISO8601DateFormatter()
            conHora.formatOptions = [.withInternetDateTime]
            // DRF puede enviar microsegundos, que ISO8601DateFormatter no acepta.
            if let fecha = conHora.date(from: texto.replacing(#/\.\d+/#, with: "")) {
                return fecha
            }

            // Una fecha sin hora es un día del calendario: medianoche en la zona del dispositivo,
            // para que al mostrarla no se corra al día anterior.
            let soloFecha = ISO8601DateFormatter()
            soloFecha.formatOptions = [.withFullDate]
            soloFecha.timeZone = .current
            if let fecha = soloFecha.date(from: texto) {
                return fecha
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Fecha no válida: \(texto)")
        }
        return decoder
    }()
}
