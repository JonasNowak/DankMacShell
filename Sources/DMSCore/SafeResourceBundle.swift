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
            candidates.append(contentsOf: candidateDirectories(executableURL: executableURL, bundleURL: Bundle.main.bundleURL))
        }
        // Executable inside an .app bundle: Contents/MacOS/<exe> -> Contents/Resources
        candidates.append(
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Resources")
        )
        return bundle(named: bundleName, in: candidates)
    }

    /// Candidate directories for a given executable/bundle pair, covering plain binaries,
    /// executables inside an `.app` bundle, and symlinked executables whose link target
    /// lives elsewhere (e.g. `.app/Contents/MacOS/<exe>` -> `.app/Contents/Resources/<exe>`).
    static func candidateDirectories(executableURL: URL, bundleURL: URL) -> [URL] {
        let resolvedExe = executableURL.resolvingSymlinksInPath()
        var candidates: [URL] = []
        candidates.append(executableURL.deletingLastPathComponent())
        candidates.append(resolvedExe.deletingLastPathComponent())
        // Executable inside an .app bundle: Contents/MacOS/<exe> -> Contents/Resources
        // (derived from the unresolved path so a symlinked exe still finds its .app Resources).
        candidates.append(
            executableURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources")
        )
        // Symlinked CLI inside an .app bundle: <App>.app/Contents/MacOS/<exe> -> <App>.app/Contents/Resources
        candidates.append(
            resolvedExe
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources")
        )
        return candidates
    }

    /// Returns the first candidate directory containing a loadable `<bundleName>.bundle`.
    /// A candidate whose bundle path exists but fails to load (`Bundle(url:)` returns nil)
    /// does not stop the search — later candidates are still tried.
    public static func bundle(named bundleName: String, in candidates: [URL]) -> Bundle? {
        for candidate in candidates {
            let bundlePath = candidate.appendingPathComponent(bundleName + ".bundle")
            guard FileManager.default.fileExists(atPath: bundlePath.path) else { continue }
            if let bundle = Bundle(url: bundlePath) {
                return bundle
            }
        }
        return nil
    }
}
