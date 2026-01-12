# Project Notes

- UI memory panel: `MemoryPanel` is a child of the root node (not `VBoxContainer`) so it can cover the full screen, and `MemoryToggle` lives in `HeaderContainer` to open/close the entire panel. The script references both via unique node names (`%MemoryPanel`, `%MemoryToggle`).
- `EntityResolver.gd` must avoid using `match` as a variable name (reserved keyword); use `match_entity` instead.
