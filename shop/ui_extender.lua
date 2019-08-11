--[[

shop mod (C) shivajiva101@hotmail.com 2019

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

-- Extend Unified Inventory functionality to track
-- item button clicks on pages registered by this mod.

gamehub.page_click_tracking = {}

function gamehub.register_click_tracking(name)
	gamehub.page_click_tracking[name] = true
end

-- register callback to track clicks
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "" then return end
	local player_name = player:get_player_name()
	local page = unified_inventory.current_page[player_name]
	if gamehub.page_click_tracking[page] then
		local item
		for name, value in pairs(fields) do
			if string.sub(name, 1, 12) == "item_button_" then
				local _, mangled_item = string.match(name, "^item_button_([a-z]+)_(.*)$")
				item = unified_inventory.demangle_for_formspec(mangled_item)
				break
			end
		end
		if item then
			unified_inventory.current_item[player_name] = item
			unified_inventory.set_inventory_formspec(player, page)
			return true -- no further handling
		end
	end
end)
