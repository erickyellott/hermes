import AppKit
import SwiftUI

/// Listens for scrollWheel events while the host view is in the window
/// and the window is key. Uses a local NSEvent monitor so it doesn't
/// interfere with hit testing or the responder chain.
struct ScrollEventHandlerView: NSViewRepresentable {
    let onScroll: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        context.coordinator.onScroll = onScroll
        context.coordinator.installMonitor()
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onScroll = onScroll
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var onScroll: ((NSEvent) -> Void)?
        private var monitor: Any?

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.onScroll?(event)
                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        deinit { removeMonitor() }
    }
}

extension View {
    func onScrollWheel(_ handler: @escaping (NSEvent) -> Void) -> some View {
        background(ScrollEventHandlerView(onScroll: handler))
    }
}
