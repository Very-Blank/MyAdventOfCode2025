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

    std.debug.print("{any}\n", .{try getMathProblemSum(buffer, allocator)});
}

test "First star, does sum match with the example?" {
    const buffer =
        \\123 328  51 64 
        \\ 45 64  387 23 
        \\  6 98  215 314
        \\*   +   *   +  
    ;

    try std.testing.expectEqual(4277556, try getMathProblemSum(buffer, std.testing.allocator));
}

const OperatorType = enum {
    @"+",
    @"*",
};

const Problem = struct {
    result: u64 = 0,
    operator: OperatorType,
};

pub fn getMathProblemSum(buffer: []const u8, allocator: std.mem.Allocator) !u128 {
    std.debug.assert(buffer.len > 0);

    var problems: std.ArrayList(Problem) = .empty;
    defer problems.deinit(allocator);

    var i: usize = buffer.len - 1;
    while (true) {
        switch (buffer[i]) {
            '*' => try problems.append(allocator, .{ .operator = .@"*", .result = 1 }),
            '+' => try problems.append(allocator, .{ .operator = .@"+", .result = 0 }),
            '0'...'9' => break,
            else => {},
        }

        if (1 <= i) {
            i -= 1;
            continue;
        }

        break;
    }

    if (i == 0) return error.InvalidInput;

    var start: usize = i;
    var end: usize = i;
    var current_operator: usize = 0;

    state: switch (enum { reset, get_number, ignore_whitespace, read_number }.ignore_whitespace) {
        .reset => if (1 <= start) {
            start -= 1;
            continue :state .ignore_whitespace;
        },
        .ignore_whitespace => switch (buffer[start]) {
            ' ', '\t', '\n', '\r', std.ascii.control_code.vt, std.ascii.control_code.ff => {
                if (start == 0) {
                    break :state;
                }

                start -= 1;

                continue :state .ignore_whitespace;
            },
            '0'...'9' => {
                end = start;
                continue :state .get_number;
            },
            else => return error.InvalidInput,
        },
        .get_number => {
            if (start == 0) {
                continue :state .read_number;
            }

            switch (buffer[start - 1]) {
                ' ', '\t', '\n', '\r', std.ascii.control_code.vt, std.ascii.control_code.ff => {
                    std.debug.assert(start <= end);

                    continue :state .read_number;
                },
                '0'...'9' => {
                    start -= 1;
                },
                else => return error.InvalidInput,
            }

            continue :state .get_number;
        },
        .read_number => {
            const num = try asciiToNum(buffer[start .. end + 1]);

            switch (problems.items[current_operator % problems.items.len].operator) {
                .@"*" => problems.items[current_operator % problems.items.len].result *= num,
                .@"+" => problems.items[current_operator % problems.items.len].result += num,
            }

            current_operator += 1;

            continue :state .reset;
        },
    }

    var sum: u128 = 0;
    for (problems.items) |problem| {
        sum += problem.result;
    }

    return sum;
}

pub fn asciiToNum(buffer: []const u8) !u16 {
    var num: u16 = 0;
    for (buffer) |char| {
        switch (char) {
            '0'...'9' => num = num * 10 + (char - '0'),
            else => return error.InvalidNumber,
        }
    }

    return num;
}
