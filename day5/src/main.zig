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

    std.debug.print("{any}\n", .{try getFreshIngredients(buffer, allocator)});
}

test "First star, does fresh ingredient count match with the example?" {
    const buffer =
        \\3-5
        \\10-14
        \\16-20
        \\12-18
        \\
        \\1
        \\5
        \\8
        \\11
        \\17
        \\32
    ;

    try std.testing.expectEqual(3, (getFreshIngredients(buffer, std.testing.allocator) catch return error.TestUnexpectedError)[0]);
}

test "Second star, does ingredient count match with the example?" {
    const buffer =
        \\3-5
        \\10-14
        \\16-20
        \\12-18
        \\
        \\1
        \\5
        \\8
        \\11
        \\17
        \\32
    ;

    try std.testing.expectEqual(14, (getFreshIngredients(buffer, std.testing.allocator) catch return error.TestUnexpectedError)[1]);
}

const Range = struct {
    start: u64,
    end: u64,

    pub fn lessThan(_: void, a: Range, b: Range) bool {
        return a.start < b.start;
    }
};

pub fn getFreshIngredients(buffer: []const u8, allocator: std.mem.Allocator) !struct { u64, u64 } {
    var start: usize = 0;
    var end: usize = 0;

    var ranges: std.ArrayList(Range) = .empty;
    defer ranges.deinit(allocator);

    {
        var middle: usize = 0;

        state: switch (enum { reset, get_range, read_range }.get_range) {
            .reset => {
                if (end + 1 < buffer.len and buffer[end] == '\n' and buffer[end + 1] == '\n') {
                    end += 2;

                    if (buffer.len <= end) return error.InvalidInput;

                    start = end;
                    break :state;
                }

                end += 1;
                start = end;

                if (end < buffer.len) continue :state .get_range;

                break :state;
            },
            .get_range => {
                end += 1;
                if (end == buffer.len) {
                    if (3 <= end - start and start < middle and middle < end) continue :state .read_range;
                    break :state;
                }

                std.debug.assert(end < buffer.len);

                switch (buffer[end]) {
                    '\n' => {
                        if (end - start < 3) return error.InvalidInput;

                        if (!(start < middle and middle < end)) return error.InvalidInput;

                        continue :state .read_range;
                    },
                    '-' => middle = end,
                    else => {},
                }

                continue :state .get_range;
            },
            .read_range => {
                const range_start = try asciiToNum(buffer[start..middle]);
                const range_end = try asciiToNum(buffer[middle + 1 .. end]);

                if (start < end) try ranges.append(allocator, .{ .start = range_start, .end = range_end });

                continue :state .reset;
            },
        }
    }

    std.mem.sort(Range, ranges.items, {}, Range.lessThan);

    var clean_ranges: std.ArrayList(Range) = .empty;
    try clean_ranges.append(allocator, ranges.items[0]);
    defer clean_ranges.deinit(allocator);

    for (ranges.items[1..]) |range| {
        if (clean_ranges.items[clean_ranges.items.len - 1].start <= range.start and range.start <= clean_ranges.items[clean_ranges.items.len - 1].end + 1) {
            if (clean_ranges.items[clean_ranges.items.len - 1].end < range.end) {
                clean_ranges.items[clean_ranges.items.len - 1].end = range.end;
            }
        } else {
            try clean_ranges.append(allocator, range);
        }
    }

    // std.debug.print("{any}\n", .{clean_ranges.items});

    var possible_fresh: u64 = 0;

    for (clean_ranges.items) |range| {
        possible_fresh += range.end - range.start + 1;
    }

    var sum: u64 = 0;
    state: switch (enum { reset, get_ingredient, read_ingredient }.get_ingredient) {
        .reset => {
            end += 1;
            start = end;

            if (end < buffer.len) continue :state .get_ingredient;

            break :state;
        },
        .get_ingredient => {
            end += 1;
            if (end == buffer.len) {
                if (3 <= end - start) continue :state .read_ingredient;
                break :state;
            }

            std.debug.assert(end < buffer.len);

            if (buffer[end] == '\n') {
                continue :state .read_ingredient;
            }

            continue :state .get_ingredient;
        },
        .read_ingredient => {
            const ingredient = try asciiToNum(buffer[start..end]);

            for (clean_ranges.items) |range| {
                if (range.start <= ingredient and ingredient <= range.end) {
                    sum += 1;
                    break;
                }

                if (ingredient <= range.end) break;
            }

            continue :state .reset;
        },
    }

    return .{ sum, possible_fresh };
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
