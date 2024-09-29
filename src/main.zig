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

const BOARD_SIDE = 16;
const TILE_SIDE = SCREEN_SIDE / BOARD_SIDE;

const COLORS = struct {
    BOMB: Color = .{ .r = 237, .g = 56, .b = 21 },
    SNAKE: struct {
        HEAD: Color = Color{ .r = 133, .g = 206, .b = 54 },
    } = .{},
}{};

// const COLORS = struct {
//     BOMB: Color,
// }{
//     .BOMB = Color{ .r = 237, .g = 56, .b = 21 },
// };

const Direction = enum {
    Left,
    Right,
    Up,
    Down,
};

const TileState = union(enum) {
    empty: void,
    bomb: void,
    multiplier: void,
    // clock: ... TODO
    body_segment: struct {
        visited_at: usize,
        in_dir: Direction,
        out_dir: ?Direction,
    },
};

var board_state: [BOARD_SIDE][BOARD_SIDE]TileState = .{.{TileState.empty} ** BOARD_SIDE} ** BOARD_SIDE;
var head_pos: Vec2i = undefined;

fn drawBoardTile(pos: Vec2i, tile: TileState) void {
    switch (tile) {
        .empty => {},
        .bomb => fillTileWithCircle(pos, COLORS.BOMB),
        .body_segment => fillTile(pos, COLORS.SNAKE.HEAD),
        else => {},
    }
}

var player_x: usize = SCREEN_SIDE / 2;
var player_y: usize = SCREEN_SIDE / 2;

var turn: usize = 0;
var turn_offset: f32 = 0;

const Vec2i = struct {
    const Self = @This();

    i: usize,
    j: usize,

    fn plus(vec: Self, dir: Direction) Self {
        return switch (dir) {
            .Right => Vec2i{ .i = vec.i + 1, .j = vec.j },
            .Left => Vec2i{ .i = vec.i - 1, .j = vec.j },
            .Down => Vec2i{ .i = vec.i, .j = vec.j + 1 },
            .Up => Vec2i{ .i = vec.i, .j = vec.j - 1 },
        };
    }
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

// OPTIMIZE
fn fillTileWithCircle(tile: Vec2i, color: Color) void {
    if (TILE_SIDE % 2 != 0) @compileError("TILE_SIDE is not even");
    for (0..TILE_SIDE) |y| {
        for (0..TILE_SIDE) |x| {
            const dx = @as(f32, @floatFromInt(x)) - TILE_SIDE / 2 + 0.5;
            const dy = @as(f32, @floatFromInt(y)) - TILE_SIDE / 2 + 0.5;
            const dd = dx * dx + dy * dy;
            if (dd < (TILE_SIDE * TILE_SIDE) / 4) {
                const asdf = &screen_buffer[y + tile.j * TILE_SIDE][x + tile.i * TILE_SIDE];
                asdf[0] = color.r;
                asdf[1] = color.g;
                asdf[2] = color.b;
                asdf[3] = 255;
            }
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

var game_started = false;
var global_t: f32 = 0;
export fn frame(delta_seconds: f32) void {
    if (!game_started) {
        game_started = true;
        reset_game();
    }
    global_t += delta_seconds;

    turn_offset += delta_seconds;
    while (turn_offset >= 1) {
        turn_offset -= 1;
        turn += 1;

        const dir: Direction = if (turn == 3) .Down else .Right;
        const new_head_pos = head_pos.plus(dir);
        tileAt(head_pos).body_segment.out_dir = dir;

        tileAt(new_head_pos).* = TileState{ .body_segment = .{
            .visited_at = turn,
            .in_dir = .Left,
            .out_dir = null,
        } };
        head_pos = new_head_pos;
    }
}

fn tileAt(pos: Vec2i) *TileState {
    return &board_state[pos.j][pos.i];
}

fn reset_game() void {
    board_state[0][0] = .bomb;
    head_pos = Vec2i{ .i = 0, .j = 1 };
    tileAt(head_pos).* = TileState{ .body_segment = .{
        .visited_at = 0,
        .in_dir = .Left,
        .out_dir = null,
    } };
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

    for (board_state, 0..) |board_row, j| {
        for (board_row, 0..) |board_tile, i| {
            drawBoardTile(.{ .i = i, .j = j }, board_tile);
        }
    }

    return @ptrCast(&screen_buffer);
}
