# Sail Coding Style Guide

This document describes the coding conventions for the x86-64 Sail model.

## General

- Build: `cd build && make -j$(nproc)`
- Tests: `ctest --output-on-failure`
- Sail project file: `model/x86.sail_project` defines compilation order

## If/Else Formatting

### Brace consistency
If either branch of an if/else has braces, both must have braces.

```sail
// OK: both bare (single expression each)
if foo then bar else baz

// OK: both braced
if cond then {
  foo;
  bar
} else {
  baz
}

// BAD: mixed braces
if cond then raise_UD() else { ... }
if cond then { foo; bar } else baz
```

### Multi-line if/else
When using braces, put `if`, `} else {`, and closing `}` on separate lines.
Do NOT put `if ... then { ... } else { ... }` all on two lines.

```sail
// OK: three or more lines
if cond then {
  do_something();
  Ok()
} else {
  do_other();
  Ok()
}

// OK: single-expression bare if/else on one line
if cond then foo else bar

// BAD: braced if/else crammed into two lines
if cond then { foo }
else { bar }
```

### Short single-expression branches

When both branches are single expressions and the whole thing fits on one
line (~100 chars), it can stay on one line:

```sail
if pfx.vex_l then write_ymm(dst, src) else write_xmm(dst, src)
```

When it doesn't fit, use three lines:

```sail
if pfx.vex_l then {
  write_ymm(dst, read_ymm(modrm_xmm_rm(modrm, pfx)));
} else {
  write_xmm(dst, read_xmm(modrm_xmm_rm(modrm, pfx)));
}
```

## Operators

- The `~()` (bitwise NOT) operator requires parens: `~(CF)` not `~CF`
- Use `bool_to_bit(cond)` instead of `if cond then bitone else bitzero`

## Functions and Declarations

- `val` declarations go in the file where the function is called
- Use `Ok()` not `Ok(())`
- Short blocks (1-2 statements + `Ok()`) can stay on a single line if the
  total length is ~100 chars or less

## Inlining

When inlining single-caller helper functions into decoder match arms:

- Keep original comments from the helper function
- A "single-caller" function has exactly 3 grep references: the `val`
  declaration, the `function` definition, and the one call site
- When removing variable aliases like `let b = src_xmm;`, replace ALL uses
  of `b` with `src_xmm` throughout the inlined code

## Naming

- `simd_idx` is `range(0,31)`, `gpr_idx` is `range(0,15)`
- Use `% 16` to convert `vex_vvvv` to GPR index
