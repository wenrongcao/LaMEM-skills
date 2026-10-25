# Helpers for reading and plotting LaMEM output with LaMEM.jl + CairoMakie.
# usage: include("lamem_plot_helpers.jl") from a script run in the default Julia
# environment (not the test/ project, which lacks ReadVTK).
using LaMEM, CairoMakie, Printf

# colours: categorical slots in fixed order, ink for exact/reference curves
const C_SERIES = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100"]
const C_INK    = "#1f1f1e"
const C_MUTED  = "#6b6a63"

function lamem_theme!()
    set_theme!(fontsize = 15, Axis = (xgridcolor = (:black, 0.06), ygridcolor = (:black, 0.06),
               leftspinecolor = C_MUTED, bottomspinecolor = C_MUTED,
               topspinevisible = false, rightspinevisible = false))
end

# node coordinate vectors of a CartData from read_LaMEM_timestep
coords(d) = (d.x.val[:, 1, 1], d.y.val[1, :, 1], d.z.val[1, 1, :])

# index of the node closest to (x0, y0, z0)
function nearest(d, x0, y0, z0)
    x, y, z = coords(d)
    return argmin(abs.(x .- x0)), argmin(abs.(y .- y0)), argmin(abs.(z .- z0))
end

# vertical profile of `field` (Symbol) through the node column closest to (x0, y0)
function vprofile(d, field::Symbol, x0, y0)
    i, j, _ = nearest(d, x0, y0, 0.0)
    return coords(d)[3], getfield(d.fields, field)[i, j, :]
end

# time history of `field` at the node closest to (x0, y0, z0), over all output steps
function history(name, dir, field::Symbol, x0, y0, z0)
    steps, _, _ = read_LaMEM_simulation(name, dir)
    t, v = Float64[], Float64[]
    for s in steps
        d, ts = read_LaMEM_timestep(name, s, dir; fields = (String(field),))
        i, j, k = nearest(d, x0, y0, z0)
        push!(t, ts[1]); push!(v, getfield(d.fields, field)[i, j, k])
    end
    return t, v
end

# x-z section of `field` at the y-plane closest to y0 (for 2D-like setups)
function xz_section(d, field::Symbol, y0)
    x, y, z = coords(d)
    j = argmin(abs.(y .- y0))
    return x, z, getfield(d.fields, field)[:, j, :]
end
