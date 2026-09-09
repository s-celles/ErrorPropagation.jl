export CauseNode, IntermediateNode, MeasurementModel

abstract type AbstractCausalNode end

struct CauseNode <: AbstractCausalNode
    name::Symbol
    metadata::Dict{Symbol, Any}
end
CauseNode(name::Symbol) = CauseNode(name, Dict{Symbol, Any}())

struct IntermediateNode <: AbstractCausalNode
    name::Symbol
    metadata::Dict{Symbol, Any}
end
IntermediateNode(name::Symbol) = IntermediateNode(name, Dict{Symbol, Any}())
IntermediateNode(name::Symbol, metadata::Dict) = IntermediateNode(name, Dict{Symbol, Any}(metadata))

struct MeasurementModel
    inputs::Vector{CauseNode}
    output::IntermediateNode
end
