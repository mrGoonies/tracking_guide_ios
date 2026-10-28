import SwiftUI

struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var usuario = ""
    @State private var contraseña = ""
    @State private var enviando = false
    @State private var error: String?
    @FocusState private var campo: Campo?

    private enum Campo {
        case usuario, contraseña
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Usuario", text: $usuario)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($campo, equals: .usuario)
                        .submitLabel(.next)
                        .onSubmit { campo = .contraseña }
                    SecureField("Contraseña", text: $contraseña)
                        .textContentType(.password)
                        .focused($campo, equals: .contraseña)
                        .submitLabel(.go)
                        .onSubmit { Task { await ingresar() } }
                } footer: {
                    Text("Las cuentas las crea un administrador de Irritec.")
                }

                if let mensaje = error ?? session.aviso {
                    Section {
                        Label(mensaje, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await ingresar() }
                    } label: {
                        HStack {
                            Spacer()
                            if enviando {
                                ProgressView()
                            } else {
                                Text("Ingresar").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(!puedeEnviar)
                }
            }
            .navigationTitle("Irritec Guias")
        }
    }

    private var usuarioLimpio: String {
        usuario.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var puedeEnviar: Bool {
        !usuarioLimpio.isEmpty && !contraseña.isEmpty && !enviando
    }

    private func ingresar() async {
        guard puedeEnviar else { return }
        enviando = true
        error = nil
        defer { enviando = false }
        do {
            try await session.iniciarSesion(usuario: usuarioLimpio, contraseña: contraseña)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    LoginView()
        .environment(SessionStore())
}
