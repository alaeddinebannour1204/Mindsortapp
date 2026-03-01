//
//  AuthServiceEnvironment.swift
//  Mindsortapp
//

import SwiftUI

private struct AuthServiceKey: EnvironmentKey {
    static let defaultValue: AuthService? = nil
}

extension EnvironmentValues {
    var authService: AuthService? {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
}
