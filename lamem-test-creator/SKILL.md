---
name: lamem-test-creator
description: Create, configure, and run LaMEM simulation tests in Julia. Use this skill whenever the user wants to add a new test case to the LaMEM test suite, generate expected output files, write marker creation scripts, update runtests.jl, or verify test results. Trigger on phrases like "add a test", "create a test", "new LaMEM test", "expected output", or any mention of `perform_lamem_test`, `runtests.jl`, or test directories.
---

# LaMEM Test Creator

A skill for creating and registering new tests in the LaMEM Julia test suite (v3.1.0).

## Overview

LaMEM tests live in `test/t<N>_<Name>/` directories and are driven by Julia's `@testset` blocks in `test/runtests.jl`. Each test runs a LaMEM simulation and compares log output against a pre-recorded `.expected` file using numerical tolerances.

Current numbering on `master` goes up to `t36_spatially_limited_erosion`; the next new test is `t37_…`.

> **Check open PRs before claiming a number.** Several in-flight branches can claim the same `t<N>`
> at once (`t37` was claimed by two open PRs simultaneously). Whoever merges second has to renumber,
> so verify with `gh pr list --repo UniMainzGeo/LaMEM --state open` and say in your PR description
> which number you took.

---

## Step-by-Step: Creating a New Test

### Step 1 — Create the test directory

```bash
mkdir test/t<N>_<Name>
```

Use the next available number `N` in the sequence and a short snake_case `<Name>`.

---

### Step 2 — Add required files

| File | Purpose |
|------|---------|
| `<test_name>.dat` | LaMEM input parameter file |
| `<Name>CreateSetup.jl` or `CreateMarkers_<Name>.jl` | Julia setup script (only if markers/topography are generated) |

Additional files may include topography binaries, phase diagrams, or other inputs referenced by the `.dat`.

---

### Step 3 — Choose a setup method

| Method | When to use |
|--------|-------------|
| **Julia setup script** | Complex geometry, topography files, non-trivial phase distributions, or when reusing `GeophysicalModelGenerator` tools |
| **Built-in geometry** (`msetup=geom` in `.dat`) | Simple boxes/spheres, no Julia setup needed |

#### Option A — Julia setup script template

```julia
using GeophysicalModelGenerator

function CreateMarkers_t<N>(dir, ParamFile;
        NumberCores=1, mpiexec="mpiexec", is64bit=false)
    cur_dir = pwd()
    cd(dir)

    Grid  = read_LaMEM_inputfile(ParamFile)
    Phase = ones(Int64,   size(Grid.X))
    Temp  = ones(Float64, size(Grid.X)) * 1350.0

    # add_box!(Phase, Temp, Grid;
    #     xlim=(-100,100), ylim=(-1,1), zlim=(0,50),
    #     phase=ConstantPhase(0), T=nothing)

    Model3D = CartData(Grid, (Phases=Phase, Temp=Temp))
    save_LaMEM_markers_parallel(Model3D, directory="./markers", verbose=false)

    cd(cur_dir)
end
```

A topography-only setup (e.g. `t35_TopoDiffusion/TopoDiffusionCreateSetup.jl`) simply calls `save_LaMEM_topography(Topo, topo_file)` instead of `save_LaMEM_markers_parallel`.

> **Note:** `read_LaMEM_inputfile` cannot parse inline `# comments` on value lines. Strip inline comments from `.dat` value lines before calling.

#### Option B — Built-in geometry (no setup script)

```
msetup     = geom
bg_phase   = 1
rand_noise = 1

<BoxStart>
    phase  = 0
    bounds = -100 100 -1 1 0 50   # xmin xmax ymin ymax zmin zmax
<BoxEnd>

<SphereStart>
    phase  = 2
    radius = 10
    center = 0 0 0
<SphereEnd>
```

---

### Step 4 — Generate the expected output file

The recommended flow is the **`update` mode** (v3.1.0): register the test first (Step 5) with
`create_expected_file=update_expected, clean_dir=clean_files`, then generate only your test's
reference file and commit it:

```bash
cd test
make update 37        # writes t37's .expected; other tests untouched
make test 37          # re-run normally to confirm it now passes
```

Selecting the test number matters — a bare `make update` overwrites **every** `.expected` in the suite.

Or run LaMEM manually from the test directory:

```bash
cd test/t<N>_<Name>

# If a Julia setup script is needed, run it first.
# Then run LaMEM and capture the log:
../../bin/opt/LaMEM -ParamFile <test_name>.dat -nstep_max 2 \
  > <test_name>_opt.expected
```

The `.expected` filename convention is `<TestKey>.expected` where `<TestKey>` is the short string passed as `expectedFile` (without the `.expected` extension — see Step 5). Older tests append `-p<N>` for the core count; new tests usually skip that.

Commit the `.expected` file to the repository.

---

### Step 5 — Register the test in `runtests.jl`

Append a new `@testset` block **inside** the outer `@testset "LaMEM Testsuite"` (before the final `end`). Always close the previous `@testset` with its own `end` before opening a new one — a missing `end` silently nests the new block and it won't appear as its own row in the summary.

**v3.1.0: wrap the testset in `should_run_test(...)`.** Every testset sits inside an
`if should_run_test("t<N>_<Name>")` guard so the selectors below can skip it. Omitting the guard
means your test runs on *every* invocation, including `make test 05`. Note the resulting **two**
`end`s — one for the `@testset`, one for the `if`.

```julia
#---------------------------------------------------------------------------
if should_run_test("t<N>_<Name>")
@testset "t<N>_<Name>" begin
    cd(test_dir)
    dir = "t<N>_<Name>"

    # Only include if a Julia setup script exists:
    # include(joinpath(dir, "CreateMarkers_t<N>.jl"))

    keywords = ("|Div|_inf", "|Div|_2", "|mRes|_2")
    acc      = ((rtol=1e-6, atol=1e-6),
                (rtol=1e-5, atol=5e-5),
                (rtol=2.5e-4, atol=1e-4))

    ParamFile = "<test_name>.dat"

    # Only call if you have a setup script:
    # CreateMarkers_t<N>(dir, ParamFile; NumberCores=1, mpiexec=mpiexec)

    @test perform_lamem_test(dir, ParamFile, "<TestKey>_opt";
        keywords = keywords,
        accuracy = acc,
        cores    = 1,
        opt      = true,
        mpiexec  = mpiexec,
        create_expected_file = update_expected,
        clean_dir            = clean_files)
end
end
```

**Key points:**
- `expectedFile` is passed **without** the `.expected` extension (`perform_lamem_test` adds it).
- `update_expected` and `clean_files` are derived from the `mode=` flag at the top of `runtests.jl` — always pass them through.
- The guard name must match the `t<N>_` prefix: `should_run_test` parses it with `^t0*(\d+)_`. A name it can't parse fails open (always runs).
- Don't hand-roll cleanup of generated inputs. `clean_dir=true` already deletes `*.bin`, `*.out`, `*.log`, `markers*`, and `restart` from the test directory — an extra `rm(joinpath(dir, topo_file))` will fail with `ENOENT`.
- After running the suite, confirm the new test appears as its **own row** in the Test Summary.

---

## Naming Conventions

When a test is named `t<N>_<Name>`, use the same `t<N>_` prefix for every test-specific file inside the directory (setup script, generated topo/phase-diagram inputs, function names defined in those scripts). String references inside the `.dat` (e.g. `surf_topo_file = t<N>_topo.bin`) should match. Consistent prefixing keeps renumbering and renaming mechanical.

The `<TestKey>` used for the `.expected` filename does not need the `t<N>_` prefix — short descriptive keys like `TopoDiffusion_opt` or `RidgeGeom_oblique_2cores` are typical.

---

### Step 6 — Verify the test passes

```bash
cd test
make test 37     # just your test, while iterating
make test        # full suite, before pushing
```

Check the **Test Summary** table; the new test must appear as its **own row** with the expected pass count.

---

## Running the Test Suite

From the `test/` directory:

```bash
# Canonical entry point (compiles LaMEM + runs full suite via Pkg.test)
make test

# Or direct invocation
julia --project=../. start_tests.jl

# Options (passed as positional ARGS)
julia --project=../. start_tests.jl use_dynamic_lib   # link via PETSc_jll
julia --project=../. start_tests.jl is64bit           # 64-bit integer build
```

The driver runs `Pkg.test("LaMEM_C")` (the project is named `LaMEM_C`, not `LaMEM`).

### Makefile targets (v3.1.0)

| Target | Effect |
|--------|--------|
| `make test` | Run tests, delete generated output afterwards (`mode=test`) |
| `make work` | Run tests, **keep** generated files for inspection (`mode=work`) |
| `make update` | Run tests and **OVERWRITE** the `.expected` files (`mode=update`) |
| `make grind` | Run under Valgrind, then check the report for leaks / uninitialised values |
| `make report` | Re-check `.xml` from a previous `make grind` without re-running it |
| `make check` | Run with `-log_view`; fail on any PETSc object creation/destruction mismatch |
| `make clean` | Remove leftover generated files |

There is no `make purge`. `make check` is a cheap leak gate worth running on any test that touches
PETSc objects.

### Test selectors

Any bare number or hyphenated range after the target selects a subset; everything else
(`is64bit`, `valgrind`, …) is ignored as a selector:

```bash
make test 01 05 32       # only t01, t05, t32
make test 03-07 11       # a range plus a single test
make update 37           # regenerate only t37's expected file
make check 12-17         # object-balance check on a range
```

With no selector, the whole suite runs. Selection is implemented by `parse_test_selectors` /
`should_run_test` at the top of `runtests.jl`.

### Regenerating `.expected` files

**Changed in v3.1.0.** The old hand-edited `maintenance = true` / `update_expected = true` block at
the top of `runtests.jl` is gone. The mode now comes from the Makefile target, so there are no flags
left to forget to reset before committing:

```bash
make update 37     # regenerate one test's expected file
make update        # regenerate ALL of them -- rarely what you want
```

Internally `runtests.jl` parses `mode=test|work|update` from `ARGS` into `test_mode`, and derives
`update_expected = (test_mode == "update")` and `clean_files = (test_mode != "work")`. Inspect the
resulting diff before committing: an `.expected` file records the full log, so an unintended
numerical change shows up there.

---

## Reference: `perform_lamem_test()` Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `dir` | String | Test directory name |
| `ParamFile` | String | LaMEM `.dat` input file |
| `expectedFile` | String | Reference key **without** `.expected` extension |
| `keywords` | Tuple | Strings to extract from the log |
| `accuracy` | Tuple | `(rtol=…, atol=…)` per keyword |
| `cores` | Int | Number of MPI cores (default 1) |
| `opt` | Bool | Use optimized build (default `true`) |
| `deb` | Bool | Use debug build (default `false`) |
| `args` | String | Extra CLI arguments for LaMEM |
| `bin_dir` | String | LaMEM binary directory (default `"../bin"`) |
| `mpiexec` | String/Cmd | MPI launcher |
| `split_sign` | String | Separator used when parsing log values (default `"="`) |
| `debug` | Bool | Print output without comparing |
| `create_expected_file` | Bool | Write `.expected` instead of comparing |
| `clean_dir` | Bool | Clean the test dir afterwards (default `true`) — removes `Timestep*/`, `*.pvd`, `*.bin`, `*.out`, `*.log`, `markers*`, `restart` |
| `valgrind` | Bool | Run under Valgrind (defaults to the `use_valgrind` global, i.e. `make grind`) |
| `memcheck` | Bool | Run with `-log_view` and check PETSc object create/destroy balance (defaults to `use_memcheck`, i.e. `make check`) |

---

## Helper Functions (`test/test_utils.jl`)

| Function | Purpose |
|----------|---------|
| `run_lamem_local_test()` | Execute a LaMEM simulation (with optional MPI) |
| `CreatePartitioningFile_local()` | Generate processor partitioning for parallel runs |
| `compare_logfiles()` | Numerically compare two log files |
| `clean_test_directory()` | Remove `*.out`, `*.log`, `*.bin`, `*.vts`, `markers*`, `restart`, `ProcessorPartitioning*`, etc. |

IO helpers (markers, topography, VTR/VTS reads) live in `test/julia/IO_functions.jl`.

---

## Running `perform_lamem_test` Outside `runtests.jl`

`test_utils.jl` expects `use_dynamic_lib` and the `IO_functions` module to be loaded:

```julia
using GeophysicalModelGenerator
include("julia/IO_functions.jl")
using .IO_functions
use_dynamic_lib = false
include("test_utils.jl")
```

---

## Cleaning Up a Test Directory

```bash
cd test/t<N>_<Name>
rm -rf markers/ Timestep_* *.vts *.pvd *.out output* LaMEM_ModelSetup*
```

---

## Common Pitfalls

### `.dat` parameters required to avoid crashes

| Symptom | Fix |
|---------|-----|
| "Specify reference viscosity for initial guess" | Add `init_guess = 1` and `eta_ref = 1e20` |
| SNES divergence with zero gravity | Use `gravity = 0 0 -9.81` instead of `gravity = 0 0 0` |
| Direct solver instability / `DIVERGED_NANORINF` at iteration 0 | Set `penalty` in `<SolverOptionsStart>` (e.g. `penalty = 1e2`); applies to both `coupled_direct` and `block_direct` |
| "Requested number of multigrid levels exceeds maximum possible" | Reduce MG levels or coarsen the grid |
| "Less than two cells are specified in the &lt;dir&gt; - direction" (`fdstag.cpp:71`) | FDSTAG (since v3.0.0) requires **≥ 2 cells in every direction**. For a 2D (x-z) setup set `nel_y = 2` (older LaMEM allowed `nel_y = 1`). Same applies to `nel_x` / `nel_z`. |

### `ADVMarkCrossFreeSurf` — marker availability at the free surface

If the free surface can move **upward** (via diffusion, sedimentation, or advection), rock markers must already exist in cells above the initial surface. Without them, LaMEM aborts with:

```
Incorrect sedimentation phase
```

**Solution:** use `msetup=geom` with a sphere whose centre is at the surface level. The upper hemisphere pre-fills above-surface cells with rock markers:

```
<SphereStart>
    phase  = 2          # rock phase for the elevated region
    radius = <R>        # match the radius of the topographic feature
    center = 0 0 <surf_level>   # centre AT surface level, upper half protrudes into air
<SphereEnd>
```

### Inline comments in `.dat` files

`read_LaMEM_inputfile` (used by `GeophysicalModelGenerator`) cannot parse inline `# comments` on parameter value lines. Strip all inline comments from value lines before calling this function.

### Periodic BC compatibility (since v3.0.0)

When `periodic = 1` is set in `fdstag`, LaMEM aborts at startup if any of these are also set:
- `noslip` on left/right (must be no-slip on bottom instead)
- non-zero `exx_num_periods`, `exy_num_periods`
- `bvel_face`, `fix_phase`, `fix_cell`

A periodic free-surface example is in `examples/PeriodicFreeSurface/`.

### Matrix-free solver compatibility

Matrix-free linear operators (`-js_mat_free`, `-gmg_mat_free_levels`) are not supported with the block preconditioner or with 2D coarsening. Use the user-defined coupled preconditioner if matrix-free is required.

### Cross-architecture tolerances (x86_64 vs aarch64)

BLAS/LAPACK and MUMPS factorization round in a different order on non-x86 architectures, so divergence-norm keywords like `|Div|_inf` / `|Div|_2` can drift past tight `rtol`. The suite handles this by:

- Loosening tolerances (often switching tight `rtol` to a small `atol`), and
- For the most sensitive cases (e.g. `t16_PhaseTransitions`, `t19_CompensatedInflow`) checking **only** `|mRes|_2` with a relaxed tolerance, e.g. `keywords = ("|mRes|_2",)` with `acc = ((rtol=1e-1, atol=2e-2),)`.

When a new or existing test fails only on aarch64 with a near-threshold numeric drift (not a real divergence), prefer relaxing the tolerance / narrowing keywords over forcing a per-architecture `.expected` file.

### Maximum 30 timesteps

Tests must finish quickly — keep `nstep_max <= 30`. Use the `args = "-nstep_max <N>"` parameter rather than baking long runs into the `.dat`.
