//
//  UndoToast.swift
//  Mindsortapp
//

import SwiftUI

struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(Theme.Typography.bodySmall())
                .foregroundStyle(.white)
            Spacer()
            Button("Undo", action: onUndo)
                .font(Theme.Typography.label())
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .accessibilityHint("Restores the deleted entry")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm + 2)
        .background(Theme.Colors.text.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.xxl + Theme.Spacing.md)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message). Undo available.")
    }
}
