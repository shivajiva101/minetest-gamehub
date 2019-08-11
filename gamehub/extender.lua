--[[
gamehub mod (C) shivajiva101@hotmail.com 2019

This file is part of gamehub.

    gamehub is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    gamehub is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with gamehub.  If not, see <https://www.gnu.org/licenses/>.

	Some parts of the code in this file are modified or copied
	from worldedit by Uberi https://github.com/Uberi/Minetest-WorldEdit
]]

local HEADER = 5 .. ":"

-- Serialise any meta nodes within a volume
-- @param pos1: first vector
-- @param pos2: second vector
-- @return serialised string, node count
function gamehub.serialise_meta(pos1, pos2)

	pos1, pos2 = worldedit.sort_pos(pos1, pos2)
	worldedit.keep_loaded(pos1, pos2)

	local pos = {x=pos1.x, y=0, z=0}
	local count = 0
	local result = {}
	local get_node, get_meta = minetest.get_node, minetest.get_meta
	while pos.x <= pos2.x do
		pos.y = pos1.y
		while pos.y <= pos2.y do
			pos.z = pos1.z
			while pos.z <= pos2.z do
				local node = get_node(pos)
				if node.name ~= "air" and node.name ~= "ignore" then

					local meta = get_meta(pos):to_table()
					local meta_content

					-- Convert metadata item stacks to item strings
					for name, inventory in pairs(meta.inventory) do
						for index, stack in ipairs(inventory) do
							meta_content = true
							inventory[index] = stack.to_string and stack:to_string() or stack
						end
					end

					for name, field in pairs(meta.fields) do
						meta_content = true
					end

					for k in pairs(meta) do
						if k ~= "inventory" and k ~= "fields" then
							meta_content = true
							break
						end
					end

					if meta_content then
						count = count + 1
						result[count] = {
							x = pos.x - pos1.x,
							y = pos.y - pos1.y,
							z = pos.z - pos1.z,
							name = node.name,
							param1 = node.param1 ~= 0 and node.param1 or nil,
							param2 = node.param2 ~= 0 and node.param2 or nil,
							meta = meta_content and meta or nil,
						}

					end
				end
				pos.z = pos.z + 1
			end
			pos.y = pos.y + 1
		end
		pos.x = pos.x + 1
	end
	-- Serialise entries
	return HEADER .. minetest.serialize(result), count
end


-- Adds a hollow cube of playerclip double lined with kill
-- designed for games created in the air
-- @param pos: base vector of cube (x=,y=,z=)
-- @param vol: volume (x=,y=,z=)
-- @param clear: replace shield with air (bool)
-- @return number of nodes added
local function wrapper(pos, vol, remove)

	local function sort_pos(pos1, pos2)
		if pos1.x > pos2.x then
			pos2.x, pos1.x = pos1.x, pos2.x
		end
		if pos1.y > pos2.y then
			pos2.y, pos1.y = pos1.y, pos2.y
		end
		if pos1.z > pos2.z then
			pos2.z, pos1.z = pos1.z, pos2.z
		end
		return pos1, pos2
	end

	local function volume(pos1, pos2)
		local p1, p2 = sort_pos(pos1, pos2)
		return (p2.x - p1.x + 1) *
			(p2.y - p1.y + 1) *
			(p2.z - p1.z + 1)
	end

	local function get_empty_data(area)
		local data = {}
		local c_ignore = minetest.get_content_id("ignore")
		for i = 1, volume(area.MinEdge, area.MaxEdge) do
			data[i] = c_ignore
		end
		return data
	end

	local function init(pos1, pos2)
		local manip = minetest.get_voxel_manip()
		local emerged_pos1, emerged_pos2 = manip:read_from_map(pos1, pos2)
		local area = VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
		return manip, area
	end

	local manip, area = init(pos, vector.add(pos, vol))
	local data = get_empty_data(area)
	local node_1, node_2, msg
	if remove == true then
		node_1 = minetest.get_content_id("air")
		node_2 = node_1
		msg = "Shield replaced with air on area id: "
	else
		node_1 = minetest.get_content_id("maptools:playerclip")
		node_2 = minetest.get_content_id("maptools:kill")
		msg = "Shield added to area id: "
	end
	local stride = {x=1, y=area.ystride, z=area.zstride}
	local offset = vector.subtract(pos, area.MinEdge)
	local count = 0

	-- add the nodes
	for z = 0, vol.z-1 do
		local index_z = (offset.z + z) * stride.z + 1
		for y = 0, vol.y-1 do
			local index_y = index_z + (offset.y + y) * stride.y
			for x = 0, vol.x-1 do
				local is_clip = z == 0 or z == vol.z-1
					or y == 0 or y == vol.y-1
					or x == 0 or x == vol.x-1
				local is_kill = z == 1 or z == vol.z-2	or z == vol.z-3
				or y == 1 or y == 2 or y == vol.y-2 or y == vol.y-3
				or x == 1 or x == 2 or x == vol.x-2 or x == vol.x-3
				if is_clip then
					local i = index_y + (offset.x + x)
					data[i] = node_1
					count = count + 1
				elseif is_kill then
					local i = index_y + (offset.x + x)
					data[i] = node_2
					count = count + 1
				end
			end
		end
	end

	manip:set_data(data)
	manip:write_to_map()
	manip:update_map()

	return count, msg
end

-- Adds a protective shield to an area id
-- @param id: area id to shield (int)
-- @param remover: replace shield with air (bool)
-- @return number of nodes added
gamehub.protect = function(id, remove)

	local p1, p2, dims
	local areas = areas.areas
	-- using area vectors
	p1 = areas[id].pos1
	p2 = areas[id].pos2

	-- sort if reqd
	if p1.y > p2.y then
		p2, p1 = p1, p2
	end

	-- volume vect
	dims = {
		x = p2.x - p1.x,
		y = p2.y - p1.y,
		z = p2.z - p1.z
	}

	-- unsign if reqd
	for k,v in pairs(dims) do
		if v < 0 then
			dims[k] = (v*v)^0.5
		end
	end

	-- execute, returning node count
	return wrapper(p1, dims, remove)
end
