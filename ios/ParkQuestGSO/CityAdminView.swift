//
//  CityAdminView.swift
//  ParkQuestGSO
//
//  City Partner dashboard — only visible to users with userType == .cityAdmin.
//  Shows city-level stats, parks, and a placeholder for management actions.
//

import SwiftUI

struct CityAdminView: View {
    @Environment(UserSettings.self) private var userSettings
    @Environment(GameState.self)    private var game

    private var city: City? {
        SeedData.allCities.first { $0.displayName == userSettings.city }
            ?? SeedData.allCities.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    cityHeader
                    statsRow
                    parksSection
                    actionsSection
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("City Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.medium()
                        withAnimation { userSettings.signOut() }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.darkGreen)
                    }
                    .accessibilityLabel("Sign out")
                }
            }
        }
    }

    // MARK: - City Header

    private var cityHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [Theme.darkGreen, Theme.primaryGreen],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                Image(systemName: "building.2.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(city?.name ?? userSettings.city)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.darkText)
                HStack(spacing: 6) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.amber)
                    Text("City Partner Account")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.amber)
                        .tracking(0.5)
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Theme.amber.opacity(0.12), in: .capsule)
            }
            Spacer()
        }
        .padding(16)
        .background(.white, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(value: "\(city?.parks.count ?? 0)",
                     label: "Parks",
                     icon: "mappin.circle.fill",
                     color: Theme.primaryGreen)
            statCard(value: "\(city?.parks.filter { !$0.isLocked }.count ?? 0)",
                     label: "Active",
                     icon: "checkmark.seal.fill",
                     color: Theme.mossGreen)
            statCard(value: "\(city?.parks.filter { $0.isLocked }.count ?? 0)",
                     label: "Coming Soon",
                     icon: "lock.fill",
                     color: Theme.amber)
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Theme.darkText)
            Text(label)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.mutedText)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white, in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Parks List

    private var parksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Parks in \(city?.name ?? "Your City")")

            VStack(spacing: 10) {
                ForEach(city?.parks ?? []) { park in
                    parkRow(park)
                }
            }
        }
    }

    private func parkRow(_ park: Park) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(park.isLocked ? Theme.lockGray.opacity(0.3) : Theme.primaryGreen.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: park.isLocked ? "lock.fill" : park.badgeSymbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(park.isLocked ? Theme.mutedText : Theme.primaryGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(park.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.darkText)
                Text(park.isLocked ? "Coming Soon" : "\(park.quests.count) quests · Active")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(park.isLocked ? Theme.mutedText : Theme.mossGreen)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.mutedText)
        }
        .padding(14)
        .background(.white, in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Management")

            VStack(spacing: 10) {
                actionRow(icon: "plus.circle.fill",   color: Theme.primaryGreen,
                          title: "Add New Park",       subtitle: "Submit a park for review")
                actionRow(icon: "chart.bar.fill",      color: Theme.amber,
                          title: "View Analytics",     subtitle: "Explorer check-in activity")
                actionRow(icon: "paintbrush.fill",     color: .purple,
                          title: "City Branding",      subtitle: "Customize your city's theme")
                actionRow(icon: "bell.fill",            color: .blue,
                          title: "Send Announcement",  subtitle: "Notify explorers in your city")
            }
        }
    }

    private func actionRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        Button {
            // TODO: wire up individual admin actions
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.darkText)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.mutedText)
                }
                Spacer()
                Text("Soon")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.mutedText)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.lockGray.opacity(0.5), in: .capsule)
            }
            .padding(14)
            .background(.white, in: .rect(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(PressableStyle())
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .tracking(1.6)
            .foregroundStyle(Theme.mutedText)
    }
}

#Preview {
    CityAdminView()
        .environment(UserSettings())
        .environment(GameState())
}
