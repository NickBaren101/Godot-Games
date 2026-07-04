# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Gunvolt** project, a Godot 4.6 game using:
- **Engine**: Godot 4.6 with GL Compatibility renderer
- **Physics**: Jolt Physics (3D)
- **Platform**: Windows (D3D12) primary, with mobile support via GL Compatibility

## Project Structure

```
gunvolt/
├── project.godot          # Godot engine configuration
├── Assets/                # All game assets (sprites, meshes, audio, fonts, etc.)
├── Scenes/                # Scene files (.tscn) organized by feature/component
├── Scripts/               # GDScript files (.gd) with matching folder structure to Scenes/
├── icon.svg               # Project icon
└── .godot/                # Godot editor cache and configuration
```

### Key Directories

- **Assets/**: Contains all project resources: sprites, 3D meshes, audio files, fonts, UI layouts, textures, and other media.
- **Scenes/**: Contains all `.tscn` (scene) files, organized into subdirectories by feature or component (e.g., UI scenes, player scenes, enemy scenes).
- **Scripts/**: Contains all `.gd` (GDScript) files. Folder structure mirrors the `Scenes/` directory exactly for easy navigation.

### Folder Matching Convention

Scenes and their corresponding scripts share the same relative path structure. To find or create a script for a scene, simply replace `Scenes/` with `Scripts/` in the file path. This makes it immediately clear which script belongs to which scene and simplifies asset organization.

## Common Development Commands

### Opening and Running the Project

```bash
# Open the Godot editor
godot --path . --editor

# Run the game
godot --path .

# Run with debug output
godot --path . -v
```

### Building and Export

Configure exports in the Godot editor under **Project > Project Settings > Export**. Primary targets:
- Windows Desktop (D3D12)
- Mobile (via GL Compatibility renderer)

## GDScript and Architecture

### Coding Conventions

- **Naming**: Use `snake_case` for variables and functions, `PascalCase` for classes and autoloads.
- **Type hints**: GDScript 2.0 (Godot 4.6) supports optional type hints. Use them for clarity, especially for public APIs.
- **Scenes and Scripts**: Each `.tscn` scene typically has an attached script (`.gd` file) defining its behavior. Scene structure and node hierarchy are defined in the `.tscn` file; logic lives in the script.

### Common Patterns

- **Autoloads**: Persistent singletons defined in project settings (`[autoload]`).
- **Signals**: GDScript uses signals for event-driven communication between nodes.
- **Input Handling**: Use the `_input()` or `_process()` callbacks on nodes that need input.

## Project Configuration

- **Physics Engine**: Jolt Physics, suitable for 3D games.
- **Rendering Method**: GL Compatibility, ensuring broad compatibility with mobile platforms and lower-end hardware.
- **Godot Version**: 4.6 (config_version=5)

## Debugging

- Use `print()` or `var_to_str()` in scripts for console output visible in Godot's output panel.
- Enable debug mode in the bottom-right of the Godot editor for detailed error messages.
- Check the **Output** panel for runtime errors and warnings.
