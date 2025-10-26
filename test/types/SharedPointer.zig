const std = @import("std");
const lm = @import("loom");

const SharedPointer = lm.types.SharedPointer;

const testing = std.testing;
const expect = testing.expect;
const expectError = testing.expectError;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;
const expectEqualStrings = testing.expectEqualStrings;
const allocator = testing.allocator;

test "create" {
    const my_shared_pointer = try SharedPointer(u8).create(allocator, 0);
    try my_shared_pointer.destroy();
}

test "destroy" {
    {
        const my_shared_pointer = try SharedPointer(u8).create(allocator, 0);
        try my_shared_pointer.destroy();
    }
    {
        const my_shared_pointer = try SharedPointer(u8).create(allocator, 0);

        _ = my_shared_pointer.getRef();

        try expectError(error.NonZeroReferenceCount, my_shared_pointer.destroy());

        my_shared_pointer.removeRef();
        try my_shared_pointer.destroy();
    }
}

test "getRef" {
    const my_shared_pointer = try SharedPointer(u8).create(allocator, 0);
    defer my_shared_pointer.destroy() catch unreachable;

    const value = my_shared_pointer.getRef() orelse return error.UnexpectedValue;
    defer my_shared_pointer.removeRef();

    try expectEqual(0, value.*);
    try expectEqual(1, my_shared_pointer.ref_count);
}

test "removeRef" {
    const my_shared_pointer = try SharedPointer(u8).create(allocator, 0);
    defer my_shared_pointer.destroy() catch unreachable;

    const value = my_shared_pointer.getRef() orelse return error.UnexpectedValue;

    try expectEqual(0, value.*);

    my_shared_pointer.removeRef();
    try expectEqual(0, my_shared_pointer.ref_count);
}
