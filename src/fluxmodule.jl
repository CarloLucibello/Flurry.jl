"""
    abstract type FluxModule end

An abstract type for Flux models.
A `FluxModule` helps orgainising you code and provides a standard interface for training.

A `FluxModule` comes with `functor` already implemented.
You can change the trainables by implementing `Optimisers.trainables`.

Types inheriting from `FluxModule` have to be mutable. They also
have to implement the following methods in order to interact with a [`Trainer`](@ref).

# Required methods

- [`configure_optimisers`](@ref)`(model, trainer)`
- [`train_step`](@ref)`(model, trainer, batch, [batch_idx])`

# Optional Methods 

- [`val_step`](@ref)`(model, trainer, batch, [batch_idx])`
- [`test_step`](@ref)`(model, trainer, batch, [batch_idx])`
- [`on_train_epoch_end`](@ref)`(model, trainer)`
- [`on_val_epoch_end`](@ref)`(model, trainer)`
- [`on_test_epoch_end`](@ref)`(model, trainer)`

# Examples

```julia
using Flux, Tsunami, Optimisers

# Define a Multilayer Perceptron implementing the FluxModule interface

mutable struct Model <: FluxModule
    net
end

function Model()
    net = Chain(Dense(4 => 32, relu), Dense(32 => 2))
    return Model(net)
end

(model::Model)(x) = model.net(x)

function Tsunami.train_step(model::Model, batch, batch_idx)
    x, y = batch
    y_hat = model(x)
    loss = Flux.Losses.mse(y_hat, y)
    return loss
end

function Tsunami.configure_optimisers(model::Model)
    return Optimisers.setup(Optimisers.Adam(1e-3), model)
end

# Prepare the dataset and the DataLoader
X, Y = rand(4, 100), rand(2, 100)
train_dataloader = Flux.DataLoader((X, Y), batchsize=10)

# Create and Train the model
model = Model()
trainer = Trainer(max_epochs=10)
Tsunami.fit!(model, trainer, train_dataloader)
```
"""
abstract type FluxModule end

function Functors.functor(::Type{<:FluxModule}, m::T) where T
    childr = (; (f => getfield(m, f) for f in fieldnames(T))...)
    re = x -> T(x...)
    return childr, re
end

not_implemented_error(name) = error("You need to implement the method `$(name)`")

"""
    configure_optimisers(model, trainer)

Return an optimiser's state initialized for the `model`.
It can also return a tuple of `(scheduler, optimiser)`,
where `scheduler` is any callable object that takes 
the current epoch as input and returns a scalar that will be 
set as the learning rate for the next epoch.

# Examples

```julia
using Optimisers, ParameterScheduler

function Tsunami.configure_optimisers(model::Model)
    return Optimisers.setup(AdamW(1e-3), model)
end

# Now with a scheduler dropping the learning rate by a factor 10 
# at epochs [50, 100, 200] starting from the initial value of 1e-2
function Tsunami.configure_optimisers(model::Model)

    function lr_scheduler(epoch)
        if epoch <= 50
            return 1e-2
        elseif epoch <= 100
            return 1e-3
        elseif epoch <= 200
            return 1e-4
        else
            return 1e-5
        end
    end
    
    opt = Optimisers.setup(AdamW(), model)
    return lr_scheduler, opt
end

# Same as above but using the ParameterScheduler package.
function Tsunami.configure_optimisers(model::Model)
    lr_scheduler = ParameterScheduler.Step(1e-2, 1/10, [50, 50, 100])
    opt = Optimisers.setup(AdamW(), model)
    return lr_scheduler, opt
end
```
"""
function configure_optimisers(model::FluxModule, trainer)
    not_implemented_error("configure_optimisers")
end

"""
    train_step(model, trainer, batch, [batch_idx])

The method called at each training step during `Tsunami.fit!`.
It should compute the forward pass of the model and return the loss 
(a scalar) corresponding to the minibatch `batch`. 
The optional argument `batch_idx` is the index of the batch in the current epoch.

Any `Model <: FluxModule` should implement either 
`train_step(model::Model, trainer, batch)` or `train_step(model::Model, trainer, batch, batch_idx)`.

The training loop in `Tsunami.fit!` approximately looks like this:
```julia
for epoch in 1:epochs
    for (batch_idx, batch) in enumerate(train_dataloader)
        grads = gradient(model) do m
            loss = train_step(m, trainer, batch, batch_idx)
            return loss
        end
        Optimisers.update!(opt, model, grads[1])
    end
end
```

# Examples

```julia
function Tsunami.train_step(model::Model, trainer, batch)
    x, y = batch
    ŷ = model(x)
    loss = Flux.Losses.logitcrossentropy(ŷ, y)
    Tsunami.log(trainer, "loss/train", loss)
    Tsunami.log(trainer, "accuracy/train", Tsunami.accuracy(ŷ, y))
    return loss
end
```
"""
train_step(model::FluxModule, trainer, batch, batch_idx) = train_step(model, trainer, batch)

function train_step(model::FluxModule, trainer, batch)
    not_implemented_error("train_step")
end

"""
    val_step(model, trainer, batch, [batch_idx])

The method called at each validation step during `Tsunami.fit!`.
Tipically used for computing metrcis and statistics on the validation 
batch `batch`. The optional argument `batch_idx` is the index of the batch in the current 
validation epoch. 

A `Model <: FluxModule` should implement either 
`val_step(model::Model, trainer, batch)` or `val_step(model::Model, trainer, batch, batch_idx)`.

See also [`train_step`](@ref).

# Examples
    
```julia
function Tsunami.val_step(model::Model, trainer, batch)
    x, y = batch
    ŷ = model(x)
    loss = Flux.Losses.logitcrossentropy(ŷ, y)
    accuracy = Tsunami.accuracy(ŷ, y)
    Tsunami.log(trainer, "loss/val", loss, on_step = false, on_epoch = true)
    Tsunami.log(trainer, "loss/accuracy", accuracy, on_step = false, on_epoch = true)
end
```
"""
val_step(model::FluxModule, trainer, batch, batch_idx) = val_step(model, trainer, batch)

function val_step(model::FluxModule, trainer, batch)
    # not_implemented_error("val_step")
    return nothing
end

"""
    test_step(model, trainer, batch, batch_idx)

Similard to [`val_step`](@ref) but called at each test step.
"""
function test_step(model::FluxModule, trainer, batch, batch_idx)
    # not_implemented_error("test_step")
    return nothing 
end

"""
    on_train_epoch_end(model, trainer)

Called in `Tsunami.fit!` at the end of each training epoch.
"""    
function on_train_epoch_end(model::FluxModule, trainer)
    return nothing
end 

"""
    on_val_epoch_end(model, trainer)

Called in `Tsunami.fit!` at the end of each validation epoch.
"""
function on_val_epoch_end(model::FluxModule, trainer)
    return nothing
end

"""
    on_test_epoch_end(model, trainer)

Called in `Tsunami.fit!` at the end of each test epoch.
"""
function on_test_epoch_end(model::FluxModule, trainer)
    return nothing
end

"""
    copy!(dest::FluxModule, src::FluxModule)

Shallow copy of all fields of `src` to `dest`.
"""
function Base.copy!(dest::T, src::T) where T <: FluxModule
    for f in fieldnames(T)
        setfield!(dest, f, getfield(src, f))
    end
    return dest
end

function check_fluxmodule(m::FluxModule)
    @assert ismutable(m) "FluxModule has to be a `mutable struct`."
end

function check_train_step(m::FluxModule, trainer, batch)
    out = train_step(m, trainer, batch, 1)
    losserrmsg = "The output of `train_step` has to be a scalar."
    @assert out isa Number losserrmsg
end

function check_val_step(m::FluxModule, trainer, batch)
    val_step(m, trainer, batch, 1)
    @assert true
end

function Base.show(io::IO, mime::MIME"text/plain", m::T) where T <: FluxModule
    if get(io, :compact, false)
        return print(io, "$T()")
    end
    print(io, "$T:")
    for f in sort(fieldnames(T) |> collect)
        startswith(string(f), "_") && continue
        v = getfield(m, f)
        if v isa Chain
            s = "  $f = "
            print(io, "\n$s")
            tsunami_big_show(io, v, length(s))
        else
            print(io, "\n  $f = ")
            compact_show(io, v)
        end
    end
end
