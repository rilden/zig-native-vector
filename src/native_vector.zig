const std = @import("std");
const builtin = @import("builtin");
const Vector = std.meta.Vector;

pub const NativeVector = struct {
    len: u16,
    ChildType: type,
    const Self = @This();

    /// Returns a native vector of type T.
    pub fn init(comptime T: type) NativeVector {
        return .{
            .len = vectorLen(T),
            .ChildType = T,
        };
    }

    /// Returns true if vector operations with type T are supported.
    pub fn supportsType(comptime T: type) bool {
        return switch (T) {
            u8, i8, u16, i16, u32, i32, f32, f64 => true,
            u64, i64 => builtin.cpu.arch == .x86_64 and std.Target.x86.featureSetHas(builtin.cpu.features, .avx512f),
            else => false,
        };
    }

    /// Returns the number of items that a native vector of type T can hold.
    pub fn vectorLen(comptime T: type) u16 {
        const arch = builtin.cpu.arch;
        // zig fmt: off
        const byte_len: u16 =
            if (arch == .x86_64 and std.Target.x86.featureSetHas(builtin.cpu.features, .avx512bw)) 64
            else if (arch == .x86_64 and std.Target.x86.featureSetHas(builtin.cpu.features, .avx2)) 32
            else 16;
        const int32_len: u16 =
            if (arch == .x86_64 and std.Target.x86.featureSetHas(builtin.cpu.features, .avx512f)) 16
            else if (arch == .x86_64 and std.Target.x86.featureSetHas(builtin.cpu.features, .avx2)) 8
            else 4;
        const float_len: u16 = 
            if (arch == .x86_64 and std.Target.x86.featureSetHas(builtin.cpu.features, .avx512f)) 16
            else if (arch == .x86_64 and std.Target.x86.featureSetHas(builtin.cpu.features, .avx)) 8
            else 4;
        // zig fmt: on
        return switch (T) {
            u8, i8 => byte_len,
            u16, i16 => byte_len / 2,
            u32, i32 => int32_len,
            u64, i64 => int32_len / 2,
            f32 => float_len,
            f64 => float_len / 2,
            else => @compileError("Vectors of " ++ @typeName(T) ++ " not supported"),
        };
    }

    pub fn Type(comptime self: Self) type {
        return Vector(self.len, self.ChildType);
    }

    pub fn minIndex(comptime self: Self, slice_len: usize) usize {
        return slice_len % self.len;
    }

    pub fn maxIndex(comptime self: Self, slice_len: usize) usize {
        return slice_len - slice_len % self.len;
    }

    pub fn splat(comptime self: Self, value: self.ChildType) Vector(self.len, self.ChildType) {
        return @splat(self.len, value);
    }

    pub inline fn load(comptime self: Self, slice: []const self.ChildType) Vector(self.len, self.ChildType) {
        const result: Vector(self.len, self.ChildType) = slice[0..self.len].*;
        return result;
    }

    pub fn store(comptime self: Self, slice: []self.ChildType, v: Vector(self.len, self.ChildType)) void {
        slice[0..self.len].* = v;
    }

    pub fn anyTrue(comptime self: Self, cmp: Vector(self.len, bool)) bool {
        return @reduce(.Or, cmp);
    }

    pub fn allTrue(comptime self: Self, cmp: Vector(self.len, bool)) bool {
        return @reduce(.And, cmp);
    }

    fn BitType(comptime len: u16) type {
        return std.meta.Int(.unsigned, len);
    }

    /// Converts a vector of bools to an unsigned integer.
    pub fn bitCast(comptime self: Self, cmp: Vector(self.len, bool)) BitType(self.len) {
        return @ptrCast(*const BitType(self.len), &cmp).*;
    }

    pub fn leadingFalseCount(comptime self: Self, cmp: Vector(self.len, bool)) u16 {
        return @ctz(BitType(self.len), self.bitCast(cmp));
    }

    pub fn trailingFalseCount(comptime self: Self, cmp: Vector(self.len, bool)) u16 {
        return @clz(BitType(self.len), self.bitCast(cmp));
    }
};
