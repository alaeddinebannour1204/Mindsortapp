//
//  RichTextEditor.swift
//  Mindsortapp
//
//  A UITextView wrapper that supports rich text editing with NSAttributedString.
//  Designed to feel like Apple Notes — always editable, auto-growing, with a
//  formatting toolbar attached above the keyboard.
//

import SwiftUI
import UIKit

// MARK: - RichTextEditor

struct RichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var plainText: String
    var placeholder: String = ""
    var onFocus: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isScrollEnabled = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsEditingTextAttributes = true
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Formatting toolbar
        textView.inputAccessoryView = FormattingToolbar.makeToolbar(for: textView, coordinator: context.coordinator)

        // Apply initial content
        if attributedText.length > 0 {
            textView.attributedText = attributedText
        }

        context.coordinator.textView = textView
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update if the attributed text changed externally (not from user typing)
        if !context.coordinator.isUpdating && textView.attributedText != attributedText {
            textView.attributedText = attributedText
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        var isUpdating = false
        weak var textView: UITextView?

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            isUpdating = true
            parent.attributedText = textView.attributedText
            parent.plainText = textView.text
            isUpdating = false
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFocus?()
        }

        // MARK: - Formatting actions

        func toggleBold() {
            toggleTrait(.traitBold)
        }

        func toggleItalic() {
            toggleTrait(.traitItalic)
        }

        func toggleUnderline() {
            guard let textView = textView else { return }
            let range = textView.selectedRange
            guard range.length > 0 else {
                // Toggle typing attributes for next character
                var attrs = textView.typingAttributes
                let current = attrs[.underlineStyle] as? Int ?? 0
                attrs[.underlineStyle] = current == 0 ? NSUnderlineStyle.single.rawValue : 0
                textView.typingAttributes = attrs
                return
            }
            let storage = textView.textStorage
            var hasUnderline = false
            storage.enumerateAttribute(.underlineStyle, in: range) { value, _, _ in
                if let v = value as? Int, v != 0 { hasUnderline = true }
            }
            storage.beginEditing()
            if hasUnderline {
                storage.removeAttribute(.underlineStyle, range: range)
            } else {
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            storage.endEditing()
            notifyChange()
        }

        func toggleStrikethrough() {
            guard let textView = textView else { return }
            let range = textView.selectedRange
            guard range.length > 0 else {
                var attrs = textView.typingAttributes
                let current = attrs[.strikethroughStyle] as? Int ?? 0
                attrs[.strikethroughStyle] = current == 0 ? NSUnderlineStyle.single.rawValue : 0
                textView.typingAttributes = attrs
                return
            }
            let storage = textView.textStorage
            var hasStrike = false
            storage.enumerateAttribute(.strikethroughStyle, in: range) { value, _, _ in
                if let v = value as? Int, v != 0 { hasStrike = true }
            }
            storage.beginEditing()
            if hasStrike {
                storage.removeAttribute(.strikethroughStyle, range: range)
            } else {
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            storage.endEditing()
            notifyChange()
        }

        func applyHeading(_ style: HeadingStyle) {
            guard let textView = textView else { return }
            let range = textView.selectedRange
            let paragraphRange = (textView.text as NSString).paragraphRange(for: range)

            let font: UIFont
            switch style {
            case .title:
                font = UIFont.systemFont(ofSize: 28, weight: .bold)
            case .heading:
                font = UIFont.systemFont(ofSize: 22, weight: .semibold)
            case .subheading:
                font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            case .body:
                font = UIFont.preferredFont(forTextStyle: .body)
            }

            let storage = textView.textStorage
            storage.beginEditing()
            storage.addAttribute(.font, value: font, range: paragraphRange)
            storage.endEditing()
            notifyChange()
        }

        func insertChecklist() {
            guard let textView = textView else { return }
            let location = textView.selectedRange.location
            let checkPrefix = "☐ "
            textView.textStorage.insert(NSAttributedString(string: checkPrefix, attributes: textView.typingAttributes), at: location)
            textView.selectedRange = NSRange(location: location + checkPrefix.count, length: 0)
            notifyChange()
        }

        func insertBulletList() {
            guard let textView = textView else { return }
            let location = textView.selectedRange.location
            let bulletPrefix = "• "
            textView.textStorage.insert(NSAttributedString(string: bulletPrefix, attributes: textView.typingAttributes), at: location)
            textView.selectedRange = NSRange(location: location + bulletPrefix.count, length: 0)
            notifyChange()
        }

        func dismissKeyboard() {
            textView?.resignFirstResponder()
        }

        // MARK: - Private

        private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
            guard let textView = textView else { return }
            let range = textView.selectedRange

            guard range.length > 0 else {
                // Toggle typing attributes
                var attrs = textView.typingAttributes
                let currentFont = attrs[.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
                let descriptor = currentFont.fontDescriptor
                let hasTrait = descriptor.symbolicTraits.contains(trait)
                if hasTrait {
                    if let newDesc = descriptor.withSymbolicTraits(descriptor.symbolicTraits.subtracting(trait)) {
                        attrs[.font] = UIFont(descriptor: newDesc, size: currentFont.pointSize)
                    }
                } else {
                    if let newDesc = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(trait)) {
                        attrs[.font] = UIFont(descriptor: newDesc, size: currentFont.pointSize)
                    }
                }
                textView.typingAttributes = attrs
                return
            }

            let storage = textView.textStorage
            var allHaveTrait = true
            storage.enumerateAttribute(.font, in: range) { value, _, _ in
                guard let font = value as? UIFont else { allHaveTrait = false; return }
                if !font.fontDescriptor.symbolicTraits.contains(trait) { allHaveTrait = false }
            }

            storage.beginEditing()
            storage.enumerateAttribute(.font, in: range) { value, subRange, _ in
                guard let font = value as? UIFont else { return }
                let descriptor = font.fontDescriptor
                let newTraits = allHaveTrait
                    ? descriptor.symbolicTraits.subtracting(trait)
                    : descriptor.symbolicTraits.union(trait)
                if let newDesc = descriptor.withSymbolicTraits(newTraits) {
                    let newFont = UIFont(descriptor: newDesc, size: font.pointSize)
                    storage.addAttribute(.font, value: newFont, range: subRange)
                }
            }
            storage.endEditing()
            notifyChange()
        }

        private func notifyChange() {
            guard let textView = textView else { return }
            isUpdating = true
            parent.attributedText = textView.attributedText
            parent.plainText = textView.text
            isUpdating = false
        }
    }
}

// MARK: - Heading styles

enum HeadingStyle: String, CaseIterable {
    case title = "Title"
    case heading = "Heading"
    case subheading = "Subheading"
    case body = "Body"
}

// MARK: - Formatting Toolbar

enum FormattingToolbar {
    static func makeToolbar(for textView: UITextView, coordinator: RichTextEditor.Coordinator) -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.barStyle = .default

        let headingButton = UIBarButtonItem(
            image: UIImage(systemName: "textformat.size"),
            menu: headingMenu(coordinator: coordinator)
        )
        headingButton.accessibilityLabel = "Text style"

        let boldButton = UIBarButtonItem(
            image: UIImage(systemName: "bold"),
            primaryAction: UIAction { _ in coordinator.toggleBold() }
        )
        boldButton.accessibilityLabel = "Bold"

        let italicButton = UIBarButtonItem(
            image: UIImage(systemName: "italic"),
            primaryAction: UIAction { _ in coordinator.toggleItalic() }
        )
        italicButton.accessibilityLabel = "Italic"

        let underlineButton = UIBarButtonItem(
            image: UIImage(systemName: "underline"),
            primaryAction: UIAction { _ in coordinator.toggleUnderline() }
        )
        underlineButton.accessibilityLabel = "Underline"

        let strikeButton = UIBarButtonItem(
            image: UIImage(systemName: "strikethrough"),
            primaryAction: UIAction { _ in coordinator.toggleStrikethrough() }
        )
        strikeButton.accessibilityLabel = "Strikethrough"

        let checklistButton = UIBarButtonItem(
            image: UIImage(systemName: "checklist"),
            primaryAction: UIAction { _ in coordinator.insertChecklist() }
        )
        checklistButton.accessibilityLabel = "Checklist"

        let bulletButton = UIBarButtonItem(
            image: UIImage(systemName: "list.bullet"),
            primaryAction: UIAction { _ in coordinator.insertBulletList() }
        )
        bulletButton.accessibilityLabel = "Bullet list"

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        let doneButton = UIBarButtonItem(
            image: UIImage(systemName: "keyboard.chevron.compact.down"),
            primaryAction: UIAction { _ in coordinator.dismissKeyboard() }
        )
        doneButton.accessibilityLabel = "Dismiss keyboard"

        toolbar.items = [
            headingButton,
            UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil).then { $0.width = 8 },
            boldButton,
            UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil).then { $0.width = 8 },
            italicButton,
            UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil).then { $0.width = 8 },
            underlineButton,
            UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil).then { $0.width = 8 },
            strikeButton,
            UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil).then { $0.width = 8 },
            checklistButton,
            UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil).then { $0.width = 8 },
            bulletButton,
            flexSpace,
            doneButton,
        ]

        return toolbar
    }

    private static func headingMenu(coordinator: RichTextEditor.Coordinator) -> UIMenu {
        UIMenu(title: "Text Style", children: HeadingStyle.allCases.map { style in
            UIAction(title: style.rawValue) { _ in
                coordinator.applyHeading(style)
            }
        })
    }
}

// MARK: - UIBarButtonItem helper

private extension UIBarButtonItem {
    func then(_ configure: (UIBarButtonItem) -> Void) -> UIBarButtonItem {
        configure(self)
        return self
    }
}

// MARK: - Rich text archiving helpers

enum RichTextArchiver {
    /// Archive NSAttributedString → Data for storage.
    static func archive(_ attributedString: NSAttributedString) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: attributedString, requiringSecureCoding: false)
    }

    /// Unarchive Data → NSAttributedString.
    static func unarchive(_ data: Data) -> NSAttributedString? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data)
    }

    /// Create an attributed string from plain text with body styling.
    static func fromPlainText(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label,
        ])
    }
}
