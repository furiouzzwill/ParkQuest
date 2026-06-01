//
//  RootView.swift
//  ParkQuestGSO
//

import SwiftUI

enum Tab: Hashable {
    case home, quests, profile
}

struct RootView: View {
    @State private var selectedTab: Tab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(Tab.home)

            QuestListView()
                .tabItem {
                    Label("Quests", systemImage: "list.bullet.clipboard.fill")
                }
                .tag(Tab.quests)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(Tab.profile)
        }
        .tint(Theme.primaryGreen)
    }
}

#Preview {
    RootView()
        .environment(GameState())
}
