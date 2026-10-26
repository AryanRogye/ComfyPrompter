//
//  PreloadGazeCoordinator.swift
//  ComfyPrompter
//
//  Created by Aryan Rogye on 10/26/26.
//

import AppKit

final class PreloadGazeCoordinator: PanelCoordinator<PreloadGazeView> {

    private let vm: PreloadGazeViewModel
    private var localMonitor: Any?
    private var globalMonitor: Any?

    init(vm: PreloadGazeViewModel) {
        self.vm = vm
        super.init(view: PreloadGazeView(vm: vm))
    }

    var onCaptureGaze: ((GazeSide) -> Void)?

    public func show() {
        if panel == nil { setupPanel() }

        panel.makeKeyAndOrderFront(nil)
        installKeyMonitors()
    }

    public func hide() {
        removeKeyMonitors()
        panel?.orderOut(nil)
    }
}

// MARK: - Monitors
extension PreloadGazeCoordinator {

    private func removeKeyMonitors() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
    }

    private func installKeyMonitors() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            handleEvent(event)
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            handleEvent(event)
        }
    }

    private func handleEvent(_ event: NSEvent) {
        if event.keyCode == 49 {
            if vm.gazeTestBegin {
                /// we'll handle this here
                onCaptureGaze?(vm.gazeSide)
                vm.gazeSide.next()
                if vm.gazeSide == .none {
                    /// this means we're done
                    self.hide()
                }
            }
        }
    }

}
