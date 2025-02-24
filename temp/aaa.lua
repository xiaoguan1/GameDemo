local DStar = {}
DStar.__index = DStar

-- 优先队列实现（最小堆）
local PriorityQueue = {}
PriorityQueue.__index = PriorityQueue

function PriorityQueue.new()
    return setmetatable({
        elements = {},
        size = 0
    }, PriorityQueue)
end

function PriorityQueue:insert(item, key)
    self.size = self.size + 1
    local i = self.size
    while i > 1 do
        local parent = math.floor(i/2)
        if self.elements[parent].key > key then
            self.elements[i] = self.elements[parent]
            i = parent
        else
            break
        end
    end
    self.elements[i] = {item = item, key = key}
end

function PriorityQueue:pop()
    if self.size == 0 then return nil end
    local result = self.elements[1]
    self.elements[1] = self.elements[self.size]
    self.size = self.size - 1
    local i = 1
    while true do
        local left = 2*i
        local right = 2*i+1
        local smallest = i
        
        if left <= self.size and self.elements[left].key < self.elements[smallest].key then
            smallest = left
        end
        if right <= self.size and self.elements[right].key < self.elements[smallest].key then
            smallest = right
        end
        
        if smallest ~= i then
            self.elements[i], self.elements[smallest] = self.elements[smallest], self.elements[i]
            i = smallest
        else
            break
        end
    end
    return result.item, result.key
end

function PriorityQueue:update(item, newKey)
    for i = 1, self.size do
        if self.elements[i].item == item then
            self.elements[i].key = newKey
            while i > 1 and self.elements[i].key < self.elements[math.floor(i/2)].key do
                local parent = math.floor(i/2)
                self.elements[i], self.elements[parent] = self.elements[parent], self.elements[i]
                i = parent
            end
            return true
        end
    end
    return false
end

-- D*算法核心实现
function DStar.new(grid, start, goal)
    local self = setmetatable({}, DStar)

    self.grid = grid
    self.start = start
    self.goal = goal
    self.openList = PriorityQueue.new()
    self.nodes = {}
    self.current = start

    -- 初始化节点
    for y = 1, #grid do
        self.nodes[y] = {}
        for x = 1, #grid[y] do
            self.nodes[y][x] = {
                x = x,
                y = y,
                state = "NEW",
                h = 0,
                k = math.huge,
                parent = nil,
                neighbors = {},
                cost = {}
            }
        end
    end

    -- 预计算邻接关系和移动成本
    for y = 1, #grid do
        for x = 1, #grid[y] do
            local node = self.nodes[y][x]
            for dy = -1, 1 do
                for dx = -1, 1 do
                    if not (dx == 0 and dy == 0) then
                        local nx, ny = x+dx, y+dy
                        if nx >= 1 and nx <= #grid[y] and ny >= 1 and ny <= #grid then
                            table.insert(node.neighbors, self.nodes[ny][nx])
                            -- 计算初始移动成本
                            if grid[ny][nx] == 1 then
                                node.cost[self.nodes[ny][nx]] = math.huge
                            else
                                node.cost[self.nodes[ny][nx]] = (dx ~= 0 and dy ~= 0) and math.sqrt(2) or 1
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- 初始化目标节点
    local goalNode = self.nodes[goal.y][goal.x]
    goalNode.h = 0
    goalNode.k = 0
    self.openList:insert(goalNode, 0)
    goalNode.state = "OPEN"
    
    return self
end

function DStar:processState()
    if self.openList.size == 0 then return -1 end
    
    local x, k_old = self.openList:pop()
    x.state = "CLOSED"
    
    -- 传播信息
    if k_old < x.h then
        for _, y in ipairs(x.neighbors) do
            if y.h + x.cost[y] < x.h then
                x.parent = y
                x.h = y.h + x.cost[y]
            end
        end
    end
    
    if k_old == x.h then
        for _, y in ipairs(x.neighbors) do
            if y.state ~= "CLOSED" and 
               (y.h > x.h + y.cost[x] or y.parent == x) then
                y.parent = x
                self:insert(y, x.h + y.cost[x])
            end
        end
    else
        for _, y in ipairs(x.neighbors) do
            if y.state ~= "CLOSED" and 
               (y.parent == x or y.h > x.h + y.cost[x]) then
                self:insert(y, y.h)
            end
        end
    end
    
    return self.openList.size
end

function DStar:insert(node, newH)
    if node.state == "NEW" then
        node.k = newH
    elseif node.state == "OPEN" then
        node.k = math.min(node.k, newH)
    else -- CLOSED
        node.k = math.min(node.h, newH)
    end
    
    node.h = newH
    if node.state ~= "OPEN" then
        self.openList:insert(node, node.k)
        node.state = "OPEN"
    else
        self.openList:update(node, node.k)
    end
end

function DStar:modifyCost(x, y, newCost)
    local node = self.nodes[y][x]
    for _, neighbor in ipairs(node.neighbors) do
        neighbor.cost[node] = newCost
        if neighbor.state == "CLOSED" then
            self:insert(neighbor, neighbor.h)
        end
    end
    while self:processState() ~= -1 do end
end

function DStar:findPath()
    local path = {}
    local current = self.nodes[self.start.y][self.start.x]
    
    while current and (current.x ~= self.goal.x or current.y ~= self.goal.y) do
        table.insert(path, {x = current.x, y = current.y})
        
        local minCost = math.huge
        local nextNode = nil
        for _, neighbor in ipairs(current.neighbors) do
            local cost = neighbor.h + current.cost[neighbor]
            if cost < minCost then
                minCost = cost
                nextNode = neighbor
            end
        end
        
        current = nextNode
        if not current then break end
    end
    
    if current then
        table.insert(path, {x = current.x, y = current.y})
    end
    
    return #path > 0 and path or nil
end

-- 测试用例
local grid = {
    {0, 0, 0, 0, 0},
    {0, 1, 0, 0, 0},
    {0, 1, 1, 0, 0},
    {0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0},
}

local start = {x = 1, y = 1}
local goal = {x = 5, y = 5}

-- 初始化D*算法
local dstar = DStar.new(grid, start, goal)

-- 第一次规划路径
while dstar:processState() ~= -1 do end
local path = dstar:findPath()

print("初始路径：")
if path then
    for _, pos in ipairs(path) do
        print("→ ("..pos.x..","..pos.y..")")
    end
else
    print("没有找到路径")
end

-- 动态更新障碍物（假设在(3,3)位置出现新障碍）
print("\n检测到新障碍物，重新规划路径...")
dstar:modifyCost(3, 3, math.huge)

-- 重新获取路径
local newPath = dstar:findPath()

print("\n新路径：")
if newPath then
    for _, pos in ipairs(newPath) do
        print("→ ("..pos.x..","..pos.y..")")
    end
else
    print("没有找到可行路径")
end