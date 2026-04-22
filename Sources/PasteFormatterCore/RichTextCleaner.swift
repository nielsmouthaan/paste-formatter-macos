import AppKit
import Foundation

public enum RichTextCleaner {
    public static func clean(
        _ input: NSAttributedString,
        options: PasteFormattingOptions
    ) -> NSAttributedString {
        let output = NSMutableAttributedString(attributedString: input)
        let fullRange = NSRange(location: 0, length: input.length)

        input.enumerateAttributes(in: fullRange) { attributes, range, _ in
            if !options.preserveFont, attributes[.font] != nil {
                output.removeAttribute(.font, range: range)
            }

            if !options.preserveColors {
                if attributes[.foregroundColor] != nil {
                    output.removeAttribute(.foregroundColor, range: range)
                }

                if attributes[.backgroundColor] != nil {
                    output.removeAttribute(.backgroundColor, range: range)
                }
            }

            if !options.preserveLinks, attributes[.link] != nil {
                output.removeAttribute(.link, range: range)
            }
        }

        return output
    }
}
