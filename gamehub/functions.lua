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

local context = {}
local hud = {}
local dirty = {}
local armor_mod = minetest.get_modpath("3d_armor")
local HSMD = 20


--[[
-----------------------------
Internal Functions
-----------------------------
]]

-- Teleport player to a game
-- @param player: player object
-- @param data: either name of game or table containing pos and facing
-- @return nothing
local tp = function(player, dta)

	local pos, facing
	local name = player:get_player_name()
	if type(dta) == "table" then
		pos = dta.pos
		facing = dta.facing
	elseif type(dta) == "string" then
		-- game teleporter
		if dta == "world" then
			pos = gamehub.player[name].pos
			facing = gamehub.player[name].facing
		else
			pos = gamehub.game[dta].pos
			facing = gamehub.game[dta].facing
		end
		gamehub.player[name].game = dta
	end

	minetest.sound_play("pad_teleport", {
		to_player = name,
		gain = 0.1,
		loop = false
	})
	player:set_pos(pos)
	player:set_look_horizontal(facing.h)
	player:set_look_vertical(facing.v)
end

-- Toggle players game hud
-- @param player: player object
-- @return nothing
local toggle_hud = function(player)
	local name = player:get_player_name()
	if not gamehub.privs[name].hub_mod then
		local game = gamehub.player[name].game
		if game == "world" then
			player:hud_set_flags({
				hotbar = true,
				healthbar = true,
				wielditem = true}
			)
		else
			player:hud_set_flags({
				hotbar = false,
				healthbar = false,
				wielditem = false}
			)
		end
	end
end

-- Set players name tag colour
-- @param player: minetest player object
-- @param color: ARGB colour table (a=,r=,g=,b=)
-- @return nothing
local set_nametag = function(player, color)
	player:set_nametag_attributes({
		color = color
	})
end

-- Clear a players inventory
-- @param player; minetest player object
-- @return nothing
local inventory_clear = function(player)

	local player_name = player:get_player_name()
	local player_inv = player:get_inventory()
	local bags_inv = minetest.get_inventory({type = 'detached', name = player_name..'_bags'})
	local lists = player_inv:get_lists()

	-- initialise shadow inventories
	if lists.smain == nil then
		player_inv:set_size("smain", player_inv:get_size("main"))
	end

	if lists.scraft == nil then
		player_inv:set_size("scraft", player_inv:get_size("craft"))
	end

	-- shadow contents and delete
	if player_inv:is_empty("smain") then -- empty?
		player_inv:set_list("smain", player_inv:get_list("main")) -- copy
		player_inv:set_list("main", {}) -- clear
	else
		player_inv:set_list("main", {}) -- clear
	end

	if player_inv:is_empty("scraft") then -- empty?
		player_inv:set_list("scraft", player_inv:get_list("craft")) -- copy
		player_inv:set_list("craft", {}) -- clear
	else
		player_inv:set_list("craft", {}) -- clear
	end

	if armor_mod then

		if lists.sarmor == nil then
			player_inv:set_size("sarmor", player_inv:get_size("armor"))
		end

		if player_inv:is_empty("sarmor") then -- empty?
			player_inv:set_list("sarmor", player_inv:get_list("armor")) -- copy
			player_inv:set_list("armor", {}) -- clear
			armor:set_player_armor(player) --refresh
			--armor:update_inventory(player) -- update
		else
			player_inv:set_list("armor", {}) -- clear
			armor:set_player_armor(player) --refresh
		end
	end

	if bags_inv then
		for bag = 1, 4 do -- store and clear bags

			if not bags_inv:is_empty('bag'..bag) then
				-- set inventory size for current bag
				player_inv:set_size("sbag"..bag, bags_inv:get_size('bag'..bag))
				player_inv:set_list("sbag"..bag, bags_inv:get_list("bag"..bag))
				player_inv:set_list("bag"..bag, {})
			else
				player_inv:set_list("bag"..bag, {})
			end
		end
	end
	-- TODO set inventory page
	--player:set_inventory_formspec()
end

-- Restore a players inventory
-- @param player; minetest player object
-- @return nothing
local inventory_restore = function(player)

	local player_inv = player:get_inventory()
	local name = player:get_player_name()
	local bags_inv = minetest.get_inventory({type = 'detached', name = name..'_bags'})


	if not player_inv:is_empty("smain") then -- contents?
		player_inv:set_list("main", player_inv:get_list("smain")) -- copy
		player_inv:set_list("smain", {}) -- clear
	end

	if not player_inv:is_empty("scraft") then -- contents?
		player_inv:set_list("craft", player_inv:get_list("scraft")) -- copy
		player_inv:set_list("scraft", {}) -- clear
	else
		player_inv:set_list("craft", {}) -- prevent theft from hub games
	end

	if armor_mod then
		if not player_inv:is_empty("sarmor") then -- contents?
			player_inv:set_list("armor", player_inv:get_list("sarmor")) -- copy
			player_inv:set_list("sarmor", {}) -- clear
			armor:set_player_armor(player) -- refresh
		end
	end

	if bags_inv then
		for bag = 1, 4 do -- return bag contents
			if not player_inv:is_empty("sbag"..bag) then -- contents
				player_inv:set_list("bag"..bag, player_inv:get_list("sbag"..bag)) -- copy
				player_inv:set_list("sbag"..bag, {}) -- clear
			end
		end
	end

	-- as the function is only called when returning a player to normal
	-- reinstate the privileges from the cache
	local privs = gamehub.privs[name]
	if privs then -- contents
		minetest.set_player_privs(name, privs) -- copy
	else
		minetest.log("error", table.concat({"gamehub.player_restore() ",name,
		" is missing from priv cache!"}))
	end
	toggle_hud(player)
end

-- Enter a subgame, called on login!
-- @param name; player name
-- @param game; name of the game
-- @return nothing
local enter_game = function(name, game)
	-- refuse jailed players.
	if gamehub.jail[name] then
		return
	end

	-- localise player obj
	local player = minetest.get_player_by_name(name)

	-- ensure player is present
	if not player then return end

	local pd = gamehub.player[name] -- player data
	local gd = gamehub.game[game] -- game data

	if pd.game == "world" then

		if not gamehub.privs[name].hub_mod then
			-- process normal player
			inventory_clear(player)
			-- players[name].last_action = minetest.get_gametime()
			minetest.set_player_privs(name, gd.privs)
			toggle_hud(player)
			set_nametag(player, {a=255,r=57,g=255,b=20})
		end

		pd.counters[game] = (pd.counters[game] or 0) -- initialise

		gamehub.tmr[name] = minetest.get_us_time() -- timestamp

		-- update current pos details
		gamehub.player[name].pos = vector.round(player:get_pos())
		gamehub.player[name].facing.h = player:get_look_horizontal()
		gamehub.player[name].facing.v = player:get_look_vertical()

	end

	tp(player, game)

	-- update
	gamehub.game[game].played = gd.played + 1

	dirty[game] = dirty[game] or {}
	dirty[game].played = true

	-- log event
	minetest.log("action", table.concat({name,"entered",game}, " "))
end

-- Load a player from the db, initialising if reqd
-- @param name: player name
-- @return nothing
local load_player = function(name)

	local r = gamehub.load_player(name)
	if r then
		-- split privs from player data
		gamehub.player[name] = r
		gamehub.privs[name] = r.privs
		gamehub.player[name].privs = nil
	else
		gamehub.new_player(name)
	end

	-- load players bank account
	gamehub.load_bank_account(name)
	if not gamehub.bank[name] then
		gamehub.new_bank_account(name)
	end

	-- check if timestamp is reqd
	if gamehub.player[name].game ~= "world" then
		gamehub.tmr[name] = minetest.get_us_time() -- timestamp
	end
end

-- Fetch a form context, initialising if reqd
-- @param name: player name
-- @return current state as a table
local get_context = function(name)

	local state = context[name]

	if not state then
		state = {index = -1}
		context[name] = state
	end

	return state
end

-- check if stats needs initialising
if not gamehub.stats then
	gamehub.stats = {}
	gamehub.new_stats_data()
end

-- Check node timers, initialising if reqd
-- @return nothing
local function check_node_timers()
	for k,v in pairs(gamehub.game) do
		local rpad = v.data.rpad
		local stages = v.data.stages
		if rpad and rpad.pos then
			local tmr = minetest.get_node_timer(rpad.pos)
			if not tmr:is_started() then
				tmr:start(1)
			end
		end
		if stages then
			for i,stage in ipairs(stages) do
				local tmr = minetest.get_node_timer(stage.pos)
				if not tmr:is_started() then
					tmr:start(1)
				end
			end
		end
	end
end

-- check node timers are all running after loading all mods
minetest.after(0, check_node_timers)

-- Custom sort function
-- @param a: first list element
-- @param b: second list element
-- @return true if first element comes before second in final order
local function mysort(a, b)
	return a.time < b.time
end

--[[
--------------
	Timers
--------------
]]

-- Update players hud
-- @return nothing
local function p_hud()

	for k,v in pairs(gamehub.player) do

		local player = minetest.get_player_by_name(k)
		local active = hud[k]

		if v.game ~= "world" then

			local g = gamehub.game[v.game]
			local len = v.game:len() + 8
			local limit = g.reward * g.cap
			local gtext = ([[
				%s Info:
				  Pays: %s
				  Limit: %s
				  Plays: %s
				  Wins: %s
			]]):format(v.game, g.reward, limit, g.played, g.completed)

			if active then
				player:hud_change(active.gtext, "text", gtext)
			else
				local mply = 1
				if len > 17 then
					mply = mply + (len-10) * 0.05
				end
				hud[k] = {}
				hud[k].bg = player:hud_add({
					hud_elem_type = "image",
					name = "bg",
					text = "hub_bg.png",
					scale = {x=(1 * mply), y=1},
					position = {x=0.815 + (mply-1), y=0.285},
					alignment = {x=0, y=0},
					offset = {x=0, y=0}
				})
				hud[k].gtext = player:hud_add({
							hud_elem_type = "text",
							name = "g_hud",
							scale = {x=100, y=100},
							text = gtext,
							number = 0x00FF00,
							position = {x=0.8, y=0.3},
							alignment = {x=0, y=0},
							offset = {x=0, y=0}
				})
			end
		elseif active then
			-- cleanup
			player:hud_remove(active.gtext)
			player:hud_remove(active.bg)
			hud[k] = nil
		end
	end

	minetest.after(1, p_hud)
end
p_hud() -- start

-- Check for dirty game data & save
-- @return nothing
local function save_tmr()

	local k, v = next(dirty)

	if k and v then
		if v.played then
			gamehub.update_game_played(k)
		end
		if v.completed then
			gamehub.update_game_completed(k)
		end
		if v.stats then
			gamehub.update_stats()
		end

		dirty[k] = nil
	end

	minetest.after(15, save_tmr)
end
save_tmr() -- start

if not playerplus then
	-- hurt players near cactus
	local function player_tmr()
		local pos, near
		for _,player in ipairs(minetest.get_connected_players()) do

			pos = player:get_pos()
			near = minetest.find_node_near(pos, 1, "default:cactus")

			if near then
				for _,obj in ipairs(minetest.get_objects_inside_radius(near, 1.1)) do
					if obj:is_player() and obj:get_hp() > 0 then
						obj:set_hp(obj:get_hp() - 2)
					end
				end
			end

		end
		minetest.after(1, player_tmr)
	end
	player_tmr()
end

--[[
-----------------------------
	API
-----------------------------
]]

-- Process player game time for leaderboard
-- @param name: player name string
-- @returns nothing
gamehub.process_stats = function(name)

	local input = gamehub.tmr[name]

	if not input then
		minetest.log("warning", name .. " doesn't have a registered timer!")
		return
	end

	local result = (minetest.get_us_time() - input ) / 1000000
	local game = gamehub.player[name].game
	local gstat = gamehub.stats[game] or {}

	if #gstat < HSMD or result < gstat[#gstat].time then

		local record = {
			name = name,
			time = result,
			date = os.time()
		}

		table.insert(gstat, record)
		if #gstat > 1 then
			table.sort(gstat, mysort)
		end
		if #gstat > HSMD then
			table.remove(gstat, #gstat)
		end

		gamehub.stats[game] = gstat

		dirty[game] = dirty[game] or {}
		dirty[game].stats = true

	end

	gamehub.tmr[name] = nil -- cleanup
end

-- Reward player on game completion
-- @param name: player name
-- @param game: game player completed
-- @return nothing
gamehub.player_reward = function(name, game)

	local limit = gamehub.game[game].cap
	local reward = gamehub.game[game].reward
	local counters = gamehub.player[name].counters[game] or 0
	local msg

	-- cache
	gamehub.game[game].completed = gamehub.game[game].completed + 1

	-- set dirty flag
	dirty[game] = dirty[game] or {}
	dirty[game].completed = true

	-- limit check
	if counters >= limit then
		msg = name .. " completed " .. game
	else
		-- increment
		counters = counters + 1
		gamehub.player[name].counters[game] = counters

		-- add reward
		gamehub.bank[name].coins = gamehub.bank[name].coins + reward

		msg = name .. " was rewarded for finishing " .. game

		minetest.sound_play("shop_pay", {
			to_player = name,
			gain = 0.2,
			loop = false
		})
	end
	-- broadcast
	minetest.chat_send_all(msg)
end

-- Enter normal mode
-- @param name: player name
-- @return nothing
gamehub.enter_world = function(name)

	-- return players normal privs, position and inventory
	local player = minetest.get_player_by_name(name)
	local old_game = gamehub.player[name].game

	tp(player, "world")

	minetest.log("action", table.concat({name, " exited ", old_game}))

	if not gamehub.privs[name].hub_mod then
		minetest.set_player_privs(name, gamehub.privs[name])
		set_nametag(player, {a=255,r=255,g=255,b=255})
		inventory_restore(player)
	end
end

-- Construct game menu formspec
-- @param name: player name
-- @return formspec string
gamehub.get_menu_formspec = function(name)

	local fs = get_context(name)
	local list = {}
	local bgimg = ""

	-- create an ipair copy
	for k,v in pairs(gamehub.game) do
		if v.active == true then
			list[#list+1] = v
		end
	end

	if #list > 0 and not fs.list then
		context[name].list = list
		fs = get_context(name)
	end

	if default and default.gui_bg_img then
		bgimg = default.gui_bg_img
	end

	local f = {"size[8,5.5]"}
	f[#f+1] = bgimg
	f[#f+1] = "label[0,0;Games Menu]"

	-- contents?
	if #list > 0 then
		f[#f+1] = "textlist[0,0.5;3,5;games;"
		for _,v in ipairs(list) do
			f[#f+1] = v.name
			f[#f+1] = ","
		end
		f[#f] = ";" -- replace last comma
		f[#f+1] = fs.index
		f[#f+1] = "]" -- finalise textlist
		-- content?
		if fs.index > 0 then
			f[#f+1] = "textarea[3.5,0.4;5,4;;Info:;"
			f[#f+1] = "Author: "
			f[#f+1] = list[fs.index].author
			f[#f+1] = "\n"
			f[#f+1] = "Credits: "
			f[#f+1] = list[fs.index].credits
			f[#f+1] = "\n"
			f[#f+1] = "Type: "
			f[#f+1] = list[fs.index].type
			f[#f+1] = "\n"
			f[#f+1] = "Description: "
			f[#f+1] = list[fs.index].description
			f[#f+1] = "\n"
			f[#f+1] = "]"
			f[#f+1] = "button_exit[3.3,4.9;1.5,0.5;play;Play]"
		end

	else
		f[#f+1] = "textarea[3.5,0.4;3.2,4;;Info:;No games have been added yet]"
	end
	f[#f+1] = "button_exit[5,4.9;1.5,0.5;quit;Close]"

	return table.concat(f)
end

-- Construct add game formspec
-- @param name: player name
-- @return formspec string
gamehub.get_add_formspec = function(name)

	local f = {"size[8.5,7]"}
	f[#f+1] = "field[0.5,-0.9;3,0.5;game;Game;"..name.."]"
	f[#f+1] = "field[0.5,0.9;3,0.5;author;Author;]"
	f[#f+1] = "textarea[0.5,1.7;6,1;credits;Credits:;]"
	f[#f+1] = "textarea[0.5,3;6,1.5;desc;Description:;]"
	f[#f+1] = "textarea[0.5,4.8;6,1;privs;Privileges:;interact,shout]"
	f[#f+1] = "textarea[0.5,6.2;6,1;items;Items:;]"
	f[#f+1] = "label[6.5,0;Type:]"
	f[#f+1] = "label[6.5,1.35;Active:]"
	f[#f+1] = "field[6.8,3.5;1.5,0.5;reward;Reward;]"
	f[#f+1] = "field[6.8,4.7;1.5,0.5;cap;Limit;]"
	f[#f+1] = "dropdown[6.5,0.5;1.5;type;puzzle,parkour,dropper,combo,pvp;1]"
	f[#f+1] = "dropdown[6.5,1.8;1.5;active;false,true;1]"
	f[#f+1] = "button_exit[6.5,6.15;2,1;save;Save]"

	return table.concat(f)
end

-- Construct edit game formspec
-- @param name: player name
-- @return formspec string
gamehub.get_edit_formspec = function(param)

	local type = {"puzzle","parkour","dropper","combo","pvp"}
	local t_select, a_select
	for i,v in ipairs(type) do
		if v == gamehub.game[param].type then
			t_select = i
		end
	end

	a_select = 1
	if gamehub.game[param].active == true then
		a_select = 2
	end

	local reward, cap
	reward = gamehub.game[param].reward or 0
	cap = gamehub.game[param].cap or 0
	local priv_string = minetest.privs_to_string(gamehub.game[param].privs)
	local f = {"size[8.5,7]"}
	f[#f+1] = "field[0.5,-1;3,0.5;game;Game;"
	f[#f+1] = gamehub.game[param].name
	f[#f+1] = "]"
	f[#f+1] = "field[0.5,0.9;3,0.5;author;Author;"
	f[#f+1] = gamehub.game[param].author
	f[#f+1] = "]"
	f[#f+1] = "textarea[0.5,1.7;6,1;credits;Credits:;"
	f[#f+1] = gamehub.game[param].credits
	f[#f+1] = "]"
	f[#f+1] = "textarea[0.5,3;6,1.5;desc;Description:;"
	f[#f+1] = gamehub.game[param].description
	f[#f+1] = "]"
	f[#f+1] = "textarea[0.5,4.8;6,1;privs;Privileges:;"
	f[#f+1] = priv_string
	f[#f+1] = "]"
	f[#f+1] = "textarea[0.5,6.2;6,1;items;Items:;"
	f[#f+1] = gamehub.game[param].items
	f[#f+1] = "]"
	f[#f+1] = "label[6.5,0;Type:]"
	f[#f+1] = "dropdown[6.5,0.5;1.5;type;puzzle,parkour,dropper,combo,pvp;"
	f[#f+1] = t_select
	f[#f+1] = "]"
	f[#f+1] = "label[6.5,1.35;Active:]"
	f[#f+1] = "dropdown[6.5,1.8;1.5;active;false,true;"
	f[#f+1] = a_select
	f[#f+1] = "]"
	f[#f+1] = "field[6.8,3.5;1.5,0.5;reward;Reward;"
	f[#f+1] = reward
	f[#f+1] = "]"
	f[#f+1] = "field[6.8,4.7;1.5,0.5;cap;Limit;"
	f[#f+1] = cap
	f[#f+1] = "]"
	f[#f+1] = "button_exit[6.5,6.15;2,1;save;Save]"

	return table.concat(f)
end

-- Construct stats formspec
-- @param name: player name
-- @return formspec string
gamehub.get_stats_formspec = function(name)

	local fs = get_context(name)

	if fs.index == -1 then fs.index = 1 end

	local list = {}
	local key = {}
	for k,v in pairs(gamehub.stats) do
		key[#key+1] = k
		list[#list+1] =  v
	end

	for i,v in ipairs(list) do
		table.sort(v, mysort)
	end

	local f = {"size[8,7]"}
	f[#f+1] = "label[3,0;High Scores]"
	f[#f+1] = "label[0.45,0.5;Game:]"
	f[#f+1] = "textlist[0.45,1;7,5;stats;"

	if #list > 0 then
		fs.count = #list
		for i,v in ipairs(list[fs.index]) do
			f[#f+1] = i
			f[#f+1] = ".    "
			f[#f+1] = v.name
			local x = 15 - string.len(v.name)
			for y = 1,x do
				f[#f+1] = " "
			end
			f[#f+1] = v.time
			f[#f+1] = " s      "
			f[#f+1] = os.date("%d-%m-%Y %H:%M:%S", v.date)
			f[#f+1] = ","
		end
	else
		f[#f+1] = "No statistics available!"
		f[#f+1] = ","
	end

	f[#f] = ";" -- replace last comma
	f[#f+1] = "-1"
	f[#f+1] = "]" -- finalise textlist

	if #list > 0 then
		f[#f+1] = "label[1.5,0.5;"
		f[#f+1] = key[fs.index]
		f[#f+1] = "]"
	end

	if #list > 1 then
		f[#f+1] = "image_button[6.7,0.5;0.5,0.5;hub_left_icon.png;left;]"
		f[#f+1] = "image_button[7.1,0.5;0.5,0.5;hub_right_icon.png;right;]"
	end

	f[#f+1] = "button_exit[3,6.5;2,0.5;quit;Close]"

	return table.concat(f)
end

-- Find area id by name
-- @param name: area name
-- @return id as integer
gamehub.get_id = function(name)
	for id,area in ipairs(areas.areas) do
		if area.name == name then
			return id
		end
	end
end

-- Find area at position
-- @param pos: vector table
-- @return area, area count
gamehub.area_at_pos = function(pos)

	local areas = areas:getAreasAtPos(pos)
	local ctr = 0
	local result

	for _, area in pairs(areas) do
		if not result then result = area end
		ctr = ctr + 1
	end

	return result, ctr
end

--[[
-----------------------------
CALLBACK REGISTRATIONS
-----------------------------
]]

-- forms
minetest.register_on_player_receive_fields(function(player, formname, fields)

	-- validate, unified inventory uses forms with no formname
	-- additionally we are only interested in our forms!
	if formname == "" or
	formname ~= "hub:add" and
	formname ~= "hub:edit" and
	formname ~= "hub:menu" and
	formname ~= "hub:stats" then
		return
	end

	if formname == "hub:add" then
		-- security check
		local name = player:get_player_name()
		if not gamehub.privs[name].hub_admin then
			minetest.log("warning",
					"[gamehub] Received fields from unauthorized user: "..name)
			return
		end

		-- catch missing reqd fields
		if not fields.save then	return end -- button pressed?
		if not fields.game then	return end -- data?

		-- form fields reqd for new entry
		local pos = vector.round(player:get_pos())
		local res = areas:getAreasAtPos(pos)
		local area, facing

		facing = {
			h = player:get_look_horizontal(),
			v = player:get_look_vertical()
		}

		local _,v = next(res)
		area = v

		if not area then
			minetest.chat_send_player(name, "You must create an area first!")
			return
		end

		-- create record
		local data = {
			name = area.name,
			type = fields.type,
			pos = pos,
			facing = facing,
			reward = tonumber(fields.reward),
			cap = tonumber(fields.cap),
			privs = minetest.string_to_privs(fields.privs),
			author = fields.author,
			credits = fields.credits,
			description = fields.desc,
			created = os.time(),
			played = 0,
			completed = 0,
			items = fields.items,
			active = fields.active == "true",
			data = {
				pos1 = area.pos1,
				pos2 = area.pos2
			}
		}

		gamehub.new_game(data)
		-- add node
		pos.y = pos.y - 1.5
		minetest.set_node(pos, {name="default:cloud"})

		-- inform player of status
		minetest.chat_send_player(name, data.name ..
		" position set at " .. minetest.pos_to_string(pos))
	elseif formname == "hub:edit" then

		-- security check
		local name = player:get_player_name()
		if not gamehub.privs[name].hub_admin then
			minetest.log("warning",
					"[gamehub] Received fields from unauthorized user: "..name)
			return
		end

		if not fields.save then	return end -- button pressed?

		local game = gamehub.game[fields.game]

		game.type = fields.type
		game.privs = fields.privs
		game.author = fields.author
		game.credits = fields.credits
		game.description = fields.desc
		game.reward = tonumber(fields.reward)
		game.cap = tonumber(fields.cap)
		game.items = fields.items
		game.active = fields.active == "true"

		if not game.data.pos1 then

			local id = gamehub.get_id(game.name)
			local area = areas.areas[id]

			game.data = {
				pos1 = area.pos1,
				pos2 = area.pos2
			}

		end

		gamehub.game[fields.game] = game

		gamehub.update_game_form(game)
	elseif formname == "hub:menu" then
		local name = player:get_player_name()
		local fs = get_context(name)
		local ev = minetest.explode_textlist_event(fields.games)
		if ev.type == "CHG" or ev.type == "DCL" then
			-- update
			fs.index = ev.index
			minetest.show_formspec(name, "hub:menu", gamehub.get_menu_formspec(name))
		end
		if fields.play then
			enter_game(name, fs.list[fs.index].name)
		end
	elseif formname == "hub:stats" then
		local name = player:get_player_name()
		local fs = get_context(name)
		if fields.left then
			if fs.index == 1 then
				fs.index = fs.count -- loop
			else
				fs.index = fs.index - 1
			end
		elseif fields.right then
			if fs.index == fs.count then
				fs.index = 1 -- loop
			else
				fs.index = fs.index + 1
			end
		elseif fields.quit then
				return
		end
		minetest.show_formspec(name, "hub:stats", gamehub.get_stats_formspec(name))
	end

	return true -- return handled
end)

--load
minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	load_player(name)
	tp(player, gamehub.player[name].game)
end)

-- unload
minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	-- save
	gamehub.update_on_leaveplayer(player)
	gamehub.update_bank_account(name)
	-- cleanup
	gamehub.player[name] = nil
	gamehub.privs[name] = nil
end)

-- respawn
minetest.register_on_respawnplayer(function(player)

	if not player then return true end

	local name = player:get_player_name()

	--handle jailed players
	if gamehub.jail.roll[name] then return end

	if gamehub.player[name] then
		local game = gamehub.player[name].game
		-- reset player position
		tp(player, game)
		-- reset health
		player:set_hp(20)
		if game ~= 'world' and not gamehub.privs[name].hub_mod then
			--reset players game timestamp
			gamehub.tmr[name] = minetest.get_us_time()
		end
		return true -- return as handled
	end
end)
