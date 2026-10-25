---
name: lamem-initial-topo
description: Set up a non-flat initial free surface in LaMEM from a binary topography file (`surf_topo_file`) generated with GeophysicalModelGenerator's `save_LaMEM_topography`. Use this skill whenever the user wants an initial topography, a dome/ridge/valley/real DEM surface, a topography input for erosion, sedimentation or topographic-diffusion models, or hits topography-file errors ("does not cover … edge", "Incorrect sedimentation phase"). Trigger on phrases like "initial topography", "topo file", "surf_topo_file", "save_LaMEM_topography", "non-flat surface", "DEM", or `topo.bin`.
---

# LaMEM Initial Topography Setup

How to start a LaMEM model with a non-flat free surface from a binary topography file.
Checked against LaMEM v3.4.0 and GeophysicalModelGenerator.jl (GMG) 0.8.

---

## Overview

Without a file, the free surface starts flat at `surf_level`. With `surf_topo_file`, LaMEM reads a
regular x–y grid of elevations and interpolates it bilinearly onto the free-surface nodes
(`FreeSurfSetTopoFromFile`, `src/surf.cpp`). The file is written by GMG's `save_LaMEM_topography`.

---

## Step 1 — Write the Julia setup script

Build a `CartData` with a `Topography` field on a regular x–y grid that covers the model box, then save it.
This is the pattern of `test/t35_TopoDiffusion/TopoDiffusionCreateSetup.jl`:

```julia
using GeophysicalModelGenerator

function CreateInitialTopo(dir, topo_file)
    cur_dir = pwd()
    cd(dir)

    R      = 10.0                         # dome radius [km]
    x_vals = collect(-100.0:1.0:100.0)    # must cover coord_x
    y_vals = collect(-1.0:2.0:1.0)        # must cover coord_y (2 points are enough in 2D)

    X_t, Y_t, Z_t = xyz_grid(x_vals, y_vals, 0)

    Topo_z = zeros(length(x_vals), length(y_vals), 1)
    for i in eachindex(x_vals)
        Topo_z[i, :, 1] .= abs(x_vals[i]) < R ? sqrt(R^2 - x_vals[i]^2) : 0.0
    end

    Topo = CartData(X_t, Y_t, Z_t, (Topography=Topo_z,))
    save_LaMEM_topography(Topo, topo_file)

    cd(cur_dir)
end
```

**Key points:**
- **Cover the whole box.** The x/y grid must reach every edge of `coord_x` / `coord_y`, or LaMEM aborts
  with `Topography input file does not cover western/eastern/southern/northern edge of the LaMEM box!`.
- **Shape.** The z-size of the `CartData` must be 1, and the field must be named `Topography`. The z
  coordinate (`Z_t`) is ignored.
- **2D models:** LaMEM needs `nel_y = 2` (at least 2 cells per direction since v3.0.0). Two y-points
  spanning `coord_y` are enough for the file.
- **Units:** coordinates and elevations are in the model's input length unit, km for `units = geo`
  and m for `si`. LaMEM divides them by the length scale.
- **Non-uniform grids:** GMG interpolates an uneven x/y spacing onto a uniform grid before writing.
- **Real topography:** for a DEM, build the `CartData` from GMG's import tools (e.g. a
  `GeoData` → `CartData` projection), keep only the `Topography` field, and crop it to cover the box.

---

## Step 2 — Generate the file

Run the script before LaMEM. Use any environment that has GMG; the LaMEM repo project has it:

```bash
julia --project=/path/to/LaMEM -e '
  include("CreateInitialTopo.jl")
  CreateInitialTopo("./", "topo.bin")
'
```

In the test suite, the setup function is `include`d and called inside the `@testset` before
`perform_lamem_test`. This is done in t35, and t38 reuses the same dome. See `lamem-test-creator`.

---

## Step 3 — Reference the file in the `.dat` input

```
surf_use         = 1
surf_level       = 0          # required even with a file
surf_air_phase   = 0
surf_topo_file   = topo.bin   # relative to the directory LaMEM is run from
```

Every rank reads the whole file ("Loading topography redundantly from …" in the log), so keep its
resolution reasonable for large DEMs.

---

## File format (for debugging)

This is what LaMEM reads, from `PetscBinaryWrite_Vec` in GMG's `LaMEM_io.jl`. Every value is a
big-endian Float64:

```
header (1211214, ignored) | nx | ny | x0 | y0 | dx | dy | Z[1 .. nx*ny]
```

- `x0`, `y0` give the south-west corner.
- `Z` is x-fastest: `Z[ix + iy*nx]` with 0-based indices in LaMEM.

To check a file:

```julia
v = ntoh.(reinterpret(Float64, read("topo.bin")))
nx, ny, x0, y0, dx, dy = v[2:7]
Z = reshape(v[8:end], Int(nx), Int(ny))
```

---

## Important: marker availability above the reference level

The file moves only the **surface**. Material markers still come from your setup (`msetup = geom`,
files, or polygons). If the topography rises above where your rock phases end, cells below the
new surface contain only air markers. `ADVMarkCrossFreeSurf` (`src/subgrid.cpp`) then fails with
`Incorrect sedimentation phase` when it tries to turn them into rock.

The fix used in t35 is to put rock markers wherever the surface can be. For a dome, add a
`<SphereStart>` centred **at the surface level**, so its upper half fills the dome:

```
msetup = geom

<SphereStart>
    phase  = 2          # rock phase for the dome
    radius = 10         # same as the dome radius R
    center = 0 0 0      # centre at surface level, upper half protrudes into the air
<SphereEnd>
```

For general shapes, fill a rock layer up to the maximum elevation, or build the phase field in
Julia from the same topography: rock below `Topo_z`, air above.

---

## Example: `t35_TopoDiffusion`

| Setting | Value |
|---------|-------|
| Grid | 64×2×35, x = [-100, 100], y = [-1, 1], z = [-20, 15] km |
| `surf_topo_file` | `topo.bin` (written by `TopoDiffusionCreateSetup(dir, "topo.bin")`) |
| Shape | semicircular dome, R = 10 km, centred at x = 0 |
| Marker setup | `msetup = geom`, sphere (phase 2) at `center = 0 0 0`, `radius = 10` |
| Also used by | `t38_slope_dependent_erosion` (same dome) |

To look at the evolving surface, set `out_surf = 1` (with `out_surf_pvd`, `out_surf_topography`) and
read it with `read_LaMEM_timestep(...; surf = true)`. See the `lamem-visualization` skill.
