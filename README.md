# Quivnote

Quivnote is a lightweight native macOS menu-bar notebook for quickly capturing, organizing, and previewing Markdown notes.

## Features

- Global shortcut to show or hide the note panel
- Multiple editing tabs with unsaved-change protection
- Local Markdown library with search, rename, import, and export
- Markdown preview, find and replace, and optional line numbers
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
| ⌘M / ⌘L | Toggle Markdown preview or line numbers |
| ⌘, | Open appearance settings |
| ⌘/ | Pin or unpin the shortcut reference |

Holding Command by itself briefly shows the shortcut reference; releasing Command hides it unless it is pinned.

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
