---
name: godot-import-sprite-character
description: Remove white or solid backgrounds from downloaded sprite-sheet PNGs with the local YummyGameTools bg-remove tool, then import, register, manage, and optionally place the resulting characters through a Godot Preset Character plugin. Use when asked to process sprite sheets into transparent textures, add characters to addons/preset_character, update preset_character_registry.json, create character scenes, or place registered characters into a specified Godot scene.
---

# Godot Sprite Character Import

Turn downloaded sprite sheets into registered, reusable Godot characters.

## Workflow

1. Inspect the Godot project before changing files:
   - Locate `project.godot`, `addons/preset_character`, the character registry, existing character scenes, and relevant target scenes.
   - Preserve unrelated worktree changes.
   - Inspect existing registered characters and follow their schema and scene structure instead of inventing a new format.

2. Locate source PNG sprite sheets in the user's Downloads directory or the path named by the user.
   - Confirm intended files by name, dimensions, frame grid, and modification time.
   - Do not assume every PNG in Downloads is a character.

3. Use the local YummyGameTools page at `http://localhost:5173/tools/bg-remove`.
   - If unavailable, start it from `E:\GameDev\YummyGameTools` with `npm run dev` when that path exists.
   - Use the Browser skill for the page interaction.
   - Load the intended images and select intelligent connected-background removal.
   - Unless overridden, use white key color, tolerance `30`, erosion `1`, feather `0`, smoothing `0`, and despill `0`.
   - Download the processed PNGs.

4. If the page processes images but its download fails, inspect the current YummyGameTools implementation (commonly `src/utils/bgRemoveUtils.ts`) and reproduce that exact algorithm locally. Do not substitute a visually similar algorithm without checking the source. For the known defaults, preserve connected edge flood-fill behavior and the erosion mask semantics used by the tool.

5. Store transparent textures under the project's established character-resource directory. Prefer `resources/character/downloaded_presets/` when the project already uses it. Use stable names such as `<character>_cutout.png`.

6. Create one Godot character scene per sprite sheet by adapting the existing Preset Character scene format.
   - Preserve the discovered frame grid and animation mappings.
   - For the current 4x8 convention, default to 10 fps only when existing presets confirm it.
   - Default `attach_controller` to `false` for NPC-like imported characters unless the user asks for a player-controlled character.

7. Update the discovered registry, commonly `scenes/characters/preset_character_registry.json`.
   - Preserve all existing entries.
   - Use `res://` paths.
   - Avoid duplicate names or paths.
   - Write UTF-8 without corrupting non-ASCII character names.

8. If the user names a target scene, instance the chosen registered character into that scene using the project's established node structure and a sensible or specified position. If no target scene is supplied, stop after registration and explicitly report that the character is ready to place through the Preset Character Dock.

## Validation

- Parse the registry as JSON and confirm every new `scene_path` and `texture_path` exists.
- Confirm output PNG dimensions match the inputs and contain transparent pixels.
- Inspect the generated `.tscn` files for valid resource paths and the expected frame/animation configuration.
- When Godot is available, run an import or headless project validation proportional to the change.
- Report processed character names, output paths, registry path, placement status, parameter values, and any fallback from the web download to the source-equivalent algorithm.

## Safety

- Never delete source images from Downloads.
- Never overwrite unrelated registry entries or user modifications.
- Do not place characters into an arbitrary scene when the user has not identified a target.
