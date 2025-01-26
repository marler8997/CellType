const DesignMode = @This();

const std = @import("std");
const app = @import("app.zig");
const root = @import("root");
const celltype = @import("celltype");

const theme = @import("theme.zig");
const XY = @import("xy.zig").XY;

arena: std.heap.ArenaAllocator,
ops: std.ArrayListUnmanaged(celltype.design.Op) = .{},
op_cursor: usize = 0,

// if true, will add the default views on the first render if there are no views
add_default_views: bool = true,
layout: ?Layout = null,
view_inputs: std.ArrayListUnmanaged(ViewInput) = .{},
grayscale: std.ArrayListUnmanaged(u8) = .{},

const ViewInput = struct {
    //position: XY(i32),
    cell_size: XY(u16),
    stroke_width: u16,
    cell_pixel_size: i32,
};

const ViewLayout = struct {
    //position: XY(i32),
    cell_size: XY(u16),
    stroke_width: u16,
    cell_pixel_size: i32,
    zoom_out_button: app.Rect,
    zoom_in_button: app.Rect,
    pixel_grid: app.Rect,
    pub fn isUpdated(self: *const ViewLayout, input: *const ViewInput) bool {
        return true and
            //self.position.eql(input.position) and
            self.cell_size.eql(input.cell_size) and
            self.stroke_width == input.stroke_width and
            self.cell_pixel_size == input.cell_pixel_size;
    }
};

const Layout = struct {
    render_scale: f32,
    text_size: XY(u16),
    ops_pos: XY(i32),
    ops_char_size: XY(i32),
    views: std.ArrayListUnmanaged(ViewLayout),
};

const zoom_out_text = "-";
const zoom_in_text = "+";

fn pxFromPt(render_scale: f32, pt: f32) i32 {
    return @intFromFloat(@round(render_scale * pt));
}

pub fn getLayout(self: *DesignMode, render_scale: f32) *const Layout {
    _ = updateLayout(self.arena.allocator(), &self.layout, render_scale, self.view_inputs.items);
    return &(self.layout.?);
}

fn updateLayout(
    allocator: std.mem.Allocator,
    layout_ref: *?Layout,
    render_scale: f32,
    view_inputs: []const ViewInput,
) bool {
    need_update: {
        if (layout_ref.*) |*layout| {
            if (layout.render_scale != render_scale) break :need_update;
            if (layout.views.items.len != view_inputs.len) break :need_update;
            for (layout.views.items, view_inputs) |*view, *view_input| {
                if (!view.isUpdated(view_input)) break :need_update;
            }
            // we already up-to-date
            return false;
        }
    }

    const text_size: XY(u16) = .{
        .x = @intCast(pxFromPt(render_scale, 10.0)),
        .y = @intCast(pxFromPt(render_scale, 20.0)),
    };
    const window_margin: i32 = pxFromPt(render_scale, 10.0);

    const zoom_button_width: i32 = pxFromPt(render_scale, 20);
    const button_padding_y: i32 = pxFromPt(render_scale, 1.0);
    const button_height: i32 = text_size.y + 2 * button_padding_y;

    var views: std.ArrayListUnmanaged(ViewLayout) = blk: {
        if (layout_ref.*) |*layout| {
            const views_copy = layout.views;
            layout.views = undefined;
            break :blk views_copy;
        }
        break :blk .{};
    };
    views.ensureTotalCapacity(allocator, view_inputs.len) catch |e| oom(e);
    views.clearRetainingCapacity();

    const grid_line_size: i32 = pxFromPt(render_scale, 1.0);

    var view_y: i32 = window_margin;

    for (view_inputs) |*view_input| {
        const zoom_top = view_y;
        view_y += button_height;
        const zoom_out_right: i32 = window_margin + zoom_button_width;
        const zoom_in_left: i32 = zoom_out_right + pxFromPt(render_scale, 10);
        const grid_right: i32 = window_margin + @as(i32, @intCast(view_input.cell_size.x)) * view_input.cell_pixel_size + @as(i32, @intCast(view_input.cell_size.x - 1)) * grid_line_size;

        const grid_top = view_y + pxFromPt(render_scale, 10);
        const grid_bottom = grid_top + view_input.cell_size.y * view_input.cell_pixel_size + (view_input.cell_size.y - 1) * grid_line_size;
        view_y = grid_bottom + pxFromPt(render_scale, 10);

        views.appendAssumeCapacity(.{
            .cell_size = view_input.cell_size,
            .stroke_width = view_input.stroke_width,
            .cell_pixel_size = view_input.cell_pixel_size,
            .zoom_out_button = .{
                .left = window_margin,
                .top = zoom_top,
                .right = zoom_out_right,
                .bottom = zoom_top + button_height,
            },
            .zoom_in_button = .{
                .left = zoom_in_left,
                .top = zoom_top,
                .right = zoom_in_left + zoom_button_width,
                .bottom = zoom_top + button_height,
            },
            .pixel_grid = .{
                .left = window_margin,
                .top = grid_top,
                .right = grid_right,
                .bottom = grid_bottom,
            },
        });
    }

    var max_grid_right: i32 = 0;
    for (views.items) |*view| {
        max_grid_right = @max(max_grid_right, view.zoom_in_button.right);
        max_grid_right = @max(max_grid_right, view.pixel_grid.right);
    }

    layout_ref.* = .{
        .render_scale = render_scale,
        .text_size = text_size,
        .views = views,
        .ops_pos = .{
            .x = max_grid_right + pxFromPt(render_scale, 25.0),
            .y = window_margin,
        },
        .ops_char_size = .{
            .x = pxFromPt(render_scale, 10.0),
            .y = pxFromPt(render_scale, 22.0),
        },
    };
    std.debug.assert(!updateLayout(allocator, layout_ref, render_scale, view_inputs));
    return true;
}

pub fn arrowKey(self: *DesignMode, key: app.ArrowKey) void {
    if (self.ops.items.len == 0) return;
    std.debug.assert(self.op_cursor < self.ops.items.len);
    switch (key) {
        .down => {
            if (self.op_cursor + 1 < self.ops.items.len) {
                self.op_cursor += 1;
                root.invalidate();
            }
        },
        .up => {
            if (self.op_cursor > 0) {
                self.op_cursor -= 1;
                root.invalidate();
            }
        },
    }
}

pub fn inputUtf8(self: *DesignMode, utf8: []const u8) void {
    if (std.mem.eql(u8, utf8, "n")) {
        self.ops.append(
            self.arena.allocator(),
            .{ .op = .{ .stroke_vert = .{ .x = .{ .base = .center } } } },
        ) catch |e| oom(e);
        root.invalidate();
    }
}

pub fn mouseButton(
    self: *DesignMode,
    kind: app.MouseButtonKind,
    state: app.MouseButtonState,
    point: XY(i32),
) void {
    const layout = self.layout orelse return;
    switch (kind) {
        .left => switch (state) {
            .up => {},
            .down => {
                if (self.view_inputs.items.len != layout.views.items.len) return;
                for (self.view_inputs.items, layout.views.items) |*view_input, *view| {
                    if (view.zoom_out_button.containsPoint(point)) {
                        if (view_input.cell_pixel_size <= 1) return;
                        view_input.cell_pixel_size = view_input.cell_pixel_size - 1;
                        return root.invalidate();
                    } else if (view.zoom_in_button.containsPoint(point)) {
                        view_input.cell_pixel_size = view_input.cell_pixel_size + 1;
                        return root.invalidate();
                    }
                }
            },
        },
    }
}

pub fn render(
    self: *DesignMode,
    target: root.RenderTarget,
    render_scale: f32,
    render_size: XY(i32),
) void {
    _ = render_size;
    if (self.add_default_views) {
        self.add_default_views = false;
        if (self.view_inputs.items.len == 0) {
            const cell_pixel_size: i32 = @intFromFloat(@round(render_scale * 10.0));
            self.view_inputs.append(self.arena.allocator(), .{
                .cell_size = .{ .x = 10, .y = 20 },
                .cell_pixel_size = cell_pixel_size,
                .stroke_width = 2,
            }) catch |e| oom(e);
            self.view_inputs.append(self.arena.allocator(), .{
                .cell_size = .{ .x = 20, .y = 36 },
                .cell_pixel_size = cell_pixel_size,
                .stroke_width = 3,
            }) catch |e| oom(e);
        }
    }

    const layout = self.getLayout(render_scale);

    for (layout.views.items) |*view| {
        target.fillRect(.button_bg, view.zoom_out_button);
        _ = app.drawTextCentered(target, layout.text_size, view.zoom_out_button.center(), zoom_out_text);
        target.fillRect(.button_bg, view.zoom_in_button);
        _ = app.drawTextCentered(target, layout.text_size, view.zoom_in_button.center(), zoom_in_text);

        const cell_count = @as(usize, view.cell_size.x) * @as(usize, view.cell_size.y);
        self.grayscale.resize(self.arena.allocator(), cell_count) catch |e| oom(e);

        const config: celltype.Config = .{};
        celltype.renderOps(
            &config,
            u16,
            view.cell_size.x,
            view.cell_size.y,
            view.stroke_width,
            self.grayscale.items.ptr,
            view.cell_size.x,
            .{ .output_precleared = false },
            self.ops.items,
        );

        const grid_line_size: i32 = pxFromPt(render_scale, 1.0);

        {
            var y: i32 = view.pixel_grid.top;
            for (0..@intCast(view.cell_size.y)) |row| {
                if (row > 0) {
                    target.fillRect(.grid_line, .{
                        .left = view.pixel_grid.left,
                        .top = y,
                        .right = view.pixel_grid.right,
                        .bottom = y + grid_line_size,
                    });
                    y += grid_line_size;
                }
                const row_offset: usize = @as(usize, view.cell_size.x) * row;

                var x: i32 = view.pixel_grid.left;
                for (0..@intCast(view.cell_size.x)) |col| {
                    if (col > 0) {
                        target.fillRect(.grid_line, .{
                            .left = x,
                            .top = y,
                            .right = x + grid_line_size,
                            .bottom = y + view.cell_pixel_size,
                        });
                        x += grid_line_size;
                    }
                    const shade = self.grayscale.items[row_offset + col];
                    target.fillRect(.{ .shade = shade }, .{
                        .left = x,
                        .top = y,
                        .right = x + view.cell_pixel_size,
                        .bottom = y + view.cell_pixel_size,
                    });
                    x += view.cell_pixel_size;
                }
                y += view.cell_pixel_size;
            }
        }
    }

    {
        var y: i32 = layout.ops_pos.y;
        _ = &y;
        for (self.ops.items, 0..) |op, op_index| {
            if (op_index == self.op_cursor) {
                const width = pxFromPt(render_scale, 10.0);
                const right = layout.ops_pos.x - pxFromPt(render_scale, 9.0);
                target.fillRect(theme.highlight, .{
                    .left = right - width,
                    .top = y,
                    .right = right,
                    .bottom = y + layout.ops_char_size.y,
                });
            }

            var render_writer: RenderWriter = .{
                .target = &target,
                .char_size = layout.ops_char_size,
                .pos = .{
                    .x = layout.ops_pos.x,
                    .y = y,
                },
            };
            const writer = render_writer.writer();
            writer.print("{}", .{op}) catch |e| switch (e) {};
            y += layout.ops_char_size.y;
        }
    }
}

const RenderWriter = struct {
    target: *const root.RenderTarget,
    char_size: XY(i32),
    pos: XY(i32),

    pub const Writer = std.io.Writer(*RenderWriter, error{}, write);
    pub fn writer(self: *RenderWriter) Writer {
        return .{ .context = self };
    }
    fn write(self: *RenderWriter, bytes: []const u8) error{}!usize {
        const glyphs_rendered = app.drawText(
            self.target.*,
            .{ .x = @intCast(self.char_size.x), .y = @intCast(self.char_size.y) },
            self.pos,
            bytes,
        );
        self.pos.x += self.char_size.x * glyphs_rendered;
        return bytes.len;
    }
};

pub fn oom(e: error{OutOfMemory}) noreturn {
    @panic(@errorName(e));
}
