const std = @import("std");

const CircularBuffer = @import("./circular_buffer.zig").CircularBuffer;

test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(@import("./circular_buffer.zig"));
}

const DEBUG_ANIM = false;

const BOARD_SIDE = 16;
const TURN_DURATION = if (DEBUG_ANIM) 2.0 else 0.16;
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

pub const Direction = enum(u8) {
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

pub const LayerStuff = struct {
    fillTile_native: fn (i: usize, j: usize, r: u8, g: u8, b: u8) callconv(.C) void,
    fillTile_float_native: fn (i: f32, j: f32, r: u8, g: u8, b: u8) callconv(.C) void,
    fillTileWithCircle_native: fn (i: usize, j: usize, r: u8, g: u8, b: u8) callconv(.C) void,
    drawSnakeCorner_native: fn (i: usize, j: usize, di_in: i8, dj_in: i8, di_out: i8, dj_out: i8, r: u8, g: u8, b: u8) callconv(.C) void,
    drawSnakeCorner_float_native: fn (i: f32, j: f32, di_in: i8, dj_in: i8, di_out: i8, dj_out: i8, r: u8, g: u8, b: u8) callconv(.C) void,
    drawSnakeHead_native: fn (i: usize, j: usize, di_in: i8, dj_in: i8, r: u8, g: u8, b: u8) callconv(.C) void,
    drawSnakeHead_float_native: fn (i: f32, j: f32, di_in: i8, dj_in: i8, r: u8, g: u8, b: u8) callconv(.C) void,
    drawSnakeScarf_first_native: fn (t: f32, i: usize, j: usize, di_in: i8, dj_in: i8, di_out: i8, dj_out: i8, r: u8, g: u8, b: u8) callconv(.C) void,
    drawSnakeScarf_last_native: fn (t: f32, i: usize, j: usize, di_in: i8, dj_in: i8, di_out: i8, dj_out: i8, r: u8, g: u8, b: u8) callconv(.C) void,
};

pub fn Drawer(comptime asdf: LayerStuff) type {
    return struct {
        const Self = @This();

        fn fillTile(tile: BoardPosition, color: Color) void {
            asdf.fillTile_native(tile.i, tile.j, color.r, color.g, color.b);
        }

        fn fillTile_float(tile: BoardPositionFractional, color: Color) void {
            asdf.fillTile_float_native(tile.i, tile.j, color.r, color.g, color.b);
        }

        fn fillTileWithCircle(tile: BoardPosition, color: Color) void {
            asdf.fillTileWithCircle_native(tile.i, tile.j, color.r, color.g, color.b);
        }

        fn drawSnakeCorner(tile: BoardPosition, dir_in: Direction, dir_out: Direction, color: Color) void {
            asdf.drawSnakeCorner_native(tile.i, tile.j, dir_in.di(), dir_in.dj(), dir_out.di(), dir_out.dj(), color.r, color.g, color.b);
        }

        fn drawSnakeHead(tile: BoardPosition, dir_in: Direction, color: Color) void {
            asdf.drawSnakeHead_native(tile.i, tile.j, dir_in.di(), dir_in.dj(), color.r, color.g, color.b);
        }

        fn drawBoardTile(game: Game, pos: BoardPosition, tile: TileState) void {
            switch (tile) {
                .empty => {},
                .bomb => Self.fillTileWithCircle(pos, COLORS.BOMB),
                .body_segment => |body| if (body.visited_at == game.turn) {
                    // head: drawn later
                } else if (body.visited_at + 1 == game.turn) {
                    // scarf: drawn later
                } else {
                    // body
                    Self.drawSnakeSegment(game, pos, body, if ((pos.i + pos.j) % 2 == 0) COLORS.SNAKE.BODY1 else COLORS.SNAKE.BODY2);
                },
                else => {},
            }
        }

        fn drawSnakeHeadAndScarf(game: Game) void {
            const in_dir = game.tileAtConst(game.head_pos).body_segment.in_dir;

            if (game.cur_explosion_particle == null) {
                const scarf_pos = game.head_pos.plus(in_dir);
                const scarf = game.tileAtConst(scarf_pos).body_segment;
                const color = COLORS.SNAKE.SCARF;
                if (game.turn_offset < ANIM_PERC) {
                    asdf.drawSnakeScarf_first_native(game.turn_offset / ANIM_PERC, scarf_pos.i, scarf_pos.j, scarf.in_dir.di(), scarf.in_dir.dj(), scarf.out_dir.?.di(), scarf.out_dir.?.dj(), color.r, color.g, color.b);

                    const prev_scarf_pos = scarf_pos.plus(scarf.in_dir);
                    const prev_scarf = game.tileAtConst(prev_scarf_pos).body_segment;
                    asdf.drawSnakeScarf_last_native(game.turn_offset / ANIM_PERC, prev_scarf_pos.i, prev_scarf_pos.j, prev_scarf.in_dir.di(), prev_scarf.in_dir.dj(), prev_scarf.out_dir.?.di(), prev_scarf.out_dir.?.dj(), color.r, color.g, color.b);
                } else {
                    if (scarf.in_dir.opposite() == scarf.out_dir.?) {
                        Self.fillTile(scarf_pos, color);
                    } else {
                        Self.drawSnakeCorner(scarf_pos, scarf.in_dir, scarf.out_dir.?, color);
                    }
                }
            }

            if (game.turn_offset < ANIM_PERC) {
                const color = COLORS.SNAKE.HEAD;
                const lerped_pos = game.head_pos.plus_fractional(in_dir, 1.0 - (game.turn_offset / ANIM_PERC));
                asdf.drawSnakeHead_float_native(lerped_pos.i, lerped_pos.j, in_dir.di(), in_dir.dj(), color.r, color.g, color.b);
            } else {
                Self.drawSnakeHead(game.head_pos, in_dir, COLORS.SNAKE.HEAD);
            }
        }

        fn drawSnakeSegment(game: Game, pos: BoardPosition, body: SnakeSegment, color: Color) void {
            if (body.out_dir == null) {
                if (game.turn_offset < TURN_DURATION) {} else {
                    Self.drawSnakeHead(pos, body.in_dir, color);
                }
            } else if (body.in_dir.opposite() == body.out_dir.?) {
                Self.fillTile(pos, color);
            } else {
                Self.drawSnakeCorner(pos, body.in_dir, body.out_dir.?, color);
            }
        }

        pub fn draw(game: Game) void {
            for (0..BOARD_SIDE) |j| {
                for (0..BOARD_SIDE) |i| {
                    Self.fillTile(.{ .i = i, .j = j }, if ((i + j) % 2 == 0)
                        COLORS.BACKGROUND.MAIN
                    else if ((i + j + 1) % 4 == 0)
                        COLORS.BACKGROUND.DIAG1
                    else
                        COLORS.BACKGROUND.DIAG2);
                }
            }

            if (game.cur_explosion_particle) |explosion_pos| {
                for (0..BOARD_SIDE) |j| {
                    for (0..BOARD_SIDE) |i| {
                        if (i == explosion_pos.i or j == explosion_pos.j) {
                            Self.fillTile(.{ .i = i, .j = j }, COLORS.EXPLOSION);
                        }
                    }
                }
            }

            for (game.board_state, 0..) |board_row, j| {
                for (board_row, 0..) |board_tile, i| {
                    Self.drawBoardTile(game, .{ .i = i, .j = j }, board_tile);
                }
            }

            Self.drawSnakeHeadAndScarf(game);
        }
    };
}

pub const Game = struct {
    rnd_implementation: std.rand.DefaultPrng,
    rnd: std.rand.Random,
    turn: usize,
    turn_offset: f32,
    board_state: [BOARD_SIDE][BOARD_SIDE]TileState,
    head_pos: BoardPosition,
    input_buffer: CircularBuffer(Direction, 32),
    cur_explosion_particle: ?BoardPosition,

    pub fn reset_game(game: *Game) void {
        game.rnd_implementation = std.rand.DefaultPrng.init(0);
        game.rnd = game.rnd_implementation.random();

        game.turn = 1;
        game.turn_offset = 0;
        game.board_state = .{.{TileState.empty} ** BOARD_SIDE} ** BOARD_SIDE;
        game.head_pos = BoardPosition{ .i = 1, .j = 1 };
        game.tileAt(game.head_pos.plus(.Left)).* = TileState{ .body_segment = .{
            .visited_at = game.turn - 1,
            .in_dir = .Left,
            .out_dir = .Right,
        } };
        game.tileAt(game.head_pos).* = TileState{ .body_segment = .{
            .visited_at = game.turn,
            .in_dir = .Left,
            .out_dir = null,
        } };
        game.input_buffer.clear();
        game.cur_explosion_particle = null;

        for (0..3) |_| game.placeBomb();
    }

    pub fn frame(game: *Game, delta_seconds: f32) void {
        game.turn_offset += delta_seconds / TURN_DURATION;
        while (game.turn_offset >= 1) {
            game.turn_offset -= 1;
            game.turn += 1;
            game.cur_explosion_particle = null;

            const default_dir = Direction.opposite(game.tileAt(game.head_pos).body_segment.in_dir);
            var next_dir: Direction = game.input_buffer.popFirst() orelse default_dir;
            while (next_dir == Direction.opposite(default_dir)) {
                next_dir = game.input_buffer.popFirst() orelse default_dir;
            }
            const new_head_pos = game.head_pos.plus(next_dir);
            game.tileAt(game.head_pos).*.body_segment.out_dir = next_dir;

            switch (game.tileAt(new_head_pos).*) {
                .body_segment => {
                    game.reset_game();
                    return;
                },
                .bomb => game.explodeBombAt(new_head_pos),
                else => {},
            }

            game.tileAt(new_head_pos).* = TileState{ .body_segment = .{
                .visited_at = game.turn,
                .in_dir = Direction.opposite(next_dir),
                .out_dir = null,
            } };
            game.head_pos = new_head_pos;
        }
    }

    fn placeBomb(game: *Game) void {
        // place bomb
        const LUCK = 5;
        var candidates: [LUCK]BoardPosition = undefined;
        var scores: [LUCK]u8 = undefined;
        for (0..LUCK) |i| {
            candidates[i] = game.findEmptySpot();
            scores[i] = game.visibleWallsAt(candidates[i]);
        }
        const new_bomb_pos = candidates[std.sort.argMax(u8, &scores, {}, std.sort.asc(u8)).?];
        game.tileAt(new_bomb_pos).* = .{ .bomb = {} };
    }

    pub fn explodeBombAt(game: *Game, pos: BoardPosition) void {
        // erase body segments
        for (0..BOARD_SIDE) |j| {
            for (0..BOARD_SIDE) |i| {
                if (i == pos.i or j == pos.j) {
                    const cur_pos = BoardPosition{ .i = i, .j = j };
                    switch (game.tileAt(cur_pos).*) {
                        .body_segment => {
                            game.tileAt(cur_pos).* = .{ .empty = {} };
                        },
                        else => {},
                    }
                }
            }
        }
        game.cur_explosion_particle = pos;
        game.placeBomb();
    }

    fn findEmptySpot(game: *Game) BoardPosition {
        var pos: BoardPosition = undefined;

        while (true) {
            pos = BoardPosition{
                .i = game.rnd.intRangeLessThanBiased(usize, 0, BOARD_SIDE),
                .j = game.rnd.intRangeLessThanBiased(usize, 0, BOARD_SIDE),
            };
            if (switch (game.tileAt(pos).*) {
                .empty => false,
                else => true,
            }) continue;
            // if (head_pos.isNextTo(pos)) continue;

            return pos;
        }
    }

    pub fn tileAt(game: *Game, pos: BoardPosition) *TileState {
        return &game.board_state[pos.j][pos.i];
    }

    pub fn tileAtConst(game: *const Game, pos: BoardPosition) *const TileState {
        return &game.board_state[pos.j][pos.i];
    }

    fn visibleWallsAt(game: *Game, pos: BoardPosition) u8 {
        var walls: u8 = 0;
        for (0..BOARD_SIDE) |j| {
            for (0..BOARD_SIDE) |i| {
                if (i == pos.i or j == pos.j) {
                    switch (game.tileAt(.{ .i = i, .j = j }).*) {
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
};

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
