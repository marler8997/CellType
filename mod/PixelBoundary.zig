const PixelBoundary = @This();

const std = @import("std");
const design = @import("design.zig");

pub const StrokeBias = enum {
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

rounded: i32,
stroke_bias: StrokeBias,

pub fn fromDesignX(w: i32, stroke_width: i32, x: design.BoundaryX) PixelBoundary {
    const boundary = fromDesignBaseX(w, stroke_width, x.base);
    return boundary.adjust(stroke_width, x.half_stroke_adjust);
}
pub fn fromDesignY(h: i32, stroke_width: i32, y: design.BoundaryY) PixelBoundary {
    const boundary = fromDesignBaseY(h, stroke_width, y.base);
    return boundary.adjust(stroke_width, y.half_stroke_adjust);
}

pub fn fromDesignBaseX(w: i32, stroke_width: i32, x: design.BoundaryBaseX) PixelBoundary {
    // if x is large enough, we just always use the same floating point
    // multiplier for the position
    const large_enough_ratio: f32 = switch (x) {
        .uppercase_left => 0.210,
        .center => 0.5,
        .uppercase_right => return fromDesignBaseX(w, stroke_width, .uppercase_left).centerReflect(w),
    };
    return PixelBoundary.initFloat(large_enough_ratio * @as(f32, @floatFromInt(w)));
}

pub fn fromDesignBaseY(h: i32, stroke_width: i32, y: design.BoundaryBaseY) PixelBoundary {
    // if y is large enough, we just always use the same floating point
    // multiplier for the position
    const large_enough_ratio: f32 = switch (y) {
        .uppercase_top => 0.2,
        .uppercase_top_quarter => {
            const top = fromDesignBaseY(h, stroke_width, .uppercase_top);
            const baseline = fromDesignBaseY(h, stroke_width, .baseline_stroke);
            return top.centerBetween(baseline).centerBetween(top);
        },
        .lowercase_dot => return fromDesignBaseY(
            h,
            stroke_width,
            .lowercase_top,
        ).adjust(stroke_width, -1).centerBetween(
            PixelBoundary{ .rounded = 0, .stroke_bias = .pos },
        ),
        ._1_slanty_bottom => 0.266,
        .lowercase_top => 0.4,
        .uppercase_center => return fromDesignBaseY(
            h,
            stroke_width,
            .uppercase_top,
        ).centerBetween(
            fromDesignBaseY(h, stroke_width, .baseline_stroke),
        ),
        .baseline_stroke => 0.71,
    };
    return PixelBoundary.initFloat(large_enough_ratio * @as(f32, @floatFromInt(h)));
}

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
            inline for (std.meta.fields(design.BoundaryBaseX)) |x_field| {
                const x: design.BoundaryBaseX = @enumFromInt(x_field.value);
                const boundary = fromDesignBaseX(size, stroke_width, x);
                for (0..10) |i_usize| {
                    const i: i8 = @intCast(i_usize);
                    const pos = boundary.adjust(stroke_width, i);
                    try std.testing.expectEqual(boundary, pos.adjust(stroke_width, -i));
                    try std.testing.expectEqual(boundary, boundary.adjust(stroke_width, -i).adjust(stroke_width, i));
                    try std.testing.expectEqual(pos, pos.adjust(stroke_width, i).adjust(stroke_width, -i));
                }
            }
            inline for (std.meta.fields(design.BoundaryBaseY)) |y_field| {
                const y: design.BoundaryBaseY = @enumFromInt(y_field.value);
                const boundary = fromDesignBaseY(size, stroke_width, y);
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
