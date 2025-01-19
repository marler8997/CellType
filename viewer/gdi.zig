const std = @import("std");
const win32 = @import("win32").everything;

const codefont = @import("codefont");

const Rgb8 = @import("Rgb8.zig");
const XY = @import("xy.zig").XY;

const Brush = enum {
    bg,
};

const theme = struct {
    const bg: Rgb8 = .{ .r = 40, .g = 40, .b = 50 };
    const fg: Rgb8 = .{ .r = 255, .g = 255, .b = 255 };
};

pub const ObjectCache = struct {
    brush_bg: ?win32.HBRUSH = null,
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
            brush_ref.* = win32.CreateSolidBrush(colorrefFromRgb(rgb)) orelse fatalWin32(
                "CreateSolidBrush",
                win32.GetLastError(),
            );
        }
        return brush_ref.*.?;
    }
};

fn colorrefFromRgb(rgb: Rgb8) u32 {
    return (@as(u32, rgb.r) << 0) | (@as(u32, rgb.g) << 8) | (@as(u32, rgb.b) << 16);
}

pub fn paint(
    hdc: win32.HDC,
    dpi: u32,
    client_size: XY(i32),
    cache: *ObjectCache,
) void {
    // NOTE: clearing the entire window first causes flickering
    //       see https://catch22.net/tuts/win32/flicker-free-drawing/
    //       TLDR; don't draw over the same pixel twice
    fillRect(hdc, .{
        .left = 0,
        .top = 0,
        .right = client_size.x,
        .bottom = client_size.y,
    }, cache.getBrush(.bg));
    _ = win32.SetBkColor(hdc, colorrefFromRgb(theme.bg));
    _ = win32.SetTextColor(hdc, colorrefFromRgb(theme.fg));

    const graphemes = [_][]const u8{ "H", "i", "1", "N", "Z" };

    const sizes = [_]XY(u16){
        .{ .x = 1, .y = 12 },
        .{ .x = 2, .y = 16 },
        .{ .x = 3, .y = 16 },
        .{ .x = 4, .y = 16 },
        .{ .x = 5, .y = 20 },
        .{ .x = 6, .y = 20 },
        .{ .x = 7, .y = 20 },
        .{ .x = 8, .y = 20 },
        .{ .x = 9, .y = 20 },
        .{ .x = 10, .y = 20 },
        .{ .x = 11, .y = 26 },
        .{ .x = 20, .y = 25 },
        .{ .x = 21, .y = 25 },
        .{ .x = 50, .y = 70 },
        .{ .x = 100, .y = 260 },
        .{ .x = 100, .y = 100 },
    };

    const margin = win32.scaleDpi(i32, 10, dpi);
    const spacing: XY(i32) = .{
        .x = 1,
        .y = win32.scaleDpi(i32, 5, dpi),
    };
    var y: i32 = margin;

    for (sizes) |size| {
        var x: i32 = margin;
        for (graphemes) |grapheme| {
            drawGrapheme(hdc, cache, .{ .x = x, .y = y }, size, grapheme);
            x += @as(i32, @intCast(size.x)) + spacing.x;
        }
        y += size.y + spacing.y;
    }
}

fn drawGrapheme(
    hdc: win32.HDC,
    cache: *ObjectCache,
    pos: XY(i32),
    size: XY(u16),
    grapheme: []const u8,
) void {
    _ = cache;

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

    // Create DIB Section
    var maybe_bits: ?*anyopaque = undefined;
    const bmp_section = win32.CreateDIBSection(
        hdc,
        @ptrCast(&bmi),
        win32.DIB_RGB_COLORS,
        &maybe_bits,
        null,
        0,
    ) orelse fatalWin32("CreateDIBSection", win32.GetLastError());
    defer deleteObject(bmp_section);

    const stride = (size.x + 3) & ~@as(u32, 3);

    // no need to clear since we just created the bitmap
    //codefont.clear();
    codefont.render(
        u16,
        size.x,
        size.y,
        @ptrCast(maybe_bits orelse @panic("possible?")),
        stride,
        grapheme,
    );

    const mem_dc = win32.CreateCompatibleDC(hdc);
    defer deleteDc(mem_dc);

    const old_bmp = win32.SelectObject(mem_dc, @ptrCast(bmp_section));
    defer _ = win32.SelectObject(mem_dc, old_bmp);

    // Copy to screen
    if (0 == win32.BitBlt(
        hdc,
        pos.x,
        pos.y,
        size.x,
        size.y,
        mem_dc,
        0,
        0,
        win32.SRCCOPY,
    )) fatalWin32("BitGlt", win32.GetLastError());
}

fn fillRect(hdc: win32.HDC, rect: win32.RECT, brush: win32.HBRUSH) void {
    if (0 == win32.FillRect(hdc, &rect, brush)) fatalWin32(
        "FillRect",
        win32.GetLastError(),
    );
}

pub fn deleteObject(obj: ?win32.HGDIOBJ) void {
    if (0 == win32.DeleteObject(obj)) fatalWin32("DeleteObject", win32.GetLastError());
}
pub fn deleteDc(obj: win32.HDC) void {
    if (0 == win32.DeleteDC(obj)) fatalWin32("DeleteDC", win32.GetLastError());
}

pub fn fatalWin32(what: []const u8, err: win32.WIN32_ERROR) noreturn {
    std.debug.panic("{s} failed with {}", .{ what, err.fmt() });
}
