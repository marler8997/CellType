// assumption: width is always <= height. this assumption
//             helps simplify things
const std = @import("std");
const CodefontRenderer = @This();

const glyphs = @import("glyphs.zig");

// Notes:
//    in general, all function/structs order values in the X direction before the Y direction.
//
// Acronyms:
//    w = width, h = height
//    c = center
//    l = left, r = right
//    t = top, b = bottom
//
//    i.e.
//    ctb = center/top/bottom
//    lrt = left/right/top
//    lrb = left/right/bottom

pub fn clear(
    comptime Dim: type,
    width: Dim,
    height: Dim,
    out_grayscale: [*]u8,
    out_stride: usize,
) void {
    std.debug.assert(width <= height);
    for (0..height) |row| {
        const row_offset = row * @as(usize, out_stride);
        @memset(out_grayscale[row_offset..][0..width], 0);
    }
}

pub fn render(
    comptime Dim: type,
    width: Dim,
    height: Dim,
    grayscale: [*]u8,
    stride: usize,
    grapheme_utf8: []const u8,
    // TODO: add option for vertical direction
) void {
    std.debug.assert(width <= height);
    // Ideas
    //     - loop through each pixel and determine it's color vs a custom
    //       iteration that just sets pixel values, could combine these strategies
    //     - layers?  Additive/Subtractive layers?
    //     - split the graphic into retangles and render each subrectangle
    //       independently (could even be paralellized?!?)
    //     - every operation could have a bounding rectangle that we check
    //       before doing any calculation
    const ops = getOps(grapheme_utf8);
    for (0..height) |row| {
        const row_offset = row * stride;
        for (0..width) |col| {
            grayscale[row_offset + col] = pixelShaderOps(
                width,
                height,
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

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// TODO: have a version of this that instead of ops, takes bytes: []const u8 and
//       decodes the bytes into ops as it goes and runs this function
fn pixelShaderOps(w: u16, h: u16, col: u16, row: u16, ops: []const glyphs.Op) u8 {
    var intensity: u8 = 0;
    for (ops) |*op| {
        intensity = @max(intensity, pixelShaderOp(w, h, col, row, op));
        if (intensity >= 255) break;
    }
    return intensity;
}
fn pixelShaderOp(w: u16, h: u16, col: u16, row: u16, op: *const glyphs.Op) u8 {
    switch (op.condition) {
        .yes => {},
        ._1_has_bottom_bar => return 0, // disable for now
    }
    return switch (op.op) {
        inline else => |*args, tag| @field(shaders, @tagName(tag))(
            w,
            h,
            col,
            row,
            args,
        ),
    };
}

fn pixelShaderErrorGlyph(w: u16, h: u16, col: u16, row: u16) u8 {
    _ = w;
    _ = h;
    _ = col;
    _ = row;
    return 20;
    // const circle_radius = 0.35;
    // const pos = normalizePos(w, h, col, row);
    // const dist = calcDistance(pos, .{ .x = 0.5, .y = 0.5 });
    // return antialiasNormalized(dist - circle_radius, @max(height, width));
}

fn getStrokeWidth(w: u16) u16 {
    // this is a good modification for testing
    //if (true) return 1;
    return @max(1, @as(u16, @intFromFloat(@round(@as(f32, @floatFromInt(w)) / 5))));
}

// const old_shaders = struct {
//     fn stroke_diag(w: u16, h: u16, col: u16, row: u16, diag: Diag) u8 {
//         return shaderDiagPx(
//             col,
//             row,
//             getStrokeWidth(w),
//             diag.x0.toPx(w),
//             diag.y0.toPx(h),
//             diag.x1.toPx(w),
//             diag.y1.toPx(h),
//             .sharp_corner,
//         );
//     }
// };

const Extent = struct {
    low: u16,
    high: u16,
    pub fn contains(self: Extent, value: u16) bool {
        return value >= self.low and value < self.high;
    }
    pub fn center(self: Extent) f32 {
        const low_f32: f32 = @floatFromInt(self.low);
        return low_f32 + (@as(f32, @floatFromInt(self.high)) - low_f32) / 2.0;
    }
    pub fn initStrokeX(w: u16, x: glyphs.StrokeX) Extent {
        const stroke_width = getStrokeWidth(w);
        const coord = coordFromX(w, x.value());
        const rounded_coord: u16 = @intFromFloat(@round(coord));
        const diff: struct { sub: u16, add: u16 } = blk: {
            switch (x) {
                .left => break :blk .{ .sub = 0, .add = stroke_width },
                .center => {
                    const small = @divTrunc(stroke_width, 2);
                    const big = @divTrunc(stroke_width + 1, 2);
                    const diff = @abs(@as(f32, @floatFromInt(rounded_coord)) - coord);
                    std.debug.assert(diff <= 1);
                    break :blk if (diff >= 0.5)
                        .{ .sub = big, .add = small }
                    else
                        .{ .sub = small, .add = big };
                },
                .right => break :blk .{ .sub = stroke_width, .add = 0 },
            }
        };
        return .{ .low = rounded_coord -| diff.sub, .high = rounded_coord +| diff.add };
    }
    pub fn initStrokeY(w: u16, h: u16, y: glyphs.StrokeY) Extent {
        const stroke_width = getStrokeWidth(w);
        const coord = coordFromY(w, h, y.value());
        const rounded_coord: u16 = @intFromFloat(@round(coord));
        const diff: struct { sub: u16, add: u16 } = blk: {
            switch (y) {
                .top => break :blk .{ .sub = 0, .add = stroke_width },
                .center => {
                    const small = @divTrunc(stroke_width, 2);
                    const big = @divTrunc(stroke_width + 1, 2);
                    const diff = @abs(@as(f32, @floatFromInt(rounded_coord)) - coord);
                    std.debug.assert(diff <= 1);
                    break :blk if (diff >= 0.5)
                        .{ .sub = big, .add = small }
                    else
                        .{ .sub = small, .add = big };
                },
                .bottom => break :blk .{ .sub = stroke_width, .add = 0 },
            }
        };
        return .{ .low = rounded_coord -| diff.sub, .high = rounded_coord +| diff.add };
    }
};

const shaders = struct {
    fn stroke_vert(w: u16, h: u16, col: u16, row: u16, s: *const glyphs.StrokeVert) u8 {
        const extent_x = Extent.initStrokeX(w, s.x);
        return shaderRectCoords(
            col,
            row,
            extent_x.low,
            roundedCoordFromY(w, h, s.top),
            extent_x.high,
            roundedCoordFromY(w, h, s.bottom),
        );
    }
    fn stroke_horz(w: u16, h: u16, col: u16, row: u16, s: *const glyphs.StrokeHorz) u8 {
        const extent_y = Extent.initStrokeY(w, h, s.y);
        return shaderRectCoords(
            col,
            row,
            roundedCoordFromX(w, s.left),
            extent_y.low,
            roundedCoordFromX(w, s.right),
            extent_y.high,
        );
    }
    fn stroke_diag(w: u16, h: u16, col: u16, row: u16, s: *const glyphs.StrokeDiag) u8 {
        return shaderDiagCoords(
            col,
            row,
            .{
                .low = roundedCoordFromX(w, s.left),
                .high = roundedCoordFromX(w, s.right),
            },
            .{
                .low = roundedCoordFromY(w, h, s.top),
                .high = roundedCoordFromY(w, h, s.bottom),
            },
            s.slope_ltr,
            s.left_attach,
            s.right_attach,
            @as(f32, @floatFromInt(getStrokeWidth(w))) / 2.0,
        );
    }
    fn stroke_dot(w: u16, h: u16, col: u16, row: u16, s: *const glyphs.StrokePoint) u8 {
        const stroke_width = getStrokeWidth(w);
        const extent_x = Extent.initStrokeX(w, s.x);
        const extent_y = Extent.initStrokeY(w, h, s.y);
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
    fn todo(w: u16, h: u16, col: u16, row: u16, args: *const void) u8 {
        _ = w;
        _ = h;
        _ = col;
        _ = row;
        _ = args;
        return 200;
        // const pos = normalizePos(w, h, col, row);
        // const border_width = 0.1;

        // if (@min(pos.x, 1.0 - pos.x) <= border_width) return 255;
        // if (@min(pos.y, 1.0 - pos.y) <= border_width) return 255;
        // return 0;
    }
};

fn shaderRectCoords(col: u16, row: u16, l: u16, t: u16, r: u16, b: u16) u8 {
    return if (col < l or col >= r or row < t or row >= b) 0 else 255;
}
fn shaderCircleCoords(col: u16, row: u16, x: f32, y: f32, diameter: u16) u8 {
    const radius: f32 = @as(f32, @floatFromInt(diameter)) / 2.0;
    const px: f32 = @as(f32, @floatFromInt(col)) + 0.5; // Center of pixel
    const py: f32 = @as(f32, @floatFromInt(row)) + 0.5;
    const dx = px - x;
    const dy = py - y;
    const distance = @sqrt(dx * dx + dy * dy);
    return antialias(radius, distance);
}
fn shaderDiagCoords(
    col: u16,
    row: u16,
    extent_x: Extent,
    extent_y: Extent,
    slope_ltr: glyphs.Ascent,
    left_attach: glyphs.Dimension,
    right_attach: glyphs.Dimension,
    half_stroke_width: f32,
) u8 {
    std.debug.assert(extent_x.low <= extent_x.high);
    std.debug.assert(extent_y.low <= extent_y.high);

    if (!extent_x.contains(col)) return 0;
    if (!extent_y.contains(row)) return 0;

    const pixel_center: Coord(f32) = .{
        .x = @as(f32, @floatFromInt(col)) + 0.5,
        .y = @as(f32, @floatFromInt(row)) + 0.5,
    };
    const p0_offset: Coord(f32) = switch (left_attach) {
        .x => .{ .x = 0, .y = switch (slope_ltr) {
            .ascend => -half_stroke_width,
            .descend => half_stroke_width,
        } },
        .y => .{ .x = half_stroke_width, .y = 0 },
    };
    const p0: Coord(f32) = .{
        .x = p0_offset.x + @as(f32, @floatFromInt(extent_x.low)),
        .y = p0_offset.y + @as(f32, switch (slope_ltr) {
            .ascend => @floatFromInt(extent_y.high),
            .descend => @floatFromInt(extent_y.low),
        }),
    };
    const p1_offset: Coord(f32) = switch (right_attach) {
        .x => .{ .x = 0, .y = switch (slope_ltr) {
            .ascend => half_stroke_width,
            .descend => -half_stroke_width,
        } },
        .y => .{ .x = -half_stroke_width, .y = 0 },
    };
    const p1: Coord(f32) = .{
        .x = p1_offset.x + @as(f32, @floatFromInt(extent_x.high)),
        .y = p1_offset.y + @as(f32, switch (slope_ltr) {
            .ascend => @floatFromInt(extent_y.low),
            .descend => @floatFromInt(extent_y.high),
        }),
    };
    const distance = pointToLineDistance(pixel_center, p0, p1);
    const thickness = half_stroke_width;
    return antialias(thickness, distance);
}

fn antialias(boundary: f32, position: f32) u8 {
    if (position <= boundary - 0.7071) return 255; // sqrt(2)/2 ≈ 0.7071 for pixel coverage
    if (position >= boundary + 0.7071) return 0;

    // Pixel is on the edge - calculate coverage
    const coverage = (boundary + 0.7071 - position) / (2 * 0.7071);
    return @intFromFloat(coverage * 255.0);
}

fn Coord(comptime T: type) type {
    return struct {
        x: T,
        y: T,
    };
}

pub fn pointToLineDistance(p: Coord(f32), p1: Coord(f32), p2: Coord(f32)) f32 {
    // Calculate the numerator: |(x₂-x₁)(y₁-y₀) - (x₁-x₀)(y₂-y₁)|
    const numerator = @abs((p2.x - p1.x) * (p1.y - p.y) -
        (p1.x - p.x) * (p2.y - p1.y));

    // Calculate the denominator: √((x₂-x₁)² + (y₂-y₁)²)
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
fn calcDist(x0: f32, y0: f32, x1: f32, y1: f32) f32 {
    return @sqrt(square(f32, x1 - x0) + square(f32, y1 - y0));
}

fn roundedCoordFromX(w: u16, x: glyphs.X) u16 {
    return @intFromFloat(@round(coordFromX(w, x)));
}
fn coordFromX(w: u16, x: glyphs.X) f32 {
    const base_x = coordFromBaseX(w, x.base);
    return base_x + x.offset.getFactor() * @as(f32, @floatFromInt(getStrokeWidth(w)));
}
fn coordFromBaseX(w: u16, x: glyphs.BaseX) f32 {
    // if x is large enough, we just always use the same floating point
    // multiplier for the position
    const uppercase_left = 0.124;
    const bottom_bar_left = 0.150;
    const large_enough_value: f32 = switch (x) {
        .uppercase_left => uppercase_left,
        .bottom_bar_left => bottom_bar_left,
        .center => 0.5,
        .bottom_bar_right => 1.0 - bottom_bar_left,
        .uppercase_right => 1.0 - uppercase_left,
    };
    return large_enough_value * @as(f32, @floatFromInt(w));
    //return @intFromFloat(@round(large_enough_value * @as(f32, @floatFromInt(w))));
    //return @intFromFloat(@round(large_enough_value * @as(f32, @floatFromInt(w))));
}

fn roundedCoordFromY(w: u16, h: u16, x: glyphs.Y) u16 {
    return @intFromFloat(@round(coordFromY(w, h, x)));
}
fn coordFromY(w: u16, h: u16, y: glyphs.Y) f32 {
    const base_y = coordFromBaseY(h, y.base);
    return base_y + y.offset.getFactor() * @as(f32, @floatFromInt(getStrokeWidth(w)));
}
fn coordFromBaseY(h: u16, y: glyphs.BaseY) f32 {
    // if y is large enough, we just always use the same floating point
    // multiplier for the position
    const large_enough_value: f32 = switch (y) {
        .uppercase_top => 0.065,
        .lowercase_dot_bottom => 0.199,
        .lowercase_top => 0.280,
        .uppercase_midline_center => 0.418,
        .baseline => 0.8,
    };
    return large_enough_value * @as(f32, @floatFromInt(h));
}
