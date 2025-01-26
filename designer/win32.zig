const builtin = @import("builtin");
const std = @import("std");

const win32 = @import("win32").everything;

const app = @import("app.zig");

const Rgb8 = @import("Rgb8.zig");
const theme = @import("theme.zig");
const XY = @import("xy.zig").XY;

const global = struct {
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // TODO: remove all references to dwrite when our text rendering is somewhat ready
    var dwrite_factory: *win32.IDWriteFactory = undefined;
    var d2d_factory: *win32.ID2D1Factory = undefined;
    var hwnd: win32.HWND = undefined;
    var wm_char_high_surrogate: u16 = 0;

    var maybe_d2d: ?D2d = null;
    var bmp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var bmp: ?RenderTarget.Bitmap = null;
};

pub const std_options: std.Options = .{
    .log_level = .info,
    .logFn = log,
};
const input_log = std.log.scoped(.input);
fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime fmt: []const u8,
    args: anytype,
) void {
    // if (scope == .input) return;
    std.log.defaultLog(level, scope, fmt, args);
}

pub const panic = win32.messageBoxThenPanic(.{
    .title = "CellType Designer Panic",
});

pub fn invalidate() void {
    win32.invalidateHwnd(global.hwnd);
}
pub fn beep() void {
    _ = win32.MessageBeep(@bitCast(win32.MB_ICONWARNING));
}

pub fn main() !u8 {
    _ = win32.AttachConsole(win32.ATTACH_PARENT_PROCESS);

    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const arena = arena_instance.allocator();

    var window_left: i32 = win32.CW_USEDEFAULT;
    var window_size: XY(i32) = .{ .x = win32.CW_USEDEFAULT, .y = win32.CW_USEDEFAULT };

    {
        const cmdline = try std.process.argsAlloc(arena);
        // no need to free
        var index: usize = 1;
        while (index < cmdline.len) {
            const arg = cmdline[index];
            index += 1;
            if (std.mem.eql(u8, arg, "--design")) {
                app.exec(.design_mode);
            } else if (std.mem.eql(u8, arg, "--text")) {
                if (index >= cmdline.len) @panic("--text requires an argument");
                const text = cmdline[index];
                index += 1;
                app.global.text = app.TextArray.fromSlice(text) catch std.debug.panic(
                    "--text ({} bytes) too long (max {})",
                    .{ text.len, app.global.text.capacity() },
                );
            } else if (std.mem.eql(u8, arg, "--left")) {
                if (index >= cmdline.len) @panic("--left requires an argument");
                const str = cmdline[index];
                index += 1;
                window_left = std.fmt.parseInt(i32, str, 10) catch std.debug.panic(
                    "--left argument '{s}' is not a number",
                    .{str},
                );
            } else if (std.mem.eql(u8, arg, "--size")) {
                if (index >= cmdline.len) @panic("--size requires an argument (i.e. 800x1000)");
                const str = cmdline[index];
                index += 1;
                const first_end = std.mem.indexOfScalar(u8, str, 'x') orelse str.len;
                window_size.x = std.fmt.parseInt(u31, str[0..first_end], 10) catch std.debug.panic(
                    "--size argument '{s}' invalid",
                    .{str},
                );
                window_size.y = if (first_end < str.len) std.fmt.parseInt(u31, str[first_end + 1 ..], 10) catch std.debug.panic(
                    "--size argument '{s}' invalid",
                    .{str},
                ) else window_size.x;
            } else std.debug.panic("unknown cmdline option '{s}'", .{arg});
        }
    }

    {
        const options: win32.D2D1_FACTORY_OPTIONS = .{
            .debugLevel = switch (builtin.mode) {
                .Debug => .WARNING,
                else => .NONE,
            },
        };
        const hr = win32.D2D1CreateFactory(
            .SINGLE_THREADED,
            win32.IID_ID2D1Factory,
            &options,
            @ptrCast(&global.d2d_factory),
        );
        if (hr < 0) return win32.panicHresult("D2D1CreateFactory", hr);
    }
    defer _ = global.d2d_factory.IUnknown.Release();

    {
        const hr = win32.DWriteCreateFactory(
            win32.DWRITE_FACTORY_TYPE_SHARED,
            win32.IID_IDWriteFactory,
            @ptrCast(&global.dwrite_factory),
        );
        if (hr < 0) win32.panicHresult("DWriteCreateFactory", hr);
    }

    const CLASS_NAME = win32.L("CellTypeDesigner");
    {
        const wc = win32.WNDCLASSEXW{
            .cbSize = @sizeOf(win32.WNDCLASSEXW),
            .style = .{ .HREDRAW = 1, .VREDRAW = 1 },
            .lpfnWndProc = WndProc,
            .cbClsExtra = 0,
            .cbWndExtra = 0,
            .hInstance = win32.GetModuleHandleW(null),
            .hIcon = null,
            .hCursor = win32.LoadCursorW(null, win32.IDC_ARROW),
            .hbrBackground = null,
            .lpszMenuName = null,
            .lpszClassName = CLASS_NAME,
            .hIconSm = null,
        };
        if (0 == win32.RegisterClassExW(&wc)) win32.panicWin32("RegisterClass", win32.GetLastError());
    }

    global.hwnd = win32.CreateWindowExW(
        .{},
        CLASS_NAME,
        win32.L("CellType Designer"),
        win32.WS_OVERLAPPEDWINDOW,
        // NOTE: can't mix CW_USEDEFAULT and non-default sizes
        window_left,
        if (window_left == win32.CW_USEDEFAULT) win32.CW_USEDEFAULT else 0,
        window_size.x,
        window_size.y,
        null, // Parent window
        null, // Menu
        win32.GetModuleHandleW(null), // Instance handle
        null, // Additional application data
    ) orelse {
        std.log.err("CreateWindow failed with {}", .{win32.GetLastError()});
        std.posix.exit(0xff);
    };

    {
        // TODO: maybe use DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1 if applicable
        // see https://stackoverflow.com/questions/57124243/winforms-dark-title-bar-on-windows-10
        //int attribute = DWMWA_USE_IMMERSIVE_DARK_MODE;
        const dark_value: c_int = 1;
        const hr = win32.DwmSetWindowAttribute(
            global.hwnd,
            win32.DWMWA_USE_IMMERSIVE_DARK_MODE,
            &dark_value,
            @sizeOf(@TypeOf(dark_value)),
        );
        if (hr < 0) std.log.warn(
            "DwmSetWindowAttribute for dark={} failed, error={}",
            .{ dark_value, win32.GetLastError() },
        );
    }

    _ = win32.ShowWindow(global.hwnd, win32.SW_SHOW);

    const wparam = blk: {
        while (true) {
            var msg: win32.MSG = undefined;
            const result = win32.GetMessageW(&msg, null, 0, 0);
            if (result < 0) win32.panicWin32("GetMessage", win32.GetLastError());
            if (result == 0) break :blk msg.wParam;
            _ = win32.TranslateMessage(&msg);
            _ = win32.DispatchMessageW(&msg);
        }
    };

    if (global.maybe_d2d) |*d2d| d2d.deinit();

    if (std.math.cast(u8, wparam)) |c| {
        std.log.info("quit {}", .{c});
        return c;
    }
    std.log.info("quit {} (0xff)", .{wparam});
    return 0xff;
}

fn WndProc(
    hwnd: win32.HWND,
    msg: u32,
    wparam: win32.WPARAM,
    lparam: win32.LPARAM,
) callconv(std.os.windows.WINAPI) win32.LRESULT {
    switch (msg) {
        win32.WM_LBUTTONDOWN => {
            const p = win32.pointFromLparam(lparam);
            app.mouseButton(.left, .down, .{ .x = @intCast(p.x), .y = @intCast(p.y) });
            return 0;
        },
        win32.WM_LBUTTONUP => {
            const p = win32.pointFromLparam(lparam);
            app.mouseButton(.left, .up, .{ .x = p.x, .y = p.y });
            return 0;
        },
        win32.WM_SYSKEYDOWN => {
            input_log.info("WM_SYSKEYDOWN {}", .{wparam});
            return win32.DefWindowProcW(hwnd, msg, wparam, lparam);
        },
        win32.WM_KEYDOWN => {
            input_log.info("WM_KEYDOWN {}", .{wparam});
            switch (wparam) {
                @intFromEnum(win32.VK_BACK) => app.backspace(),
                @intFromEnum(win32.VK_DOWN) => app.arrowKey(.down),
                @intFromEnum(win32.VK_UP) => app.arrowKey(.up),
                'A'...'Z' => |key| {
                    if (win32.GetKeyState(@intFromEnum(win32.VK_CONTROL)) < 0) {
                        app.ctrlKey(@intCast(key + ('a' - 'A')));
                    }
                },
                else => {},
            }
            return 0;
        },
        win32.WM_SYSCHAR => {
            input_log.info("WM_SYSCHAR {}", .{wparam});
            return win32.DefWindowProcW(hwnd, msg, wparam, lparam);
        },
        win32.WM_CHAR => {
            const chars: [2]u16 = blk: {
                const chars = [2]u16{ global.wm_char_high_surrogate, @truncate(wparam) };
                std.debug.assert(chars[1] == wparam);
                if (std.unicode.utf16IsHighSurrogate(chars[1])) {
                    input_log.info("WM_CHAR [{},{}] high surrogate", .{ chars[0], chars[1] });
                    global.wm_char_high_surrogate = chars[1];
                    return 0;
                }
                global.wm_char_high_surrogate = 0;
                break :blk chars;
            };
            const codepoint: u21 = blk: {
                if (std.unicode.utf16IsHighSurrogate(chars[0])) {
                    if (std.unicode.utf16DecodeSurrogatePair(&chars)) |c| break :blk c else |e| switch (e) {
                        error.ExpectedSecondSurrogateHalf => {},
                    }
                }
                break :blk chars[1];
            };
            var utf8_buf: [7]u8 = undefined;
            const len = std.unicode.utf8Encode(codepoint, &utf8_buf) catch |e| std.debug.panic(
                "utf8Encode {} failed with {s}",
                .{ codepoint, @errorName(e) },
            );
            input_log.info(
                "WM_CHAR [{},{}] codepoint={} utf8='{s}'",
                .{ chars[0], chars[1], codepoint, utf8_buf[0..len] },
            );
            switch (codepoint) {
                // 0 => {}, not sure if this one is posssible?
                1...26 => {}, // ignore Ctrl-A .. Ctrl-Z, handle in WM_KEYDOWN instead
                else => app.inputUtf8(utf8_buf[0..len]),
            }
            return 0;
        },
        win32.WM_CLOSE, win32.WM_DESTROY => {
            win32.PostQuitMessage(0);
            return 0;
        },
        win32.WM_PAINT => {
            const dpi = win32.dpiFromHwnd(hwnd);
            const client_size = win32.getClientSize(hwnd);

            const hdc, const ps = win32.beginPaint(hwnd);
            _ = hdc;

            if (global.maybe_d2d == null) {
                global.maybe_d2d = D2d.init(hwnd);
            }
            const d2d = &(global.maybe_d2d.?);
            {
                const size: win32.D2D_SIZE_U = .{
                    .width = @intCast(client_size.cx),
                    .height = @intCast(client_size.cy),
                };
                const hr = d2d.target.Resize(&size);
                if (hr < 0) win32.panicHresult("D2dResize", hr);
            }
            d2d.target.ID2D1RenderTarget.BeginDraw();
            {
                const color = d2dFromRgb8(theme.Color.bg.getRgb8());
                d2d.target.ID2D1RenderTarget.Clear(&color);
            }
            app.render(
                .{},
                win32.scaleFromDpi(f32, dpi),
                .{ .x = client_size.cx, .y = client_size.cy },
            );
            {
                var tag1: u64 = undefined;
                var tag2: u64 = undefined;
                const hr = d2d.target.ID2D1RenderTarget.EndDraw(&tag1, &tag2);
                if (hr < 0) std.debug.panic(
                    "D2dEndDraw error, tag1={}, tag2={}, hresult=0x{x}",
                    .{ tag1, tag2, @as(u32, @bitCast(hr)) },
                );
            }
            win32.endPaint(hwnd, &ps);
            return 0;
        },
        win32.WM_SIZE => {
            // since we "stretch" the image accross the full window, we
            // always invalidate the full client area on each window resize
            win32.invalidateHwnd(hwnd);
            return 0;
        },
        else => return win32.DefWindowProcW(hwnd, msg, wparam, lparam),
    }
}

const D2d = struct {
    target: *win32.ID2D1HwndRenderTarget,
    brush: *win32.ID2D1SolidColorBrush,
    bmp: ?struct {
        obj: *win32.ID2D1Bitmap,
        size: XY(u16),
    } = null,
    pub fn init(hwnd: win32.HWND) D2d {
        var target: *win32.ID2D1HwndRenderTarget = undefined;
        const target_props = win32.D2D1_RENDER_TARGET_PROPERTIES{
            .type = .DEFAULT,
            .pixelFormat = .{
                .format = .B8G8R8A8_UNORM,
                .alphaMode = .PREMULTIPLIED,
            },
            .dpiX = 0,
            .dpiY = 0,
            .usage = .{},
            .minLevel = .DEFAULT,
        };
        const hwnd_target_props = win32.D2D1_HWND_RENDER_TARGET_PROPERTIES{
            .hwnd = hwnd,
            .pixelSize = .{ .width = 0, .height = 0 },
            .presentOptions = .{},
        };

        {
            const hr = global.d2d_factory.CreateHwndRenderTarget(
                &target_props,
                &hwnd_target_props,
                &target,
            );
            if (hr < 0) return win32.panicHresult("CreateHwndRenderTarget", hr);
        }
        errdefer _ = target.IUnknown.Release();

        {
            var dc: *win32.ID2D1DeviceContext = undefined;
            {
                const hr = target.IUnknown.QueryInterface(win32.IID_ID2D1DeviceContext, @ptrCast(&dc));
                if (hr < 0) return win32.panicHresult("GetDeviceContext", hr);
            }
            defer _ = dc.IUnknown.Release();
            // just make everything DPI aware, all applications should just do this
            dc.SetUnitMode(win32.D2D1_UNIT_MODE_PIXELS);
        }

        var brush: *win32.ID2D1SolidColorBrush = undefined;
        {
            const color: win32.D2D_COLOR_F = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
            const hr = target.ID2D1RenderTarget.CreateSolidColorBrush(&color, null, &brush);
            if (hr < 0) return win32.panicHresult("CreateSolidBrush", hr);
        }
        errdefer _ = brush.IUnknown.Release();

        return .{
            .target = target,
            .brush = brush,
            .bmp = null,
        };
    }
    pub fn deinit(self: *D2d) void {
        if (self.bmp) |bmp| _ = bmp.obj.IUnknown.Release();
        _ = self.brush.IUnknown.Release();
        _ = self.target.IUnknown.Release();
    }
    pub fn solid(self: *const D2d, color: win32.D2D_COLOR_F) *win32.ID2D1Brush {
        self.brush.SetColor(&color);
        return &self.brush.ID2D1Brush;
    }
};
fn d2dFromRgb8(rgb: Rgb8) win32.D2D_COLOR_F {
    return .{
        .r = @as(f32, @floatFromInt(rgb.r)) / 255.0,
        .g = @as(f32, @floatFromInt(rgb.g)) / 255.0,
        .b = @as(f32, @floatFromInt(rgb.b)) / 255.0,
        .a = 1.0,
    };
}

pub const Rect = win32.RECT;

pub const RenderTarget = struct {
    pub fn fillRect(self: RenderTarget, color: theme.Color, rect: win32.RECT) void {
        _ = self;
        const d2d = &(global.maybe_d2d.?);
        const r: win32.D2D_RECT_F = .{
            .left = @floatFromInt(rect.left),
            .top = @floatFromInt(rect.top),
            .right = @floatFromInt(rect.right),
            .bottom = @floatFromInt(rect.bottom),
        };
        const c = d2d.solid(d2dFromRgb8(color.getRgb8()));
        d2d.target.ID2D1RenderTarget.FillRectangle(&r, c);
    }
    // TODO: remove this method when our text rendering is ready to do the UI
    pub fn drawText(self: RenderTarget, text_size: XY(u16), pos: XY(i32), text: []const u8) void {
        _ = self;
        const d2d = &(global.maybe_d2d.?);

        var text_format: *win32.IDWriteTextFormat = undefined;
        {
            const hr = global.dwrite_factory.CreateTextFormat(
                win32.L("Segoe UI"),
                null,
                win32.DWRITE_FONT_WEIGHT_NORMAL,
                win32.DWRITE_FONT_STYLE_NORMAL,
                win32.DWRITE_FONT_STRETCH_NORMAL,
                @as(f32, @floatFromInt(text_size.y)) * 0.8,
                win32.L("en-us"),
                &text_format,
            );
            if (hr < 0) win32.panicHresult("CreateTextFormat", hr);
        }
        defer _ = text_format.IUnknown.Release();

        var codepoint_index: i32 = 0;
        var offset: usize = 0;
        while (offset < text.len) : (codepoint_index += 1) {
            const utf8_len = std.unicode.utf8ByteSequenceLength(text[offset]) catch @panic("invalid utf8");
            if (utf8_len > text.len) @panic("utf8 truncated");
            const codepoint = std.unicode.utf8Decode(text[offset..][0..utf8_len]) catch @panic("invalid utf8");
            offset += utf8_len;

            const text_wide = [1:0]u16{@truncate(codepoint)};
            const left = pos.x + text_size.x * codepoint_index;
            std.log.info("rendering codepoint {} x={}", .{ codepoint, left });
            const rect: win32.D2D_RECT_F = .{
                .left = @floatFromInt(left),
                .top = @floatFromInt(pos.y),
                .right = @floatFromInt(left + text_size.x),
                .bottom = @floatFromInt(pos.y + text_size.y),
            };
            d2d.target.ID2D1RenderTarget.DrawText(
                &text_wide,
                1,
                text_format,
                &rect,
                d2d.solid(d2dFromRgb8(theme.Color.white.getRgb8())),
                .{},
                .NATURAL,
            );
        }
    }

    pub const Bitmap = struct {
        // public fields
        grayscale: [*]u8,
        stride: usize,

        size: XY(u16),
        pub fn renderDone(self: *Bitmap) void {
            self.* = undefined;
        }

        fn slice(self: Bitmap) []u8 {
            return self.grayscale[0 .. self.stride * @as(usize, self.size.y)];
        }
    };
    pub fn getBitmap(self: RenderTarget, size: XY(u16)) Bitmap {
        _ = self;
        if (global.bmp) |bmp| {
            if (bmp.size.x >= size.x and bmp.size.y >= size.y)
                return bmp;
            std.log.info(
                "freeing bitmap of size {}x{} for size {}x{}",
                .{ bmp.size.x, bmp.size.y, size.x, size.y },
            );
            global.bmp_arena.allocator().free(bmp.slice());
            global.bmp = null;
        }
        const stride: usize = size.x * 4;
        const len = stride * @as(usize, size.y);
        std.log.info("allocating {} bytes for bitmap ({}x{})", .{ len, size.x, size.y });
        global.bmp = .{
            .grayscale = (global.bmp_arena.allocator().alloc(u8, len) catch |e| oom(e)).ptr,
            .stride = stride,
            .size = size,
        };
        return global.bmp.?;
    }
    pub fn renderBitmap(self: RenderTarget, bmp: Bitmap, pos: XY(i32), size: XY(i32)) void {
        _ = self;
        std.debug.assert(size.x <= bmp.size.x);
        std.debug.assert(size.y <= bmp.size.y);

        // convert from grayscale to bgra
        for (0..@intCast(size.y)) |row| {
            const row_offset = bmp.stride * row;
            for (0..@intCast(size.x)) |col_reverse| {
                const col = @as(usize, @intCast(size.x)) - col_reverse - 1;
                const alpha = bmp.grayscale[row_offset + col];
                bmp.grayscale[row_offset + col * 4 + 0] = alpha; // blue
                bmp.grayscale[row_offset + col * 4 + 1] = alpha; // green
                bmp.grayscale[row_offset + col * 4 + 2] = alpha; // red
                bmp.grayscale[row_offset + col * 4 + 3] = alpha; // alpha
            }
        }

        const d2d = &(global.maybe_d2d.?);

        if (d2d.bmp) |old_bmp| {
            // This is throwing a segfault, might be a problem with the zigwin32 bindings
            //const old_size = old_bmp.obj.GetPixelSize();
            const old_size = old_bmp.size;
            if (old_size.x < bmp.size.x or old_size.y < bmp.size.y) {
                _ = old_bmp.obj.IUnknown.Release();
                d2d.bmp = null;
            }
        }

        if (d2d.bmp == null) {
            var new_bmp: *win32.ID2D1Bitmap = undefined;
            {
                const props = win32.D2D1_BITMAP_PROPERTIES{
                    .pixelFormat = .{
                        .format = .B8G8R8A8_UNORM,
                        .alphaMode = .PREMULTIPLIED,
                    },
                    .dpiX = 0,
                    .dpiY = 0,
                };
                const hr = d2d.target.ID2D1RenderTarget.CreateBitmap(
                    .{ .width = @intCast(bmp.size.x), .height = @intCast(bmp.size.y) },
                    null,
                    0,
                    &props,
                    &new_bmp,
                );
                if (hr < 0) win32.panicHresult("CreateBitmap", hr);
            }
            d2d.bmp = .{ .obj = new_bmp, .size = bmp.size };
        }

        {
            const rect = win32.D2D_RECT_U{
                .left = 0,
                .top = 0,
                .right = @intCast(size.x),
                .bottom = @intCast(size.y),
            };
            const hr = d2d.bmp.?.obj.CopyFromMemory(
                &rect,
                bmp.grayscale,
                @intCast(bmp.stride),
            );
            if (hr < 0) win32.panicHresult("D2dBitmapCopy", hr);
        }
        const dest_rect = win32.D2D_RECT_F{
            .left = @floatFromInt(pos.x),
            .top = @floatFromInt(pos.y),
            .right = @floatFromInt(pos.x + size.x),
            .bottom = @floatFromInt(pos.y + size.y),
        };
        const src_rect = win32.D2D_RECT_F{
            .left = 0,
            .top = 0,
            .right = @floatFromInt(size.x),
            .bottom = @floatFromInt(size.y),
        };
        d2d.target.ID2D1RenderTarget.DrawBitmap(
            d2d.bmp.?.obj,
            &dest_rect,
            1.0, // opacity
            .LINEAR, // interpolation mode
            &src_rect,
        );
    }
};

pub fn oom(e: error{OutOfMemory}) noreturn {
    @panic(@errorName(e));
}
