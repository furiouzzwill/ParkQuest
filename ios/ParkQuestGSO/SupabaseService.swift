//
//  SupabaseService.swift
//  ParkQuestGSO
//
//  Lightweight async/await wrapper around Supabase's REST API.
//  No SDK required — pure URLSession.
//

import Foundation

// MARK: - Response models

private struct CheckInRow: Decodable {
    let questID: String
    enum CodingKeys: String, CodingKey { case questID = "quest_id" }
}

private struct BadgeRow: Decodable {
    let parkID: String
    enum CodingKeys: String, CodingKey { case parkID = "park_id" }
}

/// City info returned by a successful invite redemption.
struct RedeemedCity: Decodable, Sendable {
    let id: String
    let name: String
    let state: String
}

private struct RedeemRow: Decodable {
    let city: RedeemedCity?
}

// MARK: - Service

final class SupabaseService {

    static let shared = SupabaseService()
    private init() {}

    // MARK: - Cities

    /// Inserts a new city row. Uses UPSERT so re-signing-up with the same
    /// id is safe (will overwrite name/state). Kept for admin/manual use;
    /// not called from the invite-only signup flow.
    func createCity(id: String, name: String, state: String) async throws {
        let body: [String: String] = [
            "id":    id,
            "name":  name,
            "state": state
        ]
        var req = try request(path: "/rest/v1/cities", method: "POST", body: body)
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        try await send(req)
    }

    // MARK: - City Invites

    /// Atomically redeems a city-partner invite code. Returns the city it
    /// unlocks. Throws `SupabaseError.invalidInvite` if the code doesn't
    /// exist or has already been redeemed.
    ///
    /// The PATCH filter `redeemed_at=is.null` is what makes this atomic —
    /// Postgres will only update rows where the code is still fresh, so a
    /// second client trying to redeem the same code gets back an empty array.
    func redeemInvite(code: String, redeemerID: String) async throws -> RedeemedCity {
        let trimmed = code.trimmingCharacters(in: .whitespaces).uppercased()
        let body: [String: String] = [
            "redeemed_at": ISO8601DateFormatter().string(from: .now),
            "redeemed_by": redeemerID
        ]
        var req = try request(
            path: "/rest/v1/city_invites",
            method: "PATCH",
            body: body,
            query: [
                "code":        "eq.\(trimmed)",
                "redeemed_at": "is.null",
                "select":      "city:cities(id,name,state)"
            ]
        )
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let rows: [RedeemRow] = try await fetch(req)
        guard let city = rows.first?.city else {
            throw SupabaseError.invalidInvite
        }
        return city
    }

    // MARK: - Profiles

    /// Creates a new profile row. Uses UPSERT so re-running is safe.
    func createProfile(id: String, username: String, userType: UserType = .explorer, cityID: String = "gso") async throws {
        let body: [String: String] = [
            "id":        id,
            "username":  username,
            "user_type": userType.rawValue,
            "city_id":   cityID
        ]
        var req = try request(path: "/rest/v1/profiles", method: "POST", body: body)
        // Upsert: if row with same id exists, update username
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        try await send(req)
    }

    /// Updates the username for an existing profile.
    func updateUsername(id: String, username: String) async throws {
        let body: [String: String] = ["username": username, "updated_at": ISO8601DateFormatter().string(from: .now)]
        let req = try request(
            path: "/rest/v1/profiles",
            method: "PATCH",
            body: body,
            query: ["id": "eq.\(id)"]
        )
        try await send(req)
    }

    // MARK: - Check-ins

    /// Returns the quest IDs the user has already checked in to.
    func fetchCheckIns(userID: String) async throws -> [String] {
        let req = try request(
            path: "/rest/v1/check_ins",
            method: "GET",
            query: ["user_id": "eq.\(userID)", "select": "quest_id"]
        )
        let rows: [CheckInRow] = try await fetch(req)
        return rows.map(\.questID)
    }

    /// Records a new check-in. Ignores conflicts (already checked in).
    func recordCheckIn(userID: String, questID: String, parkID: String) async throws {
        let body: [String: String] = [
            "user_id":  userID,
            "quest_id": questID,
            "park_id":  parkID
        ]
        var req = try request(path: "/rest/v1/check_ins", method: "POST", body: body)
        req.setValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")
        try await send(req)
    }

    // MARK: - Parks (partner-created)

    /// Insert a new park row. Returns the server-assigned uuid so the
    /// caller can immediately attach geofences to it.
    func createPark(
        cityID: String?,
        parkName: String,
        parkType: String,
        address: String?,
        website: String?,
        description: String?,
        contactName: String?,
        contactEmail: String?,
        contactPhone: String?,
        adminUserID: String?
    ) async throws -> UUID {
        struct Body: Encodable {
            let city_id: String?
            let park_name: String
            let park_type: String
            let address: String?
            let website: String?
            let description: String?
            let contact_name: String?
            let contact_email: String?
            let contact_phone: String?
            let admin_user_id: String?
        }
        let body = Body(
            city_id: cityID,
            park_name: parkName,
            park_type: parkType,
            address: address,
            website: website,
            description: description,
            contact_name: contactName,
            contact_email: contactEmail,
            contact_phone: contactPhone,
            admin_user_id: adminUserID
        )
        var req = try request(path: "/rest/v1/parks", method: "POST", body: body)
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")

        struct IDRow: Decodable { let id: UUID }
        let rows: [IDRow] = try await fetch(req)
        guard let first = rows.first else {
            throw SupabaseError.httpError(statusCode: 500, body: "createPark returned no rows")
        }
        return first.id
    }

    /// Fetch every park owned by a given city. Ordered newest-first.
    func fetchParks(cityID: String) async throws -> [PartnerPark] {
        let req = try request(
            path: "/rest/v1/parks",
            method: "GET",
            query: [
                "city_id": "eq.\(cityID)",
                "select":  "id,city_id,park_name,park_type,address,website,description,contact_name,contact_email,contact_phone",
                "order":   "created_at.desc"
            ]
        )
        return try await fetch(req)
    }

    // MARK: - Park geofences (landmarks)

    /// Insert a landmark for a park. No return value — caller re-fetches
    /// the full landmark list after adding.
    func createLandmark(
        parkID: UUID,
        name: String,
        description: String?,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        rewardPoints: Int
    ) async throws {
        struct Body: Encodable {
            let park_id: String
            let name: String
            let description: String?
            let latitude: Double
            let longitude: Double
            let radius_meters: Double
            let reward_points: Int
        }
        let body = Body(
            park_id: parkID.uuidString.lowercased(),
            name: name,
            description: description,
            latitude: latitude,
            longitude: longitude,
            radius_meters: radiusMeters,
            reward_points: rewardPoints
        )
        let req = try request(path: "/rest/v1/park_geofences", method: "POST", body: body)
        try await send(req)
    }

    /// Fetch landmarks for a park, ordered oldest-first (the order the
    /// admin added them, which usually matches a natural tour path).
    func fetchLandmarks(parkID: UUID) async throws -> [PartnerLandmark] {
        let req = try request(
            path: "/rest/v1/park_geofences",
            method: "GET",
            query: [
                "park_id": "eq.\(parkID.uuidString.lowercased())",
                "select":  "id,park_id,name,description,latitude,longitude,radius_meters,reward_points",
                "order":   "created_at.asc"
            ]
        )
        return try await fetch(req)
    }

    // MARK: - Badges

    /// Returns the park IDs for which the user has earned a badge.
    func fetchBadges(userID: String) async throws -> [String] {
        let req = try request(
            path: "/rest/v1/earned_badges",
            method: "GET",
            query: ["user_id": "eq.\(userID)", "select": "park_id"]
        )
        let rows: [BadgeRow] = try await fetch(req)
        return rows.map(\.parkID)
    }

    /// Records a badge. Ignores conflicts (already earned).
    func recordBadge(userID: String, parkID: String) async throws {
        let body: [String: String] = ["user_id": userID, "park_id": parkID]
        var req = try request(path: "/rest/v1/earned_badges", method: "POST", body: body)
        req.setValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")
        try await send(req)
    }

    // MARK: - URLRequest builder

    private func request<B: Encodable>(
        path: String,
        method: String,
        body: B? = nil as String?,
        query: [String: String] = [:]
    ) throws -> URLRequest {
        guard var components = URLComponents(string: SupabaseConfig.projectURL + path) else {
            throw URLError(.badURL)
        }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(SupabaseConfig.anonKey,                   forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(SupabaseConfig.anonKey)",        forHTTPHeaderField: "Authorization")
        req.setValue("application/json",                        forHTTPHeaderField: "Content-Type")
        req.setValue("application/json",                        forHTTPHeaderField: "Accept")

        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }
        return req
    }

    // MARK: - Send helpers

    /// Fire-and-check — used for writes (POST / PATCH).
    @discardableResult
    private func send(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: req)
        try checkHTTP(response, data: data)
        return data
    }

    /// Fetch + decode — used for reads (GET).
    private func fetch<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: req)
        try checkHTTP(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func checkHTTP(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "(no body)"
            throw SupabaseError.httpError(statusCode: http.statusCode, body: body)
        }
    }
}

// MARK: - Error type

enum SupabaseError: LocalizedError {
    case httpError(statusCode: Int, body: String)
    case invalidInvite

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            return "Supabase HTTP \(code): \(body)"
        case .invalidInvite:
            return "That invite code is invalid or has already been used."
        }
    }
}
