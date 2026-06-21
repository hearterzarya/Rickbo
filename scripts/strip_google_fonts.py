#!/usr/bin/env python3
"""
Replace GoogleFonts.baloo2(...) and GoogleFonts.hind(...) with plain TextStyle(...)
because the emulator has no internet for google_fonts to fetch from gstatic.
"""
import re
from pathlib import Path

ROOT = Path(r"C:\Users\DEll\Desktop\Rickbo")

# Match GoogleFonts.baloo2(...) and GoogleFonts.hind(...) with a balanced-ish
# parenthesis matcher. We can't use regex easily for nested parens, so we
# scan and use a depth counter.
PATTERNS = ["GoogleFonts.baloo2(", "GoogleFonts.hind("]

def replace_in_file(p: Path) -> bool:
    src = p.read_text(encoding="utf-8")
    out = []
    i = 0
    changed = False
    while i < len(src):
        # find next pattern
        next_idx = -1
        next_pat = None
        for pat in PATTERNS:
            j = src.find(pat, i)
            if j != -1 and (next_idx == -1 or j < next_idx):
                next_idx = j
                next_pat = pat
        if next_idx == -1:
            out.append(src[i:])
            break
        out.append(src[i:next_idx])
        # find matching close paren
        depth = 1
        k = next_idx + len(next_pat)
        while k < len(src) and depth > 0:
            c = src[k]
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
                if depth == 0:
                    break
            k += 1
        inner = src[next_idx + len(next_pat):k]
        out.append("TextStyle(" + inner + ")")
        i = k + 1
        changed = True
    if changed:
        p.write_text("".join(out), encoding="utf-8")
    return changed

# Replace in all dart files under apps/, packages/, but skip the canonical theme.dart in core
SKIP = {str(ROOT / "packages" / "core" / "lib" / "theme.dart")}

count = 0
for dart in list(ROOT.rglob("*.dart")):
    sp = str(dart)
    if sp in SKIP:
        continue
    if replace_in_file(dart):
        print(f"fixed: {sp}")
        count += 1

# Now strip the import line from any file that no longer uses GoogleFonts
import re as _re
for dart in list(ROOT.rglob("*.dart")):
    src = dart.read_text(encoding="utf-8")
    if "GoogleFonts." in src:
        continue
    new = _re.sub(r"^import 'package:google_fonts/google_fonts\.dart';\n", "", src, flags=_re.MULTILINE)
    if new != src:
        dart.write_text(new, encoding="utf-8")
        print(f"removed import: {dart}")

print(f"\nDone. {count} files fixed.")