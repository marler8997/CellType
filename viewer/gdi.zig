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

pub fn paint(
    hdc: win32.HDC,
    dpi: u32,
    client_size: win32.SIZE,
    font_weight: f32,
    graphemes: []const u8,
    cache: *ObjectCache,
) void {
    // NOTE: clearing the entire window first causes flickering
    //       see https://catch22.net/tuts/win32/flicker-free-drawing/
    //       TLDR; don't draw over the same pixel twice
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
        .{ .x = 50, .y = 20 },
        .{ .x = 100, .y = 260 },
        .{ .x = 100, .y = 100 },
    };
    const max_size = blk: {
        var max: XY(u16) = .{ .x = 0, .y = 0 };
        for (sizes) |size| {
            max.x = @max(max.x, size.x);
            max.y = @max(max.y, size.y);
        }
        break :blk max;
    };
    const bmp = cache.getBitmap(hdc, max_size);
    const bmp_stride = (bmp.size.x + 3) & ~@as(u32, 3);

    const mem_hdc = win32.CreateCompatibleDC(hdc);
    defer win32.deleteDc(mem_hdc);

    const old_bmp = win32.SelectObject(mem_hdc, @ptrCast(bmp.section));
    defer _ = win32.SelectObject(mem_hdc, old_bmp);

    const margin = win32.scaleDpi(i32, 10, dpi);
    const spacing: XY(i32) = .{
        .x = 1,
        .y = win32.scaleDpi(i32, 5, dpi),
    };
    var y: i32 = margin;

    const bg_brush = cache.getBrush(.bg);
    win32.fillRect(hdc, .{ .left = 0, .top = 0, .right = client_size.cx, .bottom = y }, bg_brush);
    win32.fillRect(hdc, .{ .left = 0, .top = margin, .right = margin, .bottom = client_size.cy }, bg_brush);
    for (sizes) |size| {
        var x: i32 = margin;
        var grapheme_offset: usize = 0;
        while (grapheme_offset < graphemes.len) {
            const config: celltype.Config = .{
                .serif = true,
            };
            const stroke_width = blk: {
                // good for testing
                //if (true) break :blk 1;
                break :blk celltype.calcStrokeWidth(u16, size.x, size.y, font_weight);
            };
            grapheme_offset += celltype.render(
                &config,
                u16,
                size.x,
                size.y,
                stroke_width,
                bmp.grayscale,
                bmp_stride,
                graphemes[grapheme_offset..],
                .{ .output_precleared = false },
            ) catch |err| std.debug.panic("render failed with {s}", .{@errorName(err)});
            if (0 == win32.BitBlt(
                hdc,
                x,
                y,
                size.x,
                size.y,
                mem_hdc,
                0,
                0,
                win32.SRCCOPY,
            )) win32.panicWin32("BitGlt", win32.GetLastError());

            x += @as(i32, @intCast(size.x));
            win32.fillRect(hdc, .{ .left = x, .top = y, .right = x + spacing.x, .bottom = y + size.y }, bg_brush);
            x += spacing.x;
        }
        win32.fillRect(hdc, .{ .left = x, .top = y, .right = client_size.cx, .bottom = y + size.y }, bg_brush);
        y += size.y;
        win32.fillRect(hdc, .{ .left = margin, .top = y, .right = client_size.cx, .bottom = y + spacing.y }, bg_brush);
        y += spacing.y;
    }
    win32.fillRect(hdc, .{ .left = 0, .top = y, .right = client_size.cx, .bottom = client_size.cy }, bg_brush);
}
