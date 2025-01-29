const std = @import("std");

pub const BoundaryBaseX = enum {
    leftmost,
    /// center of standard left stroke
    std_left,
    center,
    /// center of standard right stroke
    std_right,
    rightmost,
};
pub const BoundaryBaseY = enum {
    number_top,
    number_top_quarter,
    number_center,
    number_bottom_quarter,

    uppercase_top,
    uppercase_top_quarter,
    uppercase_center,
    uppercase_bottom_quarter,

    lowercase_dot,
    lowercase_top,
    lowercase_center,

    /// center of a stroke where the bottom touches the baseline
    base,

    bottom_edge,
};

pub const AdjustableBoundaryX = struct {
    base: BoundaryBaseX,
    adjust: i8 = 0,
    pub fn format(
        self: AdjustableBoundaryX,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.writeAll(@tagName(self.base));
        if (self.adjust != 0) {
            const prefix: u8 = if (self.adjust > 0) '+' else '-';
            try writer.print("{c}{}", .{ prefix, self.adjust });
        }
    }
};
pub const AdjustableBoundaryY = struct {
    base: BoundaryBaseY,
    adjust: i8 = 0,
    pub fn format(
        self: AdjustableBoundaryY,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.writeAll(@tagName(self.base));
        if (self.adjust != 0) {
            const prefix: u8 = if (self.adjust > 0) '+' else '-';
            try writer.print("{c}{}", .{ prefix, self.adjust });
        }
    }
};

pub const BetweenX = struct {
    to: AdjustableBoundaryX,
    ratio: f32,
    adjust: i8 = 0,
};
pub const BetweenY = struct {
    to: AdjustableBoundaryY,
    ratio: f32,
    adjust: i8 = 0,
};

pub const BoundaryX = struct {
    value: AdjustableBoundaryX,
    between: ?BetweenX = null,
    pub fn format(
        self: BoundaryX,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        if (self.between) |_| {
            try writer.writeAll("between(");
        }
        try writer.print("{}", .{self.value});
        if (self.between) |between| {
            try writer.print(" {})", .{between});
        }
    }
};
pub const BoundaryY = struct {
    value: AdjustableBoundaryY,
    between: ?BetweenY = null,
    pub fn format(
        self: BoundaryY,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        if (self.between) |_| {
            try writer.writeAll("between(");
        }
        try writer.print("{}", .{self.value});
        if (self.between) |between| {
            try writer.print(" {})", .{between});
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
    serif,
};
pub const Branch = struct {
    count: u8,
    condition: Condition,
    pub fn format(
        self: Branch,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{} {s}", .{ self.count, @tagName(self.condition) });
    }
};

pub const OpTag = enum {
    branch,
    todo,
    clip,
    stroke_vert,
    stroke_horz,
    stroke_diag,
    stroke_dot,
    stroke_curve,
};
pub const op_count = std.meta.fields(OpTag).len;

pub const Op = union(OpTag) {
    branch: Branch,
    todo: void,
    clip: Clip,
    stroke_vert: StrokeVert,
    stroke_horz: StrokeHorz,
    stroke_diag: StrokeDiag,
    stroke_dot: BoundaryPoint,
    stroke_curve: StrokeCurve,

    pub fn format(
        self: Op,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .branch => |b| try writer.print("condition {}", .{b}),
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
pub fn AdjustableBoundary(dimension: Dimension) type {
    return switch (dimension) {
        .x => AdjustableBoundaryX,
        .y => AdjustableBoundaryY,
    };
}
pub fn Boundary(dimension: Dimension) type {
    return switch (dimension) {
        .x => BoundaryX,
        .y => BoundaryY,
    };
}
