//
//  CategoryPickerSheet.swift
//  Mindsortapp
//
//  Sheet for reassigning a pending entry to a different category.
//

import SwiftUI
import SwiftData

struct CategoryPickerSheet: View {
    let currentCategoryId: String
    let categories: [CategoryModel]
    let onSelect: (CategoryModel) -> Void
    let onCreateNew: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showCreateField = false
    @State private var newCategoryName = ""

    private var filteredCategories: [CategoryModel] {
        let available = categories.filter { $0.id != currentCategoryId && !$0.isArchived }
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return available
        }
        let q = searchText.lowercased()
        return available.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if showCreateField {
                    HStack {
                        TextField("New category name", text: $newCategoryName)
                            .font(Theme.Typography.body())
                        Button("Create") {
                            let name = newCategoryName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            onCreateNew(name)
                            dismiss()
                        }
                        .font(Theme.Typography.bodySmall())
                        .fontWeight(.medium)
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    Button {
                        showCreateField = true
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Theme.Colors.accent)
                            Text("New Category")
                                .font(Theme.Typography.body())
                                .foregroundStyle(Theme.Colors.accent)
                        }
                    }
                }

                ForEach(filteredCategories) { category in
                    Button {
                        onSelect(category)
                        dismiss()
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            if let hex = category.color {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 10, height: 10)
                            }
                            Text(category.name)
                                .font(Theme.Typography.body())
                                .foregroundStyle(Theme.Colors.text)
                            Spacer()
                            Text("\(category.entryCount) thoughts")
                                .font(Theme.Typography.caption())
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search categories")
            .navigationTitle("Move to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.Typography.bodySmall())
                }
            }
        }
    }
}
