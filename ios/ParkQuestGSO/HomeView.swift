//
//  HomeView.swift
//  ParkQuestGSO
//

import SwiftUI

struct HomeView: View {
    @Environment(GameState.self) private var game
    @Environment(UserSettings.self) private var userSettings
    @Binding var selectedTab: Tab
    @State private var lockedToast: String?
    @Namespace private var parkTransition

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    statsStrip
                    activeParkCard
                    ForEach(game.lockedParks) { park in
                        LockedParkCard(park: park) {
                            withAnimation { lockedToast = park.name }
                            Haptics.soft()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                                withAnimation { lockedToast = nil }
                            }
                        }
                    }
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(backgroundView)
            .overlay(alignment: .top) {
                if let t = lockedToast {
                    Text("More parks coming soon — \(t) is on the way.")
                        .font(.pqLabel)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Theme.darkGreen, in: .capsule)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationDestination(for: String.self) { _ in
                MapView()
                    .navigationTransition(.zoom(sourceID: "featuredPark", in: parkTransition))
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [Theme.cream, Theme.bg],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.primaryGreen)
                VStack(alignment: .leading, spacing: 0) {
                    Text("ParkQuest")
                        .font(.pqTitle)
                        .foregroundStyle(Theme.darkText)
                    Text("Greensboro")
                        .font(.pqLabel)
                        .foregroundStyle(Theme.mutedText)
                        .textCase(.uppercase)
                        .tracking(1.5)
                }
            }
            Spacer()
            Circle()
                .fill(LinearGradient(colors: [Theme.primaryGreen, Theme.darkGreen],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 42, height: 42)
                .overlay {
                    Text(userSettings.initials)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .shadow(color: Theme.darkGreen.opacity(0.25), radius: 6, y: 3)
        }
        .padding(.top, 12)
    }

    private var statsStrip: some View {
        HStack(spacing: 12) {
            statPill(symbol: "star.fill", value: "\(game.totalPoints)", label: "points", color: Theme.amber)
            statPill(symbol: "medal.fill", value: "\(game.earnedBadges.count)", label: "badges", color: Theme.primaryGreen)
            statPill(symbol: "checkmark.seal.fill", value: "\(game.foundCount)/\(game.totalCount)", label: "found", color: Theme.darkGreen)
        }
    }

    private func statPill(symbol: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.darkText)
                    .contentTransition(.numericText())
            }
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Theme.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        )
    }

    private var activeParkCard: some View {
        NavigationLink(value: "featuredPark") {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    ParkMapCanvas()
                        .frame(height: 160)
                        .clipped()
                    // Featured badge top right
                    HStack {
                        Text("FEATURED PARK")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.6)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Theme.amber.opacity(0.95), in: .capsule)
                        Spacer()
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    // dark gradient at bottom
                    LinearGradient(
                        colors: [.clear, Theme.darkGreen.opacity(0.75)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 80)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(Theme.amber)
                        Text(game.park.name.uppercased())
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .tracking(0.5)
                    }
                    .padding(14)
                }
                .clipShape(.rect(cornerRadius: 22))

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(game.park.city)
                                .font(.pqLabel)
                                .foregroundStyle(Theme.mutedText)
                            Text("\(game.totalCount) quests · \(game.foundCount) found")
                                .font(.pqHeadline)
                                .foregroundStyle(Theme.darkText)
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .stroke(Theme.lockGray, lineWidth: 4)
                                .frame(width: 48, height: 48)
                            Circle()
                                .trim(from: 0, to: max(0.001, game.progress))
                                .stroke(Theme.primaryGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 48, height: 48)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: game.progress)
                            Text("\(Int(game.progress * 100))%")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.darkText)
                        }
                    }

                    ProgressBar(value: game.progress)
                        .frame(height: 10)

                    HStack {
                        Text("Explore Park")
                            .font(.pqHeadline)
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [Theme.primaryGreen, Theme.darkGreen],
                                       startPoint: .leading, endPoint: .trailing),
                        in: .rect(cornerRadius: 14)
                    )
                    .shadow(color: Theme.primaryGreen.opacity(0.35), radius: 10, y: 5)
                }
                .padding(16)
            }
            .background(.white, in: .rect(cornerRadius: 22))
            .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
        }
        .buttonStyle(PressableStyle())
        .simultaneousGesture(TapGesture().onEnded { Haptics.medium() })
        .matchedTransitionSource(id: "featuredPark", in: parkTransition)
    }
}

struct LockedParkCard: View {
    let park: Park
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.lockGray)
                        .frame(width: 64, height: 64)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.mutedText)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(park.name)
                        .font(.pqHeadline)
                        .foregroundStyle(Theme.darkText)
                    Text("Coming soon · \(park.city)")
                        .font(.pqLabel)
                        .foregroundStyle(Theme.mutedText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.lockGray)
            }
            .padding(14)
            .background(.white, in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Theme.lockGray, lineWidth: 1)
            }
        }
        .buttonStyle(PressableStyle())
    }
}

struct ProgressBar: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.lockGray)
                Capsule()
                    .fill(LinearGradient(colors: [Theme.primaryGreen, Theme.mossGreen],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, geo.size.width * value))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: value)
            }
        }
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

enum Haptics {
    static func soft() {
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.impactOccurred()
    }
    static func medium() {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.impactOccurred()
    }
    static func rigid() {
        let g = UIImpactFeedbackGenerator(style: .rigid)
        g.impactOccurred()
    }
    static func success() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
    }
}
