# Private helper — wraps a plain number or bare Symbolics.Num as a
# zero-uncertainty SymbolicMeasurement so that mixed-mode binary
# operations can dispatch to the measurement/measurement path.
# Implements REQ-015.
_wrap(x::Union{Number,Symbolics.Num}) =
    SymbolicMeasurement(Symbolics.Num(x), Symbolics.Num(0))

# Addition — mixed mode
Base.:+(x::SymbolicMeasurement, c::Union{Number,Symbolics.Num}) = x + _wrap(c)
Base.:+(c::Union{Number,Symbolics.Num}, x::SymbolicMeasurement) = _wrap(c) + x

# Subtraction — mixed mode
Base.:-(x::SymbolicMeasurement, c::Union{Number,Symbolics.Num}) = x - _wrap(c)
Base.:-(c::Union{Number,Symbolics.Num}, x::SymbolicMeasurement) = _wrap(c) - x

# Multiplication — mixed mode
Base.:*(x::SymbolicMeasurement, c::Union{Number,Symbolics.Num}) = x * _wrap(c)
Base.:*(c::Union{Number,Symbolics.Num}, x::SymbolicMeasurement) = _wrap(c) * x

# Division — mixed mode
Base.:/(x::SymbolicMeasurement, c::Union{Number,Symbolics.Num}) = x / _wrap(c)
Base.:/(c::Union{Number,Symbolics.Num}, x::SymbolicMeasurement) = _wrap(c) / x

# Power with measurement on the LHS and a plain number/Num on the RHS
# is already covered by the Base.:^(::SymbolicMeasurement, ::Union{Real,
# Num}) method in src/arithmetic.jl. The reverse case
# (c^measurement) is deferred to M2 (mathematical functions).
