const std = @import("std");

pub const BoundaryBaseX = enum {
    /// center of uppercase left stroke
    uppercase_left,
    center,
    /// center of uppercase right stroke
    uppercase_right,
};
pub const BoundaryBaseY = enum {
    /// center of uppercase top
    uppercase_top,
    uppercase_top_quarter,
    lowercase_dot,
    _1_slanty_bottom,
    lowercase_top,
    uppercase_center,
    uppercase_bottom_quarter,
    /// center of a stroke where the bottom touches the baseline
    baseline_stroke,
};

pub const BetweenX = struct {
    base: BoundaryBaseX,
    ratio: f32,
};

pub const BetweenY = struct {
    base: BoundaryBaseY,
    ratio: f32,
};

pub const BoundaryX = struct {
    base: BoundaryBaseX,
    between: ?BetweenX = null,
    half_stroke_adjust: i8 = 0,
    pub fn format(
        self: BoundaryX,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}", .{@tagName(self.base)});
        if (self.between) |between| {
            try writer.print(" (between {})", .{between});
        }
        if (self.half_stroke_adjust != 0) {
            try writer.print(" adjust {}", .{self.half_stroke_adjust});
        }
    }
};
pub const BoundaryY = struct {
    base: BoundaryBaseY,
    between: ?BetweenY = null,
    half_stroke_adjust: i8 = 0,
};

// NOTE: not currently and not sure if it should be used or not yet
pub const StrokeBalance = enum {
    // the stroke is balanced on the design boundary and when faced with
    // a choice of which way to grow, will grow away from the center
    balanced_away_from_center,
};

// Disables draw commands that follow based on a vertical or horizontal boundary.
// Has no effect on draw commands that come before.
pub const Clip = struct {
    left: ?BoundaryX = null,
    right: ?BoundaryX = null,
    top: ?BoundaryY = null,
    bottom: ?BoundaryY = null,
    // The number of draw commands that follow to apply the clip to. If count is
    // 0 then it applies to all the following draw operations.
    count: u8 = 0,
};

pub const StrokeVert = struct {
    x: BoundaryX,
    // TODO: we might want this at some point if we want strokes
    //       that grow differently based on the stroke size
    //balance: StrokeBalance,
    pub fn format(
        self: StrokeVert,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{}", .{self.x});
    }
};
pub const StrokeHorz = struct {
    y: BoundaryY,
    // TODO: we might want this at some point if we want strokes
    //       that grow differently based on the stroke size
    //balance: StrokeBalance,
};

pub const BoundaryPoint = struct {
    x: BoundaryX,
    y: BoundaryY,
};

pub const StrokeDiag = struct {
    a: BoundaryPoint,
    b: BoundaryPoint,
};

const Point = struct {
    x: BoundaryX,
    y: BoundaryY,
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
        stroke_dot: BoundaryPoint,
        stroke_curve: StrokeCurve,
    },
    pub fn format(
        self: Op,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (self.condition) {
            .yes => {},
            .serif => try writer.writeAll("if(serif) "),
        }
        switch (self.op) {
            .todo => try writer.writeAll("todo"),
            .stroke_vert => |stroke_vert| try writer.print("stroke_vert {}", .{stroke_vert}),
            else => @panic("todo"),
        }
    }
};
