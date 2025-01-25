const std = @import("std");
const root = @import("root");
const celltype = @import("celltype");

pub const TextArray = std.BoundedArray(u8, 30);

pub const global = struct {
    pub var font_weight: f32 = celltype.default_weight;
    pub var text: TextArray = TextArray.fromSlice("HiNZ0123") catch unreachable;
};

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

pub fn arrowKey(arrow_key: enum { down, up }) void {
    const new_weight = @max(0.01, switch (arrow_key) {
        .down => global.font_weight - 0.01,
        .up => global.font_weight + 0.01,
    });
    if (new_weight != global.font_weight) {
        global.font_weight = new_weight;
        root.invalidate();
    }
}

pub fn inputUtf8(utf8: []const u8) void {
    global.text.appendSlice(utf8) catch {
        // todo show error message in UI
        std.log.err("too many characters", .{});
        root.beep();
    };
    root.invalidate();
}

fn isUtf8Extension(c: u8) bool {
    return (c & 0b1100_0000) == 0b1000_0000;
}
