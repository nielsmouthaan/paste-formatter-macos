import AppKit
import Foundation

public enum PlainTextFormatter {
    public static func string(
        from input: NSAttributedString,
        options: PasteFormattingOptions
    ) -> String {
        let normalizedPlainText = normalizedLineSeparators(in: input.string)

        guard options.preserveParagraphBreaksInPlainText else {
            return normalizedPlainText
        }

        let source = input.string as NSString
        guard source.length > 0 else {
            return ""
        }

        let result = NSMutableString(string: normalizedPlainText)
        var insertedCharacters = 0
        var location = 0

        while location < source.length {
            let paragraphRange = source.paragraphRange(for: NSRange(location: location, length: 0))

            if usesExpandedParagraphBreak(beforeParagraphAt: paragraphRange.location, in: input) {
                let insertionIndex = paragraphRange.location + insertedCharacters
                result.insert("\n", at: insertionIndex)
                insertedCharacters += 1
            }

            location = NSMaxRange(paragraphRange)
        }

        return result as String
    }

    private static func normalizedLineSeparators(in string: String) -> String {
        string
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
    }

    private static func usesExpandedParagraphBreak(
        beforeParagraphAt location: Int,
        in input: NSAttributedString
    ) -> Bool {
        guard input.length > 0, location > 0 else {
            return false
        }

        let source = input.string as NSString
        let previousParagraphStart = source.paragraphRange(for: NSRange(location: location - 1, length: 0)).location
        let currentParagraphStart = source.paragraphRange(
            for: NSRange(location: min(location, max(source.length - 1, 0)), length: 0)
        ).location

        let previousStyle = input.attribute(
            .paragraphStyle,
            at: previousParagraphStart,
            effectiveRange: nil
        ) as? NSParagraphStyle

        let currentStyle = input.attribute(
            .paragraphStyle,
            at: currentParagraphStart,
            effectiveRange: nil
        ) as? NSParagraphStyle

        if isWithinSameTextList(previousStyle: previousStyle, currentStyle: currentStyle) {
            return false
        }

        return (previousStyle?.paragraphSpacing ?? 0) > 0 || (currentStyle?.paragraphSpacingBefore ?? 0) > 0
    }

    private static func isWithinSameTextList(
        previousStyle: NSParagraphStyle?,
        currentStyle: NSParagraphStyle?
    ) -> Bool {
        let previousSignature = textListSignature(for: previousStyle)
        let currentSignature = textListSignature(for: currentStyle)

        return previousSignature != nil && previousSignature == currentSignature
    }

    private static func textListSignature(for style: NSParagraphStyle?) -> String? {
        guard let textLists = style?.textLists, !textLists.isEmpty else {
            return nil
        }

        return textLists
            .map { "\($0.markerFormat)" }
            .joined(separator: "|")
    }
}
