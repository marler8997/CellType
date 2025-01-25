const std = @import("std");
const win32 = @import("win32").everything;

const celltype = @import("celltype");

const Rgb8 = @import("Rgb8.zig");
const XY = @import("xy.zig").XY;

const Brush = enum {
    bg,
};

const theme = struct {
    const bg: Rgb8 = .{ .r = 40, .g = 40, .b = 50 };
    const fg: Rgb8 = .{ .r = 255, .g = 255, .b = 255 };
};

const Bitmap = struct {
    size: XY(u16),
    section: win32.HBITMAP,
    grayscale: [*]u8,
};

pub const ObjectCache = struct {
    brush_bg: ?win32.HBRUSH = null,
    bmp: ?Bitmap = null,
    fn getBrushRef(self: *ObjectCache, brush: Brush) *?win32.HBRUSH {
        return switch (brush) {
            .bg => &self.brush_bg,
        };
    }
    pub fn getBrush(self: *ObjectCache, brush: Brush) win32.HBRUSH {
        const brush_ref = self.getBrushRef(brush);
        if (brush_ref.* == null) {
            const rgb = switch (brush) {
                .bg => theme.bg,
            };
            brush_ref.* = win32.CreateSolidBrush(colorrefFromRgb(rgb)) orelse win32.panicWin32(
                "CreateSolidBrush",
                win32.GetLastError(),
            );
        }
        return brush_ref.*.?;
    }
    pub fn getBitmap(self: *ObjectCache, hdc: win32.HDC, size: XY(u16)) Bitmap {
        if (self.bmp) |cached| {
            if (cached.size.x >= size.x and cached.size.y >= size.y)
                return cached;
            win32.deleteObject(cached.section);
            self.bmp = null;
        }

        const BmpInfo = extern struct {
            header: win32.BITMAPINFOHEADER,
            colors: [256]win32.RGBQUAD,
        };
        var bmi: BmpInfo = .{
            .header = .{
                .biSize = @sizeOf(win32.BITMAPINFOHEADER),
                .biWidth = @intCast(size.x),
                .biHeight = -@as(i32, @intCast(size.y)), // Negative for top-down
                .biPlanes = 1,
                .biBitCount = 8,
                .biCompression = win32.BI_RGB,
                .biSizeImage = 0,
                .biXPelsPerMeter = 0,
                .biYPelsPerMeter = 0,
                .biClrUsed = 0,
                .biClrImportant = 0,
            },
            .colors = undefined,
        };
        for (&bmi.colors, 0..) |*color, i| {
            color.* = .{
                .rgbBlue = @intCast(i),
                .rgbGreen = @intCast(i),
                .rgbRed = @intCast(i),
                .rgbReserved = undefined,
            };
        }

        var maybe_bits: ?*anyopaque = undefined;
        const bmp_section = win32.CreateDIBSection(
            hdc,
            @ptrCast(&bmi),
            win32.DIB_RGB_COLORS,
            &maybe_bits,
            null,
            0,
        ) orelse win32.panicWin32("CreateDIBSection", win32.GetLastError());
        errdefer win32.deleteObject(bmp_section);

        self.bmp = .{
            .size = size,
            .section = bmp_section,
            .grayscale = @ptrCast(maybe_bits orelse @panic("possible?")),
        };
        return self.bmp.?;
    }
};

fn colorrefFromRgb(rgb: Rgb8) u32 {
    return (@as(u32, rgb.r) << 0) | (@as(u32, rgb.g) << 8) | (@as(u32, rgb.b) << 16);
}
