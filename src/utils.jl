"""
    accuracy(ŷ::AbstractMatrix, y)

Compute the classification accuracy of a batch of predictions `ŷ` against true labels `y`.
`y` can be either a vector or a matrix. 
If `y` is a vector, it is assumed that the labels are integers in the range `1:K` 
where `K == size(ŷ, 1)` is the number of classes.
"""
accuracy(ŷ::AbstractMatrix, y::AbstractVector) = mean(onecold(ŷ) .== y)
accuracy(ŷ::AbstractMatrix, y::AbstractMatrix) = mean(onecold(ŷ) .== onecold(y))


# function accuracy(dataset, m)
#     num = sum(sum(onecold(m(x)) .== onecold(y)) for (x,y) in dataset)
# 	den = sum(size(x, ndims(x)) for (x,y) in dataset)
# 	# @show dataset
# 	# @show typeof(dataset) length(dataset)
# 	# sum(size(x, ndims(x)) for (x,y) in dataset)
#     return num / den
# end


@non_differentiable accuracy(::Any...)

roundval(x::Float64) = round(x, sigdigits=3)
roundval(x::AbstractFloat) = roundval(Float64(x))
roundval(x::Int) = x
roundval(x::NamedTuple) = map(roundval, x)


"""
    dir_with_version(dir::String)

Append a version number to `dir`.
"""
function dir_with_version(dir)
    i = 1
    outdir = dir * "_$i"
    while isdir(outdir)
        i += 1
		outdir = dir * "_$i"
    end
    return outdir
end

"""
    seed!(seed::Int)

Seed the RNGs of both CPU and GPU.
"""
function seed!(seed::Int)
    Random.seed!(seed)
    if CUDA.functional()
        CUDA.seed!(seed)
    end
end


#### CONVERSION
# Have to define our own until 
# https://github.com/FluxML/Flux.jl/issues/2225
# is resolved

struct TsunamiEltypeAdaptor{T} end

function Adapt.adapt_storage(::TsunamiEltypeAdaptor{T}, x::AbstractArray{<:AbstractFloat}) where 
            {T <: AbstractFloat}
    convert(AbstractArray{T}, x)
end

_paramtype(::Type{T}, m) where T = fmap(adapt(TsunamiEltypeAdaptor{T}()), m)

# shortcuts for common cases
_paramtype(::Type{T}, x::AbstractArray{<:Real}) where {T<:AbstractFloat} = x
_paramtype(::Type{T}, x::AbstractArray{<:AbstractFloat}) where {T<:AbstractFloat} = convert(AbstractArray{T}, x)

f16(m) = _paramtype(Float16, m)
f32(m) = _paramtype(Float32, m)
f64(m) = _paramtype(Float64, m)

"""
    _length(x) -> Int

Return the length of `x` if defined, otherwise return -1.
"""
function _length(x)
    try
        return length(x)
    catch
        return -1
    end
end

@non_differentiable _length(::Any)

function foreach_trainable(f, m)
    foreach(f, trainable(m))
end

# Adapted from `setup` implementation in
# https://github.com/FluxML/Optimisers.jl/blob/master/src/interface.jl
function foreach_trainable(f, x, ys...)
    if Optimisers.isnumeric(x)
        f(x, ys...)
    else
        valueforeach((xs...) -> foreach_trainable(f, xs...), trainable(x), (trainable(y) for y in ys)...)
    end
end

valueforeach(f, x...) = foreach(f, x...)
valueforeach(f, x::Dict, ys...) = foreach(pairs(x)) do (k, v)
    f(v, (get(y, k, nothing) for y in ys)...)
end