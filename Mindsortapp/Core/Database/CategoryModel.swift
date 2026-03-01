//
//  CategoryModel.swift
//  Mindsortapp
//

import Foundation
import SwiftData

@Model
final class CategoryModel {
    @Attribute(.unique) var id: String
    var userID: String
    var name: String
    var entryCount: Int
    var isArchived: Bool
    var color: String?
    var isUserCreated: Bool
    var createdAt: Date
    var lastUpdated: Date
    var latestEntryTitle: String?
    var syncStatusRaw: String

    /// The merged note body — all accepted entries concatenated into one continuous text.
    var noteBody: String = ""

    /// Rich text data (archived NSAttributedString). When nil, falls back to noteBody plain text.
    var richNoteBody: Data?

    init(
        id: String,
        userID: String,
        name: String,
        entryCount: Int = 0,
        isArchived: Bool = false,
        color: String? = nil,
        isUserCreated: Bool = true,
        createdAt: Date = Date(),
        lastUpdated: Date = Date(),
        latestEntryTitle: String? = nil,
        syncStatus: SyncStatus = .synced,
        noteBody: String = "",
        richNoteBody: Data? = nil
    ) {
        self.id = id
        self.userID = userID
        self.name = name
        self.entryCount = entryCount
        self.isArchived = isArchived
        self.color = color
        self.isUserCreated = isUserCreated
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.latestEntryTitle = latestEntryTitle
        self.syncStatusRaw = syncStatus.rawValue
        self.noteBody = noteBody
        self.richNoteBody = richNoteBody
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .synced }
        set { syncStatusRaw = newValue.rawValue }
    }
}
