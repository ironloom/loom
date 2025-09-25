<div align="center" alt="loom">
    <img src="./resources/loom_logo_1376x512.png" width="688">
    <p>The declarative, ECS-based game engine, written in zig.</p>
</div>

---

**loom** wraps [raylib-zig](https://github.com/raylib-zig/raylib-zig) and uses [johan0A](https://github.com/johan0A)'s [clay-zig-bindings](https://github.com/johan0A/clay-zig-bindings) for UI.

> [!important]
> This project uses zig version `0.15.1` and Raylib `5.6-dev`.

The engine aims to provide a declarative interface for game development. We try to provide a _"code only Unity"_, where you only have to configure scenes and entities with only a few lines of code.

## Install loom

Adding loom is easy, just follow these steps:

1. Fetch the package.

   ```sh
   zig fetch --save git+https://github.com/zewenn/loom#stable
   ```

2. Get the module.

   ```zig
   const loom_dep = b.dependency("loom", .{
       .target = target,
       .optimize = optimize,
   });
   const loom_mod = loom_dep.module("loom");
   ```

3. Add the import

   ```zig
   target_module.addImport("loom", loom_mod);
   ```

4. You are ready to go, import loom into you project:
   ```zig
   const loom = @import("loom");
   ```

## Run Example Projects

We have a few example projects included in this repository. Here is how you can run them:

1. Clone the repository
   ```sh
   git clone https://github.com/zewenn/loom.git && cd ./loom
   ```
2. Run the selected example
   ```sh
   zig build example=<example name>
   ```
   Currently available examples:
   - `gamepad` _(only works with a gamepad connected)_
   - `spawning-removing`
   - `display-sorting`
   - `components`
   - `global-behaviours`
   - `audio`
