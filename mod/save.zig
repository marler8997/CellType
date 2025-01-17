// if (false) {
//     const cmd_bytes = getCmdBytes(grapheme_utf8);
//     switch (validateDrawCommand(cmd_bytes)) {
//         .ok => {},
//         .unknown_tag => |offset| std.debug.panic(
//             "unknown tag '{}' in draw command (offset={}, full command='{}')",
//             .{
//                 std.zig.fmtEscapes(cmd_bytes[offset .. offset + 1]),
//                 offset,
//                 std.zig.fmtEscapes(cmd_bytes),
//             },
//         ),
//         .truncated => |offset| std.debug.panic(
//             "truncated draw command '{}'",
//             .{std.zig.fmtEscapes(cmd_bytes[offset..])},
//         ),
//     }
//     for (0..height) |row| {
//         const row_offset = row * stride;
//         for (0..width) |col| {
//             grayscale[row_offset + col] = pixelShader(
//                 width,
//                 height,
//                 @intCast(col),
//                 @intCast(row),
//                 cmd_bytes,
//             );
//         }
//     }
// }

fn getCmdLen(comptime T: type) usize {
    var total: usize = 0;
    inline for (std.meta.fields(T)) |field| {
        std.debug.assert(@sizeOf(field.type) == 1);
        total += 1;
    }
    return total;
}

fn serialize(comptime T: type, value: T) [getCmdLen(T)]u8 {
    const cmd_len = getCmdLen(T);
    var result: [cmd_len]u8 = undefined;
    inline for (std.meta.fields(T), 0..) |field, i| {
        result[i] = switch (@typeInfo(field.type)) {
            .Enum => @intFromEnum(@field(value, field.name)),
            else => @bitCast(@field(value, field.name)),
        };
    }
    return result;
}

fn deserialize(comptime T: type, cmd_bytes: []const u8, offset: *usize) error{DrawCommandTruncated}!T {
    const cmd_len = getCmdLen(T);
    if (offset.* + cmd_len > cmd_bytes.len) return error.DrawCommandTruncated;
    var result: T = undefined;
    inline for (std.meta.fields(T), 0..) |field, i| {
        @field(result, field.name) = switch (@typeInfo(field.type)) {
            .Enum => @enumFromInt(cmd_bytes[offset.* + i]),
            else => @bitCast(cmd_bytes[offset.* + i]),
        };
    }
    offset.* += cmd_len;
    return result;
}

fn validateDrawCommand(cmd_bytes: []const u8) union(enum) {
    ok: void,
    unknown_tag: usize,
    truncated: usize,
} {
    var offset: usize = 0;
    while (offset < cmd_bytes.len) {
        const tag_byte = cmd_bytes[offset];
        offset += 1;
        switch (Command.decodeTag(tag_byte) orelse return .{ .unknown_tag = offset - 1 }) {
            inline else => |tag| {
                _ = deserialize(tag.Args(), cmd_bytes, &offset) catch |e| switch (e) {
                    error.DrawCommandTruncated => return .{ .truncated = offset - 1 },
                };
            },
        }
    }
    return .ok;
}

// invokes unreachable if validateDrawCommand does not return "ok" on cmd_bytes
fn pixelShader(w: u16, h: u16, col: u16, row: u16, cmd_bytes: []const u8) u8 {
    var intensity: u8 = 0;
    var offset: usize = 0;
    while (offset < cmd_bytes.len) {
        const tag_byte = cmd_bytes[offset];
        offset += 1;
        intensity = @max(intensity, switch (Command.decodeTag(tag_byte).?) {
            inline else => |tag| tag.shaderFn()(
                w,
                h,
                col,
                row,
                deserialize(tag.Args(), cmd_bytes, &offset) catch unreachable,
            ),
        });
        if (intensity >= 255) break;
    }
    return intensity;
}

const Command = enum(u8) {
    stroke_ltb,
    stroke_rtb,
    stroke_ctb,
    stroke_lrc,
    stroke_diag,
    stroke_dot,
    //dot_lrb,
    rect,
    todo,
    pub fn decodeTag(byte: u8) ?Command {
        return switch (byte) {
            @intFromEnum(Command.stroke_ltb) => .stroke_ltb,
            @intFromEnum(Command.stroke_rtb) => .stroke_rtb,
            @intFromEnum(Command.stroke_ctb) => .stroke_ctb,
            @intFromEnum(Command.stroke_lrc) => .stroke_lrc,
            @intFromEnum(Command.stroke_diag) => .stroke_diag,
            @intFromEnum(Command.stroke_dot) => .stroke_dot,
            //@intFromEnum(Command.dot_lrb) => .dot_lrb,
            @intFromEnum(Command.rect) => .rect,
            @intFromEnum(Command.todo) => .todo,
            else => null,
        };
    }
    pub fn make(comptime self: Command, args: self.Args()) [1 + getCmdLen(self.Args())]u8 {
        return [_]u8{@intFromEnum(self)} ++ serialize(self.Args(), args);
    }
    pub fn Args(self: Command) type {
        return switch (self) {
            .stroke_ltb => Ltb,
            .stroke_rtb => Rtb,
            .stroke_ctb => Ctb,
            .stroke_lrc => Lrc,
            .stroke_diag => Diag,
            .stroke_dot => Point,
            //.dot_lrb => Lrb,
            .rect => Rect,
            .todo => NoArgs,
        };
    }
    pub fn shaderFn(comptime self: Command) PixelShaderFn(self.Args()) {
        return switch (self) {
            inline else => |tag| @field(shaders, @tagName(tag)),
        };
    }
};

const Dot = struct {
    x: u8,
    y: u8,
    // diameter, 255 would be the full width of the smaller dimension
    d: u8,
};

const NoArgs = struct {};
const Point = struct {
    x: X,
    y: Y,
};
const Diag = struct {
    x0: X,
    y0: Y,
    x1: X,
    y1: Y,
};
const Ltb = struct {
    l: X, // left
    t: Y, // top
    b: Y, // bottom
};
const Rtb = struct {
    r: X, // right
    t: Y, // top
    b: Y, // bottom
};
const Ctb = struct {
    c: X, // center
    t: Y, // top
    b: Y, // bottom
};

const Lrc = struct {
    l: X, // left
    r: X, // right
    c: Y, // center
};
const Lrt = struct {
    l: X, // left
    r: X, // right
    t: Y, // top
};
const Lrb = struct {
    l: X, // left
    r: X, // right
    b: Y, // bottom
};
const Rect = struct {
    l: X,
    t: Y,
    r: X,
    b: Y,
};

fn PixelShaderFn(comptime Args: type) type {
    return fn (w: u16, h: u16, col: u16, row: u16, args: Args) u8;
}

comptime {
    for (std.meta.fields(Command)) |field| {
        if (Command.decodeTag(field.value) != @as(Command, @enumFromInt(field.value)))
            @compileError("add command '" ++ field.name ++ " to the decodeTag function");
    }
}

// fn pxFromX(width: u16, x: X) u16 {
//     return pxFromArg(width, @intFromEnum(x));
// }
// fn pxFromY(height: u16, y: Y) u16 {
//     return pxFromArg(height, @intFromEnum(y));
// }
fn pxFromArgLerp(size: u16, arg: u8) u16 {
    const arg_f32: f32 = @as(f32, @floatFromInt(arg)) / 256.0;
    return @intFromFloat(@floor(arg_f32 * @as(f32, @floatFromInt(size))));
}

test "pxFromArgLerp" {
    for (0..256) |i| {
        try std.testing.expectEqual(i, pxFromArgLerp(256, @intCast(i)));
    }
}

// 0 indexes the first pixel and 255 indexes the last
// so 0 is equivalent to 255 relative to the center
//
// therefore, the reflected high value against the center is
//      low <==> 255 - low
//
//
const X = enum(u8) {
    //zero = 0,
    uppercase_left = 26,
    //h_left = 63,
    h_left = 38,
    center_low = 127,
    center_high = 128,
    h_right = 217,
    uppercase_right = 229,
    //max = 255,

    h_left_add_stroke_width,
    h_right_sub_stroke_width,
    _,

    pub fn toPx(self: X, w: u16) u16 {
        return switch (w) {
            else => switch (self) {
                .h_left_add_stroke_width => return pxFromArgLerp(w, @intFromEnum(X.h_left)) +| getStrokeWidth(w),
                .h_right_sub_stroke_width => return pxFromArgLerp(w, @intFromEnum(X.h_right)) + 1 -| getStrokeWidth(w),
                else => pxFromArgLerp(w, @intFromEnum(self)),
            },
        };
    }
};
const Y = enum(u8) {
    zero = 0,
    uppercase_top = 60,
    dot_top = 70,
    lowercase_top = 100,
    //uppercase_center = 120,
    center_low = 127,
    center_high = 128,
    baseline = 208,
    max = 255,
    _,
    pub fn toPx(self: Y, h: u16) u16 {
        return switch (h) {
            else => pxFromArgLerp(h, @intFromEnum(self)),
        };
    }
};

const glyphdef = struct {
    const todo = Command.todo.make(.{});

    const H = Command.stroke_ltb.make(.{
        .l = .h_left,
        .t = .uppercase_top,
        .b = .baseline,
    }) ++ Command.stroke_rtb.make(.{
        .r = .h_right,
        .t = .uppercase_top,
        .b = .baseline,
    }) ++ Command.stroke_lrc.make(.{
        .l = .h_left,
        .r = .h_right,
        .c = .center_high,
    });
    const N = Command.stroke_ltb.make(.{
        .l = .h_left,
        .t = .uppercase_top,
        .b = .baseline,
    }) ++ Command.stroke_rtb.make(.{
        .r = .h_right,
        .t = .uppercase_top,
        .b = .baseline,
    }) ++ Command.stroke_diag.make(.{
        .x0 = .h_left_add_stroke_width,
        .y0 = .uppercase_top,
        .x1 = .h_right_sub_stroke_width,
        .y1 = .baseline,
    });
    // simple i, todo: fancy i
    const i = Command.stroke_dot.make(.{
        .x = .center_high,
        .y = .dot_top,
    }) ++
        Command.stroke_ctb.make(.{
        .c = .center_high,
        .t = .lowercase_top,
        .b = .baseline,
    });
    // temporary implementation for testing
    //const M = Command.rect.make(.{ .l = .zero, .t = .zero, .r = .max, .b = .max });
};

fn getCmdBytes(grapheme_utf8: []const u8) []const u8 {
    if (grapheme_utf8.len == 1) return switch (grapheme_utf8[0]) {
        inline else => |c| if (@hasDecl(glyphdef, &[_]u8{c})) &@field(glyphdef, &[_]u8{c}) else &glyphdef.todo,
        else => &glyphdef.todo,
    };
    return &glyphdef.todo;
}

fn renderErrorGlyph(size: XY(u16), out_alphas: [*]u8, stride: usize) void {
    // Draws a circle with diagonal crossed lines
    const line_thickness = 0.15;
    const circle_thickness = 0.12;
    const circle_radius = 0.77;

    for (0..size.y) |row| {
        const row_offset = row * stride;
        for (0..size.x) |col| {
            const x_norm = @as(f32, @floatFromInt(col)) / @as(f32, @floatFromInt(size.x)) * 2 - 1;
            const y_norm = @as(f32, @floatFromInt(row)) / @as(f32, @floatFromInt(size.y)) * 2 - 1;

            const dist_from_center = @sqrt(x_norm * x_norm + y_norm * y_norm);
            const dist_from_circle = @abs(dist_from_center - circle_radius);
            const dist_from_diag1 = @abs(y_norm - x_norm);
            const dist_from_diag2 = @abs(y_norm + x_norm);

            const circle_alpha = 1.0 - smoothstep(0, circle_thickness, dist_from_circle);
            const diag1_alpha = 1.0 - smoothstep(0, line_thickness, dist_from_diag1);
            const diag2_alpha = 1.0 - smoothstep(0, line_thickness, dist_from_diag2);

            const max_alpha = @max(circle_alpha, @max(diag1_alpha, diag2_alpha));

            out_alphas[row_offset + col] = @as(u8, @intFromFloat(max_alpha * 255.0));
        }
    }
}

// fn normalizePosStretch(w: u16, h: u16, col: u16, row: u16) XY(f32) { //
//     return .{
//         .x = @as(f32, @floatFromInt(col)) / @as(f32, @floatFromInt(w)),
//         .yy = @as(f32, @floatFromInt(row)) / @as(f32, @floatFromInt(h)),
//     };
// }

// const Operation = enum {
//     stretch,
//     center,
// };

// fn normalizePos(h: u16, w: u16, col: u16, row: u16, op: Operation) XY(f32) {
//     var x = @as(f32, @floatFromInt(col)) / @as(f32, @floatFromInt(w));
//     var y = @as(f32, @floatFromInt(row)) / @as(f32, @floatFromInt(h));

//     switch (op) {
//         // In stretch mode, we use the raw normalized coordinates
//         .stretch => {},
//         .center => {
//             // In center mode, adjust the coordinates of the smaller dimension
//             // to maintain the aspect ratio and center the content.
//             const aspect_ratio = @as(f32, @floatFromInt(w)) / @as(f32, @floatFromInt(h));
//             if (aspect_ratio > 1.0) {
//                 // Width is larger, so y is the smaller dimension
//                 // Scale y up by aspect ratio and center it
//                 y = y * aspect_ratio; // Scale up
//                 y = (y - (aspect_ratio - 1.0) / 2.0) / aspect_ratio; // Center and normalize back
//             } else {
//                 // Height is larger, so x is the smaller dimension
//                 // Scale x up by 1/aspect_ratio and center it
//                 const inv_aspect = 1.0 / aspect_ratio;
//                 x = x * inv_aspect; // Scale up
//                 x = (x - (inv_aspect - 1.0) / 2.0) / inv_aspect; // Center and normalize back
//             }
//         },
//     }
//     return .{ .x = x, .y = y };
// }

// test "normalizePos" {
//     const testing = std.testing;
//     const epsilon = 0.0001;

//     {
//         const result = normalizePos(100, 200, 50, 100, .stretch);
//         try testing.expectApproxEqAbs(0.5, result.x, epsilon);
//         try testing.expectApproxEqAbs(0.5, result.y, epsilon);
//     }
//     {
//         const result = normalizePos(100, 200, 50, 100, .center);
//         try testing.expectApproxEqAbs(0.5, result.x, epsilon);
//         try testing.expectApproxEqAbs(0.25, result.y, epsilon);
//     }
//     {
//         const result = normalizePos(200, 100, 100, 50, .center);
//         try testing.expectApproxEqAbs(0.25, result.x, epsilon);
//         try testing.expectApproxEqAbs(0.5, result.y, epsilon);
//     }

//     {
//         const tl = normalizePos(100, 100, 0, 0, .stretch);
//         try testing.expectApproxEqAbs(tl.x, 0.0, epsilon);
//         try testing.expectApproxEqAbs(tl.y, 0.0, epsilon);
//         const br = normalizePos(100, 100, 99, 99, .stretch);
//         try testing.expectApproxEqAbs(br.x, 0.99, epsilon);
//         try testing.expectApproxEqAbs(br.y, 0.99, epsilon);
//     }
// }

fn antialiasNormalized(dist: f32, max_pixel_count: u16) u8 {
    if (dist <= 0) return 255;
    const dist_pix: f32 = @as(f32, @floatFromInt(max_pixel_count)) * dist;
    if (dist_pix >= 1) return 0;
    return 255 - lerpUint(u8, 0, 255, dist_pix);
}

fn square(comptime T: type, x: T) T {
    return x * x;
}
pub fn calcDistance(self: XY(f32), other: XY(f32)) f32 {
    return @sqrt(square(f32, self.x - other.x) + square(f32, self.y - other.y));
}

fn smoothstep(edge0: f32, edge1: f32, x: f32) f32 {
    const t = @min(@max((x - edge0) / (edge1 - edge0), 0.0), 1.0);
    return t * t * (3.0 - 2.0 * t);
}

pub fn lerpUint(comptime T: type, start: T, end: T, t: f32) T {
    std.debug.assert(end >= start);
    return start + @as(T, @intFromFloat(@as(f32, @floatFromInt(end - start)) * t));
}

fn XY(comptime T: type) type {
    return struct {
        x: T,
        y: T,
        pub fn init(x: T, y: T) @This() {
            return .{ .x = x, .y = y };
        }
    };
}

const LineCap = enum {
    sharp_corner,
    rounded_center,
};
fn shaderDiagPx(col: u16, row: u16, stroke_width: u16, x0: u16, y0: u16, x1: u16, y1: u16, line_cap: LineCap) u8 {
    switch (line_cap) {
        .sharp_corner => {
            if (col < @min(x0, x1) or col >= @max(x0, x1) or row < @min(y0, y1) or row >= @max(y0, y1)) return 0;
        },
        .rounded_center => {},
    }

    const px: f32 = @as(f32, @floatFromInt(col)) + 0.5; // Center of pixel
    const py: f32 = @as(f32, @floatFromInt(row)) + 0.5;

    const x0f: f32 = @floatFromInt(x0);
    const y0f: f32 = @floatFromInt(y0);
    const x1f: f32 = @floatFromInt(x1);
    const y1f: f32 = @floatFromInt(y1);

    // Calculate line direction vector
    const dx = x1f - x0f;
    const dy = y1f - y0f;
    const line_length = @sqrt(dx * dx + dy * dy);

    if (line_length == 0) return 0;

    // Normalize direction vector
    const nx = dx / line_length;
    const ny = dy / line_length;

    // Vector from line start to pixel center
    const px_to_line_x = px - x0f;
    const px_to_line_y = py - y0f;

    // Project pixel center onto line direction
    const dot = px_to_line_x * nx + px_to_line_y * ny;

    // Clamp projection to line segment
    const t = @min(@max(dot, 0.0), line_length);

    // Calculate nearest point on line
    const nearest_x = x0f + nx * t;
    const nearest_y = y0f + ny * t;

    // Calculate distance from pixel center to nearest point
    const dist_x = px - nearest_x;
    const dist_y = py - nearest_y;
    const distance = @sqrt(dist_x * dist_x + dist_y * dist_y);

    // Calculate pixel coverage using anti-aliasing
    // The line thickness is 1 pixel
    const stroke_widthf: f32 = @floatFromInt(stroke_width);
    const half_width: f32 = stroke_widthf / 2;
    if (distance <= half_width - 0.5) return 255;
    if (distance >= half_width + 0.5) return 0;

    // Anti-alias the edge
    const coverage = (half_width + 0.5 - distance);
    return @intFromFloat(coverage * 255.0);
}
