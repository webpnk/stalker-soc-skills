"""Lists objects of a decompiled level: section counts, or every object of given sections.
Usage: python list_objects.py <level> [section ...]"""
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spawnlib  # noqa: E402

BASE = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "work", "spawn_soc", "all_soc")
level = sys.argv[1]
_, secs = spawnlib.parse(os.path.join(BASE, "alife_%s.ltx" % level))
if len(sys.argv) == 2:
    for sec, n in sorted(Counter(s.section_name for s in secs).items()):
        print("%4d  %s" % (n, sec))
else:
    for s in secs:
        if s.section_name in sys.argv[2:]:
            p = s.position()
            cd = " | ".join(ln.strip() for ln in s.lines if ln.strip().startswith(("cfg", "respawn_section", "story_id")))
            print("%-40s %-22s %7.0f %6.0f %7.0f  %s" % (s.name, s.section_name, p[0], p[1], p[2], cd))
