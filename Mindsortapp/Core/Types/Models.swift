//
//  Models.swift
//  Mindsortapp
//
//  Shared types for API and local storage.
//

import Foundation

enum SyncStatus: String, Codable {
    case synced
    case pendingCreate
    case pendingUpdate
    case pendingDelete
}

struct Category: Codable, Identifiable, Sendable {
    let id: String
    let userID: String
    var name: String
    var entryCount: Int
    var isArchived: Bool
    var isUserCreated: Bool
    var color: String?
    let createdAt: Date
    var lastUpdated: Date
    var syncStatus: SyncStatus?
}

struct Entry: Codable, Identifiable, Sendable {
    let id: String
    let userID: String
    var transcript: String
    var title: String?
    var categoryID: String?
    var color: String?
    let createdAt: Date
    var categoryName: String?
    var syncStatus: SyncStatus?
    var locale: String?
}

struct ProcessEntryResponse: Codable, Sendable {
    let entry: Entry
    let category: Category
    let isNewCategory: Bool
}
