--[[

jail mod (C) shivajiva101@hotmail.com 2019

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

local target, mode
local filename = minetest.get_modpath("jail") .. "/schems/jail.mts"
local t_units = {
	s = 1, S=1, m = 60, h = 3600, H = 3600,
	d = 86400, D = 86400, w = 604800, W = 604800,
	M = 2592000, y = 31104000, Y = 31104000, [""] = 1
}

jail = {}

-- Insert physical jail if not present
if not gamehub.settings.jail then
	minetest.after(5, function()
		local pos = minetest.setting_get_pos("jail") or {x=0,y=-1000,z=0}
		minetest.place_schematic(pos, filename, nil, nil, true)
		gamehub.settings.jail = {x=7,y=-998,z=7}
		gamehub.new_settings_data()
	end)
end

-- Jailer entity registration
minetest.register_entity("jail:jailer", {
	physical = true,
	collisionbox = {-0.01,-0.01,-0.01, 0.01,0.01,0.01},
	visual = "sprite",
	visual_size = {x=0, y=0},
	textures = {"jailer.png"},
	is_visible = false,
	makes_footstep_sound = false,
	on_activate = function(self, staticdata)
		self.object:set_armor_groups({immortal = 1})
		if not target or not mode or self.trapped then return end
		local prisoner = minetest.get_player_by_name(target)
		if not prisoner then return end
		if mode == "attach" then
			prisoner:set_attach(self.object, "", {x=0,y=0,z=0}, {x=0,y=0,z=0})
			self.trapped = target
			minetest.sound_play("jail_door", {
				to_player = target,
				gain = 0.2,
				loop = false
			})
			target, mode = nil, nil
		end
	end,
	on_step = function(self,dtime)
		if not target or not mode then return end
		if mode == "detach" and target == self.trapped then
			local player = minetest.get_player_by_name(target)
			if not player then return end
			player:set_detach()
			gamehub.jail.delete_record(target)
			minetest.log("action", target.." released from jail!")
			minetest.chat_send_all("NEWSFLASH..." .. target ..
				" has been released from jail!")
			-- initiate action before removing object
			minetest.after(0.2, gamehub.enter_world, target)
			target, mode = nil, nil
			self.object:remove()
		end
	end,
})

--[[
-----------------------------
Internal Functions
-----------------------------
]]

-- Initialises player target
-- @param name: player name string
-- @param mode: attach or detach string
local function target_player(name, mode_string)
	target = name
	mode = mode_string
end


-- Convert UTC to a readable format
-- @param t: UTC integer
-- @return formatted string
local function hrdf(t)
	if type(t) == "number" then
		return (t and os.date("%c", t))
	end
end


-- Parse duration string converting to seconds
-- @param str: duration string
-- @return seconds integer
local parse_time = function(str)
	local s = 0
	for n, u in str:gmatch("(%d+)([smhdwyDMY]?)") do
		s = s + (tonumber(n) * (t_units[u] or 1))
	end
	return s
end

-- Preprocess attachment event
-- @param name: player name
-- @return nothing
local attach = function(name)

	minetest.set_player_privs(name, {})
	target_player(name, "attach")

	local player = minetest.get_player_by_name(name)
	-- minimise stacking
	local adj = math.random(-2,2)
	local pos = gamehub.settings.jail

	pos.x = pos.x + adj
	pos.z = pos.z + adj
	pos.y = pos.y + 0.5

	player:set_pos(pos)

	minetest.add_entity(pos, "jail:jailer")
end

-- Preprocess detachment event
-- @param name: player name
-- @return nothing
local detach = function(name)
	target_player(name, "detach")
end

-- Expiry timer
-- @return nothing
local function tmr()
	local ts = os.time()
	for name,v in pairs(gamehub.jail.roll) do
		if ts >= v.expires then
			local player = minetest.get_player_by_name(name)
			if player then
				detach(name)
			else
				gamehub.jail.delete_record(name)
				minetest.chat_send_all("Notice: " .. name ..
				" was released from jail!")
			end
		end
	end
	minetest.after(60, tmr)
end
tmr() -- start

-----------------------------
---     API Functions     ---
-----------------------------

jail.jail = function(caller, name, duration, reason)

	if not (caller and name and duration and reason) then
		return false, 'missing paramter...'
	elseif gamehub.jail.roll[name] then
		return false, name ..  'is already in jail!'
	elseif name == owner then
		return false, 'Insufficient privileges!'
	end

	duration = parse_time(duration)
	if duration < 60 then
		return false, 'You must jail for > 60 seconds'
	end

	local expires = os.time() + duration

	gamehub.jail.new_record(name, reason, caller, expires)

	if minetest.get_player_by_name(name) then
		attach(name)
	end

	minetest.log('info', name .. ' was jailed by ' .. caller .. ' for '..reason)
	return true, name .. ' was jailed by '..caller..' until ' .. hrdf(expires)
end

jail.unjail = function(caller, name)

	if not gamehub.jail.roll[name] then
		return false, name .. " isn't in jail!"
	end
	local player = minetest.get_player_by_name(name)
	if player then
		detach(name)
	else
		gamehub.jail.delete_record(target)
		minetest.log("action", target.." released from jail by " .. caller)
	end

	return true, name .. ' released from jail'
end

------------------------------
--    Register Callbacks    --
------------------------------

minetest.register_on_joinplayer(function(player)

	local name = player:get_player_name()

	if gamehub.jail.roll[name] then
		if os.time() > gamehub.jail.roll[name].expires then
			gamehub.jail.delete_record(name)
		else
			minetest.after(1, attach, name)
		end
	end
end)

minetest.register_on_leaveplayer(function(player)

	local name = player:get_player_name()

	if gamehub.jail.roll[name] then
		detach(name)
	end
end)

-- respawn
minetest.register_on_respawnplayer(function(player)
	if not player then return true end
	local name = player:get_player_name()
	if gamehub.jail.roll[name] then
		return true -- return as handled
	end
end)
------------------------------
--    Register Commands     --
------------------------------

minetest.register_chatcommand('jail', {
	description = 'jail player',
	params = '<name> <duration> <reason>',
	func = function(name, param)
		-- secure
		if not gamehub.privs[name].hub_mod then
			return false, "Insufficient privs!"
		end

		local pname, duration, reason = param:match("(%S+)%s+(%S+)%s+(.+)")

		if not (pname and duration and reason) then
			return false, "Usage: /jail <player> <time> <reason>"
		elseif gamehub.jail.roll[pname] then
			return false, pname .. " is already in jail!"
		elseif pname == owner then
			-- protect owner account
			return false, "Insufficient privileges!"
		end

		duration = parse_time(duration)
		if duration < 3600 then
			return false, "You must jail for > 60 mins"
		end

		local expires = os.time() + duration

		gamehub.jail.new_record(pname, reason, name, expires)

		if minetest.get_player_by_name(name) then
			attach(pname)
		end

		return true, pname .. " was jailed until " .. hrdf(expires)
	end
})

minetest.register_chatcommand('unjail', {
	params = '<player>',
	description = 'release player from jail',
	func = function(name, param)
		if not gamehub.privs[name].hub_mod then
			return false, 'Insufficient privs!'
		end
		if not param then
			return false, 'Usage: /unjail <player>'
		end

		if not gamehub.jail.roll[param] then
			return false, param ..  "isn't in jail!"
		end

		detach(param)

		return true, param .. ' released from jail'
	end,
})

minetest.register_chatcommand('jail_info', {
	description = 'view jail records',
	func = function(name)
		-- secure
		if not gamehub.privs[name].hub_mod then
			return false, 'Insufficient privs!'
		end

		local info = {}
		for k,v in pairs(gamehub.jail.roll) do
			info[#info+1] =('%s jailed by %s on %s for %s until %s'):format(
			k,v.source,hrdf(v.created),v.reason,hrdf(v.expires))
		end
		if #info == 0 then
			info[#info+1] = 'No jail records found...'
		end
		return true, table.concat(info,"\n")

	end
})

minetest.register_chatcommand('jail_visit', {
	description = 'visit jail',
	func = function(name)
		-- secure
		if not gamehub.privs[name].hub_mod then
			return false, 'Insufficient privs!'
		end

		local player = minetest.get_player_by_name(name)
		player:set_pos(gamehub.settings.jail)
		return true

	end
})
