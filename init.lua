banshee = {}

local path = minetest.get_modpath("banshee")

local random = math.random

local abs = math.abs

local function round(x) -- Round number up
	return x + 0.5 - (x + 0.5) % 1
end

------------------
-- HQ Functions --
------------------

function banshee.hq_linear_pursuit(self, prty, target)
	local move_resist = 0
	local strafe_dir = nil
	local offset = {
		x = random(-2, 2),
		y = 0,
		z = random(-2, 2)
	}
	local func = function(self)
		if not mobkit.is_alive(target) then return true end
		local pos = self.object:get_pos()
		local tpos = target:get_pos()
		if target:is_player() then
			tpos.y = tpos.y + 1
		end
		local dist = vector.distance(pos, tpos)
		local is_in_solid = minetest.registered_nodes[minetest.get_node(pos).name].walkable
		if is_in_solid then
			move_resist = -2
		elseif move_resist < 0 then
			move_resist = move_resist + self.dtime
		end
		if dist > self.view_range then
			mobkit.animate(self, "spin")
			self.object:set_velocity({x = 0, y = 0.1, z = 0})
			if mobkit.timer(self, 1.5) then
				return true
			end
		elseif dist > 3 then
			mobkit.animate(self, "idle")
			if pos.y - tpos.y > 7 then
				banshee.hq_swoop_to_target(self, prty + 1, target)
				return
			end
			local dir = vector.direction(pos, tpos)
			local yaw = self.object:get_yaw()
			local tyaw = minetest.dir_to_yaw(dir)
			if abs(tyaw - yaw) > 0.1 then
				mobkit.turn2yaw(self, tyaw)
			end
			dir = vector.direction(pos, vector.add(tpos, offset))
			local vel = vector.multiply(dir, self.max_speed + move_resist)
			self.object:set_velocity(vel)
			strafe_dir = nil
		else
			local dir = vector.direction(pos, tpos)
			local yaw = self.object:get_yaw()
			local tyaw = minetest.dir_to_yaw(dir)
			if abs(tyaw - yaw) > 0.1 then
				mobkit.turn2yaw(self, tyaw)
			end
			local vel = vector.multiply(dir, self.max_speed + move_resist)
			offset = {
				x = random(-2, 2),
				y = 0,
				z = random(-2, 2)
			}
			if not strafe_dir then
				if math.random(1, 2) == 1 then
					strafe_dir = -1.2
				else
					strafe_dir = 1.2
				end
			end
			vel.x = (dir.x * math.cos(strafe_dir) + dir.z * math.sin(strafe_dir)) * (self.max_speed + move_resist)
			vel.z = (-dir.x * math.sin(strafe_dir) + dir.z  * math.cos(strafe_dir)) * (self.max_speed + move_resist)
			vel.y = (round(tpos.y - pos.y)) * self.max_speed
			if dist < 2 then
				self.object:set_velocity({x = 0, y = 0, z = 0})
				mobkit.animate(self, "punch")
				if mobkit.timer(self, 0.2) then
					target:punch(self.object, 1.0, {
						full_punch_interval = 0.1,
						damage_groups = {fleshy = 4}
					}, nil)
					return true
				end
			else
				self.object:set_velocity(vel)
				mobkit.animate(self, "idle")
			end
		end
	end
	mobkit.queue_high(self, func, prty)
end

function banshee.hq_swoop_to_target(self, prty, target)
	local move_resist = 0
	local stage = 1
	local tpos = {}
	local func = function(self)
		if not mobkit.is_alive(target) then return true end
		local pos = self.object:get_pos()
		local is_in_solid = minetest.registered_nodes[minetest.get_node(pos).name].walkable
		if is_in_solid then
			move_resist = -2
		elseif move_resist < 0 then
			move_resist = move_resist + self.dtime
		end
		if stage == 1 then -- Get player position only once
			tpos = target:get_pos()
			if target:is_player() then
				tpos.y = tpos.y + 1
			end
			local dist = vector.distance(pos, tpos)
			local dir = vector.direction(pos, tpos)
			local yaw = self.object:get_yaw()
			local tyaw = minetest.dir_to_yaw(dir)
			dir.y = dir.y * 2
			if abs(tyaw - yaw) > 0.1 then
				mobkit.turn2yaw(self, tyaw)
			end
			local vel = vector.multiply(dir, self.max_speed)
			self.object:set_velocity(vel)
			if dist < 1.5 then
				stage = 2
			end
		elseif stage == 2 then -- Begin arching up
			local dist = vector.distance(pos, tpos)
			local vel = self.object:get_velocity()
			vel = vector.subtract(vel, self.dtime * 0.1) -- Begin slowing down
			vel.y = 2 -- Arch up
			self.object:set_velocity(vel)
			if dist > 3 then
				return true
			end
		end
	end
	mobkit.queue_high(self, func, prty)
end

function banshee.hq_roam(self, prty)
	local move_resist = 0
	local idle_timer = 2
	local pos2 = nil
	local init = false
	local func = function(self)
		mobkit.animate(self, "idle")
		local pos = self.object:get_pos()
		idle_timer = idle_timer - self.dtime
		if idle_timer <= 0
		and not pos2 then
			pos2 = {
				x = pos.x + random(-6, 6),
				y = pos.y + random(-2, 2),
				z = pos.z + random(-6, 6)
			}
		else
			self.object:set_velocity({x = 0, y = 0.1, z = 0})
		end
		local is_in_solid = minetest.registered_nodes[minetest.get_node(pos).name].walkable
		if is_in_solid then
			move_resist = -2
		elseif move_resist < 0 then
			move_resist = move_resist + self.dtime
		end
		if pos2 then
			local dir = vector.direction(pos, pos2)
			local yaw = self.object:get_yaw()
			local tyaw = minetest.dir_to_yaw(dir)
			if abs(tyaw - yaw) > 0.1 then
				mobkit.turn2yaw(self, tyaw)
			end
			local vel = vector.multiply(dir, self.max_speed + move_resist)
			self.object:set_velocity(vel)
			if vector.distance(pos, pos2) < 2 then
				pos2 = nil
				idle_timer = 3
			end
		end
	end
	mobkit.queue_high(self, func, prty)
end

--------------------
-- Mob Definition --
--------------------

local function banshee_logic(self)

    if self.hp <= 0 then
        mob_core.on_die(self)
        return	
    end

    local prty = mobkit.get_queue_priority(self)
    local pos = mobkit.get_stand_pos(self)
	local player = mobkit.get_nearby_player(self)
	
	if self.hurt_sound_cooldown > 0 then
		self.hurt_sound_cooldown = self.hurt_sound_cooldown -  self.dtime
	end

    if mobkit.timer(self, 1) then

        mob_core.vitals(self)
		mob_core.random_sound(self, 32)
		
		if prty < 2
		and player then
			banshee.hq_linear_pursuit(self, 2, player)
		end

        if mobkit.is_queue_empty_high(self) then
            banshee.hq_roam(self, 0)
        end
    end
end

minetest.register_entity("banshee:banshee",{
	-- Initial
	physical = false,
	collide_with_objects = false,
	visual = "mesh",
    makes_footstep_sound = false,
    static_save = true,
    timeout = 1200,
    -- Stats
    max_hp = 20,
    armor_groups = {fleshy = 100},
    view_range = 32,
    reach = 2,
    damage = 3,
    knockback = 2,
	lung_capacity = 40,
	-- Visual
	glow = 6,
	collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
	visual_size = {x = 1, y = 1},
	mesh = "banshee_banshee.b3d",
	textures = {"banshee_banshee.png"},
	animation = {
		idle = {range = {x = 1, y = 20}, speed = 5, frame_blend = 0.3, loop = true},
		punch = {range = {x = 30, y = 45}, speed = 20, frame_blend = 0.3, loop = false},
		spin = {range = {x = 55, y = 75}, speed = 25, frame_blend = 0.3, loop = true},
	},
    -- Physics
    max_speed = 6,
    stepheight = 0,
    jump_height = 0,
    max_fall = 0,
    buoyancy = 0,
	springiness = 0,
    -- Sound
    sounds = {
        random = {
            name = "banshee_random",
            gain = 0.5,
            distance = 16
		},
		hurt = {
            name = "banshee_hurt",
            gain = 0.5,
            distance = 16
		},
		death = {
            name = "banshee_death",
            gain = 0.5,
            distance = 16
        }
    },
	-- Basic
	drops = {
		{name = "default:mese_crystal_fragment", chance = 2, min = 1, max = 2},
		{name = "banshee:blowgun", chance = 10, min = 1, max = 2}
    },
	logic = banshee_logic,
	physics = function(self) end,
    get_staticdata = mobkit.statfunc,
    on_activate = function(self, staticdata, dtime_s)
        mobkit.actfunc(self, staticdata, dtime_s)
        self.hurt_sound_cooldown = 0
    end,
	on_step = mobkit.stepfunc,
	on_rightclick = function(self, clicker)
		local tool = clicker:get_wielded_item()
		if tool:get_name() == "fireflies:bug_net" then
			local inv = clicker:get_inventory()
			if inv:room_for_item("main", {name = "default:mese_crystal"}) then
				clicker:get_inventory():add_item("main", "default:mese_crystal")
			else
				local pos = self.object:get_pos()
				pos.y = pos.y + 0.5
				minetest.add_item(pos, {name = "default:mese_crystal"})
			end
			self.object:remove()
			return
		end
	end,
    on_punch = function(self, puncher, _, tool_capabilities, dir)
		local item = puncher:get_wielded_item()
		if mobkit.is_alive(self) then
			minetest.after(0.0, function()
				self.object:settexturemod("^[colorize:#FF000040")
				core.after(0.2, function()
					if mobkit.is_alive(self) then
						self.object:settexturemod("")
					end
				end)
			end)
			mobkit.hurt(self, tool_capabilities.damage_groups.fleshy or 1)
			if self.hurt_sound_cooldown <= 0 then
				mob_core.make_sound(self, "hurt")
				self.hurt_sound_cooldown = math.random(1, 3)
			end
			if mobkit.is_queue_empty_high(self) then
				banshee.hq_linear_pursuit(self, 20, puncher)
			end
		end
	end
})

mob_core.register_spawn_egg("banshee:banshee", "89db52", "66a43d")

--------------
-- Spawning --
--------------

-- Single --

mob_core.register_spawn({
	name = "banshee:banshee",
	nodes = {
		"default:snow",
		"default:dirt_with_coniferous_litter",
		"default:dirt_with_snow"
	},
	min_light = 0,
	max_light = 4,
	min_height = -31000,
	max_height = 31000,
	group = 1,
	optional = {
		biomes = {
			"taiga",
			"coniferous_forest"
		}
	}
}, 16, 8)

-- Double --

mob_core.register_spawn({
	name = "banshee:banshee",
	nodes = {
		"default:snow",
		"default:dirt_with_coniferous_litter",
		"default:dirt_with_snow"
	},
	min_light = 0,
	max_light = 4,
	min_height = -31000,
	max_height = 31000,
	group = 2,
	optional = {
		biomes = {
			"taiga",
			"coniferous_forest"
		}
	}
}, 16, 16)

-- Triple --

mob_core.register_spawn({
	name = "banshee:banshee",
	nodes = {
		"default:snow",
		"default:dirt_with_coniferous_litter",
		"default:dirt_with_snow"
	},
	min_light = 0,
	max_light = 4,
	min_height = -31000,
	max_height = 31000,
	group = 3,
	optional = {
		biomes = {
			"taiga",
			"coniferous_forest"
		}
	}
}, 16, 16)

-------------
-- Glowgun --
-------------

local goo_cube_def = {
    armor_groups = {immortal = 1},
    physical = false,
    visual = "cube",
    visual_size = {x=.2,y=.2,z=.2},
    textures = {
        "banshee_goo_cube.png",
        "banshee_goo_cube.png",
        "banshee_goo_cube.png",
        "banshee_goo_cube.png",
        "banshee_goo_cube.png",
        "banshee_goo_cube.png"
    },
	collisionbox = {0, 0, 0, 0, 0, 0},
	glow = 8,
    shooter = "",
    timer = 0.5,
    timeout = 10,
	on_step = function(self, dtime)
		if self.shooter == "" then
			self.object:remove()
			return
		end
        self.object:set_armor_groups({immortal = 1})
		self.timeout = self.timeout - dtime
        if self.timeout <= 0 then
			self.object:remove()
			return
		end
		local pos = self.object:get_pos()
		local node = minetest.get_node(pos)
		if minetest.registered_nodes[node.name].walkable then
			if self.last_pos then
				local ppos = self.last_pos
				minetest.add_particlespawner({
					amount = 6,
					time = 0.25,
					minpos = {x = ppos.x - 7 / 16, y = ppos.y + 0.6, z = ppos.z - 7 / 16},
					maxpos = {x = ppos.x + 7 / 16, y = ppos.y + 0.6, z = ppos.z + 7 / 16},
					minvel = vector.new(-1, 2, -1),
					maxvel = vector.new(1, 5, 1),
					minacc = vector.new(0, -9.81, 0),
					maxacc = vector.new(0, -9.81, 0),
					minsize = 0.5,
					maxsize = 1,
					collisiondetection = false,
					glow = 12,
					texture = "banshee_goo_splash.png"
				})
			end
			self.object:remove()
			return
		end
		local objects = minetest.get_objects_inside_radius(pos, 2)
		for _, object in ipairs(objects) do
			if object
			and ((object:is_player()
			and object:get_player_name() ~= self.shooter)
			or ( object:get_luaentity()
			and object:get_armor_groups().fleshy)) then
				if vector.distance(pos, object:get_pos()) < 2 then
					local puncher = self.object
					if minetest.get_player_by_name(self.shooter) then
						puncher = minetest.get_player_by_name(self.shooter)
					end
					object:punch(puncher, 2.0, {full_punch_interval = 0.1, damage_groups = {fleshy = 5}}, nil)
					self.object:remove()
				end
			end
		end
		self.last_pos = pos
    end
}

minetest.register_entity("banshee:glow_ammo", goo_cube_def)

minetest.register_craftitem("banshee:glowgun", {
    description = "Glowgun",
	inventory_image = "banshee_glowgun.png",
	--wield_image = "banshee_glowgun.png^[transformR90",
    wield_scale = {x = 1, y = 1, z = 2},
    stack_max = 1,
	on_use = function(itemstack, player)
		local meta = itemstack:get_meta()
		if meta:get_int("timestamp") == 0 then
			meta:set_int("timestamp", os.time())
		end
		local time = meta:get_int("timestamp")
		local diff = os.time() - time
		if diff > 1 then
			local ppos = player:get_pos()
			ppos.y = ppos.y + 1
			local object = minetest.add_entity(ppos, "banshee:glow_ammo")
			object:get_luaentity().shooter = player:get_player_name()
			local dir = player:get_look_dir()
			object:set_velocity(vector.multiply(dir, 64))
			meta:set_int("timestamp", os.time())
		end
		return itemstack
    end,
})