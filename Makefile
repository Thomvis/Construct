.PHONY: sourcery 

sourcery:
	sh scripts/sourcery-gen.sh

openapi:
	uv run --project Server python scripts/generate_openapi.py
