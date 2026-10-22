// x86-64 — SSE4/AVX Shared Integer Helpers
//
// These helper functions are used by both VEX (insn_vex.sail) and
// EVEX (insn_evex_arith.sail) instruction dispatch. This file must
// be included before both.

// =========================================================================
// Gather address computation (shared by VEX and EVEX gather instructions)
// =========================================================================

// The memory operand of the element with index idx: "BASE_ADDR +
// (SignExtend(VINDEX[i])*SCALE + DISP" (SDM Vol.2 VPGATHERDD etc.,
// Operation), an effective address of the instruction's address size, in
// the segment of the base register or the override (vsib_seg_asize).
val gather_addr : forall 'n, 'n in {32, 64}. (VSIB, bits('n)) -> MemRef
function gather_addr(vsib, idx) = {
  let offset : qword = sign_extend(idx);
  let ea : qword = match vsib.vsib_scale {
    0 => vsib.vsib_base + offset,
    1 => vsib.vsib_base + (offset << 1),
    2 => vsib.vsib_base + (offset << 2),
    3 => vsib.vsib_base + (offset << 3),
  };
  struct { seg = vsib.vsib_seg, addr = if vsib.vsib_addr64 then ea else zero_extend(ea[31..0]) }
}

// The access of one gather or scatter element.  The instructions complete
// their elements in order, from the LSB, writing each one's result as
// they go; "if a fault is triggered by an element and delivered, all
// elements closer to the LSB of the destination will be completed (and
// non-faulting).  Individual elements closer to the MSB may or may not be
// completed" (SDM VPGATHERDD etc., Vol.2C p.5-552; VPSCATTERDD p.5-619;
// APM Vol.4 §1.3.3, p.11), and the model completes none of those.  The
// order is the same for the same inputs, as "a given implementation of
// this instruction is repeatable".  A fault on an element is delivered,
// unless a completed element hit a data breakpoint: "If any traps or
// interrupts are pending from already gathered elements, they will be
// delivered in lieu of the exception; in this case, EFLAG.RF is set to one
// so an instruction breakpoint is not re-triggered when the instruction is
// continued" (SDM VPGATHERDD p.5-551, VPSCATTERDD p.5-619; APM VPGATHERDD
// p.1397, VPSCATTERDD p.1573, "the RF flag is set").  Then the access
// returns None (false): the instruction stops there with RIP at its first
// byte and RF set, and step() raises the #DB for pending_dbp.  hits is
// pending_dbp at the start of the instruction; the faulting access, which
// is not completed, hits no breakpoint.  A #PF has loaded CR2 as it was
// detected (paging.sail), and the model leaves CR2 so when the #DB takes
// its place; the manuals say only "When a page fault occurs, the
// processor loads the CR2 register with the linear address that generated
// the exception" (SDM Vol.3A §5.7, p.5-38).
val vsib_trap_in_lieu : (bits(4), bits(4)) -> bool
function vsib_trap_in_lieu(before, hits) = {
  pending_dbp = before;
  if before == hits then false
  else {
    next_rip = Some(insn_start);
    RF = 0b1;
    true
  }
}

val vsib_read : forall 'n, 'n in {32, 64}. (implicit('n), MemRef, bits(4)) -> option(bits('n))
function vsib_read(n, m, hits) = {
  let before = pending_dbp;
  try Some(read_mem(n, m) : bits('n)) catch {
    Fault(vec, err) => if vsib_trap_in_lieu(before, hits) then None() else throw Fault(vec, err),
    e => throw e,
  }
}

val vsib_write : forall 'n, 'n in {32, 64}. (implicit('n), MemRef, bits('n), bits(4)) -> bool
function vsib_write(n, m, v, hits) = {
  let before = pending_dbp;
  try { write_mem(n, m, v); true } catch {
    Fault(vec, err) => if vsib_trap_in_lieu(before, hits) then false else throw Fault(vec, err),
    e => throw e,
  }
}

// VEX VSIB decoder: decode SIB for VEX gather instructions.
// Returns the base address, vector index register, scale, segment and
// address size.  Unlike EVEX, index register is only 4-bit (REX.X extends it).
// vex_check_form has raised the #UD of a register r/m, of a memory operand
// without a SIB byte, and of destination, index and mask registers that
// are not all distinct.
val decode_vsib_vex : (byte, Prefixes) -> VSIB
function decode_vsib_vex(modrm, pfx) = {
  let modbits : range(0, 3) = unsigned(modrm[7..6]);
  let sib = fetch(1);
  let scale : range(0, 3) = unsigned(sib[7..6]);
  let (seg, addr64) = vsib_seg_asize(sib, modbits, pfx);

  let base_idx : gpr_idx = unsigned(pfx.rex_b @ sib[2..0]);
  let vidx : simd_idx = unsigned(pfx.rex_x @ sib[5..3]);

  let base_val : qword =
    if sib[2..0] == 0b101 & modbits == 0 then {
      let b0 = fetch(1);
      let b1 = fetch(1);
      let b2 = fetch(1);
      let b3 = fetch(1);
      sign_extend(b3 @ b2 @ b1 @ b0)
    } else if modbits == 0 then {
      v(64, base_idx)
    } else if modbits == 1 then {
      let d8 = fetch(1);
      v(64, base_idx) + sign_extend(d8)
    } else {
      let b0 = fetch(1);
      let b1 = fetch(1);
      let b2 = fetch(1);
      let b3 = fetch(1);
      v(64, base_idx) + sign_extend(b3 @ b2 @ b1 @ b0)
    };

  struct { vsib_base = base_val, vsib_vidx = vidx, vsib_scale = scale,
           vsib_seg = seg, vsib_addr64 = addr64 }
}

// VEX gathers (VPGATHERDD/DQ/QD/QQ, VGATHERDPS/DPD/QPS/QPD): 'iw-bit
// indices and 'ew-bit elements, as many as the wider of the two fits in
// VL, under the mask register (VEX.vvvv), in the steps of the SDM's
// Operation (VPGATHERDD etc., Vol.2C p.5-552): first MASK[MAXVL-1:VL] := 0
// (VL/2 for qword indices and dword elements) and each mask element
// extended from its most significant bit ("MASK[i+31:i] := FFFFFFFFH; //
// extend from most significant bit"); then element by element from the
// LSB, a selected element loaded into the destination ("a fault exits the
// instruction") and its mask element cleared either way ("MASK[i+31:i] :=
// 0"); and last DEST[MAXVL-1:VL] := 0 (VL/2 likewise).  The registers are
// written as the steps go, so that a fault on an element leaves them
// "partially updated; those elements that have been gathered are placed
// into the destination register and have their mask bits set to zero"
// (p.5-551), and the destination above VL as it was, which the Operation
// clears only after the last element and the description does not let a
// fault touch.  The mask outside the signs of its elements is open: the
// Operation has done its first step before the first load, whereas the
// description lets the instruction leave only the gathered elements with
// "their mask bits set to zero" (it "can be suspended by an exception if
// at least one element is already gathered", p.5-551), and a fault
// otherwise restores the state from before the instruction (Vol.3A §7.5,
// p.7-5).  The model takes the Operation's order there.  With qword
// indices and dword elements, the parts above the elements, which "do not
// correspond to any elements", may be zeroed "even if the instruction
// triggers an exception" (p.5-551); the model zeroes them when the
// Operation does.  The APM says only that the registers "may be observed
// as partially updated" (VPGATHERDD, p.1397).
val vex_gather : forall 'vl 'iw 'ew, 'vl in {128, 256} & 'iw in {32, 64} & 'ew in {32, 64}.
  (implicit('vl), int('iw), int('ew), simd_idx, simd_idx, VSIB) -> unit
function vex_gather(vl, iw, ew, dst, mask_idx, vsib) = {
  let n = vl / (if iw >= ew then iw else ew);
  let indices : bits(512) = ZMM[vsib.vsib_vidx];
  let elem : bits(512) = zero_extend(ones() : bits('ew));
  var mask : bits(512) = zeros();
  foreach (i from 0 to (n - 1)) {
    let m : bits('ew) = (ZMM[mask_idx] >> (i * ew))[ew - 1 .. 0];
    if m[ew - 1] == bitone then mask = mask | (elem << (i * ew))
  };
  ZMM[mask_idx] = mask;
  let hits = pending_dbp;
  var stopped : bool = false;
  foreach (i from 0 to (n - 1)) {
    if ~(stopped) then {
      let olo = i * ew;
      if (mask >> olo)[0] == bitone then {
        let idx : bits('iw) = (indices >> (i * iw))[iw - 1 .. 0];
        match vsib_read(ew, gather_addr(vsib, idx), hits) {
          Some(v) => ZMM[dst] = (ZMM[dst] & ~(elem << olo)) | (zero_extend(v) << olo),
          None() => stopped = true,
        }
      };
      if ~(stopped) then ZMM[mask_idx] = ZMM[mask_idx] & ~(elem << olo)
    }
  };
  if ~(stopped) then ZMM[dst] = ZMM[dst] & (ones() >> (512 - n * ew))
}

// VEX.128/256.66.0F38.W0/W1 90-93 /vsib: the destination in ModRM.reg, the
// mask in VEX.vvvv, dword indices (90, 92) or qword indices (91, 93), and
// qword elements for VEX.W = 1.
val vex_exec_gather : forall 'iw, 'iw in {32, 64}. (int('iw), Prefixes) -> unit
function vex_exec_gather(iw, pfx) = {
  let modrm = fetch(1);
  let dst = modrm_xreg(modrm, pfx);
  let vsib = decode_vsib_vex(modrm, pfx);
  let ew : {32, 64} = if pfx.vex_w then 64 else 32;
  if pfx.vex_l then vex_gather(256, iw, ew, dst, pfx.vex_vvvv, vsib)
  else vex_gather(128, iw, ew, dst, pfx.vex_vvvv, vsib)
}
