pub const DesignBoundaryX = enum {
    /// center of uppercase left stroke
    uppercase_left,
    center,
    /// center of uppercase right stroke
    uppercase_right,
};
pub const DesignBoundaryY = enum {
    /// center of uppercase top
    uppercase_top,
    lowercase_dot,
    _1_slanty_bottom,
    lowercase_top,
    uppercase_center,
    /// center of a stroke where the bottom touches the baseline
    baseline_stroke,
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

// NOTE: not currently and not sure if it should be used or not yet
pub const StrokeBalance = enum {
    // the stroke is balanced on the design boundary and when faced with
    // a choice of which way to grow, will grow away from the center
    balanced_away_from_center,
};

pub const AdjustableDesignBoundaryX = struct {
    base: DesignBoundaryX,
    adjust: StrokeOffset = .@"0",
};
pub const AdjustableDesignBoundaryY = struct {
    base: DesignBoundaryY,
    adjust: StrokeOffset = .@"0",
};

// Disables draw commands that follow based on a vertical or horizontal boundary.
// Has no effect on draw commands that come before.
pub const Clip = struct {
    left: ?AdjustableDesignBoundaryX = null,
    right: ?AdjustableDesignBoundaryX = null,
    top: ?AdjustableDesignBoundaryY = null,
    bottom: ?AdjustableDesignBoundaryY = null,
    // The number of draw commands that follow to apply the clip to. If count is
    // 0 then it applies to all the following draw operations.
    count: u8 = 0,
};

pub const StrokeVert = struct {
    x: AdjustableDesignBoundaryX,
    // TODO: we might want this at some point if we want strokes
    //       that grow differently based on the stroke size
    //balance: StrokeBalance,
};
pub const StrokeHorz = struct {
    y: AdjustableDesignBoundaryY,
    // TODO: we might want this at some point if we want strokes
    //       that grow differently based on the stroke size
    //balance: StrokeBalance,
};

pub const AdjustableDesignBoundaryPoint = struct {
    x: AdjustableDesignBoundaryX,
    y: AdjustableDesignBoundaryY,
};

pub const StrokeDiag = struct {
    a: AdjustableDesignBoundaryPoint,
    b: AdjustableDesignBoundaryPoint,
};

const Point = struct {
    x: AdjustableDesignBoundaryX,
    y: AdjustableDesignBoundaryY,
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
        stroke_vert: StrokeVert,
        stroke_horz: StrokeHorz,
        stroke_diag: StrokeDiag,
        stroke_dot: AdjustableDesignBoundaryPoint,
        stroke_curve: StrokeCurve,
    },
};

pub const todo = [_]Op{.{ .op = .todo }};

pub const c = struct {
    pub const @"1" = [_]Op{
        .{ .op = .{ .clip = .{
            .top = .{ .base = .uppercase_top, .adjust = .@"-0.5" },
            .bottom = .{ .base = .baseline_stroke, .adjust = .@"0.5" },
        } } },
        // slanty's line cap looks wrong, could fix if we have the ability to clip a diagonal
        .{ .op = .{ .clip = .{
            .count = 1,
            .left = .{ .base = .uppercase_left, .adjust = .@"-0.5" },
            .right = .{ .base = .center, .adjust = .@"0.5" },
        } } },
        .{ .op = .{ .stroke_diag = .{
            .a = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = ._1_slanty_bottom } },
            .b = .{ .x = .{ .base = .center, .adjust = .@"-0.5" }, .y = .{ .base = .uppercase_top } },
        } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .base = .center } } } },
        .{ .condition = ._1_has_bottom_bar, .op = .{ .clip = .{
            .left = .{ .base = .uppercase_left, .adjust = .@"-0.5" },
            .right = .{ .base = .uppercase_right, .adjust = .@"0.5" },
        } } },
        .{ .condition = ._1_has_bottom_bar, .op = .{ .stroke_horz = .{ .y = .{ .base = .baseline_stroke } } } },
    };
    pub const H = [_]Op{
        .{ .op = .{ .clip = .{
            .left = .{ .base = .uppercase_left, .adjust = .@"-0.5" },
            .right = .{ .base = .uppercase_right, .adjust = .@"0.5" },
            .top = .{ .base = .uppercase_top, .adjust = .@"-0.5" },
            .bottom = .{ .base = .baseline_stroke, .adjust = .@"0.5" },
        } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .base = .uppercase_left } } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .base = .uppercase_right } } } },
        .{ .op = .{ .stroke_horz = .{ .y = .{ .base = .uppercase_center } } } },
    };
    pub const i = [_]Op{
        .{ .op = .{ .clip = .{
            .left = .{ .base = .center, .adjust = .@"-0.5" },
            .right = .{ .base = .center, .adjust = .@"0.5" },
            .bottom = .{ .base = .baseline_stroke, .adjust = .@"0.5" },
        } } },
        .{ .op = .{ .stroke_dot = .{ .x = .{ .base = .center }, .y = .{ .base = .lowercase_dot } } } },
        .{ .op = .{ .clip = .{ .top = .{ .base = .lowercase_top, .adjust = .@"-0.5" } } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .base = .center } } } },
    };
    pub const N = [_]Op{
        .{ .op = .{ .clip = .{
            .left = .{ .base = .uppercase_left, .adjust = .@"-0.5" },
            .right = .{ .base = .uppercase_right, .adjust = .@"0.5" },
            .top = .{ .base = .uppercase_top, .adjust = .@"-0.5" },
            .bottom = .{ .base = .baseline_stroke, .adjust = .@"0.5" },
        } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .base = .uppercase_left } } } },
        .{ .op = .{ .stroke_vert = .{ .x = .{ .base = .uppercase_right } } } },
        .{ .op = .{ .stroke_diag = .{
            .a = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .uppercase_top, .adjust = .@"-0.5" } },
            .b = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .baseline_stroke, .adjust = .@"0.5" } },
        } } },
    };
    pub const Z = [_]Op{
        .{ .op = .{ .clip = .{
            .left = .{ .base = .uppercase_left, .adjust = .@"-0.5" },
            .right = .{ .base = .uppercase_right, .adjust = .@"0.5" },
            .top = .{ .base = .uppercase_top, .adjust = .@"-0.5" },
            .bottom = .{ .base = .baseline_stroke, .adjust = .@"0.5" },
        } } },
        .{ .op = .{ .stroke_horz = .{ .y = .{ .base = .uppercase_top } } } },
        .{ .op = .{ .stroke_horz = .{ .y = .{ .base = .baseline_stroke } } } },
        .{ .op = .{ .stroke_diag = .{
            .a = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .baseline_stroke, .adjust = .@"-0.5" } },
            .b = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_top, .adjust = .@"0.5" } },
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
