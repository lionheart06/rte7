//
//  GlobalEventMonitor.swift
//  kitkat
//
//  Created by Richard El-Kadi on 2/23/26.
//


//
//  GlobalEventMonitor.swift
//  rte7
//
//  Created by Richard El Kadi on 6/4/24.
//

import Cocoa
import ApplicationServices

enum KeyboardAccessStatus: Equatable {
    case connected
    case disconnected

    var iconSystemName: String {
        switch self {
        case .connected:
            return "keyboard.fill"
        case .disconnected:
            return "keyboard.badge.exclamationmark"
        }
    }

    var accessibilityText: String {
        switch self {
        case .connected:
            return "Keyboard access: On"
        case .disconnected:
            return "Keyboard access: Off"
        }
    }
}

protocol GlobalEventMonitorDelegate: AnyObject {
    func globalEventMonitor(
        _ monitor: GlobalEventMonitor,
        didUpdateKeyboardAccessStatus status: KeyboardAccessStatus
    )
}

protocol KeyboardAccessTrustChecking {
    func isKeyboardAccessTrusted(promptIfNeeded: Bool) -> Bool
}

struct AXKeyboardAccessTrustChecker: KeyboardAccessTrustChecking {
    func isKeyboardAccessTrusted(promptIfNeeded: Bool) -> Bool {
        if promptIfNeeded {
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options: CFDictionary = [promptKey: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }
}

protocol KeyboardAccessMonitoring: AnyObject {
    var delegate: GlobalEventMonitorDelegate? { get set }
    func start()
    func stop()
    func refreshKeyboardAccessStatus(promptForPermission: Bool)
}

final class GlobalEventMonitor: KeyboardAccessMonitoring {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let counter: CountDownTimer
    private let trustChecker: KeyboardAccessTrustChecking
    weak var delegate: GlobalEventMonitorDelegate?

    init(counter: CountDownTimer, trustChecker: KeyboardAccessTrustChecking = AXKeyboardAccessTrustChecker()) {
        self.counter = counter
        self.trustChecker = trustChecker
    }

    func start() {
        counter.continueCounter()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.counter.continueCounter()
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .keyUp],
            handler: { event in self.handleKeyboardEvent(event) }
        )
        Logger.shared.log("GlobalMonitor added")
        refreshKeyboardAccessStatus(promptForPermission: true)
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    func refreshKeyboardAccessStatus(promptForPermission: Bool = false) {
        let trusted = trustChecker.isKeyboardAccessTrusted(promptIfNeeded: promptForPermission)
        let status: KeyboardAccessStatus = trusted ? .connected : .disconnected
        delegate?.globalEventMonitor(self, didUpdateKeyboardAccessStatus: status)
        if trusted {
            Logger.shared.log("KitKat is allowed to listen to keyboard input")
        } else {
            Logger.shared.log("KitKat is NOT ALLOWED to listen to keyboard input")
        }
    }

    private func handleKeyboardEvent(_ event: NSEvent) {
        counter.continueCounter()
        Logger.shared.log("Keyboard is Clicked")
    }
}
 
