//
//  ContentView.swift
//  ParkQuestGSO
//
//  Kept as a thin shim; the real entry is RootView.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
        .environment(GameState())
}
