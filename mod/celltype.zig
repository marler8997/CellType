// assumption: width is always <= height. this assumption
//             helps simplify things
const std = @import("std");

const curve = @import("curve.zig");
const design = @import("design.zig");
const glyphs = @import("glyphs.zig");

const PixelBoundary = @import("PixelBoundary.zig");

// Notes:
//    in general, all function/structs order values in the X direction before the Y direction.
//
// Acronyms:
//    w = width, h = height
//    c = center
//    l = left, r = right
//    t = top, b = bottom

pub const default_weight: f32 = 0.2;
pub fn calcStrokeWidth(comptime T: type, width: T, height: T, weight: f32) T {
    const width_f32: f32 = @floatFromInt(@min(width, height));
    return @max(1, @as(T, @intFromFloat(@round(width_f32 * weight))));
}

pub fn clear(
    comptime Dim: type,
    width: Dim,
    height: Dim,
    out_grayscale: [*]u8,
    out_stride: usize,
) void {
    for (0..height) |row| {
        const row_offset = row * @as(usize, out_stride);
        @memset(out_grayscale[row_offset..][0..width], 0);
    }
}

pub const Config = struct {
    serif: bool = true,
};

pub fn render(
    config: *const Config,
    comptime Dim: type,
    width: Dim,
    height: Dim,
    stroke_width: Dim,
    grayscale: [*]u8,
    stride: usize,
    grapheme_utf8: []const u8,
    opt: struct {
        output_precleared: bool,
        // TODO: add option for vertical direction
    },
) error{Utf8Decode}!usize {
    std.debug.assert(grapheme_utf8.len > 0);
    const utf8_len, const ops = try getOps(grapheme_utf8);

    // NOTE: the ClipBoundaries are purely an optimization for the
    //       CPU renderer, they should not affect the output and should
    //       not be used in a GPU-based renderer.
    const boundaries = getClipBoundaries(width, height, ops);
    if (!opt.output_precleared) {
        for (boundaries.row_start..boundaries.row_limit) |row| {
            const row_grayscale = grayscale[row * stride ..];
            if (row < boundaries.row_start or row >= boundaries.row_limit) {
                @memset(row_grayscale[0..width], 0);
            } else {
                @memset(row_grayscale[0..boundaries.col_start], 0);
                @memset(row_grayscale[boundaries.col_limit..width], 0);
            }
        }
    }

    for (boundaries.row_start..boundaries.row_limit) |row| {
        const row_offset = row * stride;
        for (boundaries.col_start..boundaries.col_limit) |col| {
            grayscale[row_offset + col] = pixelShaderOps(
                config,
                @intCast(width),
                @intCast(height),
                @intCast(stroke_width),
                @intCast(col),
                @intCast(row),
                ops,
            );
        }
    }
    return utf8_len;
}

fn getOps(grapheme_utf8: []const u8) error{Utf8Decode}!struct { usize, []const design.Op } {
    std.debug.assert(grapheme_utf8.len > 0);
    const utf8_len = std.unicode.utf8CodepointSequenceLength(grapheme_utf8[0]) catch
        return error.Utf8Decode;
    const codepoint = std.unicode.utf8Decode(grapheme_utf8[0..utf8_len]) catch |err| switch (err) {
        error.Utf8ExpectedContinuation,
        error.Utf8OverlongEncoding,
        error.Utf8EncodesSurrogateHalf,
        error.Utf8CodepointTooLarge,
        => return error.Utf8Decode,
    };
    if (std.math.cast(u8, codepoint)) |codepoint_u8| switch (codepoint_u8) {
        inline else => |c| if (@hasDecl(glyphs, &[_]u8{c})) return .{ utf8_len, &@field(glyphs, &[_]u8{c}) },
    };
    return .{ utf8_len, &todo };
}

const todo = [_]design.Op{.{ .op = .todo }};

const ClipBoundaries = struct {
    row_start: usize,
    row_limit: usize,
    col_start: usize,
    col_limit: usize,
};
fn getClipBoundaries(w: i32, h: i32, ops: []const design.Op) ClipBoundaries {
    var boundaries: ClipBoundaries = .{
        .row_start = 0,
        .row_limit = @intCast(h),
        .col_start = 0,
        .col_limit = @intCast(w),
    };
    // TODO: loop over all the operations and derive any global clip boundaries from them
    _ = &boundaries;
    _ = ops;
    return boundaries;
}

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// TODO: have a version of this that instead of ops, takes bytes: []const u8 and
//       decodes the bytes into ops as it goes and runs this function
fn pixelShaderOps(config: *const Config, w: i32, h: i32, stroke_width: i32, col: i32, row: i32, ops: []const design.Op) u8 {
    var max: u8 = 0;
    var clip_count: u8 = 0;
    for (ops) |*op| {
        if (clip_count > 0) {
            clip_count -= 1;
            continue;
        }
        max = @max(max, switch (pixelShaderOp(config, w, h, stroke_width, col, row, op)) {
            .max_candidate => |candidate| candidate,
            .clip => |count| {
                if (count == 0) return max;
                clip_count = count;
                continue;
            },
        });
        if (max == 255) break;
    }
    return max;
}
fn pixelShaderOp(config: *const Config, w: i32, h: i32, stroke_width: i32, col: i32, row: i32, op: *const design.Op) ShaderResult {
    switch (op.condition) {
        .yes => {},
        .serif => if (!config.serif) return .{ .max_candidate = 0 },
    }
    return switch (op.op) {
        inline else => |*args, tag| @field(shaders, @tagName(tag))(
            w,
            h,
            stroke_width,
            col,
            row,
            args,
        ),
    };
}

const Extent = struct {
    low: i32,
    high: i32,
    pub fn contains(self: Extent, value: i32) bool {
        return value >= self.low and value < self.high;
    }
    pub fn center(self: Extent) f32 {
        const low_f32: f32 = @floatFromInt(self.low);
        return low_f32 + (@as(f32, @floatFromInt(self.high)) - low_f32) / 2.0;
    }
    pub fn initStrokeX(w: i32, stroke_width: i32, x: design.BoundaryX) Extent {
        const pixel_boundary = PixelBoundary.fromDesignX(w, stroke_width, x);
        const high = pixel_boundary.adjust(stroke_width, 1).getRounded();
        return .{ .low = high - stroke_width, .high = high };
    }
    pub fn initStrokeY(h: i32, stroke_width: i32, y: design.BoundaryY) Extent {
        const pixel_boundary = PixelBoundary.fromDesignY(h, stroke_width, y);
        const high = pixel_boundary.adjust(stroke_width, 1).getRounded();
        return .{ .low = high - stroke_width, .high = high };
    }
};

const ShaderResult = union(enum) {
    // a new maximum value candidate for the pixel
    max_candidate: u8,
    clip: u8,
};

const shaders = struct {
    fn clip(w: i32, h: i32, stroke_width: i32, col: i32, row: i32, args: *const design.Clip) ShaderResult {
        var have_clip_boundary = false;
        if (args.left) |left| {
            have_clip_boundary = true;
            const boundary = PixelBoundary.fromDesignX(w, stroke_width, left);
            if (col < boundary.getRounded()) return .{ .clip = args.count };
        }
        if (args.right) |right| {
            have_clip_boundary = true;
            const boundary = PixelBoundary.fromDesignX(w, stroke_width, right);
            if (col >= boundary.getRounded()) return .{ .clip = args.count };
        }
        if (args.top) |top| {
            have_clip_boundary = true;
            const boundary = PixelBoundary.fromDesignY(h, stroke_width, top);
            if (row < boundary.getRounded()) return .{ .clip = args.count };
        }
        if (args.bottom) |bottom| {
            have_clip_boundary = true;
            const boundary = PixelBoundary.fromDesignY(h, stroke_width, bottom);
            if (row >= boundary.getRounded()) return .{ .clip = args.count };
        }
        if (!have_clip_boundary) @panic("got clip command with no boundaries");
        return .{ .max_candidate = 0 };
    }

    fn stroke_vert(w: i32, h: i32, stroke_width: i32, col: i32, row: i32, args: *const design.StrokeVert) ShaderResult {
        _ = h;
        _ = row;
        const extent_x = Extent.initStrokeX(w, stroke_width, args.x);
        return .{ .max_candidate = if (col < extent_x.low or col >= extent_x.high) 0 else 255 };
    }
    fn stroke_horz(w: i32, h: i32, stroke_width: i32, col: i32, row: i32, args: *const design.StrokeHorz) ShaderResult {
        _ = w;
        _ = col;
        const extent_y = Extent.initStrokeY(h, stroke_width, args.y);
        return .{ .max_candidate = if (row < extent_y.low or row >= extent_y.high) 0 else 255 };
    }
    fn stroke_diag(w: i32, h: i32, stroke_width: i32, col: i32, row: i32, args: *const design.StrokeDiag) ShaderResult {
        const pixel: Coord(f32) = .{
            .x = @floatFromInt(col),
            .y = @floatFromInt(row),
        };
        const a: Coord(f32) = .{
            .x = @floatFromInt(PixelBoundary.fromDesignX(w, stroke_width, args.a.x).getRounded()),
            .y = @floatFromInt(PixelBoundary.fromDesignY(h, stroke_width, args.a.y).getRounded()),
        };
        const b: Coord(f32) = .{
            .x = @floatFromInt(PixelBoundary.fromDesignX(w, stroke_width, args.b.x).getRounded()),
            .y = @floatFromInt(PixelBoundary.fromDesignY(h, stroke_width, args.b.y).getRounded()),
        };
        const distance = pointToLineDistance(pixel, a, b);
        const half_stroke_width: f32 = @as(f32, @floatFromInt(stroke_width)) / 2.0;
        return antialias(half_stroke_width, distance);
    }
    fn stroke_dot(w: i32, h: i32, stroke_width: i32, col: i32, row: i32, s: *const design.BoundaryPoint) ShaderResult {
        const extent_x = Extent.initStrokeX(w, stroke_width, s.x);
        const extent_y = Extent.initStrokeY(h, stroke_width, s.y);
        return if (stroke_width <= 2) shaderRectCoords(
            col,
            row,
            extent_x.low,
            extent_y.low,
            extent_x.high,
            extent_y.high,
        ) else shaderCircleCoords(
            col,
            row,
            extent_x.center(),
            extent_y.center(),
            stroke_width,
        );
    }
    fn stroke_curve(w: i32, h: i32, stroke_width: i32, col: i32, row: i32, s: *const design.StrokeCurve) ShaderResult {
        return shaderCurveCoords(
            col,
            row,
            .{
                .x = @floatFromInt(PixelBoundary.fromDesignX(w, stroke_width, s.start.x).getRounded()),
                .y = @floatFromInt(PixelBoundary.fromDesignY(h, stroke_width, s.start.y).getRounded()),
            },
            .{
                .x = @floatFromInt(PixelBoundary.fromDesignX(w, stroke_width, s.control.x).getRounded()),
                .y = @floatFromInt(PixelBoundary.fromDesignY(h, stroke_width, s.control.y).getRounded()),
            },
            .{
                .x = @floatFromInt(PixelBoundary.fromDesignX(w, stroke_width, s.end.x).getRounded()),
                .y = @floatFromInt(PixelBoundary.fromDesignY(h, stroke_width, s.end.y).getRounded()),
            },
            @as(f32, @floatFromInt(stroke_width)) / 2.0,
        );
    }
    fn todo(w: i32, h: i32, stroke_width: i32, col: i32, row: i32, args: *const void) ShaderResult {
        _ = w;
        _ = h;
        _ = stroke_width;
        _ = col;
        _ = row;
        _ = args;
        // TODO: draw something more recognizable like a ? or something
        return .{ .max_candidate = 200 };
    }
};

fn shaderRectCoords(col: i32, row: i32, l: i32, t: i32, r: i32, b: i32) ShaderResult {
    return .{ .max_candidate = if (col < l or col >= r or row < t or row >= b) 0 else 255 };
}
fn shaderCircleCoords(col: i32, row: i32, x: f32, y: f32, diameter: i32) ShaderResult {
    const radius: f32 = @as(f32, @floatFromInt(diameter)) / 2.0;
    const px: f32 = @as(f32, @floatFromInt(col)) + 0.5; // Center of pixel
    const py: f32 = @as(f32, @floatFromInt(row)) + 0.5;
    const dx = px - x;
    const dy = py - y;
    const distance = @sqrt(dx * dx + dy * dy);
    return antialias(radius, distance);
}
fn shaderCurveCoords(
    col: i32,
    row: i32,
    start: Coord(f32),
    control: Coord(f32),
    end: Coord(f32),
    half_stroke_width: f32,
) ShaderResult {
    const pixel = Coord(f32){
        .x = @as(f32, @floatFromInt(col)) + 0.5,
        .y = @as(f32, @floatFromInt(row)) + 0.5,
    };

    // Find t value that gives point on curve closest to pixel
    // This requires solving a cubic equation
    const t = @import("curve.zig").findClosestPointOnQuadraticBezier(pixel, start, control, end);

    // Get point on curve at t
    const curve_point = curve.evaluateQuadraticBezier(t, start, control, end);

    // Calculate distance from pixel to curve point
    const distance = calcDist(pixel.x, pixel.y, curve_point.x, curve_point.y);

    return antialias(half_stroke_width, distance);
}

fn antialias(boundary: f32, position: f32) ShaderResult {
    if (position <= boundary - 0.7071) return .{ .max_candidate = 255 }; // sqrt(2)/2 ≈ 0.7071 for pixel coverage
    if (position >= boundary + 0.7071) return .{ .max_candidate = 0 };

    // Pixel is on the edge - calculate coverage
    const coverage = (boundary + 0.7071 - position) / (2 * 0.7071);
    return .{ .max_candidate = @intFromFloat(coverage * 255.0) };
}

pub fn Coord(comptime T: type) type {
    return struct {
        x: T,
        y: T,
    };
}

pub fn pointToLineDistance(p: Coord(f32), p1: Coord(f32), p2: Coord(f32)) f32 {
    const numerator = @abs((p2.x - p1.x) * (p1.y - p.y) -
        (p1.x - p.x) * (p2.y - p1.y));
    const denominator = @sqrt(std.math.pow(f32, p2.x - p1.x, 2) +
        std.math.pow(f32, p2.y - p1.y, 2));
    // Handle the case where the points defining the line are the same
    if (denominator == 0) {
        // Return the distance between the point and p1
        return @sqrt(std.math.pow(f32, p.x - p1.x, 2) +
            std.math.pow(f32, p.y - p1.y, 2));
    }
    return numerator / denominator;
}

fn square(comptime T: type, x: T) T {
    return x * x;
}
pub fn calcDist(x0: f32, y0: f32, x1: f32, y1: f32) f32 {
    return @sqrt(square(f32, x1 - x0) + square(f32, y1 - y0));
}
