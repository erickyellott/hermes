import SwiftUI

struct KeyEventHandlerModifier: ViewModifier {
    let isActive: Bool
    let onKeyDown: (NSEvent) -> Void
    var onFlagsChanged: ((NSEvent) -> Void)?

    func body(content: Content) -> some View {
        content.background(
            KeyEventHandlerView(
                isActive: isActive,
                onKeyDown: onKeyDown,
                onFlagsChanged: onFlagsChanged
            )
        )
    }
}

extension View {
    func onKeyDown(
        isActive: Bool,
        _ handler: @escaping (NSEvent) -> Void,
        onFlagsChanged: @escaping (NSEvent) -> Void
    ) -> some View {
        modifier(
            KeyEventHandlerModifier(
                isActive: isActive,
                onKeyDown: handler,
                onFlagsChanged: onFlagsChanged
            )
        )
    }
}

struct KeyEventHandlerView: NSViewRepresentable {
    let isActive: Bool
    let onKeyDown: (NSEvent) -> Void
    var onFlagsChanged: ((NSEvent) -> Void)?

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyDown = onKeyDown
        view.onFlagsChanged = onFlagsChanged
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.onKeyDown = onKeyDown
        nsView.onFlagsChanged = onFlagsChanged
        if isActive && !context.coordinator.wasActive {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
        context.coordinator.wasActive = isActive
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var wasActive = false
    }
}

final class KeyCaptureView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?
    var onFlagsChanged: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }

    override func flagsChanged(with event: NSEvent) {
        onFlagsChanged?(event)
    }
}
