//
//  ProfileView.swift
//  ParkQuestGSO
//

import SwiftUI

struct ProfileView: View {
    @Environment(GameState.self) private var game
    @Environment(UserSettings.self) private var userSettings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    profileHeader
                    badgeGrid
                    recentDiscoveries
                    cloudStatusRow
                    resetButton
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.primaryGreen, Theme.darkGreen],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                    .shadow(color: Theme.darkGreen.opacity(0.3), radius: 14, y: 8)
                Text(userSettings.initials)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 4) {
                Text(userSettings.username.isEmpty ? "Explorer" : userSettings.username)
                    .font(.pqTitle)
                    .foregroundStyle(Theme.darkText)
                Text(rankTitle)
                    .font(.pqLabel)
                    .foregroundStyle(Theme.primaryGreen)
                    .fontWeight(.semibold)
                Text(userSettings.city)
                    .font(.pqLabel)
                    .foregroundStyle(Theme.mutedText)
                userTypeBadge
            }
            HStack(spacing: 24) {
                VStack {
                    Text("\(game.totalPoints)")
                        .font(.pqStat)
                        .foregroundStyle(Theme.amber)
                        .contentTransition(.numericText())
                    Text("POINTS")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Theme.mutedText)
                }
                Divider().frame(height: 36)
                VStack {
                    Text("\(game.earnedBadges.count)")
                        .font(.pqStat)
                        .foregroundStyle(Theme.primaryGreen)
                        .contentTransition(.numericText())
                    Text("BADGES")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Theme.mutedText)
                }
                Divider().frame(height: 36)
                VStack {
                    Text("\(game.foundCount)")
                        .font(.pqStat)
                        .foregroundStyle(Theme.darkGreen)
                        .contentTransition(.numericText())
                    Text("QUESTS")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Theme.mutedText)
                }
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(.white, in: .rect(cornerRadius: 18))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        }
    }

    private var rankTitle: String {
        switch game.totalPoints {
        case 0..<50: return "Junior Explorer"
        case 50..<150: return "Park Explorer"
        case 150..<200: return "Senior Explorer"
        default: return "Park Ranger"
        }
    }

    private var userTypeBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: userSettings.userType.symbol)
                .font(.system(size: 10, weight: .bold))
            Text(userSettings.userType.label.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1)
        }
        .foregroundStyle(userSettings.userType == .cityAdmin ? Theme.amber : Theme.mossGreen)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            (userSettings.userType == .cityAdmin ? Theme.amber : Theme.mossGreen).opacity(0.12),
            in: .capsule
        )
    }

    private var badgeGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("My Badges")
            HStack(spacing: 12) {
                BadgeTile(name: game.park.badgeName,
                          symbol: game.park.badgeSymbol,
                          earned: game.earnedBadges.contains(game.park.id),
                          parkLabel: game.park.name)
                ForEach(game.lockedParks) { park in
                    BadgeTile(name: park.badgeName,
                              symbol: park.badgeSymbol,
                              earned: false,
                              parkLabel: park.name)
                }
            }
        }
    }

    private var recentDiscoveries: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Recent Discoveries")
            if game.recentDiscoveries.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(game.recentDiscoveries.prefix(5).enumerated()), id: \.element) { _, id in
                        if let q = game.quest(byID: id) {
                            recentRow(q)
                        }
                    }
                }
            }
        }
    }

    private func recentRow(_ q: Quest) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.foundTint).frame(width: 40, height: 40)
                Image(systemName: q.kind.symbol)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.primaryGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(q.name)
                    .font(.pqHeadline)
                    .foregroundStyle(Theme.darkText)
                Text(q.kind.label)
                    .font(.pqLabel)
                    .foregroundStyle(Theme.mutedText)
            }
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("+\(q.points)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(Theme.amber)
        }
        .padding(12)
        .background(.white, in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "binoculars.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.mutedText)
            Text("No discoveries yet — head into the park!")
                .font(.pqLabel)
                .foregroundStyle(Theme.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.white, in: .rect(cornerRadius: 14))
    }

    private var cloudStatusRow: some View {
        HStack(spacing: 8) {
            if game.isLoadingFromCloud {
                ProgressView().tint(Theme.mutedText)
                Text("Syncing with cloud…")
            } else if let err = game.lastSyncError {
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(Theme.amber)
                Text("Sync error: \(err)")
                    .lineLimit(2)
            } else {
                Image(systemName: "checkmark.icloud.fill")
                    .foregroundStyle(Theme.primaryGreen)
                Text("Cloud sync up to date")
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Theme.mutedText)
    }

    private var resetButton: some View {
        Button {
            Haptics.medium()
            withAnimation { game.reset(userID: userSettings.userID) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                Text("Reset Demo Progress")
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.mutedText)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.lockGray.opacity(0.6), in: .capsule)
        }
        .buttonStyle(PressableStyle())
    }

    private func sectionTitle(_ text: String) -> some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(Theme.mutedText)
            Spacer()
        }
    }
}

struct BadgeTile: View {
    let name: String
    let symbol: String
    let earned: Bool
    let parkLabel: String

    var body: some View {
        VStack(spacing: 8) {
            BadgeArt(name: name, symbol: symbol, earned: earned)
                .frame(height: 92)
            Text(parkLabel)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(earned ? Theme.darkText : Theme.mutedText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(.white, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}
