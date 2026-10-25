---
name: lamem-visualization
description: Read LaMEM output into Julia and make figures with LaMEM.jl and CairoMakie — profiles, time histories, cross-sections, model-vs-model and model-vs-analytical comparisons, and figures for pull requests. Use this skill whenever the user wants to plot, visualize, post-process or quantitatively check LaMEM results, compare runs, verify a change against an analytical solution, or attach plots to a PR. Trigger on phrases like "plot", "visualize", "make a figure", "compare the runs", "analytical solution", "profile", "cross-section", "time series", or any mention of `read_LaMEM_timestep`, `read_LaMEM_simulation`, `crosssection`, `view_model`, CairoMakie/GLMakie, `.pvd`/`.pvtr`/`.vtr` output or `Timestep_*` directories.
---

# LaMEM Visualization with Julia

How to get LaMEM output into Julia, plot it reproducibly with CairoMakie, and use the plots as
evidence (verification against analytical solutions, before/after comparisons, PR figures).
Checked against LaMEM v3.4.0 and LaMEM.jl 0.5.6.

---

## 1. Environment

| Environment | Has | Use for |
|---|---|---|
| default (`julia`, `~/.julia/environments/v1.x`) | `LaMEM` (LaMEM.jl), `CairoMakie`/`GLMakie`, `GeophysicalModelGenerator` | **all plotting and post-processing** |
| `test/` project (`Pkg.test("LaMEM_C")`) | its own copy of the readers in `test/julia/IO_functions.jl` | only inside the test suite |

`julia --project=..` from `test/` fails with `Package ReadVTK not found`. The reader copy there needs
the test environment that `make test` sets up, so run plotting scripts in the default environment.

Use **CairoMakie** for scripts and figures because it works headless and writes PNGs. Use **GLMakie**
only for interactive work (`view_model`). Its 3D panel stays empty under CairoMakie.

**Which LaMEM binary produced the data.** `run_lamem(model, n)` in LaMEM.jl runs the binary bundled
with the package (`LaMEM_jll`), **not your local build**. To look at the effect of a change to `src/`:
1. Run the local binary yourself, e.g. `bin/opt/LaMEM -ParamFile model.dat`.
2. Read its output directory with the functions below.

## 2. Make LaMEM write what you want to plot

In the `.dat` file:

```
out_file_name    = mymodel      # -> mymodel.pvd + Timestep_*/mymodel.pvtr
out_pvd          = 1
out_temperature  = 1            # each field needs its own out_* flag
out_conductivity = 1            # out_velocity, out_pressure, out_j2_dev_stress, ...
nstep_out        = 1            # output frequency, needed for time histories
dt_out           = 0.02         # LaMEM also writes when time passes dt_out
out_avd          = 1            # phase field on a finer grid -> mymodel_phase.pvd
out_surf         = 1            # free surface -> mymodel_surf.pvd
```

The full list of `out_*` keys is in `info/options/input_file.dat`.

For comparison runs, write the variants to a scratch directory, not into `test/`:
- Change one key with `sed`, e.g. `temperature_dependent_kappa = 1 -> 0`.
- Run each variant in its own directory.
- `diff` the inputs, so the only difference is the one you intended.

Delete old `Timestep_*` directories before re-running into the same directory.

## 3. Read the output (LaMEM.jl)

```julia
using LaMEM
steps, files, times = read_LaMEM_simulation("mymodel", dir)   # from mymodel.pvd
read_LaMEM_fieldnames("mymodel", dir)        # ("temperature [C]", "velocity [cm/yr]", ...)
d, t = read_LaMEM_timestep("mymodel", 10, dir)                # by timestep number
d, t = read_LaMEM_timestep("mymodel", 0, dir; last = true)    # last output
d, t = read_LaMEM_timestep("mymodel", 10, dir; fields = ("temperature [C]",))
d, t = read_LaMEM_timestep("mymodel", 10, dir; phase = true)  # _phase.pvd (out_avd)
d, t = read_LaMEM_timestep("mymodel", 10, dir; surf = true)   # _surf.pvd
```

What these return:
- **Timestep argument:** the *timestep number* in the `.pvd` file (`Timestep_00000010_…` → `10`), not
  a position in a list. `dir` is the directory that holds the `.pvd`.
- **Time:** `t` is a 1-element `Vector`, so use `t[1]`. It is in Myr for `units = geo` and in seconds
  for `si`.
- **Data:** `d` is a `CartData` with `d.x.val`, `d.y.val`, `d.z.val` and `d.fields.<name>`. These are
  3D arrays indexed `[ix, iy, iz]`, with z increasing upward. Fields are `Float32`.
- **Field names and units:** names lose their unit suffix (`"temperature [C]"` → `:temperature`), so
  get the units from `read_LaMEM_fieldnames`. With `units = geo` they are km, Myr, °C, MPa and cm/yr.
- **Vector fields** are a tuple of three arrays: `d.fields.velocity[3]` is v_z.
- **Grid points:** main output is on **nodes**, one more than the number of cells in each direction.
  Node values are averages of the surrounding cells, which matters for comparisons (see §6).

Index a node column or point:

```julia
x, y, z = d.x.val[:,1,1], d.y.val[1,:,1], d.z.val[1,1,:]
i, j, k = argmin(abs.(x .- 0)), argmin(abs.(y .- 0)), argmin(abs.(z .+ 6))
T_profile = d.fields.temperature[i, j, :]
```

`scripts/lamem_plot_helpers.jl` wraps these as `coords`, `nearest`, `vprofile`, `history` (a field at
one point over all output steps), `xz_section`, plus a theme (`lamem_theme!`) and colours (`C_SERIES`,
`C_INK`, `C_MUTED`). Use it with `include(".../lamem_plot_helpers.jl")`.

## 4. Built-in Makie recipes (LaMEM.jl)

These load automatically with `using CairoMakie` (or GLMakie):

```julia
fig = Figure(size = (900, 400))
lab = axis_labels(d, :temperature, y = 0)
ax  = Axis(fig[1,1], xlabel = lab.xlabel, ylabel = lab.ylabel, title = lab.title, aspect = DataAspect())
p   = crosssection!(ax, d, field = :temperature, y = 0)     # or x = …, z = …
Colorbar(fig[1,2], p, label = "Temperature [°C]")
save("section.png", fig, px_per_unit = 2)
```

- **`crosssection` / `crosssection!`** take a `CartData` or a `Model`. For a `Model`, the initial
  setup is plotted without running; once it has run, pass `timestep = n` or `:last`. Other keywords:
  `field`, `dim` (vector component) and one of `x`/`y`/`z`.
- **`axis_labels` on a `CartData`** gives `"x"`, `"z"` and the bare field name **without units**, so
  write units into the labels yourself.
- **Other recipes:** `topo(read_LaMEM_timestep(...; surf = true)[1])`, `phasediagram("Rhyolite.in", :ρ)`,
  and `view_model(model)` (interactive, GLMakie). The Plots.jl versions (`plot_cross_section`, …)
  exist too, but prefer Makie.
- Building and running models from Julia (`Model`, `Grid`, `Phase`, `add_phase!`, `add_sphere!`,
  `run_lamem`) is documented at https://juliageodynamics.github.io/LaMEM.jl/dev/juliasetups and in
  `docs/src/` of the installed package (`pkgdir(LaMEM)`).

## 5. Figure conventions

- **Layout:** one measure per axis, never two y-scales. Two quantities means two panels side by side,
  and each panel gets a short title.
- **Colour:** keep it fixed per entity across all figures, e.g. variant A `C_SERIES[1]` (blue) and
  variant B `C_SERIES[2]` (orange). Draw exact or analytical curves in `C_INK` and reference lines
  dashed.
- **Legend:** use one whenever there are two or more series.
- **Data and markers:** model output as markers, exact solution as a line. For time series, a line
  with markers at the output steps.
- **Setup line:** a muted label above the panels with the setup (grid, BCs, ρ, Cp, …), e.g.
  `Label(fig[0, :], "...", color = C_MUTED, halign = :left, tellwidth = false)`.
- **Numbers:** print the numbers the figure claims with `@printf` (max error, final values), and quote
  those numbers rather than reading them off the plot.
- **Output:** `save("fig.png", fig, px_per_unit = 2)`. Then **open the PNG and look at it** (Read the
  file) before using it, checking for overlapping labels, empty panels and wrong axes.

## 6. Verification patterns

- **Against an analytical solution** (strongest evidence):
  - Choose a setup that has a closed-form answer. Examples: 1D steady conduction, where with k(T) the
    Kirchhoff integral ∫k dT is linear in depth; half-space cooling (`erf`); a cooling sphere.
  - Report the max error **and** the size of the effect being tested, e.g. "0.16 °C error against a
    170 °C shift from the constant-k profile". This shows the test can tell the two apart.
  - Check both `units = geo` and `units = si` when a change touches scaling or temperature
    conversions.
- **Model vs model:** run the same input with a feature on and off. Compare a point history and a
  profile, and state the expected direction of the change *before* looking (e.g. "lower k, so slower
  cooling").
- **Effects of node averaging** in the main output:
  - Sharp features (phase boundaries, kinks in a piecewise law) are smoothed over one cell.
  - The phase field is fractional at nodes.
  - A value set inside a body (e.g. sphere T = 700 °C) reads lower at its nodes at t = 0.
  - Compare interior nodes away from such features, or allow about 1% there. Use `out_avd` / `phase = true`
    for sharper phase maps.

## 7. Figures in a pull request

GitHub PR bodies only show images hosted at a URL, and `gh` cannot upload attachments.
1. Do not commit figures to LaMEM.
2. Push them, plus the inputs and the plotting script, to a separate branch on the **user's fork**,
   e.g. `pr-assets/<topic>`, created from a fresh `git init` in a scratch directory.
3. Reference them with raw URLs pinned to the commit SHA:
   `![fig](https://raw.githubusercontent.com/<user>/LaMEM/<sha>/fig.png)`.
4. Check that each URL returns 200 (`curl -s -o /dev/null -w '%{http_code}'`) before editing the PR.
5. Link the branch in the PR so reviewers can reproduce the figures.

## 8. Fallback without Julia packages

To read an appended-raw `.vtr` piece without LaMEM.jl, parse the XML header for each `DataArray`'s
`offset`. Data starts after the `_` that follows `<AppendedData encoding="raw">`. Each array is a
UInt64 byte count followed by little-endian Float32 values. Arrays are x-fastest with shape
`(nz, ny, nx)` from `WholeExtent`.

## Common pitfalls

| Symptom | Cause / fix |
|---|---|
| `Package ReadVTK not found` | Ran with `--project` pointing at the LaMEM repo/test env; use the default env |
| `this timestep does not exist` | Passed a list index instead of the timestep number; check `read_LaMEM_simulation` |
| Plotted results don't reflect a source change | Model was run by `run_lamem` (LaMEM_jll binary); run the local `bin/opt/LaMEM` |
| Old steps appear in a new run | Stale `Timestep_*` dirs / `.pvd` from the previous run; clean the directory first (`clean_directory(dir)`) |
| Field missing from `d.fields` | Its `out_*` flag was not set in the `.dat` |
| Peak/initial value a bit off the input | Node averaging (§6), not a bug |
| `read_LaMEM_inputfile` (GMG) misparses values | Inline `# comments` on value lines; strip them first |
