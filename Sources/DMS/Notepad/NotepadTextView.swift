import SwiftUI
import AppKit

/// AppKit-backed text editor for NotepadView (spec 27 §6 contained bridge).
/// Replaces SwiftUI `TextEditor` so the find & replace bar can drive selection jumps
/// through `focusRange` (set → select + scroll into view → cleared).
public struct NotepadTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor
    var backgroundColor: NSColor
    var focusRange: Binding<NSRange?>?

    public init(
        text: Binding<String>,
        font: NSFont,
        textColor: NSColor,
        backgroundColor: NSColor,
        focusRange: Binding<NSRange?>? = nil
    ) {
        self._text = text
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.focusRange = focusRange
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.drawsBackground = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.string = text

        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            // Preserve the caret/selection across external content updates (e.g. replace-all).
            let selected = textView.selectedRange()
            textView.string = text
            let clamped = NSRange(location: min(selected.location, (text as NSString).length),
                                  length: min(selected.length, max(0, (text as NSString).length - min(selected.location, (text as NSString).length))))
            textView.setSelectedRange(clamped)
        }

        if let range = focusRange?.wrappedValue {
            let length = (textView.string as NSString).length
            let location = min(range.location, length)
            let clamped = NSRange(location: location, length: min(range.length, max(0, length - location)))
            textView.setSelectedRange(clamped)
            textView.scrollRangeToVisible(clamped)
            focusRange?.wrappedValue = nil
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NotepadTextView

        init(_ parent: NotepadTextView) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
