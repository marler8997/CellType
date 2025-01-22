pub const DesignBoundaryBaseX = enum {
    /// center of uppercase left stroke
    uppercase_left,
    center,
    /// center of uppercase right stroke
    uppercase_right,
};
pub const DesignBoundaryBaseY = enum {
    /// center of uppercase top
    uppercase_top,
    uppercase_top_quarter,
    lowercase_dot,
    _1_slanty_bottom,
    lowercase_top,
    uppercase_center,
    /// center of a stroke where the bottom touches the baseline
    baseline_stroke,
};

// NOTE: not currently and not sure if it should be used or not yet
pub const StrokeBalance = enum {
    // the stroke is balanced on the design boundary and when faced with
    // a choice of which way to grow, will grow away from the center
    balanced_away_from_center,
};

pub const DesignBoundaryX = struct {
    base: DesignBoundaryBaseX,
    half_stroke_adjust: i8 = 0,
};
pub const DesignBoundaryY = struct {
    base: DesignBoundaryBaseY,
    half_stroke_adjust: i8 = 0,
};

// Disables draw commands that follow based on a vertical or horizontal boundary.
// Has no effect on draw commands that come before.
pub const Clip = struct {
    left: ?DesignBoundaryX = null,
    right: ?DesignBoundaryX = null,
    top: ?DesignBoundaryY = null,
    bottom: ?DesignBoundaryY = null,
    // The number of draw commands that follow to apply the clip to. If count is
    // 0 then it applies to all the following draw operations.
    count: u8 = 0,
};

pub const StrokeVert = struct {
    x: DesignBoundaryX,
    // TODO: we might want this at some point if we want strokes
    //       that grow differently based on the stroke size
    //balance: StrokeBalance,
};
pub const StrokeHorz = struct {
    y: DesignBoundaryY,
    // TODO: we might want this at some point if we want strokes
    //       that grow differently based on the stroke size
    //balance: StrokeBalance,
};

pub const DesignBoundaryPoint = struct {
    x: DesignBoundaryX,
    y: DesignBoundaryY,
};

pub const StrokeDiag = struct {
    a: DesignBoundaryPoint,
    b: DesignBoundaryPoint,
};

const Point = struct {
    x: DesignBoundaryX,
    y: DesignBoundaryY,
};

pub const StrokeCurve = struct {
    start: Point,
    control: Point,
    end: Point,
};

pub const Condition = enum {
    yes,
    serif,
};

pub const Op = struct {
    condition: Condition = .yes,
    op: union(enum) {
        todo: void,
        clip: Clip,
        stroke_vert: StrokeVert,
        stroke_horz: StrokeHorz,
        stroke_diag: StrokeDiag,
        stroke_dot: DesignBoundaryPoint,
        stroke_curve: StrokeCurve,
    },
};

pub const todo = [_]Op{.{ .op = .todo }};

pub const c = struct {
    pub const @"1" = [_]Op{
        .{ .op = .{ .clip = .{
            .top = .{ .base = .uppercase_top, .half_stroke_adjust = -1 },
            .bottom = .{ .base = .baseline_stroke, .half_stroke_adjust = 1 },
        } } },
        // slanty's line cap looks wrong, could fix if we have the ability to clip a diagonal
        .{ .op = .{ .clip = .{
            .count = 1,
            .left = .{ .base = .uppercase_left, .half_stroke_adjust = -1 },
            .right = .{ .base = .center, .half_stroke_adjust = 1 },
        } } },
        .{ .op = .{ .stroke_diag = .{
            .a = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = ._1_slanty_bottom } },
            .b = .{ .x = .{ .base = .center, .half_stroke_adjust = -1 }, .y = .{ .base = .uppercase_top } },
        } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .base = .center } } } },
        .{ .op = .{ .clip = .{
            .left = .{ .base = .uppercase_left, .half_stroke_adjust = -1 },
            .right = .{ .base = .uppercase_right, .half_stroke_adjust = 1 },
        } } },
        .{ .condition = .serif, .op = .{ .stroke_horz = .{ .y = .{ .base = .baseline_stroke } } } },
    };
    pub const @"2" = [_]Op{
        .{ .op = .{ .clip = .{
            .left = .{ .base = .uppercase_left, .half_stroke_adjust = -1 },
            .right = .{ .base = .uppercase_right, .half_stroke_adjust = 1 },
            .top = .{ .base = .uppercase_top, .half_stroke_adjust = -1 },
            .bottom = .{ .base = .baseline_stroke, .half_stroke_adjust = 1 },
        } } },
        // top left
        .{ .op = .{
            .stroke_curve = .{
                .start = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .uppercase_top_quarter } },
                .control = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .uppercase_top } },
                .end = .{ .x = .{ .base = .center }, .y = .{ .base = .uppercase_top } },
            },
        } },
        // top right
        .{ .op = .{
            .stroke_curve = .{
                .start = .{ .x = .{ .base = .center }, .y = .{ .base = .uppercase_top } },
                .control = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_top } },
                .end = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_top_quarter } },
            },
        } },
        // middle right
        .{ .op = .{
            .stroke_curve = .{
                .start = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_top_quarter } },
                .control = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_center, .half_stroke_adjust = -1 } },
                .end = .{ .x = .{ .base = .center }, .y = .{ .base = .uppercase_center, .half_stroke_adjust = 1 } },
            },
        } },
        // middle left
        .{ .op = .{
            .stroke_curve = .{
                .start = .{ .x = .{ .base = .center }, .y = .{ .base = .uppercase_center, .half_stroke_adjust = 1 } },
                .control = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .uppercase_center, .half_stroke_adjust = 3 } },
                .end = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .baseline_stroke, .half_stroke_adjust = -1 } },
            },
        } },
        .{ .op = .{ .stroke_horz = .{ .y = .{ .base = .baseline_stroke } } } },
    };
    pub const H = [_]Op{
        .{ .op = .{ .clip = .{
            .left = .{ .base = .uppercase_left, .half_stroke_adjust = -1 },
            .right = .{ .base = .uppercase_right, .half_stroke_adjust = 1 },
            .top = .{ .base = .uppercase_top, .half_stroke_adjust = -1 },
            .bottom = .{ .base = .baseline_stroke, .half_stroke_adjust = 1 },
        } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .base = .uppercase_left } } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .base = .uppercase_right } } } },
        .{ .op = .{ .stroke_horz = .{ .y = .{ .base = .uppercase_center } } } },
    };
    pub const i = [_]Op{
        .{ .op = .{ .clip = .{
            .left = .{ .base = .center, .half_stroke_adjust = -1 },
            .right = .{ .base = .center, .half_stroke_adjust = 1 },
            .bottom = .{ .base = .baseline_stroke, .half_stroke_adjust = 1 },
        } } },
        .{ .op = .{ .stroke_dot = .{ .x = .{ .base = .center }, .y = .{ .base = .lowercase_dot } } } },
        .{ .op = .{ .clip = .{ .top = .{ .base = .lowercase_top, .half_stroke_adjust = -1 } } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .base = .center } } } },
    };
    pub const N = [_]Op{
        .{ .op = .{ .clip = .{
            .left = .{ .base = .uppercase_left, .half_stroke_adjust = -1 },
            .right = .{ .base = .uppercase_right, .half_stroke_adjust = 1 },
            .top = .{ .base = .uppercase_top, .half_stroke_adjust = -1 },
            .bottom = .{ .base = .baseline_stroke, .half_stroke_adjust = 1 },
        } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .base = .uppercase_left } } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .base = .uppercase_right } } } },
        .{ .op = .{ .stroke_diag = .{
            .a = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .uppercase_top, .half_stroke_adjust = -1 } },
            .b = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .baseline_stroke, .half_stroke_adjust = 1 } },
        } } },
    };
    pub const Z = [_]Op{
        .{ .op = .{ .clip = .{
            .left = .{ .base = .uppercase_left, .half_stroke_adjust = -1 },
            .right = .{ .base = .uppercase_right, .half_stroke_adjust = 1 },
            .top = .{ .base = .uppercase_top, .half_stroke_adjust = -1 },
            .bottom = .{ .base = .baseline_stroke, .half_stroke_adjust = 1 },
        } } },
        .{ .op = .{ .stroke_horz = .{ .y = .{ .base = .uppercase_top } } } },
        .{ .op = .{ .stroke_horz = .{ .y = .{ .base = .baseline_stroke } } } },
        .{ .op = .{ .stroke_diag = .{
            .a = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .baseline_stroke, .half_stroke_adjust = -1 } },
            .b = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_top, .half_stroke_adjust = 1 } },
        } } },
    };
    pub const O = [_]Op{
        .{ .op = .{
            .stroke_curve = .{
                .start = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .uppercase_center } },
                .control = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .uppercase_top } },
                .end = .{ .x = .{ .base = .center }, .y = .{ .base = .uppercase_top } },
            },
        } },
        .{ .op = .{
            .stroke_curve = .{
                .start = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_center } },
                .control = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_top } },
                .end = .{ .x = .{ .base = .center }, .y = .{ .base = .uppercase_top } },
            },
        } },
        .{ .op = .{
            .stroke_curve = .{
                .start = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .uppercase_center } },
                .control = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .baseline_stroke } },
                .end = .{ .x = .{ .base = .center }, .y = .{ .base = .baseline_stroke } },
            },
        } },
        .{ .op = .{
            .stroke_curve = .{
                .start = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_center } },
                .control = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .baseline_stroke } },
                .end = .{ .x = .{ .base = .center }, .y = .{ .base = .baseline_stroke } },
            },
        } },
    };
};
