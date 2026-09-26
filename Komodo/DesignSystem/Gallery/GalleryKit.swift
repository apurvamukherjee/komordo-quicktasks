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

    /// The `.k-chip` family. The real chip component arrives with the component library (DESIGN_SYSTEM §9).
    struct GalleryChip: View {
        enum Tint {
            case neutral
            case outline
            case lime
            case teal
            case blue
            case violet
            case amber
            case red
            case green
            case pink
        }

        var text: String
        var tint: Tint = .neutral
        var icon: String?
        var height: CGFloat = 24

        private var colors: (text: Color, fill: Color, border: Color) {
            switch tint {
            case .neutral: (Palette.textTertiary, .white.opacity(0.05), .white.opacity(0.07))
            case .outline: (Palette.textSecondary, .clear, .white.opacity(0.2))
            case .lime: (Palette.limeText, Palette.lime.opacity(0.12), Palette.lime.opacity(0.3))
            case .teal: (Palette.tealText, Palette.teal.opacity(0.12), Palette.teal.opacity(0.3))
            case .blue: (Palette.blueText, Palette.blue.opacity(0.12), Palette.blue.opacity(0.3))
            case .violet: (Palette.violetText, Palette.violet.opacity(0.12), Palette.violet.opacity(0.28))
            case .amber: (Palette.amberText, Palette.amber.opacity(0.12), Palette.amber.opacity(0.3))
            case .red: (Palette.redText, Palette.danger.opacity(0.12), Palette.dangerLine.opacity(0.3))
            case .green: (Palette.greenText, Palette.green.opacity(0.12), Palette.green.opacity(0.28))
            case .pink: (Palette.pinkText, Palette.pink.opacity(0.1), Palette.pink.opacity(0.26))
            }
        }

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                }
                Text(text)
            }
            .font(Typography.small)
            .foregroundStyle(colors.text)
            .padding(.horizontal, 9)
            .frame(height: height)
            .background(colors.fill, in: shape)
            .overlay(shape.strokeBorder(colors.border, lineWidth: 1))
            .fixedSize()
        }
    }

    /// A 22 pt list badge (DESIGN_SYSTEM §2.4).
    struct GalleryBadge: View {
        var letter: String
        var fill: Color
        var glyph: Color

        var body: some View {
            Text(letter)
                .font(.system(size: 10.5, weight: .heavy))
                .foregroundStyle(glyph)
                .frame(width: 22, height: 22)
                .background(fill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    #Preview("Gallery kit") {
        GallerySection(label: "SECTION LABEL") {
            GalleryCaption(token: "Palette.lime", hex: "#B5F23D", use: "Primary: Start, Done, selected")
            HStack(spacing: 6) {
                GalleryBadge(letter: "W", fill: Palette.lime, glyph: Palette.onAccent)
                GalleryChip(text: "2hr 30min", icon: "clock")
                GalleryChip(text: "Sun 10:00 AM", tint: .blue)
                GalleryChip(text: "Added", tint: .green)
                GalleryChip(text: "Skipped", tint: .outline)
            }
        }
        .padding(64)
        .frame(width: 720)
        .background(Palette.bg)
    }
#endif
