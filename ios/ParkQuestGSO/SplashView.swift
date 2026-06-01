//
//  SplashView.swift
//  ParkQuestGSO
//

import SwiftUI

struct SplashView: View {

    @State private var iconScale: CGFloat    = 0.3
    @State private var iconOpacity: Double   = 0
    @State private var titleOffset: CGFloat  = 20
    @State private var titleOpacity: Double  = 0
    @State private var taglineOpacity: Double = 0
    @State private var glowRadius: CGFloat   = 0

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Theme.darkGreen, Theme.primaryGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Radial glow behind icon
            RadialGradient(
                colors: [.white.opacity(0.18), .clear],
                center: .center,
                startRadius: 0,
                endRadius: glowRadius
            )
            .ignoresSafeArea()
            .animation(.easeOut(duration: 1.0).delay(0.2), value: glowRadius)

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 130, height: 130)
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 108, height: 108)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 52, weight: .black))
                        .foregroundStyle(.white)
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

                Spacer().frame(height: 32)

                // App name
                Text("ParkQuest")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(1)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)

                Spacer().frame(height: 8)

                // City tagline
                Text("GREENSBORO, NC")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.65))
                    .opacity(taglineOpacity)

                Spacer()

                // Bottom wordmark
                Text("Explore · Discover · Earn")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.bottom, 48)
                    .opacity(taglineOpacity)
            }
        }
        .onAppear { animate() }
    }

    private func animate() {
        // Icon springs in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            iconScale   = 1
            iconOpacity = 1
        }
        // Glow expands
        withAnimation(.easeOut(duration: 1.0).delay(0.1)) {
            glowRadius = 320
        }
        // Title slides up
        withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
            titleOffset  = 0
            titleOpacity = 1
        }
        // Taglines fade in
        withAnimation(.easeOut(duration: 0.5).delay(0.45)) {
            taglineOpacity = 1
        }
    }
}

#Preview {
    SplashView()
}
