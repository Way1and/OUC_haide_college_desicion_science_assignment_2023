#=
models:
- Julia version: 1.9.3
- Author: Way1and
- Date: 2023-11-03
=#



using StableRNGs
using DataStructures
using Distributions

# Event 事件 (抽象)
abstract type Event end


# Arrival 顾客到达
mutable struct Arrival <: Event
    id::Int64
    at::Float64
    customer_id::Union{Nothing,Int64}
    Arrival(id::Int64, at::Float64) = new(id, at, nothing)
end

# Departure 顾客离开
mutable struct Departure <: Event
    id::Int64
    at::Float64
    customer_id::Union{Nothing,Int64}
    Departure(id::Int64, at::Float64) = new(id, at, nothing)
    Departure(id::Int64, at::Float64, customer_id::Int64) = new(id, at, customer_id)
    
end

# Problem 顾客遇到问题
mutable struct Problem <: Event
    id::Int64
    at::Float64
    customer_id::Union{Nothing,Int64}
    Problem(id::Int64, at::Float64) = new(id, at, nothing)
end
# Resolved 顾客问题解决
mutable struct Resolved <: Event
    id::Int64
    at::Float64
    customer_id::Union{Nothing,Int64}
    Resolved(id::Int64, at::Float64) = new(id, at, nothing)
end
# Customer 顾客
mutable struct Customer
    id::Int64                 # 客户ID
    arrival_at::Float64       # 到达时间
    service_end_at::Float64   # 结束服务时间
    service_start_at::Float64 # 开始当前服务时间
    problem_start_at::Float64 # 问题出现解决时间
    resolve_start_at::Float64 # 问题开始解决时间
    problem_count::Int64        # 客户问题数量

    # 构造函数
    Customer(id::Int64, arrival_at::Float64) = new(id, arrival_at, Inf, Inf, Inf, Inf, 0)
end

# State 服务状态 
mutable struct State
    current_at::Float64                               # 当前时间
    event_queue::PriorityQueue{Event,Float64}        # 事件队列
    waiting_queue::Queue{Customer}                    # 等待队列
    servicing_queue::PriorityQueue{Customer,Float64} # 服务队列
    problem_queue::Queue{Customer}                   # 有问题的客户
    event_count::Int64                                # 事件计数
    customer_count::Int64                             # 客户计数

    # 构造函数
    State() = new(0.0, PriorityQueue{Event,Float64}(), Queue{Customer}(), PriorityQueue{Customer,Float64}(), Queue{Customer}(), 0, 0)
end

# Parameters 程序参数
struct Parameters
    seed::Int64                      # 种子
    checkout_num::Int64             # 市场结账数量
    interarrival_time_mean::Float64 # 到达队列后平均结账时间
    service_time_mean::Float64      # 平均每个服务花费时间
    interproblem_time_mean::Float64 # 两个问题出现平均间隔时间
    resolution_time_mean::Float64   # 处理每个问题花费的时间
    final_at::Float64

end

# Parameters 构造函数 判断输入参数是否合法
function Parameters(seed :: Int64, checkout_num::Int64, interarrival_time_mean :: Float64, 
    service_time_mean ::Float64, interproblem_time_mean::Float64, resolution_time_mean :: Float64, final_at::Float64)
    if service_time_mean <= 0
        throw_error("service_time_mean")
    end

    if checkout_num <= 0
        throw_error("checkout_num")
    end


    if interproblem_time_mean <= 0
        throw_error("interproblem_time_mean")
    end

    if resolution_time_mean < 0
        throw_error("resolution_time_mean")
    end

    if interarrival_time_mean < 0
        throw_error("interarrival_time_mean")
    end

    if final_at <= 0
        throw_error("final_at")
    end
   
    return Parameters(seed, checkout_num, interarrival_time_mean, service_time_mean, interproblem_time_mean, resolution_time_mean, final_at)
end

function throw_error(key)
     throw(DomainError(key, "argument must be reasonable."))
end

# RandomNGs 随机数
struct RandomNGs
    rng::StableRNGs.LehmerRNG
    interarrival_time::Function
    service_time::Function
    interproblem_time::Function
    resolution_time::Function
end

# RandomNGs 构造函数
function RandomNGs(P::Parameters)
    rng = StableRNGs.LehmerRNG(P.seed)
    interarrival_time() = rand(rng, Exponential(P.interarrival_time_mean))
    service_time() = rand(rng, Exponential(P.service_time_mean))
    interproblem_time() = rand(rng, Exponential(P.interproblem_time_mean))
    resolution_time() = P.resolution_time_mean
    return RandomNGs(rng, interarrival_time, service_time, interproblem_time, resolution_time)
end