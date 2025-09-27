# Agent Guidelines

- Favor well-maintained open-source libraries when they align with project needs and licensing.

- Breaking API changes are acceptable until Mechanical Muse launches; coordinate with app team before locking contracts.

## Tooling reminders

- Manage dependencies with [uv](https://github.com/astral-sh/uv). From `Server/`, run `uv sync` (and `uv sync --extra dev` when you need the lint/test toolchain).
- After making changes, run the linters (`make lint`) and resolve the issues.
- Run the test suite with `make test` to ensure the FastAPI app and helpers behave as expected.
