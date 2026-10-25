#!/bin/sh
# Generate macOS AppIcon.icns from appicon.svg using native AppKit and iconutil.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
if [ -f "$ROOT/Support/appicon.svg" ]; then
    SVG="$ROOT/Support/appicon.svg"
else
    SVG="$ROOT/appicon.svg"
fi
SUPPORT_ICNS="$ROOT/Support/AppIcon.icns"
RESOURCE_ICNS="$ROOT/Sources/DMS/Resources/AppIcon.icns"

mkdir -p "$ROOT/Support" "$ROOT/Sources/DMS/Resources"

NEEDS_GEN=0
if [ ! -f "$SUPPORT_ICNS" ] || [ ! -f "$RESOURCE_ICNS" ]; then
    NEEDS_GEN=1
elif [ -f "$SVG" ]; then
    if [ "$SVG" -nt "$SUPPORT_ICNS" ] || [ "$SVG" -nt "$RESOURCE_ICNS" ]; then
        NEEDS_GEN=1
    fi
fi

if [ "${1:-}" = "--force" ]; then
    NEEDS_GEN=1
fi

if [ "$NEEDS_GEN" -eq 1 ] && [ -f "$SVG" ]; then
    echo "==> Generating AppIcon.icns from repository appicon.svg..."
    TMPDIR=$(mktemp -d)
    trap 'rm -rf "$TMPDIR"' EXIT INT TERM
    ICONSET="$TMPDIR/AppIcon.iconset"
    mkdir -p "$ICONSET"

    swift - "$SVG" "$ICONSET" "$TMPDIR/AppIcon.icns" << 'SWIFT_EOF' 2>/dev/null
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 4 else { exit(1) }
let svgPath = args[1]
let iconsetDir = URL(fileURLWithPath: args[2])
let outputIcns = args[3]

guard let svgImage = NSImage(contentsOfFile: svgPath) else {
    fputs("Error: could not load SVG at \(svgPath)\n", stderr)
    exit(1)
}

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in sizes {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { continue }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current = ctx
    ctx?.imageInterpolation = .high
    svgImage.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: NSRect(origin: .zero, size: svgImage.size),
        operation: .copy,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()

    let fileURL = iconsetDir.appendingPathComponent(name)
    if let pngData = rep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: fileURL)
    }
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir.path, "-o", outputIcns]
try? task.run()
task.waitUntilExit()
exit(task.terminationStatus)
SWIFT_EOF

    if [ -f "$TMPDIR/AppIcon.icns" ]; then
        cp "$TMPDIR/AppIcon.icns" "$SUPPORT_ICNS"
        cp "$TMPDIR/AppIcon.icns" "$RESOURCE_ICNS"
        echo "==> Successfully generated AppIcon.icns."
    else
        echo "==> Warning: iconutil generation failed; falling back to existing icns if present." >&2
    fi
elif [ -f "$SUPPORT_ICNS" ] && [ ! -f "$RESOURCE_ICNS" ]; then
    cp "$SUPPORT_ICNS" "$RESOURCE_ICNS"
fi
