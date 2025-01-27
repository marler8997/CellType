const design = @import("design.zig");
const lex = @import("lex.zig");

const Op = design.Op;

pub const @"0" = O ++ [_]Op{
    .{ .op = .{ .clip = .{
        .count = 1,
        .left = .{ .base = .uppercase_left, .half_stroke_adjust = 1 },
        .right = .{ .base = .uppercase_right, .half_stroke_adjust = -1 },
    } } },
    // TODO: mark this stroke as "thinner", or maybe, we could make this a "half stroke" width?
    .{ .op = .{ .stroke_diag = .{
        .a = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .uppercase_top, .between = .{ .base = .base, .ratio = 0.70 } } },
        .b = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_top, .between = .{ .base = .base, .ratio = 0.30 } } },
    } } },
};
pub const @"1" = [_]Op{
    .{ .op = .{ .clip = .{
        .top = .{ .base = .uppercase_top, .half_stroke_adjust = -1 },
        .bottom = .{ .base = .base, .half_stroke_adjust = 1 },
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
    .{ .condition = .serif, .op = .{ .stroke_horz = .{ .y = .{ .base = .base } } } },
};

const @"2_ratio0" = 0.4;
const @"2_ratio1" = 0.6;
const @"2_ratio2" = 0.8;
pub const @"2" = [_]Op{
    .{ .op = .{ .clip = .{
        .left = .{ .base = .uppercase_left, .half_stroke_adjust = -1 },
        .right = .{ .base = .uppercase_right, .half_stroke_adjust = 1 },
        .top = .{ .base = .uppercase_top, .half_stroke_adjust = -1 },
        .bottom = .{ .base = .base, .half_stroke_adjust = 1 },
    } } },
    .{ .op = .{ .clip = .{
        .count = 1,
        .bottom = .{ .base = .uppercase_top_quarter },
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
            .control = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_top, .between = .{ .base = .base, .ratio = @"2_ratio0" } } },
            .end = .{ .x = .{ .base = .center }, .y = .{ .base = .uppercase_top, .between = .{ .base = .base, .ratio = @"2_ratio1" } } },
        },
    } },
    // middle left
    .{ .op = .{
        .stroke_curve = .{
            .start = .{ .x = .{ .base = .center }, .y = .{ .base = .uppercase_top, .between = .{ .base = .base, .ratio = @"2_ratio1" } } },
            .control = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .uppercase_top, .between = .{ .base = .base, .ratio = @"2_ratio2" } } },
            .end = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .base, .half_stroke_adjust = -1 } },
        },
    } },
    .{ .op = .{ .stroke_horz = .{ .y = .{ .base = .base } } } },
};

pub const @"3" = [_]Op{
    .{ .op = .{ .clip = .{
        .count = 1,
        .bottom = .{ .base = .uppercase_top_quarter },
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
    .{ .op = .{ .clip = .{
        .count = 2,
        .left = .{ .base = .center, .half_stroke_adjust = -1 },
    } } },
    // upper middle right
    .{ .op = .{
        .stroke_curve = .{
            .start = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_top_quarter } },
            .control = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_center } },
            .end = .{ .x = .{ .base = .center, .half_stroke_adjust = -1 }, .y = .{ .base = .uppercase_center } },
        },
    } },
    // lower middle right
    .{ .op = .{
        .stroke_curve = .{
            .start = .{ .x = .{ .base = .center, .half_stroke_adjust = -1 }, .y = .{ .base = .uppercase_center } },
            .control = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_center } },
            .end = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_bottom_quarter } },
        },
    } },
    // bottom right
    .{ .op = .{
        .stroke_curve = .{
            .start = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_bottom_quarter } },
            .control = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .base } },
            .end = .{ .x = .{ .base = .center }, .y = .{ .base = .base } },
        },
    } },
    .{ .op = .{ .clip = .{
        .count = 1,
        .top = .{ .base = .uppercase_bottom_quarter },
    } } },
    // bottom left
    .{ .op = .{
        .stroke_curve = .{
            .start = .{ .x = .{ .base = .center }, .y = .{ .base = .base } },
            .control = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .base } },
            .end = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .uppercase_bottom_quarter } },
        },
    } },
};

pub const H = lex.parseOps(
    \\clip
    \\    left=uppercase_left-1 right=uppercase_right+1
    \\    top=uppercase_top-1 bottom=base+1
    \\;
    \\stroke vert uppercase_left;
    \\stroke vert uppercase_right;
    \\stroke horz uppercase_center;
);
pub const L = lex.parseOps(
    \\clip left=uppercase_left-1 right=uppercase_right+1 top=uppercase_top-1 bottom=base+1;
    \\stroke vert uppercase_left;
    \\stroke horz base;
);
pub const T = lex.parseOps(
    \\clip left=uppercase_left-1 right=uppercase_right+1 top=uppercase_top-1 bottom=base+1;
    \\stroke vert center;
    \\stroke horz uppercase_top;
);

pub const i = lex.parseOps(
    \\clip bottom=base+1;
    \\stroke dot center lowercase_dot;
    \\clip top=lowercase_top-1;
    \\stroke vert center;
);

pub const N = [_]Op{
    .{ .op = .{ .clip = .{
        .left = .{ .base = .uppercase_left, .half_stroke_adjust = -1 },
        .right = .{ .base = .uppercase_right, .half_stroke_adjust = 1 },
        .top = .{ .base = .uppercase_top, .half_stroke_adjust = -1 },
        .bottom = .{ .base = .base, .half_stroke_adjust = 1 },
    } } },
    .{ .op = .{ .stroke_vert = .{ .x = .{ .base = .uppercase_left } } } },
    .{ .op = .{ .stroke_vert = .{ .x = .{ .base = .uppercase_right } } } },
    .{ .op = .{ .stroke_diag = .{
        .a = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .uppercase_top, .half_stroke_adjust = -1 } },
        .b = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .base, .half_stroke_adjust = 1 } },
    } } },
};
pub const Z = [_]Op{
    .{ .op = .{ .clip = .{
        .left = .{ .base = .uppercase_left, .half_stroke_adjust = -1 },
        .right = .{ .base = .uppercase_right, .half_stroke_adjust = 1 },
        .top = .{ .base = .uppercase_top, .half_stroke_adjust = -1 },
        .bottom = .{ .base = .base, .half_stroke_adjust = 1 },
    } } },
    .{ .op = .{ .stroke_horz = .{ .y = .{ .base = .uppercase_top } } } },
    .{ .op = .{ .stroke_horz = .{ .y = .{ .base = .base } } } },
    .{ .op = .{ .stroke_diag = .{
        .a = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .base, .half_stroke_adjust = -1 } },
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
            .control = .{ .x = .{ .base = .uppercase_left }, .y = .{ .base = .base } },
            .end = .{ .x = .{ .base = .center }, .y = .{ .base = .base } },
        },
    } },
    .{ .op = .{
        .stroke_curve = .{
            .start = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .uppercase_center } },
            .control = .{ .x = .{ .base = .uppercase_right }, .y = .{ .base = .base } },
            .end = .{ .x = .{ .base = .center }, .y = .{ .base = .base } },
        },
    } },
};
