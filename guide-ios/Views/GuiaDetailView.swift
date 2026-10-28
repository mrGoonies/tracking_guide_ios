import SwiftUI

struct GuiaDetailView: View {
    let guiaID: Int
    /// Se llama tras registrar un cambio de estado, para que la lista se actualice.
    var onCambio: () -> Void = {}

    @Environment(SessionStore.self) private var session
    @State private var guia: GuiaDetalle?
    @State private var error: String?
    @State private var cambiandoEstado = false
    @State private var fotoAmpliada: FotoSeleccionada?

    var body: some View {
        Group {
            if let guia {
                detalle(guia)
            } else if let error {
                ContentUnavailableView {
                    Label("No se pudo cargar la guía", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Reintentar") { Task { await cargar() } }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(guia.map { "Guía \($0.numeroGuia)" } ?? "Guía")
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
        .refreshable { await cargar() }
        .sheet(isPresented: $cambiandoEstado) {
            if let guia {
                CambiarEstadoView(guia: guia) { actualizada in
                    self.guia = actualizada
                    onCambio()
                }
            }
        }
        .fullScreenCover(item: $fotoAmpliada) { foto in
            FotoViewer(url: foto.url)
        }
    }

    private func detalle(_ guia: GuiaDetalle) -> some View {
        List {
            Section {
                HStack {
                    EstadoBadge(estado: guia.estado, titulo: guia.estadoDisplay)
                    Spacer()
                    if let fecha = guia.fechaDespacho {
                        Label(fecha.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if !guia.transiciones.isEmpty {
                    Button {
                        cambiandoEstado = true
                    } label: {
                        Label("Actualizar estado", systemImage: "arrow.right.circle.fill")
                            .bold()
                    }
                }
            }

            Section("Cliente") {
                LabeledContent("Razón social", value: guia.cliente.nombre)
                LabeledContent("RUT", value: guia.cliente.rut)
            }

            Section("Entrega") {
                Label(guia.direccionEntrega, systemImage: "mappin.and.ellipse")
                if let mapLink = guia.mapLink {
                    Link(destination: mapLink) {
                        Label("Abrir en Mapas", systemImage: "map")
                    }
                }
                if let notas = guia.notas, !notas.isEmpty {
                    Label(notas, systemImage: "note.text")
                }
            }

            Section("Venta") {
                if let nv = guia.nv {
                    LabeledContent("Nota de venta", value: nv)
                }
                if let vendedor = guia.vendedorDisplay {
                    LabeledContent("Vendedor", value: vendedor)
                }
                if let envio = guia.fechaEnvio {
                    LabeledContent("Fecha de envío", value: envio.formatted(date: .abbreviated, time: .omitted))
                }
            }

            Section("Historial") {
                if guia.etapas.isEmpty {
                    Text("Sin movimientos todavía.")
                        .foregroundStyle(.secondary)
                }
                ForEach(guia.etapas) { etapa in
                    EtapaRow(etapa: etapa) { url in
                        fotoAmpliada = FotoSeleccionada(url: url)
                    }
                }
            }
        }
    }

    private func cargar() async {
        do {
            guia = try await session.api.guia(id: guiaID)
            error = nil
        } catch {
            if error.esCancelacion { return }
            self.error = error.localizedDescription
        }
    }
}

private struct EtapaRow: View {
    let etapa: Etapa
    let onFoto: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(EstadoGuia(rawValue: etapa.estado)?.titulo ?? etapa.estado)
                    .font(.headline)
                Spacer()
                Text(etapa.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let observaciones = etapa.observaciones, !observaciones.isEmpty {
                Text(observaciones)
                    .font(.subheadline)
            }
            if !etapa.urlsFotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(etapa.urlsFotos, id: \.self) { url in
                            Button {
                                onFoto(url)
                            } label: {
                                MiniaturaRemota(url: url)
                            }
                            // Sin esto, en una fila de List un toque activa todos los botones.
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
