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

local ie = gamehub.ie
local MP = minetest.get_modpath(minetest.get_current_modname())
local WP = minetest.get_worldpath()

-----------------------
-- Helper Functions  --
-----------------------

-- Grant command handler
-- @param caller: player executing the command
-- @param grant_name: player name receiving privs
-- @param grant_priv_str: privileges string
-- @return bool & message
local function handle_grant_command(caller, grant_name, grant_priv_str)

	local caller_privs = minetest.get_player_privs(caller)

	if not (caller_privs.privs or caller_privs.basic_privs) then
		return false, "Your privileges are insufficient."
	end

	if not minetest.get_auth_handler().get_auth(grant_name) then
		return false, "Player " .. grant_name .. " does not exist."
	end

	local grantprivs = minetest.string_to_privs(grant_priv_str)
	local privs = minetest.get_player_privs(grant_name)
	local privs_unknown = ""
	local basic_privs = minetest.string_to_privs(
		minetest.settings:get("basic_privs") or "interact,shout")

	if grant_priv_str == "all" then
		grantprivs = minetest.registered_privileges
	end

	for priv, _ in pairs(grantprivs) do
		if not basic_privs[priv] and
		not minetest.check_player_privs(caller, {privs=true}) then
			return true, "Your privileges are insufficient."
		end
		if not minetest.registered_privileges[priv] then
			privs_unknown = privs_unknown .. "Unknown privilege: " .. priv .. "\n"
		end
		privs[priv] = true
	end

	if privs_unknown ~= "" then
	return false, privs_unknown
	end

	if not gamehub.player[grant_name] then
		gamehub.load_player(grant_name)
		if gamehub.player[grant_name] then
			gamehub.update_player_field(grant_name, "privs", privs)
			gamehub.player[grant_name] = nil
			minetest.log("action", caller..
		    ' granted ('..grant_priv_str..
		    ') privileges to '..grant_name)
			return true, "Privileges of " .. grant_name .. ": "
		      .. minetest.privs_to_string(privs, ', ')
		else
			return false, "No record for "..grant_name
		end
	end

	gamehub.privs[grant_name] = privs
	gamehub.update_player_field(grant_name, "privs") -- backup

	if gamehub.player[grant_name].game == "world" then
		minetest.set_player_privs(grant_name, privs) -- set the privileges
	end

	minetest.log("action", caller..
	' granted ('..minetest.privs_to_string(grantprivs, ', ')..
	') privileges to '..grant_name)

	if grant_name ~= caller then
		minetest.chat_send_player(grant_name, caller
		    .. " granted you privileges: "
		    .. minetest.privs_to_string(grantprivs, ' '))
	end
	return true, "Privileges of " .. grant_name .. ": "
	.. minetest.privs_to_string(
	  minetest.get_player_privs(grant_name), ' ')
end

-- Revoke command handler
-- @param caller: player executing the command
-- @param revoke_name: player name losing privs
-- @param revoke_priv_str: privileges string
-- @return bool & message
local function handle_revoke_command(caller, revoke_name, revoke_priv_str)

	local caller_privs = minetest.get_player_privs(caller)

	if not (caller_privs.privs or caller_privs.basic_privs) then
		return false, "Your privileges are insufficient."
	end

	if not minetest.get_auth_handler().get_auth(revoke_name) then
		return false, "Player " .. revoke_name .. " does not exist."
	end

	local revoke_privs = minetest.string_to_privs(revoke_priv_str)
	local privs = minetest.get_player_privs(revoke_name)
	local basic_privs = minetest.string_to_privs(
		minetest.settings:get("basic_privs") or "interact,shout")
	for priv, _ in pairs(revoke_privs) do
		if not basic_privs[priv] and
				not minetest.check_player_privs(caller, {privs=true}) then
			return true, "Your privileges are insufficient."
		end
	end
	if revoke_priv_str == "all" then
		privs = {}
	else
		for priv, _ in pairs(revoke_privs) do
			privs[priv] = nil
		end
	end
	minetest.set_player_privs(revoke_name, privs)

	gamehub.privs[revoke_name] = privs
	gamehub.update_player_field(revoke_name, "privs")

	minetest.log("action", caller..' revoked ('
			..minetest.privs_to_string(revoke_privs, ', ')
			..') privileges from '..revoke_name)
	if revoke_name ~= caller then
		minetest.chat_send_player(revoke_name, caller
				.. " revoked privileges from you: "
				.. minetest.privs_to_string(revoke_privs, ' '))
	end
	return true, "Privileges of " .. revoke_name .. ": "
		.. minetest.privs_to_string(
			minetest.get_player_privs(revoke_name), ' ')
end

-- Check path for correct file presence
-- @param path: folder to check
-- @param name: filename without extension
-- @return truth table including count
local check_files = function(path, name)

	local extension, file, err
	local list = {}

	list.n = 0
	extension = {"mts", "we", "hub"}

	for _, entry in ipairs(extension) do

		local filename = path .. name .. "." .. entry

		file, err = ie.io.open(filename, "rb")
		if err then
			list[entry] = false
		else
			file:close()
			list[entry] = true
			list.n = list.n + 1
		end

	end

	return list
end

--------------------
-- Admin Commands --
--------------------

minetest.register_chatcommand("hub", {
	description = 'gamehub management tool',
	params = '{add|del|edit|load|protect|reset|save|stage|unstage} [name|id]',
	func = function(name, param)
		-- secure access
		if not gamehub.privs[name].hub_admin then
			return false, "Insufficient privs!"
		end

		local cmd, helper, list, param2, player

		helper = [[Usage:
		/hub add
		/hub delete <area_id> [true]
		/hub edit <game>
		/hub load <filename>
		/hub protect <area_id> [true]
		/hub save <area_id>
		/hub stage
		/hub unstage <stage_num>
		]]

		list = {}
		player = minetest.get_player_by_name(name)

		if not player then
			return false, "You need to be playing to use this command!"
		end

		for word in param:gmatch("%S+") do
			list[#list+1] = word
		end

		if #list < 1 then return false, helper end

		cmd = list[1]

		if #list == 1 then

			if cmd == 'add' then

				local area, ctr = gamehub.area_at_pos(player:get_pos())

				if not area then
					return false, "You must create an area first!"
				elseif ctr > 1 then
					return false, "Multiple areas detected. Unable to continue!"
				else
					minetest.show_formspec(name, "hub:add", gamehub.get_add_formspec(area.name))
				end

			elseif cmd == 'stage' then

				local pos = vector.round(player:get_pos())
				local facing = {
					h = player:get_look_horizontal(),
					v = player:get_look_vertical()
				}
				local area, ctr = gamehub.area_at_pos(pos)
				if area and ctr == 1 then
					local data = gamehub.game[area.name].data
					local stages = data.stages or {}
					local new_stage = {
						stage = #stages + 1,
						pos = {}, -- set on pad placement
						dest = pos,
						facing = facing
					}

					stages[#stages+1] = new_stage
					data.stages = stages

					gamehub.game[area.name].data = data -- update cache
					gamehub.update_game_field(area.name, "data")

					return true, "Stage " .. #stages + 1 .. " position added to " ..
						area.name .. " data"
				else
					return false, "Multiple areas detected. Unable to continue!"
				end
			else
				-- no matches
				return false, helper
			end

		elseif #list >= 2 then

			if cmd == 'delete' then

				local id = tonumber(list[2])

				if not areas.areas[id] then
					return false, "area id " .. id .. " doesn't exist!"
				end

				local game = areas.areas[id].name
				local msg = game .. " game removed!"

				if list[3] == "true" then

					-- delete area
					local area = areas.areas[id]

					worldedit.set(area.pos1, area.pos2, "air")
					worldedit.clear_objects(area.pos1, area.pos2)
					areas:remove(id, true)
					areas:save()

					msg = msg .. "\nbuild removed!"
				end

				-- remove from db
				gamehub.delete_game(game)

				return true, msg

			elseif cmd == "edit" then

				local game = list[2]
				if #list > 2 then
					game = table.concat(list, " ", 2)
				end
				if not gamehub.game[game] then
					return false, game .. ' does not exist!'
				end

				minetest.show_formspec(name, "hub:edit",
				gamehub.get_edit_formspec(game))

			elseif cmd == 'load' then

				-- flatten list values if reqd
				local new_name
				local old_name = list[2]

				if #list > 2 then
					old_name = table.concat(list, " ", 2)
				end

				if gamehub.game[old_name] then
					for i=1,100 do
						local exists = ([[%s %i]]):format(old_name, i)
						if not gamehub.game[exists] then
							new_name = exists
							break
						end
					end
				end

				-- last entry takes precedence
				local folders = {
					MP .. "/schems/",
					WP .. "/schems/"
				}

				local path, folder, file, err, msg
				msg = {}
				for i,v in ipairs(folders) do

					local check = check_files(v, old_name)

					if check.n == 3 then

						folder = v
						msg[#msg+1] = "file set found in " .. v

					elseif check.n > 0 then

						for k,val in pairs(check) do
							if val then
								msg[#msg+1] = v.."."..k.." found..."
							else
								msg[#msg+1] = v.."."..k.." missing!"
							end
						end
					elseif check.n == 0 then
						msg[#msg + 1] = "no files found in " .. v
					end

					minetest.chat_send_player(name,	table.concat(msg, "\n"))

					check.n = nil -- reset

				end

				if not folder then return end

				path = folder .. old_name .. ".mts"

				-- add mts using player current pos
				local pos1 = vector.round(player:get_pos())

				err = minetest.place_schematic(pos1, path, nil, nil, true)

				if err == nil then
					minetest.chat_send_player(name,	"could not open file " .. path)
					return
				end

				-- add nodes with metadata
				path = folder .. old_name .. ".we"
				file, err = ie.io.open(path, "rb")

				if err then
					minetest.chat_send_player(name,	"could not open file "
					.. old_name .. ".we")
					return
				end

				local value = file:read("*a")
				file:close()

				local count = worldedit.deserialize(pos1, value)

				minetest.chat_send_player(name, "replaced " .. count ..
				" nodes...")

				-- load game file
				path = folder .. old_name .. ".hub"
				file, err = ie.io.open(path, "rb")

				if err then
					minetest.chat_send_player(name,	"could not open file "..
					old_name..".hub")
					return
				end

				value = file:read("*a")
				file:close()

				local game = minetest.deserialize(value)

				-- add new area
				-- use distance vector to calculate second position
				local dist = vector.subtract(game.data.pos2, game.data.pos1)
				local pos2 = vector.add(pos1, dist)
				local game_name = new_name or game.name
				areas:add(name, game_name, pos1, pos2, nil)

				areas:save()

				-- modify game data

				-- stages
				local stages = game.data.stages or {}

				for i, stage in ipairs(stages) do
					-- modify vectors
					local pos

					dist = vector.subtract(stage.pos, game.data.pos1)
					pos = vector.add(pos1, dist)
					stage.pos = pos

					dist = vector.subtract(stage.dest, game.data.pos1)
					pos = vector.add(pos1, dist)
					stage.dest = pos

					stages[i] = stage
					minetest.get_node_timer(stage.pos):start(1.0) -- init

				end

				game.data.stages = stages

				-- reward pad
				if game.data.rpad and game.data.rpad.pos then
					-- modify vector
					dist = vector.subtract(game.data.rpad.pos, game.data.pos1)
					game.data.rpad.pos = vector.add(pos1, dist)
					minetest.get_node_timer(game.data.rpad.pos):start(1.0) -- init
				end

				if new_name then
					-- change reward pad meta
					local meta = minetest.get_meta(game.data.rpad.pos)
					meta:set_string("game", game_name)
					meta:set_string("infotext",	"Step on pad to complete ".. game_name)
				end

				-- start vector
				dist = vector.subtract(game.pos, game.data.pos1)
				game.pos = vector.add(pos1, dist)
				game.name = game_name
				game.data.pos1 = pos1
				game.data.pos2 = pos2
				game.played = 0
				game.completed = 0

				-- create new record
				gamehub.new_game(game)

			elseif cmd == 'protect' then

				local id = tonumber(list[2])

				if not areas.areas[id] then
					return false, "area id " .. id .. " doesn't exist!"
				end

				-- optional clear param
				if #list == 3 then
					-- convert to bool
					param2 = list[3] == 'true'
				end

				local count, msg = gamehub.protect(id, param2)

				return true, msg .. id .. "\nadded " .. count .. " nodes"

			elseif cmd == 'save' then

				local id = tonumber(list[2])

				if not id or not areas.areas[id] then
					return false, "area id " .. id .. " does not exist!"
				end

				local area = areas.areas[id]

				-- serialize metadata
				local result, count = gamehub.serialize_meta(area.pos1, area.pos2)

				local path = WP .. "/schems"
				local filename = path .. "/" .. area.name .. ".we"
				local file, err = ie.io.open(filename, "wb")

				if err ~= nil then
					minetest.log(name, "Could not save file to \"" .. filename .. "\"")
					return
				end

				file:write(result)
				file:flush()
				file:close()

				minetest.chat_send_player(name, "Saved " .. count ..
				" nodes to \"" .. filename .. "\"")

				-- create schematic
				filename = path .. "/" .. area.name .. ".mts"
				minetest.create_schematic(area.pos1, area.pos2, nil, filename)

				minetest.chat_send_player(name, "Saved \"" .. filename .. "\"")

				-- create serialized db entry file
				local data = gamehub.game[area.name]

				data = minetest.serialize(data)

				filename = path .. "/" .. area.name .. ".hub"
				file, err = io.open(filename, "wb")

				if err ~= nil then
					minetest.log(name, "Could not save file to \"" .. filename .. "\"")
					return
				end

				file:write(data)
				file:flush()
				file:close()

				minetest.chat_send_player(name, "Saved \"" .. filename .. "\"")

			elseif cmd == 'unstage' then

				local num = tonumber(list[2])
				local stages, data, fresh, msg
				local area, ctr = gamehub.area_at_pos(pos)
				if area and ctr == 1 then
					data = gamehub.game[area.name].data
					stages = data.stages
					fresh = {}
					msg = "error: stage " .. num .. " doesn't exist"

					for i,stage in ipairs(stages) do
						-- rebuild table
						if stage.stage ~= num then
							table.insert(fresh, stage)
						else
							msg = ("stage %i removed!"):format(i)
						end
					end

					data.stages = fresh
					gamehub.game[area.name].data = data
					gamehub.update_game_field(area.name, "data")
					return true, msg

				else
					return true, "Multiple areas detected. Unable to continue!"
				end
			else
				return true, helper
			end
		end
	end,
})

------------------------
-- Moderator Commands --
------------------------

-- list player gamehub info
minetest.register_chatcommand("info", {
    description = 'List players game (moderator only)',
    params = "<name>",
    func = function(name, param)

		if not gamehub.privs[name].hub_mod then
			return false, "Insufficient privs!"
		end
      -- use invoker for missing param
      if param == "" then
        param = name
      end

      local player_data = gamehub.player[param]

      if player_data == nil then
		-- try to load player from db
        player_data = gamehub.load_player(param)
      end

      if player_data and player_data.game then
        return true, param.." is playing "..player_data.game
      else
        return true, "player isn't registered!"
      end

    end,
  })

-- replace default revoke/grant privileges commands
minetest.override_chatcommand("revoke", {
	params = "<name> (<privilege> | all)",
	description = "Remove privilege from player",
	privs = {privs=true},
	func = function(name, param)
		local revoke_name, revoke_priv_str = string.match(param, "([^ ]+) (.+)")
		if not revoke_name or not revoke_priv_str then
			return true, "Invalid parameters (see /help revoke)"
		elseif not minetest.get_auth_handler().get_auth(revoke_name) then
			return true, "Player " .. revoke_name .. " does not exist."
		end
		return handle_revoke_command(name, revoke_name, revoke_priv_str)
	end,
  }
)

minetest.override_chatcommand("grant", {
    params = "<name> (<privilege> | all)",
    description = "Give privilege to player",
    func = function(name, param)
		local grant_name, grant_priv_str = string.match(param, "([^ ]+) (.+)")
		if not grant_name or not grant_priv_str then
			return false, "Invalid parameters (Usage: /hub_grant <player> <privs>)"
		end
		return handle_grant_command(name, grant_name, grant_priv_str)
    end,
  }
)

---------------------
-- Player Commands --
---------------------

-- show game menu command
minetest.register_chatcommand("p", {
    description = 'Show game menu to player',
    params = "<player>",
	privs = {shout=true},
    func = function(name, param)

		if gamehub.jail[name] then
			return true, "Access Denied!"
		end

		local privs = gamehub.privs[name]
		local target = name

		if privs.hub_mod and param ~= "" and gamehub.player[param] then
			target = param -- reassign
		end

		-- show form
		minetest.show_formspec(target, "hub:menu",
			gamehub.get_menu_formspec(target))

    end,
})

-- exit a subgame
minetest.register_chatcommand("q", {
    description = 'quit current game',
    params = "<player>",
	privs = {shout=true},
    func = function(name, param)

		if gamehub.jail[name] then
			return true, "Access Denied!"
		end

		local privs = gamehub.privs[name]
		local target = name

		if privs.hub_mod and param ~= "" then
			target = param
		end

		if gamehub.player[target].game ~= "world" then
			gamehub.enter_world(target)
			return true, target .. " returned to the world"
		end
    end,
})

-- show league table
minetest.register_chatcommand("s", {
	description = 'view fastest player ranks',
	privs = {shout=true},
    func = function(name, param)

		if gamehub.jail[name] then
			return true, "Access Denied!"
		end

		local privs = gamehub.privs[name]
		local target = name

		if privs.hub_mod and param ~= "" and gamehub.player[param] then
			target = param -- reassign
		end
		minetest.show_formspec(target, "hub:stats",
			gamehub.get_stats_formspec(target))
	end
})
