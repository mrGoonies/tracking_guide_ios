//
//  guide_iosApp.swift
//  guide-ios
//
//  Created by Gabo on 12-08-26.
//

import SwiftUI

@main
struct guide_iosApp: App {
    @State private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
        }
    }
}
