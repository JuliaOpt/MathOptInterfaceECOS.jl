# References
MOI.candelete(instance::ECOSSolverInstance, r::MOI.Index) = MOI.candelete(instance.instancedata, r)
MOI.isvalid(instance::ECOSSolverInstance, r::MOI.Index) = MOI.isvalid(instance.instancedata, r)
MOI.delete!(instance::ECOSSolverInstance, r::MOI.Index) = MOI.delete!(instance.instancedata, r)

# Attributes
for f in (:canget, :canset, :set!, :get, :get!)
    @eval begin
        MOI.$f(instance::ECOSSolverInstance, attr::MOI.AnyAttribute) = MOI.$f(instance.instancedata, attr)
        MOI.$f(instance::ECOSSolverInstance, attr::MOI.AnyAttribute, ref::MOI.Index) = MOI.$f(instance.instancedata, attr, ref)
        MOI.$f(instance::ECOSSolverInstance, attr::MOI.AnyAttribute, refs::Vector{<:MOI.Index}) = MOI.$f(instance.instancedata, attr, refs)
        # Objective function
        MOI.$f(instance::ECOSSolverInstance, attr::MOI.AnyAttribute, arg::Union{MOI.OptimizationSense, MOI.AbstractScalarFunction}) = MOI.$f(instance.instancedata, attr, arg)
    end
end

# Constraints
MOI.canaddconstraint(instance::ECOSSolverInstance, f::MOI.AbstractFunction, s::MOI.AbstractSet) = MOI.canaddconstraint(instance.instancedata, f, s)
MOI.addconstraint!(instance::ECOSSolverInstance, f::MOI.AbstractFunction, s::MOI.AbstractSet) = MOI.addconstraint!(instance.instancedata, f, s)
MOI.canmodifyconstraint(instance::ECOSSolverInstance, ci::CI, change) = MOI.canmodifyconstraint(instance.instancedata, ci, change)
MOI.modifyconstraint!(instance::ECOSSolverInstance, ci::CI, change) = MOI.modifyconstraint!(instance.instancedata, ci, change)

# Objective
MOI.canmodifyobjective(instance::ECOSSolverInstance, change::MOI.AbstractFunctionModification) = MOI.canmodifyobjective(instance.instancedata, change)
MOI.modifyobjective!(instance::ECOSSolverInstance, change::MOI.AbstractFunctionModification) = MOI.modifyobjective!(instance.instancedata, change)

# Variables
MOI.addvariable!(instance::ECOSSolverInstance) = MOI.addvariable!(instance.instancedata)
MOI.addvariables!(instance::ECOSSolverInstance, n) = MOI.addvariables!(instance.instancedata, n)
