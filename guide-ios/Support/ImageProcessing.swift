import UIKit

enum ImageProcessing {
    /// Reduce la foto a un máximo de `ladoMaximo` px por lado y la codifica en JPEG,
    /// fuera del hilo principal. 2048 px mantiene legible la guía firmada.
    @concurrent
    nonisolated static func jpegParaSubir(_ imagen: UIImage, ladoMaximo: CGFloat = 2048, calidad: CGFloat = 0.75) async -> Data? {
        let lado = max(imagen.size.width, imagen.size.height)
        guard lado > 0 else { return nil }
        let escala = min(1, ladoMaximo / lado)
        let tamaño = CGSize(width: (imagen.size.width * escala).rounded(), height: (imagen.size.height * escala).rounded())

        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        // `draw(in:)` aplica la orientación de la foto, así que el JPEG sale derecho.
        let redimensionada = UIGraphicsImageRenderer(size: tamaño, format: formato).image { _ in
            imagen.draw(in: CGRect(origin: .zero, size: tamaño))
        }
        return redimensionada.jpegData(compressionQuality: calidad)
    }
}
