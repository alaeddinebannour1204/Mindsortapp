//
//  AuthService.swift
//  Mindsortapp
//
//  Supabase auth: sign in, sign up, sign out.
//

import Foundation
import Supabase

enum AuthError: LocalizedError {
    case notConfigured
    case invalidCredentials
    case userAlreadyRegistered
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Auth is not configured. Add Supabase package and set URL/key."
        case .invalidCredentials: return "Invalid email or password."
        case .userAlreadyRegistered: return "An account with this email already exists. Try signing in."
        case .networkError(let err): return err.localizedDescription
        }
    }
}

@MainActor
final class AuthService {
    private let client: SupabaseClient

    init(url: URL, key: String) {
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    init(client: SupabaseClient) {
        self.client = client
    }

    var supabase: SupabaseClient { client }

    func signIn(email: String, password: String) async throws {
        do {
            _ = try await client.auth.signIn(email: email, password: password)
        } catch {
            throw AuthError.networkError(error)
        }
    }

    func signUp(email: String, password: String) async throws {
        do {
            _ = try await client.auth.signUp(email: email, password: password)
        } catch {
            throw AuthError.networkError(error)
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func currentUserId() async -> String? {
        (try? await client.auth.session)?.user.id.uuidString
    }
}
