//
//  ComfyPrompterApp.swift
//  ComfyPrompter
//
//  Created by Aryan Rogye on 10/25/26.
//

import SwiftUI

@main
struct ComfyPrompterApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ComfyPrompterView()
            }
            .environment(appDelegate.appModel)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    let appModel = AppModel()
    var appCoordinator: AppCoordinator?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        appCoordinator = AppCoordinator(appModel: appModel)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        return true
    }

    public func applicationWillTerminate(_ notification: Notification) {
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

@MainActor
class AppCoordinator {

    let appModel: AppModel
    let preloadGazeCoordinator: PreloadGazeCoordinator
    let testGazeCoordinator: TestGazeCoordinator

    private let preloadGazeViewModel = PreloadGazeViewModel()

    init(
        appModel: AppModel
    ) {
        self.appModel = appModel
        self.preloadGazeCoordinator = .init(vm: preloadGazeViewModel)
        self.testGazeCoordinator = .init()
        assignClosures()
    }

    private func assignClosures() {

        appModel.onBeginPreloadGaze = { [weak self] in
            guard let self else { return }
            self.preloadGazeCoordinator.show()
        }
        appModel.onTestingGaze = { [weak self] isTestingGaze, eyeInfo in
            guard let self else { return }
            if isTestingGaze,
               let topLeft = appModel.topLeft,
               let topRight = appModel.topRight,
               let bottomLeft = appModel.bottomLeft,
               let bottomRight = appModel.bottomRight,
               let eyeInfo {
                self.testGazeCoordinator.show(
                    topLeft: topLeft,
                    topRight: topRight,
                    bottomLeft: bottomLeft,
                    bottomRight: bottomRight,
                    eyeInfo: eyeInfo
                )
            } else {
                self.testGazeCoordinator.hide()
            }
        }
        preloadGazeCoordinator.onCaptureGaze = { [weak self] gazeSide in
            guard let self else { return }
            self.appModel.storeGaze(gazeSide)
        }
    }
}

