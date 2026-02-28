//
//  SupabaseConfig.swift
//  Mindsortapp
//
//  Centralized Supabase configuration. Reads from environment variables.
//

import Foundation

enum SupabaseConfig {
    /// Project URL from Supabase dashboard (API Settings)
    static var url: URL? {
        guard let s = ProcessInfo.processInfo.environment["SUPABASE_URL"],
              let url = URL(string: s) else { return nil }
        return url
    }

    /// Anon / publishable key from Supabase dashboard
    static var anonKey: String? {
        ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
    }

    static var isConfigured: Bool {
        url != nil && anonKey != nil
    }
}
