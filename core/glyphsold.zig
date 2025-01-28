const Op = @import("design.zig").Op;

pub const @"1" = [_]Op{
    .{ .clip = .{
        .top = .{ .value = .{ .base = .number_top, .adjust = -1 } },
        .bottom = .{ .value = .{ .base = .base, .adjust = 1 } },
    } },
    // slanty's line cap looks wrong, could fix if we have the ability to clip a diagonal
    .{ .clip = .{
        .count = 1,
        .left = .{ .value = .{ .base = .std_left, .adjust = -1 } },
        .right = .{ .value = .{ .base = .center, .adjust = 1 } },
    } },
    .{ .stroke_diag = .{
        .a = .{ .x = .{ .value = .{ .base = .std_left } }, .y = .{ .value = .{ .base = ._1_slanty_bottom } } },
        .b = .{ .x = .{ .value = .{ .base = .center, .adjust = -1 } }, .y = .{ .value = .{ .base = .number_top } } },
    } },
    .{ .stroke_vert = .{ .x = .{ .value = .{ .base = .center } } } },
    .{ .clip = .{
        .left = .{ .value = .{ .base = .std_left, .adjust = -1 } },
        .right = .{ .value = .{ .base = .std_right, .adjust = 1 } },
    } },
    .{ .branch = .{ .count = 1, .condition = .serif } },
    .{ .stroke_horz = .{ .y = .{ .value = .{ .base = .base } } } },
};
