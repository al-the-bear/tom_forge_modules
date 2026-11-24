// Copyright (c) 2026 Peter Nicolai Alexis Kyaw
// SPDX-License-Identifier: BSD-3-Clause
//
// The macOS Preview side of the office evaluation: PDFKit, the framework
// Preview draws PDFs with (the fidelity renders of the routes' and the
// references' PDFs), and an image of the harness window. Compiled once by
// run_evaluation.py:
//
//   swiftc -O pdfkit_tool.swift -o <work>/pdfkit_tool
//
// Commands (one line of output each unless said otherwise):
//   opens  <pdf> [password]                  -> "ok <pages> <locked>" | "refused"
//   render <pdf> <page> <w> <h> <out.png> [password]
//                                            -> "ok"  (page 0-based, the crop
//                                               box drawn into w x h pixels on
//                                               white, annotations included)
//   size   <pdf> <page>                      -> "<w> <h>" of the page's crop
//                                               box in points (rotation
//                                               applied)
//   windowshot <pid> <out.png>               -> "ok <w> <h>" | "none": the
//                                               process's largest on-screen
//                                               window as macOS composes it
//                                               (webviews included); needs
//                                               the Screen Recording
//                                               permission of the process
//                                               that started the harness
//   annots <pdf> [password]                  -> one "<page>\t<type>" per line
//   fields <pdf>                             -> one "name=value" or
//                                               "name:on|off" per line (page 0)
//   diff   <a.png> <b.png> [<out.png>]       -> "<ratio> <meanAbs> <w> <h> <raw>":
//                                               ratio: the share of pixels
//                                               whose largest channel differs
//                                               by over 40 of 255 and that no
//                                               pixel within one pixel of the
//                                               other image matches (both
//                                               ways: a glyph placed a pixel
//                                               apart is not a difference,
//                                               missing content is); raw: the
//                                               same without the shift; the
//                                               mean absolute difference; b is
//                                               drawn at a's size; <out.png>
//                                               marks differences red and
//                                               one-pixel shifts orange.

import AppKit
import Foundation
import PDFKit

func fail(_ message: String) -> Never {
  FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
  exit(2)
}

func document(_ path: String, _ password: String?) -> PDFDocument? {
  guard let d = PDFDocument(url: URL(fileURLWithPath: path)) else { return nil }
  if d.isLocked, let password { _ = d.unlock(withPassword: password) }
  return d
}

func rgba(width: Int, height: Int) -> CGContext {
  guard
    let ctx = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8,
      bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { fail("no bitmap context") }
  return ctx
}

func writePng(_ ctx: CGContext, _ path: String) {
  guard let image = ctx.makeImage() else { fail("no image") }
  let rep = NSBitmapImageRep(cgImage: image)
  guard let data = rep.representation(using: .png, properties: [:]) else {
    fail("no png")
  }
  try! data.write(to: URL(fileURLWithPath: path))
}

func loadImage(_ path: String) -> CGImage {
  guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
  else { fail("cannot read \(path)") }
  return image
}

let args = CommandLine.arguments
guard args.count >= 3 else { fail("usage: pdfkit_tool <command> ...") }

switch args[1] {
case "opens":
  guard let d = document(args[2], args.count > 3 ? args[3] : nil) else {
    print("refused")
    exit(0)
  }
  print("ok \(d.pageCount) \(d.isLocked)")

case "render":
  guard args.count >= 7 else { fail("render <pdf> <page> <w> <h> <out> [pw]") }
  guard let d = document(args[2], args.count > 7 ? args[7] : nil),
    let page = d.page(at: Int(args[3])!)
  else { fail("refused") }
  let w = Int(args[4])!
  let h = Int(args[5])!
  let ctx = rgba(width: w, height: h)
  ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
  ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
  let box = page.bounds(for: .cropBox)
  let rotated = page.rotation % 180 != 0
  let pw = rotated ? box.height : box.width
  let ph = rotated ? box.width : box.height
  ctx.scaleBy(x: CGFloat(w) / pw, y: CGFloat(h) / ph)
  page.transform(ctx, for: .cropBox)
  page.draw(with: .cropBox, to: ctx)
  writePng(ctx, args[6])
  print("ok")

case "size":
  guard let d = document(args[2], nil), let page = d.page(at: Int(args[3])!)
  else { fail("refused") }
  let box = page.bounds(for: .cropBox)
  let rotated = page.rotation % 180 != 0
  print("\(Int(rotated ? box.height : box.width)) \(Int(rotated ? box.width : box.height))")

case "windowshot":
  let pid = Int(args[2])!
  let windows =
    (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]])
    ?? []
  let mine = windows.filter { ($0[kCGWindowOwnerPID as String] as? Int) == pid }
  func area(_ w: [String: Any]) -> Double {
    let b = w[kCGWindowBounds as String] as? [String: Double] ?? [:]
    return (b["Width"] ?? 0) * (b["Height"] ?? 0)
  }
  guard let window = mine.max(by: { area($0) < area($1) }),
    let id = window[kCGWindowNumber as String] as? CGWindowID
  else {
    print("none")
    exit(0)
  }
  // screencapture composes the window as macOS shows it (webviews too).
  let shot = Process()
  shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
  shot.arguments = ["-x", "-o", "-l\(id)", args[3]]
  try! shot.run()
  shot.waitUntilExit()
  if !FileManager.default.fileExists(atPath: args[3]) {
    // Window capture refused: the window's region of the screen instead.
    let b = window[kCGWindowBounds as String] as? [String: Double] ?? [:]
    let region = Process()
    region.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    region.arguments = [
      "-x",
      "-R\(Int(b["X"] ?? 0)),\(Int(b["Y"] ?? 0)),\(Int(b["Width"] ?? 0)),\(Int(b["Height"] ?? 0))",
      args[3],
    ]
    try! region.run()
    region.waitUntilExit()
  }
  guard FileManager.default.fileExists(atPath: args[3]) else {
    print("none")
    exit(0)
  }
  let image = loadImage(args[3])
  print("ok \(image.width) \(image.height)")

case "annots":
  guard let d = document(args[2], args.count > 3 ? args[3] : nil) else {
    print("refused")
    exit(0)
  }
  for i in 0..<d.pageCount {
    for a in d.page(at: i)!.annotations where a.type != "Widget" && a.type != "Link" {
      print("\(i)\t\(a.type ?? "?")")
    }
  }

case "fields":
  guard let d = document(args[2], nil), let page = d.page(at: 0) else {
    print("refused")
    exit(0)
  }
  for a in page.annotations where a.type == "Widget" {
    let name = a.fieldName ?? "?"
    switch a.widgetFieldType {
    case .text, .choice: print("\(name)=\(a.widgetStringValue ?? "")")
    default: print("\(name):\(a.buttonWidgetState == .onState ? "on" : "off")")
    }
  }

case "diff":
  guard args.count >= 4 else { fail("diff <a.png> <b.png> [out.png]") }
  let a = loadImage(args[2])
  let b = loadImage(args[3])
  let w = a.width
  let h = a.height
  let ca = rgba(width: w, height: h)
  let cb = rgba(width: w, height: h)
  for (ctx, img) in [(ca, a), (cb, b)] {
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
  }
  let pa = ca.data!.assumingMemoryBound(to: UInt8.self)
  let pb = cb.data!.assumingMemoryBound(to: UInt8.self)
  let out = args.count > 4 ? rgba(width: w, height: h) : nil
  let po = out?.data!.assumingMemoryBound(to: UInt8.self)
  // The largest channel difference of pixel i of x and pixel j of y.
  func delta(_ x: UnsafeMutablePointer<UInt8>, _ i: Int, _ y: UnsafeMutablePointer<UInt8>, _ j: Int) -> Int {
    var largest = 0
    for c in 0..<3 { largest = max(largest, abs(Int(x[i * 4 + c]) - Int(y[j * 4 + c]))) }
    return largest
  }
  // Whether pixel (px, py) of x has a close pixel within one pixel in y:
  // a glyph or an edge placed one pixel apart is not a difference.
  func matched(_ x: UnsafeMutablePointer<UInt8>, _ y: UnsafeMutablePointer<UInt8>, _ px: Int, _ py: Int) -> Bool {
    let i = py * w + px
    for dy in -1...1 {
      let qy = py + dy
      if qy < 0 || qy >= h { continue }
      for dx in -1...1 {
        let qx = px + dx
        if qx < 0 || qx >= w { continue }
        if delta(x, i, y, qy * w + qx) <= 40 { return true }
      }
    }
    return false
  }
  var differing = 0
  var shifted = 0
  var sum = 0
  for py in 0..<h {
    for px in 0..<w {
      let i = py * w + px
      for c in 0..<3 { sum += abs(Int(pa[i * 4 + c]) - Int(pb[i * 4 + c])) }
      let differs = delta(pa, i, pb, i) > 40
      if differs { differing += 1 }
      // Both ways, so content missing from either image counts.
      let real = differs && (!matched(pa, pb, px, py) || !matched(pb, pa, px, py))
      if real { shifted += 1 }
      if let po {
        // The reference faded; differences red, one-pixel shifts orange.
        for c in 0..<3 { po[i * 4 + c] = UInt8(min(255, 160 + Int(pa[i * 4 + c]) / 3)) }
        if real {
          po[i * 4] = 230; po[i * 4 + 1] = 0; po[i * 4 + 2] = 0
        } else if differs {
          po[i * 4] = 250; po[i * 4 + 1] = 190; po[i * 4 + 2] = 120
        }
        po[i * 4 + 3] = 255
      }
    }
  }
  if let out { writePng(out, args[4]) }
  let total = Double(w * h)
  print(String(format: "%.6f %.4f %d %d %.6f", Double(shifted) / total, Double(sum) / (total * 3), w, h, Double(differing) / total))

default:
  fail("unknown command \(args[1])")
}
