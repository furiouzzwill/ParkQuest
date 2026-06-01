//
//  UserSettings.swift
//  ParkQuestGSO
//

import Foundation
import Observation

@Observable
final class UserSettings {

    // MARK: - Persisted properties

    /// Username entered during onboarding.
    var username: String {
        didSet {
            UserDefaults.standard.set(username, forKey: Keys.username)
            syncUsernameToCloud()
        }
    }

    /// Whether the user has finished the onboarding flow.
    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }

    /// Stable device-level UUID — used as the Supabase profiles.id.
    /// Generated once on first launch; persisted forever.
    let userID: String

    // MARK: - Computed

    /// Up to 2 initials from the username, uppercased. Falls back to "PQ".
    var initials: String {
        let parts = username
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ")
            .prefix(2)
        let letters = parts.compactMap(\.first).map(String.init).joined().uppercased()
        return letters.isEmpty ? "PQ" : letters
    }

    // MARK: - Init

    init() {
        username                = UserDefaults.standard.string(forKey: Keys.username)  ?? ""
        hasCompletedOnboarding  = UserDefaults.standard.bool(forKey: Keys.onboarding)

        // Generate userID once; reuse on every subsequent launch.
        if let stored = UserDefaults.standard.string(forKey: Keys.userID) {
            userID = stored
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: Keys.userID)
            userID = newID
        }
    }

    // MARK: - Supabase profile creation

    /// Called from OnboardingView when the user taps "Start Exploring".
    func createCloudProfile() {
        let uid  = userID
        let name = username
        Task {
            do {
                try await SupabaseService.shared.createProfile(id: uid, username: name)
            } catch {
                print("⚠️ Profile creation error: \(error)")
            }
        }
    }

    // MARK: - Private

    private func syncUsernameToCloud() {
        let uid  = userID
        let name = username
        Task {
            try? await SupabaseService.shared.updateUsername(id: uid, username: name)
        }
    }

    private enum Keys {
        static let username  = "pq_username"
        static let onboarding = "pq_hasCompletedOnboarding"
        static let userID    = "pq_userID"
    }
}
