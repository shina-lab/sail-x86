# Task: apply the proved rewrites to the corpus sources

Context. An experiment asked an LLM to shorten straight-line blocks of
handwritten x86-64 assembly from seven programs and proved or refuted each
proposal with symbolic execution. The population is
`/home/ruiu/sail-x86/verify/blocks/blocks.json`: one entry per distinct
block with `id`, `project`, `source` (the assembly source file, relative to
/home/ruiu), `file` (the object it was extracted from), `function`,
`start`/`end` (byte offsets of the block in that object's `.text`),
`insns` (the block's instructions as objdump prints them in Intel syntax,
with `[CONST_n]` standing for a RIP-relative constant listed in
`constants`), `level` (ISA level), `live_out` and `dups` (how many other
occurrences of the same block, modulo register names, exist). The check
results are `/home/ruiu/sail-x86/verify/blocks/results/w*.json`: for a
block id, `verdict` is `unsat` when the rewrite was PROVED equivalent (on
the live registers, flags and memory; everything else may differ), `sat`
when refuted; `rewrite` is the proved sequence as a list of Intel-syntax
instructions, `n_a`/`n_b` the instruction counts before and after.

The programs are checked out at the experiment's exact revisions under
`/home/ruiu/asm-corpora/`: `ffmpeg` (482395f), `libjpeg-turbo` (d9b5af9),
`linux` (50d05c7; only arch/x86/crypto, lib/crypto/x86, lib/crc/x86 were
used), `dav1d` (5fa003d, already built in `dav1d/build`), `openssl`
(70f39a4; the corpus used the perlasm OUTPUT `.s` files, which are not
in git: generate them with `perl <file>.pl elf <file>.s` as OpenSSL's
build does, commit them once as a base commit before editing so that a
diff shows only your edits), `glibc` (0f7b73f, sysdeps/x86_64/multiarch),
`gmp-6.3.0` (a git repository made from the tarball; the sources are
mpn/x86_64/*.asm, m4 macros).

Goal: for every PROVED rewrite (verdict unsat), edit the assembly source
so that the block becomes the rewritten sequence, in the dialect of that
file (nasm with x86inc.asm macros in FFmpeg/dav1d: `m0`, `mova`, `cglobal`
register names; nasm in libjpeg-turbo; GNU as AT&T syntax in the Linux
kernel and glibc and in OpenSSL's generated `.s`; m4 in GMP), leaving the
change UNCOMMITTED in the working tree so that `git diff` in each
directory shows exactly what was optimized. Where the same block occurs in
several places (`dups`, or the same macro expanded for several widths),
apply it to each occurrence you can identify. Do not touch anything else.

Method. Map object offsets to source lines by assembling the file with
debug information (nasm `-g -F dwarf`, gas `-g`) and `objdump -dl` or
`addr2line`; the objects the corpus used were built exactly as the
projects build them (FFmpeg: `nasm -f elf64 -g -F dwarf -Pconfig.asm
-I<dir>/ -I.` from /home/ruiu/ffmpeg; libjpeg-turbo and dav1d: their
build directories; Linux: `gcc -D__ASSEMBLY__ ... -c` with the tree's
include paths, see /home/ruiu/sail-x86/verify/blocks/extract_blocks.py and
the notes there). When a block comes from a macro body that is expanded
several times (x86inc `%macro`, kernel `.macro`, GMP m4), edit the macro
once if every expansion is a proved instance, otherwise skip it and say
so. After editing a file, re-assemble it and check with objdump that the
function now contains the rewritten sequence where the block was and that
nothing else changed; for libjpeg-turbo also run its test suite
(`cmake -B build && ninja -C build && ctest --test-dir build -j64`), for
dav1d rebuild (`ninja -C build`) and run `build/tests/checkasm/checkasm
--test=...` for the affected functions if checkasm is built, for the
kernel objects re-assemble as above, for glibc re-assemble the file with
the flags from `build/string/*.o.d` or the build log, for GMP `make` in
the tree and run `make check` in mpn if feasible. Prioritize by
instructions saved (`n_a - n_b`) times occurrences.

Write `/home/ruiu/asm-corpora/REWRITES.md`: one line per applied rewrite
(program, file, line range, function, block id, instructions before ->
after) and a second list of proved rewrites you could not apply with the
reason. Commit nothing in the seven checkouts except the OpenSSL base
commit described above. Do not modify /home/ruiu/sail-x86 or
/home/ruiu/papers. Use up to 128 threads for builds.
