const builtin = @import("builtin");
const std = @import("std");

const win32 = @import("win32").everything;

const gdi = @import("gdi.zig");
const XY = @import("xy.zig").XY;

const celltype = @import("celltype");

const global = struct {
    var hwnd: win32.HWND = undefined;
    var gdi_cache: gdi.ObjectCache = .{};
    var font_weight: f32 = celltype.default_weight;
    var text: []const u8 = "HiNZ0123";
};

pub const panic = win32.messageBoxThenPanic(.{
    .title = "CellType Viewer Panic",
});

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const arena = arena_instance.allocator();

    {
        const cmdline = try std.process.argsAlloc(arena);
        // no need to free
        var index: usize = 1;
        while (index < cmdline.len) {
            const arg = cmdline[index];
            index += 1;
            if (std.mem.eql(u8, arg, "--text")) {
                if (index >= cmdline.len) @panic("--text requires an argument");
                global.text = cmdline[index];
                index += 1;
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
        win32.CW_USEDEFAULT,
        win32.CW_USEDEFAULT,
        800,
        1000,
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

fn WndProc(
    hwnd: win32.HWND,
    uMsg: u32,
    wparam: win32.WPARAM,
    lparam: win32.LPARAM,
) callconv(std.os.windows.WINAPI) win32.LRESULT {
    switch (uMsg) {
        win32.WM_KEYDOWN => {
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
        },
        win32.WM_CLOSE, win32.WM_DESTROY => {
            win32.PostQuitMessage(0);
            return 0;
        },
        win32.WM_PAINT => {
            const dpi = win32.dpiFromHwnd(hwnd);
            const client_size = win32.getClientSize(hwnd);
            const hdc, const ps = win32.beginPaint(hwnd);
            gdi.paint(hdc, dpi, client_size, global.font_weight, global.text, &global.gdi_cache);
            win32.endPaint(hwnd, &ps);
            return 0;
        },
        win32.WM_SIZE => {
            // since we "stretch" the image accross the full window, we
            // always invalidate the full client area on each window resize
            win32.invalidateHwnd(hwnd);
        },
        else => {},
    }
    return win32.DefWindowProcW(hwnd, uMsg, wparam, lparam);
}

pub fn oom(e: error{OutOfMemory}) noreturn {
    @panic(@errorName(e));
}
