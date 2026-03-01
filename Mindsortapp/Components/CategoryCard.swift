//
//  CategoryCard.swift
//  Mindsortapp
//

import SwiftUI
import SwiftData

struct CategoryCard: View {
    let category: CategoryModel
    let inboxCount: Int?
    let showNewBadge: Bool
    let isSelected: Bool

    init(
        category: CategoryModel,
        inboxCount: Int? = nil,
        showNewBadge: Bool = false,
        isSelected: Bool = false
    ) {
        self.category = category
        self.inboxCount = inboxCount
        self.showNewBadge = showNewBadge
        self.isSelected = isSelected
    }

    var body: some View {
            HStack(spacing: Theme.Spacing.md) {
                if let hex = category.color {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 10, height: 10)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        Text(category.name)
                            .font(Theme.Typography.h3())
                            .foregroundStyle(Theme.Colors.text)
                        if showNewBadge {
                            Text("NEW")
                                .font(Theme.Typography.caption())
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.accent)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(category.entryCount) thoughts")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(Theme.Typography.bodySmall())
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(Theme.Spacing.md)
            .background(isSelected ? Theme.Colors.accentLight : Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Theme.Colors.accent : Theme.Colors.border, lineWidth: isSelected ? 2 : 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(category.name), \(category.entryCount) thoughts\(showNewBadge ? ", new" : "")")
    }
}
