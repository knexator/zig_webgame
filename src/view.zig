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

const OuterLayer = @import("presenter.zig").OuterLayer;
const KeyCode = @import("presenter.zig").KeyCode;

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
}, consoleLog).init();

export fn keydown(code: KeyCode) void {
    global_thing.keydown(code);
}

export fn frame(delta_seconds: f32) void {
    global_thing.frame(delta_seconds);
}

export fn draw() void {
    global_thing.draw();
}
