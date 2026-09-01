@testitem "Aqua package hygiene" begin
    using Aqua
    using SymbolicUncertainties

    Aqua.test_all(SymbolicUncertainties)
end
