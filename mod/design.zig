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
    pub fn format(
        self: BoundaryY,
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
    pub fn format(
        self: Clip,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        var sep: []const u8 = "";
        if (self.left) |left| {
            try writer.print("{s}left={}", .{ sep, left });
            sep = " ";
        }
        if (self.right) |right| {
            try writer.print("{s}right={}", .{ sep, right });
            sep = " ";
        }
        if (self.top) |top| {
            try writer.print("{s}top={}", .{ sep, top });
            sep = " ";
        }
        if (self.bottom) |bottom| {
            try writer.print("{s}bottom={}", .{ sep, bottom });
            sep = " ";
        }
        if (self.count != 0) {
            try writer.print("{s}count={}", .{ sep, self.count });
            sep = " ";
        }
    }
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
    pub fn format(
        self: StrokeHorz,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{}", .{self.y});
    }
};

pub const BoundaryPoint = struct {
    x: BoundaryX,
    y: BoundaryY,
    pub fn format(
        self: BoundaryPoint,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{},{}", .{ self.x, self.y });
    }
};

pub const StrokeDiag = struct {
    a: BoundaryPoint,
    b: BoundaryPoint,
    pub fn format(
        self: StrokeDiag,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{} {}", .{ self.a, self.b });
    }
};

pub const StrokeCurve = struct {
    start: BoundaryPoint,
    control: BoundaryPoint,
    end: BoundaryPoint,
    pub fn format(
        self: StrokeCurve,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{} {} {}", .{ self.start, self.control, self.end });
    }
};

pub const Condition = enum {
    yes,
    serif,
};

pub const Op2Tag = enum {
    todo,
    clip,
    stroke_vert,
    stroke_horz,
    stroke_diag,
    stroke_dot,
    stroke_curve,
};
pub const op2_count = std.meta.fields(Op2Tag).len;

pub const Op2 = union(Op2Tag) {
    todo: void,
    clip: Clip,
    stroke_vert: StrokeVert,
    stroke_horz: StrokeHorz,
    stroke_diag: StrokeDiag,
    stroke_dot: BoundaryPoint,
    stroke_curve: StrokeCurve,
};

pub const Op = struct {
    condition: Condition = .yes,
    op: Op2,
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
            .clip => |c| try writer.print("clip {}", .{c}),
            .stroke_vert => |s| try writer.print("stroke vert {}", .{s}),
            .stroke_horz => |s| try writer.print("stroke horz {}", .{s}),
            .stroke_diag => |s| try writer.print("stroke diag {}", .{s}),
            .stroke_dot => |s| try writer.print("stroke dot {}", .{s}),
            .stroke_curve => |s| try writer.print("stroke curve {}", .{s}),
        }
    }
};

pub const Dimension = enum { x, y };
pub fn BoundaryBase(dimension: Dimension) type {
    return switch (dimension) {
        .x => BoundaryBaseX,
        .y => BoundaryBaseY,
    };
}
pub fn Boundary(dimension: Dimension) type {
    return switch (dimension) {
        .x => BoundaryX,
        .y => BoundaryY,
    };
}
pub fn Between(dimension: Dimension) type {
    return switch (dimension) {
        .x => BetweenX,
        .y => BetweenY,
    };
}
