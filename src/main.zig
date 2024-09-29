const std = @import("std");

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

const SCREEN_SIDE: usize = 128;

var screen_buffer = std.mem.zeroes(
    [SCREEN_SIDE][SCREEN_SIDE][4]u8,
);

export fn getScreenSide() usize {
    return SCREEN_SIDE;
}

const TILE_SIDE = SCREEN_SIDE / 16;

var player_x: usize = SCREEN_SIDE / 2;
var player_y: usize = SCREEN_SIDE / 2;

const Vec2i = struct {
    i: usize,
    j: usize,
};

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

fn fillTile(tile: Vec2i, color: Color) void {
    for (0..TILE_SIDE) |y| {
        for (0..TILE_SIDE) |x| {
            const asdf = &screen_buffer[y + tile.j * TILE_SIDE][x + tile.i * TILE_SIDE];
            asdf[0] = color.r;
            asdf[1] = color.g;
            asdf[2] = color.b;
            asdf[3] = 255;
        }
    }
}

export fn keydown(code: u32) void {
    switch (code) {
        0 => player_y -%= 1,
        1 => player_y +%= 1,
        2 => player_x -%= 1,
        3 => player_x +%= 1,
        else => {},
    }
}

var global_t: f32 = 0;
export fn frame(delta_seconds: f32) void {
    global_t += delta_seconds;
}

export fn draw() [*]u8 {
    const dark_value_red: u8 = 0;
    const dark_value_green: u8 = 0;
    const dark_value_blue: u8 = 0;
    const light_value_red: u8 = 255;
    const light_value_green: u8 = 255;
    const light_value_blue: u8 = 255;
    for (&screen_buffer, 0..) |*row, y| {
        for (row, 0..) |*square, x| {
            var is_dark_square = true;

            if ((y % 2) == 0) {
                is_dark_square = false;
            }

            if ((x % 2) == 0) {
                is_dark_square = !is_dark_square;
            }

            var square_value_red = dark_value_red;
            var square_value_green = dark_value_green;
            var square_value_blue = dark_value_blue;
            if (!is_dark_square) {
                square_value_red = light_value_red;
                square_value_green = light_value_green;
                square_value_blue = light_value_blue;
            }

            square.*[0] = @as(u8, @intCast(@as(usize, @intFromFloat(@as(f32, @floatFromInt(x)) + global_t * 11)) % 256)) ^ @as(u8, @intCast(y % 256));
            square.*[1] = @as(u8, @intCast(@as(usize, @intFromFloat(@as(f32, @floatFromInt(y)) + global_t * 7)) % 256)) ^ @as(u8, @intCast(x % 256));
            square.*[2] = @intCast(x ^ y);
            square.*[3] = 255;
        }
    }
    screen_buffer[player_y][player_x][0] = 255;
    screen_buffer[player_y][player_x][1] = 255;
    screen_buffer[player_y][player_x][2] = 0;
    screen_buffer[player_y][player_x][3] = 255;

    fillTile(.{ .i = 1, .j = 2 }, .{ .r = 255, .g = 128, .b = 0 });
    fillTile(.{ .i = 2, .j = 3 }, .{ .r = 255, .g = 128, .b = 0 });

    return @ptrCast(&screen_buffer);
}
