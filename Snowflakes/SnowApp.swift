//
//  SnowflakesApp.swift
//  Snowflakes
//
//  Created by Andrew Sereda on 22.10.2025.
//

import SwiftUI

@main
struct SnowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .frame(width: 560, height: 480)
        }
    }
}
