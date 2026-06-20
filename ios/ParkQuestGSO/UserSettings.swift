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

    /// The role assigned to this account (explorer or city admin).
    var userType: UserType {
        didSet { UserDefaults.standard.set(userType.rawValue, forKey: Keys.userType) }
    }

    /// The city this user belongs to (e.g. "Greensboro, NC").
    var city: String {
        didSet { UserDefaults.standard.set(city, forKey: Keys.city) }
    }

    /// The Supabase cities.id for this user's city. Separate from the
    /// display name so we can look up parks/quests against a stable id.
    var cityID: String {
        didSet { UserDefaults.standard.set(cityID, forKey: Keys.cityID) }
    }

    /// Email of the currently authenticated user, if any.
    var authEmail: String {
        didSet { UserDefaults.standard.set(authEmail, forKey: Keys.authEmail) }
    }

    /// Whether the user has authenticated (signed in or signed up) at least once.
    var isAuthenticated: Bool {
        didSet { UserDefaults.standard.set(isAuthenticated, forKey: Keys.isAuthenticated) }
    }

    /// Supabase access token from the current session. Empty when signed out
    /// (or when email confirmation is still pending after sign-up).
    var accessToken: String {
        didSet { UserDefaults.standard.set(accessToken, forKey: Keys.accessToken) }
    }

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
        city                    = UserDefaults.standard.string(forKey: Keys.city)        ?? "Greensboro, NC"
        cityID                  = UserDefaults.standard.string(forKey: Keys.cityID)      ?? "gso"
        authEmail               = UserDefaults.standard.string(forKey: Keys.authEmail)   ?? ""
        isAuthenticated         = UserDefaults.standard.bool(forKey: Keys.isAuthenticated)
        accessToken             = UserDefaults.standard.string(forKey: Keys.accessToken) ?? ""

        let rawType = UserDefaults.standard.string(forKey: Keys.userType) ?? ""
        userType = UserType(rawValue: rawType) ?? .explorer

        // Generate userID once; reuse on every subsequent launch.
        if let stored = UserDefaults.standard.string(forKey: Keys.userID) {
            userID = stored
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: Keys.userID)
            userID = newID
        }

        // Legacy migration: users who installed before auth gating shipped
        // already have completed onboarding but no auth state. Grant them a
        // synthetic local session so they aren't bounced to AuthView. They
        // can sign out from Profile to switch to a real account.
        if hasCompletedOnboarding && !isAuthenticated && authEmail.isEmpty {
            isAuthenticated = true
            authEmail       = "legacy@local"
        }
    }

    // MARK: - Auth

    /// Persist identity from a successful sign-in / sign-up.
    func applyAuthUser(_ user: AuthUser) {
        authEmail       = user.email
        accessToken     = user.accessToken
        isAuthenticated = true
    }

    /// Wipes auth + identity state. Called from the Profile screen sign-out
    /// button. Does not delete check-ins / badges — those are keyed to userID.
    func signOut() {
        let token = accessToken
        Task { await AuthService.shared.signOut(accessToken: token) }
        authEmail       = ""
        accessToken     = ""
        isAuthenticated = false
        hasCompletedOnboarding = false
    }

    /// City-Partner signup helper: creates the city in Supabase, then a
    /// city_admin profile, and updates local state so the app routes
    /// straight to CityAdminView (skipping the explorer onboarding flow).
    func applyCityAdminSignUp(authUser: AuthUser, cityName: String, state: String) {
        let id = UUID().uuidString
        cityID    = id
        city      = "\(cityName), \(state)"
        username  = cityName              // placeholder so initials still render
        userType  = .cityAdmin
        applyAuthUser(authUser)
        hasCompletedOnboarding = true     // city admins don't see the explorer onboarding

        Task {
            do {
                try await SupabaseService.shared.createCity(id: id, name: cityName, state: state)
                try await SupabaseService.shared.createProfile(
                    id: authUser.id,
                    username: cityName,
                    userType: .cityAdmin,
                    cityID: id
                )
            } catch {
                print("⚠️ City admin signup error: \(error)")
            }
        }
    }

    // MARK: - Supabase profile creation

    /// Called from OnboardingView when the user taps "Start Exploring".
    func createCloudProfile() {
        let uid  = userID
        let name = username
        let type = userType
        let cid  = cityID
        Task {
            do {
                try await SupabaseService.shared.createProfile(id: uid, username: name, userType: type, cityID: cid)
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
        static let username        = "pq_username"
        static let onboarding      = "pq_hasCompletedOnboarding"
        static let userID          = "pq_userID"
        static let userType        = "pq_userType"
        static let city            = "pq_city"
        static let cityID          = "pq_cityID"
        static let authEmail       = "pq_authEmail"
        static let isAuthenticated = "pq_isAuthenticated"
        static let accessToken     = "pq_accessToken"
    }
}
