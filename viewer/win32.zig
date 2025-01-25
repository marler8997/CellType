const builtin = @import("builtin");
const std = @import("std");

const win32 = @import("win32").everything;

const gdi = @import("gdi.zig");
const XY = @import("xy.zig").XY;

const celltype = @import("celltype");

const TextArray = std.BoundedArray(u8, 30);

const global = struct {
    var hwnd: win32.HWND = undefined;
    var gdi_cache: gdi.ObjectCache = .{};
    var font_weight: f32 = celltype.default_weight;
    var text: TextArray = TextArray.fromSlice("HiNZ0123") catch unreachable;
    var wm_char_high_surrogate: u16 = 0;
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
    .title = "CellType Viewer Panic",
});

pub fn main() !void {
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
            if (std.mem.eql(u8, arg, "--text")) {
                if (index >= cmdline.len) @panic("--text requires an argument");
                const text = cmdline[index];
                index += 1;
                global.text = TextArray.fromSlice(text) catch std.debug.panic(
                    "--text ({} bytes) too long (max {})",
                    .{ text.len, global.text.capacity() },
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

    const CLASS_NAME = win32.L("CellTypeViewer");
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
        win32.L("CellType Viewer"),
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
    if (std.math.cast(u32, wparam)) |c| {
        std.log.info("quit {}", .{c});
        win32.ExitProcess(c);
    }
    std.log.info("quit {} (0xffffffff)", .{wparam});
    win32.ExitProcess(0xffffffff);
}

fn isUtf8Extension(c: u8) bool {
    return (c & 0b1100_0000) == 0b1000_0000;
}

fn WndProc(
    hwnd: win32.HWND,
    msg: u32,
    wparam: win32.WPARAM,
    lparam: win32.LPARAM,
) callconv(std.os.windows.WINAPI) win32.LRESULT {
    switch (msg) {
        win32.WM_SYSKEYDOWN => {
            input_log.info("WM_SYSKEYDOWN {}", .{wparam});
            return win32.DefWindowProcW(hwnd, msg, wparam, lparam);
        },
        win32.WM_KEYDOWN => {
            input_log.info("WM_KEYDOWN {}", .{wparam});

            {
                const new_weight = @max(0.01, switch (wparam) {
                    @intFromEnum(win32.VK_DOWN) => global.font_weight - 0.01,
                    @intFromEnum(win32.VK_UP) => global.font_weight + 0.01,
                    else => global.font_weight,
                });
                if (new_weight != global.font_weight) {
                    global.font_weight = new_weight;
                    win32.invalidateHwnd(hwnd);
                }
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
            if (codepoint == 8) {
                input_log.info("WM_CHAR [{},{}] backspace", .{ chars[0], chars[1] });
                const len_before = global.text.len;
                while (global.text.len > 0) {
                    global.text.len -= 1;
                    if (!isUtf8Extension(global.text.buffer[global.text.len])) break;
                }
                if (global.text.len != len_before)
                    win32.invalidateHwnd(hwnd);
            } else {
                var utf8_buf: [7]u8 = undefined;
                const len = std.unicode.utf8Encode(codepoint, &utf8_buf) catch |e| std.debug.panic(
                    "utf8Encode {} failed with {s}",
                    .{ codepoint, @errorName(e) },
                );
                input_log.info(
                    "WM_CHAR [{},{}] codepoint={} utf8='{s}'",
                    .{ chars[0], chars[1], codepoint, utf8_buf[0..len] },
                );

                global.text.appendSlice(utf8_buf[0..len]) catch {
                    // todo show error message in UI
                    std.log.err("too many characters", .{});
                    _ = win32.MessageBeep(@bitCast(win32.MB_ICONWARNING));
                };
                win32.invalidateHwnd(hwnd);
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
            gdi.paint(hdc, dpi, client_size, global.font_weight, global.text.constSlice(), &global.gdi_cache);
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

pub fn oom(e: error{OutOfMemory}) noreturn {
    @panic(@errorName(e));
}
