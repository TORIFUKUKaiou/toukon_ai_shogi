# Repository Guidelines

## Project Structure & Module Organization
Toukon AI Shogi targets a Phoenix LiveView stack. Product direction lives in `Requirements.md`; update it whenever scope changes. Once the Phoenix scaffold is generated, keep backend modules in `lib/toukon_ai_shogi/` and LiveView surfaces in `lib/toukon_ai_shogi_web/`. Group shared contexts under `lib/toukon_ai_shogi/<context>` and keep component modules close to their LiveViews. Static shogi piece sprites stay in `koma-assets/`. Name new assets `syougiNN_<piece>.png` to align with the existing numbering.

## Build, Test, and Development Commands
Run `mix deps.get` after pulling to sync Elixir dependencies. Use `mix phx.server` for the interactive dev server; it hot-reloads LiveViews. If you add frontend tooling, install JS assets with `npm install --prefix assets` and rebuild via `npm run deploy --prefix assets`. Execute `mix ecto.setup` when database support lands; skip until schemas exist.

## Coding Style & Naming Conventions
Format Elixir code with `mix format`; configure `.formatter.exs` before committing. Follow Elixir style: two-space indentation, modules in `CamelCase`, functions in `snake_case`. LiveView modules should read `ToukonAiShogiWeb.<Feature>Live`. Keep templates and components descriptive—e.g., `board_live.html.heex` for the board surface.

## Testing Guidelines
Rely on ExUnit. Place tests under `test/`, mirroring the module path and ending files with `_test.exs`. Smoke-test LiveViews with `Phoenix.LiveViewTest`, and exercise domain contexts with focused unit tests. Run `mix test` for the suite and `mix test --cover` before merging features that touch gameplay logic.

## Commit & Pull Request Guidelines
Commits use short, imperative subjects (see `Add project requirements and shogi piece assets`). Scope body text to what changed and why. For PRs, supply a crisp summary, link any tracking issue, note migrations or config flags, and attach screenshots or recordings for UI updates. Ensure CI-ready by running formatter and tests locally before requesting review.
