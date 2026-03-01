//
//  PendingEntryBlock.swift
//  Mindsortapp
//
//  Displays a newly arrived entry that hasn't been merged into the note yet.
//  The user can "Keep" it (merge into note body) or "Move to..." (reassign to another category).
//

import SwiftUI

struct PendingEntryBlock: View {
    let entry: EntryModel
    let onKeep: () -> Void
    let onMove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("NEW")
                    .font(Theme.Typography.caption())
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.accent)
                    .clipShape(Capsule())

                Spacer()

                Text(entry.createdAt, style: .relative)
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            Text(entry.transcript)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.text)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.md) {
                Button(action: onMove) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "arrow.right.circle")
                        Text("Move to…")
                    }
                    .font(Theme.Typography.bodySmall())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button(action: onKeep) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Keep")
                    }
                    .font(Theme.Typography.bodySmall())
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Colors.accent.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("New thought: \(entry.transcript). Tap Keep to merge or Move to reassign.")
    }
}
