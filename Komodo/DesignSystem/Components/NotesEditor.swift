import AppKit
import SwiftUI

/// Rich-text notes (DESIGN_SYSTEM §10.6, FEATURES §4.5): a wrapped `NSTextView` stored as RTF, with Bold · Italic ·
/// Underline · Strikethrough · Link · Bulleted list · Numbered list and **✕ Clear**. Every edit reports the plain
/// text (for search and links) and the RTF (for the editor). Give it `.id(taskID)` so a new task loads fresh text.
struct NotesEditor: View {
    var text: String
    var rtf: Data?
    var onChange: (_ text: String, _ rtf: Data?) -> Void

    @State private var controller = NotesEditorController()

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Space.s3, style: .continuous)
        VStack(spacing: 0) {
            NotesTextView(controller: controller, text: text, rtf: rtf, onChange: onChange)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 40, alignment: .top)
                .padding(.horizontal, Space.s3)
                .padding(.vertical, 10)
            toolbar
        }
        .background(Color.black.opacity(0.4), in: shape)
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }

    private var toolbar: some View {
        HStack(spacing: 2) {
            tool("Bold") {
                Text("B").fontWeight(.heavy)
            } action: {
                controller.toggle(.boldFontMask)
            }
            tool("Italic") {
                Text("I").italic()
            } action: {
                controller.toggle(.italicFontMask)
            }
            tool("Underline") {
                Text("U").underline()
            } action: {
                controller.toggle(.underlineStyle)
            }
            tool("Strikethrough") {
                Text("S").strikethrough()
            } action: {
                controller.toggle(.strikethroughStyle)
            }
            tool("Link") {
                Image(systemName: "link")
            } action: {
                controller.addLink()
            }
            tool("Bulleted list") {
                Image(systemName: "list.bullet")
            } action: {
                controller.toggleList(numbered: false)
            }
            tool("Numbered list") {
                Text("1.").font(.system(size: 11, weight: .bold))
            } action: {
                controller.toggleList(numbered: true)
            }
            Spacer(minLength: 0)
            Button(action: controller.clearFormatting) {
                Text("✕ Clear")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(Color.white.opacity(0.05), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Remove formatting")
        }
        .font(.system(size: 12, weight: .bold))
        .padding(.horizontal, Space.s2)
        .padding(.vertical, 6)
        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
    }

    private func tool(
        _ name: String, @ViewBuilder label: () -> some View, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { label().accessibilityLabel(name) }
            .buttonStyle(.icon(.compact))
            .help(name)
    }
}

/// The toolbar's side of the editor: it acts on whatever the text view has selected.
@MainActor final class NotesEditorController {
    weak var textView: NSTextView?

    static let baseFont = NSFont.systemFont(ofSize: 13)

    /// Bold or italic across the selection, or for what's typed next when nothing is selected.
    func toggle(_ trait: NSFontTraitMask) {
        let manager = NSFontManager.shared
        let hasTrait = { (font: NSFont) in manager.traits(of: font).contains(trait) }
        let convert = { (font: NSFont, adding: Bool) in
            adding ? manager.convert(font, toHaveTrait: trait) : manager.convert(font, toNotHaveTrait: trait)
        }
        apply(.font) { fonts in
            let adding = !fonts.allSatisfy { hasTrait(($0 as? NSFont) ?? Self.baseFont) }
            return { convert(($0 as? NSFont) ?? Self.baseFont, adding) }
        }
    }

    /// Underline or strikethrough on and off.
    func toggle(_ key: NSAttributedString.Key) {
        apply(key) { values in
            let adding = !values.allSatisfy { ($0 as? Int ?? 0) != 0 }
            return { _ in adding ? NSUnderlineStyle.single.rawValue : nil }
        }
    }

    /// The system link sheet, which links the selection to a URL.
    func addLink() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
        textView.orderFrontLinkPanel(nil)
    }

    // ponytail: lists are typed markers ("• ", "1. ") rather than NSTextList, so they survive plain-text export
    // as-is. Switch to NSTextList if nested lists are ever needed.
    func toggleList(numbered: Bool) {
        guard let textView, let storage = textView.textStorage else { return }
        let text = storage.string as NSString
        let lines = text.paragraphRange(for: textView.selectedRange())
        var starts: [Int] = []
        text.enumerateSubstrings(in: lines, options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in
            starts.append(range.location)
        }
        if starts.isEmpty { starts = [lines.location] }
        let marker = { (index: Int) in numbered ? "\(index + 1). " : "• " }
        let removing = starts.enumerated().allSatisfy { index, start in
            text.substring(from: start).hasPrefix(marker(index))
        }
        // Back to front, so earlier offsets stay valid as markers go in or out.
        for (index, start) in starts.enumerated().reversed() {
            let range =
                removing ? NSRange(location: start, length: marker(index).count) : NSRange(location: start, length: 0)
            let replacement = removing ? "" : marker(index)
            guard textView.shouldChangeText(in: range, replacementString: replacement) else { return }
            storage.replaceCharacters(in: range, with: replacement)
        }
        textView.didChangeText()
    }

    /// Plain text again: the selection, or the whole note when nothing is selected. Links are found again
    /// afterwards, so a bare URL stays clickable.
    func clearFormatting() {
        guard let textView, let storage = textView.textStorage else { return }
        let selected = textView.selectedRange()
        let range = selected.length > 0 ? selected : NSRange(location: 0, length: storage.length)
        guard textView.shouldChangeText(in: range, replacementString: nil) else { return }
        storage.setAttributes(NotesTextView.baseAttributes, range: range)
        textView.didChangeText()
        textView.checkTextInDocument(nil)
    }

    /// Changes one attribute over the selection. `decide` sees the current values and returns how to map each run;
    /// with no selection it changes the typing attributes instead.
    private func apply(
        _ key: NSAttributedString.Key, decide: ([Any?]) -> (Any?) -> Any?
    ) {
        guard let textView, let storage = textView.textStorage else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else {
            let current = textView.typingAttributes[key]
            textView.typingAttributes[key] = decide([current])(current)
            return
        }
        var values: [Any?] = []
        storage.enumerateAttribute(key, in: range) { value, _, _ in values.append(value) }
        let map = decide(values)
        guard textView.shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        storage.enumerateAttribute(key, in: range) { value, run, _ in
            if let mapped = map(value) {
                storage.addAttribute(key, value: mapped, range: run)
            } else {
                storage.removeAttribute(key, range: run)
            }
        }
        storage.endEditing()
        textView.didChangeText()
    }
}

private struct NotesTextView: NSViewRepresentable {
    var controller: NotesEditorController
    var text: String
    var rtf: Data?
    var onChange: (String, Data?) -> Void

    static var baseAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        return [
            .font: NotesEditorController.baseFont, .foregroundColor: NSColor(Palette.textBody),
            .paragraphStyle: paragraph,
        ]
    }

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeNSView(context: Context) -> GrowingTextView {
        let view = GrowingTextView(usingTextLayoutManager: false)
        view.isRichText = true
        view.allowsUndo = true
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.isAutomaticLinkDetectionEnabled = true
        view.insertionPointColor = NSColor(Palette.teal)
        view.typingAttributes = Self.baseAttributes
        view.linkTextAttributes = [
            .foregroundColor: NSColor(Palette.tealText), .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand,
        ]
        view.textStorage?.setAttributedString(initialText)
        // Bare URLs in older or sample notes become links straight away.
        view.checkTextInDocument(nil)
        view.delegate = context.coordinator
        controller.textView = view
        return view
    }

    func updateNSView(_ view: GrowingTextView, context: Context) {
        context.coordinator.onChange = onChange
    }

    private var initialText: NSAttributedString {
        if let rtf, let stored = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            // Stored colors came from whatever theme wrote them; the editor always draws in its own.
            let text = NSMutableAttributedString(attributedString: stored)
            text.addAttribute(
                .foregroundColor, value: NSColor(Palette.textBody), range: NSRange(location: 0, length: text.length))
            return text
        }
        return NSAttributedString(string: text, attributes: Self.baseAttributes)
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var onChange: (String, Data?) -> Void

        init(onChange: @escaping (String, Data?) -> Void) {
            self.onChange = onChange
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView, let storage = view.textStorage else { return }
            let all = NSRange(location: 0, length: storage.length)
            onChange(view.string, storage.length == 0 ? nil : view.rtf(from: all))
        }
    }
}

/// A text view that asks for exactly the height of its text, so the note grows with what's written.
final class GrowingTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
        guard let layoutManager, let textContainer else { return super.intrinsicContentSize }
        layoutManager.ensureLayout(for: textContainer)
        let height = layoutManager.usedRect(for: textContainer).height + textContainerInset.height * 2
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(height))
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }

    override func setFrameSize(_ newSize: NSSize) {
        let widthChanged = newSize.width != frame.width
        super.setFrameSize(newSize)
        if widthChanged { invalidateIntrinsicContentSize() }
    }
}

#Preview("Notes editor") {
    struct Demo: View {
        @State private var text =
            "Walk through the floating timer states first, then the Focus Panel.\n"
            + "Figma: https://figma.com/file/komodo-inspector"
        @State private var rtf: Data?

        var body: some View {
            VStack(alignment: .leading, spacing: Space.s3) {
                NotesEditor(text: text, rtf: rtf) { text, rtf in
                    self.text = text
                    self.rtf = rtf
                }
                Text("\(text.count) characters").font(Typography.small).foregroundStyle(Palette.textMuted)
            }
            .frame(width: 330)
            .padding(Space.s8)
            .background(Palette.bg)
        }
    }
    return Demo()
}
