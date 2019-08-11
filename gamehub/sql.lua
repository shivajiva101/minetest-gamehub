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

-- localise access to the db handler
local _sql = gamehub.sql

-- localise db
local db = _sql.open(minetest.get_worldpath().."/gamehub.sqlite") -- connection

-- Create db:exec wrapper for error reporting
-- @param stmt: sql statement to execute
-- @return nothing
local function db_exec(stmt)
	if db:exec(stmt) ~= _sql.OK then
		minetest.log("error", "[Gamehub] Sqlite ERROR:  " .. db:errcode() ..
		" " .. db:errmsg())
	end
end

---------------------
---   DB TABLES   ---
---------------------

local create_db = [[
CREATE TABLE IF NOT EXISTS game (
    name		VARCHAR PRIMARY KEY,
    type		INTEGER,
    pos			VARCHAR,
    facing		VARCHAR,
    reward		VARCHAR,
    cap			INTEGER,
    privs		VARCHAR,
    author		VARCHAR,
	credits		VARCHAR,
	description	VARCHAR,
    created		INTEGER,
    played		INTEGER,
	completed	INTEGER,
    items		VARCHAR,
    active		BOOLEAN DEFAULT (0),
	data		VARCHAR DEFAULT ('return = {}')
);

CREATE TABLE IF NOT EXISTS player (
	name		VARCHAR PRIMARY KEY,
	game		INTEGER,
	privs		VARCHAR,
	pos			VARCHAR,
	facing		VARCHAR,
	counters	VARCHAR DEFAULT ('return = {}'),
	data		VARCHAR DEFAULT ('return = {}'),
	created		INTEGER
);

CREATE TABLE IF NOT EXISTS bank (
	name		VARCHAR PRIMARY KEY,
	coins		INTEGER,
	created		INTEGER
);

CREATE TABLE IF NOT EXISTS shop (
	item	VARCHAR PRIMARY KEY,
	moq		INTEGER,
	buy		INTEGER,
	sell	INTEGER,
	created	INTEGER
);

CREATE TABLE IF NOT EXISTS jail (
	name	VARCHAR PRIMARY KEY,
	reason	VARCHAR,
	source VARCHAR,
	created	INTEGER,
	expires INTEGER
);

CREATE TABLE IF NOT EXISTS settings (
	data	VARCHAR
);

CREATE TABLE IF NOT EXISTS stats (
	data 	VARCHAR
);
]]

--create tables if reqd
db_exec(create_db)

----------------
--  QUERIES  ---
----------------

-- Loads games into gamehub.game table
-- @return nothing
local function load_games()
	local q = "SELECT * FROM game;"
	for row in db:nrows(q) do
		row.pos = minetest.string_to_pos(row.pos)
		row.facing = minetest.deserialize(row.facing)
		row.privs = minetest.string_to_privs(row.privs)
		row.active = row.active == 1
		row.data = minetest.deserialize(row.data)
		gamehub.game[row.name] = row
	end
end
load_games()

-- Loads shop items into gamehub.shop table
-- @return nothing
local function load_shop()
	local q = "SELECT * FROM shop;"
	for row in db:nrows(q) do
		gamehub.shop[row.item] = row
	end
end
load_shop()

-- Loads jailed players into gamehub.jail.roll table
-- @return nothing
local function load_jail()
	local q = "SELECT * FROM jail;"
	for row in db:nrows(q) do
		gamehub.jail.roll[row.name] = row
	end
end
load_jail()

-- Loads internal settings into gamehub.settings table
-- @return nothing
local function load_settings()
	local q = "SELECT * FROM settings;"
	local it, state = db:nrows(q)
	local row = it(state)
	if row then
		gamehub.settings = minetest.deserialize(row.data)
	end
end
load_settings()

-- Load a players data unpacking as necessary
-- @param name: playes name
-- @return data as table
gamehub.load_player = function(name)
	local q = ([[
	SELECT * from player WHERE name = '%s' LIMIT 1;
	]]):format(name)
	local it, state = db:nrows(q)
	local row = it(state)
	if row then
		-- unpack
		row.pos = minetest.string_to_pos(row.pos)
		row.facing = minetest.deserialize(row.facing)
		row.privs = minetest.string_to_privs(row.privs)
		row.counters = minetest.deserialize(row.counters)
		row.data = minetest.deserialize(row.data)
		return row
	end
end

-- Load a players money into gamehub.bank table
-- @param name: players name
-- @return nothing
gamehub.load_bank_account = function(name)
	local q = ([[
	SELECT * from bank WHERE name = '%s' LIMIT 1;
	]]):format(name)
	local it, state = db:nrows(q)
	local row = it(state)
	if row then
		gamehub.bank[name] = row
	end
end

-- Loads internal settings into gamehub.settings table
-- @return nothing
local function load_stats()
	local q = "SELECT * FROM stats;"
	local it, state = db:nrows(q)
	local row = it(state)
	if row then
		gamehub.stats = minetest.deserialize(row.data)
	end
end
load_stats()

-------------------
---   INSERTS   ---
-------------------

-- Create & cache a new game record
-- @param data: table of params
-- @return nothing
gamehub.new_game = function(data)
	-- prepare data
	local pos_string = minetest.pos_to_string(vector.round(data.pos))
	local facing = minetest.serialize(data.facing)
	local priv_string = minetest.privs_to_string(data.privs)
	local active = 0
	local data_string = minetest.serialize(data.data)

	if data.active then active = 1 end

	local stmt = ([[
			INSERT INTO game (
				name,
				type,
				pos,
				facing,
				reward,
				cap,
				privs,
				author,
				credits,
				description,
				created,
				played,
				completed,
				items,
				active,
				data
			) VALUES ('%s','%s','%s','%s',%i,%i,'%s','%s','%s','%s',
			%i,%i,%i,'%s',%i,'%s');]]):format(data.name,data.type,
			pos_string,facing,data.reward,data.cap,priv_string,data.author,
			data.credits,data.description,data.created,data.played,
			data.completed,data.items,active,data_string)
	db_exec(stmt)
	-- cache
	gamehub.game[data.name] = data
end

-- Create & cache a new shop stock item record
-- @param item: item string
-- @param buy: price the shop pays for the item
-- @param sell: price the shop sells the item for
-- @param moq: minimum qty the player can buy
-- @return nothing
gamehub.new_shop_item = function(item, buy, sell, moq)
	local ts = os.time()
	local stmt = ([[
			INSERT INTO shop (
				item,
				moq,
				buy,
				sell,
				created
			) VALUES ('%s',%i,%i,%i,%i);
			]]):format(item, moq, buy, sell, ts)
	db_exec(stmt)
	-- cache
	gamehub.shop[item] = {
		item = item,
		moq = moq,
		buy = buy,
		sell = sell,
		created = ts
	}
end

-- Create & cache a new player record
-- @param name: players name
-- @return nothing
gamehub.new_player = function(name)
	local ts = os.time()
	local game = "world"
	local privs = minetest.get_player_privs(name)
	local privS = minetest.privs_to_string(privs)
	local player = minetest.get_player_by_name(name)
	local pos = player:get_pos()
	local poS = minetest.pos_to_string(vector.round(pos))
	local facing = {
		h = player:get_look_horizontal(), v = player:get_look_vertical()
	}
	local facinG = minetest.serialize(facing)
	local counters = minetest.serialize({})
	local data = minetest.serialize({})
	local stmt = ([[
			INSERT INTO player (
				name,
				game,
				privs,
				pos,
				facing,
				counters,
				data,
				created
			) VALUES ('%s','%s','%s','%s','%s','%s','%s',%i);
			]]):format(name, game, privS, poS, facinG, counters, data, ts)
	db_exec(stmt)
	-- cache
	gamehub.player[name] = {
		name = name,
		game = game,
		pos = pos,
		facing = facing,
		counters = {},
		data = {},
		created = ts
	}
	gamehub.privs[name] = privs
end

-- Create & cache a new jail record
-- @param name: jailed player name string
-- @param reason: reason string
-- @param source: name string of player creating the record
-- @param expires: expiry time as utc integer
-- @return nothing
gamehub.jail.new_record = function(name, reason, source, expires)
	local ts = os.time()
	local stmt = ([[
		INSERT INTO jail VALUES ('%s','%s','%s',%i,%i)
	]]):format(name, reason, source, ts, expires)
	db_exec(stmt)
	gamehub.jail[name] = {
		name = name,
		reason = reason,
		source = source,
		created = ts,
		expires = expires
	}
end

-- Create & cache a new bank account record
-- @param name: players name
-- @return nothing
gamehub.new_bank_account = function(name)
	local ts = os.time()
	local stmt = ([[
	INSERT INTO bank VALUES ('%s',%i,%i)
	]]):format(name, 100, ts)
	db_exec(stmt)
	gamehub.bank[name] = {
		name=name,
		coins=100,
		created=ts
	}
end

-- Create new settings record
-- @return nothing
gamehub.new_settings_data = function()
	local data = minetest.serialize(gamehub.settings)
	local stmt = ([[
	INSERT INTO settings VALUES ('%s');
	]]):format(data)
	db_exec(stmt)
end

-- Create new stats record
-- @return nothing
gamehub.new_stats_data = function()
	local data = minetest.serialize(gamehub.stats)
	local stmt = ([[
	INSERT INTO stats VALUES ('%s');
	]]):format(data)
	db_exec(stmt)
end

-------------------
---   UPDATES   ---
-------------------

-- Updates a game record field
-- @param name: game name string
-- @param field: field name string
-- @param value: new value
-- @return nothing
gamehub.update_game_field = function(name, field)

	local value = gamehub.game[name][field]

	-- format
	if field == "pos" then
		value = minetest.pos_to_string(vector.round(value))
	elseif field == "privs" then
		value = minetest.privs_to_string(value)
	elseif field == "data" or field == "facing" then
		value = minetest.serialize(value)
	elseif field == "active" and value then
		value = 1
	end
	-- db
	local stmt
	if type(value) == "string" then
		stmt = ([[
		UPDATE game SET %s = '%s' WHERE name = '%s' LIMIT 1;
		]]):format(field, value, name)
	else
		stmt = ([[
		UPDATE game SET %s = %i WHERE name = '%s' LIMIT 1;
		]]):format(field, value, name)
	end

	db_exec(stmt)
end

-- Updates & caches game information in the record
-- @param data: table of game fields
-- @return nothing
gamehub.update_game_form = function(game)
	local active = 0
	if game.active then active = 1 end
	local data = minetest.serialize(game.data)
	local stmt = ([[
	UPDATE game SET
		type = '%s',
		privs = '%s',
		author = '%s',
		credits = '%s',
		description = '%s',
		reward = %i,
		cap = %i,
		items = '%s',
		active = %i,
		data = '%s'
	WHERE name = '%s' LIMIT 1;
	]]):format(game.type, game.privs, game.author, game.credits,
	game.description, game.reward, game.cap, game.items, active,
	data, game.name)
	db_exec(stmt)
	-- cache
	gamehub.game[game.name].type = game.type
	gamehub.game[game.name].privs = minetest.string_to_privs(game.privs)
	gamehub.game[game.name].author = game.author
	gamehub.game[game.name].credits = game.credits
	gamehub.game[game.name].description = game.description
	gamehub.game[game.name].items = game.items
	gamehub.game[game.name].reward = game.reward
	gamehub.game[game.name].cap = game.cap
	gamehub.game[game.name].active = game.active
	gamehub.game[game.name].data = game.data
end

-- Updates game record play count
-- @param game: game name string
-- @return nothing
gamehub.update_game_played = function(game)
	local stmt = ([[
		UPDATE game SET played = %i WHERE name = '%s' LIMIT 1;
	]]):format(gamehub.game[game].played, game)

	db_exec(stmt)
end

-- Updates game record completed count
-- @param game: game name string
-- @return nothing
gamehub.update_game_completed = function(game)
	local stmt = ([[
	UPDATE game SET completed = %i WHERE name = '%s';
	]]):format(gamehub.game[game].completed, game)

	db_exec(stmt)
end

-- Update stats record
-- @return nothing
gamehub.update_stats = function()
	local data = minetest.serialize(gamehub.stats)
	local stmt = ([[
	UPDATE stats SET data = '%s'
	]]):format(data)
	db_exec(stmt)
end

-- Updates player record on departure
-- @param player: player object
-- @return nothing
gamehub.update_on_leaveplayer = function(player)

	local name = player:get_player_name()
	local game = gamehub.player[name].game
	local counters = minetest.serialize(gamehub.player[name].counters)
	local data = minetest.serialize(gamehub.player[name].data)
	-- default sql string for a subgame
	local stmt = ([[
	UPDATE player SET
		game = '%s',
		counters = '%s',
		data = '%s'
	WHERE name = '%s' LIMIT 1;
	]]):format(game,counters,data,name)

	if game == "world" then

		local pos = minetest.pos_to_string(vector.round(player:get_pos()))
		local facing = minetest.serialize({
			h = player:get_look_horizontal(),
			v = player:get_look_vertical()
		})
		-- replace
		stmt = ([[
		UPDATE player SET
			game = '%s',
			pos = '%s',
			facing = '%s',
			counters = '%s',
			data = '%s'
		WHERE name = '%s' LIMIT 1;
		]]):format(game,pos,facing,counters,data,name)

	end

	db_exec(stmt)
end

-- Updates player position in record
-- @param name: player name string
-- @return nothing
gamehub.update_player_pos = function(name)

	local pos, facing, stmt

	pos = minetest.pos_to_string(gamehub.player[name].pos)
	facing = minetest.serialize(gamehub.player[name].facing)
	stmt = ([[
	UPDATE player SET
	pos = '%s',
	facing = '%s'
	WHERE name = '%s' LIMIT 1;
	]]):format(pos, facing, name)

	db_exec(stmt)
end

-- Updates a player record field
-- @param name: player name string
-- @param field: field name string
-- @return nothing
gamehub.update_player_field = function(name, field)

	local value = gamehub.player[name][field]

	if field == "counters" or field == "data" then
		value = minetest.serialize(value)
	elseif field == "privs" then
		value = minetest.privs_to_string(gamehub.privs[name])
	end

	local stmt
	if type(value) == "string" then
		stmt = ([[
		UPDATE player SET %s = '%s' WHERE name = '%s' LIMIT 1;
		]]):format(field, value, name)
	else
		stmt = ([[
		UPDATE player SET %s = %i WHERE name = '%s' LIMIT 1;
		]]):format(field, value, name)
	end

	db_exec(stmt)
end

-- Updates shop item record
-- @param item: item name string
-- @param buy: price the shop pays
-- @param sell: price the buyer pays
-- @param moq: minimum order quantity
-- @return nothing
gamehub.update_shop_item = function(item, buy, sell, moq)
	-- cache
	gamehub.shop[item].moq = moq
	gamehub.shop[item].buy = buy
	gamehub.shop[item].sell = sell
	-- db
	local stmt = ([[
	UPDATE shop SET moq = %i, buy = %i, sell = %i
	WHERE name = '%s' LIMIT 1;
	]]):format(moq, buy, sell, item)
	db_exec(stmt)
end

-- Update game record play count
-- @param name: player name string
-- @return nothing
gamehub.update_bank_account = function(name)
	local balance = gamehub.bank[name].coins
	local stmt = ([[
	UPDATE bank SET coins = %i WHERE name = '%s' LIMIT 1;
	]]):format(balance, name)
	db_exec(stmt)
end

-- Updates data in settings record
-- @return nothing
gamehub.update_setting_data = function()
	local data = minetest.serialize(gamehub.settings)
	local stmt = ([[
	UPDATE settings SET data = '%s';
	]]):format(data)
	db_exec(stmt)
end

-------------------
---   DELETES   ---
-------------------

-- Deletes a game record
-- @param name: game name string
-- @return nothing
gamehub.delete_game = function(name)
	local stmt = ([[
	DELETE FROM game WHERE name = '%s' LIMIT 1;
	]]):format(name)
	db_exec(stmt)
	gamehub.game[name] = nil -- update cache
end

-- Deletes a player record
-- @param name: player name string
-- @return nothing
gamehub.delete_player = function(name)
	local stmt = ([[
	DELETE FROM player WHERE name = '%s'
	]]):format(name)
	db_exec(stmt)
	gamehub.player[name] = nil -- update cache
	--gamehub.delete_account(name)
end

-- Deletes a jail record
-- @param name: player name string
-- @return nothing
gamehub.jail.delete_record = function(name)
	local stmt = ([[
	DELETE FROM jail WHERE name = '%s';
	]]):format(name)
	db_exec(stmt)
	gamehub.jail[name] = nil -- update cache
end

-- Deletes a shop item record
-- @param item: item name string
-- @return nothing
gamehub.delete_shop_item = function(item)
	local stmt = ([[
	DELETE FROM shop WHERE item = '%s'
	]]):format(item)
	db_exec(stmt)
	gamehub.shop[item] = nil -- update cache
end

-- Deletes players bank account record
-- @param name: player name string
-- @return nothing
gamehub.delete_bank_account = function(name)
	local stmt = ([[
	DELETE FROM bank WHERE name = '%s';
	]]):format(name)
	db_exec(stmt)
	gamehub.bank[name] = nil
end
