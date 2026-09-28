import UIKit

/// Screen rotation setting: follow the phone, or lock to how the bar mount holds it.
enum OrientationLock: String, CaseIterable {
    case auto, portrait, landscape

    var mask: UIInterfaceOrientationMask {
        switch self {
        case .auto: .allButUpsideDown
        case .portrait: .portrait
        case .landscape: .landscape // either way round, whichever way the mount faces
        }
    }

    var icon: String {
        switch self {
        case .auto: "rotate.right"
        case .portrait: "rectangle.portrait"
        case .landscape: "rectangle"
        }
    }

    var next: OrientationLock {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    /// Tell iOS which orientations are allowed now and rotate if needed.
    func apply() {
        AppDelegate.orientationMask = mask
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
    }
}

/// SwiftUI has no orientation lock of its own; iOS asks the app delegate.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationMask: UIInterfaceOrientationMask = .allButUpsideDown

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.orientationMask
    }
}
