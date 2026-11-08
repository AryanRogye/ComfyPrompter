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
        }
    }
}

public class AppDelegate: NSObject, NSApplicationDelegate {

    var appCoordinator: AppCoordinator?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        appCoordinator = AppCoordinator()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        appCoordinator?.openApp()
        return true
    }

    public func applicationWillTerminate(_ notification: Notification) {
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

final class AppCoordinator {
    public func openApp() {

    }
}
