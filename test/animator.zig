const lm = @import("loom");
const std = @import("std");

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualStrings = testing.expectEqualStrings;

test "Keyframe sprite interpolation order" {
    const kf1 = lm.Keyframe{ .sprite = "frame_a.png" };
    const kf2 = lm.Keyframe{ .sprite = "frame_b.png" };

    const interp_start = kf1.interpolate(kf2, lm.interpolation.lerp, 0.0);
    try expectEqualStrings("frame_a.png", interp_start.sprite.?);

    const interp_mid = kf1.interpolate(kf2, lm.interpolation.lerp, 0.5);
    try expectEqualStrings("frame_a.png", interp_mid.sprite.?);

    const interp_past_mid = kf1.interpolate(kf2, lm.interpolation.lerp, 0.51);
    try expectEqualStrings("frame_b.png", interp_past_mid.sprite.?);

    const interp_end = kf1.interpolate(kf2, lm.interpolation.lerp, 1.0);
    try expectEqualStrings("frame_b.png", interp_end.sprite.?);
}

test "Animation single keyframe close" {
    var anim = lm.Animation.init("single", 1.0, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "only_frame.png" },
    });
    defer anim.deinit();

    for (anim.base_keyframes) |kf| {
        _ = anim.append(kf);
    }
    anim.close();

    const curr = anim.current();
    try expect(curr != null);
    try expectEqualStrings("only_frame.png", curr.?.sprite.?);

    const nxt = anim.next();
    try expect(nxt == null);
}

test "Animation zero keyframe close does not crash" {
    var anim = lm.Animation.init("empty", 1.0, lm.interpolation.lerp, &.{});
    defer anim.deinit();

    _ = anim.append(lm.Keyframe{ .sprite = "dummy.png" });
    // Remove or test with empty unregistered
    var empty_anim = lm.Animation.init("empty2", 1.0, lm.interpolation.lerp, &.{});
    defer empty_anim.deinit();
    empty_anim.close();

    try expect(empty_anim.keys == null);
}

test "Animation multiple keyframes close" {
    var anim = lm.Animation.init("multi", 1.0, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "frame_1.png" },
        lm.Keyframe{ .sprite = "frame_2.png" },
    });
    defer anim.deinit();

    for (anim.base_keyframes) |kf| {
        _ = anim.append(kf);
    }
    anim.close();

    try expect(anim.keys != null);
    try expectEqual(@as(usize, 2), anim.keys.?.len);
    try expectEqual(@as(i32, 0), anim.keys.?[0]);
    try expectEqual(@as(i32, 10), anim.keys.?[1]);
}
