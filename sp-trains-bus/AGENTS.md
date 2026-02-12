# AGENTS.md

Purpose: reduce tokens and ambiguity for AI agents implementing features in this repo.

## 1) Path Rules
- Treat this file's directory as project root: `ROOT=.`.
- Use only root-relative paths (example: `App/...`, `Infrastructure/...`).
- Never use absolute machine-specific paths.

## 2) How to Work
- Read only files needed for the current task.
- Prefer targeted search (`rg`) before opening files.
- Keep edits minimal and localized.
- Preserve existing architecture and naming patterns.
- Do not refactor unrelated code.

## 3) Project Structure (quick map)
- `App/`: app entry, composition, startup.
- `Application/`: use cases, orchestration.
- `Domain/`: entities, business rules, protocols.
- `Infrastructure/`: API, persistence, external integrations.
- `Presentation/`: UI, view models, state handling.
- `Resources/`: assets, plist, static resources.
- `Tests/`: unit/integration/UI tests.

## 4) Implementation Guidelines
- Reuse existing abstractions before creating new ones.
- Keep feature boundaries aligned with layers above.
- Add/adjust tests in `Tests/` for behavior changes.
- Update docs only when behavior or setup changes.

## 5) Output Style for Agents
- Return concise summary:
  1. What changed.
  2. Why.
  3. How it was validated (tests/build).
- Reference files using root-relative paths only.

## 6) Constraints
- Do not introduce secrets or environment-specific config.
- Do not rename/move large folders unless explicitly requested.
- If requirement is unclear, state assumption briefly and proceed.
