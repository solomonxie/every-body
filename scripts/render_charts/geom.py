"""Shape helpers for the chart generator: smooth curves, tapered limbs, bands, cuts and SVG output."""
import math

from shapely.geometry import LineString, MultiPolygon, Point, Polygon
from shapely.geometry.polygon import orient
from shapely.ops import unary_union


def catmull(pts, closed=True, n=12):
    """Uniform Catmull-Rom samples through the points."""
    m = len(pts)
    out = []
    last = m if closed else m - 1
    for i in range(last):
        p0 = pts[(i - 1) % m] if closed or i > 0 else pts[0]
        p1, p2 = pts[i], pts[(i + 1) % m]
        p3 = pts[(i + 2) % m] if closed or i + 2 < m else pts[-1]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    if not closed:
        out.append(tuple(pts[-1]))
    return out


def smooth(pts):
    return Polygon(catmull(pts)).buffer(0)


def curve(pts):
    return LineString(catmull(pts, closed=False))


def band(pts, width, cap="round"):
    return curve(pts).buffer(width / 2, cap_style=cap, quad_segs=12)


def taper(circles):
    """Hull chain through (x, y, r) circles: fingers, toes, crura."""
    parts = []
    for a, b in zip(circles, circles[1:]):
        parts.append(unary_union([Point(a[0], a[1]).buffer(a[2], quad_segs=24),
                                  Point(b[0], b[1]).buffer(b[2], quad_segs=24)]).convex_hull)
    return unary_union(parts)


def circle(x, y, r):
    return Point(x, y).buffer(r, quad_segs=24)


def ellipse(x, y, rx, ry, rot=0):
    from shapely import affinity
    e = affinity.scale(Point(0, 0).buffer(1, quad_segs=24), rx, ry)
    return affinity.translate(affinity.rotate(e, rot, origin=(0, 0)), x, y)


def half(a, b, side=1, far=2000):
    """Half-plane left (side=1) or right (-1) of the directed line a→b."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy)
    ux, uy = dx / n, dy / n
    nx, ny = -uy * side, ux * side
    p1 = (a[0] - ux * far, a[1] - uy * far)
    p2 = (a[0] + ux * far, a[1] + uy * far)
    return Polygon([p1, p2, (p2[0] + nx * far, p2[1] + ny * far), (p1[0] + nx * far, p1[1] + ny * far)])


def side_of(pts, side=1, far=600):
    """Region below (side=1) or above (-1) a roughly horizontal polyline, extended at both ends."""
    if pts[-1][0] < pts[0][0]:
        pts = pts[::-1]
    c = catmull(pts, closed=False, n=8)
    (x0, y0), (x1, y1) = c[0], c[1]
    (xa, ya), (xb, yb) = c[-2], c[-1]

    def ext(p, q, k):
        dx, dy = q[0] - p[0], q[1] - p[1]
        n = math.hypot(dx, dy) or 1
        return (q[0] + dx / n * k, q[1] + dy / n * k)

    start, end = ext((x1, y1), (x0, y0), far), ext((xa, ya), (xb, yb), far)
    line = [start] + c + [end]
    dx, dy = end[0] - start[0], end[1] - start[1]
    n = math.hypot(dx, dy)
    nx, ny = -dy / n * side * far, dx / n * side * far
    return Polygon(line + [(end[0] + nx, end[1] + ny), (start[0] + nx, start[1] + ny)]).buffer(0)


def slices(region, axis_pts, cuts):
    """Cut a region across a curved axis at the given fractions (0..1) of its length; returns the pieces."""
    line = curve(axis_pts)
    L = line.length
    out = []
    edges = []
    for f in cuts:
        p = line.interpolate(f * L)
        q = line.interpolate(min(L, f * L + 0.5)) if f < 1 else line.interpolate(L)
        r = line.interpolate(max(0, f * L - 0.5))
        dx, dy = q.x - r.x, q.y - r.y
        n = math.hypot(dx, dy) or 1
        nx, ny = -dy / n, dx / n
        edges.append(((p.x - nx * 400, p.y - ny * 400), (p.x + nx * 400, p.y + ny * 400)))
    for (a1, a2), (b1, b2) in zip(edges, edges[1:]):
        quad = Polygon([a1, a2, b2, b1]).buffer(0)
        out.append(region.intersection(quad))
    return out


def polys(g):
    if g.is_empty:
        return []
    if isinstance(g, Polygon):
        return [g]
    if isinstance(g, MultiPolygon):
        return list(g.geoms)
    return [p for x in getattr(g, "geoms", []) for p in polys(x)]


def clean(g, min_area=16):
    ps = [p for p in polys(g) if p.area >= min_area]
    return MultiPolygon(ps) if len(ps) > 1 else ps[0] if ps else Polygon()


def num(v):
    s = f"{v:.1f}"
    return s[:-2] if s.endswith(".0") else s


def zone_d(g, gap=0.6, round_r=2.4, tol=0.25):
    """Zone geometry → compact SVG path: slightly inset so neighbours show a hairline gap, soft corners."""
    soft = g.buffer(-(gap + round_r), join_style="round").buffer(round_r, join_style="round")
    # thin zones would vanish under the soft corners
    g = soft if soft.area > g.area * 0.75 else g.buffer(-(gap + 1), join_style="round").buffer(1, join_style="round")
    out = []
    for p in polys(g):
        if p.area < 3:
            continue
        p = orient(p.simplify(tol), 1.0)
        for ring in [p.exterior] + list(p.interiors):
            c = list(ring.coords)[:-1]
            out.append("M" + " ".join(f"{num(x)} {num(y)}" for x, y in c) + "Z")
    return "".join(out)


def smooth_d(g, step=3.0):
    """Closed geometry → Catmull-Rom cubic Beziers through evenly spaced points."""
    out = []
    for p in polys(g):
        for ring in [p.exterior] + list(p.interiors):
            L = ring.length
            n = max(8, int(L / step))
            pts = [ring.interpolate(L * k / n).coords[0] for k in range(n)]
            out.append(bezier_d(pts, closed=True))
    return " ".join(out)


def bezier_d(pts, closed=False):
    m = len(pts)
    s = f"M{num(pts[0][0])} {num(pts[0][1])}"
    last = m if closed else m - 1
    for i in range(last):
        p0 = pts[(i - 1) % m] if closed or i > 0 else pts[0]
        p1, p2 = pts[i], pts[(i + 1) % m]
        p3 = pts[(i + 2) % m] if closed or i + 2 < m else pts[-1]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        s += f"C{num(c1[0])} {num(c1[1])} {num(c2[0])} {num(c2[1])} {num(p2[0])} {num(p2[1])}"
    return s + ("Z" if closed else "")


def line_d(pts):
    """Open smooth stroke (creases, contours)."""
    return bezier_d([tuple(p) for p in pts]) if len(pts) > 2 else f"M{num(pts[0][0])} {num(pts[0][1])}L{num(pts[1][0])} {num(pts[1][1])}"
