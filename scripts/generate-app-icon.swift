import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers
let root = CommandLine.arguments[1]
for (size, name) in [(1024,"Assets.xcassets/AppIcon.appiconset/AppIcon.png"),(120,"AppIcon60x60@2x.png"),(180,"AppIcon60x60@3x.png")] {
    let n = CGFloat(size)
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setFillColor(CGColor(red: 1, green: 0.84, blue: 0.26, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: n, height: n))
    let font = CTFontCreateWithName("HiraginoSans-W8" as CFString, n * 0.68, nil)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: CGColor(red: 0.16, green: 0.13, blue: 0.24, alpha: 1)]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "ポ", attributes: attrs))
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    ctx.textPosition = CGPoint(x: (n - bounds.width) / 2 - bounds.minX, y: (n - bounds.height) / 2 - bounds.minY)
    CTLineDraw(line, ctx)
    let url = URL(fileURLWithPath: root).appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}
