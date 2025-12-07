const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

    const allocator: std.mem.Allocator, const is_debug: bool = switch (builtin.mode) {
        .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
        .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
    };

    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    const buffer = try allocator.alloc(u8, try file.getEndPos());
    defer allocator.free(buffer);

    {
        var read_buffer: [100]u8 = undefined;
        var file_reader: std.fs.File.Reader = .init(file, &read_buffer);
        try file_reader.interface.readSliceAll(buffer);
    }

    std.debug.print("{any}\n", .{try getSplitCount(141, buffer)});
}

test "First star, split count match with the example?" {
    const buffer =
        \\.......S.......
        \\...............
        \\.......^.......
        \\...............
        \\......^.^......
        \\...............
        \\.....^.^.^.....
        \\...............
        \\....^.^...^....
        \\...............
        \\...^.^...^.^...
        \\...............
        \\..^...^.....^..
        \\...............
        \\.^.^.^.^.^...^.
        \\...............
    ;

    try std.testing.expectEqual(21, try getSplitCount(15, buffer));
}

pub fn getSplitCount(comptime columns: usize, buffer: []const u8) !u64 {
    var current_beams: [columns]u2 = .{0} ** (columns >> 1) ++ .{1} ++ .{0} ** (columns >> 1);
    var new_beams: [columns]u2 = .{0} ** (columns >> 1) ++ .{1} ++ .{0} ** (columns >> 1);

    var current_column: usize = 0;
    var split_count: u64 = 0;

    for (columns + 1..buffer.len) |i| {
        if (buffer[i] == '^' and current_beams[current_column % columns] == 1) {
            if (current_column % columns == 0) return error.InvalidInput;

            new_beams[(current_column - 1) % columns] = 1;
            new_beams[current_column % columns] = 0;
            new_beams[(current_column + 1) % columns] = 1;

            split_count += 1;
        }

        switch (buffer[i]) {
            '.', '^' => current_column += 1,
            '\n' => {
                current_beams = new_beams;
            },
            else => {},
        }
    }

    current_beams = new_beams;

    return split_count;
}

pub fn asciiToNum(buffer: []const u8) !u64 {
    var num: u64 = 0;
    for (buffer) |char| {
        switch (char) {
            '0'...'9' => num = num * 10 + (char - '0'),
            else => return error.InvalidNumber,
        }
    }

    return num;
}
