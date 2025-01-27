const Rgba8 = @import("Rgba8.zig");

pub const bg: Color = .bg;
pub const fg: Color = .fg;
pub const button_bg: Color = .button_bg;
pub const highlight: Color = .highlight;
pub const grid_line: Color = .grid_line;

pub const Color = union(enum) {
    bg,
    fg,
    button_bg,
    highlight,

    grid_line,

    shade: u8,

    overlay_bg,

    pub fn getRgba8(self: Color) Rgba8 {
        return switch (self) {
            .bg => .{ .r = 40, .g = 40, .b = 50, .a = 255 },
            .fg => .{ .r = 255, .g = 255, .b = 255, .a = 255 },
            .button_bg => .{ .r = 80, .g = 80, .b = 80, .a = 255 },
            .highlight => .{ .r = 200, .g = 255, .b = 255, .a = 255 },
            .grid_line => .{ .r = 132, .g = 225, .b = 216, .a = 255 },
            .shade => |shade| .{ .r = shade, .g = shade, .b = shade, .a = 255 },
            .overlay_bg => .{ .r = 0, .g = 0, .b = 0, .a = 230 },
        };
    }
};
