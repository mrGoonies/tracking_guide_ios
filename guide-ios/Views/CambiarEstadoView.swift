import PhotosUI
import SwiftUI

/// Registra una nueva etapa de la guía. Entregar o rechazar exige la foto de la
/// guía firmada y al menos una del cliente; el cambio no se puede deshacer.
struct CambiarEstadoView: View {
    let guia: GuiaDetalle
    let onActualizada: (GuiaDetalle) -> Void

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var estado: EstadoGuia
    @State private var observaciones = ""
    @State private var fotoGuia: FotoLocal?
    @State private var fotosCliente: [FotoLocal] = []
    @State private var enviando = false
    @State private var error: String?
    @State private var confirmando = false

    private let maximoFotosCliente = 10

    init(guia: GuiaDetalle, onActualizada: @escaping (GuiaDetalle) -> Void) {
        self.guia = guia
        self.onActualizada = onActualizada
        _estado = State(initialValue: guia.transiciones.first ?? .enRuta)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nuevo estado") {
                    Picker("Estado", selection: $estado) {
                        ForEach(guia.transiciones) { estado in
                            Text(estado.titulo).tag(estado)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if estado.requiereFotos {
                    seccionFotoGuia
                    seccionFotosCliente
                }

                Section("Observaciones") {
                    TextField("Opcional", text: $observaciones, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .disabled(enviando)
            .navigationTitle("Guía \(guia.numeroGuia)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .disabled(enviando)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if enviando {
                        ProgressView()
                    } else {
                        Button("Guardar") { confirmando = true }
                            .disabled(!esValido)
                    }
                }
            }
            .overlay {
                if enviando {
                    ProgressView(estado.requiereFotos ? "Subiendo fotos…" : "Guardando…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .interactiveDismissDisabled(enviando || hayCambios)
            .confirmationDialog(
                "¿Marcar la guía como \(estado.titulo)?",
                isPresented: $confirmando,
                titleVisibility: .visible
            ) {
                Button("Marcar como \(estado.titulo)") {
                    Task { await enviar() }
                }
            } message: {
                Text("Este cambio no se puede deshacer desde la app.")
            }
        }
    }

    private var seccionFotoGuia: some View {
        Section {
            if let fotoGuia {
                Image(uiImage: fotoGuia.imagen)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .frame(maxWidth: .infinity)
                Button("Quitar foto", systemImage: "trash", role: .destructive) {
                    self.fotoGuia = nil
                }
            } else {
                SelectorDeFotos(maximo: 1) { imagenes in
                    fotoGuia = imagenes.first.map { FotoLocal($0) }
                }
            }
        } header: {
            Text("Guía de despacho firmada")
        } footer: {
            Text("Una foto legible de la guía con la firma del cliente.")
        }
    }

    private var seccionFotosCliente: some View {
        Section {
            if !fotosCliente.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(fotosCliente) { foto in
                            MiniaturaLocal(imagen: foto.imagen) {
                                fotosCliente.removeAll { $0.id == foto.id }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            if fotosCliente.count < maximoFotosCliente {
                SelectorDeFotos(maximo: maximoFotosCliente - fotosCliente.count) { imagenes in
                    fotosCliente += imagenes.map { FotoLocal($0) }
                }
            }
        } header: {
            Text("Fotos de la recepción")
        } footer: {
            Text("Al menos una foto del cliente recibiendo los productos.")
        }
    }

    private var esValido: Bool {
        !estado.requiereFotos || (fotoGuia != nil && !fotosCliente.isEmpty)
    }

    private var hayCambios: Bool {
        fotoGuia != nil || !fotosCliente.isEmpty || !observaciones.isEmpty
    }

    private func enviar() async {
        enviando = true
        error = nil
        defer { enviando = false }

        var datosGuia: Data?
        var datosCliente: [Data] = []
        if estado.requiereFotos, let fotoGuia {
            datosGuia = await ImageProcessing.jpegParaSubir(fotoGuia.imagen)
            for foto in fotosCliente {
                if let datos = await ImageProcessing.jpegParaSubir(foto.imagen) {
                    datosCliente.append(datos)
                }
            }
            guard datosGuia != nil, datosCliente.count == fotosCliente.count else {
                error = "No se pudo procesar una de las fotos. Quítala y vuelve a tomarla."
                return
            }
        }

        do {
            let actualizada = try await session.api.cambiarEstado(
                guiaID: guia.id,
                a: estado,
                observaciones: observaciones.trimmingCharacters(in: .whitespacesAndNewlines),
                fotoGuia: datosGuia,
                fotosCliente: datosCliente
            )
            onActualizada(actualizada)
            dismiss()
        } catch {
            if error.esCancelacion { return }
            var mensaje = error.localizedDescription
            if case .red? = error as? APIError {
                // Si la conexión se cortó después de que el servidor guardó la etapa,
                // reintentar daría "transición no permitida".
                mensaje += " Si vuelve a fallar, revisa el historial de la guía: el cambio podría haberse guardado."
            }
            self.error = mensaje
        }
    }
}

/// Foto tomada o elegida, pendiente de subir.
private struct FotoLocal: Identifiable {
    let id = UUID()
    let imagen: UIImage

    init(_ imagen: UIImage) {
        self.imagen = imagen
    }
}

private struct MiniaturaLocal: View {
    let imagen: UIImage
    let onQuitar: () -> Void

    var body: some View {
        Image(uiImage: imagen)
            .resizable()
            .scaledToFill()
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                Button(action: onQuitar) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .padding(4)
                .accessibilityLabel("Quitar foto")
            }
    }
}

/// Filas "Tomar foto" (si hay cámara) y "Elegir de la galería" dentro de una sección de Form.
private struct SelectorDeFotos: View {
    /// Máximo de fotos a elegir de una vez en la galería.
    let maximo: Int
    let onSeleccion: ([UIImage]) -> Void

    @State private var mostrandoCamara = false
    @State private var seleccion: [PhotosPickerItem] = []

    var body: some View {
        if CameraPicker.disponible {
            Button("Tomar foto", systemImage: "camera") {
                mostrandoCamara = true
            }
            .fullScreenCover(isPresented: $mostrandoCamara) {
                CameraPicker { onSeleccion([$0]) }
                    .ignoresSafeArea()
            }
        }
        PhotosPicker(selection: $seleccion, maxSelectionCount: maximo, matching: .images) {
            Label("Elegir de la galería", systemImage: "photo.on.rectangle")
        }
        .onChange(of: seleccion) {
            Task { await cargarSeleccion() }
        }
    }

    private func cargarSeleccion() async {
        guard !seleccion.isEmpty else { return }
        var imagenes: [UIImage] = []
        for item in seleccion {
            if let datos = try? await item.loadTransferable(type: Data.self),
               let imagen = UIImage(data: datos) {
                imagenes.append(imagen)
            }
        }
        seleccion = []
        onSeleccion(imagenes)
    }
}
