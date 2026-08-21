# Architecture

Quivnote is a small AppKit/SwiftUI macOS application organized around a single observable workspace. The directory structure expresses ownership without introducing framework layers that the current app does not need.

## Layers

### App

`App` is the composition root. It starts the accessory application, installs menus and shortcut monitors, owns the floating panel, and connects those objects to the shared `Workspace`.

### Models

`Workspace` owns open tabs, selection, transient overlays, find-and-replace state, and workspace persistence. `NoteLibrary` owns saved-note metadata and Markdown files. UI code reads and mutates these observable models on the main actor.

### Design system

`AppearanceSettings` persists the selected appearance and accent. `QuivPalette` is the shared adaptive color vocabulary used by both SwiftUI and AppKit views.

### Views

`NoteEditorView` is the main screen. Feature overlays remain separate views, while `NoteTextView` bridges the native `NSTextView` editor into SwiftUI. Tabs select among WYSIWYG, rendered preview, and Markdown editor modes; the backing model remains plaintext Markdown in every mode.

## Data flow

```text
AppDelegate
  ├── Workspace ── NoteLibrary ── Application Support/quivnote
  ├── NotePanelController ── NoteEditorView
  ├── ShortcutMonitor
  ├── HotKeyManager
  └── AppMenus
```

User actions flow from menus, shortcut handlers, or views into `Workspace`. Observable changes redraw the SwiftUI hierarchy. Persistence remains local:

- `workspace.json` restores open tabs and editor state.
- `notes/index.json` stores saved-note metadata.
- `notes/<UUID>.md` stores each saved note body.
- `UserDefaults` stores appearance preferences.

## Dependency policy

Third-party packages should be added only when the platform SDK does not provide a clear solution. Pin resolved versions through Swift Package Manager and document each dependency in the README.
