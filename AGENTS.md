# Repository Guidelines
Use this guide when contributing as an autonomous agent to the HarmonyOS Javis client so your changes stay aligned with team practices.

## Project Structure & Module Organization
- `entry/src/main/ets/` follows MVVM: UI pages in `pages/`, stateful logic in `viewmodels/`, data contracts in `models/`, and shared types in `types/`.
- Reusable UI sits in `components/`, domain services in `services/`, remote connectors in `clients/`, and persistence helpers across `storage/`, `utils/`, and `animations/`.
- Tests mirror production code in `entry/src/test` using Hypium/Hamock; `CompleteTestSuite.ets` aggregates runs and `TestUtils.ets` houses shared fixtures.
- Static resources live in `AppScope/resources`, reference docs in `docs/`, and runtime config templates under `entry/src/main/resources/rawfile/*.template`.

## Build, Test & Development Commands
- `./build.sh` compiles the `.hap` via Hvigor (add `--analyze` for bundle diagnostics).
- `./deploy.sh` installs the latest build on a connected device or emulator.
- `./test.sh` runs the full suite; `./test-single.sh APIManagerTest` targets one spec, and `./fix_tests.sh` resets instrumentation before reruns if needed.

## Coding Style & Naming Conventions
- Embrace ArkTS V2 strict typing—no `any`, `unknown`, or bare `ESObject`; surface shared contracts from `types/`.
- Keep two-space indentation, PascalCase for components/services, camelCase for functions, props, and locals, and respect MVVM boundaries.
- Use the shared `Logger` instead of `console`, format with `npx prettier --write "**/*.ets"`, and satisfy `code-linter.json5` (TypeScript + security rules).

## Testing Guidelines
- Name specs `<Feature>Test.ets`, mock external services, and reuse helpers from `TestUtils.ets` for deterministic runs.
- Sustain ≈95% coverage by pairing new logic with tests and registering suites in `CompleteTestSuite.ets`.
- Run `./test.sh` before submitting; include the failing command and output in reviews when issues persist.

## Commit & Pull Request Guidelines
- Commits follow short imperative subjects (e.g., `init`) capped at 72 chars; expand context in bodies when helpful.
- Reference related issues, call out config prerequisites (like `config.json`), and document test evidence alongside changes.
- Pull requests must describe scope, attach UI screenshots or recordings when visuals shift, and flag new secrets or deployment steps.

## Configuration & Environment
- Develop with DevEco Studio 5.0+ and HarmonyOS SDK 5.0.5(17) targeting `phone@default`.
- Default backend endpoints in `config.json` point to `http://YOUR_SERVER_IP:8080/api` and `ws://YOUR_SERVER_IP:8080/ws`; never commit real keys.
- Deploy only to trusted devices, rotate credentials after leaks, and keep sensitive files out of version control.
