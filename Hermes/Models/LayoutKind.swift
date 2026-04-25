import Foundation

enum LayoutKind: String, Codable, CaseIterable, Identifiable {
    case leftTwoThirds
    case rightOneThird
    case leftHalf
    case rightHalf
    case maximize

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .leftTwoThirds: return "Left 2/3"
        case .rightOneThird: return "Right 1/3"
        case .leftHalf: return "Left 1/2"
        case .rightHalf: return "Right 1/2"
        case .maximize: return "Maximize"
        }
    }

    // Index used as Carbon hotkey ID in the "HMWL" signature space
    var hotkeyIndex: UInt32 {
        switch self {
        case .leftTwoThirds: return 0
        case .rightOneThird: return 1
        case .leftHalf: return 2
        case .rightHalf: return 3
        case .maximize: return 4
        }
    }

    func frame(in visibleFrame: CGRect) -> CGRect {
        switch self {
        case .leftTwoThirds:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width * 2 / 3,
                height: visibleFrame.height)
        case .rightOneThird:
            return CGRect(
                x: visibleFrame.minX + visibleFrame.width * 2 / 3,
                y: visibleFrame.minY,
                width: visibleFrame.width / 3,
                height: visibleFrame.height)
        case .leftHalf:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height)
        case .rightHalf:
            return CGRect(
                x: visibleFrame.minX + visibleFrame.width / 2,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height)
        case .maximize:
            return visibleFrame
        }
    }
}

// Grouped for display on the resize page
let layoutGroups: [[LayoutKind]] = [
    [.leftTwoThirds, .rightOneThird],
    [.leftHalf, .rightHalf],
    [.maximize],
]
