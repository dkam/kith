# Trim fixtures, v1

These files are shared by **kith-web, kith-ios and kith-android**. Each
implementation of the trim runs every case here and must produce the expected
output. If two implementations disagree, one of them has a bug; do not edit a
fixture to make one pass.

The rules are trim v1, as pinned in kith-web's `app/models/track/geo.rb` and
`Track#trim`. A changed rule is a new trim version and a new directory of
fixtures, never an edit to these.

## A case

Each `*.json` file is one case:

```json
{ "description": "what it tests, and the answer worked out by hand",
  "trim":     { "radius_m": 500, "bearing_deg": 90.0, "offset_m": 250.0 },
  "zones":    [ { "lat": 0.0, "lon": 0.03, "radius_m": 300 } ],
  "input":    { GeoJSON Feature, as below, with absolute times },
  "expected": { GeoJSON Feature, as below, with relative times } }
```

`expected` is `null` when nothing survives: no track is stored.

The input and expected tracks use the stored track format:

```json
{ "type": "Feature",
  "geometry": { "type": "MultiLineString",
                "coordinates": [[[lon, lat, ele], ...], ...] },
  "properties": { "times": [[t, ...], ...] } }
```

Elevation is absent from every position, and `times` from `properties`, when a
track has none.

## Trim v1

1. **Read.** Round every longitude and latitude to 6 decimal places and every
   elevation to 1, as the input is read. Everything below works on the rounded
   values, which are the values that get stored.
2. **Circles.** One around the ride's first point and one around its last
   point, each with radius `R = trim.radius_m`, and one around each zone's
   centre, with `R = zone.radius_m`. A circle around `p` is centred at `c`,
   which is `trim.offset_m` metres from `p` on bearing `trim.bearing_deg`,
   and has radius `ρ = R + trim.offset_m`. The offset is the same for every
   circle, whatever its radius, so circles of different radii around one
   point share a centre.
3. **Drop** every point whose distance from any circle's centre is `< ρ`,
   strictly.
4. **Split.** A dropped point ends a segment. Input segments stay separate.
5. **Discard** any segment with fewer than 2 points. No segments left means no
   track.
6. **Times** in each surviving segment become whole seconds since that
   segment's first point, so every segment's times start at 0.

The formulas, with mean Earth radius `R = 6 371 008.8 m`:

```
distance (haversine):
  a = sin²(Δφ/2) + cos φ₁ cos φ₂ sin²(Δλ/2)
  d = 2 R asin(√a)

destination, d metres from (φ₁, λ₁) on bearing θ, with δ = d / R:
  φ₂ = asin(sin φ₁ cos δ + cos φ₁ sin δ cos θ)
  λ₂ = λ₁ + atan2(sin θ sin δ cos φ₁, cos δ − sin φ₁ sin φ₂)
```

## Comparing

Compare parsed values, not bytes: key order and number formatting differ
between JSON writers. A float tolerance of `1e-9` is ample, since stored values
have 6 decimal places.

No input point lies within 1 m of any circle's boundary, so floating-point
differences between languages cannot move a point from one side to the other.
No input value sits exactly on a rounding half either, because languages
disagree about those: Python rounds half to even, while Ruby and Swift's
`rounded()` round half away from zero. Use half away from zero. `generate.py`
checks both before it writes a case.

## Where they come from

`generate.py` is a separate implementation of trim v1 in Python, written apart
from the Ruby one, and it is what computed `expected`. It is not run in CI, so
run it with `python3 generate.py .` from this directory to add a case. Every
coordinate is in open ocean, either on the equator near 0° E or on the 120° W
meridian near 40° S. Along either line, distance is exactly `R × Δ` in radians,
so each description's numbers can be checked by hand.
