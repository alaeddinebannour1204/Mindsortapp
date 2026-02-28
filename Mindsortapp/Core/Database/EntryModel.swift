//
//  EntryModel.swift
//  Mindsortapp
//

import Foundation
import SwiftData

@Model
final class EntryModel {
    @Attribute(.unique) var id: String
    var userID: String
    var transcript: String
    var title: String?
    var categoryID: String?
    var color: String?
    var createdAt: Date
    var syncStatusRaw: String
    var locale: String?

    init(
        id: String,
        userID: String,
        transcript: String,
        title: String? = nil,
        categoryID: String? = nil,
        color: String? = nil,
        createdAt: Date = Date(),
        syncStatus: SyncStatus = .synced,
        locale: String? = nil
    ) {
        self.id = id
        self.userID = userID
        self.transcript = transcript
        self.title = title
        self.categoryID = categoryID
        self.color = color
        self.createdAt = createdAt
        self.syncStatusRaw = syncStatus.rawValue
        self.locale = locale
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .synced }
        set { syncStatusRaw = newValue.rawValue }
    }
}
