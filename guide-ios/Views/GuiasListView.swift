import SwiftUI

struct GuiasListView: View {
    @Environment(SessionStore.self) private var session
    @State private var guias: [GuiaResumen] = []
    @State private var cargada = false
    @State private var error: String?
    @State private var filtro: EstadoGuia?
    @State private var busqueda = ""
    @State private var confirmandoSalida = false

    var body: some View {
        NavigationStack {
            List {
                if let error, !guias.isEmpty {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                ForEach(filtradas) { guia in
                    NavigationLink(value: guia.id) {
                        GuiaRow(guia: guia)
                    }
                }
            }
            .overlay { estadoVacio }
            .navigationTitle("Mis guías")
            .navigationDestination(for: Int.self) { id in
                GuiaDetailView(guiaID: id) {
                    Task { await cargar() }
                }
            }
            .searchable(text: $busqueda, prompt: "N° de guía, cliente o dirección")
            .refreshable { await cargar() }
            .task(id: filtro) { await cargar() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { menuCuenta }
                ToolbarItem(placement: .topBarTrailing) { menuFiltro }
            }
            .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmandoSalida, titleVisibility: .visible) {
                Button("Cerrar sesión", role: .destructive) { session.cerrarSesion() }
            }
        }
    }

    private var filtradas: [GuiaResumen] {
        let texto = busqueda.trimmingCharacters(in: .whitespaces)
        guard !texto.isEmpty else { return guias }
        return guias.filter { guia in
            [guia.numeroGuia, guia.clienteNombre, guia.direccionEntrega, guia.nv ?? ""]
                .contains { $0.localizedStandardContains(texto) }
        }
    }

    @ViewBuilder
    private var estadoVacio: some View {
        if !cargada {
            ProgressView("Cargando guías…")
        } else if let error, guias.isEmpty {
            ContentUnavailableView {
                Label("No se pudieron cargar las guías", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("Reintentar") { Task { await cargar() } }
            }
        } else if filtradas.isEmpty {
            if !busqueda.isEmpty {
                ContentUnavailableView.search(text: busqueda)
            } else if let filtro {
                ContentUnavailableView("Sin guías", systemImage: "shippingbox",
                                       description: Text("No tienes guías en estado \(filtro.titulo)."))
            } else {
                ContentUnavailableView("Sin guías", systemImage: "shippingbox",
                                       description: Text("No tienes guías asignadas."))
            }
        }
    }

    private var menuCuenta: some View {
        Menu {
            Section(session.nombre ?? "") {
                Button("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    confirmandoSalida = true
                }
            }
        } label: {
            Label("Cuenta", systemImage: "person.crop.circle")
        }
    }

    private var menuFiltro: some View {
        Menu {
            Picker("Estado", selection: $filtro) {
                Text("Todas").tag(EstadoGuia?.none)
                ForEach(EstadoGuia.allCases) { estado in
                    Text(estado.titulo).tag(Optional(estado))
                }
            }
        } label: {
            Label("Filtrar", systemImage: filtro == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
    }

    private func cargar() async {
        do {
            guias = try await session.api.misGuias(estado: filtro)
            error = nil
        } catch {
            if error.esCancelacion { return }
            self.error = error.localizedDescription
        }
        cargada = true
    }
}

private struct GuiaRow: View {
    let guia: GuiaResumen

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Guía \(guia.numeroGuia)")
                    .font(.headline)
                Spacer()
                EstadoBadge(estado: guia.estado, titulo: guia.estadoDisplay)
            }
            Text(guia.clienteNombre)
                .font(.subheadline)
            Label(guia.direccionEntrega, systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let fecha = guia.fechaDespacho {
                Label(fecha.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
