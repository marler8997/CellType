pub const X = enum {
    // //zero,
    uppercase_left,
    bottom_bar_left,
    center,
    bottom_bar_right,
    uppercase_right,
};
pub const Y = enum {
    uppercase_top,
    lowercase_dot_bottom,
    lowercase_top,
    uppercase_midline_center,
    baseline,
};

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
        .{ .op = .{ .stroke_vert = .{ .x = .{ .center = .center }, .top = .uppercase_top, .bottom = .baseline } } },
        // TODO: draw the little slanty top part
        .{ .condition = ._1_has_bottom_bar, .op = .{ .stroke_horz = .{ .y = .{ .bottom = .baseline }, .left = .bottom_bar_left, .right = .bottom_bar_right } } },
    };
    pub const H = [_]Op{
        .{ .op = .{ .stroke_vert = .{ .x = .{ .left = .uppercase_left }, .top = .uppercase_top, .bottom = .baseline } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .right = .uppercase_right }, .top = .uppercase_top, .bottom = .baseline } } },
        .{ .op = .{ .stroke_horz = .{ .y = .{ .center = .uppercase_midline_center }, .left = .uppercase_left, .right = .uppercase_right } } },
    };
    pub const i = [_]Op{
        .{ .op = .{ .stroke_dot = .{ .x = .{ .center = .center }, .y = .{ .bottom = .lowercase_dot_bottom } } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .center = .center }, .top = .lowercase_top, .bottom = .baseline } } },
    };
    pub const N = [_]Op{
        .{ .op = .{ .stroke_vert = .{ .x = .{ .left = .uppercase_left }, .top = .uppercase_top, .bottom = .baseline } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .right = .uppercase_right }, .top = .uppercase_top, .bottom = .baseline } } },
        .{ .op = .{ .stroke_diag = .{ .left = .uppercase_left, .top = .uppercase_top, .right = .uppercase_right, .bottom = .baseline, .slope_ltr = .descend, .left_attach = .y, .right_attach = .y } } },
    };
    pub const Z = [_]Op{
        .{ .op = .{ .stroke_horz = .{ .y = .{ .top = .uppercase_top }, .left = .uppercase_left, .right = .uppercase_right } } },
        .{ .op = .{ .stroke_horz = .{ .y = .{ .bottom = .baseline }, .left = .uppercase_left, .right = .uppercase_right } } },
        .{ .op = .{ .stroke_diag = .{ .left = .uppercase_left, .top = .uppercase_top, .right = .uppercase_right, .bottom = .baseline, .slope_ltr = .ascend, .left_attach = .x, .right_attach = .x } } },
    };
};
