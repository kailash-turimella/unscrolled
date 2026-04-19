import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var bubbleSetUp = false

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(
            rootView: ContentView().environmentObject(SessionManager.shared)
        )
        self.window = window
        window.makeKeyAndVisible()

        if connectionOptions.urlContexts.contains(where: { $0.url.host == "factcheck" }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: .openFactCheck, object: nil)
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard URLContexts.contains(where: { $0.url.host == "factcheck" }) else { return }
        SessionManager.shared.loadLatestFrame()
        NotificationCenter.default.post(name: .openFactCheck, object: nil)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        if !bubbleSetUp {
            bubbleSetUp = true
            BubbleWindowManager.shared.setup(with: windowScene)
        }
        if SessionManager.shared.isSessionActive {
            BubbleWindowManager.shared.show()
        }
        SessionManager.shared.startBroadcastPolling()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        SessionManager.shared.stopBroadcastPolling()
    }
}
