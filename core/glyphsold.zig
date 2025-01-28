const Op = @import("design.zig").Op;

pub const @"1" = [_]Op{
    .{ .op = .{ .clip = .{
        .top = .{ .value = .{ .base = .number_top, .adjust = -1 } },
        .bottom = .{ .value = .{ .base = .base, .adjust = 1 } },
    } } },
    // slanty's line cap looks wrong, could fix if we have the ability to clip a diagonal
    .{ .op = .{ .clip = .{
        .count = 1,
        .left = .{ .value = .{ .base = .std_left, .adjust = -1 } },
        .right = .{ .value = .{ .base = .center, .adjust = 1 } },
    } } },
    .{ .op = .{ .stroke_diag = .{
        .a = .{ .x = .{ .value = .{ .base = .std_left } }, .y = .{ .value = .{ .base = ._1_slanty_bottom } } },
        .b = .{ .x = .{ .value = .{ .base = .center, .adjust = -1 } }, .y = .{ .value = .{ .base = .number_top } } },
    } } },
    .{ .op = .{ .stroke_vert = .{ .x = .{ .value = .{ .base = .center } } } } },
    .{ .op = .{ .clip = .{
        .left = .{ .value = .{ .base = .std_left, .adjust = -1 } },
        .right = .{ .value = .{ .base = .std_right, .adjust = 1 } },
    } } },
    .{ .condition = .serif, .op = .{ .stroke_horz = .{ .y = .{ .value = .{ .base = .base } } } } },
};

pub const @"3" = [_]Op{
    .{ .op = .{ .clip = .{
        .count = 1,
        .bottom = .{ .value = .{ .base = .number_top_quarter } },
    } } },
    // top left
    .{ .op = .{
        .stroke_curve = .{
            .start = .{ .x = .{ .value = .{ .base = .std_left } }, .y = .{ .value = .{ .base = .number_top_quarter } } },
            .control = .{ .x = .{ .value = .{ .base = .std_left } }, .y = .{ .value = .{ .base = .number_top } } },
            .end = .{ .x = .{ .value = .{ .base = .center } }, .y = .{ .value = .{ .base = .number_top } } },
        },
    } },
    // top right
    .{ .op = .{
        .stroke_curve = .{
            .start = .{ .x = .{ .value = .{ .base = .center } }, .y = .{ .value = .{ .base = .number_top } } },
            .control = .{ .x = .{ .value = .{ .base = .std_right } }, .y = .{ .value = .{ .base = .number_top } } },
            .end = .{ .x = .{ .value = .{ .base = .std_right } }, .y = .{ .value = .{ .base = .number_top_quarter } } },
        },
    } },
    .{ .op = .{ .clip = .{
        .count = 2,
        .left = .{ .value = .{ .base = .center, .adjust = -1 } },
    } } },
    // upper middle right
    .{ .op = .{
        .stroke_curve = .{
            .start = .{ .x = .{ .value = .{ .base = .std_right } }, .y = .{ .value = .{ .base = .number_top_quarter } } },
            .control = .{ .x = .{ .value = .{ .base = .std_right } }, .y = .{ .value = .{ .base = .uppercase_center } } },
            .end = .{ .x = .{ .value = .{ .base = .center, .adjust = -1 } }, .y = .{ .value = .{ .base = .uppercase_center } } },
        },
    } },
    // lower middle right
    .{ .op = .{
        .stroke_curve = .{
            .start = .{ .x = .{ .value = .{ .base = .center, .adjust = -1 } }, .y = .{ .value = .{ .base = .uppercase_center } } },
            .control = .{ .x = .{ .value = .{ .base = .std_right } }, .y = .{ .value = .{ .base = .uppercase_center } } },
            .end = .{ .x = .{ .value = .{ .base = .std_right } }, .y = .{ .value = .{ .base = .uppercase_bottom_quarter } } },
        },
    } },
    // bottom right
    .{ .op = .{
        .stroke_curve = .{
            .start = .{ .x = .{ .value = .{ .base = .std_right } }, .y = .{ .value = .{ .base = .uppercase_bottom_quarter } } },
            .control = .{ .x = .{ .value = .{ .base = .std_right } }, .y = .{ .value = .{ .base = .base } } },
            .end = .{ .x = .{ .value = .{ .base = .center } }, .y = .{ .value = .{ .base = .base } } },
        },
    } },
    .{ .op = .{ .clip = .{
        .count = 1,
        .top = .{ .value = .{ .base = .uppercase_bottom_quarter } },
    } } },
    // bottom left
    .{ .op = .{
        .stroke_curve = .{
            .start = .{ .x = .{ .value = .{ .base = .center } }, .y = .{ .value = .{ .base = .base } } },
            .control = .{ .x = .{ .value = .{ .base = .std_left } }, .y = .{ .value = .{ .base = .base } } },
            .end = .{ .x = .{ .value = .{ .base = .std_left } }, .y = .{ .value = .{ .base = .uppercase_bottom_quarter } } },
        },
    } },
};
