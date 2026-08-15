#!/usr/bin/env python3
"""Per-area coverage gate for the Doctor App frontend CI.

Reads the `coverage/lcov.info` produced by `flutter test --coverage` and
enforces >= 80% statement coverage on the areas that make up the project's
testability gate (see .opencode/plans/IMPLEMENTATION_PLAN.md, section 3.4).

Exclusions:
  - `*.g.dart` — generated code (drift) that is not hand-tested.
  - `core/llm/cloud_llm_adapter.dart` — cloud fallback path; per the Q5
    decision cloud wiring stays as skeleton/deferred, so it is not part
    of the gate.

Usage: python3 tool/coverage_gate.py [coverage/lcov.info]
Exit code 0 when every area meets the threshold, 1 otherwise.
"""

import sys

THRESHOLD = 80.0

AREAS = {
    'cubits': ('features/note_assist/presentation/cubit/', ()),
    'core services': ('core/services/', ()),
    'note_assist data/repos': ('features/note_assist/data/', ('g.dart',)),
    'domain services': ('features/note_assist/domain/', ()),
    'llm adapters': ('core/llm/', ('cloud_llm_adapter.dart',)),
}

def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else 'coverage/lcov.info'
    per_file: dict[str, list[int]] = {}
    current = None
    try:
        with open(path) as fh:
            for raw in fh:
                line = raw.strip()
                if line.startswith('SF:'):
                    current = line[3:]
                    per_file.setdefault(current, [0, 0])
                elif line.startswith('LF:'):
                    per_file[current][0] += int(line[3:])
                elif line.startswith('LH:'):
                    per_file[current][1] += int(line[3:])
    except FileNotFoundError:
        print(f'ERROR: {path} not found. Run `flutter test --coverage` first.')
        return 1
    if not per_file:
        print('ERROR: no coverage data found.')
        return 1

    ok = True
    print(f"{'area':<26}{'lines':>8}{'hit':>8}{'pct':>8}  threshold")
    for name, (substr, excludes) in AREAS.items():
        lf = lh = 0
        for filename, (f_lf, f_lh) in per_file.items():
            if substr not in filename:
                continue
            if any(filename.endswith(x) for x in excludes):
                continue
            lf += f_lf
            lh += f_lh
        pct = (100.0 * lh / lf) if lf else 0.0
        status = 'PASS' if pct >= THRESHOLD else 'FAIL'
        if pct < THRESHOLD:
            ok = False
        print(f"{name:<26}{lf:>8}{lh:>8}{pct:>7.1f}%   {THRESHOLD:.0f}%  {status}")

    if not ok:
        print(f'\nCoverage gate FAILED: all areas must be >= {THRESHOLD:.0f}%.')
        return 1
    print('\nCoverage gate PASSED.')
    return 0

if __name__ == '__main__':
    sys.exit(main())
