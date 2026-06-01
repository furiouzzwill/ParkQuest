//
//  QuestListView.swift
//  ParkQuestGSO
//

import SwiftUI

struct QuestListView: View {
    @Environment(GameState.self)    private var game
    @Environment(UserSettings.self) private var userSettings
    @State private var activeQuest: Quest?
    @State private var celebrationQuest: Quest?
    @State private var badgeEarned: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    headerCard
                    questsSection
                    badgeProgressCard
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Quests")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $activeQuest) { quest in
            QuestCardSheet(quest: quest, isFound: game.isFound(quest)) {
                activeQuest = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    let earned = game.checkIn(quest, userID: userSettings.userID)
                    Haptics.success()
                    badgeEarned = earned
                    celebrationQuest = quest
                }
            }
            .presentationDetents([.fraction(0.55), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(Theme.cream)
        }
        .fullScreenCover(item: $celebrationQuest) { quest in
            CelebrationView(
                quest: quest,
                pointsTotal: game.totalPoints,
                foundCount: game.foundCount,
                totalCount: game.totalCount,
                badgeEarned: badgeEarned,
                badgeName: game.park.badgeName,
                badgeSymbol: game.park.badgeSymbol,
                onDismiss: {
                    celebrationQuest = nil
                    badgeEarned = false
                }
            )
        }
    }

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [Theme.primaryGreen, Theme.darkGreen],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(game.park.name)
                    .font(.pqHeadline)
                    .foregroundStyle(Theme.darkText)
                Text("\(game.foundCount) of \(game.totalCount) discovered · \(game.totalPoints) pts")
                    .font(.pqLabel)
                    .foregroundStyle(Theme.mutedText)
            }
            Spacer()
        }
        .padding(14)
        .background(.white, in: .rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private var questsSection: some View {
        let sorted = game.park.quests.sorted { lhs, rhs in
            let lf = game.isFound(lhs), rf = game.isFound(rhs)
            if lf != rf { return lf && !rf }
            return lhs.kind != .daily && rhs.kind == .daily
        }
        return VStack(spacing: 10) {
            ForEach(sorted) { quest in
                QuestRow(
                    quest: quest,
                    isFound: game.isFound(quest),
                    onTap: {
                        if !game.isFound(quest) {
                            Haptics.medium()
                            activeQuest = quest
                        } else {
                            Haptics.soft()
                        }
                    }
                )
            }
        }
    }

    private var badgeProgressCard: some View {
        HStack(spacing: 14) {
            BadgeArt(name: game.park.badgeName, symbol: game.park.badgeSymbol,
                     earned: game.earnedBadges.contains(game.park.id))
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text(game.park.badgeName)
                    .font(.pqHeadline)
                    .foregroundStyle(Theme.darkText)
                Text("Find all \(game.totalCount) to unlock")
                    .font(.pqLabel)
                    .foregroundStyle(Theme.mutedText)
                ProgressBar(value: game.progress).frame(height: 8)
                Text("\(game.foundCount) of \(game.totalCount)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.primaryGreen)
            }
        }
        .padding(14)
        .background(.white, in: .rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

struct QuestRow: View {
    let quest: Quest
    let isFound: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                iconCircle
                VStack(alignment: .leading, spacing: 3) {
                    Text(quest.name)
                        .font(.pqHeadline)
                        .foregroundStyle(isFound ? Theme.mutedText : Theme.darkText)
                        .strikethrough(isFound, color: Theme.mutedText)
                    Text(isFound ? "Discovered" : quest.kind.label)
                        .font(.pqLabel)
                        .foregroundStyle(isFound ? Theme.primaryGreen : Theme.mutedText)
                }
                Spacer()
                pointsTag
            }
            .padding(14)
            .background(isFound ? Theme.foundTint : .white, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            }
        }
        .buttonStyle(PressableStyle())
    }

    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(circleColor)
                .frame(width: 44, height: 44)
            Image(systemName: isFound ? "checkmark" : quest.kind.symbol)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)
        }
    }

    private var circleColor: Color {
        if isFound { return Theme.primaryGreen }
        if quest.kind == .daily { return Theme.dailyRed }
        return Theme.primaryGreen
    }

    private var borderColor: Color {
        if quest.kind == .daily && !isFound { return Theme.dailyRed.opacity(0.3) }
        return .clear
    }
    private var borderWidth: CGFloat {
        if quest.kind == .daily && !isFound { return 1.5 }
        return 0
    }

    private var pointsTag: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 10, weight: .bold))
            Text("+\(quest.points)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(isFound ? Theme.mutedText : Theme.amber)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(
            (isFound ? Theme.lockGray : Theme.amber.opacity(0.12)),
            in: .capsule
        )
    }
}
