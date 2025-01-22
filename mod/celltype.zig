// assumption: width is always <= height. this assumption
//             helps simplify things
const std = @import("std");

const curve = @import("curve.zig");
const glyphs = @import("glyphs.zig");

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
) void {
    const ops = getOps(grapheme_utf8);

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
}

fn getOps(grapheme_utf8: []const u8) []const glyphs.Op {
    if (grapheme_utf8.len == 1) return switch (grapheme_utf8[0]) {
        inline else => |c| if (@hasDecl(glyphs.c, &[_]u8{c})) &@field(glyphs.c, &[_]u8{c}) else &glyphs.todo,
    };
    return &glyphs.todo;
}

const ClipBoundaries = struct {
    row_start: usize,
    row_limit: usize,
    col_start: usize,
    col_limit: usize,
};
fn getClipBoundaries(w: i32, h: i32, ops: []const glyphs.Op) ClipBoundaries {
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
fn pixelShaderOps(config: *const Config, w: i32, h: i32, stroke_width: i32, col: i32, row: i32, ops: []const glyphs.Op) u8 {
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
fn pixelShaderOp(config: *const Config, w: i32, h: i32, stroke_width: i32, col: i32, row: i32, op: *const glyphs.Op) ShaderResult {
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
    pub fn initStrokeX(w: i32, stroke_width: i32, x: glyphs.DesignBoundaryX) Extent {
        const pixel_boundary = pixelBoundaryFromDesignX(w, stroke_width, x);
        const high = pixel_boundary.adjust(stroke_width, 1).rounded;
        return .{ .low = high - stroke_width, .high = high };
    }
    pub fn initStrokeY(h: i32, stroke_width: i32, y: glyphs.DesignBoundaryY) Extent {
        const pixel_boundary = pixelBoundaryFromDesignY(h, stroke_width, y);
        const high = pixel_boundary.adjust(stroke_width, 1).rounded;
        return .{ .low = high - stroke_width, .high = high };
    }
};

const ShaderResult = union(enum) {
    // a new maximum value candidate for the pixel
    max_candidate: u8,
    clip: u8,
};

const shaders = struct {
    fn clip(w: i32, h: i32, stroke_width: i32, col: i32, row: i32, args: *const glyphs.Clip) ShaderResult {
        var have_clip_boundary = false;
        if (args.left) |left| {
            have_clip_boundary = true;
            const boundary = pixelBoundaryFromDesignX(w, stroke_width, left);
            if (col < boundary.rounded) return .{ .clip = args.count };
        }
        if (args.right) |right| {
            have_clip_boundary = true;
            const boundary = pixelBoundaryFromDesignX(w, stroke_width, right);
            if (col >= boundary.rounded) return .{ .clip = args.count };
        }
        if (args.top) |top| {
            have_clip_boundary = true;
            const boundary = pixelBoundaryFromDesignY(h, stroke_width, top);
            if (row < boundary.rounded) return .{ .clip = args.count };
        }
        if (args.bottom) |bottom| {
            have_clip_boundary = true;
            const boundary = pixelBoundaryFromDesignY(h, stroke_width, bottom);
            if (row >= boundary.rounded) return .{ .clip = args.count };
        }
        if (!have_clip_boundary) @panic("got clip command with no boundaries");
        return .{ .max_candidate = 0 };
    }

    fn stroke_vert(w: i32, h: i32, stroke_width: i32, col: i32, row: i32, args: *const glyphs.StrokeVert) ShaderResult {
        _ = h;
        _ = row;
        const extent_x = Extent.initStrokeX(w, stroke_width, args.x);
        return .{ .max_candidate = if (col < extent_x.low or col >= extent_x.high) 0 else 255 };
    }
    fn stroke_horz(w: i32, h: i32, stroke_width: i32, col: i32, row: i32, args: *const glyphs.StrokeHorz) ShaderResult {
        _ = w;
        _ = col;
        const extent_y = Extent.initStrokeY(h, stroke_width, args.y);
        return .{ .max_candidate = if (row < extent_y.low or row >= extent_y.high) 0 else 255 };
    }
    fn stroke_diag(w: i32, h: i32, stroke_width: i32, col: i32, row: i32, args: *const glyphs.StrokeDiag) ShaderResult {
        const pixel: Coord(f32) = .{
            .x = @floatFromInt(col),
            .y = @floatFromInt(row),
        };
        const a: Coord(f32) = .{
            .x = @floatFromInt(pixelBoundaryFromDesignX(w, stroke_width, args.a.x).rounded),
            .y = @floatFromInt(pixelBoundaryFromDesignY(h, stroke_width, args.a.y).rounded),
        };
        const b: Coord(f32) = .{
            .x = @floatFromInt(pixelBoundaryFromDesignX(w, stroke_width, args.b.x).rounded),
            .y = @floatFromInt(pixelBoundaryFromDesignY(h, stroke_width, args.b.y).rounded),
        };
        const distance = pointToLineDistance(pixel, a, b);
        const half_stroke_width: f32 = @as(f32, @floatFromInt(stroke_width)) / 2.0;
        return antialias(half_stroke_width, distance);
    }
    fn stroke_dot(w: i32, h: i32, stroke_width: i32, col: i32, row: i32, s: *const glyphs.DesignBoundaryPoint) ShaderResult {
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
    fn stroke_curve(w: i32, h: i32, stroke_width: i32, col: i32, row: i32, s: *const glyphs.StrokeCurve) ShaderResult {
        return shaderCurveCoords(
            col,
            row,
            .{
                .x = @floatFromInt(pixelBoundaryFromDesignX(w, stroke_width, s.start.x).rounded),
                .y = @floatFromInt(pixelBoundaryFromDesignY(h, stroke_width, s.start.y).rounded),
            },
            .{
                .x = @floatFromInt(pixelBoundaryFromDesignX(w, stroke_width, s.control.x).rounded),
                .y = @floatFromInt(pixelBoundaryFromDesignY(h, stroke_width, s.control.y).rounded),
            },
            .{
                .x = @floatFromInt(pixelBoundaryFromDesignX(w, stroke_width, s.end.x).rounded),
                .y = @floatFromInt(pixelBoundaryFromDesignY(h, stroke_width, s.end.y).rounded),
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

const StrokeBias = enum {
    neg,
    pos,
    pub fn flip(self: StrokeBias) StrokeBias {
        return switch (self) {
            .neg => .pos,
            .pos,
            => .neg,
        };
    }
};

const PixelBoundary = struct {
    rounded: i32,
    stroke_bias: StrokeBias,
    pub fn initFloat(float: f32) PixelBoundary {
        const rounded: i32 = @intFromFloat(@round(float));
        const remainder = float - @as(f32, @floatFromInt(rounded));
        return .{
            .rounded = rounded,
            .stroke_bias = if (remainder >= 0) .pos else .neg,
        };
    }
    pub fn centerReflect(self: PixelBoundary, size: i32) PixelBoundary {
        return .{
            .rounded = size - self.rounded,
            .stroke_bias = self.stroke_bias.flip(),
        };
    }
    pub fn centerBetween(self: PixelBoundary, other: PixelBoundary) PixelBoundary {
        const self_slot = self.rounded * 2 + @as(i32, if (self.stroke_bias == .pos) 1 else 0);
        const other_slot = other.rounded * 2 + @as(i32, if (other.stroke_bias == .pos) 1 else 0);
        const diff = other_slot - self_slot;

        //const odd_add: i32 = if (diff >= 0) 1 else -1;
        const half: i32 = if ((diff & 1) == 0) @divExact(diff, 2) else @divExact(diff + 1, 2);
        const center_slot = self_slot + half;
        return .{
            .rounded = @divFloor(center_slot, 2),
            .stroke_bias = if (0 == (@mod(center_slot, 2))) .neg else .pos,
        };
    }
    pub fn adjust(self: PixelBoundary, stroke_width: i32, half_stroke_offset: i8) PixelBoundary {
        if ((half_stroke_offset & 1) == 0) return .{
            .rounded = self.rounded + stroke_width * @divExact(half_stroke_offset, 2),
            .stroke_bias = self.stroke_bias,
        };

        const base_mult: i32 = @divExact(if (half_stroke_offset > 0) (half_stroke_offset - 1) else (half_stroke_offset + 1), 2);
        const base_step: i32 = self.rounded + base_mult * stroke_width;

        const direction: StrokeBias = if (half_stroke_offset > 0) .pos else .neg;
        if (@as(u31, @intCast(stroke_width)) % 2 == 0) return .{
            .rounded = base_step + switch (direction) {
                .neg => -@divExact(stroke_width, 2),
                .pos => @divExact(stroke_width, 2),
            },
            .stroke_bias = self.stroke_bias,
        };

        const step: i32 = @divTrunc(stroke_width + @as(i32, if (direction == self.stroke_bias) 1 else 0), 2);
        return .{
            .rounded = base_step + switch (direction) {
                .neg => -step,
                .pos => step,
            },
            .stroke_bias = self.stroke_bias.flip(),
        };
    }
    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = fmt;
        _ = options;
        try writer.print("{}({c} bias)", .{
            self.rounded,
            @as(u8, switch (self.stroke_bias) {
                .neg => '-',
                .pos => '+',
            }),
        });
    }
};

fn testCenterBetween(
    expected: PixelBoundary,
    a: PixelBoundary,
    b: PixelBoundary,
) !void {
    try std.testing.expectEqual(expected, a.centerBetween(b));
    try std.testing.expectEqual(expected, b.centerBetween(a));
}

test "PixelBoundary.centerBetween" {
    for (&[_]i32{ -100, -10, -1, 0, 1, 10, 40 }) |boundary| {
        try testCenterBetween(
            PixelBoundary{ .rounded = boundary, .stroke_bias = .neg },
            PixelBoundary{ .rounded = boundary, .stroke_bias = .neg },
            PixelBoundary{ .rounded = boundary, .stroke_bias = .neg },
        );
        try testCenterBetween(
            PixelBoundary{ .rounded = boundary, .stroke_bias = .pos },
            PixelBoundary{ .rounded = boundary, .stroke_bias = .pos },
            PixelBoundary{ .rounded = boundary, .stroke_bias = .pos },
        );
        try testCenterBetween(
            PixelBoundary{ .rounded = boundary, .stroke_bias = .pos },
            PixelBoundary{ .rounded = boundary, .stroke_bias = .neg },
            PixelBoundary{ .rounded = boundary, .stroke_bias = .pos },
        );
        try testCenterBetween(
            PixelBoundary{ .rounded = boundary, .stroke_bias = .pos },
            PixelBoundary{ .rounded = boundary, .stroke_bias = .neg },
            PixelBoundary{ .rounded = boundary + 1, .stroke_bias = .neg },
        );
        try testCenterBetween(
            PixelBoundary{ .rounded = boundary + 1, .stroke_bias = .neg },
            PixelBoundary{ .rounded = boundary, .stroke_bias = .pos },
            PixelBoundary{ .rounded = boundary + 1, .stroke_bias = .neg },
        );
        try testCenterBetween(
            PixelBoundary{ .rounded = boundary + 1, .stroke_bias = .neg },
            PixelBoundary{ .rounded = boundary, .stroke_bias = .pos },
            PixelBoundary{ .rounded = boundary + 1, .stroke_bias = .pos },
        );
        try testCenterBetween(
            PixelBoundary{ .rounded = boundary, .stroke_bias = .neg },
            PixelBoundary{ .rounded = boundary, .stroke_bias = .pos },
            PixelBoundary{ .rounded = boundary - 1, .stroke_bias = .pos },
        );
        try testCenterBetween(
            PixelBoundary{ .rounded = boundary - 1, .stroke_bias = .pos },
            PixelBoundary{ .rounded = boundary, .stroke_bias = .neg },
            PixelBoundary{ .rounded = boundary - 1, .stroke_bias = .neg },
        );
        try testCenterBetween(
            PixelBoundary{ .rounded = boundary, .stroke_bias = .neg },
            PixelBoundary{ .rounded = boundary, .stroke_bias = .neg },
            PixelBoundary{ .rounded = boundary - 1, .stroke_bias = .pos },
        );
    }
}

test "adjusting boundaries" {
    try std.testing.expectEqual(
        @as(i32, 69),
        (PixelBoundary{
            .rounded = 100,
            .stroke_bias = .pos,
        }).adjust(21, -3).rounded,
    );
    try std.testing.expectEqual(
        @as(i32, 70),
        (PixelBoundary{
            .rounded = 100,
            .stroke_bias = .pos,
        }).adjust(20, -3).rounded,
    );

    for (0..127) |stroke_offset| {
        {
            const b = (PixelBoundary{
                .rounded = 0,
                .stroke_bias = .pos,
            }).adjust(1, @intCast(stroke_offset));
            const expect: i32 = @intCast(@divTrunc(stroke_offset + 1, 2));
            try std.testing.expectEqual(expect, b.rounded);
        }
        {
            const b = (PixelBoundary{
                .rounded = 0,
                .stroke_bias = .neg,
            }).adjust(1, -@as(i8, @intCast(stroke_offset)));
            const expect: i32 = -@as(i32, @intCast(@divTrunc(stroke_offset + 1, 2)));
            try std.testing.expectEqual(expect, b.rounded);
        }
    }
    for (0..63) |i| {
        {
            const b = (PixelBoundary{
                .rounded = 0,
                .stroke_bias = .pos,
            }).adjust(1, @as(i8, @intCast(i)) * 2);
            try std.testing.expectEqual(@as(i32, @intCast(i)), b.rounded);
        }
        {
            const b = (PixelBoundary{
                .rounded = 0,
                .stroke_bias = .neg,
            }).adjust(1, -@as(i8, @intCast(i)) * 2);
            try std.testing.expectEqual(-@as(i32, @intCast(i)), b.rounded);
        }
        {
            const b = (PixelBoundary{
                .rounded = 0,
                .stroke_bias = .pos,
            }).adjust(2, @as(i8, @intCast(i)) * 2);
            try std.testing.expectEqual(@as(i32, @intCast(i * 2)), b.rounded);
        }
        {
            const b = (PixelBoundary{
                .rounded = 0,
                .stroke_bias = .neg,
            }).adjust(2, -@as(i8, @intCast(i)) * 2);
            try std.testing.expectEqual(-@as(i32, @intCast(i * 2)), b.rounded);
        }
    }

    for (1..100) |size_usize| {
        const size: i32 = @intCast(size_usize);
        for (0..100) |stroke_width_usize| {
            const stroke_width: i32 = @intCast(stroke_width_usize);
            inline for (std.meta.fields(glyphs.DesignBoundaryBaseX)) |x_field| {
                const x: glyphs.DesignBoundaryBaseX = @enumFromInt(x_field.value);
                const boundary = pixelBoundaryFromDesignBaseX(size, stroke_width, x);
                for (0..10) |i_usize| {
                    const i: i8 = @intCast(i_usize);
                    const pos = boundary.adjust(stroke_width, i);
                    try std.testing.expectEqual(boundary, pos.adjust(stroke_width, -i));
                    try std.testing.expectEqual(boundary, boundary.adjust(stroke_width, -i).adjust(stroke_width, i));
                    try std.testing.expectEqual(pos, pos.adjust(stroke_width, i).adjust(stroke_width, -i));
                }
            }
            inline for (std.meta.fields(glyphs.DesignBoundaryBaseY)) |y_field| {
                const y: glyphs.DesignBoundaryBaseY = @enumFromInt(y_field.value);
                const boundary = pixelBoundaryFromDesignBaseY(size, stroke_width, y);
                for (0..10) |i_usize| {
                    const i: i8 = @intCast(i_usize);
                    const pos = boundary.adjust(stroke_width, i);
                    try std.testing.expectEqual(boundary, pos.adjust(stroke_width, -i));
                    try std.testing.expectEqual(boundary, boundary.adjust(stroke_width, -i).adjust(stroke_width, i));
                    try std.testing.expectEqual(pos, pos.adjust(stroke_width, i).adjust(stroke_width, -i));
                }
            }
        }
    }
}

fn pixelBoundaryFromDesignX(w: i32, stroke_width: i32, x: glyphs.DesignBoundaryX) PixelBoundary {
    const boundary = pixelBoundaryFromDesignBaseX(w, stroke_width, x.base);
    return boundary.adjust(stroke_width, x.half_stroke_adjust);
}
fn pixelBoundaryFromDesignY(h: i32, stroke_width: i32, y: glyphs.DesignBoundaryY) PixelBoundary {
    const boundary = pixelBoundaryFromDesignBaseY(h, stroke_width, y.base);
    return boundary.adjust(stroke_width, y.half_stroke_adjust);
}

fn pixelBoundaryFromDesignBaseX(w: i32, stroke_width: i32, x: glyphs.DesignBoundaryBaseX) PixelBoundary {
    // if x is large enough, we just always use the same floating point
    // multiplier for the position
    const large_enough_ratio: f32 = switch (x) {
        .uppercase_left => 0.210,
        .center => 0.5,
        .uppercase_right => return pixelBoundaryFromDesignBaseX(w, stroke_width, .uppercase_left).centerReflect(w),
    };
    return PixelBoundary.initFloat(large_enough_ratio * @as(f32, @floatFromInt(w)));
}

fn pixelBoundaryFromDesignBaseY(h: i32, stroke_width: i32, y: glyphs.DesignBoundaryBaseY) PixelBoundary {
    // if y is large enough, we just always use the same floating point
    // multiplier for the position
    const large_enough_ratio: f32 = switch (y) {
        .uppercase_top => 0.2,
        .uppercase_top_quarter => {
            const top = pixelBoundaryFromDesignBaseY(h, stroke_width, .uppercase_top);
            const baseline = pixelBoundaryFromDesignBaseY(h, stroke_width, .baseline_stroke);
            return top.centerBetween(baseline).centerBetween(top);
        },
        .lowercase_dot => return pixelBoundaryFromDesignBaseY(
            h,
            stroke_width,
            .lowercase_top,
        ).adjust(stroke_width, -1).centerBetween(
            PixelBoundary{ .rounded = 0, .stroke_bias = .pos },
        ),
        ._1_slanty_bottom => 0.266,
        .lowercase_top => 0.4,
        .uppercase_center => return pixelBoundaryFromDesignBaseY(
            h,
            stroke_width,
            .uppercase_top,
        ).centerBetween(
            pixelBoundaryFromDesignBaseY(h, stroke_width, .baseline_stroke),
        ),
        .baseline_stroke => 0.71,
    };
    return PixelBoundary.initFloat(large_enough_ratio * @as(f32, @floatFromInt(h)));
}
