#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-"$ROOT/Sources/TestSupport/Resources/appstore-3.0.2-rich.sqlite"}"
WORKTREE="$(mktemp -d "${TMPDIR:-/tmp}/construct-3.0.2-fixture.XXXXXX")"

cleanup() {
  git -C "$ROOT" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

git -C "$ROOT" worktree add --detach "$WORKTREE" 3.0.2
cp "$ROOT/scripts/fixtures/appstore-3.0.2-db-tool-main.swift" "$WORKTREE/Sources/DatabaseInitTool/main.swift"

# The fixture should be produced by the 3.0.2 model/persistence code, but that
# tag's SwiftPM command-line target no longer builds unchanged with the current
# host toolchain:
# - the replacement generator imports packages that were transitive in 3.0.2,
#   so DatabaseInitTool needs explicit target dependencies;
# - newer dependency constraints require a newer macOS platform than the tag
#   declared;
# - Helpers/Mailer.swift imports UIKit/MessageUI, which is not available for the
#   macOS command-line tool build and is irrelevant to database generation;
# - a few old Tagged call sites need explicit rawValue/UUID construction.
# Keep these patches scoped to the temporary worktree so the generated database
# remains a historical 3.0.2 input while the generator stays reproducible.
python3 - "$WORKTREE/Package.swift" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
text = text.replace('.macOS(.v12)', '.macOS(.v14)')
old = '''.executableTarget(
            name: "DatabaseInitTool",
            dependencies: [
                "Persistence"
            ]
        )'''
new = '''.executableTarget(
            name: "DatabaseInitTool",
            dependencies: [
                "Persistence",
                "Compendium",
                "GameModels",
                "Helpers",
                "Dice",
                .product(name: "Tagged", package: "swift-tagged")
            ]
        )'''
if old not in text:
    raise SystemExit("Could not patch DatabaseInitTool dependencies")
path.write_text(text.replace(old, new))
PY

cat > "$WORKTREE/Sources/Helpers/Mailer.swift" <<'SWIFT'
import Foundation
SWIFT
python3 - "$WORKTREE/Sources/GameModels/CompendiumRealm.swift" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
text = text.replace('.init("core")', '.init(rawValue: "core")')
text = text.replace('.init("homebrew")', '.init(rawValue: "homebrew")')
path.write_text(text)
PY
python3 - "$WORKTREE/Sources/GameModels/Character.swift" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
text = text.replace(
    'Tagged(uuidString: key.identifier) ?? self.id',
    'UUID(uuidString: newValue.identifier).map { $0.tagged() } ?? self.id'
)
path.write_text(text)
PY
python3 - "$WORKTREE/Sources/Persistence/GRDB/Migrations.swift" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
text = text.replace('id: .init(name),', 'id: .init(rawValue: name),')
path.write_text(text)
PY

mkdir -p "$(dirname "$OUTPUT")"
swift run --package-path "$WORKTREE" db-tool "$OUTPUT"
