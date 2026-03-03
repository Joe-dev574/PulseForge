//
//  PulseForgeWatchApp.swift
//  PulseForge watchOS
//
//  Created by Joseph DeWeese on 3/1/26.
//

import SwiftUI
import SwiftData

@main
struct PulseForgeWatchApp: App {
    
    let container = PulseForgeContainer.container
    
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(HealthKitManager.shared)
                .environment(PurchaseManager.shared)
                .environment(AuthenticationManager.shared)
                .environment(ErrorManager.shared)
        }
        .modelContainer(container)
    }
}
