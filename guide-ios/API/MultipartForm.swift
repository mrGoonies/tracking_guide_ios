import Foundation

/// Cuerpo `multipart/form-data` para `POST guias/{id}/estado/`.
struct MultipartForm {
    private let boundary = "Boundary-\(UUID().uuidString)"
    private var cuerpo = Data()

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    mutating func agregarCampo(_ nombre: String, _ valor: String) {
        agregar("--\(boundary)\r\n")
        agregar("Content-Disposition: form-data; name=\"\(nombre)\"\r\n\r\n")
        agregar("\(valor)\r\n")
    }

    mutating func agregarArchivo(_ nombre: String, nombreArchivo: String, mimeType: String, datos: Data) {
        agregar("--\(boundary)\r\n")
        agregar("Content-Disposition: form-data; name=\"\(nombre)\"; filename=\"\(nombreArchivo)\"\r\n")
        agregar("Content-Type: \(mimeType)\r\n\r\n")
        cuerpo.append(datos)
        agregar("\r\n")
    }

    func datos() -> Data {
        cuerpo + Data("--\(boundary)--\r\n".utf8)
    }

    private mutating func agregar(_ texto: String) {
        cuerpo.append(Data(texto.utf8))
    }
}
