# Hanassik

Hanassik is a Flutter MVP for storing repeatable work sequences as templates, starting a work run from a template, and checking each step off as the work progresses.

## MVP scope

- Create reusable task templates with ordered steps.
- Start a checklist run from any saved template.
- Check and uncheck steps in an active run.
- Track progress and completion status.
- Persist templates and runs locally with `shared_preferences`.

## Run

This MVP includes Flutter web platform files. Install the pinned Flutter toolchain with `mise`:

```sh
mise install
mise run install
mise run dev
```

Run checks with:

```sh
mise run check
```
