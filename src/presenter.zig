const LayerStuff = @import("domain.zig").LayerStuff;
const Game = @import("domain.zig").Game;
const Drawer = @import("domain.zig").Drawer;
const Direction = @import("domain.zig").Direction;

pub const KeyCode = enum(u32) {
    KeyW,
    KeyS,
    KeyA,
    KeyD,
};

pub fn OuterLayer(
    comptime asdf: LayerStuff,
    consoleLog: fn (arg: u32) callconv(.C) void,
) type {
    return struct {
        game: Game,
        drawer: Drawer(asdf),

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
            @TypeOf(self.drawer).draw(self.game);
        }
    };
}
