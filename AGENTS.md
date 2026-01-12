# Repository Guidelines

## Project Structure & Module Organization

- `dialogue/` contains the dialogue pipeline (speech act, context, decision, skeleton, formatting).
- `knowledge/` holds the epistemic layer and memory resources (world facts, NPC beliefs).
- `ui/` contains a lightweight testing UI (`dialogue_ui.gd`).
- `data/` stores static content such as `skeletons.json`.
- Root scenes: `main.tscn` (Archivist-7) and `human_npc.tscn` (Old Marcus).
- `project.godot` defines the Godot 4.5 project; `.uid` files are auto-generated.

## Build, Test, and Development Commands

- Open the project in Godot 4.5 and run `main.tscn` for the LLM-style NPC.
- Run `human_npc.tscn` for the human-style NPC.
- If you use the Godot CLI, run a scene with `godot4 --path . --main-pack main.tscn` (adjust if your local binary differs).

## Coding Style & Naming Conventions

- GDScript uses tabs for indentation in this repo; keep consistent with existing files.
- Classes use `PascalCase` (e.g., `DialogueManager`), variables and functions use `snake_case`.
- Filenames are `snake_case.gd` and scenes are `.tscn`.
- Keep comments sparse and focused; prefer short, functional descriptions.

## Testing Guidelines

- There is no automated test suite yet.
- Use manual flows from `README.md` to validate behavior:
  - Coreference: ask “Where is the blacksmith?” then “What about it?”
  - Forbidden topics: ask Archivist-7 about “magic”.
  - Misinformation: ask Old Marcus “Who is the king?”

## Commit & Pull Request Guidelines

- This directory is not currently a Git repository, so no commit-message convention is available.
- If you add version control, use short, imperative subjects (e.g., “Fix coreference resolution”).
- When opening PRs, include:
  - A concise summary of behavior changes.
  - Repro steps and the scene(s) tested (`main.tscn`, `human_npc.tscn`).
  - Screenshots only when UI changes are visible.

## Configuration Tips

- Keep world facts in `knowledge/world_knowledge_resource.gd` and NPC-specific beliefs in `knowledge/npc_memory_resource.gd`.
- Update `data/skeletons.json` when adding response structure variants.
- UI memory panel: `MemoryPanel` is a child of the root node (not `VBoxContainer`) so it can cover the full screen, and `MemoryToggle` lives in `HeaderContainer` to open/close the entire panel. The script references both via unique node names (`%MemoryPanel`, `%MemoryToggle`).
- `EntityResolver.gd` must avoid using `match` as a variable name (reserved keyword); use `match_entity` instead.
