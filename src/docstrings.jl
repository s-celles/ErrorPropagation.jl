# Reserved for shared docstring infrastructure.
#
# At M0 this file is intentionally empty: REQ-130 restricts the runtime
# dependency set to Symbolics.jl only, which forbids importing
# DocStringExtensions from src/. When M1 introduces the first exported
# symbol, this file will either (a) host plain-string helper constants
# for JCGM / IEC / EA section references or (b) be replaced by a
# DocStringExtensions-based template system conditional on a spec
# amendment relaxing REQ-130.
