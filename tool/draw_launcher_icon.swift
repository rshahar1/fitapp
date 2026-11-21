// Draws the FitApp "Iron plate" launcher mark: a heavy chevron above a bar,
// square caps and mitered joins, plate yellow (#F5C518).
//
// Usage:  swift tool/draw_launcher_icon.swift <out_dir>
//   <out_dir>/icon.png            1024x1024, opaque soot (#15120F) background
//   <out_dir>/icon_foreground.png 1024x1024, transparent, mark scaled into the
//                                 Android adaptive-icon safe zone
// Then run: dart run flutter_launcher_icons && dart run flutter_native_splash:create
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
  FileHandle.standardError.write("usage: swift draw_launcher_icon.swift <out_dir>\n".data(using: .utf8)!)
  exit(1)
}
let outDir = CommandLine.arguments[1]
let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let yellow = CGColor(colorSpace: space, components: [245/255, 197/255, 24/255, 1])!
let soot = CGColor(colorSpace: space, components: [21/255, 18/255, 15/255, 1])!

func render(background: CGColor?, scale: CGFloat, to name: String) {
  let info = background == nil
    ? CGImageAlphaInfo.premultipliedLast.rawValue
    : CGImageAlphaInfo.noneSkipLast.rawValue
  let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                      bytesPerRow: 0, space: space, bitmapInfo: info)!
  if let bg = background {
    ctx.setFillColor(bg)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
  }
  // Design coordinates are top-left origin (1024 grid); flip to CoreGraphics.
  ctx.translateBy(x: 0, y: CGFloat(size))
  ctx.scaleBy(x: 1, y: -1)
  // Scale about the centre (used for the adaptive-icon safe zone).
  ctx.translateBy(x: 512, y: 512)
  ctx.scaleBy(x: scale, y: scale)
  ctx.translateBy(x: -512, y: -512)

  ctx.setStrokeColor(yellow)
  ctx.setLineWidth(104)
  ctx.setLineCap(.square)
  ctx.setLineJoin(.miter)
  ctx.setMiterLimit(10)

  ctx.beginPath()  // chevron
  ctx.move(to: CGPoint(x: 227, y: 568))
  ctx.addLine(to: CGPoint(x: 512, y: 283))
  ctx.addLine(to: CGPoint(x: 797, y: 568))
  ctx.strokePath()

  ctx.beginPath()  // bar
  ctx.move(to: CGPoint(x: 227, y: 730))
  ctx.addLine(to: CGPoint(x: 797, y: 730))
  ctx.strokePath()

  let url = URL(fileURLWithPath: outDir).appendingPathComponent(name) as CFURL
  let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
  guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(name)") }
}

render(background: soot, scale: 1.0, to: "icon.png")
render(background: nil, scale: 0.697, to: "icon_foreground.png")
