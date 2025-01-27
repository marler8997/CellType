const std = @import("std");
const root = @import("root");
const celltype = @import("celltype");

const DesignMode = @import("DesignMode.zig");
const XY = @import("xy.zig").XY;

pub const TextArray = std.BoundedArray(u8, 30);

pub const Mode = enum {
    view,
    design,
};
pub const MouseButtonKind = enum { left };
pub const MouseButtonState = enum { up, down };

pub const global = struct {
    var mode: Mode = .view;
    var design_mode: DesignMode = .{
        .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator),
    };

    var font_weight: f32 = celltype.default_weight;
    pub var text: TextArray = TextArray.fromSlice("HiNZ0123") catch unreachable;
};

pub fn setDesignFile(file: []const u8) void {
    global.design_mode.setDesignFile(file);
}

pub fn backspace() void {
    const len_before = global.text.len;
    while (global.text.len > 0) {
        global.text.len -= 1;
        if (!isUtf8Extension(global.text.buffer[global.text.len])) break;
    }
    if (global.text.len != len_before)
        root.invalidate();
    root.invalidate();
}

pub const ArrowKey = enum { left, right, down, up };

pub fn arrowKey(key: ArrowKey) void {
    switch (global.mode) {
        .view => {
            const new_weight = @max(0.01, switch (key) {
                .left => return,
                .right => return,
                .down => global.font_weight - 0.01,
                .up => global.font_weight + 0.01,
            });
            if (new_weight != global.font_weight) {
                global.font_weight = new_weight;
                root.invalidate();
            }
        },
        .design => {
            global.design_mode.arrowKey(key);
        },
    }
}

pub const Command = union(enum) {
    view_mode,
    design_mode,
    reload_design_file,
};
pub fn exec(command: Command) void {
    switch (command) {
        .view_mode => {
            if (global.mode != .view) {
                global.mode = .view;
                root.invalidate();
            }
        },
        .design_mode => {
            if (global.mode != .design) {
                global.mode = .design;
                root.invalidate();
            }
        },
        .reload_design_file => global.design_mode.reloadFile(),
    }
}

pub fn ctrlKey(key: u8) void {
    switch (key) {
        'd' => exec(.design_mode),
        'v' => exec(.view_mode),
        else => {},
    }
}

pub fn inputUtf8(utf8: []const u8) void {
    switch (global.mode) {
        .view => {
            global.text.appendSlice(utf8) catch {
                // todo show error message in UI
                std.log.err("too many characters", .{});
                root.beep();
            };
            root.invalidate();
        },
        .design => global.design_mode.inputUtf8(utf8),
    }
}

pub const Rect = struct {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
    pub fn initSized(left: i32, top: i32, width: i32, height: i32) Rect {
        return .{
            .left = left,
            .top = top,
            .right = left + width,
            .bottom = top + height,
        };
    }
    pub fn topLeft(self: Rect) XY(i32) {
        return .{ .x = self.left, .y = self.top };
    }
    pub fn center(self: Rect) XY(f32) {
        const left: f32 = @floatFromInt(self.left);
        const top: f32 = @floatFromInt(self.top);
        return .{
            .x = left + @as(f32, @floatFromInt(self.right - self.left)) / 2,
            .y = top + @as(f32, @floatFromInt(self.bottom - self.top)) / 2,
        };
    }
    pub fn containsPoint(self: Rect, p: XY(i32)) bool {
        return p.x >= self.left and p.x < self.right and p.y >= self.top and p.y < self.bottom;
    }
};

pub fn mouseButton(kind: MouseButtonKind, state: MouseButtonState, pos: XY(i32)) void {
    switch (global.mode) {
        .view => {},
        .design => global.design_mode.mouseButton(kind, state, pos),
    }
}

pub fn countGlyphs(text: []const u8) usize {
    var glyph_count: usize = 0;
    var offset: usize = 0;
    while (offset < text.len) : (glyph_count += 1) {
        const utf8_len = std.unicode.utf8ByteSequenceLength(text[offset]) catch @panic("invalid utf8");
        if (utf8_len > text.len) @panic("utf8 truncated");
        _ = std.unicode.utf8Decode(text[offset..][0..utf8_len]) catch @panic("invalid utf8");
        offset += utf8_len;
    }
    return glyph_count;
}

pub fn drawText(target: root.RenderTarget, text_cell_size: XY(u16), pos: XY(i32), text: []const u8) i32 {
    // TODO: don't defer to the render target when we have enough characters to render text ourselves
    return target.drawText(text_cell_size, pos, text);
}
pub fn drawTextCentered(target: root.RenderTarget, text_cell_size: XY(u16), center: XY(f32), text: []const u8) i32 {
    const glyph_count = countGlyphs(text);
    const full_text_width: i32 = @as(i32, @intCast(text_cell_size.x)) * @as(i32, @intCast(glyph_count));
    return drawText(target, text_cell_size, .{
        .x = @intFromFloat(@round(center.x - @as(f32, @floatFromInt(full_text_width)) / 2)),
        .y = @intFromFloat(@round(center.y - @as(f32, @floatFromInt(text_cell_size.y)) / 2)),
    }, text);
}

pub fn render(target: root.RenderTarget, scale: f32, render_size: XY(i32)) void {
    switch (global.mode) {
        .view => renderViewMode(target, scale, render_size),
        .design => global.design_mode.render(target, scale, render_size),
    }
}
fn renderViewMode(target: root.RenderTarget, scale: f32, render_size: XY(i32)) void {
    _ = render_size;
    // NOTE: the win32 platform is currently using GDI which means
    //       we need to avoid overdraw (drawing the same pixel twice)
    //       see https://catch22.net/tuts/win32/flicker-free-drawing/
    const cell_sizes = [_]XY(u16){
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
        for (cell_sizes) |s| {
            max.x = @max(max.x, s.x);
            max.y = @max(max.y, s.y);
        }
        break :blk max;
    };

    var bmp = target.getBitmap(max_size);
    defer bmp.renderDone();

    const margin: i32 = @intFromFloat(@round(10 * scale));
    const spacing: XY(i32) = .{
        .x = 1,
        .y = @intFromFloat(@round(5 * scale)),
    };
    var y: i32 = margin;

    const graphemes = global.text.constSlice();

    for (cell_sizes) |cell_size| {
        var x: i32 = margin;
        var grapheme_offset: usize = 0;
        while (grapheme_offset < graphemes.len) {
            const config: celltype.Config = .{
                .serif = true,
            };
            const stroke_width = blk: {
                // good for testing
                //if (true) break :blk 1;
                break :blk celltype.calcStrokeWidth(u16, cell_size.x, cell_size.y, global.font_weight);
            };
            grapheme_offset += celltype.renderText(
                &config,
                u16,
                cell_size.x,
                cell_size.y,
                stroke_width,
                bmp.grayscale,
                bmp.stride,
                .{ .output_precleared = false },
                graphemes[grapheme_offset..],
            ) catch |err| std.debug.panic("render failed with {s}", .{@errorName(err)});
            target.renderBitmap(bmp, .{ .x = x, .y = y }, .{ .x = cell_size.x, .y = cell_size.y });
            x += @as(i32, @intCast(cell_size.x));
            x += spacing.x;
        }
        y += cell_size.y;
        y += spacing.y;
    }
}

fn isUtf8Extension(c: u8) bool {
    return (c & 0b1100_0000) == 0b1000_0000;
}
