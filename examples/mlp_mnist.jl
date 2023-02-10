using Flux, Functors, Optimisers, Tsunami, MLDatasets
using Flux: DataLoader, flatten

mutable struct MLP <: FluxModule
    net
end

function MLP()
    net = Chain(
        flatten,
        Dense(28^2 => 256, relu), 
        Dense(256 => 10))
    return MLP(net)
end

function (m::MLP)(x)
    m.net(x)
end

function Tsunami.training_step(m::MLP, batch, batch_idx)
    x, y = batch
    y_hat = m(x)
    y = Flux.onehotbatch(y, 0:9)
    loss = Flux.Losses.logitcrossentropy(y_hat, y)
    acc = Tsunami.accuracy(y_hat, y)
    return (; loss, acc)
end

function Tsunami.configure_optimisers(m::MLP)
    return Optimisers.setup(Optimisers.AdamW(1e-3), m)
end

train_loader = DataLoader(MNIST(:train), batchsize=128, shuffle=true)
test_loader = DataLoader(MNIST(:test), batchsize=128)

# TRAIN FROM SCRATCH
model = MLP()
trainer = Trainer(max_epochs=10, 
                 default_root_dir=@__DIR__,
                 accelerator=:cpu,
                 enable_checkpointing=true,
                 logger=true,
                 )
Tsunami.fit!(model, trainer; train_dataloader=train_loader, val_dataloader=test_loader)

# RESUME TRAINING
trainer.max_epochs = 20
Tsunami.fit!(model, trainer; train_dataloader=train_loader, val_dataloader=test_loader,
    ckpt_path = joinpath(@__DIR__, "ckpt_epoch=0002.bson"))
