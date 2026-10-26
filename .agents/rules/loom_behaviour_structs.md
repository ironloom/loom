---
trigger: always_on
---

loom Behaviour structs (files) should always be formatted in the following manner:
- put imports first, like: 
  ```zig
  const std = @import("std");
  const lm = @import("loom");
  ```

- ALWAYS create a `Self` type:
  ```zig
  const Self = @This();
  ```

- Then add the TOP-LEVEL struct fields:
  ```zig
  field_1: SomeType = SomeType{...},
  field_2: ?*Component = null,
  ...
  ```
  NOTE: components should ALWAYS be an optional pointer!

- Then add the behaviour methods: `Awake`, `Start`, `Update`, `Tick`, and `End`.
   - `Awake` should set up memory allocations, arena allocators, and everything the other methods might use.
   - `Start` should get/create+setup the other required components
   - `Update` should have the frame-logic (since it runs every frame)
   - `Tick` should have periodical, heavy code, which needs to run multiple times per second, just not on every frame (e.g.: collision)
   - `End` should clear up every allocation made by the component
  NOTE: you do not need to create all of these methods, just those, which you are going to use

- Then you can add your own methods. These can be helper functions, public methods, or anything else.