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

var global_thing = OuterLayer(.{
    .fillTile_native = fillTile_native,
    .fillTile_float_native = fillTile_float_native,
    .fillTileWithCircle_native = fillTileWithCircle_native,
    .drawSnakeCorner_native = drawSnakeCorner_native,
    .drawSnakeCorner_float_native = drawSnakeCorner_float_native,
    .drawSnakeHead_native = drawSnakeHead_native,
    .drawSnakeHead_float_native = drawSnakeHead_float_native,
    .drawSnakeScarf_first_native = drawSnakeScarf_first_native,
    .drawSnakeScarf_last_native = drawSnakeScarf_last_native,
}).init();

export fn keydown(code: KeyCode) void {
    global_thing.keydown(code);
}

export fn frame(delta_seconds: f32) void {
    global_thing.frame(delta_seconds);
}

export fn draw() void {
    global_thing.draw();
}

fn OuterLayer(comptime asdf: struct {
    fillTile_native: fn (i: usize, j: usize, r: u8, g: u8, b: u8) callconv(.C) void,
    fillTile_float_native: fn (i: f32, j: f32, r: u8, g: u8, b: u8) callconv(.C) void,
    fillTileWithCircle_native: fn (i: usize, j: usize, r: u8, g: u8, b: u8) callconv(.C) void,
    drawSnakeCorner_native: fn (i: usize, j: usize, di_in: i8, dj_in: i8, di_out: i8, dj_out: i8, r: u8, g: u8, b: u8) callconv(.C) void,
    drawSnakeCorner_float_native: fn (i: f32, j: f32, di_in: i8, dj_in: i8, di_out: i8, dj_out: i8, r: u8, g: u8, b: u8) callconv(.C) void,
    drawSnakeHead_native: fn (i: usize, j: usize, di_in: i8, dj_in: i8, r: u8, g: u8, b: u8) callconv(.C) void,
    drawSnakeHead_float_native: fn (i: f32, j: f32, di_in: i8, dj_in: i8, r: u8, g: u8, b: u8) callconv(.C) void,
    drawSnakeScarf_first_native: fn (t: f32, i: usize, j: usize, di_in: i8, dj_in: i8, di_out: i8, dj_out: i8, r: u8, g: u8, b: u8) callconv(.C) void,
    drawSnakeScarf_last_native: fn (t: f32, i: usize, j: usize, di_in: i8, dj_in: i8, di_out: i8, dj_out: i8, r: u8, g: u8, b: u8) callconv(.C) void,
}) type {
    return struct {
        game: Game,
        drawer: Drawer(
            asdf.fillTile_native,
            asdf.fillTile_float_native,
            asdf.fillTileWithCircle_native,
            asdf.drawSnakeCorner_native,
            asdf.drawSnakeCorner_float_native,
            asdf.drawSnakeHead_native,
            asdf.drawSnakeHead_float_native,
            asdf.drawSnakeScarf_first_native,
            asdf.drawSnakeScarf_last_native,
        ),

        game_started: bool,
        global_t: f32,

        const Self = @This();

        pub fn init() Self {
            return Self{
                .game = undefined,
                .drawer = .{},
                .game_started = false,
                .global_t = 0,
            };
        }

        pub fn keydown(self: *Self, code: KeyCode) void {
            const maybe_dir: ?Direction = switch (code) {
                .KeyW => .Up,
                .KeyS => .Down,
                .KeyA => .Left,
                .KeyD => .Right,
                // else => null,
            };
            if (maybe_dir) |dir| {
                self.game.input_buffer.append(dir) catch {
                    consoleLog(999); // input was lost
                };
            }
        }

        pub fn frame(self: *Self, delta_seconds: f32) void {
            if (!self.game_started) {
                self.game_started = true;
                self.game.reset_game();
            }
            self.global_t += delta_seconds;
            self.game.frame(delta_seconds);
        }

        pub fn draw(self: Self) void {
            self.game.draw(self.drawer);
        }
    };
}
