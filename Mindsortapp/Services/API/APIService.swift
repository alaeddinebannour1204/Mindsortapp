//
//  APIService.swift
//  Mindsortapp
//

import Foundation
import Supabase

@MainActor
final class APIService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    /// Force-refresh the Supabase session so the access token is current.
    /// Call before any sync batch to avoid 401s from expired JWTs.
    func refreshSession() async throws {
        _ = try await client.auth.session
    }

    func fetchCategories() async throws -> [Category] {
        let response: [CategoryRow] = try await client
            .from("categories")
            .select()
            .eq("is_archived", value: false)
            .order("last_updated", ascending: false)
            .execute()
            .value
        return response.map { $0.toCategory() }
    }

    func createCategory(name: String, id: String? = nil) async throws -> Category {
        struct Insert: Encodable {
            let id: String
            let name: String
            let is_user_created: Bool
        }
        let localId = id ?? UUID().uuidString
        let response: [CategoryRow] = try await client
            .from("categories")
            .insert(Insert(id: localId, name: name, is_user_created: true))
            .select()
            .single()
            .execute()
            .value
        return (response.first ?? CategoryRow.empty(name: name, id: localId)).toCategory()
    }

    func renameCategory(id: String, name: String) async throws {
        try await client
            .from("categories")
            .update(["name": name, "last_updated": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id)
            .execute()
    }

    func deleteCategory(id: String) async throws {
        try await client
            .from("categories")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func fetchEntriesByCategory(categoryId: String) async throws -> [Entry] {
        let response: [EntryRow] = try await client
            .from("entries")
            .select()
            .eq("category_id", value: categoryId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return response.map { $0.toEntry() }
    }

    func editEntry(id: String, transcript: String?, title: String?, categoryID: String?) async throws {
        var payload: [String: String] = ["last_updated": ISO8601DateFormatter().string(from: Date())]
        if let t = transcript { payload["transcript"] = t }
        if let t = title { payload["title"] = t }
        if let c = categoryID { payload["category_id"] = c }
        try await client
            .from("entries")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }

    func deleteEntry(id: String) async throws {
        try await client
            .from("entries")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func processEntry(transcript: String, locale: String?, categoryId: String?) async throws -> ProcessEntryResponse {
        struct Payload: Encodable {
            let transcript: String
            let locale: String?
            let category_id: String?
        }
        let row: ProcessEntryResponseRow = try await client.functions
            .invoke("process-entry", options: .init(body: Payload(transcript: transcript, locale: locale, category_id: categoryId)))
        return ProcessEntryResponse(
            entry: row.entry.toEntry(),
            category: row.category.toCategory(),
            isNewCategory: row.is_new_category
        )
    }

    func searchEntries(query: String) async throws -> [Entry] {
        struct Payload: Encodable {
            let query: String
        }
        let rows: [EntryRow] = try await client.functions
            .invoke("search-entries", options: .init(body: Payload(query: query)))
        return rows.map { $0.toEntry() }
    }
}

// MARK: - Edge Function response row

private struct ProcessEntryResponseRow: Codable {
    let entry: EntryRow
    let category: CategoryRow
    let is_new_category: Bool
}

// MARK: - Row types

private struct CategoryRow: Codable {
    let id: String
    let user_id: String
    let name: String
    let entry_count: Int?
    let is_archived: Bool?
    let color: String?
    let is_user_created: Bool?
    let created_at: String
    let last_updated: String
    let latest_entry_title: String?

    static func empty(name: String, id: String = UUID().uuidString) -> CategoryRow {
        CategoryRow(
            id: id,
            user_id: "",
            name: name,
            entry_count: 0,
            is_archived: false,
            color: nil,
            is_user_created: true,
            created_at: ISO8601DateFormatter().string(from: Date()),
            last_updated: ISO8601DateFormatter().string(from: Date()),
            latest_entry_title: nil
        )
    }

    func toCategory() -> Category {
        Category(
            id: id,
            userID: user_id,
            name: name,
            embeddingCentroid: nil,
            entryCount: entry_count ?? 0,
            isArchived: is_archived ?? false,
            isUserCreated: is_user_created ?? true,
            color: color,
            createdAt: ISO8601DateFormatter().date(from: created_at) ?? Date(),
            lastUpdated: ISO8601DateFormatter().date(from: last_updated) ?? Date(),
            latestEntryTitle: latest_entry_title,
            syncStatus: .synced
        )
    }
}

private struct EntryRow: Codable {
    let id: String
    let user_id: String
    let transcript: String
    let title: String?
    let category_id: String?
    let color: String?
    let created_at: String
    let category_name: String?
    let locale: String?

    func toEntry() -> Entry {
        Entry(
            id: id,
            userID: user_id,
            transcript: transcript,
            title: title,
            categoryID: category_id,
            embeddingVector: nil,
            color: color,
            createdAt: ISO8601DateFormatter().date(from: created_at) ?? Date(),
            categoryName: category_name,
            syncStatus: .synced,
            locale: locale
        )
    }
}
