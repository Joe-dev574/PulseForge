//
//  WatchContentView.swift
//  PulseForge watchOS
//
//  Created by Joseph DeWeese on 3/1/26.
//

import SwiftUI

struct WatchContentView: View {
    
    @Environment(AuthenticationManager.self) private var authManager
    
    var body: some View {
        WatchWorkoutListView()
    }
}
