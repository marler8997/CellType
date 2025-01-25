const DesignMode = @This();

const std = @import("std");
const app = @import("app.zig");
const root = @import("root");

const XY = @import("xy.zig").XY;

cell_size: XY(u16) = .{ .x = 10, .y = 20 },
cell_pixel_size: ?u32 = null,

layout: ?Layout = null,

const Layout = struct {
    render_scale: f32,
    cell_pixel_size: u32,
    text_size: XY(u16),
    zoom_out_button: app.Rect,
    zoom_in_button: app.Rect,
    grid_pos: XY(i32),
};

const zoom_out_text = "Zoom Out";
const zoom_in_text = "Zoom In";

fn pxFromPt(render_scale: f32, pt: f32) i32 {
    return @intFromFloat(@round(render_scale * pt));
}

pub fn getLayout(self: *DesignMode, render_scale: f32, cell_pixel_size: u32) *const Layout {
    if (self.layout) |*layout| {
        if (layout.render_scale == render_scale and layout.cell_pixel_size == cell_pixel_size) return layout;
    }

    const text_size: XY(u16) = .{
        .x = @intCast(pxFromPt(render_scale, 10.0)),
        .y = @intCast(pxFromPt(render_scale, 20.0)),
    };

    const margin: i32 = pxFromPt(render_scale, 10.0);

    const button_padding: i32 = pxFromPt(render_scale, 10.0);
    const button_height: i32 = text_size.y + 2 * button_padding;
    const grid_top: i32 = margin + button_height + pxFromPt(render_scale, 10.0);

    const zoom_in_left: i32 = margin + text_size.x * @as(i32, @intCast(zoom_out_text.len)) + pxFromPt(render_scale, 20.0);

    self.layout = .{
        .render_scale = render_scale,
        .cell_pixel_size = cell_pixel_size,
        .text_size = text_size,
        .zoom_out_button = app.Rect.initSized(
            margin,
            margin,
            text_size.x * @as(i32, @intCast(zoom_in_text.len)),
            text_size.y,
        ),
        .zoom_in_button = app.Rect.initSized(
            zoom_in_left,
            margin,
            zoom_in_left + text_size.x * @as(i32, @intCast(zoom_in_text.len)),
            text_size.y,
        ),
        .grid_pos = .{ .x = margin, .y = grid_top },
    };
    return &(self.layout.?);
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
                if (layout.zoom_out_button.containsPoint(point)) {
                    const cell_pixel_size = self.cell_pixel_size orelse return;
                    self.cell_pixel_size = @max(1, cell_pixel_size - 1);
                    root.invalidate();
                } else if (layout.zoom_in_button.containsPoint(point)) {
                    const cell_pixel_size = self.cell_pixel_size orelse return;
                    self.cell_pixel_size = cell_pixel_size + 1;
                    root.invalidate();
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
    if (self.cell_pixel_size == null) {
        self.cell_pixel_size = @intFromFloat(@round(render_scale * 10.0));
    }
    const cell_pixel_size: i32 = @intCast(self.cell_pixel_size.?);

    // TODO: currently this causes overdraw
    target.fillRect(.bg, .{ .left = 0, .top = 0, .right = render_size.x, .bottom = render_size.y });
    const layout = self.getLayout(render_scale, @intCast(cell_pixel_size));

    target.drawText(layout.text_size, layout.zoom_out_button.topLeft(), zoom_out_text);
    target.drawText(layout.text_size, layout.zoom_in_button.topLeft(), zoom_in_text);

    const grid_line_size: i32 = pxFromPt(render_scale, 1.0);

    {
        var y: i32 = layout.grid_pos.y;
        for (0..@intCast(self.cell_size.y)) |row| {
            if (row > 0) {
                target.fillRect(.grid_line, .{
                    .left = layout.grid_pos.x,
                    .top = y,
                    .right = layout.grid_pos.x + self.cell_size.x * cell_pixel_size + (self.cell_size.x - 1) * grid_line_size,
                    .bottom = y + grid_line_size,
                });
                y += grid_line_size;
            }

            var x: i32 = layout.grid_pos.x;
            for (0..@intCast(self.cell_size.x)) |col| {
                if (col > 0) {
                    target.fillRect(.grid_line, .{
                        .left = x,
                        .top = y,
                        .right = x + grid_line_size,
                        .bottom = y + cell_pixel_size,
                    });
                    x += grid_line_size;
                }
                target.fillRect(.black, .{
                    .left = x,
                    .top = y,
                    .right = x + cell_pixel_size,
                    .bottom = y + cell_pixel_size,
                });
                x += cell_pixel_size;
            }
            y += cell_pixel_size;
        }
    }
}
