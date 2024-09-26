const std = @import("std");

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

const checkerboard_size: usize = 128;

// checkerboard_size * 2, where each pixel is 4 bytes (rgba)
var checkerboard_buffer = std.mem.zeroes(
    [checkerboard_size][checkerboard_size][4]u8,
);

export fn getCheckerboardSize() usize {
    return checkerboard_size;
}

var player_x: usize = checkerboard_size / 2;
var player_y: usize = checkerboard_size / 2;

export fn keydown(code: u32) void {
    switch (code) {
        0 => player_y -%= 1,
        1 => player_y +%= 1,
        2 => player_x -%= 1,
        3 => player_x +%= 1,
        else => {},
    }
}

export fn frame(delta_seconds: f32) void {
    _ = delta_seconds; // autofix
}

export fn draw() [*]u8 {
    const dark_value_red: u8 = 0;
    const dark_value_green: u8 = 0;
    const dark_value_blue: u8 = 0;
    const light_value_red: u8 = 255;
    const light_value_green: u8 = 255;
    const light_value_blue: u8 = 255;
    for (&checkerboard_buffer, 0..) |*row, y| {
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

            square.*[0] = square_value_red;
            square.*[1] = square_value_green;
            square.*[2] = square_value_blue;
            square.*[3] = 255;
        }
    }
    checkerboard_buffer[player_y][player_x][0] = 255;
    checkerboard_buffer[player_y][player_x][1] = 255;
    checkerboard_buffer[player_y][player_x][2] = 0;
    checkerboard_buffer[player_y][player_x][3] = 255;

    return @ptrCast(&checkerboard_buffer);
}
