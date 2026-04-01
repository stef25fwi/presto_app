import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var startupSplashView: DesktopStartupSplashView?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.backgroundColor = NSColor(calibratedRed: 34 / 255, green: 80 / 255, blue: 244 / 255, alpha: 1)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    if let contentView = self.contentView {
      let splashView = DesktopStartupSplashView(frame: contentView.bounds)
      splashView.autoresizingMask = [.width, .height]
      contentView.addSubview(splashView, positioned: .above, relativeTo: nil)
      startupSplashView = splashView

      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
        self?.dismissStartupSplash()
      }
    }
  }

  private func dismissStartupSplash() {
    guard let splashView = startupSplashView else {
      return
    }

    NSAnimationContext.runAnimationGroup({ context in
      context.duration = 0.22
      splashView.animator().alphaValue = 0
    }, completionHandler: { [weak self] in
      splashView.removeFromSuperview()
      self?.startupSplashView = nil
    })
  }
}

final class DesktopStartupSplashView: NSView {
  private let blue = NSColor(calibratedRed: 34 / 255, green: 80 / 255, blue: 244 / 255, alpha: 1)
  private let orange = NSColor(calibratedRed: 1, green: 138 / 255, blue: 29 / 255, alpha: 1)
  private let pinkTint = NSColor(calibratedRed: 210 / 255, green: 164 / 255, blue: 188 / 255, alpha: 1)

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    wantsLayer = true
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    let bounds = self.bounds
    let midX = bounds.midX

    blue.setFill()
    NSBezierPath(rect: NSRect(x: bounds.minX, y: bounds.minY, width: midX, height: bounds.height)).fill()

    orange.setFill()
    NSBezierPath(rect: NSRect(x: midX, y: bounds.minY, width: bounds.maxX - midX, height: bounds.height)).fill()

    let glowRect = NSRect(x: bounds.width * 0.39, y: 0, width: bounds.width * 0.22, height: bounds.height)
    if let centerGlow = NSGradient(colors: [
      NSColor.white.withAlphaComponent(0.0),
      NSColor.white.withAlphaComponent(0.08),
      NSColor.white.withAlphaComponent(0.14),
      NSColor.white.withAlphaComponent(0.06),
      NSColor.white.withAlphaComponent(0.0),
    ]) {
      centerGlow.draw(in: glowRect, angle: 90)
    }

    let bottomTintRect = NSRect(
      x: bounds.midX - 130,
      y: bounds.height * 0.02,
      width: 260,
      height: 180
    )
    if let bottomTint = NSGradient(colors: [
      pinkTint.withAlphaComponent(0.52),
      pinkTint.withAlphaComponent(0.14),
      .clear,
    ]) {
      bottomTint.draw(in: NSBezierPath(ovalIn: bottomTintRect), relativeCenterPosition: .zero)
    }

    let titleAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: min(54, bounds.width * 0.085), weight: .heavy),
      .foregroundColor: NSColor.white
    ]
    let title = "iliprestō" as NSString
    let titleSize = title.size(withAttributes: titleAttributes)
    let titleShadow = NSShadow()
    titleShadow.shadowBlurRadius = 14
    titleShadow.shadowOffset = NSSize(width: 0, height: -8)
    titleShadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
    let titleShadowAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: min(54, bounds.width * 0.085), weight: .heavy),
      .foregroundColor: NSColor.white,
      .shadow: titleShadow,
    ]
    let titleRect = NSRect(
      x: (bounds.width - titleSize.width) / 2,
      y: bounds.height - max(120, bounds.height * 0.18),
      width: titleSize.width,
      height: titleSize.height
    )
    title.draw(in: titleRect, withAttributes: titleShadowAttributes)

    let logoSize = min(bounds.width * 0.28, 220)
    let logoRect = NSRect(
      x: (bounds.width - logoSize) / 2,
      y: (bounds.height - logoSize) / 2 - 10,
      width: logoSize,
      height: logoSize
    )

    let logoShadowRect = NSRect(
      x: logoRect.minX + logoRect.width * 0.22,
      y: logoRect.minY - logoRect.height * 0.12,
      width: logoRect.width * 0.56,
      height: logoRect.height * 0.12
    )
    if let shadowGradient = NSGradient(colors: [
      NSColor(calibratedRed: 47 / 255, green: 54 / 255, blue: 84 / 255, alpha: 0.40),
      .clear,
    ]) {
      shadowGradient.draw(in: NSBezierPath(ovalIn: logoShadowRect), relativeCenterPosition: .zero)
    }

    let logoGlowRect = logoRect.insetBy(dx: -8, dy: -8)
    let logoGlowPath = NSBezierPath(roundedRect: logoGlowRect, xRadius: 34, yRadius: 34)
    NSColor.white.withAlphaComponent(0.14).setFill()
    logoGlowPath.fill()

    NSGraphicsContext.current?.saveGraphicsState()
    let clipPath = NSBezierPath(roundedRect: logoRect, xRadius: 28, yRadius: 28)
    clipPath.addClip()

    blue.setFill()
    NSBezierPath(rect: NSRect(x: logoRect.minX, y: logoRect.minY, width: logoRect.width / 2, height: logoRect.height)).fill()
    orange.setFill()
    NSBezierPath(rect: NSRect(x: logoRect.midX, y: logoRect.minY, width: logoRect.width / 2, height: logoRect.height)).fill()

    NSGraphicsContext.current?.restoreGraphicsState()

    let borderPath = NSBezierPath(roundedRect: logoRect, xRadius: 28, yRadius: 28)
    borderPath.lineWidth = 3
    NSColor.white.setStroke()
    borderPath.stroke()

    let dividerPath = NSBezierPath()
    dividerPath.lineWidth = 6
    dividerPath.lineCapStyle = .round
    dividerPath.move(to: NSPoint(x: logoRect.midX, y: logoRect.minY + 10))
    dividerPath.line(to: NSPoint(x: logoRect.midX, y: logoRect.maxY - 10))
    dividerPath.stroke()

    let iAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: logoRect.width * 0.62, weight: .heavy),
      .foregroundColor: NSColor.white
    ]
    let iGlyph = "i" as NSString
    let iSize = iGlyph.size(withAttributes: iAttributes)
    let leftRect = NSRect(
      x: logoRect.minX + (logoRect.width / 4) - (iSize.width / 2),
      y: logoRect.minY + logoRect.height * 0.14,
      width: iSize.width,
      height: iSize.height
    )
    let rightRect = NSRect(
      x: logoRect.minX + (logoRect.width * 0.75) - (iSize.width / 2),
      y: logoRect.minY + logoRect.height * 0.14,
      width: iSize.width,
      height: iSize.height
    )
    iGlyph.draw(in: leftRect, withAttributes: iAttributes)
    iGlyph.draw(in: rightRect, withAttributes: iAttributes)

    let smileShadowPath = NSBezierPath()
    smileShadowPath.lineWidth = logoRect.width * 0.06
    smileShadowPath.lineCapStyle = .round
    smileShadowPath.move(to: NSPoint(x: logoRect.minX + logoRect.width * 0.38, y: logoRect.minY + logoRect.height * 0.24))
    smileShadowPath.curve(to: NSPoint(x: logoRect.minX + logoRect.width * 0.64, y: logoRect.minY + logoRect.height * 0.25),
                          controlPoint1: NSPoint(x: logoRect.minX + logoRect.width * 0.46, y: logoRect.minY + logoRect.height * 0.16),
                          controlPoint2: NSPoint(x: logoRect.minX + logoRect.width * 0.56, y: logoRect.minY + logoRect.height * 0.16))
    NSColor.black.withAlphaComponent(0.14).setStroke()
    let shadowTransform = AffineTransform(translationByX: 0, byY: -4)
    smileShadowPath.transform(using: shadowTransform)
    smileShadowPath.stroke()

    let smilePath = NSBezierPath()
    smilePath.lineWidth = logoRect.width * 0.055
    smilePath.lineCapStyle = .round
    smilePath.move(to: NSPoint(x: logoRect.minX + logoRect.width * 0.38, y: logoRect.minY + logoRect.height * 0.24))
    smilePath.curve(to: NSPoint(x: logoRect.minX + logoRect.width * 0.64, y: logoRect.minY + logoRect.height * 0.25),
                    controlPoint1: NSPoint(x: logoRect.minX + logoRect.width * 0.46, y: logoRect.minY + logoRect.height * 0.16),
                    controlPoint2: NSPoint(x: logoRect.minX + logoRect.width * 0.56, y: logoRect.minY + logoRect.height * 0.16))
    NSColor.white.withAlphaComponent(0.96).setStroke()
    smilePath.stroke()
  }
}
