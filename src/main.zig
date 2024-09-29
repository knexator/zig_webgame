extern fn consoleLog(arg: u32) void;

const Direction = enum {
    Left,
    Right,
    Up,
    Down,
};

var next_dir: Direction = undefined;

export fn buggy(code: u32) void {
    consoleLog(code);
    switch (code) {
        0 => next_dir = .Up,
        1 => next_dir = .Down,
        2 => next_dir = .Left,
        3 => next_dir = .Right,
        else => {},
    }
    consoleLog(switch (next_dir) {
        .Up => 0,
        .Down => 1,
        .Left => 2,
        .Right => 3,
    });
}
