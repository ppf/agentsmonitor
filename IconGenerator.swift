#!/usr/bin/swift

import AppKit
import Foundation

/// Generates app icons for AgentsMonitor
/// Run: swift IconGenerator.swift

struct IconGenerator {
    static let sizes: [(name: String, size: Int)] = [
        ("icon_16x16", 16),
        ("icon_16x16@2x", 32),
        ("icon_32x32", 32),
        ("icon_32x32@2x", 64),
        ("icon_128x128", 128),
        ("icon_128x128@2x", 256),
        ("icon_256x256", 256),
        ("icon_256x256@2x", 512),
        ("icon_512x512", 512),
        ("icon_512x512@2x", 1024)
    ]

    static func generateIcon(size: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))

        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let cornerRadius = CGFloat(size) * 0.22 // macOS icon corner radius

        // Background gradient (purple to blue)
        let gradient = NSGradient(colors: [
            NSColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 1.0),  // Purple
            NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0)   // Blue
        ])!

        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        gradient.draw(in: path, angle: -45)

        // Draw CPU/chip icon
        let iconSize = CGFloat(size) * 0.5
        let iconX = (CGFloat(size) - iconSize) / 2
        let iconY = (CGFloat(size) - iconSize) / 2

        NSColor.white.withAlphaComponent(0.95).setFill()
        NSColor.white.withAlphaComponent(0.95).setStroke()

        // Main chip body
        let chipSize = iconSize * 0.6
        let chipX = iconX + (iconSize - chipSize) / 2
        let chipY = iconY + (iconSize - chipSize) / 2
        let chipRect = NSRect(x: chipX, y: chipY, width: chipSize, height: chipSize)
        let chipPath = NSBezierPath(roundedRect: chipRect, xRadius: chipSize * 0.15, yRadius: chipSize * 0.15)
        chipPath.lineWidth = CGFloat(size) * 0.02
        chipPath.stroke()

        // Inner circuit pattern
        let innerSize = chipSize * 0.5
        let innerX = chipX + (chipSize - innerSize) / 2
        let innerY = chipY + (chipSize - innerSize) / 2
        let innerRect = NSRect(x: innerX, y: innerY, width: innerSize, height: innerSize)
        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: innerSize * 0.2, yRadius: innerSize * 0.2)
        innerPath.fill()

        // Connection pins
        let pinWidth = CGFloat(size) * 0.02
        let pinLength = CGFloat(size) * 0.08
        let pinSpacing = chipSize / 4

        // Top and bottom pins
        for i in 0..<3 {
            let pinX = chipX + pinSpacing * CGFloat(i + 1) - pinWidth / 2

            // Top pins
            let topPin = NSRect(x: pinX, y: chipY + chipSize, width: pinWidth, height: pinLength)
            NSBezierPath(rect: topPin).fill()

            // Bottom pins
            let bottomPin = NSRect(x: pinX, y: chipY - pinLength, width: pinWidth, height: pinLength)
            NSBezierPath(rect: bottomPin).fill()
        }

        // Left and right pins
        for i in 0..<3 {
            let pinY = chipY + pinSpacing * CGFloat(i + 1) - pinWidth / 2

            // Left pins
            let leftPin = NSRect(x: chipX - pinLength, y: pinY, width: pinLength, height: pinWidth)
            NSBezierPath(rect: leftPin).fill()

            // Right pins
            let rightPin = NSRect(x: chipX + chipSize, y: pinY, width: pinLength, height: pinWidth)
            NSBezierPath(rect: rightPin).fill()
        }

        // Pulsing dot indicator (representing activity)
        let dotSize = CGFloat(size) * 0.08
        let dotX = CGFloat(size) * 0.75
        let dotY = CGFloat(size) * 0.75

        // Glow effect
        NSColor.green.withAlphaComponent(0.3).setFill()
        let glowPath = NSBezierPath(ovalIn: NSRect(x: dotX - dotSize * 0.3, y: dotY - dotSize * 0.3, width: dotSize * 1.6, height: dotSize * 1.6))
        glowPath.fill()

        // Main dot
        NSColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0).setFill()
        let dotPath = NSBezierPath(ovalIn: NSRect(x: dotX, y: dotY, width: dotSize, height: dotSize))
        dotPath.fill()

        image.unlockFocus()

        return image
    }

    static func saveIcon(_ image: NSImage, name: String, to directory: URL) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            print("Failed to create PNG for \(name)")
            return
        }

        let fileURL = directory.appendingPathComponent("\(name).png")
        do {
            try pngData.write(to: fileURL)
            print("Created: \(name).png")
        } catch {
            print("Failed to save \(name).png: \(error)")
        }
    }

    static func generateAll() {
        let fileManager = FileManager.default
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let outputDir = currentDir
            .appendingPathComponent("AgentsMonitor")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Assets.xcassets")
            .appendingPathComponent("AppIcon.appiconset")

        // Create directory if needed
        try? fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)

        print("Generating icons to: \(outputDir.path)")

        for (name, size) in sizes {
            let image = generateIcon(size: size)
            saveIcon(image, name: name, to: outputDir)
        }

        // Update Contents.json
        let contents = generateContentsJSON()
        let contentsURL = outputDir.appendingPathComponent("Contents.json")
        try? contents.write(to: contentsURL, atomically: true, encoding: .utf8)
        print("Updated: Contents.json")

        print("\nDone! Icons generated successfully.")
    }

    static func generateContentsJSON() -> String {
        return """
        {
          "images" : [
            {
              "filename" : "icon_16x16.png",
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "16x16"
            },
            {
              "filename" : "icon_16x16@2x.png",
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "16x16"
            },
            {
              "filename" : "icon_32x32.png",
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "32x32"
            },
            {
              "filename" : "icon_32x32@2x.png",
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "32x32"
            },
            {
              "filename" : "icon_128x128.png",
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "128x128"
            },
            {
              "filename" : "icon_128x128@2x.png",
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "128x128"
            },
            {
              "filename" : "icon_256x256.png",
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "256x256"
            },
            {
              "filename" : "icon_256x256@2x.png",
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "256x256"
            },
            {
              "filename" : "icon_512x512.png",
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "512x512"
            },
            {
              "filename" : "icon_512x512@2x.png",
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "512x512"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
    }
}

// Run the generator
IconGenerator.generateAll()
