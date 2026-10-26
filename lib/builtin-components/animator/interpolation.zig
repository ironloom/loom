const std = @import("std");

pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a * (1.0 - t) + b * t;
}

pub fn easeIn(a: f32, b: f32, t: f32) f32 {
    return lerp(a, b, t * t);
}
pub const ease_in = easeIn;

pub fn easeOut(a: f32, b: f32, t: f32) f32 {
    return lerp(a, b, t * (2.0 - t));
}
pub const ease_out = easeOut;

pub fn easeInOut(a: f32, b: f32, t: f32) f32 {
    const factor: f32 = if (t < 0.5)
        2.0 * t * t
    else
        1.0 - std.math.pow(f32, -2.0 * t + 2.0, 2) / 2.0;
    return lerp(a, b, factor);
}
pub const ease_in_out = easeInOut;

pub fn easeInCubic(a: f32, b: f32, t: f32) f32 {
    return lerp(a, b, t * t * t);
}
pub const ease_in_cubic = easeInCubic;

pub fn easeOutCubic(a: f32, b: f32, t: f32) f32 {
    const inv = 1.0 - t;
    return lerp(a, b, 1.0 - inv * inv * inv);
}
pub const ease_out_cubic = easeOutCubic;

pub fn easeInOutCubic(a: f32, b: f32, t: f32) f32 {
    const factor: f32 = if (t < 0.5)
        4.0 * t * t * t
    else
        1.0 - std.math.pow(f32, -2.0 * t + 2.0, 3) / 2.0;
    return lerp(a, b, factor);
}
pub const ease_in_out_cubic = easeInOutCubic;

// Sine Easing
pub fn easeInSine(a: f32, b: f32, t: f32) f32 {
    return lerp(a, b, 1.0 - @cos((t * std.math.pi) / 2.0));
}
pub const ease_in_sine = easeInSine;

pub fn easeOutSine(a: f32, b: f32, t: f32) f32 {
    return lerp(a, b, @sin((t * std.math.pi) / 2.0));
}
pub const ease_out_sine = easeOutSine;

pub fn easeInOutSine(a: f32, b: f32, t: f32) f32 {
    return lerp(a, b, -(@cos(std.math.pi * t) - 1.0) / 2.0);
}
pub const ease_in_out_sine = easeInOutSine;

// Exponential Easing
pub fn easeInExpo(a: f32, b: f32, t: f32) f32 {
    const factor: f32 = if (t <= 0.0) 0.0 else std.math.pow(f32, 2.0, 10.0 * t - 10.0);
    return lerp(a, b, factor);
}
pub const ease_in_expo = easeInExpo;

pub fn easeOutExpo(a: f32, b: f32, t: f32) f32 {
    const factor: f32 = if (t >= 1.0) 1.0 else 1.0 - std.math.pow(f32, 2.0, -10.0 * t);
    return lerp(a, b, factor);
}
pub const ease_out_expo = easeOutExpo;

pub fn easeInOutExpo(a: f32, b: f32, t: f32) f32 {
    const factor: f32 = if (t <= 0.0)
        0.0
    else if (t >= 1.0)
        1.0
    else if (t < 0.5)
        std.math.pow(f32, 2.0, 20.0 * t - 10.0) / 2.0
    else
        (2.0 - std.math.pow(f32, 2.0, -20.0 * t + 10.0)) / 2.0;
    return lerp(a, b, factor);
}
pub const ease_in_out_expo = easeInOutExpo;
