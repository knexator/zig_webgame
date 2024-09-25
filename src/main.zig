const std = @import("std");

export fn getPixel(x: f32, y: f32, c: i32) i32 {
    _ = x; // autofix
    _ = y; // autofix
    return switch (c) {
        0 => 255,
        1 => 128,
        2 => 0,
        else => unreachable,
    };
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
