//
//  DismissedDefaultCategory.swift
//  Mindsortapp
//

import Foundation
import SwiftData

@Model
final class DismissedDefaultCategory {
    @Attribute(.unique) var id: String
    var userID: String
    var name: String

    init(id: String, userID: String, name: String) {
        self.id = id
        self.userID = userID
        self.name = name
    }
}
