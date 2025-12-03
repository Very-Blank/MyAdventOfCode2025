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

    std.debug.print("{any}\n", .{try getMaxJoltage(2, buffer)});
    std.debug.print("{any}\n", .{try getMaxJoltage(12, buffer)});
}

test "First star, does joltage match with the example?" {
    const buffer =
        \\987654321111111
        \\811111111111119
        \\234234234234278
        \\818181911112111
    ;

    try std.testing.expectEqual(357, getMaxJoltage(2, buffer));
}

test "Second star, does joltage match with the example?" {
    const buffer =
        \\987654321111111
        \\811111111111119
        \\234234234234278
        \\818181911112111
    ;

    try std.testing.expectEqual(3121910778619, getMaxJoltage(12, buffer));
}

pub fn getMaxJoltage(comptime batteries_count: u64, buffer: []const u8) !u64 {
    if (batteries_count == 0) @compileError("Expected a non zero u64 was given 0");

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

            var batteries: [batteries_count]u8 = .{0} ** batteries_count;

            for (buffer[start..end]) |char| {
                var free_value: u8 = char - '0';

                for (0..batteries.len - 1) |current| {
                    const move_for_future = init: {
                        for (current..batteries.len - 1) |current_future| {
                            for (current_future + 1..batteries.len) |future| {
                                if (batteries[future] < batteries[current_future]) break :init true;
                            }
                        }

                        break :init false;
                    };

                    if (batteries[current] < free_value or move_for_future) {
                        const tmp = batteries[current];
                        batteries[current] = free_value;
                        free_value = tmp;
                        continue;
                    }

                    free_value = 0;

                    break;
                }

                if (batteries[batteries.len - 1] < free_value) batteries[batteries.len - 1] = free_value;
            }

            // if (second_battery < num) {
            //     if (first_battery < second_battery) {
            //         first_battery = second_battery;
            //     }
            //     second_battery = num;
            // } else if (first_battery < num) {
            //     first_battery = second_battery;
            //     second_battery = num;
            // } else if (first_battery < second_battery) {
            //     first_battery = second_battery;
            //     second_battery = num;
            // }

            // for (0..batteries.len) |i| {
            //     std.debug.print("{any}", .{batteries[batteries.len - 1 - i]});
            // }
            //
            // std.debug.print("\n", .{});

            for (batteries, 0..) |battery, i| {
                var battery_joltage: u64 = battery;

                for (0..i) |_| {
                    battery_joltage *= 10;
                }

                joltage += battery_joltage;
            }

            continue :state .reset;
        },
    }

    return joltage;
}
