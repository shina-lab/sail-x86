// x86-64 — FMA Shared Helpers
//
// Polymorphic FMA helpers and scalar dispatch.

// FMADDSUB: even elements get a*b-c, odd elements get a*b+c.
val avx_fmaddsub : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {16, 32, 64}.
  (int('eb), bits('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_fmaddsub(eb, a, b, c) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    let ae = velem('eb, a, i);
    let be = velem('eb, b, i);
    let ce = velem('eb, c, i);
    r[(lo + 'eb - 1)..lo] =
      if i % 2 == 0 then fp_fmsub(ae, be, ce) else fp_fmadd(ae, be, ce);
  };
  r
}

// FMSUBADD: even elements get a*b+c, odd elements get a*b-c.
val avx_fmsubadd : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {16, 32, 64}.
  (int('eb), bits('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_fmsubadd(eb, a, b, c) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    let ae = velem('eb, a, i);
    let be = velem('eb, b, i);
    let ce = velem('eb, c, i);
    r[(lo + 'eb - 1)..lo] =
      if i % 2 == 0 then fp_fmadd(ae, be, ce) else fp_fmsub(ae, be, ce);
  };
  r
}

// exec_vfma_scalar and FMAOrder are defined in insn_vex.sail

