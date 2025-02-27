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

ChainRulesCore.@non_differentiable accuracy(::Any...)
EnzymeCore.EnzymeRules.inactive_noinl(::typeof(accuracy), args...) = nothing

roundval(x::Float64) = round(x, sigdigits=3)
roundval(x::AbstractFloat) = roundval(Float64(x))
roundval(x::Int) = x
roundval(x::NamedTuple) = map(roundval, x)

# Append a version number to `dir`.
function dir_with_version(dir::String)
    i = 1
    outdir = dir * "_$i"
    while isdir(outdir)
        i += 1
		outdir = dir * "_$i"
    end
    return outdir
end

is_cuda_functional() = MLDataDevices.functional(CUDADevice)
is_amdgpu_functional() = MLDataDevices.functional(AMDGPUDevice)
is_metal_functional() = MLDataDevices.functional(MetalDevice)

get_cuda_module() = Base.loaded_modules[PkgId(UUID("052768ef-5323-5732-b1bb-66c8b64840ba"), "CUDA")]
get_amdgpu_module() = Base.loaded_modules[PkgId(UUID("21141c5a-9bdb-4563-92ae-f87d6854732e"), "AMDGPU")]
get_metal_module() = Base.loaded_modules[PkgId(UUID("dde4c033-4e86-420c-a63e-0dd931031962"), "Metal")]

is_loaded(name::Symbol) = any(x -> Symbol(x) == name, values(Base.loaded_modules))

"""
    seed!(seed::Int)

Seed the RNGs of both CPU and GPU.
"""
function seed!(seed::Int)
    Random.seed!(seed)
    if is_cuda_functional()
        get_cuda_module().seed!(seed)
    end
    if is_amdgpu_functional()
        get_amdgpu_module().seed!(seed)
    end
    if is_metal_functional()
        get_metal_module().seed!(seed)
    end
end

# Return the length of `x` if defined, otherwise return -1.
function _length(x)
    try
        return length(x)
    catch
        return -1
    end
end

ChainRulesCore.@non_differentiable _length(::Any)
EnzymeCore.EnzymeRules.inactive_noinl(::typeof(_length), args...) = nothing


# Adapted from `setup` implementation in
# https://github.com/FluxML/Optimisers.jl/blob/master/src/interface.jl
"""
    foreach_trainable(f, x, ys...)

Apply `f` to each trainable array in object `x`
(or `x` itself if it is a leaf array) recursing into the children given by
`Optimisers.trainable`.

`ys` are optional additional objects with the same structure as `x`.
`f` will be applied to corresponding elements of `x` and `ys`.
"""
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