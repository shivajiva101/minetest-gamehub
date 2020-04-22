unused_args = false
allow_defined_top = true
max_line_length = 999

globals = {
	"gamehub", "unified_inventory",
}

read_globals = {
	string = {fields = {"split", "trim"}},
	table = {fields = {"copy", "getn"}},

	-- Minetest
	"minetest", "core",
	"vector", "ItemStack",
	"VoxelArea",

	"default", "playerplus",
	"armor", "areas",
	"worldedit", "sqlite3",

	"jail", "stairsplus", "signs_lib",
}

files["gamehub/commands.lua"].ignore = { "pos" }
files["jail/init.lua"].ignore = { "owner" }
