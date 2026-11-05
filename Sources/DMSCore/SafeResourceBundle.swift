import Foundation

/// Safe replacement for the SwiftPM-generated `Bundle.module` accessor.
/// The generated accessor calls `fatalError` when the resource bundle is not
/// found next to the executable (e.g. a standalone CLI binary installed
/// without its `.bundle`), crashing the process on first access.
/// This resolver returns `nil` instead so callers can fall back gracefully.
public enum SafeResourceBundle {
    /// Locates a SwiftPM resource bundle (e.g. `DMS_DMSSymbian.bundle`) without crashing.
    /// Checks the same locations as the generated accessor, plus the executable's directory.
    public static func bundle(named bundleName: String) -> Bundle? {
        var candidates: [URL] = []
        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL)
        }
        candidates.append(Bundle.main.bundleURL)
        if let executableURL = Bundle.main.executableURL {
            candidates.append(executableURL.deletingLastPathComponent())
        }
        // Executable inside an .app bundle: Contents/MacOS/<exe> -> Contents/Resources
        candidates.append(
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Resources")
        )
        for candidate in candidates {
            let bundlePath = candidate.appendingPathComponent(bundleName + ".bundle")
            if FileManager.default.fileExists(atPath: bundlePath.path) {
                return Bundle(url: bundlePath)
            }
        }
        return nil
    }
}
