//
//  NoteTextView.swift
//  quivnote
//

import AppKit
import SwiftUI

struct NoteTextView: NSViewRepresentable {
    @Binding var text: String
    var showLineNumbers: Bool
    var tabID: UUID
    var onStatus: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.scrollerStyle = .overlay

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = QuivPalette.nsInk
        textView.insertionPointColor = QuivPalette.nsAccent
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.usesFindBar = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: .greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 12, height: 14)

        // Better line spacing
        textView.defaultParagraphStyle = {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 3
            return style
        }()

        scroll.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.installRuler(on: scroll)
        context.coordinator.applyLineNumbers(showLineNumbers)
        context.coordinator.applyInlineHighlight()
        context.coordinator.observeNotifications(tabID: tabID)

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }

        if context.coordinator.tabID != tabID {
            context.coordinator.tabID = tabID
            context.coordinator.observeNotifications(tabID: tabID)
            textView.string = text
            context.coordinator.applyInlineHighlight()
        } else if textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
            let max = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(selected.location, max), length: 0))
            context.coordinator.applyInlineHighlight()
        }

        context.coordinator.applyLineNumbers(showLineNumbers)
        textView.textColor = QuivPalette.nsInk
        textView.insertionPointColor = QuivPalette.nsAccent
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteTextView
        weak var textView: NSTextView?
        var tabID: UUID
        private var observers: [NSObjectProtocol] = []
        private var ruler: LineNumberRulerView?

        init(_ parent: NoteTextView) {
            self.parent = parent
            self.tabID = parent.tabID
        }

        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }

        func installRuler(on scroll: NSScrollView) {
            let ruler = LineNumberRulerView(scrollView: scroll)
            self.ruler = ruler
            scroll.verticalRulerView = ruler
            scroll.hasVerticalRuler = true
            scroll.rulersVisible = false
        }

        func applyLineNumbers(_ show: Bool) {
            guard let scroll = textView?.enclosingScrollView else { return }
            scroll.rulersVisible = show
            ruler?.needsDisplay = true
        }

        func observeNotifications(tabID: UUID) {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
            let center = NotificationCenter.default

            observers.append(center.addObserver(forName: .quivFind, object: nil, queue: .main) { [weak self] note in
                guard let self,
                      let info = note.userInfo,
                      info["tabID"] as? String == tabID.uuidString,
                      let query = info["query"] as? String,
                      let forward = info["forward"] as? Bool
                else { return }
                self.find(query: query, forward: forward)
            })

            observers.append(center.addObserver(forName: .quivReplaceOne, object: nil, queue: .main) { [weak self] note in
                guard let self,
                      let info = note.userInfo,
                      info["tabID"] as? String == tabID.uuidString,
                      let query = info["query"] as? String,
                      let replacement = info["replacement"] as? String
                else { return }
                self.replaceOne(query: query, replacement: replacement)
            })

            observers.append(center.addObserver(forName: .quivReloadText, object: nil, queue: .main) { [weak self] note in
                guard let self, note.object as? String == tabID.uuidString, let textView = self.textView else { return }
                textView.string = self.parent.text
                self.applyInlineHighlight()
            })

            observers.append(center.addObserver(forName: .quivFocusEditor, object: nil, queue: .main) { [weak self] _ in
                guard let textView = self?.textView else { return }
                textView.window?.makeFirstResponder(textView)
            })
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            applyInlineHighlight()
            ruler?.needsDisplay = true
        }

        func applyInlineHighlight() {
            guard let textView, let storage = textView.textStorage else { return }
            let full = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.removeAttribute(.foregroundColor, range: full)
            storage.removeAttribute(.font, range: full)
            storage.removeAttribute(.backgroundColor, range: full)
            storage.addAttribute(.foregroundColor, value: QuivPalette.nsInk, range: full)
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15), range: full)

            let ns = storage.string as NSString

            // Headings — accent color, bolder
            let headingPattern = #"^(#{1,6})\s+(.+)$"#
            if let headingRegex = try? NSRegularExpression(pattern: headingPattern, options: .anchorsMatchLines) {
                headingRegex.enumerateMatches(in: storage.string, options: [], range: full) { match, _, _ in
                    guard let match, match.numberOfRanges >= 3 else { return }
                    let hashRange = match.range(at: 1)
                    let textRange = match.range(at: 2)
                    storage.addAttribute(.foregroundColor, value: QuivPalette.nsAccent, range: textRange)
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15, weight: .bold), range: textRange)
                    storage.addAttribute(.foregroundColor, value: QuivPalette.nsMuted.withAlphaComponent(0.5), range: hashRange)
                }
            }

            let patterns: [(String, NSFont, NSColor?)] = [
                (#"\*\*(.+?)\*\*"#, .systemFont(ofSize: 15, weight: .semibold), nil),
                (#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, .systemFont(ofSize: 15).withItalicTrait, nil),
                (#"`([^`]+)`"#, .systemFont(ofSize: 15), QuivPalette.nsAccent.withAlphaComponent(0.12)),
            ]

            for (pattern, font, background) in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                regex.enumerateMatches(in: storage.string, options: [], range: full) { match, _, _ in
                    guard let match, match.numberOfRanges >= 2 else { return }
                    let inner = match.range(at: 1)
                    storage.addAttribute(.font, value: font, range: inner)
                    if let background {
                        storage.addAttribute(.backgroundColor, value: background, range: match.range)
                    }
                    // Dim the markdown markers
                    let markers = [
                        NSRange(location: match.range.location, length: max(0, inner.location - match.range.location)),
                        NSRange(
                            location: NSMaxRange(inner),
                            length: max(0, NSMaxRange(match.range) - NSMaxRange(inner))
                        ),
                    ]
                    for marker in markers where marker.length > 0 {
                        storage.addAttribute(.foregroundColor, value: QuivPalette.nsMuted.withAlphaComponent(0.45), range: marker)
                    }
                    _ = ns
                }
            }
            storage.endEditing()
        }

        func find(query: String, forward: Bool) {
            guard let textView else { return }
            let hay = textView.string as NSString
            guard !query.isEmpty, hay.length > 0 else {
                parent.onStatus("No matches")
                return
            }

            let selected = textView.selectedRange()
            let start: Int
            let searchRange: NSRange
            var options: NSString.CompareOptions = []

            if forward {
                start = selected.location + selected.length
                searchRange = NSRange(location: start, length: max(0, hay.length - start))
            } else {
                options.insert(.backwards)
                start = selected.location
                searchRange = NSRange(location: 0, length: start)
            }

            var found = hay.range(of: query, options: options, range: searchRange)
            if found.location == NSNotFound {
                // Wrap
                let wrapRange = NSRange(location: 0, length: hay.length)
                found = hay.range(of: query, options: options, range: wrapRange)
            }

            if found.location == NSNotFound {
                parent.onStatus("No matches")
                return
            }

            textView.setSelectedRange(found)
            textView.scrollRangeToVisible(found)
            parent.onStatus("")
        }

        func replaceOne(query: String, replacement: String) {
            guard let textView else { return }
            let selected = textView.selectedRange()
            let ns = textView.string as NSString
            if selected.length > 0, ns.substring(with: selected) == query {
                if textView.shouldChangeText(in: selected, replacementString: replacement) {
                    textView.replaceCharacters(in: selected, with: replacement)
                    textView.didChangeText()
                }
            }
            find(query: query, forward: true)
        }
    }
}

private final class LineNumberRulerView: NSRulerView {
    init(scrollView: NSScrollView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = scrollView.documentView
        ruleThickness = 40
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard
            let textView = clientView as? NSTextView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else { return }

        // Subtle gutter background
        QuivPalette.nsBase.withAlphaComponent(0.6).setFill()
        bounds.fill()

        // Gutter separator line
        let sepRect = NSRect(x: bounds.maxX - 0.5, y: bounds.minY, width: 0.5, height: bounds.height)
        QuivPalette.nsInk.withAlphaComponent(0.06).setFill()
        sepRect.fill()

        let relativePoint = self.convert(NSPoint.zero, from: textView)
        let visible = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visible, in: textContainer)

        var lineNumber = 1
        let ns = textView.string as NSString
        ns.enumerateSubstrings(
            in: NSRange(location: 0, length: min(glyphRange.location, ns.length)),
            options: [.byLines, .substringNotRequired]
        ) { _, _, _, _ in
            lineNumber += 1
        }

        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var lineRange = NSRange()
            let rects = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &lineRange
            )
            let y = rects.minY + relativePoint.y + 2
            let label = "\(lineNumber)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: QuivPalette.nsMuted.withAlphaComponent(0.55),
            ]
            let size = label.size(withAttributes: attrs)
            label.draw(at: NSPoint(x: ruleThickness - size.width - 8, y: y), withAttributes: attrs)

            glyphIndex = NSMaxRange(lineRange)
            lineNumber += 1
        }
    }
}

private extension NSFont {
    var withItalicTrait: NSFont {
        let traits = NSFontManager.shared.convert(self, toHaveTrait: .italicFontMask)
        return traits
    }
}
