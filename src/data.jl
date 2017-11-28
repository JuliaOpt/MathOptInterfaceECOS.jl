# References
MOI.candelete(instance::ECOSSolverInstance, r::MOI.AnyReference) = MOI.candelete(instance.data, r)
MOI.isvalid(instance::ECOSSolverInstance, r::MOI.AnyReference) = MOI.isvalid(instance.data, r)
MOI.delete!(instance::ECOSSolverInstance, r::MOI.AnyReference) = MOI.delete!(instance.data, r)

# Attributes
for f in (:canget, :canset, :set!, :get, :get!)
    @eval begin
        MOI.$f(instance::ECOSSolverInstance, attr::MOI.AnyAttribute) = MOI.$f(instance.data, attr)
        MOI.$f(instance::ECOSSolverInstance, attr::MOI.AnyAttribute, ref::MOI.AnyReference) = MOI.$f(instance.data, attr, ref)
        MOI.$f(instance::ECOSSolverInstance, attr::MOI.AnyAttribute, refs::Vector{<:MOI.AnyReference}) = MOI.$f(instance.data, attr, refs)
        # Objective function
        MOI.$f(instance::ECOSSolverInstance, attr::MOI.AnyAttribute, arg::Union{MOI.OptimizationSense, MOI.AbstractScalarFunction}) = MOI.$f(instance.data, attr, arg)
    end
end

# Constraints
MOI.canaddconstraint(instance::ECOSSolverInstance, f::MOI.AbstractFunction, s::MOI.AbstractSet) = MOI.canaddconstraint(instance.data, f, s)
MOI.addconstraint!(instance::ECOSSolverInstance, f::MOI.AbstractFunction, s::MOI.AbstractSet) = MOI.addconstraint!(instance.data, f, s)
MOI.canmodifyconstraint(instance::ECOSSolverInstance, cr::CR, change) = MOI.canmodifyconstraint(instance.data, cr, change)
MOI.modifyconstraint!(instance::ECOSSolverInstance, cr::CR, change) = MOI.modifyconstraint!(instance.data, cr, change)

# Objective
MOI.canmodifyobjective(instance::ECOSSolverInstance, change::MOI.AbstractFunctionModification) = MOI.canmodifyobjective(instance.data, change)
MOI.modifyobjective!(instance::ECOSSolverInstance, change::MOI.AbstractFunctionModification) = MOI.modifyobjective!(instance.data, change)

# Variables
MOI.addvariable!(instance::ECOSSolverInstance) = MOI.addvariable!(instance.data)
MOI.addvariables!(instance::ECOSSolverInstance, n) = MOI.addvariables!(instance.data, n)
