const std = @import("std");

const mod_root = @import("mod.zig");
const Coord = mod_root.Coord;

pub fn findClosestPointOnQuadraticBezier(
    point: Coord(f32),
    p0: Coord(f32),
    p1: Coord(f32),
    p2: Coord(f32),
) f32 {
    // The quadratic Bezier curve is defined as:
    // B(t) = (1-t)Â²p0 + 2(1-t)tp1 + tÂ²p2
    //
    // To find closest point, we need to minimize:
    // D(t) = |B(t) - point|Â²
    //
    // This leads to a cubic equation in the form:
    // atÂ³ + btÂ² + ct + d = 0

    const ax = p0.x - 2 * p1.x + p2.x;
    const ay = p0.y - 2 * p1.y + p2.y;
    const bx = 2 * (p1.x - p0.x);
    const by = 2 * (p1.y - p0.y);

    // Coefficients of the cubic equation
    const a = 4 * (ax * ax + ay * ay);
    const b = 6 * (ax * bx + ay * by);
    const c = 2 * (bx * bx + by * by + 2 * ax * (p0.x - point.x) + 2 * ay * (p0.y - point.y));
    const d = 2 * (bx * (p0.x - point.x) + by * (p0.y - point.y));

    // Find roots of the cubic equation
    const roots = solveCubic(a, b, c, d);

    // Find the t value that gives minimum distance
    var min_dist: f32 = std.math.inf(f32);
    var best_t: f32 = 0;

    // Check all roots between 0 and 1
    for (roots) |t| {
        if (t >= 0 and t <= 1) {
            const pt = evaluateQuadraticBezier(t, p0, p1, p2);
            const dist = mod_root.calcDist(point.x, point.y, pt.x, pt.y);
            if (dist < min_dist) {
                min_dist = dist;
                best_t = t;
            }
        }
    }

    // Also check endpoints
    const dist0 = mod_root.calcDist(point.x, point.y, p0.x, p0.y);
    if (dist0 < min_dist) {
        min_dist = dist0;
        best_t = 0;
    }

    const dist1 = mod_root.calcDist(point.x, point.y, p2.x, p2.y);
    if (dist1 < min_dist) {
        min_dist = dist1;
        best_t = 1;
    }

    return best_t;
}

pub fn evaluateQuadraticBezier(t: f32, p0: Coord(f32), p1: Coord(f32), p2: Coord(f32)) Coord(f32) {
    const t1 = 1 - t;
    return .{
        .x = t1 * t1 * p0.x + 2 * t1 * t * p1.x + t * t * p2.x,
        .y = t1 * t1 * p0.y + 2 * t1 * t * p1.y + t * t * p2.y,
    };
}

fn solveCubic(a: f32, b: f32, c: f32, d: f32) [3]f32 {
    // Handle degenerate cases
    if (@abs(a) < 1e-6) {
        // Actually quadratic
        return solveQuadratic(b, c, d);
    }

    // Convert to depressed cubic tÂ³ + pt + q = 0
    const p = (3.0 * a * c - b * b) / (3.0 * a * a);
    const q = (2.0 * b * b * b - 9.0 * a * b * c + 27.0 * a * a * d) / (27.0 * a * a * a);

    // Use Cardano's formula
    const D = q * q / 4.0 + p * p * p / 27.0;

    if (D > 0) {
        // One real root
        const u = cbrt(-q / 2.0 + @sqrt(D));
        const v = cbrt(-q / 2.0 - @sqrt(D));
        const root = u + v - b / (3.0 * a);
        return .{ root, root, root };
    } else if (D < 0) {
        // Three real roots
        const phi = std.math.acos(-q / (2.0 * @sqrt(-p * p * p / 27.0)));
        const t = 2.0 * @sqrt(-p / 3.0);
        return .{
            t * @cos(phi / 3.0) - b / (3.0 * a),
            t * @cos((phi + 2.0 * std.math.pi) / 3.0) - b / (3.0 * a),
            t * @cos((phi + 4.0 * std.math.pi) / 3.0) - b / (3.0 * a),
        };
    } else {
        // Three real roots, at least two equal
        const u = if (q < 0) cbrt(-q / 2.0) else -cbrt(q / 2.0);
        return .{
            2.0 * u - b / (3.0 * a),
            -u - b / (3.0 * a),
            -u - b / (3.0 * a),
        };
    }
}

fn solveQuadratic(a: f32, b: f32, c: f32) [3]f32 {
    const disc = b * b - 4.0 * a * c;
    if (disc < 0) {
        return .{ 0, 0, 0 };
    } else if (disc == 0) {
        const x = -b / (2.0 * a);
        return .{ x, x, x };
    } else {
        const q = if (b > 0)
            -b - @sqrt(disc)
        else
            -b + @sqrt(disc);
        const x1 = q / (2.0 * a);
        const x2 = c / (a * x1);
        return .{ x1, x2, x2 };
    }
}

fn cbrt(x: f32) f32 {
    return if (x < 0) -std.math.pow(f32, -x, 1.0 / 3.0) else std.math.pow(f32, x, 1.0 / 3.0);
}
