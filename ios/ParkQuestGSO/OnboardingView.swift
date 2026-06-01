//
//  OnboardingView.swift
//  ParkQuestGSO
//

import SwiftUI

struct OnboardingView: View {
    @Environment(UserSettings.self)  private var userSettings
    @Environment(LocationManager.self) private var locationManager
    @Environment(GameState.self)     private var game

    @State private var nameInput: String = ""
    @State private var showNameField = false
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var contentOffset: CGFloat = 40
    @State private var contentOpacity: Double = 0
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()
                logoSection
                Spacer().frame(height: 48)
                if showNameField {
                    nameSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    welcomeSection
                }
                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) {
                logoScale = 1
                logoOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                contentOffset = 0
                contentOpacity = 1
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.darkGreen, Theme.primaryGreen, Theme.mossGreen],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [.white.opacity(0.15), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Logo

    private var logoSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 110, height: 110)
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 88, height: 88)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(.white)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)

            VStack(spacing: 6) {
                Text("ParkQuest")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(1)
                Text("GREENSBORO")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .offset(y: contentOffset)
            .opacity(contentOpacity)
        }
    }

    // MARK: - Welcome section (step 1)

    private var welcomeSection: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("Explore Greensboro's Parks")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Find quest locations, check in when you arrive, and earn badges for each park you conquer.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            featureRow(icon: "mappin.and.ellipse", text: "GPS-verified check-ins at real park locations")
            featureRow(icon: "medal.fill", text: "Earn collectible badges for each park")
            featureRow(icon: "bolt.fill", text: "Daily bonus challenges for extra points")

            Button {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                    showNameField = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    nameFocused = true
                }
            } label: {
                Text("Get Started")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.darkGreen)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(.white, in: .rect(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            }
            .buttonStyle(PressableStyle())
        }
        .offset(y: contentOffset)
        .opacity(contentOpacity)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    // MARK: - Name section (step 2)

    private var nameSection: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("What's your name?")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("We'll use this for your explorer profile.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                TextField("Your name", text: $nameInput)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.darkText)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(.white, in: .rect(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { attemptContinue() }
                    .autocorrectionDisabled()
            }

            Button { attemptContinue() } label: {
                HStack(spacing: 8) {
                    Text("Start Exploring")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(nameInput.trimmingCharacters(in: .whitespaces).isEmpty
                                 ? Theme.darkGreen.opacity(0.4)
                                 : Theme.darkGreen)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    nameInput.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color.white.opacity(0.5)
                        : Color.white,
                    in: .rect(cornerRadius: 18)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            }
            .buttonStyle(PressableStyle())
            .disabled(nameInput.trimmingCharacters(in: .whitespaces).isEmpty)

            // Ask for location permission as part of setup
            Button {
                withAnimation { showNameField = false }
            } label: {
                Text("Back")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Actions

    private func attemptContinue() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        nameFocused = false
        Haptics.success()
        locationManager.requestPermission()
        userSettings.username = trimmed
        // Create profile in Supabase (fire-and-forget)
        userSettings.createCloudProfile()
        // Load any existing cloud state for this device
        let uid = userSettings.userID
        Task { await game.loadFromCloud(userID: uid) }
        withAnimation(.easeInOut(duration: 0.3)) {
            userSettings.hasCompletedOnboarding = true
        }
    }
}

#Preview {
    OnboardingView()
        .environment(UserSettings())
        .environment(LocationManager())
}
