import AppKit
import SwiftUI

/// DESIGN_SYSTEM §9's code block (`.st-code`): SF Mono on near-black with a hairline, JSON keys in teal and
/// strings in lime, and Copy in the corner, which reads Copied with a check for 2 s.
struct CodeBlock: View {
    var code: String

    @State private var copiedAt: Date?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        Text(Self.highlighted(code))
            .font(.system(size: 12, design: .monospaced))
            .lineSpacing(5)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.leading, Space.s4)
            .padding(.trailing, 110)
            .background(Palette.bg, in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                Button(copiedAt == nil ? "Copy" : "Copied", systemImage: copiedAt == nil ? "doc.on.doc" : "checkmark") {
                    copy()
                }
                .buttonStyle(.komodo(.secondary, size: .small))
                .foregroundStyle(copiedAt == nil ? Palette.textPrimary : Palette.greenText)
                .padding(10)
                .animation(Motion.fast, value: copiedAt)
            }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        let stamp = Date()
        copiedAt = stamp
        Task {
            try? await Task.sleep(for: .seconds(2))
            // A second Copy restarts the 2 s, so only the latest one clears it.
            if copiedAt == stamp { copiedAt = nil }
        }
    }

    /// Quoted text followed by a colon is a key; any other quoted text is a string; the rest is punctuation.
    static func highlighted(_ code: String) -> AttributedString {
        var result = AttributedString()
        var rest = Substring(code)
        while let open = rest.firstIndex(of: "\"") {
            result += styled(rest[..<open], Palette.textSecondary)
            let afterOpen = rest.index(after: open)
            let close = rest[afterOpen...].firstIndex(of: "\"") ?? rest.index(before: rest.endIndex)
            let end = rest.index(after: close)
            let isKey = rest[end...].drop(while: { $0 == " " }).first == ":"
            result += styled(rest[open..<end], isKey ? Palette.tealText : Palette.limeText)
            rest = rest[end...]
        }
        return result + styled(rest, Palette.textSecondary)
    }

    private static func styled(_ text: Substring, _ color: Color) -> AttributedString {
        var part = AttributedString(text)
        part.foregroundColor = color
        return part
    }
}

#Preview("Code block") {
    CodeBlock(
        code: """
            {
              "mcpServers": {
                "komodo": {
                  "command": "/Applications/Komodo.app/Contents/Helpers/komodo-mcp",
                  "args": []
                }
              }
            }
            """
    )
    .frame(width: 620)
    .padding(Space.s6)
    .background(Palette.raised)
}
