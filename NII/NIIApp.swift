//
//  NIIApp.swift
//  NII App — НИИ Инклюзивного Инжиниринга
//

import SwiftUI

@main
struct NIIApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(state.pro)
                .tint(.niiNavy)
        }
    }
}
