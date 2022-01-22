const std = @import("std");
const NativeVector = @import("native_vector.zig").NativeVector;
const assert = std.debug.assert;

pub fn indexOfScalar(comptime T: type, items: []const T, value: T) ?usize {
    var i: usize = 0;
    if (comptime NativeVector.supportsType(T)) {
        const vec = NativeVector.init(T);
        const splat_value = vec.splat(value);
        while (i < vec.maxIndex(items.len)) : (i += vec.len) {
            const v = vec.load(items[i..]);
            const cmpEqual = v == splat_value;
            if (vec.anyTrue(cmpEqual)) {
                return i + vec.leadingFalseCount(cmpEqual);
            }
        }
    }
    while (i < items.len) : (i += 1) {
        if (items[i] == value) {
            return i;
        }
    }
    return null;
}

pub fn lastIndexOfScalar(comptime T: type, items: []const T, value: T) ?usize {
    var i: usize = items.len;
    if (comptime NativeVector.supportsType(T)) {
        const vec = NativeVector.init(T);
        const splat_value = vec.splat(value);
        while (i > vec.minIndex(items.len)) {
            i -= vec.len;
            const v = vec.load(items[i..]);
            const cmpEqual = v == splat_value;
            if (vec.anyTrue(cmpEqual)) {
                return i + vec.len - 1 - vec.trailingFalseCount(cmpEqual);
            }
        }
    }
    while (i > 0) {
        i -= 1;
        if (items[i] == value) {
            return i;
        }
    }
    return null;
}

pub fn min(comptime T: type, items: []const T) T {
    assert(items.len > 0);
    var min_value: T = items[0];
    var i: usize = 0;
    if (comptime NativeVector.supportsType(T)) {
        const vec = NativeVector.init(T);
        if (items.len >= vec.len) {
            var vmin = vec.load(items[0..]);
            i += vec.len;
            while (i < vec.maxIndex(items.len)) : (i += vec.len) {
                const v = vec.load(items[i..]);
                vmin = @select(T, v < vmin, v, vmin);
            }
            min_value = @reduce(.Min, vmin);
        }
    }
    for (items[i..]) |value| {
        min_value = std.math.min(min_value, value);
    }
    return min_value;
}

pub fn max(comptime T: type, items: []const T) T {
    assert(items.len > 0);
    var max_value: T = items[0];
    var i: usize = 0;
    if (comptime NativeVector.supportsType(T)) {
        const vec = NativeVector.init(T);
        if (items.len >= vec.len) {
            var vmax = vec.load(items[0..]);
            i += vec.len;
            while (i < vec.maxIndex(items.len)) : (i += vec.len) {
                const v = vec.load(items[i..]);
                vmax = @select(T, v > vmax, v, vmax);
            }
            max_value = @reduce(.Max, vmax);
        }
    }
    for (items[i..]) |value| {
        max_value = std.math.max(max_value, value);
    }
    return max_value;
}

pub fn eql(comptime T: type, a: []const T, b: []const T) bool {
    if (a.len != b.len) return false;
    if (a.ptr == b.ptr) return true;
    var i: usize = 0;
    if (comptime NativeVector.supportsType(T)) {
        const vec = NativeVector.init(T);
        while (i < vec.maxIndex(a.len)) : (i += vec.len) {
            if (vec.anyTrue(vec.load(a[i..]) != vec.load(b[i..]))) {
                return false;
            }
        }
    }
    while (i < a.len) : (i += 1) {
        if (a[i] != b[i]) {
            return false;
        }
    }
    return true;
}
