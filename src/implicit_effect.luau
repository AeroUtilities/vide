--* [[----------< modules >----------]]

local graph = require "./graph"


--* [[----------< graph >----------]]

local create_node = graph.create_node
local assert_stable_scope = graph.assert_stable_scope
local get_scope = graph.get_scope
local evaluate_node = graph.evaluate_node
local push_cleanup = graph.push_cleanup


--* [[----------< types >----------]]

-- anything accepted as a child: an instance, a nested list, or a function returning either (nil = nothing)
-- the list is read-only so arrays of narrower types (e.g. { Instance }) are accepted; mutable tables are invariant
export type Children = Instance | { read [number]: Children } | (() -> Children?)

type ChildrenCache = {
    instance: Instance,
    cur_children_set: { [Instance]: true },
    new_children_set: { [Instance]: true },
    source: () -> Children?,
}

type PropertyCache = {
    instance: Instance,
    property: string,
    source: () -> unknown,
}

type ParentCache = {
    instance: Instance,
    source: () -> Instance,
}


--* [[----------< effects >----------]]

local function update_property_effect(p: PropertyCache): PropertyCache
    (p.instance :: any)[p.property] = p.source()
    return p
end

local function update_parent_effect(p: ParentCache): ParentCache
    p.instance.Parent = p.source()
    return p
end

-- todo: investigate if "count" method used in indexes() and values() can improve performance here
local function update_children_effect(p: ChildrenCache): ChildrenCache
    local cur_children_set = p.cur_children_set -- children parented before this update
    local new_children_set = p.new_children_set -- children that should remain after this update

    local new_children = p.source()

    local function process_child(child: Children?)
        if type(child) == "userdata" then
            local instance = child :: Instance
            if new_children_set[instance] then
                return -- already recorded this update
            end

            new_children_set[instance] = true

            if not cur_children_set[instance] then
                instance.Parent = p.instance
            else
                cur_children_set[instance] = nil -- still present; keep parented
            end
        elseif type(child) == "table" then
            for _, sub in child do
                process_child(sub)
            end
        elseif type(child) == "function" then
            local cache: ChildrenCache = {
                instance = p.instance,
                cur_children_set = {},
                new_children_set = {},
                source = child,
            }

            local scope = assert(get_scope())
            local node = create_node(scope, update_children_effect, cache)

            evaluate_node(node)

            push_cleanup(scope, function()
                for nested in node.cache.cur_children_set do
                    nested.Parent = nil
                end
            end)
        end
    end

    process_child(new_children)

    for child in cur_children_set do
        child.Parent = nil -- no longer in the new set
    end

    table.clear(cur_children_set) -- clear cache, preserve capacity
    p.cur_children_set, p.new_children_set = new_children_set, cur_children_set

    return p
end


--* [[----------< api >----------]]

local function property(instance: Instance, property_name: string, source: () -> unknown)
    local node = create_node(assert_stable_scope(), update_property_effect, {
        instance = instance,
        property = property_name,
        source = source,
    })

    evaluate_node(node)

    return node
end

local function parent(instance: Instance, source: () -> Instance)
    local node = create_node(assert_stable_scope(), update_parent_effect, {
        instance = instance,
        source = source,
    })

    evaluate_node(node)

    return node
end

local function children(instance: Instance, source: () -> Children?)
    local scope = assert_stable_scope()
    local cache: ChildrenCache = {
        instance = instance,
        cur_children_set = {},
        new_children_set = {},
        source = source,
    }

    local node = create_node(scope, update_children_effect, cache)

    evaluate_node(node)

    push_cleanup(scope, function()
        for child in node.cache.cur_children_set do
            child.Parent = nil
        end
    end)

    return node
end

return {
    property = property,
    parent = parent,
    children = children,
}
