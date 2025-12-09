const std = @import("std");
const lm = @import("loom");

pub fn main() !void {
    std.testing.refAllDeclsRecursive(lm);
}
