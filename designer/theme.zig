const Rgb8 = @import("Rgb8.zig");

pub const bg: Color = .bg;
pub const fg: Color = .fg;
pub const button_bg: Color = .button_bg;
pub const grid_line: Color = .grid_line;

pub const Color = union(enum) {
    bg,
    fg,
    button_bg,

    grid_line,

    shade: u8,

    pub fn getRgb8(self: Color) Rgb8 {
        return switch (self) {
            .bg => .{ .r = 40, .g = 40, .b = 50 },
            .fg => .{ .r = 255, .g = 255, .b = 255 },
            .button_bg => .{ .r = 80, .g = 80, .b = 80 },
            .grid_line => .{ .r = 132, .g = 225, .b = 216 },
            .shade => |shade| .{ .r = shade, .g = shade, .b = shade },
        };
    }
};
