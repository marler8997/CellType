pub const BaseX = enum {
    uppercase_left,
    bottom_bar_left,
    center,
    bottom_bar_right,
    uppercase_right,
};
pub const BaseY = enum {
    uppercase_top,
    lowercase_dot_bottom,
    lowercase_top,
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

pub const StrokeVert = struct {
    x: StrokeX,
    top: Y,
    bottom: Y,
};
pub const StrokeHorz = struct {
    y: StrokeY,
    left: X,
    right: X,
};

pub const Dimension = enum { x, y };
pub const Ascent = enum { ascend, descend };

pub const StrokeDiag = struct {
    left: X,
    top: Y,
    right: X,
    bottom: Y,
    slope_ltr: Ascent,
    left_attach: Dimension,
    right_attach: Dimension,
};

pub const Condition = enum {
    yes,
    _1_has_bottom_bar,
};

pub const Op = struct {
    condition: Condition = .yes,
    op: union(enum) {
        todo: void,
        stroke_vert: StrokeVert,
        stroke_horz: StrokeHorz,
        stroke_diag: StrokeDiag,
        stroke_dot: StrokePoint,
    },
};

pub const todo = [_]Op{.{ .op = .todo }};
pub const c = struct {
    pub const @"1" = [_]Op{
        .{ .op = .{ .stroke_vert = .{ .x = .{ .center = .{ .base = .center } }, .top = .{ .base = .uppercase_top }, .bottom = .{ .base = .baseline } } } },
        // TODO: draw the little slanty top part
        .{ .condition = ._1_has_bottom_bar, .op = .{ .stroke_horz = .{ .y = .{ .bottom = .{ .base = .baseline } }, .left = .{ .base = .bottom_bar_left }, .right = .{ .base = .bottom_bar_right } } } },
    };
    pub const H = [_]Op{
        .{ .op = .{ .stroke_vert = .{ .x = .{ .left = .{ .base = .uppercase_left } }, .top = .{ .base = .uppercase_top }, .bottom = .{ .base = .baseline } } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .right = .{ .base = .uppercase_right } }, .top = .{ .base = .uppercase_top }, .bottom = .{ .base = .baseline } } } },
        .{ .op = .{ .stroke_horz = .{ .y = .{ .center = .{ .base = .uppercase_midline_center } }, .left = .{ .base = .uppercase_left }, .right = .{ .base = .uppercase_right } } } },
    };
    pub const i = [_]Op{
        .{ .op = .{ .stroke_dot = .{ .x = .{ .center = .{ .base = .center } }, .y = .{ .bottom = .{ .base = .lowercase_dot_bottom } } } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .center = .{ .base = .center } }, .top = .{ .base = .lowercase_top }, .bottom = .{ .base = .baseline } } } },
    };
    pub const N = [_]Op{
        .{ .op = .{ .stroke_vert = .{ .x = .{ .left = .{ .base = .uppercase_left } }, .top = .{ .base = .uppercase_top }, .bottom = .{ .base = .baseline } } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .right = .{ .base = .uppercase_right } }, .top = .{ .base = .uppercase_top }, .bottom = .{ .base = .baseline } } } },
        .{ .op = .{ .stroke_diag = .{ .left = .{ .base = .uppercase_left }, .top = .{ .base = .uppercase_top }, .right = .{ .base = .uppercase_right }, .bottom = .{ .base = .baseline }, .slope_ltr = .descend, .left_attach = .y, .right_attach = .y } } },
    };
    pub const Z = [_]Op{
        .{ .op = .{ .stroke_horz = .{ .y = .{ .top = .{ .base = .uppercase_top } }, .left = .{ .base = .uppercase_left }, .right = .{ .base = .uppercase_right } } } },
        .{ .op = .{ .stroke_horz = .{ .y = .{ .bottom = .{ .base = .baseline } }, .left = .{ .base = .uppercase_left }, .right = .{ .base = .uppercase_right } } } },
        .{ .op = .{ .stroke_diag = .{ .left = .{ .base = .uppercase_left }, .top = .{ .base = .uppercase_top, .offset = .@"1" }, .right = .{ .base = .uppercase_right }, .bottom = .{ .base = .baseline, .offset = .@"-1" }, .slope_ltr = .ascend, .left_attach = .y, .right_attach = .y } } },
    };
};
