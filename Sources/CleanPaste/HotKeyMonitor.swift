import Carbon.HIToolbox
import Foundation

@MainActor
final class HotKeyMonitor {
    private let signature = HotKeyMonitor.fourCharCode("CLNP")
    private let action: @MainActor () -> Void

    private var hotKeyReference: EventHotKeyRef?
    private var eventHandlerReference: EventHandlerRef?

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    func start() {
        guard hotKeyReference == nil else {
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

        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let modifiers = UInt32(controlKey) | UInt32(optionKey) | UInt32(cmdKey)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyReference
        )
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

        guard status == noErr, hotKeyID.signature == monitor.signature else {
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
}
