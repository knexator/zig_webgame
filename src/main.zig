extern fn consoleLog(arg: u32) void;

const Direction = enum {
    Left,
    Right,
    Up,
    Down,

    fn dir2num(d: Direction) u32 {
        return switch (d) {
            .Up => 0,
            .Down => 1,
            .Left => 2,
            .Right => 3,
        };
    }

    fn num2dir(n: u32) Direction {
        return switch (n) {
            0 => .Up,
            1 => .Down,
            2 => .Left,
            3 => .Right,
            else => unreachable,
        };
    }
};

var my_global_value: Direction = undefined;

export fn buggy(new_value: u32) void {
    consoleLog(new_value);
    my_global_value = Direction.num2dir(new_value);
    consoleLog(Direction.dir2num(my_global_value));
}
