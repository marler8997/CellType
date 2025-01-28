const PixelBoundary = @This();

const std = @import("std");
const core = @import("core");
const design = core.design;

pub const Bias = enum {
    neg,
    pos,
    pub fn flip(self: Bias) Bias {
        return switch (self) {
            .neg => .pos,
            .pos,
            => .neg,
        };
    }
};

// represents a boundary between pixels and a direction (negative or positive), i.e.
//
//   -4 => -2 (negative direction
//   -3 => -2 (positive direction)
//   -2 => -1 (negative direction)
//   -1 => -1 (positive direction
//    0 => 0 (negative direction)
//    1 => 0 (positive direction)
//    2 => 1 (negative direction)
//    3 => 1 (positive direction)
//    4 => 2 (negative direction)
//
slot: i32,

pub fn getRounded(self: PixelBoundary) i32 {
    return @divFloor(self.slot + 1, 2);
}
pub fn fromRounded(rounded: i32, bias: Bias) PixelBoundary {
    return .{ .slot = 2 * rounded + @as(i32, switch (bias) {
        .pos => 1,
        .neg => 0,
    }) };
}

pub fn fromDesignX(w: i32, stroke_width: i32, x: design.BoundaryX) PixelBoundary {
    const boundary = fromDesignBaseX(w, stroke_width, x.value.base).adjust(stroke_width, x.value.adjust);
    const bet = x.between orelse return boundary;
    return boundary.betweenX(w, stroke_width, bet).adjust(stroke_width, bet.adjust);
}
pub fn fromDesignY(h: i32, stroke_width: i32, y: design.BoundaryY) PixelBoundary {
    const boundary = fromDesignBaseY(h, stroke_width, y.value.base).adjust(stroke_width, y.value.adjust);
    const bet = y.between orelse return boundary;
    return boundary.betweenY(h, stroke_width, bet).adjust(stroke_width, bet.adjust);
}

pub fn fromDesignBaseX(w: i32, stroke_width: i32, x: design.BoundaryBaseX) PixelBoundary {
    // if x is large enough, we just always use the same floating point
    // multiplier for the position
    const large_enough_ratio: f32 = switch (x) {
        .std_left => 0.210,
        .center => 0.4999,
        .std_right => return fromDesignBaseX(w, stroke_width, .std_left).centerReflect(w),
    };
    return PixelBoundary.initFloat(large_enough_ratio * @as(f32, @floatFromInt(w)));
}

test fromDesignBaseX {
    try std.testing.expectEqual(fromRounded(5, .neg), fromDesignBaseX(10, 2, .center));
}

pub fn fromDesignBaseY(h: i32, stroke_width: i32, y: design.BoundaryBaseY) PixelBoundary {
    // if y is large enough, we just always use the same floating point
    // multiplier for the position
    const large_enough_ratio: f32 = switch (y) {
        .number_top => 0.18,
        .number_top_quarter => {
            const top = fromDesignBaseY(h, stroke_width, .number_top);
            const baseline = fromDesignBaseY(h, stroke_width, .base);
            return top.between(baseline, 0.25);
        },
        .number_center => return fromDesignBaseY(
            h,
            stroke_width,
            .number_top,
        ).between(
            fromDesignBaseY(h, stroke_width, .base),
            0.5,
        ),
        .number_bottom_quarter => {
            const top = fromDesignBaseY(h, stroke_width, .number_top);
            const baseline = fromDesignBaseY(h, stroke_width, .base);
            return top.between(baseline, 0.75);
        },
        .uppercase_top => 0.22,
        .uppercase_top_quarter => {
            const top = fromDesignBaseY(h, stroke_width, .uppercase_top);
            const baseline = fromDesignBaseY(h, stroke_width, .base);
            return top.between(baseline, 0.25);
        },
        .uppercase_center => return fromDesignBaseY(
            h,
            stroke_width,
            .uppercase_top,
        ).between(
            fromDesignBaseY(h, stroke_width, .base),
            0.5,
        ),
        .uppercase_bottom_quarter => {
            const top = fromDesignBaseY(h, stroke_width, .uppercase_top);
            const baseline = fromDesignBaseY(h, stroke_width, .base);
            return top.between(baseline, 0.75);
        },
        .lowercase_dot => return fromDesignBaseY(
            h,
            stroke_width,
            .lowercase_top,
        ).adjust(stroke_width, -1).between(
            PixelBoundary{ .slot = 1 },
            0.5,
        ),
        .lowercase_top => 0.4,
        .lowercase_center => return fromDesignBaseY(
            h,
            stroke_width,
            .lowercase_top,
        ).between(
            fromDesignBaseY(h, stroke_width, .base),
            0.5,
        ),
        .base => 0.71,
    };
    return PixelBoundary.initFloat(large_enough_ratio * @as(f32, @floatFromInt(h)));
}

pub fn initFloat(float: f32) PixelBoundary {
    const rounded: i32 = @intFromFloat(@round(float));
    const remainder = float - @as(f32, @floatFromInt(rounded));
    return fromRounded(rounded, if (remainder >= 0) .pos else .neg);
}

pub fn centerReflect(self: PixelBoundary, size: i32) PixelBoundary {
    return .{ .slot = size * 2 - self.slot };
}

pub fn betweenX(self: PixelBoundary, w: i32, stroke_width: i32, maybe: ?design.BetweenX) PixelBoundary {
    return if (maybe) |b| self.between(fromDesignBaseX(w, stroke_width, b.to.base).adjust(
        stroke_width,
        b.to.adjust,
    ), b.ratio) else self;
}
pub fn betweenY(self: PixelBoundary, h: i32, stroke_width: i32, maybe: ?design.BetweenY) PixelBoundary {
    return if (maybe) |b| self.between(fromDesignBaseY(h, stroke_width, b.to.base).adjust(
        stroke_width,
        b.to.adjust,
    ), b.ratio) else self;
}
pub fn between(self: PixelBoundary, other: PixelBoundary, ratio: f32) PixelBoundary {
    const diff = other.slot - self.slot;
    const lerped: i32 = @intFromFloat(@round(
        std.math.lerp(@as(f32, 0), @as(f32, @floatFromInt(diff)), ratio),
    ));
    std.debug.assert(@abs(lerped) <= @abs(diff));
    return .{
        .slot = self.slot + lerped,
    };
}

pub fn adjust(self: PixelBoundary, stroke_width: i32, half_stroke_offset: i8) PixelBoundary {
    return .{ .slot = self.slot + stroke_width * half_stroke_offset };
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
        self.getRounded(),
        @as(u8, if (@rem(self.slots, 2) == 0) '-' else '+'),
    });
}

fn testCenterBetween(
    expected: PixelBoundary,
    a: PixelBoundary,
    b: PixelBoundary,
) !void {
    const a_to_b = a.between(b, 0.5);
    const b_to_a = b.between(a, 0.5);
    try std.testing.expectEqual(expected.slot, a_to_b.slot);
    try std.testing.expect(@abs(a_to_b.slot - b_to_a.slot) <= 1);
}

fn testBetween(opt: struct {
    expected: PixelBoundary,
    a: PixelBoundary,
    b: PixelBoundary,
    ratio: f32,
}) !void {
    const a_to_b = opt.a.between(opt.b, opt.ratio);
    const b_to_a = opt.b.between(opt.a, 1.0 - opt.ratio);
    try std.testing.expectEqual(opt.expected.slot, a_to_b.slot);
    try std.testing.expectEqual(opt.expected.slot, b_to_a.slot);
}

test "PixelBoundary.centerBetween" {
    try testBetween(.{
        .expected = PixelBoundary.fromRounded(1, .neg),
        .a = PixelBoundary.fromRounded(0, .neg),
        .b = PixelBoundary.fromRounded(2, .neg),
        .ratio = 0.5,
    });
    try testBetween(.{
        .expected = PixelBoundary.fromRounded(0, .pos),
        .a = PixelBoundary.fromRounded(0, .neg),
        .b = PixelBoundary.fromRounded(2, .neg),
        .ratio = 0.25,
    });
    try testBetween(.{
        .expected = PixelBoundary.fromRounded(1, .pos),
        .a = PixelBoundary.fromRounded(0, .neg),
        .b = PixelBoundary.fromRounded(2, .neg),
        .ratio = 0.75,
    });

    for (&[_]i32{ -100, -10, -1, 0, 1, 10, 40 }) |boundary| {
        try testCenterBetween(
            PixelBoundary.fromRounded(boundary, .neg),
            PixelBoundary.fromRounded(boundary, .neg),
            PixelBoundary.fromRounded(boundary, .neg),
        );
        try testCenterBetween(
            PixelBoundary.fromRounded(boundary, .pos),
            PixelBoundary.fromRounded(boundary, .pos),
            PixelBoundary.fromRounded(boundary, .pos),
        );
        try testCenterBetween(
            PixelBoundary.fromRounded(boundary, .pos),
            PixelBoundary.fromRounded(boundary, .neg),
            PixelBoundary.fromRounded(boundary, .pos),
        );
        try testCenterBetween(
            PixelBoundary.fromRounded(boundary, .pos),
            PixelBoundary.fromRounded(boundary, .neg),
            PixelBoundary.fromRounded(boundary + 1, .neg),
        );
        try testCenterBetween(
            PixelBoundary.fromRounded(boundary + 1, .neg),
            PixelBoundary.fromRounded(boundary, .pos),
            PixelBoundary.fromRounded(boundary + 1, .neg),
        );
        try testCenterBetween(
            PixelBoundary.fromRounded(boundary + 1, .neg),
            PixelBoundary.fromRounded(boundary, .pos),
            PixelBoundary.fromRounded(boundary + 1, .pos),
        );
        try testCenterBetween(
            PixelBoundary.fromRounded(boundary, .neg),
            PixelBoundary.fromRounded(boundary, .pos),
            PixelBoundary.fromRounded(boundary - 1, .pos),
        );
        try testCenterBetween(
            PixelBoundary.fromRounded(boundary - 1, .pos),
            PixelBoundary.fromRounded(boundary, .neg),
            PixelBoundary.fromRounded(boundary - 1, .neg),
        );
        try testCenterBetween(
            PixelBoundary.fromRounded(boundary - 1, .pos),
            PixelBoundary.fromRounded(boundary - 1, .neg),
            PixelBoundary.fromRounded(boundary - 1, .pos),
        );
    }
}

fn testAdjust(opt: struct {
    start: PixelBoundary,
    adjusted: PixelBoundary,
    width: i32,
    half_offset: i8,
}) !void {
    try std.testing.expectEqual(opt.adjusted, opt.start.adjust(opt.width, opt.half_offset));
    try std.testing.expectEqual(opt.start, opt.adjusted.adjust(opt.width, -opt.half_offset));
}

test "adjusting boundaries" {
    try testAdjust(.{
        .start = PixelBoundary.fromRounded(0, .neg),
        .adjusted = PixelBoundary.fromRounded(0, .neg),
        .width = 1,
        .half_offset = 0,
    });
    try testAdjust(.{
        .start = PixelBoundary.fromRounded(0, .neg),
        .adjusted = PixelBoundary.fromRounded(0, .pos),
        .width = 1,
        .half_offset = 1,
    });
    try testAdjust(.{
        .start = PixelBoundary.fromRounded(0, .neg),
        .adjusted = PixelBoundary.fromRounded(-1, .pos),
        .width = 1,
        .half_offset = -1,
    });
    try testAdjust(.{
        .start = PixelBoundary.fromRounded(0, .neg),
        .adjusted = PixelBoundary.fromRounded(1, .neg),
        .width = 1,
        .half_offset = 2,
    });
    try testAdjust(.{
        .start = PixelBoundary.fromRounded(100, .pos),
        .adjusted = PixelBoundary.fromRounded(69, .neg),
        .width = 21,
        .half_offset = -3,
    });
    try testAdjust(.{
        .start = PixelBoundary.fromRounded(100, .pos),
        .adjusted = PixelBoundary.fromRounded(70, .pos),
        .width = 20,
        .half_offset = -3,
    });

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
