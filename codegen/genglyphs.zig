const std = @import("std");

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const arena = arena_instance.allocator();
    const full_cmdline = try std.process.argsAlloc(arena);
    if (full_cmdline.len <= 1) @panic("not enough cmdline args");
    const cmdline = full_cmdline[1..];
    if (cmdline.len != 2) std.debug.panic("expected 2 cmdline args but got {}", .{cmdline.len});

    const in_filename = cmdline[0];
    const out_filename = cmdline[1];

    const content = blk: {
        const file = try std.fs.cwd().openFile(in_filename, .{});
        defer file.close();
        break :blk try file.readToEndAlloc(arena, std.math.maxInt(usize));
    };
    // no need to free content

    const out_file = try std.fs.cwd().createFile(out_filename, .{});
    defer out_file.close();
    var bw = std.io.bufferedWriter(out_file.writer());
    const writer = bw.writer();
    try writer.writeAll("const core = @import(\"core\");\n");

    var inside_glyph = false;

    var line_it = std.mem.splitScalar(u8, content, '\n');
    var lineno: u32 = 0;

    while (line_it.next()) |line_untrimmed| {
        lineno += 1;
        const line = std.mem.trimRight(u8, line_untrimmed, " \r");
        if (line.len == 0 or line[0] == '#') continue;

        const new_glyph_prefix = "--- ";
        const is_new_glyph_line = std.mem.startsWith(u8, line, new_glyph_prefix);
        if (is_new_glyph_line) {
            if (inside_glyph) {
                try writer.writeAll(") catch unreachable;\n");
            }
            const glyph = line[new_glyph_prefix.len..];
            const quote_it = (glyph.len == 1) and ((glyph[0] >= '!') and (glyph[0] <= '9') or
                (glyph[0] >= '[') and (glyph[0] <= '`'));
            const prefix: []const u8 = if (quote_it) "@\"" else "";
            const suffix: []const u8 = if (quote_it) "\"" else "";
            try writer.print(
                "pub const {s}{s}{s} = core.lex.parseOps(\n",
                .{ prefix, glyph, suffix },
            );
            inside_glyph = true;
        } else {
            if (!inside_glyph) std.debug.panic(
                "{s}:{}: expected '{s}<LETTER>' but got '{s}'",
                .{ in_filename, lineno, new_glyph_prefix, line },
            );
            try writer.print("    \\\\{s}\n", .{line});
        }
    }

    if (inside_glyph) {
        try writer.writeAll(") catch unreachable;\n");
    }

    try bw.flush();
}
