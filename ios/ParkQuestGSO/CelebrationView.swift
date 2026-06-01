//
//  CelebrationView.swift
//  ParkQuestGSO
//

import SwiftUI

struct CelebrationView: View {
    let quest: Quest
    let pointsTotal: Int
    let foundCount: Int
    let totalCount: Int
    let badgeEarned: Bool
    let badgeName: String
    let badgeSymbol: String
    let onDismiss: () -> Void

    @State private var animatedPoints: Int = 0
    @State private var iconScale: CGFloat = 0.4
    @State private var iconOpacity: Double = 0
    @State private var headlineOffset: CGFloat = -16
    @State private var headlineOpacity: Double = 0
    @State private var confettiTick: Int = 0
    @State private var showBadge: Bool = false

    var body: some View {
        ZStack {
            background
            ConfettiView(trigger: confettiTick)
                .ignoresSafeArea()

            if showBadge {
                BadgeEarnedOverlay(
                    badgeName: badgeName,
                    badgeSymbol: badgeSymbol,
                    sessionPoints: pointsTotal,
                    onContinue: onDismiss
                )
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            } else {
                content
            }
        }
        .onAppear {
            confettiTick += 1
            Haptics.success()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
                iconScale = 1
                iconOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.05)) {
                headlineOffset = 0
                headlineOpacity = 1
            }
            // Animate points counter
            let target = quest.points
            let stepCount = 24
            for i in 0...stepCount {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.025) {
                    animatedPoints = Int(Double(target) * Double(i) / Double(stepCount))
                }
            }

            if badgeEarned {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showBadge = true
                    }
                    confettiTick += 1
                    Haptics.success()
                }
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.darkGreen, Theme.primaryGreen, Theme.mossGreen],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            // Subtle radial glow
            RadialGradient(
                colors: [.white.opacity(0.18), .clear],
                center: .center, startRadius: 5, endRadius: 280
            )
            .ignoresSafeArea()
        }
    }

    private var content: some View {
        VStack(spacing: 26) {
            Spacer()

            VStack(spacing: 8) {
                Text("DISCOVERED!")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .offset(y: headlineOffset)
                    .opacity(headlineOpacity)

                Text(quest.kind.label.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(Theme.amberSoft)
                    .opacity(headlineOpacity)
            }

            iconCard
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            VStack(spacing: 6) {
                Text("+\(animatedPoints)")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.amberSoft)
                    .shadow(color: Theme.amber.opacity(0.8), radius: 16)
                    .contentTransition(.numericText())
                Text("POINTS EARNED")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            progressStrip

            Button(action: {
                Haptics.medium()
                onDismiss()
            }) {
                HStack {
                    Text("Keep Exploring")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.darkGreen)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(.white, in: .rect(cornerRadius: 18))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
    }

    private var iconCard: some View {
        VStack(spacing: 8) {
            Image(systemName: quest.kind.symbol)
                .font(.system(size: 56, weight: .black))
                .foregroundStyle(Theme.primaryGreen)
                .padding(28)
                .background(
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
                )
                .overlay {
                    Circle().strokeBorder(Theme.amber, lineWidth: 4)
                }
            Text(quest.name)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var progressStrip: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(foundCount) of \(totalCount) quests found")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                if foundCount < totalCount {
                    Text("\(totalCount - foundCount) to badge")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.amberSoft)
                }
            }
            ProgressBar(value: Double(foundCount) / Double(totalCount))
                .frame(height: 10)
        }
        .padding(16)
        .background(.white.opacity(0.12), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
        .padding(.horizontal, 24)
    }
}

struct BadgeEarnedOverlay: View {
    let badgeName: String
    let badgeSymbol: String
    let sessionPoints: Int
    let onContinue: () -> Void

    @State private var scale: CGFloat = 0.4
    @State private var shimmer: CGFloat = -1

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Text("🏅 BADGE EARNED!")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white)

            BadgeArt(name: badgeName, symbol: badgeSymbol, earned: true)
                .frame(width: 220, height: 220)
                .scaleEffect(scale)
                .shadow(color: Theme.amber.opacity(0.7), radius: 30)

            VStack(spacing: 6) {
                Text("You explored every corner of Barber Park.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Well done, Explorer.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            HStack(spacing: 6) {
                Image(systemName: "star.fill").foregroundStyle(Theme.amberSoft)
                Text("\(sessionPoints) total points")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button(action: {
                Haptics.success()
                onContinue()
            }) {
                Text("View My Profile")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.darkGreen)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(.white, in: .rect(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.55)) {
                scale = 1
            }
        }
    }
}
