//
//  SearchBar.swift
//  Mindsortapp
//

import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    init(
        text: Binding<String>,
        placeholder: String = "Search",
        onSubmit: @escaping () -> Void = {}
    ) {
        _text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Colors.textTertiary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
}
