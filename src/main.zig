const std = @import("std");
const vectorized = @import("algorithms.zig");
const Vector = std.meta.Vector;
const print = std.debug.print;
const assert = std.debug.assert;

pub fn main() !void {
    const T = u8;
    const num_items = 1_000_000;
    var items: [num_items]T align(32) = undefined;

    var default_prng = std.rand.DefaultPrng.init(42);
    var rnd = default_prng.random();
    for (items) |*v| {
        v.* = rnd.intRangeAtMost(T, 0, 199);
    }
    const Test = enum { min, max, indexOfScalar, eql };
    // modify this to test another function
    const current_test = Test.eql;
    print("Testing {s}:\n", .{@tagName(current_test)});

    for ([_]usize{ 1, 5, 50, 500, 5000, 50000, 500_000 }) |find_index, i| {
        const find_value: T = 200 + @intCast(T, i);
        items[find_index - 1] = find_value;
        for (items[0..find_index]) |v, j| {
            items[j + find_index] = v;
        }
        var speed1: u64 = undefined;
        var speed2: u64 = undefined;
        switch (current_test) {
            .min => {
                checkResult1(T, std.mem.min, vectorized.min, items[0..find_index]);
                speed1 = timeIt1(T, find_index, comptime std.mem.min, items[0..find_index]);
                speed2 = timeIt1(T, find_index, vectorized.min, items[0..find_index]);
            },
            .max => {
                checkResult1(T, std.mem.max, vectorized.max, items[0..find_index]);
                speed1 = timeIt1(T, find_index, comptime std.mem.max, items[0..find_index]);
                speed2 = timeIt1(T, find_index, vectorized.max, items[0..find_index]);
            },
            .eql => {
                checkResult2(T, std.mem.eql, vectorized.eql, items[0..find_index], items[find_index..][0..find_index]);
                speed1 = timeIt2(T, find_index, comptime std.mem.eql, items[0..find_index], items[find_index..][0..find_index]);
                speed2 = timeIt2(T, find_index, comptime vectorized.eql, items[0..find_index], items[find_index..][0..find_index]);
            },
            .indexOfScalar => {
                checkResult2(T, std.mem.indexOfScalar, vectorized.indexOfScalar, items[0..find_index], find_value);
                speed1 = timeIt2(T, find_index, comptime std.mem.indexOfScalar, items[0..find_index], find_value);
                speed2 = timeIt2(T, find_index, comptime vectorized.indexOfScalar, items[0..find_index], find_value);
            },
        }

        print("items scanned: {}\n", .{find_index});
        print("std.mem:    {} MB/s\n", .{speed1});
        print("vectorized: {} MB/s\n", .{speed2});
        print("------------------------\n", .{});
    }
}

// Returns megabytes processed per second.
fn timeIt2(comptime T: type, bytes_scanned: u64, comptime func: anytype, arg1: anytype, arg2: anytype) u64 {
    const milliseconds_in_ns = 1_000_000;
    var iterations: u64 = 1;
    var elapsed_ns = elapsedIter2(T, iterations, comptime func, arg1, arg2);
    while (elapsed_ns < 100 * milliseconds_in_ns) {
        iterations *= 2;
        elapsed_ns = elapsedIter2(T, iterations, comptime func, arg1, arg2);
    }
    iterations = std.math.max(1, iterations * 800 * milliseconds_in_ns / elapsed_ns);
    elapsed_ns = elapsedIter2(T, iterations, comptime func, arg1, arg2);
    return 1_000 * @sizeOf(T) * bytes_scanned * iterations / elapsed_ns;
}

fn elapsedIter2(comptime T: type, iterations: u64, comptime func: anytype, arg1: anytype, arg2: anytype) u64 {
    var timer = std.time.Timer.start() catch unreachable;
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const result = func(T, arg1, arg2);
        std.mem.doNotOptimizeAway(&result);
    }
    return timer.lap();
}

fn timeIt1(comptime T: type, bytes_scanned: u64, comptime func: anytype, arg1: anytype) u64 {
    const milliseconds_in_ns = 1_000_000;
    var iterations: u64 = 1;
    var elapsed_ns = elapsedIter1(T, iterations, comptime func, arg1);
    while (elapsed_ns < 100 * milliseconds_in_ns) {
        iterations *= 2;
        elapsed_ns = elapsedIter1(T, iterations, comptime func, arg1);
    }
    iterations = std.math.max(1, iterations * 800 * milliseconds_in_ns / elapsed_ns);
    elapsed_ns = elapsedIter1(T, iterations, comptime func, arg1);
    return 1_000 * @sizeOf(T) * bytes_scanned * iterations / elapsed_ns;
}

fn elapsedIter1(comptime T: type, iterations: u64, comptime func: anytype, arg1: anytype) u64 {
    var timer = std.time.Timer.start() catch unreachable;
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const result = func(T, arg1);
        std.mem.doNotOptimizeAway(&result);
    }
    return timer.lap();
}

fn checkResult1(comptime T: type, comptime func_std: anytype, func_vec: anytype, arg1: anytype) void {
    const res_std = func_std(T, arg1);
    const res_vec = func_vec(T, arg1);
    if (res_std != res_vec) print("Error: std.mem returned {d}, vectorized returned {d}\n", .{ res_std, res_vec });
}

fn checkResult2(comptime T: type, comptime func_std: anytype, func_vec: anytype, arg1: anytype, arg2: anytype) void {
    const res_std = func_std(T, arg1, arg2);
    const res_vec = func_vec(T, arg1, arg2);
    if (res_std != res_vec) print("Error: std.mem returned {d}, vectorized returned {d}\n", .{ res_std, res_vec });
}
