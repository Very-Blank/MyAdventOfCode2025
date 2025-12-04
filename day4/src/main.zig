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

    std.debug.print("{any}", .{try getPaperCount(137, 137, buffer)});
}

test "First star, does paper count match with the example?" {
    const buffer =
        \\..@@.@@@@.
        \\@@@.@.@.@@
        \\@@@@@.@.@@
        \\@.@@@@..@.
        \\@@.@@@@.@@
        \\.@@@@@@@.@
        \\.@.@.@.@@@
        \\@.@@@.@@@@
        \\.@@@@@@@@.
        \\@.@.@@@.@.
    ;

    try std.testing.expectEqual(13, (try getPaperCount(10, 10, buffer))[0]);
}

test "First star, does removed paper count match with the example?" {
    const buffer =
        \\..@@.@@@@.
        \\@@@.@.@.@@
        \\@@@@@.@.@@
        \\@.@@@@..@.
        \\@@.@@@@.@@
        \\.@@@@@@@.@
        \\.@.@.@.@@@
        \\@.@@@.@@@@
        \\.@@@@@@@@.
        \\@.@.@@@.@.
    ;

    try std.testing.expectEqual(43, (try getPaperCount(10, 10, buffer))[1]);
}

pub fn getPaperCount(comptime rows: usize, comptime columns: usize, buffer: []const u8) !struct { u64, u64 } {
    var paper_matrix: [rows][columns]u2 = .{.{0} ** columns} ** rows;
    {
        var i: usize = 0;
        var current_row: usize = 0;
        var current_column: usize = 0;

        while (i < buffer.len) : (i += 1) {
            if (buffer[i] == '\n') {
                current_row += 1;
                current_column = 0;

                continue;
            }

            if (columns <= current_column) return error.InvalidInput;
            if (rows <= current_row) return error.InvalidInput;

            if (buffer[i] == '@') {
                paper_matrix[current_row][current_column] = 1;
            }

            current_column += 1;
        }
    }

    var weight_matrix: [rows + 2][columns + 2]u8 = .{.{0} ** (columns + 2)} ** (rows + 2);

    for (0..rows) |row| {
        for (0..columns) |column| {
            if (paper_matrix[row][column] == 1) {
                for (0..3) |i| {
                    for (0..3) |j| {
                        weight_matrix[row + i][column + j] += 1;
                    }
                }
            }
        }
    }

    var removable_at_first: u64 = 0;

    for (0..rows) |row| {
        for (0..columns) |column| {
            if (paper_matrix[row][column] == 1 and weight_matrix[row + 1][column + 1] <= 4) removable_at_first += 1;
        }
    }

    var total_removed: u64 = 0;
    var removed_by_iteration: u64 = 80085;
    while (removed_by_iteration > 0) {
        removed_by_iteration = 0;

        for (0..rows) |row| {
            for (0..columns) |column| {
                if (paper_matrix[row][column] == 1 and weight_matrix[row + 1][column + 1] <= 4) {
                    paper_matrix[row][column] = 0;

                    for (0..3) |i| {
                        for (0..3) |j| {
                            weight_matrix[row + i][column + j] -= 1;
                        }
                    }

                    removed_by_iteration += 1;
                }
            }
        }

        total_removed += removed_by_iteration;
    }

    return .{ removable_at_first, total_removed };
}
