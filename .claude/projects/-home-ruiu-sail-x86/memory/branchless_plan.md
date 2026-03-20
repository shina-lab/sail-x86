# Branchless Conversion Plan

## Goal
Replace branchy `if/then/else` patterns with branchless bitvector arithmetic across the codebase. Every transformation must be formally proven equivalent before code is changed.

## Proof Methodology
- For every transformation, write a `$property` function taking full-width inputs (e.g., `a: bits(128), b: bits(128)`)
- Assert `original_expression == replacement_expression` at the full instruction output width
- Run `sail --smt --smt-auto --smt-auto-solver z3 proofs/branchless2.sail`
- Only apply code changes after ALL proofs pass
- Type-check with `cd model && sail -just_check x86.sail_project` after changes
- Run `cd build && ctest -j128` at the end

## Branchless Techniques

### Compare-to-mask (cmp_eq, cmp_gt)
Already have branchless: cmp_eq8, cmp_eq16, cmp_gt8, cmp_gt16 (in insn_sse_int.sail)
Need new: cmp_eq32, cmp_eq64, cmp_gt32, cmp_gt64

Pattern for cmp_eq (N-bit):
```
let xd = (0b0 @ xor(a, b)) - zero_extend(0b1)  // (N+1)-bit
zeros() - zero_extend(xd[N..N])                  // broadcast borrow bit
```

Pattern for cmp_gt signed (N-bit):
```
let diff = sign_extend(b) - sign_extend(a)  // (N+1)-bit
zeros() - zero_extend(diff[N..N])            // broadcast sign bit
```

### Absolute value (abs)
Pattern: `mask = zeros() - zero_extend(x[N-1..N-1]); (x ^ mask) - mask`
- If x >= 0: mask=0, result = x
- If x < 0: mask=all-1s, result = ~x + 1 = -x

### Packed sign (psign)
Three-way: if b<0 then -a; if b==0 then 0; else a
Pattern:
```
neg_mask = zeros() - zero_extend(b[N-1..N-1])     // all-1s if b < 0
borrow = (0b0 @ b) - zero_extend(0b1)             // borrow if b == 0
non_zero = zeros() - zero_extend(~borrow[N..N])   // all-1s if b != 0
result = ((a ^ neg_mask) - neg_mask) & non_zero
```

### Signed min/max
Pattern for max_s (N-bit):
```
diff = sign_extend(b) - sign_extend(a)  // (N+1)-bit
mask = zeros() - zero_extend(diff[N..N]) // all-1s if a > b signed
(a & mask) | (b & ~mask)
```

### Unsigned min/max
Pattern for min_u (N-bit):
```
diff = (0b0 @ a) - (0b0 @ b)  // (N+1)-bit
mask = zeros() - zero_extend(diff[N..N])  // all-1s if a < b unsigned
(a & mask) | (b & ~mask)
```
For max_u: swap a/b in the select: `(b & mask) | (a & ~mask)`

### Saturated unsigned add
```
wide = (0b0 @ a) + (0b0 @ b)
sat_mask = zeros() - zero_extend(wide[N..N])  // all-1s on overflow
result = wide[N-1..0] | sat_mask
```

### Saturated unsigned subtract
```
wide = (0b0 @ a) - (0b0 @ b)
no_borrow = zeros() - zero_extend(~wide[N..N])  // all-1s when no borrow
result = wide[N-1..0] & no_borrow
```

## Transformations by File

### 1. model/insn_sse_int.sail — Helper functions to rewrite
- `abs8`, `abs16`, `abs32` → branchless abs (add `abs64`)
- `psign8`, `psign16`, `psign32` → branchless psign
- `sat_add_u8`, `sat_add_u16` → branchless sat add
- `sat_sub_u8`, `sat_sub_u16` → branchless sat sub
- Add new helpers: `cmp_eq32`, `cmp_eq64`, `cmp_gt32`, `cmp_gt64`
- Add new helpers: `max_s64`, `min_s64`, `max_u64`, `min_u64`

### 2. model/insn_sse_int.sail — Inline call sites
- PCMPGTD (line ~771): 4× inline `if signed > signed then ones else zeros : dword` → `cmp_gt32()`
- PCMPEQD (line ~1169): 4× inline `if == then ones else zeros : dword` → `cmp_eq32()`
- PCMPGTQ (line ~2667): 2× inline `if signed > signed then ones else zeros : qword` → `cmp_gt64()`
- PCMPEQQ (line ~2586): 2× inline `if == then ones else zeros : qword` → `cmp_eq64()`

### 3. model/insn_mmx.sail — Inline call sites
- PCMPGTD (line ~107): 2× inline signed gt dword → `cmp_gt32()`
- PCMPEQW (line ~321): 4× inline eq word → `cmp_eq16()` (helper exists)
- PCMPEQD (line ~335): 2× inline eq dword → `cmp_eq32()`

### 4. model/insn_vex.sail — Inline call sites + loop bodies
- `vex_pcmpgtd_128` (line ~674): 4× inline signed gt dword → `cmp_gt32()`
- `avx_pcmpeqq_128` (line ~535): 2× inline eq qword → `cmp_eq64()`
- `vex_pminub_128` (line ~816): loop body `if unsigned < unsigned then a else b` → `min_u8()`
- `vex_pmaxub_128` (line ~827): loop body → `max_u8()`
- `vex_pminsw_128` (line ~839): loop body → `min_s16()`
- `avx_pminuw_128` (line ~494): loop body → `min_u16()`
- `avx_maxuw_128` (line ~517): loop body → `max_u16()`

### 5. model/insn_vex_int.sail — Inline call sites
- VPCMPEQD 256-bit (line ~584): 8× inline eq dword → `cmp_eq32()`
- VPCMPEQD 128-bit (line ~596): 4× inline eq dword → `cmp_eq32()`
- VPMAXSW 256-bit (line ~1477): loop body `if signed > signed then a else b` → `max_s16()`
- VPMAXSW 128-bit (line ~1487): loop body → `max_s16()`

### 6. model/insn_sse4_helpers.sail — Loop bodies
- `avx_pminsb_128` (line ~170): loop body → `min_s8()`
- `avx_pminsd_128` (line ~186): loop body → `min_s32()`
- `avx_pminud_128` (line ~202): loop body → `min_u32()`
- `avx_pmaxsb_128` (line ~218): loop body → `max_s8()`
- `avx_pmaxsd_128` (line ~234): loop body → `max_s32()`
- `avx_pmaxud_128` (line ~250): loop body → `max_u32()`

### 7. model/insn_evex_int.sail — Loop bodies
- `avx_pminub_128` (line ~105): loop body → `min_u8()`
- `avx_pmaxub_128` (line ~556): loop body → `max_u8()`
- `avx_pminsw_128` (line ~580): loop body → `min_s16()`
- `avx_pmaxsw_128` (line ~604): loop body → `max_s16()`
- `avx_pmaxuw_128` (line ~940): loop body → `max_u16()` (in evex_arith)

### 8. model/insn_evex_arith.sail — Loop bodies
- `avx_pabsb/w/d/q_128`: abs loops → `abs8/16/32/64()`
- `avx_pminsq_128`, `avx_pmaxsq_128`: loop body → `min_s64()`, `max_s64()`
- `avx_pmaxuw_128`: loop body → `max_u16()`
- `avx_pminuq_128`, `avx_pmaxuq_128`: loop body → `min_u64()`, `max_u64()`

## Progress
- [x] Proof file proofs/branchless2.sail: per-element proofs pass (19/19)
- [x] Apply code changes (all 7 files, ~38 call sites)
- [x] Type-check passes
- [x] All 247 tests pass
