//
//  QuestCardSheet.swift
//  ParkQuestGSO
//

import SwiftUI
import CoreLocation

struct QuestCardSheet: View {
    let quest: Quest
    let isFound: Bool
    let onCheckIn: () -> Void

    @Environment(LocationManager.self) private var location
    @State private var showARCapture = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headerArt
                    titleBlock
                    Divider().background(Theme.lockGray)
                    Text(quest.description)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Theme.darkText)
                        .lineSpacing(4)
                    if quest.kind == .daily {
                        dailyCallout
                    }
                    // Distance indicator (when location available)
                    if !isFound, let dist = location.distance(to: quest.coordinate) {
                        distanceBadge(meters: dist)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            footer
        }
        .fullScreenCover(isPresented: $showARCapture) {
            ARCaptureView(quest: quest) {
                // AR capture succeeded → close AR, then fire check-in
                showARCapture = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    onCheckIn()
                }
            } onCancel: {
                showARCapture = false
            }
        }
    }

    // MARK: - Header

    private var headerArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(quest.kind == .daily
                      ? LinearGradient(colors: [Theme.dailyRed, Theme.amber],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                      : LinearGradient(colors: [Theme.primaryGreen, Theme.darkGreen],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 110)

            // Soft decorative rings
            GeometryReader { geo in
                Canvas { ctx, size in
                    ctx.opacity = 0.18
                    for i in 0..<7 {
                        let r = CGFloat(40 + i * 14)
                        let path = Path(ellipseIn: CGRect(
                            x: size.width - r * 0.6, y: -r * 0.4,
                            width: r * 1.3, height: r * 1.3))
                        ctx.stroke(path, with: .color(.white), lineWidth: 1)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(height: 110)
            .clipShape(.rect(cornerRadius: 20))
            .allowsHitTesting(false)

            HStack {
                Image(systemName: quest.kind.symbol)
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("REWARD")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.8))
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.amberSoft)
                        Text("\(quest.points) pts")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 22)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(quest.kind.label.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(quest.kind == .daily ? Theme.dailyRed : Theme.primaryGreen)
            Text(quest.name)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.darkText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dailyCallout: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(Theme.dailyRed)
            Text("Bonus: visit all 5 spots in one session.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.darkText)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.dailyRed.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    private func distanceBadge(meters: CLLocationDistance) -> some View {
        let isClose = meters <= LocationManager.checkInRadius
        return HStack(spacing: 8) {
            Image(systemName: isClose ? "location.fill" : "location")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isClose ? Theme.primaryGreen : Theme.amber)
            Text(isClose
                 ? "You're here! Ready to check in."
                 : "\(formattedDistance(meters)) away — get closer to check in.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.darkText)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            (isClose ? Theme.foundTint : Theme.amberSoft.opacity(0.3)),
            in: .rect(cornerRadius: 12)
        )
    }

    private func formattedDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return "\(Int(meters)) m"
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            footerContent
            Text("Swipe down to close")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.mutedText)
                .padding(.bottom, 12)
        }
        .padding(.top, 8)
        .background(Theme.cream)
    }

    @ViewBuilder
    private var footerContent: some View {
        if isFound {
            alreadyFoundView
        } else {
            locationAwareCheckIn
        }
    }

    private var alreadyFoundView: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
            Text("Already Discovered")
        }
        .font(.pqHeadline)
        .foregroundStyle(Theme.primaryGreen)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Theme.foundTint, in: .rect(cornerRadius: 16))
        .padding(.horizontal, 22)
    }

    // MARK: - Location-aware check-in states

    @ViewBuilder
    private var locationAwareCheckIn: some View {
#if DEBUG
        // ── Debug: GPS gate bypassed so AR can be tested anywhere ──
        VStack(spacing: 8) {
            checkInButton
            HStack(spacing: 4) {
                Image(systemName: "ant.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("DEBUG — location check bypassed")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(Theme.amber)
        }
#else
        switch location.authorizationStatus {
        case .notDetermined:
            requestLocationView

        case .denied, .restricted:
            locationDeniedView

        default:
            // Authorized (when in use or always)
            if let dist = location.distance(to: quest.coordinate) {
                if dist <= LocationManager.checkInRadius {
                    checkInButton     // ✅ Close enough
                } else {
                    tooFarView(dist)  // 📍 Too far
                }
            } else {
                gettingLocationView  // ⏳ Waiting for first fix
            }
        }
#endif
    }

    /// Permission not yet requested — ask for it.
    private var requestLocationView: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.medium()
                location.requestPermission()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .black))
                    Text("Allow Location Access")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    LinearGradient(colors: [Theme.primaryGreen, Theme.darkGreen],
                                   startPoint: .leading, endPoint: .trailing),
                    in: .rect(cornerRadius: 16)
                )
                .shadow(color: Theme.primaryGreen.opacity(0.4), radius: 12, y: 6)
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 22)

            Text("Location is required to verify you're at the park.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
        }
    }

    /// Permission permanently denied — send user to Settings.
    private var locationDeniedView: some View {
        VStack(spacing: 10) {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                        .font(.system(size: 18, weight: .black))
                    Text("Open Settings")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(Theme.amber, in: .rect(cornerRadius: 16))
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 22)

            Text("Enable location in Settings → ParkQuest to check in.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
        }
    }

    /// Authorized, but no GPS fix yet.
    private var gettingLocationView: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(Theme.primaryGreen)
            Text("Getting your location…")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.mutedText)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.horizontal, 22)
    }

    /// Authorized, location known, but too far away.
    private func tooFarView(_ distance: CLLocationDistance) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You're \(formattedDistance(distance)) away")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.darkText)
                    Text("Walk within \(Int(LocationManager.checkInRadius)) m of this spot to check in.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.mutedText)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Theme.amberSoft.opacity(0.3), in: .rect(cornerRadius: 16))
            .padding(.horizontal, 22)
        }
    }

    /// Authorized, within range — launches AR capture game.
    private var checkInButton: some View {
        Button {
            Haptics.rigid()
            showARCapture = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .black))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Capture the Spirit")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                    Text("Point your camera & tap to earn points")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .opacity(0.8)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                LinearGradient(colors: [Theme.primaryGreen, Theme.darkGreen],
                               startPoint: .leading, endPoint: .trailing),
                in: .rect(cornerRadius: 16)
            )
            .shadow(color: Theme.primaryGreen.opacity(0.45), radius: 12, y: 6)
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal, 22)
    }
}
