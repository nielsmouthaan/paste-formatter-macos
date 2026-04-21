import AppKit
import CleanPasteCore
import Foundation
import Testing

@Test func defaultOptionsStripFontsAndColorsButKeepLinks() {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center

    let input = NSMutableAttributedString(string: "CleanPaste")
    let fullRange = NSRange(location: 0, length: input.length)
    input.addAttributes([
        .font: NSFont.systemFont(ofSize: 18, weight: .bold),
        .foregroundColor: NSColor.systemRed,
        .backgroundColor: NSColor.systemYellow,
        .link: URL(string: "https://example.com") as Any,
        .paragraphStyle: paragraphStyle
    ], range: fullRange)

    let output = RichTextCleaner.clean(input, options: PasteFormattingOptions())
    let attributes = output.attributes(at: 0, effectiveRange: nil)

    #expect(attributes[.font] == nil)
    #expect(attributes[.foregroundColor] == nil)
    #expect(attributes[.backgroundColor] == nil)
    #expect(attributes[.link] != nil)
    #expect((attributes[.paragraphStyle] as? NSParagraphStyle)?.alignment == .center)
}

@Test func canRemoveLinksWhenConfigured() {
    let input = NSMutableAttributedString(string: "Link")
    input.addAttribute(
        .link,
        value: URL(string: "https://example.com") as Any,
        range: NSRange(location: 0, length: input.length)
    )

    let output = RichTextCleaner.clean(
        input,
        options: PasteFormattingOptions(preserveFont: false, preserveColors: false, preserveLinks: false)
    )

    #expect(output.attributes(at: 0, effectiveRange: nil)[.link] == nil)
    #expect(output.string == "Link")
}

@Test func canPreserveFontAndColors() {
    let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    let input = NSMutableAttributedString(string: "Styled")
    input.addAttributes([
        .font: font,
        .foregroundColor: NSColor.systemBlue,
        .backgroundColor: NSColor.systemMint
    ], range: NSRange(location: 0, length: input.length))

    let output = RichTextCleaner.clean(
        input,
        options: PasteFormattingOptions(preserveFont: true, preserveColors: true, preserveLinks: true)
    )
    let attributes = output.attributes(at: 0, effectiveRange: nil)

    #expect((attributes[.font] as? NSFont) == font)
    #expect(attributes[.foregroundColor] as? NSColor == NSColor.systemBlue)
    #expect(attributes[.backgroundColor] as? NSColor == NSColor.systemMint)
}
