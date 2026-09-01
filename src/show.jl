"""
    Base.show(io::IO, m::SymbolicMeasurement)

Display a [`SymbolicMeasurement`](@ref) as `val ± err` in Unicode when
the output context supports it, falling back to `val +/- err` in
plain ASCII when the context carries `:unicode => false`.

Traces REQ-111.
"""
function Base.show(io::IO, m::SymbolicMeasurement)
    show(io, m.val)
    if get(io, :unicode, true)
        print(io, " ± ")
    else
        print(io, " +/- ")
    end
    show(io, m.err)
    return nothing
end
