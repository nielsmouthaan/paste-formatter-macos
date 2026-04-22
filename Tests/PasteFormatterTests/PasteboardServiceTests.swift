import AppKit
@testable import PasteFormatter
import PasteFormatterCore
import Foundation
import Testing

@MainActor
@Test func restoresOriginalClipboardWhenTemporaryContentIsStillPresent() {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteFormatterTests.\(UUID().uuidString)"))
    let service = PasteboardService(pasteboard: pasteboard)

    pasteboard.clearContents()
    #expect(pasteboard.setString("Original clipboard", forType: .string))

    let snapshot = service.captureSnapshot()

    let temporaryReceipt = service.write(
        .plainText("Temporary clipboard"),
        options: PasteFormattingOptions()
    )

    #expect(temporaryReceipt != nil)
    #expect(pasteboard.string(forType: .string) == "Temporary clipboard")

    let restored = service.restoreSnapshot(snapshot, ifMatches: temporaryReceipt!)

    #expect(restored)
    #expect(pasteboard.string(forType: .string) == "Original clipboard")
}

@MainActor
@Test func doesNotRestoreClipboardIfItChangedAfterTemporaryPaste() {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteFormatterTests.\(UUID().uuidString)"))
    let service = PasteboardService(pasteboard: pasteboard)

    pasteboard.clearContents()
    #expect(pasteboard.setString("Original clipboard", forType: .string))

    let snapshot = service.captureSnapshot()

    let temporaryReceipt = service.write(
        .plainText("Temporary clipboard"),
        options: PasteFormattingOptions()
    )

    #expect(temporaryReceipt != nil)
    pasteboard.clearContents()
    #expect(pasteboard.setString("User changed clipboard", forType: .string))

    let restored = service.restoreSnapshot(snapshot, ifMatches: temporaryReceipt!)

    #expect(!restored)
    #expect(pasteboard.string(forType: .string) == "User changed clipboard")
}
