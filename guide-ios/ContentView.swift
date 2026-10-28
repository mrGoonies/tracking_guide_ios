//
//  ContentView.swift
//  guide-ios
//
//  Created by Gabo on 12-08-26.
//

import SwiftUI

/// Raíz de la app: login o lista de guías según el estado de la sesión.
struct ContentView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        switch session.estado {
        case .cargando:
            ProgressView()
                .task { await session.restaurar() }
        case .sinSesion:
            LoginView()
        case .activa:
            GuiasListView()
        }
    }
}

#Preview {
    ContentView()
        .environment(SessionStore())
}
