# Hanassik Project - Workspace Customizations

This file contains rules and guidelines for Antigravity, Gemini, and other agentic AI systems when working on the Hanassik project.

## Core Rules for Agents
- **Context**: Hanassik is a minimalist, Android-first Flutter MVP for task template and checklist management.
- **Simplicity**: Maintain the current architecture. Use `shared_preferences` for storage and basic Flutter state management. Do not over-engineer or introduce complex architectures (like Clean Architecture or BLoC) without the user's explicit consent.
- **UI Consistency**: The app uses Material 3 with a primary green seed color (`0xFF2F6B4F`) and supports System Dark Mode. Ensure new UI elements adapt to both light and dark themes using `Theme.of(context).colorScheme`.
- **Key Mechanics**: The `AddTemplateSheet` relies on `ReorderableListView` for step reordering. Always use `ObjectKey` for `TextEditingController` items within lists.
- **Execution**: If you need to run static analysis, use `mise run check` or `flutter analyze`.

If you are an agent modifying this project, always adhere to these constraints to preserve the MVP's lightweight nature.
