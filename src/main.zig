const std = @import("std");
extern fn consoleLog(arg: u32) void;

const CircularBuffer = @import("./circular_buffer.zig").CircularBuffer;

// test external stuff
comptime {
    _ = @import("./circular_buffer.zig");
}

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
const TURN_DURATION = 0.16;

const COLORS = struct {
    BOMB: Color = .{ .r = 237, .g = 56, .b = 21 },
    SNAKE: struct {
        HEAD: Color = Color{ .r = 133, .g = 206, .b = 54 },
        BODY1: Color = Color{ .r = 128, .g = 197, .b = 53 },
        BODY2: Color = Color{ .r = 106, .g = 163, .b = 44 },
        SCARF: Color = Color{ .r = 86, .g = 126, .b = 42 },
    } = .{},
    BACKGROUND: struct {
        MAIN: Color = Color{ .r = 33, .g = 54, .b = 54 },
        DIAG1: Color = Color{ .r = 32, .g = 60, .b = 60 },
        DIAG2: Color = Color{ .r = 37, .g = 61, .b = 61 },
    } = .{},
}{};

// const COLORS = struct {
//     BOMB: Color,
// }{
//     .BOMB = Color{ .r = 237, .g = 56, .b = 21 },
// };

const Direction = enum(u8) {
    Left,
    Right,
    Up,
    Down,

    fn opposite(d: Direction) Direction {
        return switch (d) {
            .Left => .Right,
            .Right => .Left,
            .Down => .Up,
            .Up => .Down,
        };
    }
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

var rnd_implementation: std.rand.DefaultPrng = undefined;
var rnd: std.rand.Random = undefined;
var turn: usize = undefined;
var turn_offset: f32 = undefined;
var board_state: [BOARD_SIDE][BOARD_SIDE]TileState = undefined;
var head_pos: BoardPosition = undefined;
var input_buffer = CircularBuffer(Direction, 32){};

fn reset_game() void {
    rnd_implementation = std.rand.DefaultPrng.init(0);
    rnd = rnd_implementation.random();

    turn = 0;
    turn_offset = 0;
    board_state = .{.{TileState.empty} ** BOARD_SIDE} ** BOARD_SIDE;
    head_pos = BoardPosition{ .i = 0, .j = 1 };
    tileAt(head_pos).* = TileState{ .body_segment = .{
        .visited_at = turn,
        .in_dir = .Left,
        .out_dir = null,
    } };
    input_buffer.clear();

    for (0..3) |_| placeBomb();
}

fn drawBoardTile(pos: BoardPosition, tile: TileState) void {
    switch (tile) {
        .empty => {},
        .bomb => fillTileWithCircle(pos, COLORS.BOMB),
        .body_segment => |body| fillTile(pos, if (body.out_dir == null)
            COLORS.SNAKE.HEAD
        else if (body.visited_at + 1 == turn)
            COLORS.SNAKE.SCARF
        else if ((pos.i + pos.j) % 2 == 0) COLORS.SNAKE.BODY1 else COLORS.SNAKE.BODY2),
        else => {},
    }
}

const BoardPosition = struct {
    const Self = @This();

    i: usize,
    j: usize,

    fn eq(a: Self, b: Self) bool {
        return a.i == b.i and a.j == b.j;
    }

    fn plus(vec: Self, dir: Direction) Self {
        return switch (dir) {
            .Right => BoardPosition{ .i = _inc(vec.i), .j = vec.j },
            .Left => BoardPosition{ .i = _dec(vec.i), .j = vec.j },
            .Down => BoardPosition{ .i = vec.i, .j = _inc(vec.j) },
            .Up => BoardPosition{ .i = vec.i, .j = _dec(vec.j) },
        };
    }

    fn wrap(vec: Self) Self {
        return BoardPosition{ .i = vec.i % BOARD_SIDE, .j = vec.j % BOARD_SIDE };
    }

    fn _inc(v: usize) usize {
        return @mod(v + 1, BOARD_SIDE);
    }

    fn _dec(v: usize) usize {
        if (v == 0) {
            return BOARD_SIDE - 1;
        } else {
            return v - 1;
        }
    }
};

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

fn fillTile(tile: BoardPosition, color: Color) void {
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

// OPTIMIZE, maybe
fn fillTileWithCircle(tile: BoardPosition, color: Color) void {
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
    const maybe_dir: ?Direction = switch (code) {
        0 => .Up,
        1 => .Down,
        2 => .Left,
        3 => .Right,
        else => null,
    };
    if (maybe_dir) |dir| {
        input_buffer.append(dir) catch {
            consoleLog(999); // input was lost
        };
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

    turn_offset += delta_seconds / TURN_DURATION;
    while (turn_offset >= 1) {
        turn_offset -= 1;
        turn += 1;

        const default_dir = Direction.opposite(tileAt(head_pos).body_segment.in_dir);
        var next_dir: Direction = input_buffer.popFirst() orelse default_dir;
        if (next_dir == tileAt(head_pos).body_segment.in_dir) {
            next_dir = default_dir;
        }
        const new_head_pos = head_pos.plus(next_dir);
        tileAt(head_pos).*.body_segment.out_dir = next_dir;

        switch (tileAt(new_head_pos).*) {
            .body_segment => {
                reset_game();
                return;
            },
            .bomb => explodeBombAt(new_head_pos),
            else => {},
        }

        tileAt(new_head_pos).* = TileState{ .body_segment = .{
            .visited_at = turn,
            .in_dir = Direction.opposite(next_dir),
            .out_dir = null,
        } };
        head_pos = new_head_pos;
    }
}

fn explodeBombAt(pos: BoardPosition) void {
    // erase body segments
    for (0..BOARD_SIDE) |j| {
        for (0..BOARD_SIDE) |i| {
            if (i == pos.i or j == pos.j) {
                const cur_pos = BoardPosition{ .i = i, .j = j };
                switch (tileAt(cur_pos).*) {
                    .body_segment => {
                        tileAt(cur_pos).* = .{ .empty = {} };
                    },
                    else => {},
                }
            }
        }
    }

    placeBomb();
}

fn placeBomb() void {
    // place bomb
    const LUCK = 5;
    var candidates: [LUCK]BoardPosition = undefined;
    var scores: [LUCK]u8 = undefined;
    for (0..LUCK) |i| {
        candidates[i] = findEmptySpot();
        scores[i] = visibleWallsAt(candidates[i]);
    }
    const new_bomb_pos = candidates[std.sort.argMax(u8, &scores, {}, std.sort.asc(u8)).?];
    tileAt(new_bomb_pos).* = .{ .bomb = {} };
}

fn visibleWallsAt(pos: BoardPosition) u8 {
    var walls: u8 = 0;
    for (0..BOARD_SIDE) |j| {
        for (0..BOARD_SIDE) |i| {
            if (i == pos.i or j == pos.j) {
                switch (tileAt(.{ .i = i, .j = j }).*) {
                    .body_segment => {
                        walls += 1;
                    },
                    else => {},
                }
            }
        }
    }
    return walls;
}

fn findEmptySpot() BoardPosition {
    var pos: BoardPosition = undefined;

    while (true) {
        pos = BoardPosition{
            .i = rnd.intRangeLessThanBiased(usize, 0, BOARD_SIDE),
            .j = rnd.intRangeLessThanBiased(usize, 0, BOARD_SIDE),
        };
        if (switch (tileAt(pos).*) {
            .empty => false,
            else => true,
        }) continue;
        // if (head_pos.isNextTo(pos)) continue;

        return pos;
    }
}

fn tileAt(pos: BoardPosition) *TileState {
    return &board_state[pos.j][pos.i];
}

export fn draw() [*]u8 {
    for (&screen_buffer) |*row| {
        for (row) |*square| {
            square.*[0] = 0;
            square.*[1] = 0;
            square.*[2] = 0;
            square.*[3] = 255;
        }
    }

    for (0..BOARD_SIDE) |j| {
        for (0..BOARD_SIDE) |i| {
            fillTile(.{ .i = i, .j = j }, if ((i + j) % 2 == 0)
                COLORS.BACKGROUND.MAIN
            else if ((i + j + 1) % 4 == 0)
                COLORS.BACKGROUND.DIAG1
            else
                COLORS.BACKGROUND.DIAG2);
        }
    }

    for (board_state, 0..) |board_row, j| {
        for (board_row, 0..) |board_tile, i| {
            drawBoardTile(.{ .i = i, .j = j }, board_tile);
        }
    }

    return @ptrCast(&screen_buffer);
}
