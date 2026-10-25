# Architecture

outRage is organized around a small native host and data-driven target profiles.

The current foundation separates four concerns:

- **Host** — native macOS entry point and user-facing lifecycle.
- **Profiles** — versioned target metadata and backend preferences.
- **Planner** — resolves a profile against host capabilities into a launch plan.
- **Runtime storage** — stable per-user locations for runtimes, targets, caches, and logs.

Backend implementations are intentionally replaceable. Profiles select behavior without coupling the host application to a specific execution or rendering strategy.

The initial milestone is deliberately narrow: make profile validation, host capability discovery, bundle generation, and launch planning deterministic before adding heavier runtime components.
