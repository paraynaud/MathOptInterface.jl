# Copyright (c) 2017: Miles Lubin and contributors
# Copyright (c) 2017: Google Inc.
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    Base.precompile(
        Tuple{
            typeof(MOI.eval_hessian_lagrangian),
            NLPEvaluator,
            SubArray{Float64,1,Vector{Float64},Tuple{UnitRange{Int64}},true},
            Vector{Float64},
            Float64,
            SubArray{Float64,1,Vector{Float64},Tuple{UnitRange{Int64}},true},
        },
    )
    Base.precompile(
        Tuple{
            typeof(MOI.eval_objective_gradient),
            NLPEvaluator,
            Vector{Float64},
            Vector{Float64},
        },
    )
    Base.precompile(Tuple{typeof(MOI.initialize),NLPEvaluator,Vector{Symbol}})
    Base.precompile(Tuple{typeof(MOI.features_available),NLPEvaluator})
    Base.precompile(
        Tuple{
            typeof(MOI.eval_constraint_jacobian),
            NLPEvaluator,
            SubArray{Float64,1,Vector{Float64},Tuple{UnitRange{Int64}},true},
            Vector{Float64},
        },
    )
    Base.precompile(
        Tuple{
            typeof(MOI.eval_constraint),
            NLPEvaluator,
            SubArray{Float64,1,Vector{Float64},Tuple{UnitRange{Int64}},true},
            Vector{Float64},
        },
    )
    Base.precompile(Tuple{typeof(MOI.jacobian_structure),NLPEvaluator})
    Base.precompile(
        Tuple{typeof(MOI.eval_objective),NLPEvaluator,Vector{Float64}},
    )
    return
end

_precompile_()
