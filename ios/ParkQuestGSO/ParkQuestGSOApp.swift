//
//  ParkQuestGSOApp.swift
//  ParkQuestGSO
//

import SwiftUI

@main
struct ParkQuestGSOApp: App {
    @State private var game            = GameState()
    @State private var locationManager = LocationManager()
    @State private var userSettings    = UserSettings()
    @State private var showSplash      = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app (rendered beneath splash so it's ready instantly)
                Group {
                    if userSettings.hasCompletedOnboarding {
                        RootView()
                    } else {
                        OnboardingView()
                    }
                }
                .environment(game)
                .environment(locationManager)
                .environment(userSettings)
                .preferredColorScheme(.light)
                .tint(Theme.primaryGreen)
                .task {
                    if userSettings.hasCompletedOnboarding {
                        await game.loadFromCloud(userID: userSettings.userID)
                    }
                }

                // Splash sits on top and fades away
                if showSplash {
                    SplashView()
                        .transition(
                            .asymmetric(
                                insertion: .identity,
                                removal: .opacity.combined(with: .scale(scale: 1.05))
                            )
                        )
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showSplash)
            .task {
                try? await Task.sleep(for: .seconds(2.2))
                showSplash = false
            }
        }
    }
}
