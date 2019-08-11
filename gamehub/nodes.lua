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
]]

local function rpad_timer(pos, elapsed)

	local meta = minetest.get_meta(pos)
	local game = meta:get_string("game")

	if game == "" then
		return true
	elseif not gamehub.game[game] then
		return true
	end

	local data = gamehub.game[game].data.rpad

	if not data then
		minetest.log("error", "Warning: rpad data missing at " .. minetest.pos_to_string(pos))
		return false
	end

	local objs = minetest.get_objects_inside_radius(pos, 1)

	if #objs == 0 then return true end

	if vector.equals(data.pos, pos) then

		for i, obj in ipairs(objs) do

			if obj:is_player() then

				local name = obj:get_player_name()

				if gamehub.player[name].game == game or
				gamehub.privs[name].hub_admin then
					gamehub.process_stats(name)
					minetest.sound_play("pad_reward", {
						to_player = name, gain = 1, loop = false})
					gamehub.player_reward(name, game)
					gamehub.enter_world(name)
					obj:set_hp(20)
				else
					if not gamehub.privs[name].hub_mod then
						minetest.log("action", name ..
						" attempted to use the reward pad in "..
						game ..
						" whilst registerd to "..gamehub.player[name].game)
					end
				end

			end

		end
	else

		local msg = {}
		msg[#msg+1] = 'rpad at '
		msg[#msg+1] = minetest.pos_to_string(pos)
		msg[#msg+1] = ' does not match db record '
		msg[#msg+1] = minetest.pos_to_string(data.pos)
		minetest.log("warning", msg:concat())
	end

	return true
end

local function gpad_timer(pos, elapsed)

	local objs = minetest.get_objects_inside_radius(pos, 1)

	if #objs == 0 then return true end

	local meta = minetest.get_meta(pos)
	local pad = tonumber(meta:get_string("pad"))
	local area = gamehub.area_at_pos(pos)
	local game = area.name
	local stage = gamehub.game[game].data.stages[pad]

	if vector.equals(pos, stage.pos) then
		for i, obj in ipairs(objs) do

			if obj:is_player() then

				local name = obj:get_player_name()

				if gamehub.privs[name].hub_admin or -- admin test access
				gamehub.player[name].game == game then -- game players
					obj:set_pos(stage.dest)
					obj:set_look_horizontal(stage.facing.h)
					obj:set_look_vertical(stage.facing.v)
				end

			end
		end
	else

		local msg = {}
		msg[#msg+1] = 'gpad at '
		msg[#msg+1] = minetest.pos_to_string(pos)
		msg[#msg+1] = ' does not match db record '
		msg[#msg+1] = minetest.pos_to_string(stage.pos)
		minetest.log("warning", msg:concat())

	end

	return true -- run again
end

-----------------------------
-- REGISTER NODES
-----------------------------

-- coord based teleport pad
minetest.register_node("gamehub:gpad", {
	tiles = {"hub_gpad.png"},
	drawtype = 'nodebox',
	paramtype = "light",
	paramtype2 = "wallmounted",
	legacy_wallmounted = true,
	walkable = true,
	sunlight_propagates = true,
	description = "Teleport pad to move player to the next stage in the game",
	inventory_image = "hub_gpad.png",
	wield_image = "hub_gpad.png",
	light_source = 14,
	groups = {unbreakable = 1, not_in_creative_inventory = 1},
	node_box = {
		type = "wallmounted",
		wall_top = { - 0.5, 0.4375, - 0.5, 0.5, 0.5, 0.5},
		wall_bottom = { - 0.5, - 0.5, - 0.5, 0.5, - 0.4375, 0.5},
		wall_side = { - 0.5, - 0.5, - 0.5, - 0.4375, 0.5, 0.5},
	},
	selection_box = {type = "wallmounted"},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local area, ctr = gamehub.area_at_pos(pos)
		if area and ctr == 1 then
			local game = area.name
			local data = gamehub.game[game].data
			local stages = data.stages or {}
			for _, stage in ipairs(stages) do
				if stage.pos == 0 then
					stage.pos = pos
					gamehub.game[game].data = data
					gamehub.update_game_field(game, "data")
					break
				end
			end
			meta:set_string("infotext", "Stage " .. #stages+1)
			meta:set_string("pad", #stages)
			minetest.get_node_timer(pos):start(1.0)
		end
	end,
	on_destruct = function(pos)
		local area, _ = gamehub.area_at_pos(pos)
		if area then
			local game = area.name
			local data = gamehub.game[game].data
			local stages = data.stages
			for i, stage in ipairs(stages) do
				if vector.equals(stage.pos, vector.round(pos)) then
					stage.pos = {}
					break
				end
			end
			gamehub.game[game].data = data
			gamehub.update_game_field(game, "data")
		end
	end,
	on_drop = function(itemstack, dropper, pos)
		return
	end,
	on_timer = gpad_timer,
})

-- reward pad:
minetest.register_node("gamehub:rpad", {
	tiles = {"hub_rpad.png"},
	drawtype = 'nodebox',
	paramtype = "light",
	paramtype2 = "wallmounted",
	legacy_wallmounted = true,
	walkable = true,
	sunlight_propagates = true,
	description = "Reward Pad (place and right-click to set)",
	inventory_image = "hub_rpad.png",
	wield_image = "hub_rpad.png",
	light_source = 14,
	groups = {unbreakable = 1, not_in_creative_inventory = 1},
	node_box = {
		type = "wallmounted",
		wall_top = { - 0.5, 0.4375, - 0.5, 0.5, 0.5, 0.5},
		wall_bottom = { - 0.5, - 0.5, - 0.5, 0.5, - 0.4375, 0.5},
		wall_side = { - 0.5, - 0.5, - 0.5, - 0.4375, 0.5, 0.5},
	},
	selection_box = {type = "wallmounted"},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		-- set formspec & info
		meta:set_string("formspec", "size[3.2,2.5]"..
			"field[0.5,0.75;2,0.25;game;Game;${game}]"..
			"button_exit[0.6,1.75;2,0.2;quit;Save]")
		meta:set_string("infotext", "Right-click to set")
		minetest.get_node_timer(pos):start(1.0)
	end,
	on_destruct = function(pos)
		local area, _ = gamehub.area_at_pos(pos)
		if area then
			local game = area.name
			gamehub.game[game].data.rpad = nil
			gamehub.update_game_field(game, "data")
		end
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		if fields.quit then
			if not fields.game then return end
			local game = fields.game
			local name = sender:get_player_name()
			if not name then
				return
			elseif not gamehub.privs[name].hub_admin then
				minetest.chat_send_player(name, "permission denied!")
				return
			elseif not gamehub.game[game] then
				minetest.chat_send_player(name, game .. " doesn't exist!")
				return
			end
			-- set pad meta
			local meta = minetest.get_meta(pos)
			meta:set_string("game", game)
			meta:set_string("formspec", "")
			meta:set_string("infotext",	"Step on pad to complete ".. game)
			-- store data
			gamehub.game[game].data.rpad = {pos = vector.round(pos)}
			gamehub.update_game_field(game, "data")
		end
	end,
	on_drop = function(itemstack, dropper, pos)
		return
	end,
	on_timer = rpad_timer,
})

----------------------
--  EXTRAS
----------------------

minetest.register_node("gamehub:egg", {
		description = "Easter Egg",
		drawtype = "plantlike",
		tiles = {"hub_egg.png"},
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = false,
		groups = {crumbly = 1, not_in_creative_inventory = 1},
		drop = {},
		sounds = default.node_sound_stone_defaults,
})

if minetest.get_modpath("moreblocks") then
	-- Add support for moreores mod
	stairsplus:register_all("moreores", "mithril_block", "moreores:mithril_block", {
		description = "Mithril",
		tiles = {"moreores_mithril_block.png"},
		groups = {snappy = 1, bendy = 2, cracky = 1, melty = 2, level= 2},
		sounds = default.node_sound_stone_defaults(),
	})

	stairsplus:register_all("moreores", "silver_block", "moreores:silver_block", {
		description = "Silver",
		tiles = {"moreores_silver_block.png"},
		groups = {snappy = 1, bendy = 2, cracky = 1, melty = 2, level= 2},
		sounds = default.node_sound_stone_defaults(),
	})
	-- Add snow and ice
	stairsplus:register_all("moreblocks", "snowblock", "default:snowblock", {
		description = "Snow Block",
		tiles = {"default_snow.png"},
		groups = {crumbly = 3, cools_lava = 1, snowy = 1},
		sounds = default.node_sound_snow_defaults(),
	})

	stairsplus:register_all("moreblocks", "ice", "default:ice", {
		description = "Ice",
		tiles = {"default_ice.png"},
		is_ground_content = false,
		paramtype = "light",
		groups = {cracky = 3, cools_lava = 1, slippery = 3},
		sounds = default.node_sound_glass_defaults(),
	})

end

-- Add cleanup for rogue entities from signs_lib
if not signs_lib then
	minetest.register_entity(":signs:text", {
		on_activate = function(self)
			self.object:remove()
		end
	})
end
