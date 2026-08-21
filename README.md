# Quivnote

Quivnote is a lightweight native macOS menu-bar notebook for quickly capturing, organizing, and previewing Markdown notes.

## Features

- Global shortcut to show or hide the note panel
- Left-click the menu-bar icon to open the note; right-click it for app options
- Multiple editing tabs with unsaved-change protection
- Local Markdown library with search, rename, import, and export
- WYSIWYG writing (the default), Markdown preview, raw editor, find and replace, and optional line numbers
- System, light, and dark appearances with selectable accent colors
- Keyboard-first navigation and an in-app shortcut reference

## Requirements

- macOS 26.5 or later
- Xcode 26.6 or later

## Getting started

1. Clone the repository.
2. Open `quivnote.xcodeproj` in Xcode.
3. Select the **quivnote** scheme and a signing team if Xcode requests one.
4. Run the app from Xcode.

Swift Package Manager resolves the pinned MarkdownUI dependency from `Package.resolved` when the project opens.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘⌥⇧N | Show or hide the note panel |
| ⌘T / ⌘W | Open or close a tab |
| ⌘⇧] / ⌘⇧[ | Select the next or previous tab |
| ⌃Tab / ⌃⇧Tab | Select the next or previous tab |
| ⌘O / ⌘S | Open or save to the library |
| ⌘⇧I / ⌘⇧E | Import or export a Markdown file |
| ⌘F / ⌘H | Find or find and replace |
| ⌘B / ⌘I / ⌘U | Bold, italicize, or underline the selection |
| ⌘M / ⌘L | Cycle WYSIWYG, preview, and editor modes / toggle line numbers |
| ⌘, | Open appearance settings |
| ⌘/ | Pin or unpin the shortcut reference |

Holding Command by itself briefly shows the shortcut reference; releasing Command hides it unless it is pinned.

## Editor modes

- **WYSIWYG** is the default. Completed inline Markdown is formatted immediately, while block syntax such as `# Heading` stays visible until you move to the next line. Move the caret back into formatted text to reveal its Markdown markers.
- **Preview** renders the note as a read-only document.
- **Editor** keeps the Markdown source visible for precise editing.

All three modes use the same plaintext Markdown as the source of truth, so switching modes does not change saved or exported content.

Formatting shortcuts wrap selected text in Markdown-compatible syntax and insert paired markers when there is no selection. Control-B, Control-I, and Control-U are also accepted as editor-local aliases. Pasting a web URL while text is selected turns that selection into a clickable Markdown link.

### Markdown support

WYSIWYG formatting covers ATX headings, asterisk and underscore emphasis/strong text, inline and fenced code, strikethrough, links and detected URLs, images as styled alt text, blockquotes, ordered and unordered lists, task-list state, thematic breaks, and portable `<u>` underline markup. Syntax is revealed when it is useful for editing and remains the saved source of truth.

Preview uses MarkdownUI's GitHub-Flavored Markdown renderer, including headings, lists and task lists, blockquotes, fenced code, links, images, tables, and thematic breaks. Complex structures such as tables and embedded images remain source-assisted rather than fully interactive while editing in WYSIWYG.

## Data storage

Quivnote stores its workspace and note library locally under the user's Application Support directory:

```text
~/Library/Application Support/quivnote/
```

The app does not require environment variables or an external service.

Notes are stored as local plaintext Markdown and JSON. Back up this directory and avoid storing sensitive material there unless the Mac account and disk are appropriately protected.

## Project layout

```text
quivnote/
├── App/           # App lifecycle, menus, global shortcuts, and panel hosting
├── DesignSystem/  # Shared colors and appearance settings
├── Models/        # Workspace state and note persistence
├── Views/         # SwiftUI and AppKit-backed UI
└── Assets.xcassets
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for ownership boundaries and data flow. Contributor conventions are in [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Dependencies

- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) for rendered Markdown previews

Dependencies are managed through Swift Package Manager. Commit `Package.resolved` so collaborators and CI resolve the same versions.
