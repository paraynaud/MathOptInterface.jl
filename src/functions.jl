# Copyright (c) 2017: Miles Lubin and contributors
# Copyright (c) 2017: Google Inc.
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

"""
    output_dimension(f::AbstractFunction)

Return 1 if `f` is an [`AbstractScalarFunction`](@ref), or the number of output
components if `f` is an [`AbstractVectorFunction`](@ref).
"""
function output_dimension end

output_dimension(::AbstractScalarFunction) = 1

"""
    constant(f::AbstractFunction[, ::Type{T}]) where {T}

Returns the constant term of a scalar-valued function, or the constant vector of
a vector-valued function.

If `f` is untyped and `T` is provided, returns `zero(T)`.
"""
constant(f::AbstractFunction, ::Type{T}) where {T} = constant(f)

"""
    coefficient(t::ScalarAffineTerm)
    coefficient(t::ScalarQuadraticTerm)
    coefficient(t::VectorAffineTerm)
    coefficient(t::VectorQuadraticTerm)

Finds the coefficient stored in the term `t`.
"""
function coefficient end

"""
    term_indices(t::ScalarAffineTerm)
    term_indices(t::ScalarQuadraticTerm)
    term_indices(t::VectorAffineTerm)
    term_indices(t::VectorQuadraticTerm)

Returns the indices of the input term `t` as a tuple of `Int`s.

* For `t::ScalarAffineTerm`, this is a 1-tuple of the variable index.
* For `t::ScalarQuadraticTerm`, this is a 2-tuple of the variable indices
  in non-decreasing order.
* For `t::VectorAffineTerm`, this is a 2-tuple of the row/output and
  variable indices.
* For `t::VectorQuadraticTerm`, this is a 3-tuple of the row/output and
  variable indices in non-decreasing order.
"""
function term_indices end

"""
    term_pair(t::ScalarAffineTerm)
    term_pair(t::ScalarQuadraticTerm)
    term_pair(t::VectorAffineTerm)
    term_pair(t::VectorQuadraticTerm)

Returns the pair [`term_indices`](@ref) `=>` [`coefficient`](@ref) of the term.
"""
function term_pair end

# VariableIndex is defined in indextypes.jl

constant(f::VariableIndex, ::Type{T}) where {T} = zero(T)

Base.copy(x::VariableIndex) = x

Base.isapprox(x::VariableIndex, y::VariableIndex; kwargs...) = x == y

"""
    ScalarAffineTerm{T}(coefficient::T, variable::VariableIndex) where {T}

Represents the scalar-valued term `coefficient * variable`.

## Example

```jldoctest
julia> import MathOptInterface as MOI

julia> x = MOI.VariableIndex(1)
MOI.VariableIndex(1)

julia> MOI.ScalarAffineTerm(2.0, x)
MathOptInterface.ScalarAffineTerm{Float64}(2.0, MOI.VariableIndex(1))
```
"""
struct ScalarAffineTerm{T}
    coefficient::T
    variable::VariableIndex
end

coefficient(t::ScalarAffineTerm) = t.coefficient

term_indices(t::ScalarAffineTerm) = (t.variable.value,)

term_pair(t::ScalarAffineTerm) = term_indices(t) => coefficient(t)

# !!! developer note
#
#     ScalarAffineFunction is mutable because its `constant` field is likely of
#     an immutable type, while its `terms` field is of a mutable type, meaning
#     that creating a `ScalarAffineFunction` allocates, and it is desirable to
#     provide a zero-allocation option for working with ScalarAffineFunctions.
#
#     See https://github.com/jump-dev/MathOptInterface.jl/pull/343.

"""
    ScalarAffineFunction{T}(terms::ScalarAffineTerm{T}, constant::T) where {T}

Represents the scalar-valued affine function ``a^\\top x + b``, where:

 * ``a^\\top x`` is represented by the vector of [`ScalarAffineTerm`](@ref)s
 * ``b`` is a scalar `constant::T`

## Duplicates

Duplicate variable indices in `terms` are accepted, and the corresponding
coefficients are summed together.

## Example

```jldoctest
julia> import MathOptInterface as MOI

julia> x = MOI.VariableIndex(1)
MOI.VariableIndex(1)

julia> terms = [MOI.ScalarAffineTerm(2.0, x), MOI.ScalarAffineTerm(3.0, x)]
2-element Vector{MathOptInterface.ScalarAffineTerm{Float64}}:
 MathOptInterface.ScalarAffineTerm{Float64}(2.0, MOI.VariableIndex(1))
 MathOptInterface.ScalarAffineTerm{Float64}(3.0, MOI.VariableIndex(1))

julia> f = MOI.ScalarAffineFunction(terms, 4.0)
4.0 + 2.0 MOI.VariableIndex(1) + 3.0 MOI.VariableIndex(1)
```
"""
mutable struct ScalarAffineFunction{T} <: AbstractScalarFunction
    terms::Vector{ScalarAffineTerm{T}}
    constant::T
end

constant(f::ScalarAffineFunction) = f.constant

function Base.copy(f::ScalarAffineFunction)
    return ScalarAffineFunction(copy(f.terms), copy(f.constant))
end

function ScalarAffineFunction{T}(x::VariableIndex) where {T}
    return ScalarAffineFunction([ScalarAffineTerm(one(T), x)], zero(T))
end

"""
    ScalarQuadraticTerm{T}(
        coefficient::T,
        variable_1::VariableIndex,
        variable_2::VariableIndex,
    ) where {T}

Represents the scalar-valued term ``c x_i x_j`` where ``c`` is `coefficient`,
``x_i`` is `variable_1` and ``x_j`` is `variable_2`.

## Example

```jldoctest
julia> import MathOptInterface as MOI

julia> x = MOI.VariableIndex(1)
MOI.VariableIndex(1)

julia> MOI.ScalarQuadraticTerm(2.0, x, x)
MathOptInterface.ScalarQuadraticTerm{Float64}(2.0, MOI.VariableIndex(1), MOI.VariableIndex(1))
```
"""
struct ScalarQuadraticTerm{T}
    coefficient::T
    variable_1::VariableIndex
    variable_2::VariableIndex
end

coefficient(t::ScalarQuadraticTerm) = t.coefficient

function term_indices(t::ScalarQuadraticTerm)
    return minmax(t.variable_1.value, t.variable_2.value)
end

term_pair(t::ScalarQuadraticTerm) = term_indices(t) => coefficient(t)

# !!! developer note
#
#     ScalarQuadraticFunction is mutable because its `constant` field is likely
#     of an immutable type, while its `terms` field is of a mutable type,
#     meaning that creating a `ScalarQuadraticFunction` allocates, and it is
#     desirable to provide a zero-allocation option for working with
#     ScalarQuadraticFunctions.
#
#     See https://github.com/jump-dev/MathOptInterface.jl/pull/343.

"""
    ScalarQuadraticFunction{T}(
        quadratic_terms::Vector{ScalarQuadraticTerm{T}},
        affine_terms::Vector{ScalarAffineTerm{T}},
        constant::T,
    ) wher {T}

The scalar-valued quadratic function ``\\frac{1}{2}x^\\top Q x + a^\\top x + b``,
where:

 * ``Q`` is the symmetric matrix given by the vector of [`ScalarQuadraticTerm`](@ref)s
 * ``a^\\top x`` is a sparse vector given by the vector of [`ScalarAffineTerm`](@ref)s
 * ``b`` is the scalar `constant::T`.

## Duplicates

Duplicate indices in `quadratic_terms` or `affine_terms` are accepted, and the
corresponding coefficients are summed together.

In `quadratic_terms`, "mirrored" indices, `(q, r)` and `(r, q)` where `r` and
`q` are [`VariableIndex`](@ref)es, are considered duplicates; only one needs to
be specified.

## The 0.5 factor

Coupled with the interpretation of mirrored indices, the `0.5` factor in front
of the ``Q`` matrix is a common source of bugs.

As a rule, to represent ``a * x^2 + b * x * y``:

 * The coefficient ``a`` in front of squared variables (diagonal elements in
   ``Q``) must be doubled when creating a [`ScalarQuadraticTerm`](@ref)
 * The coefficient ``b`` in front of off-diagonal elements in ``Q`` should be
   left as ``b``, be cause the mirrored index ``b * y * x`` will be implicitly
   added.

## Example

To represent the function ``f(x, y) = 2 * x^2 + 3 * x * y + 4 * x + 5``, do:

```jldoctest
julia> import MathOptInterface as MOI

julia> x = MOI.VariableIndex(1);

julia> y = MOI.VariableIndex(2);

julia> constant = 5.0;

julia> affine_terms = [MOI.ScalarAffineTerm(4.0, x)];

julia> quadratic_terms = [
           MOI.ScalarQuadraticTerm(4.0, x, x),  # Note the changed coefficient
           MOI.ScalarQuadraticTerm(3.0, x, y),
       ]
2-element Vector{MathOptInterface.ScalarQuadraticTerm{Float64}}:
 MathOptInterface.ScalarQuadraticTerm{Float64}(4.0, MOI.VariableIndex(1), MOI.VariableIndex(1))
 MathOptInterface.ScalarQuadraticTerm{Float64}(3.0, MOI.VariableIndex(1), MOI.VariableIndex(2))

julia> f = MOI.ScalarQuadraticFunction(quadratic_terms, affine_terms, constant)
5.0 + 4.0 MOI.VariableIndex(1) + 2.0 MOI.VariableIndex(1)² + 3.0 MOI.VariableIndex(1)*MOI.VariableIndex(2)
```

"""
mutable struct ScalarQuadraticFunction{T} <: AbstractScalarFunction
    quadratic_terms::Vector{ScalarQuadraticTerm{T}}
    affine_terms::Vector{ScalarAffineTerm{T}}
    constant::T
end

constant(f::ScalarQuadraticFunction) = f.constant

function Base.copy(f::ScalarQuadraticFunction)
    return ScalarQuadraticFunction(
        copy(f.quadratic_terms),
        copy(f.affine_terms),
        copy(f.constant),
    )
end

"""
    abstract type AbstractVectorFunction <: AbstractFunction

Abstract supertype for vector-valued [`AbstractFunction`](@ref)s.

## Required methods

All subtypes of `AbstractVectorFunction` must implement:

 * [`output_dimension`](@ref)
"""
abstract type AbstractVectorFunction <: AbstractFunction end

"""
    VectorOfVariables(variables::Vector{VariableIndex}) <: AbstractVectorFunction

The vector-valued function `f(x) = variables`, where `variables` is a subset of
[`VariableIndex`](@ref)es in the model.

The list of `variables` may contain duplicates.

## Example

```jldoctest
julia> import MathOptInterface as MOI

julia> x = MOI.VariableIndex.(1:2)
2-element Vector{MathOptInterface.VariableIndex}:
 MOI.VariableIndex(1)
 MOI.VariableIndex(2)

julia> f = MOI.VectorOfVariables([x[1], x[2], x[1]])
┌                    ┐
│MOI.VariableIndex(1)│
│MOI.VariableIndex(2)│
│MOI.VariableIndex(1)│
└                    ┘

julia> MOI.output_dimension(f)
3
```
"""
struct VectorOfVariables <: AbstractVectorFunction
    variables::Vector{VariableIndex}
end

output_dimension(f::VectorOfVariables) = length(f.variables)

function constant(f::VectorOfVariables, ::Type{T}) where {T}
    return zeros(T, output_dimension(f))
end

Base.copy(f::VectorOfVariables) = VectorOfVariables(copy(f.variables))

function Base.:(==)(f::VectorOfVariables, g::VectorOfVariables)
    return f.variables == g.variables
end

Base.isapprox(x::VectorOfVariables, y::VectorOfVariables; kwargs...) = x == y

"""
    VectorAffineTerm{T}(
        output_index::Int64,
        scalar_term::ScalarAffineTerm{T},
    ) where {T}

A `VectorAffineTerm` is a `scalar_term` that appears in the `output_index` row
of the vector-valued [`VectorAffineFunction`](@ref) or
[`VectorQuadraticFunction`](@ref).

## Example

```jldoctest
julia> import MathOptInterface as MOI

julia> x = MOI.VariableIndex(1);

julia> MOI.VectorAffineTerm(Int64(2), MOI.ScalarAffineTerm(3.0, x))
MathOptInterface.VectorAffineTerm{Float64}(2, MathOptInterface.ScalarAffineTerm{Float64}(3.0, MOI.VariableIndex(1)))
```
"""
struct VectorAffineTerm{T}
    output_index::Int64
    scalar_term::ScalarAffineTerm{T}
end

function VectorAffineTerm(
    output_index::Base.Integer,
    scalar_term::ScalarAffineTerm,
)
    return VectorAffineTerm(convert(Int64, output_index), scalar_term)
end

coefficient(t::VectorAffineTerm) = t.scalar_term.coefficient

function term_indices(t::VectorAffineTerm)
    return (t.output_index, term_indices(t.scalar_term)...)
end

term_pair(t::VectorAffineTerm) = term_indices(t) => coefficient(t)

"""
    VectorAffineFunction{T}(
        terms::Vector{VectorAffineTerm{T}},
        constants::Vector{T},
    ) where {T}

The vector-valued affine function ``A x + b``, where:

 * ``A x`` is the sparse matrix given by the vector of [`VectorAffineTerm`](@ref)s
 * ``b`` is the vector `constants`

## Duplicates

Duplicate indices in the ``A`` are accepted, and the corresponding coefficients
are summed together.

## Example

```jldoctest
julia> import MathOptInterface as MOI

julia> x = MOI.VariableIndex(1);

julia> terms = [
           MOI.VectorAffineTerm(Int64(1), MOI.ScalarAffineTerm(2.0, x)),
           MOI.VectorAffineTerm(Int64(2), MOI.ScalarAffineTerm(3.0, x)),
       ];

julia> f = MOI.VectorAffineFunction(terms, [4.0, 5.0])
┌                              ┐
│4.0 + 2.0 MOI.VariableIndex(1)│
│5.0 + 3.0 MOI.VariableIndex(1)│
└                              ┘

julia> MOI.output_dimension(f)
2
```
"""
struct VectorAffineFunction{T} <: AbstractVectorFunction
    terms::Vector{VectorAffineTerm{T}}
    constants::Vector{T}
end

output_dimension(f::VectorAffineFunction) = length(f.constants)

constant(f::VectorAffineFunction) = f.constants

function Base.copy(f::VectorAffineFunction)
    return VectorAffineFunction(copy(f.terms), copy(f.constants))
end

function VectorAffineFunction{T}(f::VectorOfVariables) where {T}
    terms = map(1:output_dimension(f)) do i
        return VectorAffineTerm(i, ScalarAffineTerm(one(T), f.variables[i]))
    end
    return VectorAffineFunction(terms, zeros(T, output_dimension(f)))
end

"""
    VectorQuadraticTerm{T}(
        output_index::Int64,
        scalar_term::ScalarQuadraticTerm{T},
    ) where {T}

A `VectorQuadraticTerm` is a [`ScalarQuadraticTerm`](@ref) `scalar_term` that
appears in the `output_index` row of the vector-valued
[`VectorQuadraticFunction`](@ref).

## Example

```jldoctest
julia> import MathOptInterface as MOI

julia> x = MOI.VariableIndex(1);

julia> MOI.VectorQuadraticTerm(Int64(2), MOI.ScalarQuadraticTerm(3.0, x, x))
MathOptInterface.VectorQuadraticTerm{Float64}(2, MathOptInterface.ScalarQuadraticTerm{Float64}(3.0, MOI.VariableIndex(1), MOI.VariableIndex(1)))
```
"""
struct VectorQuadraticTerm{T}
    output_index::Int64
    scalar_term::ScalarQuadraticTerm{T}
end

function VectorQuadraticTerm(
    output_index::Base.Integer,
    scalar_term::ScalarQuadraticTerm,
)
    return VectorQuadraticTerm(convert(Int64, output_index), scalar_term)
end

coefficient(t::VectorQuadraticTerm) = t.scalar_term.coefficient

function term_indices(t::VectorQuadraticTerm)
    return (t.output_index, term_indices(t.scalar_term)...)
end

term_pair(t::VectorQuadraticTerm) = term_indices(t) => coefficient(t)

"""
    VectorQuadraticFunction{T}(
        quadratic_terms::Vector{VectorQuadraticTerm{T}},
        affine_terms::Vector{VectorAffineTerm{T}},
        constants::Vector{T},
    ) where {T}

The vector-valued quadratic function with i`th` component ("output index")
defined as ``\\frac{1}{2}x^\\top Q_i x + a_i^\\top x + b_i``, where:

 * ``\\frac{1}{2}x^\\top Q_i x`` is the symmetric matrix given by the
   [`VectorQuadraticTerm`](@ref) elements in `quadratic_terms` with
   `output_index == i`
 * ``a_i^\\top x`` is the sparse vector given by the [`VectorAffineTerm`](@ref)
   elements in `affine_terms` with `output_index == i`
 * ``b_i`` is a scalar given by `constants[i]`

## Duplicates

Duplicate indices in `quadratic_terms` and `affine_terms` with the same
`output_index` are handled in the same manner as duplicates in
[`ScalarQuadraticFunction`](@ref).

## Example

```jldoctest
julia> import MathOptInterface as MOI

julia> x = MOI.VariableIndex(1);

julia> y = MOI.VariableIndex(2);

julia> constants = [4.0, 5.0];

julia> affine_terms = [
           MOI.VectorAffineTerm(Int64(1), MOI.ScalarAffineTerm(2.0, x)),
           MOI.VectorAffineTerm(Int64(2), MOI.ScalarAffineTerm(3.0, x)),
       ];

julia> quad_terms = [
        MOI.VectorQuadraticTerm(Int64(1), MOI.ScalarQuadraticTerm(2.0, x, x)),
        MOI.VectorQuadraticTerm(Int64(2), MOI.ScalarQuadraticTerm(3.0, x, y)),
           ];

julia> f = MOI.VectorQuadraticFunction(quad_terms, affine_terms, constants)
┌                                                                              ┐
│4.0 + 2.0 MOI.VariableIndex(1) + 1.0 MOI.VariableIndex(1)²                    │
│5.0 + 3.0 MOI.VariableIndex(1) + 3.0 MOI.VariableIndex(1)*MOI.VariableIndex(2)│
└                                                                              ┘

julia> MOI.output_dimension(f)
2
```
"""
struct VectorQuadraticFunction{T} <: AbstractVectorFunction
    quadratic_terms::Vector{VectorQuadraticTerm{T}}
    affine_terms::Vector{VectorAffineTerm{T}}
    constants::Vector{T}
end

output_dimension(f::VectorQuadraticFunction) = length(f.constants)

constant(f::VectorQuadraticFunction) = f.constants

function Base.copy(f::VectorQuadraticFunction)
    return VectorQuadraticFunction(
        copy(f.quadratic_terms),
        copy(f.affine_terms),
        copy(f.constants),
    )
end

# Function modifications

"""
    AbstractFunctionModification

An abstract supertype for structs which specify partial modifications to
functions, to be used for making small modifications instead of replacing the
functions entirely.
"""
abstract type AbstractFunctionModification end

"""
    ScalarConstantChange{T}(new_constant::T)

A struct used to request a change in the constant term of a scalar-valued
function.

Applicable to [`ScalarAffineFunction`](@ref) and [`ScalarQuadraticFunction`](@ref).
"""
struct ScalarConstantChange{T} <: AbstractFunctionModification
    new_constant::T
end

"""
    VectorConstantChange{T}(new_constant::Vector{T})

A struct used to request a change in the constant vector of a vector-valued
function.

Applicable to [`VectorAffineFunction`](@ref) and [`VectorQuadraticFunction`](@ref).
"""
struct VectorConstantChange{T} <: AbstractFunctionModification
    new_constant::Vector{T}
end

"""
    ScalarCoefficientChange{T}(variable::VariableIndex, new_coefficient::T)

A struct used to request a change in the linear coefficient of a single variable
in a scalar-valued function.

Applicable to [`ScalarAffineFunction`](@ref) and [`ScalarQuadraticFunction`](@ref).
"""
struct ScalarCoefficientChange{T} <: AbstractFunctionModification
    variable::VariableIndex
    new_coefficient::T
end

# !!! developer note
#     MultiRowChange is mutable because its `variable` field of an immutable
#     type, while `new_coefficients` is of a mutable type, meaning that creating
#     a `MultiRowChange` allocates, and it is desirable to provide a
#     zero-allocation option for working with MultiRowChanges.
#
#     See https://github.com/jump-dev/MathOptInterface.jl/pull/343.

"""
    MultirowChange{T}(
        variable::VariableIndex,
        new_coefficients::Vector{Tuple{Int64,T}},
    ) where {T}

A struct used to request a change in the linear coefficients of a single
variable in a vector-valued function.

New coefficients are specified by `(output_index, coefficient)` tuples.

Applicable to [`VectorAffineFunction`](@ref) and [`VectorQuadraticFunction`](@ref).
"""
mutable struct MultirowChange{T} <: AbstractFunctionModification
    variable::VariableIndex
    new_coefficients::Vector{Tuple{Int64,T}}
end

function MultirowChange(
    variable::VariableIndex,
    new_coefficients::Vector{Tuple{Ti,T}},
) where {Ti<:Base.Integer,T}
    return MultirowChange(
        variable,
        [(convert(Int64, i), j) for (i, j) in new_coefficients],
    )
end

# isapprox

# For affine and quadratic functions, terms are compressed in a dictionary using
# `_dicts` and then the dictionaries are compared with `dict_compare`
function dict_compare(d1::Dict, d2::Dict{<:Any,T}, compare::Function) where {T}
    for key in union(keys(d1), keys(d2))
        if !compare(Base.get(d1, key, zero(T)), Base.get(d2, key, zero(T)))
            return false
        end
    end
    return true
end

# Build a dictionary where the duplicate keys are summed
function sum_dict(kvs::Vector{Pair{K,V}}) where {K,V}
    d = Dict{K,V}()
    for (key, value) in kvs
        d[key] = value + Base.get(d, key, zero(V))
    end
    return d
end

function _dicts(f::Union{ScalarAffineFunction,VectorAffineFunction})
    return (sum_dict(term_pair.(f.terms)),)
end

function _dicts(f::Union{ScalarQuadraticFunction,VectorQuadraticFunction})
    return (
        sum_dict(term_pair.(f.quadratic_terms)),
        sum_dict(term_pair.(f.affine_terms)),
    )
end

function Base.isapprox(
    f::F,
    g::G;
    kwargs...,
) where {
    F<:Union{
        ScalarAffineFunction,
        ScalarQuadraticFunction,
        VectorAffineFunction,
        VectorQuadraticFunction,
    },
    G<:Union{
        ScalarAffineFunction,
        ScalarQuadraticFunction,
        VectorAffineFunction,
        VectorQuadraticFunction,
    },
}
    return isapprox(constant(f), constant(g); kwargs...) && all(
        dict_compare.(
            _dicts(f),
            _dicts(g),
            (α, β) -> isapprox(α, β; kwargs...),
        ),
    )
end

###
### Base.convert
###

# VariableIndex

function Base.convert(::Type{VariableIndex}, f::ScalarAffineFunction)
    if (
        !iszero(f.constant) ||
        !isone(length(f.terms)) ||
        !isone(f.terms[1].coefficient)
    )
        throw(InexactError(:convert, VariableIndex, f))
    end
    return f.terms[1].variable
end

function Base.convert(
    ::Type{VariableIndex},
    f::ScalarQuadraticFunction{T},
) where {T}
    return convert(VariableIndex, convert(ScalarAffineFunction{T}, f))
end

# ScalarAffineFunction

function Base.convert(::Type{ScalarAffineFunction{T}}, α::T) where {T}
    return ScalarAffineFunction{T}(ScalarAffineTerm{T}[], α)
end

function Base.convert(
    ::Type{ScalarAffineFunction{T}},
    f::VariableIndex,
) where {T}
    return ScalarAffineFunction{T}(f)
end

function Base.convert(
    ::Type{ScalarAffineTerm{T}},
    t::ScalarAffineTerm,
) where {T}
    return ScalarAffineTerm{T}(t.coefficient, t.variable)
end

function Base.convert(
    ::Type{ScalarAffineFunction{T}},
    f::ScalarAffineFunction,
) where {T}
    return ScalarAffineFunction{T}(f.terms, f.constant)
end

function Base.convert(
    ::Type{ScalarAffineFunction{T}},
    f::ScalarQuadraticFunction{T},
) where {T}
    if !Base.isempty(f.quadratic_terms)
        throw(InexactError(:convert, ScalarAffineFunction{T}, f))
    end
    return ScalarAffineFunction{T}(f.affine_terms, f.constant)
end

# ScalarQuadraticFunction

function Base.convert(::Type{ScalarQuadraticFunction{T}}, α::T) where {T}
    return ScalarQuadraticFunction{T}(
        ScalarQuadraticTerm{T}[],
        ScalarAffineTerm{T}[],
        α,
    )
end

function Base.convert(
    ::Type{ScalarQuadraticFunction{T}},
    f::VariableIndex,
) where {T}
    return convert(
        ScalarQuadraticFunction{T},
        convert(ScalarAffineFunction{T}, f),
    )
end

function Base.convert(
    ::Type{ScalarQuadraticFunction{T}},
    f::ScalarAffineFunction{T},
) where {T}
    return ScalarQuadraticFunction{T}(
        ScalarQuadraticTerm{T}[],
        f.terms,
        f.constant,
    )
end

function Base.convert(
    ::Type{ScalarQuadraticTerm{T}},
    f::ScalarQuadraticTerm,
) where {T}
    return ScalarQuadraticTerm{T}(f.coefficient, f.variable_1, f.variable_2)
end

function Base.convert(
    ::Type{ScalarQuadraticFunction{T}},
    f::ScalarQuadraticFunction,
) where {T}
    return ScalarQuadraticFunction{T}(
        f.quadratic_terms,
        f.affine_terms,
        f.constant,
    )
end

# VectorOfVariables

function Base.convert(::Type{VectorOfVariables}, g::VariableIndex)
    return VectorOfVariables([g])
end

# VectorAffineFunction

function Base.convert(
    ::Type{VectorAffineFunction{T}},
    g::VariableIndex,
) where {T}
    return VectorAffineFunction{T}(
        [VectorAffineTerm(1, ScalarAffineTerm(one(T), g))],
        [zero(T)],
    )
end

function Base.convert(
    ::Type{VectorAffineFunction{T}},
    g::ScalarAffineFunction,
) where {T}
    return VectorAffineFunction{T}(
        VectorAffineTerm{T}[VectorAffineTerm(1, term) for term in g.terms],
        [g.constant],
    )
end

function Base.convert(
    ::Type{VectorAffineTerm{T}},
    f::VectorAffineTerm,
) where {T}
    return VectorAffineTerm{T}(f.output_index, f.scalar_term)
end

function Base.convert(
    ::Type{VectorAffineFunction{T}},
    f::VectorAffineFunction,
) where {T}
    return VectorAffineFunction{T}(f.terms, f.constants)
end

# VectorQuadraticFunction

function Base.convert(
    ::Type{VectorQuadraticFunction{T}},
    g::VariableIndex,
) where {T}
    return VectorQuadraticFunction{T}(
        VectorQuadraticTerm{T}[],
        [VectorAffineTerm(1, ScalarAffineTerm(one(T), g))],
        [zero(T)],
    )
end

function Base.convert(
    ::Type{VectorQuadraticFunction{T}},
    g::ScalarAffineFunction,
) where {T}
    return VectorQuadraticFunction{T}(
        VectorQuadraticTerm{T}[],
        VectorAffineTerm{T}[VectorAffineTerm(1, term) for term in g.terms],
        [g.constant],
    )
end

function Base.convert(
    ::Type{VectorQuadraticFunction{T}},
    g::ScalarQuadraticFunction,
) where {T}
    return VectorQuadraticFunction{T}(
        VectorQuadraticTerm{T}[
            VectorQuadraticTerm(1, term) for term in g.quadratic_terms
        ],
        VectorAffineTerm{T}[
            VectorAffineTerm(1, term) for term in g.affine_terms
        ],
        [g.constant],
    )
end

function Base.convert(
    ::Type{VectorQuadraticTerm{T}},
    f::VectorQuadraticTerm,
) where {T}
    return VectorQuadraticTerm{T}(f.output_index, f.scalar_term)
end

function Base.convert(
    ::Type{VectorQuadraticFunction{T}},
    f::VectorQuadraticFunction,
) where {T}
    return VectorQuadraticFunction{T}(
        f.quadratic_terms,
        f.affine_terms,
        f.constants,
    )
end

for f in (
    :ScalarAffineTerm,
    :ScalarAffineFunction,
    :ScalarQuadraticTerm,
    :ScalarQuadraticFunction,
    :VectorAffineTerm,
    :VectorAffineFunction,
    :VectorQuadraticTerm,
    :VectorQuadraticFunction,
)
    @eval Base.convert(::Type{$f{T}}, x::$f{T}) where {T} = x
end
