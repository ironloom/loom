const std = @import("std");

const loom = @import("root.zig");
const rl = loom.rl;

pub const KeyboardKey = rl.KeyboardKey;

pub const MouseButton = rl.MouseButton;
pub const MouseCursor = rl.MouseCursor;

pub const GamepadAxis = rl.GamepadAxis;
pub const GamepadButton = rl.GamepadButton;

pub const keyboard = struct {
    pub const getKey = rl.isKeyDown;

    pub const getKeyDown = rl.isKeyPressed;
    pub const getKeyDownRepeat = rl.isKeyPressedRepeat;

    pub const getKeyUp = rl.isKeyReleased;
    pub const getKeyReleased = rl.isKeyUp;

    pub const getKeyPressed = rl.getKeyPressed;

    pub const getKeyName = rl.getKeyName;

    pub fn anyKey() bool {
        return .null != getKeyPressed();
    }
};

pub const mouse = struct {
    pub const getButton = rl.isMouseButtonDown;
    pub const getButtonDown = rl.isMouseButtonPressed;

    pub const getButtonUp = rl.isMouseButtonReleased;
    pub const getButtonReleased = rl.isMouseButtonUp;

    pub const getPosition = rl.getMousePosition;
    pub const getDelta = rl.getMouseDelta;

    pub const getX = rl.getMouseX;
    pub const getY = rl.getMouseY;

    pub const getWheelMoveVector = rl.getMouseWheelMoveV;
    pub const getWheelMove = rl.getMouseWheelMove;

    pub const setCursor = rl.setMouseCursor;
    pub const setOffset = rl.setMouseOffset;
    pub const setScale = rl.setMouseScale;
    pub const setPosition = rl.setMousePosition;
};

pub const gamepad = struct {
    /// `0` is the first gamepad.
    pub const isAvailable = rl.isGamepadAvailable;
    pub const getAxisCount = rl.getGamepadAxisCount;
    pub const getName = rl.getGamepadName;

    pub const getButton = rl.isGamepadButtonDown;
    pub const getButtonDown = rl.isGamepadButtonPressed;

    pub const getButtonUp = rl.isGamepadButtonReleased;
    pub const getButtonReleased = rl.isGamepadButtonUp;

    pub const getAxisMovement = rl.getGamepadAxisMovement;
    pub const getButtonPressed = rl.getGamepadButtonPressed;

    pub fn anyButton() bool {
        return .null != getButtonPressed();
    }

    pub fn getStickVector(gamepad_number: i32, stick: enum { left, right }, threshold: f32) loom.Vector2 {
        return switch (stick) {
            .left => .init(
                applyThreshold(getAxisMovement(gamepad_number, .left_x), threshold),
                applyThreshold(getAxisMovement(gamepad_number, .left_y), threshold),
            ),
            .right => .init(
                applyThreshold(getAxisMovement(gamepad_number, .right_x), threshold),
                applyThreshold(getAxisMovement(gamepad_number, .right_y), threshold),
            ),
        };
    }

    fn applyThreshold(value: f32, threshold: f32) f32 {
        return if (value > threshold or value < -1 * threshold) value else 0;
    }
};
