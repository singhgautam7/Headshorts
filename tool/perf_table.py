#!/usr/bin/env python3
"""tool/perf_table.py a.json [b.json]: side-by-side frame numbers."""
import json, sys
F = [json.load(open(p)) for p in sys.argv[1:]]
def flat(d, pre=''):
    for k, v in d.items():
        if isinstance(v, dict) and 'build_p50' in v: yield pre + k, v
        elif isinstance(v, dict): yield from flat(v, pre + k + '/')
rows = {}
for i, f in enumerate(F):
    for k, v in flat(f): rows.setdefault(k, {})[i] = v
print('| Action | ' + ' | '.join(f'run {i}: build p50/p90/worst · raster p50/p90/worst · >16 build+raster/frames' for i in range(len(F))) + ' |')
print('|---' * (len(F) + 1) + '|')
for k, v in rows.items():
    c = []
    for i in range(len(F)):
        s = v.get(i)
        c.append('-' if not s else f"{s['build_p50']}/{s['build_p90']}/**{s['build_worst']}** · {s['raster_p50']}/{s['raster_p90']}/{s['raster_worst']} · {s['build_over16']}+{s['raster_over16']}/{s['frames']}" + (f" · {s['ms_to_screen']}ms" if 'ms_to_screen' in s else ''))
    print(f'| {k} | ' + ' | '.join(c) + ' |')
for k in sorted({k for f in F for k, v in f.items() if not isinstance(v, (dict, list))}):
    print(f'- {k}: ' + ' -> '.join(str(f.get(k)) for f in F))
