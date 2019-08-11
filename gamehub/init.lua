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

-- globals
gamehub = {}
gamehub.game = {} -- game cache
gamehub.privs = {} -- priv cache
gamehub.player = {} -- player cache
gamehub.shop = {} -- item cache
gamehub.settings = {} -- settings cache
gamehub.bank = {} -- bank accounts cache
gamehub.jail = {} -- jail API
gamehub.jail.roll = {} -- jailed player cache
gamehub.tmr = {}

-- request an insecure enviroment
local ie = minetest.request_insecure_environment()

-- catch inaccessible insecure environment
if not ie then
	error("insecure environment inaccessible\n"..
		" - make sure gamehub has been added to the conf file for this server!")
end

-- temp globals
gamehub.sql = ie.require("lsqlite3")
gamehub.ie = ie

-- privs registered by this mod
minetest.register_privilege("hub_mod", "Hub moderator")
minetest.register_privilege("hub_admin", "Hub administrator")
minetest.register_privilege("jailer", "Jail moderator")

local MP = minetest.get_modpath(minetest.get_current_modname())

-- Logo
print('                            .__         ___.    ')
print('   _________    _____   ____|  |__ ___ _\\_ |__  ')
print('  / ___\\__  \\  /     \\_/ __ \\  |  \\   |  \\  __ \\ ')
print(' / /_/  > __ \\_  Y Y  \\  ___/   Y  \\  |  /  \\_\\ \\')
print(' \\___  (____  /__|_|  /\\___  >__|  /____/| ___  /')
print('/_____/     \\/      \\/     \\/    \\/           \\/ ')

-- Process mods files
dofile(MP.."/sql.lua")
dofile(MP.."/functions.lua")
dofile(MP.."/nodes.lua")
dofile(MP.."/commands.lua")
dofile(MP.."/extender.lua")

-- remove temp globals
gamehub.sql = nil
gamehub.ie = nil

-- secure this instance of sqlite3
sqlite3 = nil -- luacheck: ignore sqlite3
