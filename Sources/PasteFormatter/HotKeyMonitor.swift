import Carbon.HIToolbox
import Foundation
import PasteFormatterUI

@MainActor
final class HotKeyMonitor {
    private let signature = HotKeyMonitor.fourCharCode("CLNP")
    private let action: @MainActor () -> Void

    private var currentShortcut: KeyboardShortcut?
    private var hotKeyReference: EventHotKeyRef?
    private var eventHandlerReference: EventHandlerRef?
    private var isShortcutSuspended = false

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    func start(with shortcut: KeyboardShortcut) {
        installEventHandlerIfNeeded()
        updateShortcut(shortcut)
    }

    func canRegisterShortcut(_ shortcut: KeyboardShortcut) -> Bool {
        installEventHandlerIfNeeded()

        guard currentShortcut != shortcut else {
            return true
        }

        let previousShortcut = currentShortcut
        let shouldRestorePreviousShortcut = !isShortcutSuspended
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
            self.hotKeyReference = nil
        }

        var probeReference: EventHotKeyRef?
        let probeHotKeyID = EventHotKeyID(signature: signature, id: 2)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            probeHotKeyID,
            GetApplicationEventTarget(),
            0,
            &probeReference
        )

        if let probeReference {
            UnregisterEventHotKey(probeReference)
        }

        if shouldRestorePreviousShortcut, let previousShortcut {
            _ = register(previousShortcut, id: 1, reference: &hotKeyReference)
        }

        return status == noErr
    }

    func suspendShortcut() {
        isShortcutSuspended = true

        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
            self.hotKeyReference = nil
        }
    }

    func resumeShortcut() {
        isShortcutSuspended = false

        guard hotKeyReference == nil, let currentShortcut else {
            return
        }

        _ = register(currentShortcut, id: 1, reference: &hotKeyReference)
    }

    @discardableResult
    func updateShortcut(_ shortcut: KeyboardShortcut) -> Bool {
        installEventHandlerIfNeeded()

        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
            self.hotKeyReference = nil
        }

        let status = register(shortcut, id: 1, reference: &hotKeyReference)

        guard status == noErr else {
            return false
        }

        isShortcutSuspended = false
        currentShortcut = shortcut
        return true
    }

    func stop() {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
            self.hotKeyReference = nil
        }

        if let eventHandlerReference {
            RemoveEventHandler(eventHandlerReference)
            self.eventHandlerReference = nil
        }

        currentShortcut = nil
    }

    private static let hotKeyHandler: EventHandlerUPP = { _, event, userData in
        guard
            let event,
            let userData
        else {
            return noErr
        }

        let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()
        var hotKeyID = EventHotKeyID()

        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.signature == monitor.signature, hotKeyID.id == 1 else {
            return noErr
        }

        MainActor.assumeIsolated {
            monitor.action()
        }

        return noErr
    }

    private static func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { partialResult, byte in
            (partialResult << 8) + OSType(byte)
        }
    }

    private func register(
        _ shortcut: KeyboardShortcut,
        id: UInt32,
        reference: inout EventHotKeyRef?
    ) -> OSStatus {
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        return RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerReference == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.hotKeyHandler,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerReference
        )
    }
}
