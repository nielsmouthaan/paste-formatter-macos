import AppKit
import PasteFormatterCore
import Foundation
import Testing

@Test func preservesDefaultPlainTextWhenParagraphBreakExpansionIsDisabled() {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacing = 18

    let input = NSMutableAttributedString(string: "First paragraph\nSecond paragraph")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: input.length)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions(preserveParagraphBreaksInPlainText: false)
    )

    #expect(output == "First paragraph\nSecond paragraph")
}

@Test func expandsParagraphBreaksWhenSourceUsesParagraphSpacing() {
    let firstParagraphStyle = NSMutableParagraphStyle()
    firstParagraphStyle.paragraphSpacing = 14

    let input = NSMutableAttributedString(string: "First paragraph\nSecond paragraph")
    input.addAttribute(
        .paragraphStyle,
        value: firstParagraphStyle,
        range: NSRange(location: 0, length: "First paragraph".count)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "First paragraph\n\nSecond paragraph")
}

@Test func keepsSingleParagraphBreaksWhenNoParagraphSpacingExists() {
    let input = NSAttributedString(string: "First paragraph\nSecond paragraph")

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "First paragraph\nSecond paragraph")
}

@Test func preservesExistingPlainTextContentWhileAddingParagraphBreaks() {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacing = 14

    let input = NSMutableAttributedString(string: "\u{2022}\tFirst item\nSecond paragraph")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: "\u{2022}\tFirst item".count)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "\u{2022}\tFirst item\n\nSecond paragraph")
}

@Test func doesNotExpandParagraphBreaksBetweenItemsInSameTextList() {
    let list = NSTextList(markerFormat: .disc, options: 0)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacing = 14
    paragraphStyle.textLists = [list]

    let input = NSMutableAttributedString(string: "\u{2022} First item\n\u{2022} Second item")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: input.length)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "\u{2022} First item\n\u{2022} Second item")
}

@Test func stillExpandsParagraphBreaksWhenEnteringOrLeavingATextList() {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacing = 14

    let list = NSTextList(markerFormat: .disc, options: 0)
    let listStyle = NSMutableParagraphStyle()
    listStyle.textLists = [list]

    let input = NSMutableAttributedString(string: "Intro paragraph\n\u{2022} First item")
    input.addAttribute(
        .paragraphStyle,
        value: paragraphStyle,
        range: NSRange(location: 0, length: "Intro paragraph".count)
    )
    input.addAttribute(
        .paragraphStyle,
        value: listStyle,
        range: NSRange(location: "Intro paragraph\n".count, length: "\u{2022} First item".count)
    )

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "Intro paragraph\n\n\u{2022} First item")
}

@Test func normalizesUnicodeLineSeparatorsToPlainNewlines() {
    let input = NSAttributedString(string: "Bien cordialement,\u{2028}Niels")

    let output = PlainTextFormatter.string(
        from: input,
        options: PasteFormattingOptions()
    )

    #expect(output == "Bien cordialement,\nNiels")
}
