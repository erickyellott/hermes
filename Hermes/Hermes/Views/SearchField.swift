import AppKit
import SwiftUI

struct SearchField: View {
    @Binding var text: String
    let shouldFocus: Bool
    var onEscape: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.5))
                .font(.system(size: 16))

            SearchTextField(text: $text, shouldFocus: shouldFocus, onEscape: onEscape)

            if !text.isEmpty {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.4))
                    .onTapGesture { text = "" }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    let shouldFocus: Bool
    var onEscape: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 16)
        field.textColor = .white.withAlphaComponent(0.9)
        field.placeholderAttributedString = NSAttributedString(
            string: "Type to search apps\u{2026}",
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.4),
                .font: NSFont.systemFont(ofSize: 16),
            ]
        )
        if shouldFocus {
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
            }
        }
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        context.coordinator.parent = self
        if shouldFocus && !context.coordinator.wasFocused {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
        context.coordinator.wasFocused = shouldFocus
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchTextField
        var wasFocused = false

        init(_ parent: SearchTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            if let field = obj.object as? NSTextField,
                let editor = field.currentEditor() as? NSTextView
            {
                editor.insertionPointColor = .white.withAlphaComponent(0.8)
            }
        }

        func control(
            _ control: NSControl, textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
                return true
            }
            return false
        }
    }
}
