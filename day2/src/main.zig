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
}

test "Sameness check" {
    for (0..10_000) |i| {
        if (isRepeatedTwice(i)) std.debug.print("{any}\n", .{i});
    }
}

pub fn howManyTwiceRepated(start: u64, end: u64) u64 {
    // 0..100
    // 1 1... 9 9 // 9
    // {num}{num} // count: 0 .. num
    //
    // Start point format {num1}{num2}
    // 1. Convert start to {num}{num} if (num2 < num1) increase num2 til num1 == num2 else num1 + 1 and num2 == num1
    //
    // End point format {num1}{num2}
    // 2. Convert end to {num}{num} if (num1 < num2) decrease num1 til num1 == num2 else num1 - 1 and num2 == num1
    //
    // count == (end point num) - (start point num)
    //
    // 100 -> 10/10
    // 9 -> 9/9
}

const Number = struct { upper_half: u64, bottom_half: u64 };

pub fn splitNumber() Number {}

pub fn isRepeatedTwice(num: u64) bool {
    const num_width: u64 = init: {
        var copy: u64 = num;

        var i: u6 = 0;
        while (copy > 0) : (i += 1) {
            copy /= 10;
        }

        break :init i;
    };

    if (1 & num_width == 1) return false;

    const bottom_half = init: {
        var copy: u64 = num;
        for (0..num_width >> 1) |_| {
            copy /= 10;
        }

        break :init copy;
    };

    const top_half = init: {
        var copy: u64 = bottom_half;
        for (0..num_width >> 1) |_| {
            copy *= 10;
        }

        break :init copy;
    };

    return top_half == (num - bottom_half);
}
