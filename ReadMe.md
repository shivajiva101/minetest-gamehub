## Gamehub Modpack
### for minetest by shivajiva101@hotmail.com

This mod provides a hub concept for sub games within a Minetest world.

Designed to handle privileges, inventory, transport and rewards.
Adding nodes for game stages and game completion, menus, commands,
shop and jail features. It uses and extends other mods API's to create a simple but powerful concept.

You *just* need to create the content! To help you start there are a few
example games in the /schems folder you can add. You have the ability to load, save and share the games you create! Easy player access to the menu and admin tools to simplify the game creation process.

Mod dependencies:
* default
* areas
* maptools
* unified inventory
* worldedit

Lua dependencies:
* lsqlite3 (http://lua.sqlite.org/)

I suggest you use luarocks (https://luarocks.org/) to install lsqlite3 with the command:

``sudo apt install luarocks``

then you can install lsqlite3 with the following command:

``luarocks install lsqlite3``

This mod should be added to secure.trusted in your minetest.conf before starting the server.
### Privileges
```
hub_admin   -- games admin
hub_mod     -- server moderator
```
### Admin Commands
```
/hub <option>

Options:

add                         -- display add game form
delete <area_id> [true]     -- delete a game [remove]
edit <game>                 -- display form to edit game
load <name> [new_name]      -- load a saved game [used to duplicate]
protect <area_id> [true]    -- add pclip & kill nodes to an area [remove]
save <area_id>              -- save a game
stage                       -- add a stage destination to a game
unstage <game> <num> 	    -- remove a stage destination
```
### Moderator Commands
```
/info <player>		-- display players current game
```
### Player Commands
```
/p		-- display game menu to player
/q		-- quit current game
/s		-- display statistics
```
### Adding an example game
A few examples are provided in the mods /schems folder. A saved game consists of a set of 3 files with the same name but different extensions [hub, mts, we]. Check the folder to see the names available to use. Some games have dependencies on frame, signs_lib etc. You should check your server has them enabled before attempting to load them. See readme.md file in the schems folder for more info.

For example to add a game:
* choose a location, preferably above 1000 height
* type ``/hub load Barnyard`` or ``/hub load BunnyHop`` or ``/hub load X-men Rooms``

The game will be inserted into your world and appear as an entry in the players game menu. Yes you read that correctly...a single command will add a functional game!
### Creating a new game in your world
The basic steps to add a game are as follows;
* Choose a location to build the game, preferably away from players access

* Create an area large enough to hold the game using the name you have chosen for the game. This ensures it's protected during the build phase.
* Go to the place you want the player to start from
* Turn and face the direction you want the player to face on arrival and type ``/hub add``
* Fill in form details leaving active *unchecked* and press save
* Build your game using the single cloud node that appears
* Use stage pads if required for getting between different stages of your game (see section below)
* Place reward pad at finish point, right-click it and set the game name
* Type ``/hub protect <area_id>`` where area_id is the id of the area you created in step 2. This command will wrap the area in pclip and line the inside with kill nodes 2 deep.
* Type ``/hub edit <game>`` to modify any details, tick active checkbox and save

The game should now appear in the players game menu.
### Setting stages in your games
If you want multiple stages in your game, you can use stage pads. The mechanism is simple, go to the destination for the pad, look at the view you want a player to see when they arrive, then type ``/hub stage``
you should be informed the stage was added at the current vector. Now you can go back and place the pad, that's it! You have added your first stage.

If for any reason you need to remove a stage you can use ``/hub unstage <stage_number>``  where ``<index>`` refers to the table index, one less than the stage. You must be within the game area, do not execute this command anywhere else!
### Saving games
Use the area ID to save a game, remember it creates 3 files named the same as the area name,
so it's important to think about what you call the area, prior to building a game within it.
* type ``/hub save <area_id>``

3 files will be created in your worlds /schems folder which you can compress as a set to share with your friends and the community.
### Jail
A simple but powerful mechanism is used to jail players and disable their functionality. The jail building is inserted in the bowels of the world, a fitting place for a player finding themselves on the wrong side of the server management team. To jail a player use the command:

 ``/jail <player> <duration> <reason>``

 where ``<player>`` is the players name, ``<duration>`` is the length of time in the same format as sban & xban. For example:

 ``/jail Steve 1w trolling a staff member ``

 this would jail Steve for 1 week and will automatically expire. The hub_mod privilege is required before you can jail players.
 To unjail a currently jailed player use the following command:

 ``/unjail <player>``

 jail records are only kept for the duration of the jail sentence and can be viewed using the command:

 ``/jail_info``

 this command also requires the hub_mod privilege so only the server staff have access to the information.
### Shop
The hub admin controls the shop, they have the necessary privilege to add items from the inventory, choosing a selling price, moq and buy back price if required for each item they wish to sell. It provides a method to spend the reward credits and earn more from mining and farming. The shop is accessed via Unified Inventory with the shop icon.
### Credits
See individual credit.txt in the respective folders for further information.

This modpack was inspired by running a Skyblock server and time spent playing with the code, friends who undoubtedly know who they are, plus all the Minetest developers & mod developers contributions that enabled it.
### Status
Functional, not fully tested

THIS MODPACK IS A WIP!
