const std = @import("std");
const builtin = @import("builtin");

const Rotation = union(enum) {
    L: u16,
    R: u16,
};

// ({0..99}).len = 100
const dial_values_length: u16 = 100;
const dial_start_value: u16 = 50;

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

    const zero_count = try getDialZeroCount(buffer);

    std.debug.print("{any}\n", .{zero_count});
}

test "First star, does zero count match with example?" {
    const buffer =
        \\L68
        \\L30
        \\R48
        \\L5
        \\R60
        \\L55
        \\L1
        \\L99
        \\R14
        \\L82
    ;

    const count = try getDialZeroCount(buffer);
    try std.testing.expectEqual(3, count.dial_is_zero);
}

test "Second star, does zero count match with example?" {
    const buffer =
        \\L68
        \\L30
        \\R48
        \\L5
        \\R60
        \\L55
        \\L1
        \\L99
        \\R14
        \\L82
    ;

    const count = try getDialZeroCount(buffer);
    try std.testing.expectEqual(6, count.dial_hits_zero);
}

const ZeroCounter = struct {
    dial_is_zero: usize, // First star
    dial_hits_zero: usize, // Second star

    const zero = ZeroCounter{ .dial_is_zero = 0, .dial_hits_zero = 0 };
};

pub fn getDialZeroCount(buffer: []const u8) !ZeroCounter {
    var start: usize = 0;
    var end: usize = 0;

    var rotation: Rotation = .{ .L = 0 };
    var dial: u16 = dial_start_value;
    var zero_counter: ZeroCounter = .zero;

    // NOTE: I think a state machine fits here nicely, others might not agree :)
    state: switch ((enum {
        start_new_get_rotation,
        get_rotation,
        read_rotation,
        apply_rotation,
    }).get_rotation) {
        .start_new_get_rotation => {
            if (end + 1 < buffer.len) {
                end += 1;
                start = end;
                continue :state .get_rotation;
            }

            break :state;
        },
        .get_rotation => {
            if (buffer[end] != '\n') {
                end += 1;

                if (end < buffer.len) {
                    continue :state .get_rotation;
                }

                if (start == end or end - start < 2) {
                    break :state;
                }
            }

            if (end - start < 2) return error.InputInvalid;

            continue :state .read_rotation;
        },
        .read_rotation => {
            switch (buffer[start]) {
                'L', 'R' => |direction| {
                    var distance: u16 = 0;
                    for (buffer[start + 1 .. end]) |char| {
                        switch (char) {
                            '0'...'9' => distance = distance * 10 + (char - '0'),
                            else => return error.InvalidNumber,
                        }
                    }

                    if (direction == 'L') {
                        rotation = .{ .L = distance };
                    } else {
                        rotation = .{ .R = distance };
                    }

                    continue :state .apply_rotation;
                },
                else => return error.InputInvalid,
            }
        },
        .apply_rotation => {
            switch (rotation) {
                .L => |distance| {
                    const hits_while_turning = (distance - (distance % dial_values_length)) / (dial_values_length - 1);
                    zero_counter.dial_hits_zero += hits_while_turning;
                    if (dial <= distance % dial_values_length and dial != 0) zero_counter.dial_hits_zero += 1;

                    dial = (dial + (dial_values_length - distance % dial_values_length)) % (dial_values_length);
                },
                .R => |distance| {
                    const hits_while_turning = (distance - (distance % dial_values_length)) / (dial_values_length - 1);
                    zero_counter.dial_hits_zero += hits_while_turning;
                    if (dial_values_length <= dial + distance % dial_values_length) zero_counter.dial_hits_zero += 1;

                    dial = (dial + distance) % (dial_values_length);
                },
            }

            if (dial == 0) zero_counter.dial_is_zero += 1;

            continue :state .start_new_get_rotation;
        },
    }

    return zero_counter;
}
