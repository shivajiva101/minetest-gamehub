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

local function get_name(item)
	if type(item) == "table" then
		return item.name
	end
	return item
end

-- display info and handle buying & selling items
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "" then return end
	local name = player:get_player_name()
	local item = get_name(unified_inventory.current_item[name])
	-- catch events
	if fields.shop_admin and gamehub.privs[name].server then

		unified_inventory.set_inventory_formspec(player, "shop_manager")

	elseif fields.shop_buy then

		local p_inv = player:get_inventory()
		local qty = tonumber(fields.shop_qty) or 1
		local moq = gamehub.shop[item].moq
		if qty < moq then
			minetest.chat_send_player(name,"minimum qty: "..moq)
			return
		end
		local total = tonumber(gamehub.shop[item].sell) * tonumber(qty)
		-- funds and inventory space check
		if gamehub.bank[name].coins >= total then
			local item_stack = ItemStack(item .. " " .. qty)
			if p_inv:room_for_item("main", item_stack) then
				total = total - (2 * total)
				gamehub.bank[name].coins = gamehub.bank[name].coins + total
				gamehub.update_bank_account(name)
				p_inv:add_item("main", item_stack)
				minetest.sound_play("shop_register", {
					to_player = name,
					gain = 0.1,
					loop = false
				})
				minetest.log("info",
				name.." bought "..qty.." of "..item.."from the shop")
			else
				minetest.chat_send_player(name,
				"insufficient space in your inventory!")
			end
			unified_inventory.set_inventory_formspec(player, "shop_player") -- refresh
		else
			minetest.chat_send_player(name,"insufficient funds!")
		end

	elseif fields.shop_remove then

		gamehub.delete_shop_item(item)
		unified_inventory.set_inventory_formspec(player, "shop_manager")

	elseif fields.shop_add and gamehub.privs[name].server then

		if not gamehub.shop[item] and tonumber(fields.shop_selling) > 0 then -- new
			gamehub.new_shop_item(item, tonumber(fields.shop_buying),
			tonumber(fields.shop_selling), tonumber(fields.shop_moq))
		elseif gamehub.shop[item] then -- update
			gamehub.update_shop_item(item, tonumber(fields.shop_buying),
			tonumber(fields.shop_selling), tonumber(fields.shop_moq))
		end
		unified_inventory.set_inventory_formspec(player, "shop_manager") -- refresh
		
	end
end)

-- Initialise shop drop slot
minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	-- create single slot inventory
	local shop_inv = minetest.create_detached_inventory(name.."_shop_inv",{
		allow_put = function(inv, listname, index, stack)
			local item = get_name(unified_inventory.current_item[name])
			if string.find(stack:get_name(), item) == nil then return 0 end
			return stack:get_count()
		end,
		on_put = function(inv, listname, index, stack, p)
			local n = p:get_player_name()
			local item = get_name(unified_inventory.current_item[n])
			local payment = stack:get_count() * gamehub.shop[item].buy
			inv:remove_item(listname, stack)
			gamehub.bank[n].coins = gamehub.bank[n].coins + payment
			gamehub.update_bank_account(n)
			minetest.sound_play("shop_pay", {
				to_player = n,
				gain = 1,
				loop = false
			})
			minetest.log("info",
			name .. " balance is now " .. gamehub.bank[n].coins .. " coins")
			unified_inventory.set_inventory_formspec(p, "shop_player")
		end
	}, name)
	shop_inv:set_size("shop", 1)
end)

-- Register button
unified_inventory.register_button("shop_player", {
	type = "image",
	image = "shop_button.png",
	tooltip = "Shop",
})

-- Register UI pages
unified_inventory.register_page("shop_player", {
	get_formspec = function(player, perplayer_formspec)

		local name = player:get_player_name()
		local fy = perplayer_formspec.formspec_y
		local fhy = perplayer_formspec.form_header_y
		local item = get_name(unified_inventory.current_item[name])
		local def = minetest.registered_items[item]
		local description

		if def and def.description then
			description = def.description
		else
			description = item
		end

		local fs = {}
		fs[#fs+1] = "background[0,"
		fs[#fs+1] = (fy + 3.5)
		fs[#fs+1] = ";8,4;ui_main_inventory.png]"
		fs[#fs+1] = "label[0,"
		fs[#fs+1] = fhy
		fs[#fs+1] = ";Server Shop]"
		fs[#fs+1] = "size[8,8.6]"
		fs[#fs+1] = "image[5,1;1,1;shop_treasure.png]"
		fs[#fs+1] = "label[6,1.4;"
		fs[#fs+1] = gamehub.bank[name].coins
		fs[#fs+1] = "]"

		-- admin?
		if gamehub.privs[name].server then
			fs[#fs+1] = "image_button[7.5,4;0.5,0.5;ui_craft_icon.png;shop_admin;]"
		end

		if not item then
			fs[#fs+1] = "label[1,1;Select an item...]"
			return {formspec=table.concat(fs)}
		end

		if gamehub.shop[item] then
			fs[#fs+1] = "item_image_button[1,1;2,2;"
			fs[#fs+1] = item
			fs[#fs+1] = ";shop_buy;]"
			fs[#fs+1] = "tooltip[shop_buy;Press to buy "
			fs[#fs+1] = description
			fs[#fs+1] = "]"
			fs[#fs+1] = "label[1,3.2;Price: "
			fs[#fs+1] = gamehub.shop[item].sell
			fs[#fs+1] = "]"
			if def.type ~= "tool" then
				fs[#fs+1] = "field[3.6,1.5;1,0.5;shop_qty;Qty;"
				fs[#fs+1] = gamehub.shop[item].moq
				fs[#fs+1] = "]"
			end
			if tonumber(gamehub.shop[item].buy) > 0 then
				fs[#fs+1] = "background[5,"
				fs[#fs+1] = (fy + 1.5)
				fs[#fs+1] = ";1,1;ui_single_slot.png]"
				fs[#fs+1] = "list[detached:"
				fs[#fs+1] = name
				fs[#fs+1] = "_shop_inv;shop;5,2.5;1,1]"
				fs[#fs+1] = "label[5,3.5;Pays: "
				fs[#fs+1] = gamehub.shop[item].buy
				fs[#fs+1] = "]"
			end
		else
			fs[#fs+1] = "image[1.1,1;2,2;ui_no.png]"
		end

		return {formspec=table.concat(fs)}
	end,
})

unified_inventory.register_page("shop_manager", {
	get_formspec = function(player, perplayer_formspec)

		local name = player:get_player_name()
		local fy = perplayer_formspec.formspec_y
		local fhy = perplayer_formspec.form_header_y
		local item = get_name(unified_inventory.current_item[name])
		local def = minetest.registered_items[item]
		local description

		if def and def.description then
			description = def.description
		else
			description = item
		end

		local fs = {}
		fs[#fs+1] = "background[0,"
		fs[#fs+1] = (fy + 3.5)
		fs[#fs+1] = ";8,4;ui_main_inventory.png]"
		fs[#fs+1] = "label[0,"
		fs[#fs+1] = fhy
		fs[#fs+1] = ";Shop Management]"

		if not item then
			fs[#fs+1] = "label[1,1;Select an item...]"
			return {formspec=table.concat(fs)}
		end

		local sell,buy,moq = "0","0","1"
		if gamehub.shop[item] then
			buy = gamehub.shop[item].buy
			sell = gamehub.shop[item].sell
			moq = gamehub.shop[item].moq
		end

		fs[#fs+1] = "item_image_button[1,1;2,2;"
		fs[#fs+1] = item
		fs[#fs+1] = ";shop_add;]"
		fs[#fs+1] = "label[1,3.2;Item: "
		fs[#fs+1] = description
		fs[#fs+1] = "]"
		fs[#fs+1] = "field[3.8,1.5;1,0.5;shop_selling;sell:;"
		fs[#fs+1] = sell
		fs[#fs+1] = "]"
		fs[#fs+1] = "field[3.8,2.7;1,0.5;shop_buying;buy:;"
		fs[#fs+1] = buy
		fs[#fs+1] = "]"
		fs[#fs+1] = "field[5,2.7;1,0.5;shop_moq;moq:;"
		fs[#fs+1] = moq
		fs[#fs+1] = "]"
		fs[#fs+1] = "tooltip[shop_selling;selling price]"
		fs[#fs+1] = "tooltip[shop_buying;purchase price]"
		if gamehub.shop[item] then
			fs[#fs+1] = "tooltip[shop_add;press to update item]"
		else
			fs[#fs+1] = "tooltip[shop_add;press to add item]"
		end
		fs[#fs+1] = "tooltip[shop_moq;minimum order quantity]"
		if gamehub.shop[item] then
			fs[#fs+1] = "image_button[7.2,1;0.5,0.5;shop_delete.png;shop_remove;]"
			fs[#fs+1] = "tooltip[shop_remove;Press to remove item from shop]"
		end

		return {formspec=table.concat(fs)}
	end,
})

-- register pages for item button click tracking
gamehub.register_click_tracking("shop_player")
gamehub.register_click_tracking("shop_manager")
