extern fn consoleLog(arg: u32) void;
extern fn fillTile_native(i: usize, j: usize, r: u8, g: u8, b: u8) void;
extern fn fillTile_float_native(i: f32, j: f32, r: u8, g: u8, b: u8) void;
extern fn fillTileWithCircle_native(i: usize, j: usize, r: u8, g: u8, b: u8) void;
extern fn drawSnakeCorner_native(i: usize, j: usize, di_in: i8, dj_in: i8, di_out: i8, dj_out: i8, r: u8, g: u8, b: u8) void;
extern fn drawSnakeCorner_float_native(i: f32, j: f32, di_in: i8, dj_in: i8, di_out: i8, dj_out: i8, r: u8, g: u8, b: u8) void;
extern fn drawSnakeHead_native(i: usize, j: usize, di_in: i8, dj_in: i8, r: u8, g: u8, b: u8) void;
extern fn drawSnakeHead_float_native(i: f32, j: f32, di_in: i8, dj_in: i8, r: u8, g: u8, b: u8) void;
extern fn drawSnakeScarf_first_native(t: f32, i: usize, j: usize, di_in: i8, dj_in: i8, di_out: i8, dj_out: i8, r: u8, g: u8, b: u8) void;
extern fn drawSnakeScarf_last_native(t: f32, i: usize, j: usize, di_in: i8, dj_in: i8, di_out: i8, dj_out: i8, r: u8, g: u8, b: u8) void;

const Game = @import("domain.zig").Game;
const Drawer = @import("domain.zig").Drawer;
const KeyCode = @import("generate_keycodes_js.zig").KeyCode;
const Direction = @import("domain.zig").Direction;

// .fillTile_native = fillTile_native,
// .fillTile_float_native = fillTile_float_native,
// .fillTileWithCircle_native = fillTileWithCircle_native,
// .drawSnakeCorner_native = drawSnakeCorner_native,
// .drawSnakeCorner_float_native = drawSnakeCorner_float_native,
// .drawSnakeHead_native = drawSnakeHead_native,
// .drawSnakeHead_float_native = drawSnakeHead_float_native,
// .drawSnakeScarf_first_native = drawSnakeScarf_first_native,
// .drawSnakeScarf_last_native = drawSnakeScarf_last_native,

var global_game: Game = undefined;
const global_drawer: Drawer(
    fillTile_native,
    fillTile_float_native,
    fillTileWithCircle_native,
    drawSnakeCorner_native,
    drawSnakeCorner_float_native,
    drawSnakeHead_native,
    drawSnakeHead_float_native,
    drawSnakeScarf_first_native,
    drawSnakeScarf_last_native,
) = .{};

export fn keydown(code: KeyCode) void {
    const maybe_dir: ?Direction = switch (code) {
        .KeyW => .Up,
        .KeyS => .Down,
        .KeyA => .Left,
        .KeyD => .Right,
        // else => null,
    };
    if (maybe_dir) |dir| {
        global_game.input_buffer.append(dir) catch {
            consoleLog(999); // input was lost
        };
    }
}

var game_started = false;
var global_t: f32 = 0;
export fn frame(delta_seconds: f32) void {
    if (!game_started) {
        game_started = true;
        global_game.reset_game();
    }
    global_t += delta_seconds;

    global_game.frame(delta_seconds);
}

export fn draw() void {
    const game = global_game;
    const drawer = global_drawer;

    game.draw(drawer);
}
