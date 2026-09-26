# Copy-ready SoC Lua patterns (all used in a shipped-quality mod; `P` = your prefix)

## Spawning and releasing
```lua
-- spawn at a world point (x, z) snapped to the AI mesh; exact position if you give (x, y, z)
local function spawn(section, xz, parent)
	local pos, lv, gv = P_nav.point_near(xz[1], xz[#xz])
	if #xz == 3 then pos = vector():set(xz[1], xz[2], xz[3]) end
	if parent then return alife():create(section, pos, lv, gv, parent) end   -- never pass nil
	return alife():create(section, pos, lv, gv)
end

-- remember ids in pstor so they survive save/load
P_story.set("npc_bob", spawn("P_bob", { -213.5, -123.2 }).id)
local function id_of(key) return P_story.get(key, nil) end

local function release_key(key)
	local id = id_of(key)
	P_hud.unmark(id)                               -- map spot first
	local se = id and alife():object(id)
	if se then alife():release(se, true) end
	P_story.set(key, nil)
end
```

## Inventory
```lua
local function count_items(section)
	local n = 0
	db.actor:iterate_inventory(function(dummy, item) if item:section() == section then n = n + 1 end end, db.actor)
	return n
end
local function take_items(section, n)
	local ids = {}
	db.actor:iterate_inventory(function(dummy, item)
		if item:section() == section and #ids < n then ids[#ids + 1] = item:id() end
	end, db.actor)
	for _, id in ipairs(ids) do local se = alife():object(id) if se then alife():release(se, true) end end
end
local function give_items(section, n)
	for i = 1, n or 1 do
		alife():create(section, db.actor:position(), db.actor:level_vertex_id(), db.actor:game_vertex_id(), db.actor:id())
	end
end
-- a stash box with loot (ammo sections need create_ammo)
local box = spawn("P_stash_box", { x, z })
for _, it in ipairs({ { "medkit", 2 }, { "ammo_9x18_fmj", 3 } }) do
	for i = 1, it[2] do
		if system_ini():line_exist(it[1], "box_size") then se_respawn.create_ammo(it[1], pos, lv, gv, box.id, 1)
		else alife():create(it[1], pos, lv, gv, box.id) end
	end
end
```

## Deferred reactions (inventory callbacks, dialog actions)
```lua
local taken = {}
function on_item_take(item) taken[#taken + 1] = item:section() end    -- from P_main, nothing else here

local pending_release = false
function dialog_action_vanish(npc, actor) pending_release = true end   -- dialog <action>

function update(t)
	if #taken > 0 then local q = taken; taken = {}; for _, s in ipairs(q) do handle_taken(s) end end
	if pending_release and not db.actor:is_talking() then pending_release = false; release_key("npc_bob") end
end
```

## Time skip (no API to set the clock: fast-forward under a black screen)
```lua
local skip = nil
function time_skip(hour, done_cb)          -- start it outside dialogs (input gets disabled)
	if skip then return end
	skip = { hour = hour, factor = level.get_time_factor(), done = done_cb, started = time_global() }
	level.disable_input(); level.hide_indicators()
	level.add_pp_effector("agr_u_fade.ppe", 2620, true)
	level.set_time_factor(3000)
end
local function update_skip(t)
	if skip == nil then return end
	if t - skip.started > 2000 and level.get_time_hours() == skip.hour then
		level.set_time_factor(skip.factor); level.remove_pp_effector(2620)
		level.show_indicators(); level.enable_input()
		local cb = skip.done; skip = nil; if cb then cb() end
	end
end
```

## Custom condition for NPC logic condlists (`{=P_cond}` in an .ltx)
```lua
-- register at actor spawn (xr_conditions is a vanilla module table)
xr_conditions.P_retreating = function(actor, npc) return my_state[npc:id()] == "retreat" end
-- logic: combat_ignore_cond = {=P_retreating}
```
Likewise `xr_effects.P_something = function(actor, npc) ... end` for `%=P_something%` effects.

## Key NPCs that must not die (quests can't break)
```lua
for _, key in ipairs({ "npc_bob", "npc_alice" }) do
	local o = level.object_by_id(id_of(key) or -1)
	if o and o:alive() and o.health < 0.99 then o.health = 1 - o.health end   -- delta setter
end
```
Truly unkillable enemies: big immunities in the section plus a "virtual HP" kept in Lua and the real
health resynced to a high band every ~60 ms (the setter is a delayed delta, so measure drops against
the last value you set).

## Effects and sounds (keep references!)
```lua
local fx = {}
local function burst(effect, pos, snd)
	local po = particles_object(effect); po:play_at_pos(pos); fx[#fx + 1] = po
	if snd then local s = sound_object(snd); s:play_at_pos(db.actor, pos, 0, sound_object.s3d); fx[#fx + 1] = s end
	if #fx > 40 then table.remove(fx, 1) end
end
burst("explosions\\explosion_heli_rocket_00", vector():set(x, y + 20, z), "weapons\\f1_explode")
level.add_pp_effector("teleport.ppe", 2641, false)
level.add_cam_effector("camera_effects\\earthquake.anm", 2640, false, "")
```
Point in front of the player: `local d = device().cam_dir; local p = db.actor:position(); local q = vector():set(p.x + d.x*45, p.y, p.z + d.z*45)`.

## Hanging lamps placed in all.spawn (on/off from script)
```lua
local o = level.object_by_id(lamp_id)     -- only while online; re-apply when it comes back online
if o then local l = o:get_hanging_lamp(); if want then l:turn_on() else l:turn_off() end end
```
Find ids once by scanning names: `for id = 1, 65534 do local se = alife():object(id) if se and string.find(se:name(), "^P_lamp_") then ... end end`.

## Weather
Add a weather section (copy an environment cycle) in `config\weathers\`, register it in
`environment.ltx` (patch), then `level.set_weather("P_fog", false)` / `level.set_weather("default", false)`.

## Slowing/trapping the player
There's no walk-speed API: put an invisible very heavy item (custom section, `inv_weight = 400`) into
the inventory (overload = can't move), remove it to release. Combine with `alcohol.ppe` and a psy drain.

## Measuring things you can't read
SoC exposes no belt API. Trick used: a belt artifact scales incoming hits of a type - hit the actor
with a tiny probe hit (`hit.telepatic`, power 0.02), read `psy_health` one tick later, refund it; no
loss = the artifact with telepatic immunity is on the belt.
