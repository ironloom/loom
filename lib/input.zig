const std = @import("std");

const loom = @import("root.zig");
const rl = loom.rl;

pub const KeyboardKey = rl.KeyboardKey;
pub const MouseButton = rl.MouseButton;
pub const MouseCursor = rl.MouseCursor;

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
