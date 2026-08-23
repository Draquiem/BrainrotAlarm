import math, random
BANDS={'gentle':(0.55,1.0),'standard':(0.25,0.85),'brutal':(0.0,0.5),'nightmare':(0.0,0.3)}
GRID={'gentle':3,'standard':4,'brutal':6,'nightmare':9}

def decoys(n_others, count, diff):
    """Mirror of ChallengeSession.decoys index math. Returns (lower, upper, taken)."""
    if count <= 0: return (0,0,0)
    if n_others == 0: return (0,0,0)
    if n_others <= count: return (0, n_others, n_others)   # early return path
    lo_f, hi_f = BANDS[diff]
    lower = math.floor(n_others*lo_f)
    upper = math.ceil(n_others*hi_f)
    upper = min(upper, n_others)
    lower = max(0, min(lower, upper-1))
    while upper-lower < count:
        if lower > 0: lower -= 1
        elif upper < n_others: upper += 1
        else: break
    taken = min(count, upper-lower)
    return (lower, upper, taken)

print("pool | diff       | grid | decoys wanted | band slice | got | ok")
fails=0
for pool in (24, 16, 8, 5, 3, 2, 1):
    for diff in BANDS:
        count = GRID[diff]-1
        n_others = pool-1
        lo,hi,got = decoys(n_others, count, diff)
        want = min(count, n_others)
        ok = (got==want) and 0<=lo<=hi<=max(n_others,0)
        if not ok: fails+=1
        print(f"{pool:4d} | {diff:10s} | {GRID[diff]:4d} | {count:13d} | [{lo:2d},{hi:2d}) | {got:3d} | {'ok' if ok else 'FAIL'}")
print(f"\n{fails} failures")

# Which characters actually get picked at each difficulty, using real distances
import re
from heur import chars, dist
print("\nDecoy realism on the full roster (answer = tralalero):")
ans=[c for c in chars if c[0]=='tralalero'][0]
others=sorted((c for c in chars if c[0]!=ans[0]), key=lambda c: dist(ans,c))
for diff in BANDS:
    lo,hi,got=decoys(len(others), GRID[diff]-1, diff)
    picks=[c[0] for c in others[lo:hi]]
    print(f"  {diff:10s} draws {got} from {len(picks)} candidates: {', '.join(picks[:6])}{'...' if len(picks)>6 else ''}")
