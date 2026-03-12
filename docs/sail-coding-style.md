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

### `then match` as braces

`if ... then match ... { ... }` visually acts like `if ... then { ... }`,
so we treat the match braces as if-braces. This means the else branch
must also be braced:

```sail
// OK: then-match + braced else
if count == 1 then match os {
  OS8  => OF = bool_to_bit(result[7] != CF),
  OS16 => OF = bool_to_bit(result[15] != CF),
  OS32 => OF = bool_to_bit(result[31] != CF),
  OS64 => OF = bool_to_bit(result[63] != CF),
} else {
  OF = undefined;
}

// OK: then-match + else-match (both visually braced)
if pfx.rex_w then match pfx.evex_ll {
  2 => ...,
  1 => ...,
  _ => ...,
} else match pfx.evex_ll {
  2 => ...,
  1 => ...,
  _ => ...,
}

// BAD: then-match + bare else
if count == 1 then match os {
  ...
} else OF = undefined;

// BAD: over-wrapped (unnecessary nesting)
if count == 1 then {
  match os {
    ...
  }
} else {
  OF = undefined;
}
```

### Multi-line bare branches

When either branch of an if/else is multi-line (e.g., a braced block),
do NOT leave the other branch bare.

```sail
// BAD: bare then + braced else
if cond then raise_UD()
else {
  do_stuff();
  Ok()
}

// OK: braces on both branches
if cond then {
  raise_UD()
} else {
  do_stuff();
  Ok()
}
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

## Indentation

All code must be properly indented. When a block is nested inside another
(e.g., a `match` inside an `else`), the inner block must be indented relative
to its enclosing block.

## Match vs If/Else Chains

Prefer `match` over if/else if/else chains when dispatching on an integer
or enum value. This is clearer and more consistent with the rest of the
codebase.

```sail
// OK: match on reg_field
match reg_field {
  // PSRLW xmm1, imm8
  2 => { ... },
  // PSRAW xmm1, imm8
  4 => { ... },
  // PSLLW xmm1, imm8
  6 => { ... },
  _ => raise_UD(),
}

// BAD: if/else chain on the same
if reg_field == 2 then { ... }
else if reg_field == 4 then { ... }
else if reg_field == 6 then { ... }
else raise_UD()
```

A short two-way if/else on a single condition is fine — this rule applies
when there are three or more branches dispatching on the same variable.

## Comments on Match Arms

Put the instruction name comment on the line **before** the match arm,
not inside the body or as a trailing comment on the closing brace.

Include the instruction signature (operands) in the comment, not just
the mnemonic.

```sail
// OK: comment above the arm with signature
match sub_op {
  // PUNPCKLBW xmm1, xmm2/m128
  0 => {
    ...
  },
  // PUNPCKLWD xmm1, xmm2/m128
  1 => {
    ...
  },
}

// BAD: comment inside the body
0 => {
  // PUNPCKLBW xmm1, xmm2/m128
  ...
},

// BAD: trailing comment on closing brace
0 => {
  ...
},   // 0F 60

// BAD: mnemonic only, no operands
// PUNPCKLBW
0 => {
  ...
},
```

For one-liner match arms, the comment goes on the line above:

```sail
// FCHS
224 => x87_write_st(0, __f80_chs(x87_read_st(0))),
// FABS
225 => x87_write_st(0, __f80_abs(x87_read_st(0))),
```

When a group comment covers the outer match arm (e.g., an opcode range),
each inner sub-dispatch arm still needs its own instruction name comment.

## Operators

- The `~()` (bitwise NOT) operator requires parens: `~(CF)` not `~CF`
- Use `bool_to_bit(cond)` instead of `if cond then bitone else bitzero`

## Range Comparisons

When checking if a value is in a range, write comparisons in number-line
order (ascending left to right):

```sail
// OK: matches the number line
if 10 <= x & x <= 20 then ...

// BAD: reversed order
if x >= 10 & x <= 20 then ...
```

When checking if a value is outside a range, keep the constants in the
same ascending order:

```sail
// OK: constants still in number-line order
if x < 10 | 20 < x then ...

// BAD: reversed order
if x < 10 | x > 20 then ...
```

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
