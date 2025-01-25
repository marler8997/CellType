const Rgb8 = @import("Rgb8.zig");

pub const Color = enum {
    bg,
    fg,
    button_bg,

    grid_line,

    black,
    white,

    pub fn getRgb8(self: Color) Rgb8 {
        return switch (self) {
            .bg => .{ .r = 40, .g = 40, .b = 50 },
            .fg => .{ .r = 255, .g = 255, .b = 255 },
            .button_bg => .{ .r = 80, .g = 80, .b = 80 },
            .grid_line => .{ .r = 132, .g = 225, .b = 216 },
            .black => .{ .r = 0, .g = 0, .b = 0 },
            .white => .{ .r = 255, .g = 255, .b = 255 },
        };
    }
};
