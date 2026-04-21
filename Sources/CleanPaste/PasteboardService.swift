import AppKit
import Foundation

enum ClipboardPayload {
    case attributed(NSAttributedString)
    case plainText(String)
}

@MainActor
struct PasteboardService {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func readCurrentContents() -> ClipboardPayload? {
        if let attributed = readAttributedString(for: .rtf, documentType: .rtf) {
            return .attributed(attributed)
        }

        if let attributed = readAttributedString(for: .html, documentType: .html) {
            return .attributed(attributed)
        }

        if let string = pasteboard.string(forType: .string) {
            return .plainText(string)
        }

        return nil
    }

    @discardableResult
    func write(_ payload: ClipboardPayload) -> Bool {
        pasteboard.clearContents()

        switch payload {
        case .attributed(let attributedString):
            let fullRange = NSRange(location: 0, length: attributedString.length)

            guard let rtfData = try? attributedString.data(
                from: fullRange,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ) else {
                return false
            }

            let wroteRichText = pasteboard.setData(rtfData, forType: .rtf)
            let wrotePlainText = pasteboard.setString(attributedString.string, forType: .string)
            return wroteRichText && wrotePlainText

        case .plainText(let string):
            return pasteboard.setString(string, forType: .string)
        }
    }

    private func readAttributedString(
        for pasteboardType: NSPasteboard.PasteboardType,
        documentType: NSAttributedString.DocumentType
    ) -> NSAttributedString? {
        guard let data = pasteboard.data(forType: pasteboardType) else {
            return nil
        }

        var options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: documentType
        ]

        if documentType == .html {
            options[.characterEncoding] = String.Encoding.utf8.rawValue
        }

        return try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        )
    }
}
