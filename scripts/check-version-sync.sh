#!/bin/sh
# Tool version: 1.0.0. Read component declarations; never source installer code.
set -eu
exec python3 - "$@" <<'PY'
from pathlib import Path
import re, subprocess, sys

if sys.argv[1:] not in ([], ['--staged']):
    raise SystemExit('Usage: scripts/check-version-sync.sh [--staged]')
staged = bool(sys.argv[1:])
root = Path.cwd().resolve()
def read(path):
    candidate = (root / path).resolve()
    if not candidate.is_relative_to(root):
        raise ValueError('component path escapes repository')
    if staged:
        return subprocess.check_output(['git', 'show', ':' + path], text=True)
    return candidate.read_text()

try:
    handoff = read('docs/llm/HANDOFF.md')
    section = handoff.split('## Current Versions\n', 1)[1].split('\n## ', 1)[0]
    rows = re.findall(r'^- ([\w./-]+\.sh): (\d+\.\d+\.\d+)\s*$', section, re.M)
    if not rows or len({path for path, _ in rows}) != len(rows):
        raise ValueError('missing or duplicate component version declarations')
    failures = []
    for path, expected in rows:
        text = read(path)
        values = re.findall(r'^VERSION=["\x27]?(\d+\.\d+\.\d+)["\x27]?\s*$', text, re.M)
        if not values:
            values = re.findall(r'^# Version (\d+\.\d+\.\d+)\s*$', text, re.M)
        if values != [expected]:
            failures.append(path + ': declaration does not match ' + expected)
    if failures:
        raise ValueError('; '.join(failures))
except (OSError, ValueError, IndexError, subprocess.CalledProcessError) as error:
    print('FAIL: ' + str(error))
    raise SystemExit(1)
print('PASS: ' + str(len(rows)) + ' component declarations match HANDOFF; no shared project version.')
PY
