#!/usr/bin/env python3
"""Print `<window id> <width> <height>` of the largest on-screen window owned by a pid; exit 1 when none.

  uv run --no-project --with pyobjc-framework-Quartz python window-info.py <pid>
"""
import sys

import Quartz


def main():
    pid = int(sys.argv[1])
    best = None
    for w in Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID):
        if w.get("kCGWindowOwnerPID") != pid or w.get("kCGWindowLayer") != 0:
            continue
        b = w["kCGWindowBounds"]
        area = b["Width"] * b["Height"]
        if best is None or area > best[0]:
            best = (area, w["kCGWindowNumber"], int(b["Width"]), int(b["Height"]))
    if best is None or best[2] < 300 or best[3] < 200:
        return 1
    print(best[1], best[2], best[3])
    return 0


if __name__ == "__main__":
    sys.exit(main())
