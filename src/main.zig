const std = @import("std");
extern fn consoleLog(arg: u32) void;
extern fn fillTile_native(i: usize, j: usize, r: u8, g: u8, b: u8) void;
extern fn fillTile_float_native(i: f32, j: f32, r: u8, g: u8, b: u8) void;
extern fn fillTileWithCircle_native(i: usize, j: usize, r: u8, g: u8, b: u8) void;
extern fn drawSnakeCorner_native(i: usize, j: usize, di_in: i8, dj_in: i8, di_out: i8, dj_out: i8, r: u8, g: u8, b: u8) void;
extern fn drawSnakeCorner_float_native(i: f32, j: f32, di_in: i8, dj_in: i8, di_out: i8, dj_out: i8, r: u8, g: u8, b: u8) void;
extern fn drawSnakeHead_native(i: usize, j: usize, di_in: i8, dj_in: i8, r: u8, g: u8, b: u8) void;
extern fn drawSnakeHead_float_native(i: f32, j: f32, di_in: i8, dj_in: i8, r: u8, g: u8, b: u8) void;

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

const DEBUG_ANIM = false;

const BOARD_SIDE = 16;
const TURN_DURATION = if (DEBUG_ANIM) 0.46 else 0.16;
const ANIM_PERC = if (DEBUG_ANIM) 0.95 else 0.2;

const COLORS = struct {
    BOMB: Color = .{ .r = 237, .g = 56, .b = 21 },
    EXPLOSION: Color = .{ .r = 255, .g = 205, .b = 117 },
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

    fn di(d: Direction) i8 {
        return switch (d) {
            .Left => -1,
            .Right => 1,
            .Up, .Down => 0,
        };
    }

    fn dj(d: Direction) i8 {
        return switch (d) {
            .Down => 1,
            .Up => -1,
            .Left, .Right => 0,
        };
    }
};

const SnakeSegment = struct {
    visited_at: usize,
    in_dir: Direction,
    out_dir: ?Direction,
};
const TileState = union(enum) {
    empty: void,
    bomb: void,
    multiplier: void,
    // clock: ... TODO
    body_segment: SnakeSegment,
};

var rnd_implementation: std.rand.DefaultPrng = undefined;
var rnd: std.rand.Random = undefined;
var turn: usize = undefined;
var turn_offset: f32 = undefined;
var board_state: [BOARD_SIDE][BOARD_SIDE]TileState = undefined;
var head_pos: BoardPosition = undefined;
var input_buffer = CircularBuffer(Direction, 32){};
var cur_explosion_particle: ?BoardPosition = undefined;

fn reset_game() void {
    rnd_implementation = std.rand.DefaultPrng.init(0);
    rnd = rnd_implementation.random();

    turn = 1;
    turn_offset = 0;
    board_state = .{.{TileState.empty} ** BOARD_SIDE} ** BOARD_SIDE;
    head_pos = BoardPosition{ .i = 1, .j = 1 };
    tileAt(head_pos.plus(.Left)).* = TileState{ .body_segment = .{
        .visited_at = turn - 1,
        .in_dir = .Left,
        .out_dir = .Right,
    } };
    tileAt(head_pos).* = TileState{ .body_segment = .{
        .visited_at = turn,
        .in_dir = .Left,
        .out_dir = null,
    } };
    input_buffer.clear();
    cur_explosion_particle = null;

    for (0..3) |_| placeBomb();
}

fn drawBoardTile(pos: BoardPosition, tile: TileState) void {
    switch (tile) {
        .empty => {},
        .bomb => fillTileWithCircle(pos, COLORS.BOMB),
        .body_segment => |body| if (body.visited_at == turn) {
            // head: drawn later
        } else if (body.visited_at + 1 == turn) {
            // scarf: drawn later
        } else {
            // body
            drawSnakeSegment(pos, body, if ((pos.i + pos.j) % 2 == 0) COLORS.SNAKE.BODY1 else COLORS.SNAKE.BODY2);
        },
        else => {},
    }
}

// TODO: better
fn drawSnakeHeadAndScarf() void {
    const in_dir = tileAt(head_pos).body_segment.in_dir;

    if (cur_explosion_particle == null) {
        const scarf_pos = head_pos.plus(in_dir);
        const scarf = tileAt(scarf_pos).body_segment;
        if (turn_offset < ANIM_PERC) {
            if (scarf.in_dir.opposite() == scarf.out_dir.?) {
                fillTile_float(scarf_pos.plus_fractional(scarf.in_dir, 1 - turn_offset / ANIM_PERC), COLORS.SNAKE.SCARF);
            } else {
                drawSnakeCorner(scarf_pos, scarf.in_dir, scarf.out_dir.?, COLORS.SNAKE.SCARF);
                fillTile_float(scarf_pos.plus_fractional(scarf.in_dir, 1 - turn_offset / ANIM_PERC), COLORS.SNAKE.SCARF);
            }
        } else {
            if (scarf.in_dir.opposite() == scarf.out_dir.?) {
                fillTile(scarf_pos, COLORS.SNAKE.SCARF);
            } else {
                drawSnakeCorner(scarf_pos, scarf.in_dir, scarf.out_dir.?, COLORS.SNAKE.SCARF);
            }
        }
    }

    if (turn_offset < ANIM_PERC) {
        const color = COLORS.SNAKE.HEAD;
        const lerped_pos = head_pos.plus_fractional(in_dir, 1.0 - (turn_offset / ANIM_PERC));
        drawSnakeHead_float_native(lerped_pos.i, lerped_pos.j, in_dir.di(), in_dir.dj(), color.r, color.g, color.b);
    } else {
        drawSnakeHead(head_pos, in_dir, COLORS.SNAKE.HEAD);
    }
}

fn drawSnakeSegment(pos: BoardPosition, body: SnakeSegment, color: Color) void {
    if (body.out_dir == null) {
        if (turn_offset < TURN_DURATION) {} else {
            drawSnakeHead(pos, body.in_dir, color);
        }
    } else if (body.in_dir.opposite() == body.out_dir.?) {
        fillTile(pos, color);
    } else {
        drawSnakeCorner(pos, body.in_dir, body.out_dir.?, color);
    }
}

const BoardPositionFractional = struct {
    i: f32,
    j: f32,
};

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

    fn plus_fractional(vec: Self, dir: Direction, scale: f32) BoardPositionFractional {
        return BoardPositionFractional{
            .i = @mod(@as(f32, @floatFromInt(vec.i)) + @as(f32, @floatFromInt(dir.di())) * scale, BOARD_SIDE),
            .j = @mod(@as(f32, @floatFromInt(vec.j)) + @as(f32, @floatFromInt(dir.dj())) * scale, BOARD_SIDE),
        };
    }
};

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

fn fillTile(tile: BoardPosition, color: Color) void {
    fillTile_native(tile.i, tile.j, color.r, color.g, color.b);
}

fn fillTile_float(tile: BoardPositionFractional, color: Color) void {
    fillTile_float_native(tile.i, tile.j, color.r, color.g, color.b);
}

fn fillTileWithCircle(tile: BoardPosition, color: Color) void {
    fillTileWithCircle_native(tile.i, tile.j, color.r, color.g, color.b);
}

fn drawSnakeCorner(tile: BoardPosition, dir_in: Direction, dir_out: Direction, color: Color) void {
    drawSnakeCorner_native(tile.i, tile.j, dir_in.di(), dir_in.dj(), dir_out.di(), dir_out.dj(), color.r, color.g, color.b);
}

fn drawSnakeHead(tile: BoardPosition, dir_in: Direction, color: Color) void {
    drawSnakeHead_native(tile.i, tile.j, dir_in.di(), dir_in.dj(), color.r, color.g, color.b);
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
        cur_explosion_particle = null;

        const default_dir = Direction.opposite(tileAt(head_pos).body_segment.in_dir);
        var next_dir: Direction = input_buffer.popFirst() orelse default_dir;
        while (next_dir == Direction.opposite(default_dir)) {
            next_dir = input_buffer.popFirst() orelse default_dir;
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

    cur_explosion_particle = pos;

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

export fn draw() void {
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

    if (cur_explosion_particle) |explosion_pos| {
        for (0..BOARD_SIDE) |j| {
            for (0..BOARD_SIDE) |i| {
                if (i == explosion_pos.i or j == explosion_pos.j) {
                    fillTile(.{ .i = i, .j = j }, COLORS.EXPLOSION);
                }
            }
        }
    }

    for (board_state, 0..) |board_row, j| {
        for (board_row, 0..) |board_tile, i| {
            drawBoardTile(.{ .i = i, .j = j }, board_tile);
        }
    }

    drawSnakeHeadAndScarf();
}
