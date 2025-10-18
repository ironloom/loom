const refAllDeclsRecursive = @import("std").testing.refAllDeclsRecursive;

test {
    refAllDeclsRecursive(@import("loom"));

    _ = @import("types/types.zig");
    _ = @import("ecs/ecs.zig");
    _ = @import("eventloop/eventloop.zig");
}
