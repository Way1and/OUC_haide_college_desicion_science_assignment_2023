#=
handlers:
- Julia version: 1.9.3
- Author: Way1and
- Date: 2023-11-03
=#
include("./models.jl")

# Arrival 模拟到达事件
function update!(S::State, P::Parameters, R::RandomNGs, E::Arrival)::Customer
    S.current_at = E.at

    customer = generate_customer(S)                                      # 生成 顾客
    enqueue!(S.waiting_queue, customer)                                   # 入队 等待顾客对列
    next_arrival = get_next_arrival(S, R)                                      # 生成 下次抵达事件
    event_push!(S, next_arrival)                                             # 入队
    waiting_go_service(S, P, R)                                             # 推进 队列
    return customer
end


# Departure 处理离开事件
function update!(S::State, P::Parameters, R::RandomNGs, E::Departure)::Customer
    S.current_at = E.at

    #=
    # 出队
    # 这里不能用 service_start_at 因为遇到问题后 出队 顺序变更
    =#

    customer, _ = DataStructures.Base.first(S.servicing_queue) 
    delete!(S.servicing_queue, customer)
    waiting_go_service(S, P, R)
    
    return customer
end

# Problem 处理问题事件
function update!(S::State, P::Parameters, R::RandomNGs, E::Problem)::Union{Customer, Nothing}
    S.current_at = E.at

    # !( 服务队列有用户, 问题队列未满) = 不可以添加问题时
    if !(length(S.servicing_queue) != 0 && length(S.problem_queue) != P.checkout_num)
       return nothing
    end
     
    problem_customer::Customer = rand(R.rng, keys(S.servicing_queue))
    delete!(S.servicing_queue, problem_customer)        # 出队 服务顾客
    problem_customer.problem_count += 1                 # 增加 顾客问题计数
    problem_customer.problem_start_at = S.current_at    # 设置 终止服务 进入问题队列时间
    #= 计算 开始解决时间 resolve_start_at
    # 问题队列为空 直接开始处理
    # 不为空 计算时间
    =#
    
    if length(S.problem_queue) == 0                     
        problem_customer.resolve_start_at = E.at
    else
                                   
        problem_customer.resolve_start_at = E.at - first(S.problem_queue).resolve_start_at + (length(S.problem_queue) - 1) * R.resolution_time() + E.at
        # 开始解决时间点 = (问题发生时间点 - 第一个问题开始解决时间点)即第一个问题剩余解决时间 + 后续问题解决所需时间段 + 出现问题时间点
    end

    enqueue!(S.problem_queue, problem_customer)         # 入队 问题顾客

    # 入队 下次问题事件
    next_problem = Problem(S.event_count + 1, E.at + R.interproblem_time())
    event_push!(S, next_problem)                         

    # 入队 问题解决事件
    resolved = Resolved(S.event_count + 1, problem_customer.resolve_start_at + R.resolution_time())
    resolved.customer_id = problem_customer.id
    event_push!(S, resolved)        

     # 循环修改离开事件时间
    for pair in S.event_queue 
        event, _ = pair
        # 顾客ID 相同, 事件是离开类型
        if event.customer_id == problem_customer.id && isa(event, Departure)
            # 新的离开时间 = ( 原本顾客结束服务时间点 - 顾客问题出现时间点 ) 即剩余服务时间 + 问题解决的时间点   
            S.event_queue[event] =  problem_customer.service_end_at - problem_customer.problem_start_at + resolved.at 
            break
        end
    end
    return problem_customer
end


# Resolved 问题解决事件
function update!(S::State, P::Parameters, R::RandomNGs, E::Resolved)::Customer
    S.current_at = E.at

    customer = dequeue!(S.problem_queue)  # 出队 问题顾客
    customer.service_end_at = customer.service_end_at - customer.problem_start_at + E.at  # 计算 新的完成时间
    enqueue!(S.servicing_queue, customer => customer.service_end_at)  # 入队 服务顾客
    return customer
end

# waiting_go_service 推进
function waiting_go_service(S::State, P::Parameters, R::RandomNGs)
    if (length(S.servicing_queue) + length(S.problem_queue)) < P.checkout_num && length(S.waiting_queue) != 0
        # 有空闲机器 ( 服务 + 问题 ) , 等待队列有顾客
        customer = dequeue!(S.waiting_queue)                                # 出队 等候顾客

        customer.service_start_at = S.current_at                            # 设置 服务开始时间
        customer.service_end_at = R.service_time() + S.current_at           # 随机 服务结束时间

        event_push!(S, Departure(S.event_count, customer.service_end_at, customer.id))    # 入队 顾客离开事件
        enqueue!(S.servicing_queue, customer => customer.service_end_at)                 # 入队 服务顾客队列
    end
end

# event_push 通用 添加事件
function event_push!(S::State, E::Event)
    S.event_count += 1
    enqueue!(S.event_queue, E, E.at)
end

# generate_customer 生成顾客
function generate_customer(S::State)::Customer
    S.customer_count += 1
    return Customer(S.customer_count, S.current_at)
end

# get_next_arrival 下次到达事件
function get_next_arrival(S::State, R::RandomNGs)::Arrival
    next_arrival_at = S.current_at + R.interarrival_time()
    return Arrival(S.event_count + 1, next_arrival_at)
end
