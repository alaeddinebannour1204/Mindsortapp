//
//  CategoryLastSeen.swift
//  Mindsortapp
//

import Foundation
import SwiftData

@Model
final class CategoryLastSeen {
    @Attribute(.unique) var categoryID: String
    var userID: String
    var lastSeenAt: Date

    init(categoryID: String, userID: String, lastSeenAt: Date = Date()) {
        self.categoryID = categoryID
        self.userID = userID
        self.lastSeenAt = lastSeenAt
    }
}
