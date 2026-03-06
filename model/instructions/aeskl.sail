// AES Key Locker Instructions
// AESENC128KL, AESDEC128KL, AESENC256KL, AESDEC256KL — Single-block Key Locker
// AESENCWIDE128KL, AESDECWIDE128KL, AESENCWIDE256KL, AESDECWIDE256KL — Wide Key Locker
//
// These instructions use wrapped keys (handles) stored in memory to perform
// AES encryption/decryption. They involve key unwrapping and authentication
// which are complex implementation-defined operations. Model as external.
// ZF is set to 1 on failure, 0 on success. OF/SF/AF/PF/CF cleared.

val __aesenc128kl : (xmmword, bits(384)) -> (bit, xmmword)
val __aesdec128kl : (xmmword, bits(384)) -> (bit, xmmword)
val __aesenc256kl : (xmmword, zmmword) -> (bit, xmmword)
val __aesdec256kl : (xmmword, zmmword) -> (bit, xmmword)

// Wide variants operate on 8 XMM registers (XMM0-XMM7) simultaneously.
// Takes the 8 input blocks and handle, returns success flag and 8 output blocks.
val __aesencwide128kl : (xmmword, xmmword, xmmword, xmmword,
                         xmmword, xmmword, xmmword, xmmword,
                         bits(384)) -> (bit, xmmword, xmmword, xmmword, xmmword,
                                             xmmword, xmmword, xmmword, xmmword)
val __aesdecwide128kl : (xmmword, xmmword, xmmword, xmmword,
                         xmmword, xmmword, xmmword, xmmword,
                         bits(384)) -> (bit, xmmword, xmmword, xmmword, xmmword,
                                             xmmword, xmmword, xmmword, xmmword)
val __aesencwide256kl : (xmmword, xmmword, xmmword, xmmword,
                         xmmword, xmmword, xmmword, xmmword,
                         zmmword) -> (bit, xmmword, xmmword, xmmword, xmmword,
                                             xmmword, xmmword, xmmword, xmmword)
val __aesdecwide256kl : (xmmword, xmmword, xmmword, xmmword,
                         xmmword, xmmword, xmmword, xmmword,
                         zmmword) -> (bit, xmmword, xmmword, xmmword, xmmword,
                                             xmmword, xmmword, xmmword, xmmword)

// Helper: clear OF/SF/AF/PF/CF, set ZF based on success flag
val set_kl_flags : bit -> unit
function set_kl_flags(ok) = {
  ZF = if ok == bitone then bitzero else bitone;
  OF = bitzero;
  SF = bitzero;
  AF = bitzero;
  PF = bitzero;
  CF = bitzero;
}

// AESENC128KL — AES Encrypt 128-bit with Key Locker
val exec_aesenc128kl : (simd_idx, bits(384)) -> ExecutionResult
function exec_aesenc128kl(dst, handle) = {
  let data : xmmword = read_xmm(dst);
  let (ok, result) = __aesenc128kl(data, handle);
  if ok == bitone then write_xmm_legacy(dst, result);
  set_kl_flags(ok);
  Ok(())
}

// AESDEC128KL — AES Decrypt 128-bit with Key Locker
val exec_aesdec128kl : (simd_idx, bits(384)) -> ExecutionResult
function exec_aesdec128kl(dst, handle) = {
  let data : xmmword = read_xmm(dst);
  let (ok, result) = __aesdec128kl(data, handle);
  if ok == bitone then write_xmm_legacy(dst, result);
  set_kl_flags(ok);
  Ok(())
}

// AESENC256KL — AES Encrypt 256-bit with Key Locker
val exec_aesenc256kl : (simd_idx, zmmword) -> ExecutionResult
function exec_aesenc256kl(dst, handle) = {
  let data : xmmword = read_xmm(dst);
  let (ok, result) = __aesenc256kl(data, handle);
  if ok == bitone then write_xmm_legacy(dst, result);
  set_kl_flags(ok);
  Ok(())
}

// AESDEC256KL — AES Decrypt 256-bit with Key Locker
val exec_aesdec256kl : (simd_idx, zmmword) -> ExecutionResult
function exec_aesdec256kl(dst, handle) = {
  let data : xmmword = read_xmm(dst);
  let (ok, result) = __aesdec256kl(data, handle);
  if ok == bitone then write_xmm_legacy(dst, result);
  set_kl_flags(ok);
  Ok(())
}

// AESENCWIDE128KL — AES Encrypt 8 Blocks with 128-bit Key Locker
val exec_aesencwide128kl : bits(384) -> ExecutionResult
function exec_aesencwide128kl(handle) = {
  let x0 : xmmword = read_xmm(0);
  let x1 : xmmword = read_xmm(1);
  let x2 : xmmword = read_xmm(2);
  let x3 : xmmword = read_xmm(3);
  let x4 : xmmword = read_xmm(4);
  let x5 : xmmword = read_xmm(5);
  let x6 : xmmword = read_xmm(6);
  let x7 : xmmword = read_xmm(7);
  let (ok, r0, r1, r2, r3, r4, r5, r6, r7) =
    __aesencwide128kl(x0, x1, x2, x3, x4, x5, x6, x7, handle);
  if ok == bitone then {
    write_xmm_legacy(0, r0);
    write_xmm_legacy(1, r1);
    write_xmm_legacy(2, r2);
    write_xmm_legacy(3, r3);
    write_xmm_legacy(4, r4);
    write_xmm_legacy(5, r5);
    write_xmm_legacy(6, r6);
    write_xmm_legacy(7, r7);
  };
  set_kl_flags(ok);
  Ok(())
}

// AESDECWIDE128KL — AES Decrypt 8 Blocks with 128-bit Key Locker
val exec_aesdecwide128kl : bits(384) -> ExecutionResult
function exec_aesdecwide128kl(handle) = {
  let x0 : xmmword = read_xmm(0);
  let x1 : xmmword = read_xmm(1);
  let x2 : xmmword = read_xmm(2);
  let x3 : xmmword = read_xmm(3);
  let x4 : xmmword = read_xmm(4);
  let x5 : xmmword = read_xmm(5);
  let x6 : xmmword = read_xmm(6);
  let x7 : xmmword = read_xmm(7);
  let (ok, r0, r1, r2, r3, r4, r5, r6, r7) =
    __aesdecwide128kl(x0, x1, x2, x3, x4, x5, x6, x7, handle);
  if ok == bitone then {
    write_xmm_legacy(0, r0);
    write_xmm_legacy(1, r1);
    write_xmm_legacy(2, r2);
    write_xmm_legacy(3, r3);
    write_xmm_legacy(4, r4);
    write_xmm_legacy(5, r5);
    write_xmm_legacy(6, r6);
    write_xmm_legacy(7, r7);
  };
  set_kl_flags(ok);
  Ok(())
}

// AESENCWIDE256KL — AES Encrypt 8 Blocks with 256-bit Key Locker
val exec_aesencwide256kl : zmmword -> ExecutionResult
function exec_aesencwide256kl(handle) = {
  let x0 : xmmword = read_xmm(0);
  let x1 : xmmword = read_xmm(1);
  let x2 : xmmword = read_xmm(2);
  let x3 : xmmword = read_xmm(3);
  let x4 : xmmword = read_xmm(4);
  let x5 : xmmword = read_xmm(5);
  let x6 : xmmword = read_xmm(6);
  let x7 : xmmword = read_xmm(7);
  let (ok, r0, r1, r2, r3, r4, r5, r6, r7) =
    __aesencwide256kl(x0, x1, x2, x3, x4, x5, x6, x7, handle);
  if ok == bitone then {
    write_xmm_legacy(0, r0);
    write_xmm_legacy(1, r1);
    write_xmm_legacy(2, r2);
    write_xmm_legacy(3, r3);
    write_xmm_legacy(4, r4);
    write_xmm_legacy(5, r5);
    write_xmm_legacy(6, r6);
    write_xmm_legacy(7, r7);
  };
  set_kl_flags(ok);
  Ok(())
}

// AESDECWIDE256KL — AES Decrypt 8 Blocks with 256-bit Key Locker
val exec_aesdecwide256kl : zmmword -> ExecutionResult
function exec_aesdecwide256kl(handle) = {
  let x0 : xmmword = read_xmm(0);
  let x1 : xmmword = read_xmm(1);
  let x2 : xmmword = read_xmm(2);
  let x3 : xmmword = read_xmm(3);
  let x4 : xmmword = read_xmm(4);
  let x5 : xmmword = read_xmm(5);
  let x6 : xmmword = read_xmm(6);
  let x7 : xmmword = read_xmm(7);
  let (ok, r0, r1, r2, r3, r4, r5, r6, r7) =
    __aesdecwide256kl(x0, x1, x2, x3, x4, x5, x6, x7, handle);
  if ok == bitone then {
    write_xmm_legacy(0, r0);
    write_xmm_legacy(1, r1);
    write_xmm_legacy(2, r2);
    write_xmm_legacy(3, r3);
    write_xmm_legacy(4, r4);
    write_xmm_legacy(5, r5);
    write_xmm_legacy(6, r6);
    write_xmm_legacy(7, r7);
  };
  set_kl_flags(ok);
  Ok(())
}
