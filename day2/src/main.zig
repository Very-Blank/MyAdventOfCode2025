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

    const sum = try sumAllTwiceNumbers(buffer);
    std.debug.print("{any}\n", .{sum});
}

test "First star, does zero count match with example?" {
    const buffer = "11-22,95-115,998-1012,1188511880-1188511890,222220-222224,1698522-1698528,446443-446449,38593856-38593862,565653-565659,824824821-824824827,2121212118-2121212124";

    try std.testing.expectEqual(1227775554, sumAllTwiceNumbers(buffer));
}

pub fn sumAllTwiceNumbers(buffer: []const u8) !u64 {
    var start: usize = 0;
    var middle: usize = 0;
    var end: usize = 0;

    var sum: u64 = 0;

    state: switch (enum { reset, get_ranges, read_ranges }.get_ranges) {
        .reset => {
            end += 1;
            start = end;

            if (end < buffer.len) continue :state .get_ranges;

            break :state;
        },
        .get_ranges => {
            end += 1;
            if (end == buffer.len) {
                if (3 <= end - start and start < middle and middle < end) continue :state .read_ranges;
                break :state;
            }

            std.debug.assert(end < buffer.len);

            switch (buffer[end]) {
                ',', '\n' => {
                    if (!(start < middle and middle < end)) return error.InvalidInput;

                    continue :state .read_ranges;
                },
                '-' => middle = end,
                else => {},
            }

            continue :state .get_ranges;
        },
        .read_ranges => {
            const lower_bound = try asciiToNum(buffer[start..middle]);
            const higher_bound = try asciiToNum(buffer[middle + 1 .. end]);

            sum += sumTwiceNumbers(lower_bound, higher_bound);

            continue :state .reset;
        },
    }

    return sum;
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

pub fn sumTwiceNumbers(lower_bound: u64, higher_bound: u64) u64 {
    const num_width: u64 = init: {
        var copy: u64 = lower_bound;

        var i: u6 = 0;
        while (copy > 0) : (i += 1) {
            copy /= 10;
        }

        break :init @max(1, i);
    };

    var sum: u64 = 0;

    var base: u64 = init: {
        const half_num_width = num_width >> 1;

        if (num_width & 1 == 1) {
            var base: u64 = 1;
            for (0..half_num_width) |_| {
                base *= 10;
            }

            break :init base;
        }

        var upper_half: u64 = lower_bound;
        for (0..half_num_width) |_| {
            upper_half /= 10;
        }

        var upper_half_raised: u64 = upper_half;
        for (0..half_num_width) |_| {
            upper_half_raised *= 10;
        }

        const lower_half = lower_bound - upper_half_raised;

        if (upper_half < lower_half) break :init upper_half + 1;

        break :init upper_half;
    };

    var offset: u64 = 1;
    while (true) : (base += 1) {
        while (offset <= base) {
            offset *= 10;
        }

        const repeated_number = base * offset + base;

        if (repeated_number <= higher_bound) {
            sum += repeated_number;
        }

        if (higher_bound <= repeated_number) {
            break;
        }
    }

    return sum;
}
