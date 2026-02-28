//
//  APIServiceEnvironment.swift
//  Mindsortapp
//

import SwiftUI

private struct APIServiceKey: EnvironmentKey {
    static let defaultValue: APIService? = nil
}

extension EnvironmentValues {
    var apiService: APIService? {
        get { self[APIServiceKey.self] }
        set { self[APIServiceKey.self] = newValue }
    }
}
