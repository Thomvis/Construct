.PHONY: lint test

lint:
	uv run --extra dev mypy .
	uv run --extra dev ruff check

test:
	uv run --extra dev pytest