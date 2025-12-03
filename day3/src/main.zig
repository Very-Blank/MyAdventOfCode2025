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

    const sum = try getMaxJoltage(buffer);
    std.debug.print("{any}\n", .{sum});
}

test "First star, does zero count match with example?" {
    const buffer =
        \\987654321111111
        \\811111111111119
        \\234234234234278
        \\818181911112111
    ;

    try std.testing.expectEqual(357, getMaxJoltage(buffer));
}

pub fn getMaxJoltage(buffer: []const u8) !u64 {
    var start: usize = 0;
    var end: usize = 0;

    var joltage: u64 = 0;

    state: switch (enum { reset, get_batteries, read_joltages }.get_batteries) {
        .reset => {
            end += 1;
            start = end;

            if (end < buffer.len) continue :state .get_batteries;

            break :state;
        },
        .get_batteries => {
            end += 1;
            if (end == buffer.len) {
                if (3 <= end - start) continue :state .read_joltages;
                break :state;
            }

            std.debug.assert(end < buffer.len);

            if (buffer[end] == '\n') {
                continue :state .read_joltages;
            }

            continue :state .get_batteries;
        },
        .read_joltages => {
            // std.debug.print("\n", .{});
            // std.debug.print("{s}:\n", .{buffer[start..end]});

            var first_battery: u8 = 0;
            var second_battery: u8 = 0;

            for (buffer[start..end]) |char| {
                const num: u8 = char - '0';
                if (second_battery < num) {
                    if (first_battery < second_battery) {
                        first_battery = second_battery;
                    }
                    second_battery = num;
                } else if (first_battery < num) {
                    first_battery = second_battery;
                    second_battery = num;
                } else if (first_battery < second_battery) {
                    first_battery = second_battery;
                    second_battery = num;
                }
            }

            // std.debug.print("{any}{any}\n", .{ first_battery, second_battery });

            joltage += first_battery * 10 + second_battery;

            continue :state .reset;
        },
    }

    return joltage;
}
