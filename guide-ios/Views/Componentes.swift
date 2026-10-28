import SwiftUI

struct EstadoBadge: View {
    let estado: String
    let titulo: String

    var body: some View {
        Text(titulo)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var color: Color {
        switch EstadoGuia(rawValue: estado) {
        case .emitida: .gray
        case .asignada: .blue
        case .enRuta: .orange
        case .entregada: .green
        case .rechazada: .red
        case .cerrada, nil: .secondary
        }
    }
}

/// Miniatura de una foto remota (Cloudinary).
struct MiniaturaRemota: View {
    let url: URL
    var lado: CGFloat = 72

    var body: some View {
        AsyncImage(url: url) { fase in
            switch fase {
            case .success(let imagen):
                imagen.resizable().scaledToFill()
            case .failure:
                Image(systemName: "photo").foregroundStyle(.secondary)
            default:
                ProgressView()
            }
        }
        .frame(width: lado, height: lado)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Foto a pantalla completa.
struct FotoViewer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AsyncImage(url: url) { fase in
                switch fase {
                case .success(let imagen):
                    imagen.resizable().scaledToFit()
                case .failure:
                    ContentUnavailableView("No se pudo cargar la foto", systemImage: "photo")
                default:
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: url)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

/// Envoltorio para presentar una URL con `.fullScreenCover(item:)`.
struct FotoSeleccionada: Identifiable {
    let url: URL
    var id: URL { url }
}
