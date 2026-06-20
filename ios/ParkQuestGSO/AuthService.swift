//
//  AuthService.swift
//  ParkQuestGSO
//
//  Real Supabase Auth, called over REST (no SDK required).
//  Replaces the previous UserDefaults-only demo implementation.
//
//  Supabase project URL + anon key are read from SupabaseConfig.
//
//  IMPORTANT: For prototype use, disable email confirmation in your
//  Supabase project (Auth → Providers → Email → "Confirm email" OFF).
//  Otherwise newly signed-up users won't get an access token until
//  they click the confirmation link in their inbox.
//

import Foundation

struct AuthUser {
    let id: String           // Supabase auth user UUID
    let email: String
    let accessToken: String  // empty when email confirmation pending
    let refreshToken: String
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword(String)
    case emailNotConfirmed
    case networkError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:  return "Invalid email or password."
        case .emailAlreadyInUse:   return "An account with that email already exists."
        case .weakPassword(let m): return m
        case .emailNotConfirmed:   return "Please confirm your email before signing in."
        case .networkError(let m): return m
        case .unknown(let m):      return m
        }
    }
}

final class AuthService {

    static let shared = AuthService()
    private init() {}

    // MARK: - Public API

    func signUp(email: String, password: String) async throws -> AuthUser {
        let body = Credentials(email: email, password: password)
        let req = try authRequest(path: "/auth/v1/signup", method: "POST", body: body)
        let resp: AuthResponse = try await fetch(req)
        return try authUser(from: resp)
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        let body = Credentials(email: email, password: password)
        let req = try authRequest(
            path: "/auth/v1/token",
            method: "POST",
            body: body,
            query: ["grant_type": "password"]
        )
        let resp: AuthResponse = try await fetch(req)
        return try authUser(from: resp)
    }

    /// Fire-and-forget logout. We don't surface failures because the local
    /// state is cleared regardless — a stale server-side session is harmless.
    func signOut(accessToken: String) async {
        guard !accessToken.isEmpty else { return }
        guard var req = try? authRequest(path: "/auth/v1/logout", method: "POST", body: EmptyBody()) else { return }
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
    }

    // MARK: - Request/response models

    private struct Credentials: Encodable {
        let email: String
        let password: String
    }
    private struct EmptyBody: Encodable {}

    /// Handles both response shapes:
    /// - Sign-in (and sign-up when email confirmation is off): includes
    ///   `access_token` + `refresh_token` and a nested `user`.
    /// - Sign-up when email confirmation is on: just a user payload at the root.
    private struct AuthResponse: Decodable {
        let access_token: String?
        let refresh_token: String?
        let user: UserPayload?
        let id: String?
        let email: String?
    }
    private struct UserPayload: Decodable {
        let id: String
        let email: String?
    }
    private struct ErrorResponse: Decodable {
        let error: String?
        let error_description: String?
        let msg: String?
        let message: String?
    }

    private func authUser(from resp: AuthResponse) throws -> AuthUser {
        let id    = resp.user?.id ?? resp.id ?? ""
        let email = resp.user?.email ?? resp.email ?? ""
        guard !id.isEmpty else { throw AuthError.unknown("Auth response missing user id") }
        return AuthUser(
            id: id,
            email: email,
            accessToken: resp.access_token ?? "",
            refreshToken: resp.refresh_token ?? ""
        )
    }

    // MARK: - Networking

    private func authRequest<B: Encodable>(
        path: String,
        method: String,
        body: B,
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
        req.setValue(SupabaseConfig.anonKey,            forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json",                 forHTTPHeaderField: "Content-Type")
        req.setValue("application/json",                 forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(body)
        return req
    }

    private func fetch<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.networkError("No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw mapError(status: http.statusCode, data: data)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func mapError(status: Int, data: Data) -> AuthError {
        let err = try? JSONDecoder().decode(ErrorResponse.self, from: data)
        let msg = err?.msg
            ?? err?.message
            ?? err?.error_description
            ?? err?.error
            ?? "HTTP \(status)"
        let lower = msg.lowercased()
        if lower.contains("already") && (lower.contains("registered") || lower.contains("exists")) {
            return .emailAlreadyInUse
        }
        if lower.contains("invalid login") || lower.contains("invalid credentials") {
            return .invalidCredentials
        }
        if lower.contains("password") && (lower.contains("weak") || lower.contains("at least") || lower.contains("characters")) {
            return .weakPassword(msg)
        }
        if lower.contains("confirm") {
            return .emailNotConfirmed
        }
        return .unknown(msg)
    }
}
