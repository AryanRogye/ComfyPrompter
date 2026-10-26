//
//  PanelCoordinator.swift
//  ComfyPrompter
//
//  Created by Aryan Rogye on 10/26/26.
//

import AppKit
import SwiftUI

@MainActor
class PanelCoordinator<T: View> {
    var panel : NSPanel!
    var view: T
    var screen: NSScreen?

    init(view: T) {
        self.view = view
    }

    @MainActor
    func setupPanel() {
        guard let screen = NSScreen.screens.first(where: {
            $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            == CGMainDisplayID()
        }) else { return }

        self.screen = screen

        panel = FocusablePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.setFrame(screen.frame, display: true)
        /// Allow content to draw outside panel bounds
        panel.contentView?.wantsLayer = true

        panel.registerForDraggedTypes([.fileURL])
        panel.title = "SS"
        panel.acceptsMouseMovedEvents = true

        let overlayRaw = CGWindowLevelForKey(.overlayWindow)
        panel.level = NSWindow.Level(rawValue: Int(overlayRaw))

        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .fullScreenDisallowsTiling,
            .ignoresCycle,
            .transient
        ]

        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none

        let view: NSView = NSHostingView(
            rootView: view
        )

        /// Allow hosting view to overflow
        view.wantsLayer = true
        view.layer?.masksToBounds = false

        panel.contentView = view
        panel.makeKeyAndOrderFront(nil)
    }
}
