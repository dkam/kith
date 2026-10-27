"""Trim v1, implemented apart from the Ruby, to compute the shared fixtures.

Run from this directory: python3 generate.py .
It refuses to write a case in which any input point lies within 1 m of any
circle boundary. See README.md.
"""
import json, math, os, sys

R_EARTH = 6371008.8
OUT = sys.argv[1]
MARGIN = 1.0

def rad(d): return d * math.pi / 180
def deg(r): return r * 180 / math.pi

def dist(lat1, lon1, lat2, lon2):
    p1, p2 = rad(lat1), rad(lat2)
    a = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(rad(lon2 - lon1) / 2) ** 2
    return 2 * R_EARTH * math.asin(math.sqrt(min(max(a, 0.0), 1.0)))

def dest(lat, lon, brg, d):
    p1, t, dl = rad(lat), rad(brg), d / R_EARTH
    p2 = math.asin(math.sin(p1) * math.cos(dl) + math.cos(p1) * math.sin(dl) * math.cos(t))
    l2 = rad(lon) + math.atan2(math.sin(t) * math.sin(dl) * math.cos(p1), math.cos(dl) - math.sin(p1) * math.sin(p2))
    return deg(p2), deg(l2)

def circle(trim, lat, lon, r):
    o = trim["offset_m"]
    clat, clon = dest(lat, lon, trim["bearing_deg"], o)
    return (clat, clon, r + o)

def trim_track(segments, trim, zones, name):
    # segments: list of list of (lon, lat, ele|None, time|None), already rounded
    pts = [p for s in segments for p in s]
    first, last = pts[0], pts[-1]
    circles = [circle(trim, first[1], first[0], trim["radius_m"]), circle(trim, last[1], last[0], trim["radius_m"])]
    circles += [circle(trim, z["lat"], z["lon"], z["radius_m"]) for z in zones]
    for p in pts:
        for c in circles:
            d = dist(c[0], c[1], p[1], p[0])
            if abs(d - c[2]) < MARGIN:
                raise SystemExit(f"{name}: a point is {d - c[2]:+.3f} m from a boundary")
    out = []
    for s in segments:
        cur = []
        for p in s:
            if any(dist(c[0], c[1], p[1], p[0]) < c[2] for c in circles):
                if len(cur) >= 2: out.append(cur)
                cur = []
            else:
                cur.append(p)
        if len(cur) >= 2: out.append(cur)
    return out

def rnd(segments):
    pts = [p for s in segments for p in s]
    has_ele = all(p[2] is not None for p in pts)
    has_time = all(p[3] is not None for p in pts)
    return [[(round(p[0], 6), round(p[1], 6), round(p[2], 1) if has_ele else None, p[3] if has_time else None) for p in s] for s in segments]

def feature(segments, relative):
    has_ele = segments and segments[0][0][2] is not None
    has_time = segments and segments[0][0][3] is not None
    coords = [[[p[0], p[1]] + ([p[2]] if has_ele else []) for p in s] for s in segments]
    props = {}
    if has_time:
        props["times"] = [[(p[3] - s[0][3]) if relative else p[3] for p in s] for s in segments]
    return {"type": "Feature", "geometry": {"type": "MultiLineString", "coordinates": coords}, "properties": props}

def off_the_half(name, segments):
    # Languages disagree about rounding a value that sits exactly on a half
    # (Python rounds half to even, Ruby away from zero), so no input may.
    from decimal import Decimal
    for s in segments:
        for p in s:
            for v, places in ((p[0], 6), (p[1], 6), (p[2], 1)):
                if v is None: continue
                d = Decimal(repr(v)).scaleb(places)
                if abs(abs(d - d.to_integral_value("ROUND_FLOOR")) - Decimal("0.5")) < Decimal("1e-6"):
                    raise SystemExit(f"{name}: an input value sits on a rounding half")

def write(name, description, trim, zones, segments):
    off_the_half(name, segments)
    expected_segments = trim_track(rnd(segments), trim, zones, name)
    case = {
        "description": description,
        "trim": trim,
        "zones": zones,
        "input": feature(segments, relative=False),
        "expected": feature(expected_segments, relative=True) if expected_segments else None,
    }
    with open(os.path.join(OUT, name + ".json"), "w") as f:
        json.dump(case, f, indent=2)
        f.write("\n")
    kept = sum(len(s) for s in expected_segments)
    print(f"{name}: {sum(len(s) for s in segments)} in, {len(expected_segments)} segments, {kept} kept")

T0 = 1_790_000_000
STEP = 0.00047  # degrees: 52.26 m along the equator or a meridian
STEP_M = R_EARTH * rad(STEP)

def east(lon0, n, lat=0.0, t0=T0, dt=10, ele=None):
    return [(round(lon0 + i * STEP, 10), lat, (ele(i) if ele else None), t0 + i * dt) for i in range(n)]

RIDE = "A ride due east along the equator, 0.00047° (52.26 m) per point, 101 points (5226 m)."

# 1. Ends trimmed, offset east.
write("ends_offset_east",
      RIDE + " R = 500 m, offset 250 m due east, so ρ = 750 m. The start circle is centred 250 m east "
      "of the start and drops everything up to 1000 m east of it (points 0–19). The end circle is centred 250 m "
      "beyond the end, so it reaches only 500 m back along the ride (points 91–100). 71 points survive.",
      {"radius_m": 500, "bearing_deg": 90.0, "offset_m": 250.0}, [],
      [east(0.0, 101, ele=lambda i: 10.0 + i * 0.3)])

# 2. Same ride, offset west, the smallest offset, a smaller radius.
write("ends_offset_west",
      RIDE + " R = 400 m, offset 125 m due west, so ρ = 525 m. The start circle reaches 400 m east of the start "
      "(points 0–7); the end circle, centred 125 m back along the ride, reaches 650 m back from the end "
      "(points 88–100). 80 points survive.",
      {"radius_m": 400, "bearing_deg": 270.0, "offset_m": 125.0}, [],
      [east(0.0, 101, ele=lambda i: 10.0 + i * 0.3)])

# 3. North offset, no elevation, no times.
write("offset_north_no_elevation_no_times",
      RIDE + " No elevation and no times, so the output has neither. R = 500 m, offset 250 m due "
      "north, so each circle (ρ = 750 m) is centred 250 m off the line and cuts it √(750² − 250²) ≈ 707 m either "
      "side of each end (points 0–13 and 87–100). 73 points survive.",
      {"radius_m": 500, "bearing_deg": 0.0, "offset_m": 250.0}, [],
      [[(p[0], p[1], None, None) for p in east(0.0, 101)]])

# 4. Out and back past the start, then out the other side.
lons = [i * STEP for i in range(0, 61)] + [(60 - i) * STEP for i in range(1, 121)]
write("passes_the_start_mid_ride",
      "Out 3.1 km east along the equator, back west past the start, and 3.1 km beyond it, 52.26 m per point. "
      "R = 500 m, offset 150 m on bearing 45°. The start circle cuts the beginning of the ride, and cuts "
      "it again where it passes the start on the way back; the end circle cuts the end. Two pieces survive: the "
      "outbound and return legs as one, and the stretch beyond the start as the other, with a gap where the ride "
      "passed the door.",
      {"radius_m": 500, "bearing_deg": 45.0, "offset_m": 150.0}, [],
      [[(round(lon, 10), 0.0, 20.0, T0 + 12 * i) for i, lon in enumerate(lons)]])

# 5. A privacy zone mid-ride splits the segment.
write("zone_mid_ride",
      "A ride due east along the equator, 121 points 52.26 m apart (6271 m), with a privacy zone of radius 300 m "
      "centred 66.7 m north of the line at 0.03° E. The offset is 200 m due south whatever the radius, so the zone's "
      "circle (ρ = 500 m) is centred 133.3 m south of the line and splits the ride in two. The ends are trimmed "
      "with R = 500 m (ρ = 700 m, centred 200 m south of each end, cutting about 671 m along the line).",
      {"radius_m": 500, "bearing_deg": 180.0, "offset_m": 200.0},
      [{"lat": 0.0006, "lon": 0.03, "radius_m": 300}],
      [east(0.0, 121, ele=lambda i: 50.0)])

# 6. Input already in two segments; only the ride's first and last points are
# trimmed, not the inner ends. Latitude carries more precision than storage.
write("two_segments_and_rounding",
      "Two input segments of 41 points, 52.26 m apart, with a GPS gap between them, at a latitude given to 11 "
      "places (stored as 0.000123). Only the ride's first and last points are trimmed (R = 300 m, offset "
      "150 m due east, ρ = 450 m): the first segment's end and the second's start survive, and each "
      "segment's times restart at 0.",
      {"radius_m": 300, "bearing_deg": 90.0, "offset_m": 150.0}, [],
      [east(0.0, 41, lat=0.00012345678), east(0.025, 41, lat=0.00012345678, t0=T0 + 2000)])

# 7. Entirely inside: nothing survives.
write("entirely_inside",
      "A 209 m ride, five points, wholly inside the start circle (R = 500 m). No track survives, so expected is null.",
      {"radius_m": 500, "bearing_deg": 123.0, "offset_m": 125.0}, [],
      [east(0.0, 5)])

# 8. A single point left between a zone and the end circle is dropped.
write("one_point_leftover_is_dropped",
      RIDE + " R = 500 m, offset 250 m due east. A zone of radius 200 m at 0.035793° E (3980 m along): its circle, "
      "also offset 250 m east, with ρ = 450 m, drops points between 3780 m and 4680 m (73–89). The end circle drops points from 4726 m (91–100). "
      "Point 90 is alone between them, and a segment needs two points, so it goes too.",
      {"radius_m": 500, "bearing_deg": 90.0, "offset_m": 250.0},
      [{"lat": 0.0, "lon": 0.035793, "radius_m": 200}],
      [east(0.0, 101, ele=lambda i: 5.0)])

# 9. Away from the equator, along a meridian: distance is R × Δφ exactly.
write("mid_latitude_meridian",
      "A ride due north along the 120° W meridian from 40° S, in open ocean, 81 points 52.26 m apart, with "
      "elevation jitter that never reaches 3 m. R = 600 m, offset 210 m on bearing 135°.",
      {"radius_m": 600, "bearing_deg": 135.0, "offset_m": 210.0}, [],
      [[(-120.0, round(-40.0 + i * STEP, 10), 100.0 + (i % 3) * 0.7, T0 + 15 * i) for i in range(81)]])
