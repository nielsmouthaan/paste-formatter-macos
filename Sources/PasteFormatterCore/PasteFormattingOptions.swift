import Foundation

public struct PasteFormattingOptions: Sendable, Equatable {
    public var preserveFont: Bool
    public var preserveColors: Bool
    public var preserveLinks: Bool
    public var preserveParagraphBreaksInPlainText: Bool

    public init(
        preserveFont: Bool = false,
        preserveColors: Bool = false,
        preserveLinks: Bool = true,
        preserveParagraphBreaksInPlainText: Bool = true
    ) {
        self.preserveFont = preserveFont
        self.preserveColors = preserveColors
        self.preserveLinks = preserveLinks
        self.preserveParagraphBreaksInPlainText = preserveParagraphBreaksInPlainText
    }
}
