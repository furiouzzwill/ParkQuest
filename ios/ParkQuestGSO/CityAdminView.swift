//
//  CityAdminView.swift
//  ParkQuestGSO
//
//  City Partner dashboard — only visible to users with userType == .cityAdmin.
//  Loads the parks the partner has set up via the wizard from Supabase,
//  shows a welcome sheet on first visit, and hosts the Add Park flow.
//

import SwiftUI

struct CityAdminView: View {
    @Environment(UserSettings.self) private var userSettings
    @Environment(GameState.self)    private var game

    // Loaded from Supabase — the parks this City Partner has actually added.
    @State private var partnerParks: [PartnerPark] = []
    @State private var isLoadingParks: Bool = false
    @State private var loadError: String?

    // Sheet state
    @State private var showAddPark: Bool = false
    @State private var showWelcome: Bool = false

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
            .refreshable { await loadParks() }
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
            .task {
                await loadParks()
                if !userSettings.hasSeenPartnerWelcome {
                    // Small delay so the sheet feels intentional, not jarring.
                    try? await Task.sleep(for: .milliseconds(500))
                    showWelcome = true
                }
            }
            .sheet(isPresented: $showAddPark) {
                AddParkView {
                    Task { await loadParks() }
                }
            }
            .sheet(isPresented: $showWelcome) {
                PartnerWelcomeSheet(
                    cityName: displayCityName,
                    onStart: {
                        userSettings.hasSeenPartnerWelcome = true
                        showWelcome = false
                        // Give the sheet a beat to dismiss before opening the wizard.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showAddPark = true
                        }
                    },
                    onDismiss: {
                        userSettings.hasSeenPartnerWelcome = true
                        showWelcome = false
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Loading

    private var displayCityName: String {
        // Prefer the human-readable name from SeedData if we have it,
        // otherwise fall back to whatever's stored on the user (e.g. "Asheville, NC").
        SeedData.allCities.first { $0.displayName == userSettings.city }?.name
            ?? userSettings.city
    }

    private func loadParks() async {
        guard !userSettings.cityID.isEmpty else { return }
        isLoadingParks = true
        defer { isLoadingParks = false }
        do {
            partnerParks = try await SupabaseService.shared.fetchParks(cityID: userSettings.cityID)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    // MARK: - City header

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
                Text(displayCityName)
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
            statCard(value: "\(partnerParks.count)",
                     label: "Parks",
                     icon: "mappin.circle.fill",
                     color: Theme.primaryGreen)
            statCard(value: "\(partnerParks.count)",
                     label: "Active",
                     icon: "checkmark.seal.fill",
                     color: Theme.mossGreen)
            statCard(value: "0",
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
                .contentTransition(.numericText())
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

    // MARK: - Parks list

    private var parksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Parks in \(displayCityName)")

            if isLoadingParks && partnerParks.isEmpty {
                loadingCard
            } else if partnerParks.isEmpty {
                emptyParksCard
            } else {
                VStack(spacing: 10) {
                    ForEach(partnerParks) { park in
                        partnerParkRow(park)
                    }
                }
            }
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Theme.primaryGreen)
            Text("Loading your parks…")
                .font(.pqLabel).foregroundStyle(Theme.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.white, in: .rect(cornerRadius: 14))
    }

    /// Empty state — first thing a new city partner sees. Doubles as the
    /// primary CTA into the Add Park wizard.
    private var emptyParksCard: some View {
        Button {
            Haptics.medium()
            showAddPark = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.primaryGreen)
                Text("No parks yet")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.darkText)
                Text("Add your first park to start welcoming explorers to \(displayCityName).")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.mutedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Set up a park")
                }
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Theme.primaryGreen, in: .capsule)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
            .background(.white, in: .rect(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(PressableStyle())
    }

    private func partnerParkRow(_ park: PartnerPark) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.primaryGreen.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: park.parkTypeEnum.symbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.primaryGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(park.parkName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.darkText)
                Text("\(park.parkTypeEnum.label) · Active")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.mossGreen)
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

    // MARK: - Management actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Management")

            VStack(spacing: 10) {
                actionRow(
                    icon: "plus.circle.fill",
                    color: Theme.primaryGreen,
                    title: "Add New Park",
                    subtitle: "Set up a park + landmarks",
                    isReady: true
                ) {
                    Haptics.medium()
                    showAddPark = true
                }
                actionRow(icon: "chart.bar.fill",   color: Theme.amber,
                          title: "View Analytics",  subtitle: "Explorer check-in activity")
                actionRow(icon: "paintbrush.fill",  color: .purple,
                          title: "City Branding",   subtitle: "Customize your city's theme")
                actionRow(icon: "bell.fill",        color: .blue,
                          title: "Send Announcement", subtitle: "Notify explorers in your city")
            }
        }
    }

    private func actionRow(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        isReady: Bool = false,
        action: (() -> Void)? = nil
    ) -> some View {
        Button {
            if isReady { action?() }
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
                if isReady {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.mutedText)
                } else {
                    Text("Soon")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.mutedText)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.lockGray.opacity(0.5), in: .capsule)
                }
            }
            .padding(14)
            .background(.white, in: .rect(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isReady)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .tracking(1.6)
            .foregroundStyle(Theme.mutedText)
    }
}

// MARK: - First-visit welcome sheet

private struct PartnerWelcomeSheet: View {
    let cityName: String
    let onStart: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 8)
            ZStack {
                Circle().fill(LinearGradient(colors: [Theme.darkGreen, Theme.primaryGreen],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 92, height: 92)
                    .shadow(color: Theme.darkGreen.opacity(0.35), radius: 14, y: 8)
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Welcome, \(cityName)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.darkText)
                    .multilineTextAlignment(.center)
                Text("Set up a park with landmarks so explorers can start earning points and badges when they visit.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.mutedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            VStack(alignment: .leading, spacing: 12) {
                bullet("1. Fill in your park's basics — name, type, address, contact.")
                bullet("2. Drop landmarks on the map — playgrounds, trails, points of interest.")
                bullet("3. Publish. Explorers earn points at each landmark they check into.")
            }
            .padding(16)
            .background(Theme.primaryGreen.opacity(0.08), in: .rect(cornerRadius: 14))
            .padding(.horizontal, 16)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    Haptics.medium()
                    onStart()
                } label: {
                    Text("Set up my first park")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.primaryGreen, in: .rect(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                }
                Button("I'll do this later", action: onDismiss)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.mutedText)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.primaryGreen)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.darkText)
        }
    }
}

#Preview {
    CityAdminView()
        .environment(UserSettings())
        .environment(GameState())
}
