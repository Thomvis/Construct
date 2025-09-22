from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
SERVER_ROOT = PROJECT_ROOT / "Server"

if str(SERVER_ROOT) not in sys.path:
    sys.path.insert(0, str(SERVER_ROOT))

from app.main import create_app


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate the OpenAPI specification")
    parser.add_argument(
        "--compact",
        action="store_true",
        help="Write compact JSON without indentation",
    )
    args = parser.parse_args()

    spec = create_app().openapi()

    target = PROJECT_ROOT / "Sources" / "ConstructAPI" / "openapi.json"
    target.parent.mkdir(parents=True, exist_ok=True)

    with target.open("w", encoding="utf-8") as stream:
        if args.compact:
            json.dump(spec, stream, separators=(",", ":"), ensure_ascii=False)
        else:
            json.dump(spec, stream, indent=2, ensure_ascii=False)
            stream.write("\n")


if __name__ == "__main__":
    main()
