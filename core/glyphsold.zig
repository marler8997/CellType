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
