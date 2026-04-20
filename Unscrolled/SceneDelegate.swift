import UIKit
import SwiftUI
import SwiftData

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let context = ModelContext(AppDelegate.modelContainer)
        SessionManager.shared.configure(modelContext: context)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(
            rootView: ContentView()
                .environmentObject(SessionManager.shared)
                .modelContainer(AppDelegate.modelContainer)
        )
        self.window = window
        window.makeKeyAndVisible()

        if connectionOptions.urlContexts.contains(where: { $0.url.host == "factcheck" }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SessionManager.shared.captureFactCheckFrame()
                NotificationCenter.default.post(name: .openFactCheck, object: nil)
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard URLContexts.contains(where: { $0.url.host == "factcheck" }) else { return }
        SessionManager.shared.captureFactCheckFrame()
        NotificationCenter.default.post(name: .openFactCheck, object: nil)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        SessionManager.shared.startBroadcastPolling()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        SessionManager.shared.stopBroadcastPolling()
    }
}
