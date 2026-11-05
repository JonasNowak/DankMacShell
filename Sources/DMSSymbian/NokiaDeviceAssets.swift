import AppKit

/// Bundled image assets for the Nokia Belle sync companion.
/// `nokia-c7.jpg` is a real product photo of the Nokia C7 (CC BY-SA 3.0 — see Resources/NokiaC7-Photo-Attribution.txt).
public enum NokiaDeviceAssets {
    /// Product photo of the Nokia C7-00 running Nokia Belle, loaded from the DMSSymbian bundle resources.
    public static var c7Image: NSImage? {
        Bundle.module.image(forResource: "nokia-c7.jpg")
    }
}
