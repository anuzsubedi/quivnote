//
//  NoteTextView.swift
//  quivnote
//

import AppKit
import SwiftUI

enum MarkdownFormatStyle {
    case bold
    case italic
    case underline

    var opening: String {
        switch self {
        case .bold: "**"
        case .italic: "*"
        case .underline: "<u>"
        }
    }

    var closing: String {
        switch self {
        case .bold: "**"
        case .italic: "*"
        case .underline: "</u>"
        }
    }
}

struct NoteTextView: NSViewRepresentable {
    @Binding var text: String
    var showLineNumbers: Bool
    var mode: NoteEditorMode
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

        let textView = MarkdownTextView()
        textView.delegate = context.coordinator
        textView.onFormat = { [weak coordinator = context.coordinator] style in
            coordinator?.toggleFormatting(style)
        }
        textView.onPasteURLOverSelection = { [weak coordinator = context.coordinator] in
            coordinator?.pasteURLOverSelection() ?? false
        }
        textView.string = text
        textView.font = .systemFont(ofSize: 15.5)
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
        textView.linkTextAttributes = [
            .foregroundColor: QuivPalette.nsAccent,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        textView.usesFindBar = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: .greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 22, height: 22)

        // Better line spacing
        textView.defaultParagraphStyle = {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 4
            style.paragraphSpacing = 2
            return style
        }()

        scroll.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.installRuler(on: scroll)
        context.coordinator.applyLineNumbers(showLineNumbers)
        context.coordinator.applyRendering()
        context.coordinator.observeNotifications(tabID: tabID)

        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }

        if context.coordinator.tabID != tabID {
            context.coordinator.tabID = tabID
            context.coordinator.observeNotifications(tabID: tabID)
            textView.string = text
            context.coordinator.applyRendering()
        } else if textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
            let max = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(selected.location, max), length: 0))
            context.coordinator.applyRendering()
        }

        context.coordinator.applyLineNumbers(showLineNumbers)
        textView.textColor = QuivPalette.nsInk
        textView.insertionPointColor = QuivPalette.nsAccent
        textView.setAccessibilityLabel("Markdown note editor")
        context.coordinator.applyRendering()
        textView.setAccessibilityHelp(mode == .wysiwyg ? "Write Markdown with live formatting" : "Edit Markdown source")
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
                self.applyRendering()
            })

            observers.append(center.addObserver(forName: .quivFocusEditor, object: nil, queue: .main) { [weak self] _ in
                guard let textView = self?.textView else { return }
                textView.window?.makeFirstResponder(textView)
            })

            observers.append(center.addObserver(forName: .quivAppearanceChanged, object: nil, queue: .main) { [weak self] _ in
                guard let self, let textView = self.textView else { return }
                textView.textColor = QuivPalette.nsInk
                textView.insertionPointColor = QuivPalette.nsAccent
                self.applyRendering()
                self.ruler?.needsDisplay = true
            })
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            applyRendering()
            ruler?.needsDisplay = true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            if parent.mode == .wysiwyg {
                applyRendering()
            }
        }

        func applyRendering() {
            guard parent.mode != .preview else { return }
            if parent.mode == .wysiwyg {
                applyLivePreview()
            } else {
                applySourceHighlight()
            }
        }

        private func resetAttributes(_ storage: NSTextStorage) {
            let full = NSRange(location: 0, length: storage.length)
            storage.removeAttribute(.foregroundColor, range: full)
            storage.removeAttribute(.font, range: full)
            storage.removeAttribute(.backgroundColor, range: full)
            storage.removeAttribute(.paragraphStyle, range: full)
            storage.removeAttribute(.kern, range: full)
            storage.removeAttribute(.strikethroughStyle, range: full)
            storage.removeAttribute(.underlineStyle, range: full)
            storage.removeAttribute(.link, range: full)
            storage.addAttribute(.foregroundColor, value: QuivPalette.nsInk, range: full)
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15.5), range: full)
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 4
            style.paragraphSpacing = 2
            storage.addAttribute(.paragraphStyle, value: style, range: full)
        }

        private func applySourceHighlight() {
            guard let textView, let storage = textView.textStorage else { return }
            let full = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            resetAttributes(storage)

            let ns = storage.string as NSString

            // Headings — accent color, bolder
            let headingPattern = #"^(#{1,6})\s+(.+)$"#
            if let headingRegex = try? NSRegularExpression(pattern: headingPattern, options: .anchorsMatchLines) {
                headingRegex.enumerateMatches(in: storage.string, options: [], range: full) { match, _, _ in
                    guard let match, match.numberOfRanges >= 3 else { return }
                    let hashRange = match.range(at: 1)
                    let textRange = match.range(at: 2)
                    storage.addAttribute(.foregroundColor, value: QuivPalette.nsAccent, range: textRange)
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15.5, weight: .bold), range: textRange)
                    storage.addAttribute(.foregroundColor, value: QuivPalette.nsMuted.withAlphaComponent(0.5), range: hashRange)
                }
            }

            let patterns: [(String, NSFont, NSColor?)] = [
                (#"\*\*(.+?)\*\*"#, .systemFont(ofSize: 15.5, weight: .semibold), nil),
                (#"__(.+?)__"#, .systemFont(ofSize: 15.5, weight: .semibold), nil),
                (#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, .systemFont(ofSize: 15.5).withItalicTrait, nil),
                (#"(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#, .systemFont(ofSize: 15.5).withItalicTrait, nil),
                (#"`([^`]+)`"#, .monospacedSystemFont(ofSize: 14.5, weight: .regular), QuivPalette.nsAccent.withAlphaComponent(0.12)),
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

            let decoratedPatterns: [(String, NSAttributedString.Key, Any)] = [
                (#"~~([^\n~]+)~~"#, .strikethroughStyle, NSUnderlineStyle.single.rawValue),
                (#"(?i)<u>([^<\n]+)</u>"#, .underlineStyle, NSUnderlineStyle.single.rawValue),
            ]
            for (pattern, attribute, value) in decoratedPatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                regex.enumerateMatches(in: storage.string, options: [], range: full) { match, _, _ in
                    guard let match, match.numberOfRanges >= 2 else { return }
                    storage.addAttribute(attribute, value: value, range: match.range(at: 1))
                    let inner = match.range(at: 1)
                    storage.addAttribute(.foregroundColor, value: QuivPalette.nsMuted.withAlphaComponent(0.45), range: NSRange(location: match.range.location, length: inner.location - match.range.location))
                    storage.addAttribute(.foregroundColor, value: QuivPalette.nsMuted.withAlphaComponent(0.45), range: NSRange(location: NSMaxRange(inner), length: NSMaxRange(match.range) - NSMaxRange(inner)))
                }
            }
            storage.endEditing()
            textView.typingAttributes = [
                .font: NSFont.systemFont(ofSize: 15.5),
                .foregroundColor: QuivPalette.nsInk,
            ]
        }

        private func applyLivePreview() {
            guard let textView, let storage = textView.textStorage else { return }
            guard !textView.hasMarkedText() else { return }
            let full = NSRange(location: 0, length: storage.length)
            let source = storage.string as NSString
            let selection = textView.selectedRange()
            let activeLine = source.length == 0
                ? NSRange(location: 0, length: 0)
                : source.lineRange(for: NSRange(location: min(selection.location, source.length), length: 0))

            storage.beginEditing()
            resetAttributes(storage)

            // A block becomes a heading only after the caret has moved to another line.
            if let regex = try? NSRegularExpression(pattern: #"^( {0,3})(#{1,6})[\t ]+(.+?)[\t ]*#*[\t ]*$"#, options: .anchorsMatchLines) {
                regex.enumerateMatches(in: storage.string, options: [], range: full) { match, _, _ in
                    guard let match, match.numberOfRanges >= 4,
                          NSIntersectionRange(match.range, activeLine).length == 0,
                          !isInsideFencedCode(at: match.range.location, source: source)
                    else { return }
                    let hashes = match.range(at: 2)
                    let content = match.range(at: 3)
                    let level = hashes.length
                    let sizes: [CGFloat] = [27, 23, 20, 18, 16.5, 15.5]
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: sizes[level - 1], weight: .bold), range: content)
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.lineSpacing = 3
                    paragraph.paragraphSpacingBefore = level <= 2 ? 10 : 6
                    paragraph.paragraphSpacing = level <= 2 ? 7 : 4
                    storage.addAttribute(.paragraphStyle, value: paragraph, range: match.range)
                    hideMarker(match.range(at: 1), in: storage)
                    hideMarker(hashes, in: storage)
                    let gap = NSRange(location: NSMaxRange(hashes), length: max(0, content.location - NSMaxRange(hashes)))
                    hideMarker(gap, in: storage)
                    let closing = NSRange(location: NSMaxRange(content), length: max(0, NSMaxRange(match.range) - NSMaxRange(content)))
                    hideMarker(closing, in: storage)
                }
            }

            applyBlockStyles(storage: storage, selection: selection, activeLine: activeLine)

            let codePattern = #"(?<!\\)`([^`\n]+)`"#
            let codeRanges = matchRanges(pattern: codePattern, in: storage.string)
            applyCompletedInline(pattern: codePattern, font: .monospacedSystemFont(ofSize: 14.5, weight: .regular), background: QuivPalette.nsAccent.withAlphaComponent(0.10), storage: storage, selection: selection)
            applyCompletedInline(pattern: #"(?<!\\)\*\*([^\n*](?:[^\n]*?[^\n*])?)\*\*"#, font: .systemFont(ofSize: 15.5, weight: .bold), background: nil, storage: storage, selection: selection, excluding: codeRanges)
            applyCompletedInline(pattern: #"(?<![\\_\p{L}\p{N}])__(?!_)([^\n_](?:[^\n]*?[^\n_])?)__(?![_\p{L}\p{N}])"#, font: .systemFont(ofSize: 15.5, weight: .bold), background: nil, storage: storage, selection: selection, excluding: codeRanges)
            applyCompletedInline(pattern: #"(?<![\\*])\*(?!\*)([^\n*]+?)\*(?!\*)"#, font: NSFont.systemFont(ofSize: 15.5).withItalicTrait, background: nil, storage: storage, selection: selection, excluding: codeRanges)
            applyCompletedInline(pattern: #"(?<![\\_\p{L}\p{N}])_(?!_)([^\n_]+?)_(?![_\p{L}\p{N}])"#, font: NSFont.systemFont(ofSize: 15.5).withItalicTrait, background: nil, storage: storage, selection: selection, excluding: codeRanges)
            applyCompletedInline(pattern: #"(?<!\\)~~([^\n~]+)~~"#, font: .systemFont(ofSize: 15.5), background: nil, storage: storage, selection: selection, strikethrough: true, excluding: codeRanges)
            applyCompletedInline(pattern: #"(?i)<u>([^<\n]+)</u>"#, font: .systemFont(ofSize: 15.5), background: nil, storage: storage, selection: selection, underline: true, excluding: codeRanges)
            applyImages(storage: storage, selection: selection, excluding: codeRanges)
            applyLinks(storage: storage, selection: selection, excluding: codeRanges)
            applyAutolinks(storage: storage, selection: selection, excluding: codeRanges)
            applyDetectedLinks(storage: storage, excluding: codeRanges + matchRanges(pattern: #"!?\[[^\]\n]+\]\([^\)\n]+\)"#, in: storage.string))

            storage.endEditing()
            textView.typingAttributes = [
                .font: NSFont.systemFont(ofSize: 15.5),
                .foregroundColor: QuivPalette.nsInk,
            ]
        }

        private func applyCompletedInline(
            pattern: String,
            font: NSFont,
            background: NSColor?,
            storage: NSTextStorage,
            selection: NSRange,
            strikethrough: Bool = false,
            foreground: NSColor? = nil,
            underline: Bool = false,
            excluding excludedRanges: [NSRange] = []
        ) {
            let full = NSRange(location: 0, length: storage.length)
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            regex.enumerateMatches(in: storage.string, options: [], range: full) { match, _, _ in
                guard let match, match.numberOfRanges >= 2,
                      !excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }),
                      !isInsideFencedCode(at: match.range.location, source: storage.string as NSString)
                else { return }
                let inner = match.range(at: 1)
                storage.addAttribute(.font, value: font, range: inner)
                if let background { storage.addAttribute(.backgroundColor, value: background, range: inner) }
                if strikethrough { storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: inner) }
                if let foreground { storage.addAttribute(.foregroundColor, value: foreground, range: inner) }
                if underline { storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: inner) }

                // Keep syntax visible while the caret is inside the construct; a just-typed
                // closing marker places the caret at the end and therefore renders immediately.
                let editingSyntax = selection.length == 0
                    && selection.location >= match.range.location
                    && selection.location < NSMaxRange(match.range)
                guard !editingSyntax else {
                    let markerColor = QuivPalette.nsMuted.withAlphaComponent(0.45)
                    storage.addAttribute(.foregroundColor, value: markerColor, range: NSRange(location: match.range.location, length: inner.location - match.range.location))
                    storage.addAttribute(.foregroundColor, value: markerColor, range: NSRange(location: NSMaxRange(inner), length: NSMaxRange(match.range) - NSMaxRange(inner)))
                    return
                }
                hideMarker(NSRange(location: match.range.location, length: inner.location - match.range.location), in: storage)
                hideMarker(NSRange(location: NSMaxRange(inner), length: NSMaxRange(match.range) - NSMaxRange(inner)), in: storage)
            }
        }

        private func matchRanges(pattern: String, in string: String) -> [NSRange] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
            let full = NSRange(location: 0, length: (string as NSString).length)
            return regex.matches(in: string, options: [], range: full).map(\.range)
        }

        private func applyBlockStyles(storage: NSTextStorage, selection: NSRange, activeLine: NSRange) {
            let full = NSRange(location: 0, length: storage.length)

            if let quoteRegex = try? NSRegularExpression(pattern: #"^( {0,3}>[\t ]?)(.+)$"#, options: .anchorsMatchLines) {
                quoteRegex.enumerateMatches(in: storage.string, options: [], range: full) { match, _, _ in
                    guard let match, match.numberOfRanges >= 3,
                          NSIntersectionRange(match.range, activeLine).length == 0
                    else { return }
                    let marker = match.range(at: 1)
                    let content = match.range(at: 2)
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.headIndent = 18
                    paragraph.firstLineHeadIndent = 18
                    paragraph.paragraphSpacing = 4
                    storage.addAttribute(.paragraphStyle, value: paragraph, range: match.range)
                    storage.addAttribute(.foregroundColor, value: QuivPalette.nsMuted, range: content)
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15.5).withItalicTrait, range: content)
                    hideMarker(marker, in: storage)
                }
            }

            if let listRegex = try? NSRegularExpression(pattern: #"^( {0,3})((?:[-+*])|(?:\d+[.)]))([\t ]+)(?:\[([ xX])\][\t ]+)?(.+)$"#, options: .anchorsMatchLines) {
                listRegex.enumerateMatches(in: storage.string, options: [], range: full) { match, _, _ in
                    guard let match, match.numberOfRanges >= 6 else { return }
                    let marker = match.range(at: 2)
                    let content = match.range(at: 5)
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.headIndent = 24
                    paragraph.firstLineHeadIndent = 4
                    paragraph.paragraphSpacing = 2
                    storage.addAttribute(.paragraphStyle, value: paragraph, range: match.range)
                    storage.addAttribute(.foregroundColor, value: QuivPalette.nsAccent, range: marker)
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15.5, weight: .semibold), range: marker)
                    if match.range(at: 4).location != NSNotFound,
                       ["x", "X"].contains((storage.string as NSString).substring(with: match.range(at: 4))) {
                        storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: content)
                        storage.addAttribute(.foregroundColor, value: QuivPalette.nsMuted, range: content)
                    }
                }
            }

            if let ruleRegex = try? NSRegularExpression(pattern: #"^( {0,3})(?:(?:\*[\t ]*){3,}|(?:-[\t ]*){3,}|(?:_[\t ]*){3,})$"#, options: .anchorsMatchLines) {
                ruleRegex.enumerateMatches(in: storage.string, options: [], range: full) { match, _, _ in
                    guard let match else { return }
                    storage.addAttribute(.foregroundColor, value: QuivPalette.nsAccent.withAlphaComponent(0.55), range: match.range)
                }
            }

            applyFencedCodeStyles(storage: storage)
            _ = selection
        }

        private func applyFencedCodeStyles(storage: NSTextStorage) {
            let source = storage.string as NSString
            var location = 0
            var fence: String?
            while location < source.length {
                let lineRange = source.lineRange(for: NSRange(location: location, length: 0))
                let line = source.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if let currentFence = fence {
                    if line.hasPrefix(currentFence) {
                        storage.addAttribute(.foregroundColor, value: QuivPalette.nsAccent.withAlphaComponent(0.5), range: lineRange)
                        fence = nil
                    } else {
                        storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular), range: lineRange)
                        storage.addAttribute(.backgroundColor, value: QuivPalette.nsAccent.withAlphaComponent(0.06), range: lineRange)
                    }
                } else if line.hasPrefix("```") {
                    fence = "```"
                    storage.addAttribute(.foregroundColor, value: QuivPalette.nsAccent.withAlphaComponent(0.5), range: lineRange)
                } else if line.hasPrefix("~~~") {
                    fence = "~~~"
                    storage.addAttribute(.foregroundColor, value: QuivPalette.nsAccent.withAlphaComponent(0.5), range: lineRange)
                }
                let next = NSMaxRange(lineRange)
                guard next > location else { break }
                location = next
            }
        }

        private func applyImages(storage: NSTextStorage, selection: NSRange, excluding excludedRanges: [NSRange]) {
            let pattern = #"(?<!\\)!\[([^\]\n]*)\]\(([^\)\n]+)\)"#
            let full = NSRange(location: 0, length: storage.length)
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            regex.enumerateMatches(in: storage.string, options: [], range: full) { match, _, _ in
                guard let match, match.numberOfRanges >= 3,
                      !excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }),
                      !isInsideFencedCode(at: match.range.location, source: storage.string as NSString)
                else { return }
                let alt = match.range(at: 1)
                if alt.length > 0 {
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15.5).withItalicTrait, range: alt)
                    storage.addAttribute(.foregroundColor, value: QuivPalette.nsMuted, range: alt)
                }
                let editingSyntax = selection.length == 0
                    && selection.location >= match.range.location
                    && selection.location < NSMaxRange(match.range)
                guard !editingSyntax else { return }
                hideMarker(NSRange(location: match.range.location, length: alt.location - match.range.location), in: storage)
                hideMarker(NSRange(location: NSMaxRange(alt), length: NSMaxRange(match.range) - NSMaxRange(alt)), in: storage)
            }
        }

        private func applyDetectedLinks(storage: NSTextStorage, excluding excludedRanges: [NSRange]) {
            guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return }
            let full = NSRange(location: 0, length: storage.length)
            detector.enumerateMatches(in: storage.string, options: [], range: full) { match, _, _ in
                guard let match, let url = match.url,
                      !excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }),
                      !isInsideFencedCode(at: match.range.location, source: storage.string as NSString),
                      let scheme = url.scheme?.lowercased(),
                      ["http", "https", "mailto"].contains(scheme)
                else { return }
                storage.addAttribute(.link, value: url, range: match.range)
                storage.addAttribute(.foregroundColor, value: QuivPalette.nsAccent, range: match.range)
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
            }
        }

        private func applyAutolinks(storage: NSTextStorage, selection: NSRange, excluding excludedRanges: [NSRange]) {
            let pattern = #"<((?:https?://|mailto:)[^>\n]+)>"#
            let full = NSRange(location: 0, length: storage.length)
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return }
            regex.enumerateMatches(in: storage.string, options: [], range: full) { match, _, _ in
                guard let match, match.numberOfRanges >= 2,
                      !excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }),
                      !isInsideFencedCode(at: match.range.location, source: storage.string as NSString)
                else { return }
                let label = match.range(at: 1)
                let target = (storage.string as NSString).substring(with: label)
                guard let url = URL(string: target),
                      let scheme = url.scheme?.lowercased(),
                      ["http", "https", "mailto"].contains(scheme)
                else { return }
                storage.addAttribute(.link, value: url, range: label)
                storage.addAttribute(.foregroundColor, value: QuivPalette.nsAccent, range: label)
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: label)
                let editingSyntax = selection.length == 0
                    && selection.location >= match.range.location
                    && selection.location < NSMaxRange(match.range)
                guard !editingSyntax else { return }
                hideMarker(NSRange(location: match.range.location, length: 1), in: storage)
                hideMarker(NSRange(location: NSMaxRange(match.range) - 1, length: 1), in: storage)
            }
        }

        private func applyLinks(storage: NSTextStorage, selection: NSRange, excluding excludedRanges: [NSRange]) {
            let pattern = #"(?<![\\!])\[([^\]\n]+)\]\(([^\)\n]+)\)"#
            let full = NSRange(location: 0, length: storage.length)
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            regex.enumerateMatches(in: storage.string, options: [], range: full) { match, _, _ in
                guard let match, match.numberOfRanges >= 3,
                      !excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }),
                      !isInsideFencedCode(at: match.range.location, source: storage.string as NSString)
                else { return }
                let label = match.range(at: 1)
                let target = (storage.string as NSString).substring(with: match.range(at: 2))
                let trimmedTarget = target.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
                if let url = URL(string: trimmedTarget),
                   let scheme = url.scheme?.lowercased(),
                   ["http", "https", "mailto"].contains(scheme) {
                    storage.addAttribute(.link, value: url, range: label)
                }
                storage.addAttribute(.foregroundColor, value: QuivPalette.nsAccent, range: label)
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: label)

                let editingSyntax = selection.length == 0
                    && selection.location >= match.range.location
                    && selection.location < NSMaxRange(match.range)
                let leading = NSRange(location: match.range.location, length: label.location - match.range.location)
                let trailing = NSRange(location: NSMaxRange(label), length: NSMaxRange(match.range) - NSMaxRange(label))
                if editingSyntax {
                    storage.addAttribute(.foregroundColor, value: QuivPalette.nsMuted.withAlphaComponent(0.45), range: leading)
                    storage.addAttribute(.foregroundColor, value: QuivPalette.nsMuted.withAlphaComponent(0.45), range: trailing)
                } else {
                    hideMarker(leading, in: storage)
                    hideMarker(trailing, in: storage)
                }
            }
        }

        func toggleFormatting(_ style: MarkdownFormatStyle) {
            guard let textView else { return }
            let selected = textView.selectedRange()
            let source = textView.string as NSString
            let opening = style.opening
            let closing = style.closing
            let openingLength = (opening as NSString).length
            let closingLength = (closing as NSString).length

            if selected.length > 0 {
                let selectedText = source.substring(with: selected)
                if selectedText.hasPrefix(opening), selectedText.hasSuffix(closing),
                   selected.length >= openingLength + closingLength {
                    let innerRange = NSRange(
                        location: openingLength,
                        length: selected.length - openingLength - closingLength
                    )
                    let inner = (selectedText as NSString).substring(with: innerRange)
                    replace(selected, with: inner, selecting: NSRange(location: selected.location, length: (inner as NSString).length))
                    return
                }

                if selected.location >= openingLength,
                   NSMaxRange(selected) + closingLength <= source.length {
                    let surrounding = NSRange(
                        location: selected.location - openingLength,
                        length: openingLength + selected.length + closingLength
                    )
                    if source.substring(with: NSRange(location: surrounding.location, length: openingLength)) == opening,
                       source.substring(with: NSRange(location: NSMaxRange(selected), length: closingLength)) == closing {
                        replace(surrounding, with: selectedText, selecting: NSRange(location: surrounding.location, length: selected.length))
                        return
                    }
                }

                let replacement = opening + selectedText + closing
                replace(selected, with: replacement, selecting: NSRange(location: selected.location + openingLength, length: selected.length))
            } else {
                replace(selected, with: opening + closing, selecting: NSRange(location: selected.location + openingLength, length: 0))
            }
        }

        func pasteURLOverSelection() -> Bool {
            guard let textView else { return false }
            let selected = textView.selectedRange()
            guard selected.length > 0,
                  var pasted = (NSPasteboard.general.string(forType: .URL)
                      ?? NSPasteboard.general.string(forType: .string))?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !pasted.isEmpty
            else { return false }

            if pasted.hasPrefix("www.") { pasted = "https://" + pasted }
            guard let url = URL(string: pasted),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https", "mailto"].contains(scheme)
            else { return false }

            let source = textView.string as NSString
            let selectedText = source.substring(with: selected)
            guard !selectedText.contains("\n") else { return false }
            let label = selectedText
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "[", with: "\\[")
                .replacingOccurrences(of: "]", with: "\\]")
            let target = url.absoluteString
                .replacingOccurrences(of: "(", with: "%28")
                .replacingOccurrences(of: ")", with: "%29")
            let replacement = "[\(label)](\(target))"
            replace(selected, with: replacement, selecting: NSRange(location: selected.location + 1, length: (label as NSString).length))
            return true
        }

        private func replace(_ range: NSRange, with replacement: String, selecting selection: NSRange) {
            guard let textView, textView.shouldChangeText(in: range, replacementString: replacement) else { return }
            textView.replaceCharacters(in: range, with: replacement)
            textView.didChangeText()
            textView.setSelectedRange(selection)
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            let url: URL?
            if let value = link as? URL {
                url = value
            } else if let value = link as? String {
                url = URL(string: value)
            } else {
                url = nil
            }
            guard let url,
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https", "mailto"].contains(scheme)
            else { return false }
            NSWorkspace.shared.open(url)
            return true
        }

        private func isInsideFencedCode(at location: Int, source: NSString) -> Bool {
            guard location > 0 else { return false }
            let prefix = source.substring(with: NSRange(location: 0, length: min(location, source.length)))
            var inside = false
            prefix.enumerateLines { line, _ in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                    inside.toggle()
                }
            }
            return inside
        }

        private func hideMarker(_ range: NSRange, in storage: NSTextStorage) {
            guard range.length > 0 else { return }
            storage.addAttribute(.foregroundColor, value: NSColor.clear, range: range)
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 0.1), range: range)
            storage.addAttribute(.kern, value: -0.1, range: range)
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

private final class MarkdownTextView: NSTextView {
    var onFormat: ((MarkdownFormatStyle) -> Void)?
    var onPasteURLOverSelection: (() -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard modifiers == .command else { return super.performKeyEquivalent(with: event) }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "x":
            cut(nil)
            return true
        case "c":
            copy(nil)
            return true
        case "v":
            paste(nil)
            return true
        case "a":
            selectAll(nil)
            return true
        case "z" where event.modifierFlags.contains(.shift):
            undoManager?.redo()
            return true
        case "z":
            undoManager?.undo()
            return true
        case "b":
            onFormat?(.bold)
            return true
        case "i":
            onFormat?(.italic)
            return true
        case "u":
            onFormat?(.underline)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let isFormattingModifier = modifiers == .command || modifiers == .control
        if isFormattingModifier {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "b":
                onFormat?(.bold)
                return
            case "i":
                onFormat?(.italic)
                return
            case "u":
                onFormat?(.underline)
                return
            default:
                break
            }
        }
        super.keyDown(with: event)
    }

    override func paste(_ sender: Any?) {
        if onPasteURLOverSelection?() == true { return }
        super.paste(sender)
    }

    @objc func quivToggleBold(_ sender: Any?) {
        onFormat?(.bold)
    }

    @objc func quivToggleItalic(_ sender: Any?) {
        onFormat?(.italic)
    }

    @objc func quivToggleUnderline(_ sender: Any?) {
        onFormat?(.underline)
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
