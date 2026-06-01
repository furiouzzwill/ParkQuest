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

// MARK: - Service

final class SupabaseService {

    static let shared = SupabaseService()
    private init() {}

    // MARK: - Profiles

    /// Creates a new profile row. Uses UPSERT so re-running is safe.
    func createProfile(id: String, username: String) async throws {
        let body: [String: String] = ["id": id, "username": username]
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

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            return "Supabase HTTP \(code): \(body)"
        }
    }
}
