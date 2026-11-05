import AppKit
import DMSCore

/// Bundled image assets for the Nokia Belle sync companion.
/// `nokia-c7.jpg` is a real product photo of the Nokia C7 (CC BY-SA 3.0 — see Resources/NokiaC7-Photo-Attribution.txt).
public enum NokiaDeviceAssets {
    /// Product photo of the Nokia C7-00 running Nokia Belle, loaded from the DMSSymbian bundle resources.
    /// Resolved defensively via `SafeResourceBundle`: returns nil when the `DMS_DMSSymbian.bundle`
    /// is not shipped next to the executable (standalone binary), instead of crashing like `Bundle.module`.
    public static var c7Image: NSImage? {
        guard let bundle = SafeResourceBundle.bundle(named: "DMS_DMSSymbian"),
              let url = bundle.url(forResource: "nokia-c7", withExtension: "jpg") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
