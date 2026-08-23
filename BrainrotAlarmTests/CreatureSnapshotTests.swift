import XCTest
import SwiftUI
import UIKit
@testable import BrainrotAlarm

/// Renders every character to a PNG so the procedural art can be looked at.
///
/// The drawing code has only ever been reasoned about, never seen — a wrong sign
/// in a control point or a shape drawn outside its tile would compile, pass every
/// other test, and still look like nothing. This writes a contact sheet to
/// `/tmp/brainrot-shots` (the simulator shares the host filesystem) for CI to
/// upload.
@MainActor
final class CreatureSnapshotTests: XCTestCase {

    private let outputDirectory = URL(fileURLWithPath: "/tmp/brainrot-shots")
    private let tileSize: CGFloat = 220

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: outputDirectory,
                                                 withIntermediateDirectories: true)
    }

    func testRenderEveryCharacter() throws {
        var rendered: [(BrainrotCharacter, UIImage)] = []

        for character in BrainrotCatalog.all {
            let renderer = ImageRenderer(
                content: CreatureView(recipe: character.art)
                    .frame(width: tileSize, height: tileSize))
            renderer.scale = 2

            guard let image = renderer.uiImage else {
                XCTFail("\(character.id) rendered nothing")
                continue
            }
            // A blank tile means the drawing fell outside its bounds.
            XCTAssertFalse(isBlank(image), "\(character.id) rendered blank")
            rendered.append((character, image))

            if let data = image.pngData() {
                try? data.write(to: outputDirectory.appendingPathComponent("\(character.id).png"))
            }
        }

        XCTAssertEqual(rendered.count, BrainrotCatalog.all.count)
        try writeContactSheet(rendered)
    }

    /// True if every pixel is the same colour.
    private func isBlank(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return true }
        let width = min(24, cgImage.width), height = min(24, cgImage.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return true }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let first = Array(pixels.prefix(3))
        for index in stride(from: 0, to: pixels.count, by: 4) {
            if Array(pixels[index..<index + 3]) != first { return false }
        }
        return true
    }

    private func writeContactSheet(_ entries: [(BrainrotCharacter, UIImage)]) throws {
        let columns = 6
        let rows = Int(ceil(Double(entries.count) / Double(columns)))
        let cell = tileSize
        let label: CGFloat = 26
        let pad: CGFloat = 10
        let size = CGSize(width: CGFloat(columns) * (cell + pad) + pad,
                          height: CGFloat(rows) * (cell + label + pad) + pad)

        let renderer = UIGraphicsImageRenderer(size: size)
        let sheet = renderer.image { context in
            UIColor(red: 0.055, green: 0.043, blue: 0.078, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            for (index, entry) in entries.enumerated() {
                let column = index % columns, row = index / columns
                let x = pad + CGFloat(column) * (cell + pad)
                let y = pad + CGFloat(row) * (cell + label + pad)
                entry.1.draw(in: CGRect(x: x, y: y, width: cell, height: cell))

                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                    .foregroundColor: UIColor.white
                ]
                let name = entry.0.name as NSString
                name.draw(with: CGRect(x: x, y: y + cell + 3, width: cell, height: label),
                          options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
            }
        }
        if let data = sheet.pngData() {
            try data.write(to: outputDirectory.appendingPathComponent("contact-sheet.png"))
        }
    }
}
