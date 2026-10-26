const std = @import("std");
const lm = @import("../root.zig");

pub const Status = enum(u8) {
    pending,
    cpu_ready,
    ready,
    failed,
};

pub fn AssetPromise(comptime Raw: type, comptime Uploaded: type) type {
    return struct {
        hash: u64,
        uploadFn: *const fn (u64, Raw, usize) anyerror!*Uploaded,
        releaseRawFn: ?*const fn (Raw) void = null,

        status: std.atomic.Value(Status) = .init(.pending),
        raw_data: ?Raw = null,
        value: ?*Uploaded = null,
        ref_count: usize = 1,

        pub fn upload(self: *@This()) !?*Uploaded {
            if (self.status.load(.acquire) != .cpu_ready) return self.value;

            if (self.raw_data) |raw| {
                defer {
                    if (self.releaseRawFn) |releaseRawFn|
                        @call(.auto, releaseRawFn, .{raw});
                    self.raw_data = null;
                }

                self.value = self.uploadFn(self.hash, raw, self.ref_count) catch |err| {
                    self.status.store(.failed, .release);
                    return err;
                };

                self.status.store(.ready, .release);
            }
            return self.value;
        }

        pub fn sync(self: *@This()) !?*Uploaded {
            while (self.status.load(.acquire) == .pending) {
                std.Thread.yield() catch {};
            }
            return self.upload();
        }
    };
}
