#if DEBUG
    import SwiftUI

    /// The artboard is 1440 pt wide; section previews use it too so they wrap like the full gallery.
    enum GalleryCanvas {
        static let width: CGFloat = 1440
    }

    /// A `.fd-sec` block: panel fill, radius 26, 28 pt padding, a label row, then the content.
    struct GallerySection<Trailing: View, Content: View>: View {
        var label: String
        var labelColor = Palette.textSecondary
        /// A soft wash from the top centre, as on the spotlight section.
        var ambient: Color?
        @ViewBuilder var trailing: Trailing
        @ViewBuilder var content: Content

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.column, style: .continuous)
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    GalleryLabel(label, color: labelColor)
                    Spacer()
                    trailing
                }
                content
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                ZStack {
                    shape.fill(Palette.panel)
                    if let ambient {
                        // Sized by the section itself; a fixed-size gradient here would stretch the background.
                        EllipticalGradient(
                            stops: [
                                .init(color: ambient.opacity(0.07), location: 0),
                                .init(color: .clear, location: 0.75),
                            ],
                            center: .top
                        )
                        .clipShape(shape)
                    }
                    shape.strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                }
            }
        }
    }

    extension GallerySection where Trailing == EmptyView {
        init(label: String, labelColor: Color = Palette.textSecondary, @ViewBuilder content: () -> Content) {
            self.init(label: label, labelColor: labelColor, ambient: nil, trailing: { EmptyView() }, content: content)
        }
    }

    struct GalleryLabel: View {
        var text: String
        var color: Color

        init(_ text: String, color: Color = Palette.textSecondary) {
            self.text = text
            self.color = color
        }

        var body: some View {
            Text(text)
                .font(Typography.label)
                .tracking(Typography.Tracking.label)
                .foregroundStyle(color)
        }
    }

    /// The artboard's annotation styles: `.fd-tok`, `.fd-hex` and `.fd-use`.
    enum GalleryType {
        static let token = Font.system(size: 11.5, design: .monospaced)
        static let hex = Font.system(size: 10.5, design: .monospaced)
        static let use = Font.system(size: 11.5)
    }

    struct GalleryCaption: View {
        var token: String
        var hex: String?
        var use: String?
        var tokenColor = Palette.textBody

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(token).font(GalleryType.token).foregroundStyle(tokenColor)
                if let hex {
                    Text(hex).font(GalleryType.hex).foregroundStyle(Palette.textMuted)
                }
                if let use {
                    Text(use).font(GalleryType.use).lineSpacing(2).foregroundStyle(Palette.textSecondary)
                }
            }
        }
    }

    #Preview("Gallery kit") {
        GallerySection(label: "SECTION LABEL") {
            GalleryCaption(token: "Palette.lime", hex: "#B5F23D", use: "Primary: Start, Done, selected")
        }
        .padding(64)
        .frame(width: 720)
        .background(Palette.bg)
    }
#endif
