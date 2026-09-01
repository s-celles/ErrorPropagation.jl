"""
    ±(a, u)

Infix constructor for [`SymbolicMeasurement`](@ref). The left operand is
the estimate of the measurand; the right operand is its standard
uncertainty. Either operand may be a `Symbolics.Num` or a plain
`Number`; numeric operands are promoted to `Num` literals.

`±` denotes the *standard* uncertainty (`u_c`), not the expanded
uncertainty (`U = k · u_c`), consistent with JCGM 100:2008 §6.

Implements the methodology of JCGM 100:2008 §6. Traces REQ-003.
"""
±(a::Symbolics.Num, u::Symbolics.Num) = SymbolicMeasurement(a, u)

±(a::Symbolics.Num, u::Number) = SymbolicMeasurement(a, Symbolics.Num(u))

±(a::Number, u::Symbolics.Num) = SymbolicMeasurement(Symbolics.Num(a), u)

±(a::Number, u::Number) = SymbolicMeasurement(a, u)
