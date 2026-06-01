//
//  MapView.swift
//  ParkQuestGSO
//

import SwiftUI
import MapKit

struct MapView: View {
    @Environment(GameState.self)     private var game
    @Environment(LocationManager.self) private var location
    @Environment(UserSettings.self)  private var userSettings
    @Environment(\.dismiss) private var dismiss

    @State private var activeQuest: Quest?
    @State private var celebrationQuest: Quest?
    @State private var badgeJustEarned = false
    @State private var alreadyToast: String?

    /// Camera position — starts framing all of Barber Park.
    @State private var mapPosition: MapCameraPosition = .region(.barberPark)

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer

            VStack(spacing: 0) {
                topBar
                Spacer()
                legend
            }

            if let t = alreadyToast {
                Text("\(t) — already discovered ✓")
                    .font(.pqLabel)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.darkGreen, in: .capsule)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden(true)
        .sheet(item: $activeQuest) { quest in
            QuestCardSheet(
                quest: quest,
                isFound: game.isFound(quest),
                onCheckIn: {
                    activeQuest = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        let earned = game.checkIn(quest, userID: userSettings.userID)
                        Haptics.success()
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                            celebrationQuest = quest
                            badgeJustEarned = earned
                        }
                    }
                }
            )
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
                badgeEarned: badgeJustEarned,
                badgeName: game.park.badgeName,
                badgeSymbol: game.park.badgeSymbol,
                onDismiss: {
                    celebrationQuest = nil
                    badgeJustEarned = false
                }
            )
        }
    }

    // MARK: - Real MapKit map

    private var mapLayer: some View {
        Map(position: $mapPosition,
            bounds: MapCameraBounds(
                centerCoordinateBounds: MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 36.0521, longitude: -79.7519),
                    span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.020)
                ),
                minimumDistance: nil,
                maximumDistance: 900
            )
        ) {
            // User's real location dot
            UserAnnotation()

            // Quest pins at real GPS coordinates
            ForEach(game.park.quests) { quest in
                Annotation("", coordinate: quest.coordinate, anchor: .center) {
                    QuestPin(
                        quest: quest,
                        isFound: game.isFound(quest)
                    ) {
                        if game.isFound(quest) {
                            Haptics.soft()
                            withAnimation { alreadyToast = quest.name }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                withAnimation { alreadyToast = nil }
                            }
                        } else {
                            Haptics.medium()
                            activeQuest = quest
                        }
                    }
                }
            }
        }
        .mapStyle(.hybrid(
            elevation: .realistic,
            pointsOfInterest: .excludingAll
        ))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .ignoresSafeArea()
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.soft()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.darkText)
                    .frame(width: 40, height: 40)
                    .background(.white, in: .circle)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(game.park.name)
                    .font(.pqTitle)
                    .foregroundStyle(Theme.darkText)
                Text(game.park.city)
                    .font(.pqLabel)
                    .foregroundStyle(Theme.mutedText)
            }

            Spacer()

            // Recenter button
            Button {
                withAnimation {
                    mapPosition = .region(.barberPark)
                }
            } label: {
                Image(systemName: "scope")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.primaryGreen)
                    .frame(width: 40, height: 40)
                    .background(.white, in: .circle)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            }

            // Progress pill
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.primaryGreen)
                Text("\(game.foundCount)/\(game.totalCount)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.darkText)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.white, in: .capsule)
            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
        }
        .padding(.horizontal, 16)
        .padding(.top, 56) // clear the status bar
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [.white.opacity(0.92), .white.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 18) {
            LegendDot(color: Theme.primaryGreen,
                      label: "Available", icon: nil)
            LegendDot(color: Theme.foundTint,
                      label: "Found",
                      icon: "checkmark",
                      iconColor: Theme.primaryGreen,
                      ring: Theme.primaryGreen)
            LegendDot(color: Theme.dailyRed,
                      label: "Daily",
                      icon: "bolt.fill",
                      iconColor: .white)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.white)
        .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 12, y: -4)
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Supporting views (unchanged)

struct LegendDot: View {
    let color: Color
    let label: String
    var icon: String? = nil
    var iconColor: Color = .white
    var ring: Color? = nil

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(color).frame(width: 16, height: 16)
                if let ring {
                    Circle().strokeBorder(ring, lineWidth: 2).frame(width: 16, height: 16)
                }
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(iconColor)
                }
            }
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.darkText)
        }
    }
}

struct QuestPin: View {
    let quest: Quest
    let isFound: Bool
    let action: () -> Void

    @State private var pulse: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulse ring for available (non-daily)
                if !isFound && quest.kind != .daily {
                    Circle()
                        .stroke(Theme.primaryGreen.opacity(0.45), lineWidth: 2)
                        .frame(width: 48, height: 48)
                        .scaleEffect(pulse ? 1.4 : 1)
                        .opacity(pulse ? 0 : 1)
                }
                // White halo
                Circle()
                    .fill(.white)
                    .frame(width: 42, height: 42)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                // Inner fill
                Circle()
                    .fill(innerColor)
                    .frame(width: 34, height: 34)
                // Icon
                Image(systemName: iconName)
                    .font(.system(size: iconSize, weight: .black))
                    .foregroundStyle(iconColor)
            }
            .contentShape(.circle)
        }
        .buttonStyle(PressableStyle())
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }

    private var innerColor: Color {
        if isFound { return Theme.foundTint }
        if quest.kind == .daily { return Theme.dailyRed }
        return Theme.primaryGreen
    }
    private var iconColor: Color {
        isFound ? Theme.primaryGreen : .white
    }
    private var iconName: String {
        if isFound { return "checkmark" }
        if quest.kind == .daily { return "bolt.fill" }
        return quest.kind.symbol
    }
    private var iconSize: CGFloat {
        isFound ? 16 : 14
    }
}
