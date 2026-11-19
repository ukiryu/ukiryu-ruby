#!/usr/bin/env python3
"""The platform-gems workflow matrix must equal release/platforms.json."""
import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
listed = {(p['platform'], p['runner'], p['library'], p.get('container', ''))
          for p in json.loads((root / 'release/platforms.json').read_text())['platforms']}
text = (root / '.github/workflows/platform-gems.yml').read_text()
used = set(re.findall(r'platform: (\S+)\n\s+runner: (\S+)\n\s+library: (\S+)(?:\n\s+container: (\S+))?', text))
if listed != used:
    sys.exit(f'platform matrix differs: only in json {sorted(listed - used)}, only in workflow {sorted(used - listed)}')
print(f'ok: {len(listed)} platforms agree')
