//
//  SyncCoordinatorEnvironment.swift
//  Mindsortapp
//

import SwiftUI

private struct SyncCoordinatorKey: EnvironmentKey {
    static let defaultValue: SyncCoordinator? = nil
}

extension EnvironmentValues {
    var syncCoordinator: SyncCoordinator? {
        get { self[SyncCoordinatorKey.self] }
        set { self[SyncCoordinatorKey.self] = newValue }
    }
}
