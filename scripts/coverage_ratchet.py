#!/usr/bin/env python3
"""Coverage ratchet: compara lines% do lcov.info com o baseline.

- coverage < baseline  → exit 1 (trava regressão no CI)
- coverage > baseline  → atualiza .coverage-baseline e exit 0
"""
import sys
from pathlib import Path

LCOV = Path("coverage/lcov.info")
BASELINE_FILE = Path(".coverage-baseline")
DEFAULT_BASELINE = 55.46


def lcov_lines_percent() -> float:
    lf = lh = 0
    for line in LCOV.read_text().splitlines():
        if line.startswith("LF:"):
            lf += int(line.split(":", 1)[1])
        elif line.startswith("LH:"):
            lh += int(line.split(":", 1)[1])
    pct = round(lh / lf * 100, 2)
    if lf == 0:
        print("ERRO: lcov.info sem dados (LF total = 0)")
        sys.exit(2)
    return pct


def baseline() -> float:
    if BASELINE_FILE.exists():
        return float(BASELINE_FILE.read_text().strip())
    return DEFAULT_BASELINE


def main() -> None:
    if not LCOV.exists():
        print("ERRO: coverage/lcov.info nao encontrado. Rode flutter test --coverage.")
        sys.exit(2)
    pct = lcov_lines_percent()
    base = baseline()
    print(f"coverage lines: {pct:.2f}% | baseline: {base:.2f}%")
    if pct < base:
        print(f"FALHA: coverage {pct:.2f}% < baseline {base:.2f}% (regressao travada)")
        sys.exit(1)
    if pct > base:
        BASELINE_FILE.write_text(f"{pct:.2f}\n")
        print(f"baseline atualizado para {pct:.2f}%")
    print("OK: coverage nao regrediu")


if __name__ == "__main__":
    main()
