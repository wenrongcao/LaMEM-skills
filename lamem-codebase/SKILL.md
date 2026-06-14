---
name: lamem-codebase
description: Provides deep knowledge of the LaMEM (Lithosphere and Mantle Evolution Model) codebase — architecture, build system, conventions, and development workflows. Use this skill whenever working in the LaMEM repository, adding features, modifying physics, debugging, adding input parameters, or asking about any LaMEM source file, struct, or solver. Trigger on any mention of LaMEM, PETSc solvers, FDSTAG, JacRes, marker-in-cell, `.dat` input files, passive tracers, matrix-free solvers, periodic BCs, or phrases like "how does LaMEM work", "where is X implemented", or "how do I add Y to LaMEM".
---

# LaMEM Codebase Guide

LaMEM (v3.0.0) is a parallel 3D geodynamics code for thermo-mechanical processes with visco-elasto-plastic rheologies. It uses a **marker-in-cell** approach on a staggered finite difference grid, built on PETSc, and scales from laptops to 458,752 cores.

**Stack:** C++17 core · PETSc 3.19–3.25 · MPI · Julia test framework & integration

---

## Repository Layout

```
src/         C++ core source + LaMEM_C.jl module
test/        35 Julia-driven test cases (t01_…–t35_…)
examples/    Pre-configured model setups (BuiltInSetups, Localization, …)
doc/         Documenter.jl HTML documentation source
info/        Installation notes, solver options reference, ParaView tips
scripts/     bash/ and julia/ post-processing utilities
```

Version is tracked in `Project.toml` and printed by `LaMEMLib.cpp` (`Version : 3.0.0`).

---

## Build System

### Prerequisites
```bash
export PETSC_OPT=/path/to/petsc/optimized
export PETSC_DEB=/path/to/petsc/debug
```

### Compile from `src/`
```bash
make mode=opt all        # Production build  → bin/opt/LaMEM
make mode=deb all        # Debug build       → bin/deb/LaMEM
make mode=opt dylib      # Dynamic library (Julia integration) → lib/opt/LaMEMLib.dylib
make mode=opt clean_all  # Clean artifacts
```

**Build details:** Single `Makefile` (no separate `Makefile.in`). C++17, very strict warnings (`-Wall -Wextra -Wconversion -Wnon-virtual-dtor …`). Auto-detects compiler (gcc/clang/icpx). Builds `liblamem.a` then links `LaMEM`. Dependency tracking via `.d` files; force-rebuild via `dep/<mode>/makefile.stat`.

Supported platforms: x86_64, arm64/aarch64, armv6l/armv7l, i686, powerpc64le, amd64 (MSYS on Windows).

---

## Data Flow

```
Parse .dat → Create FDSTAG grid → Load/generate markers → Initialize fields
     ↓
Time Loop:
  1. Advect markers, update properties
  2. Nonlinear solve (JacRes): assemble/apply residual & Jacobian → linear solve → line search
  3. Update temperature (if active)
  4. Apply free surface erosion/sedimentation
  5. Apply topographic diffusion (last surface process)
  6. Advect/output passive tracers (if active)
  7. Write output (ParaView)
     ↓
Marker↔Grid coupling:
  markers carry material props → interpolate to grid → solve → interpolate vel back
  Conservative Velocity Interpolation (CVI) available as alternative
```

---

## Source Map (`src/`)

| Area | Files | Purpose |
|------|-------|---------|
| Entry | `LaMEM.cpp/h`, `LaMEMLib.cpp/h`, `LaMEM_C.jl` | Main program, library interface, Julia module |
| Grid | `fdstag.cpp/h` | Staggered grid, domain decomp, ghost cells, periodic topology |
| Solvers | `JacRes.cpp/h`, `JacResAux.cpp`, `JacResTemp.cpp`, `nlsolve.cpp/h`, `lsolve.cpp/h` | Residual/Jacobian (aux + temperature split), nonlinear (Picard/Newton), linear |
| Matrix layer | `matrix.cpp/h`, `matData.cpp/h`, `matAux.cpp`, `matFree.cpp/h`, `matBFBT.cpp` | Preconditioner matrices, matrix data, auxiliary ops, matrix-free operators, BFBT preconditioner |
| Solver options | `options.cpp/h` | Default PETSc solver-option presets (replaces old `DisplaySolverOptions`) |
| Time stepping | `tssolve.cpp/h`, `multigrid.cpp/h` | Time schemes, geometric multigrid (supports matrix-free levels) |
| Markers | `advect.cpp/h`, `marker.cpp/h`, `AVD.cpp/h`, `subgrid.cpp/h` | Marker advection, management, AVD, subgrid resampling |
| Velocity interp | `cvi.cpp/h` | Conservative Velocity Interpolation |
| Rheology | `constEq.cpp/h`, `meltParam.cpp/h`, `Tensor.cpp/h` | Visco-elasto-plastic constitutive equations, tensor algebra |
| Phases | `phase.cpp/h`, `phase_transition.cpp/h` | Phase definitions, transitions (adiabatic correction in Box/NotInAirBox) |
| BCs | `bc.cpp/h`, `surf.cpp/h` | Boundary conditions (incl. periodic), free surface + erosion + topographic diffusion |
| Passive tracers | `passive_tracer.cpp/h` | Lagrangian tracer tracking |
| Special | `dike.cpp/h`, `adjoint.cpp/h`, `objFunct.cpp/h` | Dike propagation (PBC-aware), inversion gradients (PBC-aware), objective functions |
| Output | `paraViewOut*.cpp/h`, `outFunct.cpp/h` | ParaView (AVD, binary, markers, surface, passive tracers) |
| Utilities | `parsing.cpp/h`, `scaling.cpp/h`, `interpolate.cpp/h`, `tools.cpp/h`, `asprintf.h` | I/O, scaling, interpolation, string utilities |

---

## What's New in v3.0.0 (vs v2.2.x)

### Matrix-free linear operators (`matFree.cpp/h`, `matData.cpp/h`)
Velocity-block matrix-vector products and diagonal extraction without assembling the matrix. Activated per solver:
```
-js_mat_free                       # matrix-free Jacobian for Krylov solve
-gmg_mat_free_levels <N>           # number of top MG levels run matrix-free
                                   # (followed by one assembled level)
```
Limitations: block preconditioner does not support matrix-free MG; 2D coarsening does not support matrix-free MG.

### BFBT block preconditioner (`matBFBT.cpp`)
Block factorization preconditioner with BFBT Schur-complement approximation. See `info/options/solver_options.txt` for `-bf_*` options.

### Coupled direct solver
New support for `-jp_type user` with coupled direct factorisation; requires PETSc 3.24/3.25. The `penalty` knob (`<SolverOptionsStart>`, default `1e3`) now applies to **all** direct solvers, not just `block_direct`. On non-x86 builds (e.g. aarch64) `coupled_direct` with `direct_solver_type = mumps` and a lowered `penalty = 1e2` is the configuration the test suite uses for cross-architecture stability.

### Periodic boundary conditions (PBC) end-to-end
`periodic` flag in `fdstag` propagates through `bc`, `surf` (free surface), `dike`, and `adjoint`. Incompatibilities are checked at startup (e.g., no-slip on bottom is required; xx/xy background strain rates not allowed). See `examples/PeriodicFreeSurface/`.

### Solver-options presets (`options.cpp/h`)
`solverOptionsSetDefaults()` populates sensible PETSc options based on problem type so newcomers get a working solver without writing a `<PetscOptionsStart>` block. All values can still be overridden in the `.dat`.

### Directory reorganisation
- `input_models/` → `examples/` (with `BuiltInSetups`, `Localization`, `PeriodicFreeSurface`, `SubductionWithParticles`)
- `matlab/` and `utils/` directories **removed**
- `info/` directory added with installation guides, solver-options reference, and ParaView tips
- `scripts/` split into `bash/` and `julia/`

### Grid: minimum 2 cells per direction (breaking change)
FDSTAG now aborts setup if any direction has fewer than 2 cells (`fdstag.cpp:71`, `MeshSeg1DReadParam`). 2D (x-z) setups that previously used `nel_y = 1` must use `nel_y = 2`. Error message: `Less than two cells are specified in the <dir> - direction`.

---

## Critical Conventions

### Non-dimensionalization
All internal calculations are non-dimensionalized. Always apply the correct scaling unit when reading parameters:
```c
getScalarParam(fb, _REQUIRED_, "er_rates", surf->erRates, surf->numErPhs, scal->velocity);
```

### Memory & error handling
```c
PetscMalloc() / PetscFree()           // allocation
DMCreateGlobalVector() / VecDestroy() // vectors
PetscCall(ierr);  // or  CHKERRQ(ierr);
```

### Grid access (macros from `fdstag.h`)
```c
START_STD_LOOP / END_STD_LOOP   // standard cell loop
COORD_NODE(i, sx, dsx)          // node coordinate
COORD_CELL(i, sx, dsx)          // cell center coordinate
SIZE_NODE / SIZE_CELL           // cell sizes
```

### Parallel output
```c
PetscPrintf(PETSC_COMM_WORLD, "...");  // parallel-safe
printf("...");                          // never use
```

### Ghost cell updates
```c
LOCAL_TO_LOCAL(...)
GLOBAL_TO_LOCAL(...)
```

---

## Input File Format (`.dat`)

```
#===== section separator (comment) =====
param_name  = value
array_param = val1 val2 val3

<MaterialStart>
    ID  = 0
    rho = 2700
<MaterialEnd>

<PetscOptionsStart>
    -snes_monitor
<PetscOptionsEnd>
```

Parsing functions: `getIntParam()`, `getScalarParam()`, `getStringParam()`.
Second argument is `_REQUIRED_` or `_OPTIONAL_`.

Reference of every available `.dat` parameter: `info/options/input_file.dat`.
Reference of every solver option / prefix: `info/options/solver_options.txt`.

---

## Common Workflows

### Adding a new input parameter
1. Add member to the relevant struct (e.g., `FreeSurf` in `surf.h`)
2. Read in the `Create` function with `get*Param()` and the correct scaling unit
3. Add to the print-summary section
4. Implement the functionality
5. Document in `info/options/input_file.dat`

### Modifying physics
1. Find residual assembly in `JacRes.cpp` / `JacResAux.cpp` / `JacResTemp.cpp`
2. Edit residual/Jacobian — **preserve symmetry** for iterative solvers
3. If matrix-free is used, mirror the change in `matFree.cpp`
4. Update marker properties if needed (`marker.cpp`, `phase.cpp`)
5. Test on 1 core with a small grid first; then verify on 2/4 cores

### Debugging
```bash
make mode=deb all   # debug build with PETSc checks
```
Add to `.dat` PetscOptions block:
```
-snes_monitor   # nonlinear convergence
-ksp_monitor    # linear solver progress
```
Key convergence indicators: `|Div|_inf`, `|Div|_2`, `|mRes|_2`.
For parallel issues: reproduce on 1 → 2 → 4 cores.

### Running tests
```bash
cd test
make test                                       # compiles LaMEM + runs full suite
julia --project=../. start_tests.jl             # direct invocation
julia --project=../. start_tests.jl is64bit     # 64-bit integer build
julia --project=../. start_tests.jl use_dynamic_lib   # link via PETSc_jll
```
Test utilities are in `test/julia/` and `test/test_utils.jl`. See the `lamem-test-creator` skill for adding new tests.
