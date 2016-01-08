local filepath = "/home/user/mtrecipe/data.json"

local recipes = {}
local oldc = minetest.register_craft
function minetest.register_craft(def)
  recipes[#recipes + 1] = def
  return oldc(def)
end

local function strip_name(name)
	if name == nil then
		return
	end

	res = name:gsub('%"', '')

	if res:sub(1, 1) == ":" then
    	res = table.concat{res:sub(1, 1-1), "", res:sub(1+1)}
	end

	for str in string.gmatch(res, "([^ ]+)") do
		if str ~= " " and str ~= nil then
			res=str
			break
		end
	end

	if res == nil then
		res=""
	end

	return res
end

local function add_item(state, name)
  local item = minetest.registered_items[name]
  if not item then
    return false
  end

  local desc = item.description
  if not desc or desc == "" then
    desc = name
  end
  local tmp = {data = {id = name:trim(), name = desc, weight = 0}}
  state.nodes[#state.nodes + 1] = tmp
  state.items[name] = tmp

  return true
end

local function recursiveEdge(state, output, recipe)
  if type(recipe) == "table" then
    for _, item in pairs(recipe) do
      recursiveEdge(state, output, item)
    end
  elseif recipe:find("group:") == 0 then
    local flags = recipe:split(",")
    for name, def in pairs(minetest.registered_items) do
      local flag = true
      for k, v in pairs(flags) do
        local g = def.groups and def.groups[v:gsub('%group:', '')] or 0
        if not g or g <= 0 then
          flag = false
          break
        end
      end
      if flag then
        recursiveEdge(state, output, name)
      end
    end
  else
    recipe = strip_name(recipe)
    if recipe == "" then
      return
    end
    if not state.links[recipe .. "_GOES_TO_" .. output] then
      local reg = minetest.registered_items
      if not reg[output] or not reg[recipe] then
        return
      end
      if not state.items[output] and not add_item(state, output) then
        return
      end
      if not state.items[recipe] and not add_item(state, recipe) then
        return
      end
      state.items[output].data.weight = state.items[output].data.weight + 1
      state.items[recipe].data.weight = state.items[recipe].data.weight + 1
      state.links[recipe .. "_GOES_TO_" .. output] = true
      state.edges[#state.edges + 1] = {data = {source = recipe:trim(), target = output:trim()}}
    end
  end
end

minetest.after(0, function()
  local nodes = {}
  local edges = {}
  local state = {nodes=nodes, edges=edges, links={}, items={}}
  for _, recipe in pairs(recipes) do
    if recipe.output then
      recursiveEdge(state, strip_name(recipe.output), recipe.recipe)
    end
  end

  local retval = minetest.write_json({
    nodes = nodes,
    edges = edges
  })
  local file = io.open(filepath, "w")
  file:write(retval)
  file:write("\n")
  file:close()
end)
