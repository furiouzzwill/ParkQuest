//
//  GameState.swift
//  ParkQuestGSO
//
//  Local-first: state is restored from UserDefaults immediately on launch,
//  then synced from Supabase in the background (cloud wins for check-ins).
//

import SwiftUI
import Observation

@Observable
final class GameState {

    // MARK: - Park data

    let park: Park = SeedData.barberPark
    let lockedParks: [Park] = SeedData.lockedParks

    // MARK: - Game state (observed by views)

    private(set) var foundQuestIDs: Set<String> = []
    private(set) var earnedBadges: Set<String>  = []
    private(set) var recentDiscoveries: [String] = []

    /// True while the initial Supabase load is in flight.
    var isLoadingFromCloud = false
    /// Non-nil if the last cloud sync produced an error (shown in Profile for debug).
    var lastSyncError: String?

    // MARK: - Computed

    var totalPoints: Int {
        park.quests
            .filter { foundQuestIDs.contains($0.id) }
            .map(\.points)
            .reduce(0, +)
    }
    var foundCount: Int { foundQuestIDs.count }
    var totalCount: Int { park.quests.count }
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(foundCount) / Double(totalCount)
    }

    func isFound(_ quest: Quest) -> Bool { foundQuestIDs.contains(quest.id) }

    func quest(byID id: String) -> Quest? { park.quests.first { $0.id == id } }

    // MARK: - Init (restore from local cache immediately)

    init() {
        foundQuestIDs       = Set(UserDefaults.standard.stringArray(forKey: Keys.foundIDs) ?? [])
        earnedBadges        = Set(UserDefaults.standard.stringArray(forKey: Keys.badges)   ?? [])
        recentDiscoveries   =    (UserDefaults.standard.stringArray(forKey: Keys.recent)   ?? [])
    }

    // MARK: - Check-in

    /// Marks a quest as found locally (instant) and syncs to Supabase.
    /// Returns true if this check-in just earned the park badge.
    @discardableResult
    func checkIn(_ quest: Quest, userID: String? = nil) -> Bool {
        guard !foundQuestIDs.contains(quest.id) else { return false }

        foundQuestIDs.insert(quest.id)
        recentDiscoveries.insert(quest.id, at: 0)

        let badgeJustEarned = foundQuestIDs.count == park.quests.count
                              && !earnedBadges.contains(park.id)
        if badgeJustEarned { earnedBadges.insert(park.id) }

        persistLocally()

        // Fire-and-forget cloud sync
        if let uid = userID ?? storedUserID {
            Task {
                do {
                    try await SupabaseService.shared.recordCheckIn(
                        userID: uid,
                        questID: quest.id,
                        parkID: park.id
                    )
                    if badgeJustEarned {
                        try await SupabaseService.shared.recordBadge(
                            userID: uid,
                            parkID: park.id
                        )
                    }
                } catch {
                    // Non-fatal — local state is already saved
                    print("⚠️ Supabase sync error: \(error)")
                }
            }
        }

        return badgeJustEarned
    }

    // MARK: - Cloud load

    /// Loads check-ins and badges from Supabase, merging with local state.
    /// Call this once after the user ID is known (app launch or onboarding).
    @MainActor
    func loadFromCloud(userID: String) async {
        isLoadingFromCloud = true
        lastSyncError = nil

        do {
            async let remoteQuestIDs = SupabaseService.shared.fetchCheckIns(userID: userID)
            async let remoteBadgeIDs = SupabaseService.shared.fetchBadges(userID: userID)

            let (quests, badges) = try await (remoteQuestIDs, remoteBadgeIDs)

            // Cloud is source of truth — merge (union) so offline check-ins aren't lost
            let mergedQuests = foundQuestIDs.union(quests)
            let mergedBadges = earnedBadges.union(badges)

            // Push any locally-only check-ins up to the cloud
            let unsynced = foundQuestIDs.subtracting(quests)
            if !unsynced.isEmpty {
                for questID in unsynced {
                    try? await SupabaseService.shared.recordCheckIn(
                        userID: userID, questID: questID, parkID: park.id
                    )
                }
            }

            foundQuestIDs     = mergedQuests
            earnedBadges      = mergedBadges

            // Rebuild recentDiscoveries from merged set if local list is empty
            if recentDiscoveries.isEmpty {
                recentDiscoveries = Array(mergedQuests)
            }

            persistLocally()

        } catch {
            lastSyncError = error.localizedDescription
            print("⚠️ Supabase load error: \(error)")
        }

        isLoadingFromCloud = false
    }

    // MARK: - Reset

    func reset(userID: String? = nil) {
        foundQuestIDs     = []
        earnedBadges      = []
        recentDiscoveries = []
        persistLocally()
        // Note: does NOT delete server-side records (by design — use Supabase dashboard to wipe)
    }

    // MARK: - Private helpers

    private var storedUserID: String? {
        UserDefaults.standard.string(forKey: "pq_userID")
    }

    private func persistLocally() {
        UserDefaults.standard.set(Array(foundQuestIDs),  forKey: Keys.foundIDs)
        UserDefaults.standard.set(Array(earnedBadges),   forKey: Keys.badges)
        UserDefaults.standard.set(recentDiscoveries,     forKey: Keys.recent)
    }

    private enum Keys {
        static let foundIDs = "pq_foundQuestIDs"
        static let badges   = "pq_earnedBadges"
        static let recent   = "pq_recentDiscoveries"
    }
}
