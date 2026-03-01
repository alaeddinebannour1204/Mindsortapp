//
//  EntryCard.swift
//  Mindsortapp
//

import SwiftUI
import SwiftData

struct EntryCard: View {
    @Environment(AppStore.self) private var store
    let entry: EntryModel
    let isEditing: Bool
    let onChange: (String, String) -> Void
    let onDelete: () -> Void
    let onColorTap: () -> Void

    @State private var localTitle: String
    @State private var localTranscript: String

    init(
        entry: EntryModel,
        isEditing: Bool,
        onChange: @escaping (String, String) -> Void,
        onDelete: @escaping () -> Void,
        onColorTap: @escaping () -> Void = {}
    ) {
        self.entry = entry
        self.isEditing = isEditing
        self.onChange = onChange
        self.onDelete = onDelete
        self.onColorTap = onColorTap
        _localTitle = State(initialValue: entry.title ?? "")
        _localTranscript = State(initialValue: entry.transcript)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                Button(action: onColorTap) {
                    Circle()
                        .fill(colorDot)
                        .frame(width: 10, height: 10)
                }
                .buttonStyle(.plain)

                if isEditing {
                    TextField(store.t("entry.title"), text: $localTitle)
                        .font(Theme.Typography.h3())
                        .onChange(of: localTitle) { _ in
                            notifyChange()
                        }
                } else {
                    Text(localTitle.isEmpty ? store.t("entry.untitled") : localTitle)
                        .font(Theme.Typography.h3())
                        .foregroundStyle(Theme.Colors.text)
                        .lineLimit(1)
                }

                Spacer()
            }

            if isEditing {
                TextEditor(text: $localTranscript)
                    .font(Theme.Typography.body())
                    .frame(minHeight: 80)
                    .onChange(of: localTranscript) { _ in
                        notifyChange()
                    }
            } else {
                Text(localTranscript.isEmpty ? store.t("entry.empty") : localTranscript)
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: isEditing ? .contain : .combine)
        .accessibilityLabel(isEditing ? "" : "\(localTitle.isEmpty ? store.t("entry.untitled") : localTitle). \(localTranscript)")
        .accessibilityHint(isEditing ? "" : store.t("entry.tapToEdit"))
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label(store.t("common.delete"), systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label(store.t("common.delete"), systemImage: "trash")
            }
        }
    }

    private var colorDot: Color {
        if let hex = entry.color {
            return Color(hex: hex)
        }
        return Theme.Colors.textTertiary
    }

    private func notifyChange() {
        onChange(localTitle, localTranscript)
    }
}
