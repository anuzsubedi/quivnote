# Contributing

## Workflow

1. Create a focused `feature/`, `fix/`, or `chore/` branch from `main`.
2. Keep each change scoped; avoid combining refactors with unrelated behavior changes.
3. Update documentation when behavior, shortcuts, storage, or project structure changes.
4. Review the final diff for generated files, personal Xcode state, and secrets before committing.

## Source organization

- **App** owns lifecycle and macOS integration.
- **DesignSystem** owns shared visual tokens and appearance preferences.
- **Models** owns application state and persistence.
- **Views** owns presentation and user interaction.
- Prefer one primary type per file and name the file after that type.
- Keep reusable UI in `Views/Components` rather than embedding it in feature screens.

## Repository hygiene

- Keep `Package.resolved` tracked.
- Do not commit `xcuserdata`, Derived Data, local build output, or machine-specific configuration.
- Never commit credentials or signing material. Use an ignored `*.xcconfig.local` file for local-only values if the project later needs them.
- Treat changes to `project.pbxproj` as code: inspect them carefully and avoid unrelated Xcode churn.

## Validation

Before opening a pull request, use Xcode to build the app and manually exercise the behavior affected by the change. Document what you validated in the pull-request description.

