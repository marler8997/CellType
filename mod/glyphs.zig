pub const BaseX = enum {
    uppercase_left,
    bottom_bar_left,
    _1_slanty_left,
    center,
    bottom_bar_right,
    uppercase_right,
};
pub const BaseY = enum {
    uppercase_top,
    lowercase_dot_bottom,
    _1_slanty_bottom,
    lowercase_top,
    uppercase_center,
    uppercase_midline_center,
    baseline,
};

pub const StrokeOffset = enum {
    @"-1",
    @"-0.5",
    @"0",
    @"0.5",
    @"1",
    pub fn getFactor(self: StrokeOffset) f32 {
        return switch (self) {
            .@"-1" => -1,
            .@"-0.5" => -0.5,
            .@"0" => 0,
            .@"0.5" => 0.5,
            .@"1" => 1,
        };
    }
};

pub const X = struct { base: BaseX, offset: StrokeOffset = .@"0" };
pub const Y = struct { base: BaseY, offset: StrokeOffset = .@"0" };

// Disables draw commands that follow based on a vertical or horizontal boundary.
// Has no effect on draw commands that come before.
pub const Clip = union(enum) {
    left: ClipX,
    right: ClipX,
    top: ClipY,
    bottom: ClipY,
};

pub const ClipX = struct {
    x: X,
    // The number of draw commands that follow to apply the clip to. If count is
    // 0 then it applies to all the following draw operations.
    count: u8 = 0,
};
pub const ClipY = struct { y: Y, count: u8 = 0 };

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// TODO: I *think I can get rid of StrokeX/StrokeY and just use the offset
//       in X/Y instead. Also offset should be an f32 between -1 and 1
pub const StrokeX = union(enum) {
    left: X,
    center: X,
    right: X,
    pub fn value(self: StrokeX) X {
        return switch (self) {
            .left => |x| x,
            .center => |x| x,
            .right => |x| x,
        };
    }
};
pub const StrokeY = union(enum) {
    top: Y,
    center: Y,
    bottom: Y,
    pub fn value(self: StrokeY) Y {
        return switch (self) {
            .top => |y| y,
            .center => |y| y,
            .bottom => |y| y,
        };
    }
};
pub const StrokePoint = struct {
    x: StrokeX,
    y: StrokeY,
};

pub const Dimension = enum { x, y };
pub const Ascent = enum { ascend, descend };

pub const StrokeDiag = struct {
    // TODO: simplify this now that we have Clip
    left: X,
    top: Y,
    right: X,
    bottom: Y,
    slope_ltr: Ascent,
    left_attach: Dimension,
    right_attach: Dimension,
};

const Point = struct {
    x: X,
    y: Y,
};

pub const StrokeCurve = struct {
    start: Point,
    control: Point,
    end: Point,
};

pub const Condition = enum {
    yes,
    _1_has_bottom_bar,
};

pub const Op = struct {
    condition: Condition = .yes,
    op: union(enum) {
        todo: void,
        clip: Clip,
        stroke_vert: StrokeX,
        stroke_horz: StrokeY,
        stroke_diag: StrokeDiag,
        stroke_dot: StrokePoint,
        stroke_curve: StrokeCurve,
    },
};

pub const todo = [_]Op{.{ .op = .todo }};
pub const c = struct {
    pub const @"1" = [_]Op{
        .{ .op = .{ .clip = .{ .top = .{ .y = .{ .base = .uppercase_top } } } } },
        .{ .op = .{ .clip = .{ .bottom = .{ .y = .{ .base = .baseline } } } } },
        // slanty's line cap looks wrong, need new line cap support
        .{ .op = .{ .stroke_diag = .{ .left = .{ .base = ._1_slanty_left }, .top = .{ .base = .uppercase_top }, .right = .{ .base = .center, .offset = .@"0.5" }, .bottom = .{ .base = ._1_slanty_bottom }, .slope_ltr = .ascend, .left_attach = .x, .right_attach = .y } } },
        .{ .op = .{ .clip = .{ .left = .{ .x = .{ .base = .bottom_bar_left } } } } },
        .{ .op = .{ .clip = .{ .right = .{ .x = .{ .base = .bottom_bar_right } } } } },
        .{ .op = .{ .stroke_vert = .{ .center = .{ .base = .center } } } },
        .{ .condition = ._1_has_bottom_bar, .op = .{ .stroke_horz = .{ .bottom = .{ .base = .baseline } } } },
    };
    pub const H = [_]Op{
        .{ .op = .{ .clip = .{ .left = .{ .x = .{ .base = .uppercase_left } } } } },
        .{ .op = .{ .clip = .{ .right = .{ .x = .{ .base = .uppercase_right } } } } },
        .{ .op = .{ .clip = .{ .top = .{ .y = .{ .base = .uppercase_top } } } } },
        .{ .op = .{ .clip = .{ .bottom = .{ .y = .{ .base = .baseline } } } } },
        .{ .op = .{ .stroke_vert = .{ .left = .{ .base = .uppercase_left } } } },
        .{ .op = .{ .stroke_vert = .{ .right = .{ .base = .uppercase_right } } } },
        .{ .op = .{ .stroke_horz = .{ .center = .{ .base = .uppercase_midline_center } } } },
    };
    pub const i = [_]Op{
        .{ .op = .{ .clip = .{ .bottom = .{ .y = .{ .base = .baseline } } } } },
        .{ .op = .{ .stroke_dot = .{ .x = .{ .center = .{ .base = .center } }, .y = .{ .bottom = .{ .base = .lowercase_dot_bottom } } } } },
        .{ .op = .{ .clip = .{ .top = .{ .y = .{ .base = .lowercase_top } } } } },
        .{ .op = .{ .stroke_vert = .{ .center = .{ .base = .center } } } },
    };
    pub const N = [_]Op{
        .{ .op = .{ .clip = .{ .left = .{ .x = .{ .base = .uppercase_left } } } } },
        .{ .op = .{ .clip = .{ .right = .{ .x = .{ .base = .uppercase_right } } } } },
        .{ .op = .{ .clip = .{ .top = .{ .y = .{ .base = .uppercase_top } } } } },
        .{ .op = .{ .clip = .{ .bottom = .{ .y = .{ .base = .baseline } } } } },
        .{ .op = .{ .stroke_vert = .{ .left = .{ .base = .uppercase_left } } } },
        .{ .op = .{ .stroke_vert = .{ .right = .{ .base = .uppercase_right } } } },
        .{ .op = .{ .stroke_diag = .{ .left = .{ .base = .uppercase_left }, .top = .{ .base = .uppercase_top }, .right = .{ .base = .uppercase_right }, .bottom = .{ .base = .baseline }, .slope_ltr = .descend, .left_attach = .y, .right_attach = .y } } },
    };
    pub const Z = [_]Op{
        .{ .op = .{ .clip = .{ .left = .{ .x = .{ .base = .uppercase_left } } } } },
        .{ .op = .{ .clip = .{ .right = .{ .x = .{ .base = .uppercase_right } } } } },
        .{ .op = .{ .clip = .{ .top = .{ .y = .{ .base = .uppercase_top } } } } },
        .{ .op = .{ .clip = .{ .bottom = .{ .y = .{ .base = .baseline } } } } },
        .{ .op = .{ .stroke_horz = .{ .top = .{ .base = .uppercase_top } } } },
        .{ .op = .{ .stroke_horz = .{ .bottom = .{ .base = .baseline } } } },
        .{ .op = .{ .stroke_diag = .{ .left = .{ .base = .uppercase_left }, .top = .{ .base = .uppercase_top, .offset = .@"1" }, .right = .{ .base = .uppercase_right }, .bottom = .{ .base = .baseline, .offset = .@"-1" }, .slope_ltr = .ascend, .left_attach = .y, .right_attach = .y } } },
    };
    pub const O = [_]Op{
        .{ .op = .{
            .stroke_curve = .{
                .start = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .uppercase_center } },
                .control = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .uppercase_top, .offset = .@"0.5" } },
                .end = .{ .x = .{ .base = .center }, .y = .{ .base = .uppercase_top, .offset = .@"0.5" } },
            },
        } },
        .{ .op = .{
            .stroke_curve = .{
                .start = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_center } },
                .control = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_top, .offset = .@"0.5" } },
                .end = .{ .x = .{ .base = .center }, .y = .{ .base = .uppercase_top, .offset = .@"0.5" } },
            },
        } },
        .{ .op = .{
            .stroke_curve = .{
                .start = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .uppercase_center } },
                .control = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .baseline } },
                .end = .{ .x = .{ .base = .center }, .y = .{ .base = .baseline } },
            },
        } },
        .{ .op = .{
            .stroke_curve = .{
                .start = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_center } },
                .control = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .baseline } },
                .end = .{ .x = .{ .base = .center }, .y = .{ .base = .baseline } },
            },
        } },
    };
};
