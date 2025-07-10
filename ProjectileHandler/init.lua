local Modules = {}

local require = function(func)
	return func()
end

Modules.ParticleFramework = function()
	local ParticleFramework = {}

	local Workspace = game:GetService("Workspace")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local Debris = game:GetService("Debris")

	local IsServer = RunService:IsServer()

	local TargetEvent
	if not IsServer then
		TargetEvent = RunService.RenderStepped
	else
		TargetEvent = RunService.Heartbeat
	end

	local Miscs = ReplicatedStorage:WaitForChild("Miscs")

	local Bullets = Miscs.Bullets
	local Projectiles = Miscs.Projectiles

	local DamageModule = require(Modules.DamageModule)
	local Utilities = require(Modules.Utilities)
	local Thread = Utilities.Thread
	local Math = Utilities.Math

	local DebugVisualization = false

	-- Legends
	-->green: stopped
	-->red: entered object
	-->blue: exited object
	-->yellow: ricochet
	-->viollet: penetrated humanoid

	do
		local setmt = setmetatable
		local insert = table.insert
		local remove = table.remove
		local tick = tick
		local new = Instance.new
		local c3 = Color3.new
		local ns = NumberSequence.new
		local v3 = Vector3.new
		local cf = CFrame.new
		local ray = Ray.new
		local nv = v3()
		local nc = cf()
		local dot = nv.Dot
		local ptos = nc.pointToObjectSpace
		local vtws = nc.vectorToWorldSpace
		local camera = not IsServer and Workspace.CurrentCamera
		local ffc = game.FindFirstChild
		local particles = {}
		local removelist = {}
		local time = os.clock()
		local camcf = not IsServer and camera.CFrame
		local neweffect
		do
			function neweffect(w0, partprop, ricochetdata)
				local t0, p0, v0
				local t1, p1, v1 = os.clock(), ptos(camcf, w0)
				local attach0 = Bullets[partprop[4]].Attachment0:Clone()
				local attach1 = Bullets[partprop[4]].Attachment1:Clone()
				local effects = {}
				attach0.Parent = Workspace.Terrain
				attach1.Parent = Workspace.Terrain
				for _, effect in next, Bullets[partprop[4]]:GetChildren() do
					if effect:IsA("Beam") or effect:IsA("Trail") then
						local eff = effect:Clone()
						eff.Attachment0 = attach0 --attach1
						eff.Attachment1 = attach1 --attach0
						eff.Parent = Workspace.Terrain
						table.insert(effects, eff)
					end
				end
				local function update(pos, lastpos, w2, t2, motionblurdata)
					--{size, bloom, brightness}
					if motionblurdata then
						local t2 = os.clock()
						local p2 = ptos(camcf, w2)
						local v2
						if t0 then
							v2 = 2 / (t2 - t1) * (p2 - p1) - (p2 - p0) / (t2 - t0)
						else
							v2 = (p2 - p1) / (t2 - t1)
							v1 = v2
						end
						t0, v0, p0 = t1, v1, p1
						t1, v1, p1 = t2, v2, p2
						local dt = t1 - t0
						local m0 = v0.Magnitude
						local m1 = v1.Magnitude
						attach0.Position = camcf * p0
						attach1.Position = camcf * p1
						if m0 > 1.0E-8 then
							attach0.Axis = vtws(camcf, v0 / m0)
						end
						if m1 > 1.0E-8 then
							attach1.Axis = vtws(camcf, v1 / m1)
						end
						local dist0 = -p0.z
						local dist1 = -p1.z
						if dist0 < 0 then
							dist0 = 0
						end
						if dist1 < 0 then
							dist1 = 0
						end
						local w0 = motionblurdata.size + motionblurdata.bloom * dist0
						local w1 = motionblurdata.size + motionblurdata.bloom * dist1
						local l = ((p1 - p0)*v3(1, 1, 0)).Magnitude
						local tr = 1 - 4 * motionblurdata.size * motionblurdata.size / ((w0 + w1) * (2 * l + w0 + w1)) * motionblurdata.brightness
						for _, effect in next, effects do
							effect.CurveSize0 = dt / 3 * m0
							effect.CurveSize1 = dt / 3 * m1
							effect.Width0 = w0
							effect.Width1 = w1
							effect.Transparency = ns(tr)
						end
					else
						if (pos - lastpos).Magnitude > 0 then
							local rotation = CFrame.new(lastpos, pos) - lastpos
							local offset = CFrame.Angles(0, math.pi / 2, 0)
							attach0.CFrame = CFrame.new(pos) * rotation * offset
							attach1.CFrame = CFrame.new(lastpos, pos) * offset
						end					
					end
				end
				local function remove()
					attach0:Destroy()
					attach1:Destroy()
					for _, effect in next, effects do
						effect:Destroy()
					end
				end
				local part
				if partprop[5] ~= "None" then
					part = Projectiles[partprop[5]]:Clone()
					part.CFrame = CFrame.new(partprop[2], partprop[2] + partprop[3])
					part.Parent = camera

					for _,child in pairs(part:GetDescendants()) do
						if child:IsA("ParticleEmitter") then
							child.Enabled = true
						elseif child:IsA("Sound") then
							child:Play()
						elseif child:IsA("PointLight") then
							child.Enabled = true
						elseif child:IsA("Trail") then
							child.Enabled = true
						elseif child:IsA("Beam") then
							child.Enabled = true
						end
					end
				end
				local function updatepart(position, velocity, offset, t, av, rot, hitscan)
					if part then
						if partprop[6] then
							if not hitscan then
								if ricochetdata[2] then
									part.CFrame = CFrame.new(position + offset) * Math.FromAxisAngle(t * av) * rot
								else
									if ricochetdata[1] > 0  then
										part.CFrame = CFrame.new(position + offset) * Math.FromAxisAngle(t * av) * rot
									else
										part.CFrame = CFrame.new(position, position + velocity) * CFrame.Angles(math.rad(-360 * (os.clock() * partprop[7] - math.floor(os.clock() * partprop[7]))), math.rad(-360 * (os.clock() * partprop[8] - math.floor(os.clock() * partprop[8]))), math.rad(-360 * (os.clock() * partprop[9] - math.floor(os.clock() * partprop[9]))))
									end
								end							
							else
								part.CFrame = CFrame.new(position, position + velocity) * CFrame.Angles(math.rad(-360 * (os.clock() * partprop[7] - math.floor(os.clock() * partprop[7]))), math.rad(-360 * (os.clock() * partprop[8] - math.floor(os.clock() * partprop[8]))), math.rad(-360 * (os.clock() * partprop[9] - math.floor(os.clock() * partprop[9]))))
							end
						else
							part.CFrame = CFrame.new(position, position + velocity)
						end
					end
				end
				local function removepart()
					if part then
						part.Transparency = 1
						for _,child in pairs(part:GetDescendants()) do
							if (child:IsA("BasePart") or child:IsA("Decal") or child:IsA("Texture")) then
								child.Transparency = 1
							elseif child:IsA("ParticleEmitter") then
								child.Enabled = false
							elseif child:IsA("Sound") then
								child:Stop()
							elseif child:IsA("PointLight") then
								child.Enabled = false
						--[[elseif child:IsA("Trail") then -- There is a case that trail is barely visible when projectile hits (especially at high speed). So I marked it as comment.
							child.Enabled = false]]
							elseif child:IsA("Beam") then
								child.Enabled = false
							end
						end
						Debris:AddItem(part, 10)
					end
				end
				local hitboxattachments
				if part then
					for _, v in next, part:GetDescendants() do
						if v:IsA("Attachment") then
							if v.Name == "HitboxAttachment" then
								if hitboxattachments ~= nil then
									table.insert(hitboxattachments, v)
									if DebugVisualization then
										local trail = Instance.new('Trail')
										local trailattachment = Instance.new('Attachment')

										trailattachment.Name = "DebugAttachment"
										trailattachment.Position = v.Position - Vector3.new(0, 0, 0.1)

										trail.Color = ColorSequence.new(Color3.new(1, 0, 0))
										trail.LightEmission = 1
										trail.Transparency = NumberSequence.new({
											NumberSequenceKeypoint.new(0, 0),
											NumberSequenceKeypoint.new(0.5, 0),
											NumberSequenceKeypoint.new(1, 1)
										})
										trail.FaceCamera = true
										trail.Lifetime = 1

										trail.Attachment0 = v
										trail.Attachment1 = trailattachment

										trail.Parent = trailattachment
										trailattachment.Parent = v.Parent
									end
								else
									hitboxattachments = {}
									table.insert(hitboxattachments, v)
									if DebugVisualization then
										local trail = Instance.new('Trail')
										local trailattachment = Instance.new('Attachment')

										trailattachment.Name = "DebugAttachment"
										trailattachment.Position = v.Position - Vector3.new(0, 0, 0.1)

										trail.Color = ColorSequence.new(Color3.new(1, 0, 0))
										trail.LightEmission = 1
										trail.Transparency = NumberSequence.new({
											NumberSequenceKeypoint.new(0, 0),
											NumberSequenceKeypoint.new(0.5, 0),
											NumberSequenceKeypoint.new(1, 1)
										})
										trail.FaceCamera = true
										trail.Lifetime = 10

										trail.Attachment0 = v
										trail.Attachment1 = trailattachment

										trail.Parent = trailattachment
										trailattachment.Parent = v.Parent
									end
								end
							end
						end
					end
				end
				return effects, update, remove, part, updatepart, removepart, hitboxattachments
			end
		end
		local function GetVisualizationContainer()
			local fcVisualizationObjects = Workspace.Terrain:FindFirstChild("VisualizationObjects")
			if fcVisualizationObjects ~= nil then
				return fcVisualizationObjects
			end

			fcVisualizationObjects = Instance.new("Folder")
			fcVisualizationObjects.Name = "VisualizationObjects"
			fcVisualizationObjects.Archivable = false -- TODO: Keep this as-is? You can't copy/paste it if this is false. I have it false so that it doesn't linger in studio if you save with the debug data in there.
			fcVisualizationObjects.Parent = Workspace.Terrain
			return fcVisualizationObjects
		end
		function DbgVisualizeCone(atCF, color)
			if DebugVisualization ~= true then return end
			local adornment = Instance.new("ConeHandleAdornment")
			adornment.Adornee = Workspace.Terrain
			adornment.CFrame = atCF
			adornment.AlwaysOnTop = true
			adornment.Height = 1
			adornment.Color3 = color
			adornment.Radius = 0.05
			adornment.Transparency = 0.5
			adornment.Parent = GetVisualizationContainer()
			Debris:AddItem(adornment, 30)
			return adornment
		end
		function DbgVisualizeSphere(atCF, color)
			if DebugVisualization ~= true then return end
			local adornment = Instance.new("SphereHandleAdornment")
			adornment.Adornee = Workspace.Terrain
			adornment.CFrame = atCF
			adornment.Radius = 0.15
			adornment.Transparency = 0.5
			adornment.Color3 = color
			adornment.Parent = GetVisualizationContainer()
			Debris:AddItem(adornment, 30)
			return adornment
		end
		local function castwithwhitelist(origin, direction, whitelist, ignoreWater)
			if not whitelist or typeof(whitelist) ~= "table" then
				-- This array is faulty.
				error("Call in castwithwhitelist failed! whitelist table is either nil, or is not actually a table.", 0)
			end
			local castRay = Ray.new(origin, direction)
			-- Now here's something bizarre: FindPartOnRay and FindPartOnRayWithIgnoreList have a "terrainCellsAreCubes" boolean before ignoreWater. FindPartOnRayWithWhitelist, on the other hand, does not!
			return Workspace:FindPartOnRayWithWhitelist(castRay, whitelist, ignoreWater)
		end
		local function castwithblacklist(origin, direction, blacklist, ignoreWater, character, friendlyFire)
			if not blacklist or typeof(blacklist) ~= "table" then
				-- This array is faulty
				error("Call in castwithblacklist failed! blacklist table is either nil, or is not actually a table.", 0)
			end
			local castRay = Ray.new(origin, direction)
			local hitPart, hitPoint, hitNormal, hitMaterial = nil, origin + direction, Vector3.new(0,1,0), Enum.Material.Air
			local success = false	
			repeat
				hitPart, hitPoint, hitNormal, hitMaterial = Workspace:FindPartOnRayWithIgnoreList(castRay, blacklist, false, ignoreWater)
				if hitPart then
					local target = hitPart:FindFirstAncestorOfClass("Model")
					local targetHumanoid = target and target:FindFirstChildOfClass("Humanoid")
					if (hitPart.Transparency > 0.75
						or hitPart.Name == "Missile"
						or hitPart.Name == "Handle"
						or hitPart.Name == "Effect"
						or hitPart.Name == "Bullet"
						or hitPart.Name == "Laser"
						or string.lower(hitPart.Name) == "water"
						or hitPart.Name == "Rail"
						or hitPart.Name == "Arrow"
						or (targetHumanoid and (targetHumanoid.Health == 0 or not DamageModule.CanDamage(target, character, friendlyFire)))
						--[[or (hitPart.Parent:FindFirstChildOfClass("Tool") or hitPart.Parent.Parent:FindFirstChildOfClass("Tool"))]]) then
						insert(blacklist, hitPart)
						success	= false
					else
						success	= true
					end
				else
					success	= true
				end
			until success
			return hitPart, hitPoint, hitNormal, hitMaterial
		end
		local function particlewind(t, p)
			local xy, yz, zx = p.x + p.y, p.y + p.z, p.z + p.x
			return Vector3.new(
				(math.sin(yz + t * 2) + math.sin(yz + t)) / 2 + math.sin((yz + t) / 10) / 2,
				(math.sin(zx + t * 2) + math.sin(zx + t)) / 2 + math.sin((zx + t) / 10) / 2,
				(math.sin(xy + t * 2) + math.sin(xy + t)) / 2 + math.sin((xy + t) / 10) / 2
			)
		end
		function ParticleFramework.new(prop)
			local self = {}
			local position = prop.position or nv
			local velocity = prop.velocity or nv
			local acceleration = prop.acceleration or nv
			local visible = prop.visible --or true

			local motionblur = prop.motionblur or false
			local size = prop.size or 1
			local bloom = prop.bloom or 0
			local brightness = prop.brightness or 1

			local windspeed = prop.windspeed or 10
			local windresistance = prop.windresistance or 1
			local cancollide = prop.cancollide == nil or prop.cancollide
			local penetrationtype = prop.penetrationtype or "WallPenetration"
			local penetrationdepth = prop.penetrationdepth or 0
			local penetrationamount = prop.penetrationamount or 0
			local ricochetamount = prop.ricochetamount or 0 
			local bounceelasticity = prop.bounceelasticity or 0.3
			local frictionconstant = prop.frictionconstant or 0.08
			local noexplosionwhilebouncing = prop.noexplosionwhilebouncing or false
			local stopbouncingonhithumanoid = prop.stopbouncingonhithumanoid or false
			local superricochet = prop.superricochet or false
			local visualorigin = prop.visualorigin or position
			local visualdirection = prop.visualdirection or nv
			local visualoffset = visualorigin - position
			local penetrationpower = penetrationdepth
			local penetrationcount = penetrationamount
			local currentbounces = ricochetamount
			local reallife = prop.life or 10
			local life = os.clock() + reallife
			local bullettype = prop.bullettype or "None"
			local projectiletype = prop.projectiletype or "Normal"
			local canspinpart = prop.canspinpart or false
			local spinx = prop.spinx or 0
			local spiny = prop.spiny or 0 
			local spinz = prop.spinz or 0
			local homing = prop.homing or false
			local homingdistance = prop.homingdistance or 250
			local turnratepersecond = prop.turnratepersecond or 1
			local homethroughwall = prop.homethroughwall or false
			local lockononhovering = prop.lockononhovering or false
			local lockedentity = prop.lockedentity or nil
			local toucheventontimeout = prop.toucheventontimeout or false
			local hitscan = prop.hitscan or false
			local character = prop.character or nil
			local friendlyfire = prop.friendlyfire or false
			local physignore = prop.physicsignore or (not IsServer and {
				camera,
			} or {})
			local onstep = prop.onstep
			local ontouch = prop.ontouch
			local onenter = prop.onenter
			local onexit = prop.onexit
			local onbounce = prop.onbounce
			local initpenetrationdepth = penetrationdepth
			local lastbounce = false
			local wind
			local h, p, n, m = nil, visualorigin + visualdirection, Vector3.new(0,1,0), Enum.Material.Air
			function self:remove()
				removelist[self] = true
			end
			local part
			local effects, effectupdate, effectremove, projectile, projectileupdate, projectileremove, hitboxattachments
			local t0
			local av0
			local rot0
			local offset
			local lastposition
			local lastpositions = {}
			local humanoids = {}
			local humanoid
			if character then
				humanoid = character:FindFirstChildOfClass("Humanoid")
			end
			local initalvelocity = velocity
			local distancefromvelocityandlifetime = (initalvelocity.Magnitude * reallife)
			local tweentable = {}
			local motionblurdata = motionblur and {size = size, bloom = bloom, brightness = brightness} or nil
			if not IsServer then
				effects, effectupdate, effectremove, projectile, projectileupdate, projectileremove, hitboxattachments = neweffect(position + visualoffset, {visible, visualorigin, visualdirection, bullettype, projectiletype, canspinpart, spinx, spiny, spinz}, {ricochetamount, superricochet})	
				self.effects = effects
				self.effectupdate = effectupdate
				self.effectremove = effectremove
				self.projectile = projectile
				self.projectileupdate = projectileupdate
				self.projectileremove = projectileremove
				t0 = os.clock()
				av0 = Vector3.new(spinx, spiny, spinz)
				rot0 = projectile and (projectile.CFrame - projectile.CFrame.p) or CFrame.new()
				offset = Vector3.new()	
			end
			local function populatehumanoids(mdl)
				if mdl.ClassName == "Humanoid" then
					if DamageModule.CanDamage(mdl.Parent, character, friendlyfire) then
						table.insert(humanoids, mdl)
					end
				end
				for i2, mdl2 in ipairs(mdl:GetChildren()) do
					populatehumanoids(mdl2)
				end
			end
			local function findnearestentity(position)
				humanoids = {}
				populatehumanoids(Workspace)
				local dist = homingdistance
				local targetModel = nil
				local targetHumanoid = nil
				local targetTorso = nil
				for i, v in ipairs(humanoids) do
					local torso = v.Parent:FindFirstChild("HumanoidRootPart") or v.Parent:FindFirstChild("Torso") or v.Parent:FindFirstChild("UpperTorso")
					if v and torso then
						if (torso.Position - position).Magnitude < (dist + (torso.Size.Magnitude / 2.5)) and v.Health > 0 then
							if not homethroughwall then
								local hit, pos, normal, material = castwithblacklist(position, (torso.CFrame.p - position).Unit * 999, physignore, true, character, friendlyfire)
								if hit then
									if hit:isDescendantOf(v.Parent) then
										if DamageModule.CanDamage(v.Parent, character, friendlyfire) then
											targetModel = v.Parent
											targetHumanoid = v
											targetTorso = torso
											dist = (position - torso.Position).Magnitude
										end
									end
								end
							else
								if DamageModule.CanDamage(v.Parent, character, friendlyfire) then
									targetModel = v.Parent
									targetHumanoid = v
									targetTorso = torso
									dist = (position - torso.Position).Magnitude
								end
							end						
						end
					end	
				end
				return targetModel, targetHumanoid, targetTorso
			end
			local function casthitscan(origin, direction, distance)
				local hit, enterpoint, norm, material = castwithblacklist(origin, direction * distance, physignore, true, character, friendlyfire)
				if not IsServer then
					insert(tweentable, {
						direction = CFrame.new(origin, enterpoint),
						s = 0,
						st = os.clock(),
						ready = false,
						l = (origin - enterpoint).Magnitude,
					})				
				end
				if hit then
					local target = hit:FindFirstAncestorOfClass("Model")
					local targetHumanoid = target and target:FindFirstChildOfClass("Humanoid")
					if ricochetamount > 0 then
						if currentbounces > 0 then
							local newdir = direction - (2 * direction:Dot(norm) * norm)
							currentbounces = currentbounces - 1
							if stopbouncingonhithumanoid then
								if targetHumanoid and targetHumanoid.Health > 0 then
									position = enterpoint
									velocity = direction.Unit * initalvelocity.Magnitude
									if ontouch then
										ontouch(part, hit, enterpoint, norm, material)
									end
									if not IsServer then
										DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
										DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
									else
										removelist[self] = true
									end
								else
									position = enterpoint
									velocity = newdir.Unit * initalvelocity.Magnitude
									if onbounce then
										onbounce(part, hit, enterpoint, norm, material, noexplosionwhilebouncing)
									end
									if not IsServer then
										DbgVisualizeSphere(CFrame.new(enterpoint), Color3.fromRGB(245, 205, 48))
										DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.fromRGB(245, 205, 48))	
									end								
									casthitscan(enterpoint, newdir, distance)
								end
							else
								position = enterpoint
								velocity = newdir.Unit * initalvelocity.Magnitude
								if onbounce then
									onbounce(part, hit, enterpoint, norm, material, noexplosionwhilebouncing)
								end
								if not IsServer then
									DbgVisualizeSphere(CFrame.new(enterpoint), Color3.fromRGB(245, 205, 48))
									DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.fromRGB(245, 205, 48))
								end								
								casthitscan(enterpoint, newdir, distance)
							end
						else
							position = enterpoint
							velocity = direction.Unit * initalvelocity.Magnitude
							if ontouch then
								ontouch(part, hit, enterpoint, norm, material)
							end
							if not IsServer then
								DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
								DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
							else
								removelist[self] = true
							end
						end
					else
						position = enterpoint
						velocity = direction.Unit * initalvelocity.Magnitude
						if penetrationtype == "WallPenetration" then
							local unit = direction
							local maxextent = hit.Size.Magnitude * unit	
							local exithit, exitpoint, exitnorm, exitmaterial = castwithwhitelist(enterpoint + maxextent, -maxextent, {hit}, true)
							local diff = exitpoint - enterpoint
							local dist = dot(unit, diff)
							local exited
							if dist < penetrationdepth then
								if onexit then
									onexit(part, exithit, exitpoint, exitnorm, exitmaterial)
									if not IsServer then
										DbgVisualizeSphere(CFrame.new(exitpoint), Color3.fromRGB(13, 105, 172))
										DbgVisualizeCone(CFrame.new(exitpoint, exitpoint + exitnorm), Color3.fromRGB(13, 105, 172))
									end
								end
								if targetHumanoid and targetHumanoid.Health > 0 then
									insert(physignore, target)
									--physignore[#physignore + 1] = target
								else
									insert(physignore, hit)
									--physignore[#physignore + 1] = hit
								end
								local neworigin = enterpoint + 0.01 * unit
								penetrationdepth = targetHumanoid and penetrationdepth or penetrationdepth - dist
								exited = true
								if onenter then
									onenter(part, hit, enterpoint, norm, material, exited)
								end
								if not IsServer then
									DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(1, 0.2, 0.2))
									DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(1, 0.2, 0.2))
								end							
								casthitscan(neworigin, direction, distance)
							else
								exited = nil
								if ontouch then
									ontouch(part, hit, enterpoint, norm, material)
								end
								if not IsServer then
									DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
									DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
								end
							end
						elseif penetrationtype == "HumanoidPenetration" then
							if penetrationcount > 0 then
								if targetHumanoid and targetHumanoid.Health > 0 then
									insert(physignore, target)
									--physignore[#physignore + 1] = target
									penetrationcount = hit and (penetrationcount - 1) or 0
									if onenter then
										onenter(part, hit, enterpoint, norm, material, nil)
									end
									if not IsServer then
										DbgVisualizeSphere(CFrame.new(enterpoint), Color3.fromRGB(107, 50, 124))
										DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.fromRGB(107, 50, 124))
									end
									casthitscan(enterpoint, direction, distance)
								else
									if ontouch then
										ontouch(part, hit, enterpoint, norm, material)
									end
									if not IsServer then
										DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
										DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
									else
										removelist[self] = true
									end
								end
							else
								if ontouch then
									ontouch(part, hit, enterpoint, norm, material)
								end
								if not IsServer then
									DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
									DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
								else
									removelist[self] = true
								end
							end
						end
					end
				end
			end
			function self.step(dt, time)
				if not hitscan then	
					if life and time > life then
						removelist[self] = true
						if toucheventontimeout then
							if ontouch then
								ontouch(part, h, p, n, m)
							end
							if not IsServer then
								DbgVisualizeSphere(CFrame.new(p), Color3.new(0.2, 1, 0.5))
								DbgVisualizeCone(CFrame.new(p, p + n), Color3.new(0.2, 1, 0.5))
							end
						end
						return
					end
					local t = not IsServer and os.clock() - t0
					lastposition = position
					do
						local position0 = position
						local velocity0 = velocity
						wind = (particlewind(os.clock(), position0) * windspeed - velocity0) * (1 - windresistance)
						local dposition
						if homing and cancollide then
							dposition = dt * velocity0 + dt * dt / 2 * Vector3.new(0, 0, 0)
						else
							dposition = dt * velocity0 + dt * dt / 2 * (acceleration + wind)
						end
						if cancollide then
							if not IsServer and hitboxattachments then
								local hitbyhitboxattachment = false
								local hit, enterpoint, norm, material
								for _, v in next, hitboxattachments do
									if v then
										local attachmentorigin = v.WorldPosition
										local attachmentdir = v.WorldCFrame.LookVector * 1
										hit, enterpoint, norm, material = castwithblacklist(attachmentorigin, attachmentdir, physignore, true, character, friendlyfire)
										if hit and not hitbyhitboxattachment then
											hitbyhitboxattachment = true
											break
										end
									--[[local currentposition = v.WorldPosition
									local lastposition = lastpositions[v] or currentposition
									if currentposition ~= lastposition then
										hit, enterpoint, norm, material = castwithblacklist(currentposition, currentposition - lastposition, physignore, true, character, friendlyfire)
										if hit and not hitbyhitboxattachment then
											hitbyhitboxattachment = true
											break
										end
									end
									lastpositions[v] = currentposition]]
									end
								end
								if hitbyhitboxattachment then
									if hit then
										local target = hit:FindFirstAncestorOfClass("Model")
										local targetHumanoid = target and target:FindFirstChildOfClass("Humanoid")
										if not IsServer then
											t0 = os.clock()
											av0 = norm:Cross(velocity) / 0.2
											rot0 = projectile and (projectile.CFrame - projectile.CFrame.p) or CFrame.new()
											offset = 0.2 * norm
										end
										h = hit
										p = enterpoint
										n = norm
										m = material
										if homing then
											removelist[self] = true
											position = position0 --enterpoint
											if ontouch then
												ontouch(part, hit, enterpoint, norm, material)
											end
											if not IsServer then
												DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
												DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
											end
										else
											if superricochet then
											--[[position = enterpoint
											local truevelocity = (velocity0 - 2 * norm:Dot(velocity0) / norm:Dot(norm) * norm)
											velocity = truevelocity + dt * acceleration]]
												local delta = position0 - position --enterpoint - position
												local fix = 1 - 0.001 / delta.Magnitude
												fix = fix < 0 and 0 or fix
												position = position + fix * delta + 0.05 * norm
												--position = enterpoint + norm * 0.0001
												local normvel = Vector3.new().Dot(norm, velocity) * norm
												local tanvel = velocity - normvel
												local geometricdeceleration
												local d1 = -Vector3.new().Dot(norm, acceleration)
												local d2 = -(1 + bounceelasticity) * Vector3.new().Dot(norm, velocity)
												geometricdeceleration = 1 - frictionconstant * (10 * (d1 < 0 and 0 or d1) * dt + (d2 < 0 and 0 or d2)) / tanvel.Magnitude
											--[[if lastbounce then
												geometricdeceleration = 1 - frictionconstant * acceleration.Magnitude * dt / tanvel.Magnitude
											else
												geometricdeceleration = 1 - frictionconstant * (acceleration.Magnitude + (1 + bounceelasticity) * normvel.Magnitude) / tanvel.Magnitude
											end]]
												velocity = (geometricdeceleration < 0 and 0 or geometricdeceleration) * tanvel - bounceelasticity * normvel
												lastbounce = true
												if velocity.Magnitude > 0 then
													if currentbounces > 0 then
														currentbounces = currentbounces - 1
														if stopbouncingonhithumanoid then
															if targetHumanoid and targetHumanoid.Health > 0 then
																removelist[self] = true
																position = enterpoint
																if ontouch then
																	ontouch(part, hit, enterpoint, norm, material)
																end
																if not IsServer then
																	DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
																	DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
																end
															else
																if onbounce then
																	onbounce(part, hit, enterpoint, norm, material, noexplosionwhilebouncing)
																end
																if not IsServer then
																	DbgVisualizeSphere(CFrame.new(enterpoint), Color3.fromRGB(245, 205, 48))
																	DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.fromRGB(245, 205, 48))
																end
															end
														else
															if onbounce then
																onbounce(part, hit, enterpoint, norm, material, noexplosionwhilebouncing)
															end
															if not IsServer then
																DbgVisualizeSphere(CFrame.new(enterpoint), Color3.fromRGB(245, 205, 48))
																DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.fromRGB(245, 205, 48))
															end
														end
													end
												end
											else
												if ricochetamount > 0 then
													if currentbounces > 0 then
													--[[position = enterpoint
													local truevelocity = (velocity0 - 2 * norm:Dot(velocity0) / norm:Dot(norm) * norm)
													velocity = truevelocity + dt * acceleration]]
														local delta = position0 - position --enterpoint - position
														local fix = 1 - 0.001 / delta.Magnitude
														fix = fix < 0 and 0 or fix
														position = position + fix * delta + 0.05 * norm
														--position = enterpoint + norm * 0.0001
														local normvel = Vector3.new().Dot(norm, velocity) * norm
														local tanvel = velocity - normvel
														local geometricdeceleration
														local d1 = -Vector3.new().Dot(norm, acceleration)
														local d2 = -(1 + bounceelasticity) * Vector3.new().Dot(norm, velocity)
														geometricdeceleration = 1 - frictionconstant * (10 * (d1 < 0 and 0 or d1) * dt + (d2 < 0 and 0 or d2)) / tanvel.Magnitude
													--[[if lastbounce then
														geometricdeceleration = 1 - frictionconstant * acceleration.Magnitude * dt / tanvel.Magnitude
													else
														geometricdeceleration = 1 - frictionconstant * (acceleration.Magnitude + (1 + bounceelasticity) * normvel.Magnitude) / tanvel.Magnitude
													end]]
														velocity = (geometricdeceleration < 0 and 0 or geometricdeceleration) * tanvel - bounceelasticity * normvel
														lastbounce = true
														if velocity.Magnitude > 0 then
															currentbounces = currentbounces - 1
															if stopbouncingonhithumanoid then
																if targetHumanoid and targetHumanoid.Health > 0 then
																	removelist[self] = true
																	position = enterpoint
																	if ontouch then
																		ontouch(part, hit, enterpoint, norm, material)
																	end
																	if not IsServer then
																		DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
																		DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
																	end
																else
																	if onbounce then
																		onbounce(part, hit, enterpoint, norm, material, noexplosionwhilebouncing)
																	end
																	if not IsServer then
																		DbgVisualizeSphere(CFrame.new(enterpoint), Color3.fromRGB(245, 205, 48))
																		DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.fromRGB(245, 205, 48))
																	end
																end
															else
																if onbounce then
																	onbounce(part, hit, enterpoint, norm, material, noexplosionwhilebouncing)
																end
																if not IsServer then
																	DbgVisualizeSphere(CFrame.new(enterpoint), Color3.fromRGB(245, 205, 48))
																	DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.fromRGB(245, 205, 48))
																end
															end
														end
													else
														removelist[self] = true
														position = enterpoint
														if ontouch then
															ontouch(part, hit, enterpoint, norm, material)
														end
														if not IsServer then
															DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
															DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
														end
													end
												else
													if penetrationtype == "WallPenetration" then
														local unit = dposition.Unit
														local maxextent = hit.Size.Magnitude * unit
														local exithit, exitpoint, exitnorm, exitmaterial = castwithwhitelist(enterpoint + maxextent, -maxextent, {hit}, true)
														local diff = exitpoint - enterpoint
														local dist = dot(unit, diff)
														local exited
														if dist < penetrationdepth then
															if onexit then
																onexit(part, exithit, exitpoint, exitnorm, exitmaterial)
																if not IsServer then
																	DbgVisualizeSphere(CFrame.new(exitpoint), Color3.fromRGB(13, 105, 172))
																	DbgVisualizeCone(CFrame.new(exitpoint, exitpoint + exitnorm), Color3.fromRGB(13, 105, 172))
																end
															end
															if targetHumanoid and targetHumanoid.Health > 0 then
																insert(physignore, target)
																--physignore[#physignore + 1] = target
															else
																insert(physignore, hit)
																--physignore[#physignore + 1] = hit
															end
															position = position0 + 0.01 * unit --enterpoint + 0.01 * unit
															p = position
															local truedt = dot(dposition, enterpoint - position0) / dot(dposition, dposition) * dt
															velocity = velocity0 + truedt * acceleration
															penetrationdepth = targetHumanoid and penetrationdepth or penetrationdepth - dist
															exited = true
															if onenter then
																onenter(part, hit, enterpoint, norm, material, exited)
															end
															if not IsServer then
																DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(1, 0.2, 0.2))
																DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(1, 0.2, 0.2))
															end
														else
															removelist[self] = true
															position = position0 --enterpoint
															exited = nil
															if ontouch then
																ontouch(part, hit, enterpoint, norm, material)
															end
															if not IsServer then
																DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
																DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
															end
														end
													elseif penetrationtype == "HumanoidPenetration" then
														if penetrationcount > 0 then
															if targetHumanoid and targetHumanoid.Health > 0 then
																insert(physignore, target)
																--physignore[#physignore + 1] = target
												        	--[[position = position0 + dposition
									            			velocity = velocity0 + dt * acceleration
															p = position]]
																penetrationcount = hit and (penetrationcount - 1) or 0
																if onenter then
																	onenter(part, hit, enterpoint, norm, material, nil)
																end
																if not IsServer then
																	DbgVisualizeSphere(CFrame.new(enterpoint), Color3.fromRGB(107, 50, 124))
																	DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.fromRGB(107, 50, 124))
																end
															else
																removelist[self] = true
																position = position0 --enterpoint
																if ontouch then
																	ontouch(part, hit, enterpoint, norm, material)
																end
																if not IsServer then
																	DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
																	DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
																end
															end
														else
															removelist[self] = true
															position = position0 --enterpoint
															if ontouch then
																ontouch(part, hit, enterpoint, norm, material)
															end
															if not IsServer then
																DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
																DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
															end
														end
													end
												end
											end
										end
									end
								else
									if homing then
										if lockononhovering then
											if lockedentity then
												local entityhumanoid = lockedentity:FindFirstChildOfClass("Humanoid")
												if entityhumanoid and entityhumanoid.Health > 0 then
													position = position0 + dposition
													velocity = velocity0 + dt * Vector3.new(0, 0, 0)
													local entitytorso = lockedentity:FindFirstChild("HumanoidRootPart") or lockedentity:FindFirstChild("Torso") or lockedentity:FindFirstChild("UpperTorso")
													local desiredvector = (entitytorso.Position - position).Unit
													local currentvector = velocity.Unit
													local angulardifference = math.acos(desiredvector:Dot(currentvector))
													if angulardifference > 0 then
														local orthovector = currentvector:Cross(desiredvector).Unit
														local angularcorrection = math.min(angulardifference, dt * turnratepersecond)
														velocity = CFrame.fromAxisAngle(orthovector, angularcorrection):vectorToWorldSpace(velocity)
													end
												else
													position = position0 + dposition
													velocity = velocity0 + dt * Vector3.new(0, 0, 0)
												end
											else
												position = position0 + dposition
												velocity = velocity0 + dt * Vector3.new(0, 0, 0)
											end
										else
											local targetentity, targethumanoid, targettorso = findnearestentity(position)
											if targetentity and targethumanoid and targettorso and (humanoid and humanoid.Health > 0) then
												position = position0 + dposition
												velocity = velocity0 + dt * Vector3.new(0, 0, 0)
												local desiredvector = (targettorso.Position - position).Unit
												local currentvector = velocity.Unit
												local angulardifference = math.acos(desiredvector:Dot(currentvector))
												if angulardifference > 0 then
													local orthovector = currentvector:Cross(desiredvector).Unit
													local angularcorrection = math.min(angulardifference, dt * turnratepersecond)
													velocity = CFrame.fromAxisAngle(orthovector, angularcorrection):vectorToWorldSpace(velocity)
												end
											else
												position = position0 + dposition
												velocity = velocity0 + dt * Vector3.new(0, 0, 0)
											end
										end
									else								
										wind = (particlewind(os.clock(), position0) * windspeed - velocity0) * (1 - windresistance)
										position = position0 + dposition
										velocity = velocity0 + dt * (acceleration + wind)
									end
									h = nil
									p = position
									n = Vector3.new(0,1,0)
									m = Enum.Material.Air
									lastbounce = false
								end 
							else
								local hit, enterpoint, norm, material = castwithblacklist(position0, dposition, physignore, true, character, friendlyfire)
								if hit then
									local target = hit:FindFirstAncestorOfClass("Model")
									local targetHumanoid = target and target:FindFirstChildOfClass("Humanoid")
									if not IsServer then
										t0 = os.clock()
										av0 = norm:Cross(velocity) / 0.2
										rot0 = projectile and (projectile.CFrame - projectile.CFrame.p) or CFrame.new()
										offset = 0.2 * norm
									end
									h = hit
									p = enterpoint
									n = norm
									m = material
									if homing then
										removelist[self] = true
										position = enterpoint
										if ontouch then
											ontouch(part, hit, enterpoint, norm, material)
										end
										if not IsServer then
											DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
											DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
										end
									else
										if superricochet then
										--[[position = enterpoint
										local truevelocity = (velocity0 - 2 * norm:Dot(velocity0) / norm:Dot(norm) * norm)
										velocity = truevelocity + dt * acceleration]]
											local delta = enterpoint - position
											local fix = 1 - 0.001 / delta.Magnitude
											fix = fix < 0 and 0 or fix
											position = position + fix * delta + 0.05 * norm
											--position = enterpoint + norm * 0.0001
											local normvel = Vector3.new().Dot(norm, velocity) * norm
											local tanvel = velocity - normvel
											local geometricdeceleration
											local d1 = -Vector3.new().Dot(norm, acceleration)
											local d2 = -(1 + bounceelasticity) * Vector3.new().Dot(norm, velocity)
											geometricdeceleration = 1 - frictionconstant * (10 * (d1 < 0 and 0 or d1) * dt + (d2 < 0 and 0 or d2)) / tanvel.Magnitude
										--[[if lastbounce then
											geometricdeceleration = 1 - frictionconstant * acceleration.Magnitude * dt / tanvel.Magnitude
										else
											geometricdeceleration = 1 - frictionconstant * (acceleration.Magnitude + (1 + bounceelasticity) * normvel.Magnitude) / tanvel.Magnitude
										end]]
											velocity = (geometricdeceleration < 0 and 0 or geometricdeceleration) * tanvel - bounceelasticity * normvel
											lastbounce = true
											if velocity.Magnitude > 0 then
												if currentbounces > 0 then
													currentbounces = currentbounces - 1
													if stopbouncingonhithumanoid then
														if targetHumanoid and targetHumanoid.Health > 0 then
															removelist[self] = true
															position = enterpoint
															if ontouch then
																ontouch(part, hit, enterpoint, norm, material)
															end
															if not IsServer then
																DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
																DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
															end
														else
															if onbounce then
																onbounce(part, hit, enterpoint, norm, material, noexplosionwhilebouncing)
															end
															if not IsServer then
																DbgVisualizeSphere(CFrame.new(enterpoint), Color3.fromRGB(245, 205, 48))
																DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.fromRGB(245, 205, 48))
															end
														end
													else
														if onbounce then
															onbounce(part, hit, enterpoint, norm, material, noexplosionwhilebouncing)
														end
														if not IsServer then
															DbgVisualizeSphere(CFrame.new(enterpoint), Color3.fromRGB(245, 205, 48))
															DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.fromRGB(245, 205, 48))
														end
													end
												end
											end
										else
											if ricochetamount > 0 then
												if currentbounces > 0 then
												--[[position = enterpoint
												local truevelocity = (velocity0 - 2 * norm:Dot(velocity0) / norm:Dot(norm) * norm)
												velocity = truevelocity + dt * acceleration]]
													local delta = enterpoint - position
													local fix = 1 - 0.001 / delta.Magnitude
													fix = fix < 0 and 0 or fix
													position = position + fix * delta + 0.05 * norm
													--position = enterpoint + norm * 0.0001
													local normvel = Vector3.new().Dot(norm, velocity) * norm
													local tanvel = velocity - normvel
													local geometricdeceleration
													local d1 = -Vector3.new().Dot(norm, acceleration)
													local d2 = -(1 + bounceelasticity) * Vector3.new().Dot(norm, velocity)
													geometricdeceleration = 1 - frictionconstant * (10 * (d1 < 0 and 0 or d1) * dt + (d2 < 0 and 0 or d2)) / tanvel.Magnitude
												--[[if lastbounce then
													geometricdeceleration = 1 - frictionconstant * acceleration.Magnitude * dt / tanvel.Magnitude
												else
													geometricdeceleration = 1 - frictionconstant * (acceleration.Magnitude + (1 + bounceelasticity) * normvel.Magnitude) / tanvel.Magnitude
												end]]
													velocity = (geometricdeceleration < 0 and 0 or geometricdeceleration) * tanvel - bounceelasticity * normvel
													lastbounce = true
													if velocity.Magnitude > 0 then
														currentbounces = currentbounces - 1
														if stopbouncingonhithumanoid then
															if targetHumanoid and targetHumanoid.Health > 0 then
																removelist[self] = true
																position = enterpoint
																if ontouch then
																	ontouch(part, hit, enterpoint, norm, material)
																end
																if not IsServer then
																	DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
																	DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
																end
															else
																if onbounce then
																	onbounce(part, hit, enterpoint, norm, material, noexplosionwhilebouncing)
																end
																if not IsServer then
																	DbgVisualizeSphere(CFrame.new(enterpoint), Color3.fromRGB(245, 205, 48))
																	DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.fromRGB(245, 205, 48))
																end
															end
														else
															if onbounce then
																onbounce(part, hit, enterpoint, norm, material, noexplosionwhilebouncing)
															end
															if not IsServer then
																DbgVisualizeSphere(CFrame.new(enterpoint), Color3.fromRGB(245, 205, 48))
																DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.fromRGB(245, 205, 48))
															end
														end
													end
												else
													removelist[self] = true
													position = enterpoint
													if ontouch then
														ontouch(part, hit, enterpoint, norm, material)
													end
													if not IsServer then
														DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
														DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
													end
												end
											else
												if penetrationtype == "WallPenetration" then
													local unit = dposition.Unit
													local maxextent = hit.Size.Magnitude * unit	
													local exithit, exitpoint, exitnorm, exitmaterial = castwithwhitelist(enterpoint + maxextent, -maxextent, {hit}, true)
													local diff = exitpoint - enterpoint
													local dist = dot(unit, diff)
													local exited
													if dist < penetrationdepth then
														if onexit then
															onexit(part, exithit, exitpoint, exitnorm, exitmaterial)
															if not IsServer then
																DbgVisualizeSphere(CFrame.new(exitpoint), Color3.fromRGB(13, 105, 172))
																DbgVisualizeCone(CFrame.new(exitpoint, exitpoint + exitnorm), Color3.fromRGB(13, 105, 172))
															end
														end
														if targetHumanoid and targetHumanoid.Health > 0 then
															insert(physignore, target)
															--physignore[#physignore + 1] = target
														else
															insert(physignore, hit)
															--physignore[#physignore + 1] = hit
														end
														position = enterpoint + 0.01 * unit
														p = position
														local truedt = dot(dposition, enterpoint - position0) / dot(dposition, dposition) * dt
														velocity = velocity0 + truedt * acceleration
														penetrationdepth = targetHumanoid and penetrationdepth or penetrationdepth - dist
														exited = true
														if onenter then
															onenter(part, hit, enterpoint, norm, material, exited)
														end
														if not IsServer then
															DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(1, 0.2, 0.2))
															DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(1, 0.2, 0.2))
														end
													else
														removelist[self] = true
														position = enterpoint
														exited = nil
														if ontouch then
															ontouch(part, hit, enterpoint, norm, material)
														end
														if not IsServer then
															DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
															DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
														end
													end
												elseif penetrationtype == "HumanoidPenetration" then
													if penetrationcount > 0 then
														if targetHumanoid and targetHumanoid.Health > 0 then
															insert(physignore, target)
															--physignore[#physignore + 1] = target
												        --[[position = position0 + dposition
									            		velocity = velocity0 + dt * acceleration
														p = position]]
															penetrationcount = hit and (penetrationcount - 1) or 0
															if onenter then
																onenter(part, hit, enterpoint, norm, material, nil)
															end
															if not IsServer then
																DbgVisualizeSphere(CFrame.new(enterpoint), Color3.fromRGB(107, 50, 124))
																DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.fromRGB(107, 50, 124))
															end
														else
															removelist[self] = true
															position = enterpoint
															if ontouch then
																ontouch(part, hit, enterpoint, norm, material)
															end
															if not IsServer then
																DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
																DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
															end
														end
													else
														removelist[self] = true
														position = enterpoint
														if ontouch then
															ontouch(part, hit, enterpoint, norm, material)
														end
														if not IsServer then
															DbgVisualizeSphere(CFrame.new(enterpoint), Color3.new(0.2, 1, 0.5))
															DbgVisualizeCone(CFrame.new(enterpoint, enterpoint + norm), Color3.new(0.2, 1, 0.5))
														end
													end
												end
											end
										end
									end
								else
									if homing then
										if lockononhovering then
											if lockedentity then
												local entityhumanoid = lockedentity:FindFirstChildOfClass("Humanoid")
												if entityhumanoid and entityhumanoid.Health > 0 then
													position = position0 + dposition
													velocity = velocity0 + dt * Vector3.new(0, 0, 0)
													local entitytorso = lockedentity:FindFirstChild("HumanoidRootPart") or lockedentity:FindFirstChild("Torso") or lockedentity:FindFirstChild("UpperTorso")
													local desiredvector = (entitytorso.Position - position).Unit
													local currentvector = velocity.Unit
													local angulardifference = math.acos(desiredvector:Dot(currentvector))
													if angulardifference > 0 then
														local orthovector = currentvector:Cross(desiredvector).Unit
														local angularcorrection = math.min(angulardifference, dt * turnratepersecond)
														velocity = CFrame.fromAxisAngle(orthovector, angularcorrection):vectorToWorldSpace(velocity)
													end
												else
													position = position0 + dposition
													velocity = velocity0 + dt * Vector3.new(0, 0, 0)
												end
											else
												position = position0 + dposition
												velocity = velocity0 + dt * Vector3.new(0, 0, 0)
											end
										else
											local targetentity, targethumanoid, targettorso = findnearestentity(position)
											if targetentity and targethumanoid and targettorso and (humanoid and humanoid.Health > 0) then
												position = position0 + dposition
												velocity = velocity0 + dt * Vector3.new(0, 0, 0)
												local desiredvector = (targettorso.Position - position).Unit
												local currentvector = velocity.Unit
												local angulardifference = math.acos(desiredvector:Dot(currentvector))
												if angulardifference > 0 then
													local orthovector = currentvector:Cross(desiredvector).Unit
													local angularcorrection = math.min(angulardifference, dt * turnratepersecond)
													velocity = CFrame.fromAxisAngle(orthovector, angularcorrection):vectorToWorldSpace(velocity)
												end
											else
												position = position0 + dposition
												velocity = velocity0 + dt * Vector3.new(0, 0, 0)
											end
										end
									else
										wind = (particlewind(os.clock(), position0) * windspeed - velocity0) * (1 - windresistance)
										position = position0 + dposition
										velocity = velocity0 + dt * (acceleration + wind)
									end
									h = nil
									p = position
									n = Vector3.new(0,1,0)
									m = Enum.Material.Air
									lastbounce = false
								end
							end
						else
							wind = (particlewind(os.clock(), position0) * windspeed - velocity0) * (1 - windresistance)
							position = position0 + dposition
							velocity = velocity0 + dt * (acceleration + wind)
							h = nil
							p = position
							n = Vector3.new(0,1,0)
							m = Enum.Material.Air
						end
					end
					if not IsServer then
						if onstep then
							onstep(part, dt)
						end
						effectupdate(position + visualoffset, lastposition, position + visualoffset, time, motionblurdata)
						projectileupdate(position, velocity, offset, t, av0, rot0, hitscan)
					end				
				end		
			end
			particles[self] = true
			local get = {}
			local set = {}
			local meta = {}
			function meta.__index(table, index)
				return get[index]()
			end
			function meta.__newindex(table, index, value)
				return set[index](value)
			end
			function get.position()
				return position
			end
			function get.velocity()
				return velocity
			end
			function get.acceleration()
				return acceleration
			end
			function get.cancollide()
				return cancollide
			end
			function set.size(newsize)
				size = newsize
			end
			function set.bloom(newbloom)
				bloom = newbloom
			end
			function set.brightness(newbrightness)
				brightness = newbrightness
			end
			function get.life()
				return life - os.clock()
			end
			function get.distance()
				return 1
			end
			function get.hitwall()
				return penetrationdepth ~= initpenetrationdepth
			end
			function get.penetrationcount()
				return penetrationcount
			end
			function get.currentbounces()
				return currentbounces
			end
			function set.position(p)
				position = p
			end
			function set.velocity(v)
				velocity = v
			end
			function set.acceleration(a)
				acceleration = a
			end
			function set.cancollide(newcancollide)
				cancollide = newcancollide
			end
			function set.life(newlife)
				life = os.clock() + newlife
			end
			part = setmt(self, meta)
			if prop.dt then
				self.step(prop.dt, os.clock())
			end
			if hitscan then
				casthitscan(position, velocity.Unit, distancefromvelocityandlifetime)
				if not IsServer then
					Thread:Spawn(function()
						for i, v in pairs(tweentable) do
							while not v.ready do
								--Thread:Wait()
								TargetEvent:Wait()
								local et = os.clock() - v.st
								local new = initalvelocity.Magnitude * v.s
								if v.s >= 0 then
									local fd = math.min(new, v.l)
									position = v.direction * Vector3.new(0, 0, -fd)
									velocity = v.direction.LookVector * initalvelocity.Magnitude
									if onstep then
										onstep(part, et)
									end								
									effectupdate(position + visualoffset, lastposition, position + visualoffset, time, motionblurdata)
									projectileupdate(position, v.direction.LookVector, nil, nil, nil, nil, hitscan)
									v.ready = fd >= v.l
								end
								v.s = v.s + et							
							end
						end
						removelist[self] = true
					end)
				end	
			end
			return part
		end
		function ParticleFramework.step(dt)
			local newtime = os.clock()
			local dt = newtime - time
			time = newtime
			camcf = not IsServer and camera.CoordinateFrame
			for p in next, particles, nil do
				if removelist[p] then
					removelist[p] = nil
					particles[p] = nil
					if not IsServer then
						p.effectremove()
						p.projectileremove()
					end
				else
					p.step(dt, time)
				end
			end
		end
		function ParticleFramework:reset()
			if not IsServer then
				for p in next, particles, nil do
					p.effectremove()
					p.projectileremove()
				end
			end
			particles = {}
			removelist = {}
		end
	end

	TargetEvent:Connect(function(dt)
		ParticleFramework.step(dt)
	end)

	return ParticleFramework
end

Modules.DamageModule = function()
	local module = {}

	local Players = game:GetService("Players")

	module.CanDamage = function(targetObj, taggerObj, friendlyFire)
		local humanoid = targetObj:FindFirstChildOfClass("Humanoid")
		if taggerObj and humanoid then
			if friendlyFire then
				return true
			else
				local player = Players:GetPlayerFromCharacter(taggerObj)
				local p = Players:GetPlayerFromCharacter(targetObj)
				if p and player then
					if p == player then
						return false
					else
						if p.Neutral or player.Neutral then
							return true
						elseif p.TeamColor ~= player.TeamColor then
							return true
						end
					end
				else
					local targetTEAM = targetObj:FindFirstChild("TEAM")
					local TEAM = taggerObj:FindFirstChild("TEAM")
					if TEAM and targetTEAM then
						if targetTEAM.Value ~= TEAM.Value then
							return true
						else
							return false
						end
					else
						return true					
					end
				end
			end
		end
		return false
	end

	return module
end

Modules.Utilities = function()
	local Utils = {}
	
	Utils.Math = function()
		local Math = {}

		local function ToQuaternion(c)
			local x, y, z,
			xx, yx, zx,
			xy, yy, zy,
			xz, yz, zz = CFrame.new().components(c)
			local tr = xx + yy + zz
			if tr > 2.99999 then
				return x, y, z, 0, 0, 0, 1
			elseif tr > -0.99999 then
				local m = 2 * (tr + 1) ^ 0.5
				return x, y, z,
				(yz - zy) / m,
				(zx - xz) / m,
				(xy - yx) / m,
				m / 4
			else
				local qx = xx + yx + zx + 1
				local qy = xy + yy + zy + 1
				local qz = xz + yz + zz + 1
				local m	= (qx * qx + qy * qy + qz * qz) ^ 0.5
				return x, y, z, qx / m, qy / m, qz / m, 0
			end
		end

		function Math.Randomize(value)
			return (0.5 - math.random()) * 2 * value
		end

		function Math.Randomize2(min, max, accuracy)
			local inverse = 1 / (accuracy or 1)
			return (math.random(min * inverse, max * inverse) / inverse)
		end

		function Math.Lerp(a, b, t)
			return a + (b - a) * t
		end

		function Math.ToQuaternion(c)
			ToQuaternion(c)
		end

		function Math.Interpolator(c0, c1)
			if c1 then
				local x0, y0, z0, qx0, qy0, qz0, qw0 = ToQuaternion(c0)
				local x1, y1, z1, qx1, qy1, qz1, qw1 = ToQuaternion(c1)
				local x, y, z = x1 - x0, y1 - y0, z1 - z0
				local c = qx0 * qx1 + qy0 * qy1 + qz0 * qz1 + qw0 * qw1
				if c < 0 then
					qx0, qy0, qz0, qw0 = -qx0, -qy0, -qz0, -qw0
				end
				if c < 0.9999 then
					local s = (1 - c * c) ^ 0.5
					local th = math.acos(c)
					return function(t)
						local s0 = math.sin(th * (1 - t)) / s
						local s1 = math.sin(th * t) / s
						return CFrame.new(
							x0 + t * x,
							y0 + t * y,
							z0 + t * z,
							s0 * qx0 + s1 * qx1,
							s0 * qy0 + s1 * qy1,
							s0 * qz0 + s1 * qz1,
							s0 * qw0 + s1 * qw1
						)
					end
				else
					return function(t)
						return CFrame.new(x0 + t * x, y0 + t * y, z0 + t * z, qx1, qy1, qz1, qw1)
					end
				end
			else
				local x, y, z, qx, qy, qz, qw = ToQuaternion(c0)
				if qw < 0.9999 then
					local s = (1 - qw * qw) ^ 0.5
					local th = math.acos(qw)
					return function(t)
						local s1 = math.sin(th * t) / s
						return CFrame.new(
							t * x,
							t * y,
							t * z,
							s1 * qx,
							s1 * qy,
							s1 * qz,
							math.sin(th * (1 - t)) / s + s1 * qw
						)
					end
				else
					return function(t)
						return CFrame.new(t * x, t * y, t * z, qx, qy, qz, qw)
					end
				end
			end
		end

		function Math.FromAxisAngle(x, y, z)
			if not y then
				x, y, z = x.X, x.Y, x.Z
			end
			local m = (x * x + y * y + z * z) ^ 0.5
			if m > 1e-5 then
				local si = math.sin(m / 2) / m
				return CFrame.new(0, 0, 0, si * x, si * y, si * z, math.cos(m / 2))
			else
				return CFrame.new()
			end
		end

		return Math
	end
	
	Utils.ProjectileMotion = function()
		local module = {}

		function module.CalculateBeamProjectile(x0, v0, t1, gravity)
			gravity = gravity or Vector3.new(0, 0, 0)

			--Calculate the bezier points.
			local c = 0.5 * 0.5 * 0.5
			local p3 = 0.5 * gravity * t1 * t1 + v0 * t1 + x0
			local p2 = p3 - (gravity * t1 * t1 + v0 * t1) / 3
			local p1 = (c * gravity * t1 * t1 + 0.5 * v0 * t1 + x0 - c * (x0 + p3)) / (3 * c) - p2

			--The curve sizes.
			local curve0 = (p1 - x0).Magnitude
			local curve1 = (p2 - p3).Magnitude

			--Build the world CFrames for the attachments.
			local b = (x0 - p3).Unit
			local r1 = (p1 - x0).Unit
			local u1 = r1:Cross(b).Unit
			local r2 = (p2 - p3).Unit
			local u2 = r2:Cross(b).Unit
			b = u1:Cross(r1).Unit

			local cf1 = CFrame.new(
				x0.x, x0.y, x0.z,
				r1.x, u1.x, b.x,
				r1.y, u1.y, b.y,
				r1.z, u1.z, b.z
			)

			local cf2 = CFrame.new(
				p3.x, p3.y, p3.z,
				r2.x, u2.x, b.x,
				r2.y, u2.y, b.y,
				r2.z, u2.z, b.z
			)

			return curve0, -curve1, cf1, cf2
		end

		function module.ShowProjectilePath(beamClone, x0, v0, t, gravity)
			gravity = gravity or Vector3.new(0, 0, 0)

			local attach0 = Instance.new("Attachment", workspace.Terrain)
			local attach1 = Instance.new("Attachment", workspace.Terrain)

			local beam = beamClone:Clone()
			beam.Attachment0 = attach0
			beam.Attachment1 = attach1
			beam.Parent = workspace.Terrain

			local curve0, curve1, cf1, cf2 = module.CalculateBeamProjectile(x0, v0, t, gravity)

			beam.CurveSize0 = curve0
			beam.CurveSize1 = curve1

			--Convert world space CFrames to be relative to the attachment parent.
			attach0.CFrame = attach0.Parent.CFrame:Inverse() * cf1
			attach1.CFrame = attach1.Parent.CFrame:Inverse() * cf2

			return beam, attach0, attach1
		end

		function module.UpdateProjectilePath(beam, attach0, attach1, x0, v0, t, gravity)
			gravity = gravity or Vector3.new(0, 0, 0)

			local curve0, curve1, cf1, cf2 = module.CalculateBeamProjectile(x0, v0, t, gravity)

			beam.CurveSize0 = curve0
			beam.CurveSize1 = curve1

			--Convert world space CFrames to be relative to the attachment parent.
			attach0.CFrame = attach0.Parent.CFrame:Inverse() * cf1
			attach1.CFrame = attach1.Parent.CFrame:Inverse() * cf2
		end

		return module
	end
	
	Utils.Roblox = function()
		local TweenService 		= game:GetService("TweenService")
		local CollectionService = game:GetService("CollectionService")
		local RunService 		= game:GetService("RunService")
		local UserInputService	= game:GetService("UserInputService")

		local Roblox = {}

		Roblox.Random = Random.new()
		Roblox.zeroVector2 = Vector2.new()
		Roblox.zeroVector3 = Vector3.new()
		Roblox.identityCFrame = CFrame.new()
		Roblox.upVector2 = Vector2.new(0, 1)
		Roblox.upVector3 = Vector3.new(0, 1, 0)

		local guidCharsText = "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!@#$%^&*()_+./"
		local guidChars = {}
		for i = 1, #guidCharsText do
			guidChars[i] = guidCharsText:sub(i, i)
		end
		local guidRandom = Random.new()

		function Roblox.newGuid()
			local guid = ""
			for _ = 1, 10 do
				local char = guidRandom:NextInteger(1,#guidChars)
				guid = guid .. guidChars[char]
			end
			return guid
		end

		function Roblox.isPlaySolo()
			return RunService:IsClient() and RunService:IsServer() and RunService:IsStudio()
		end

		function Roblox.waitForDescendant(instance, descendantName, timeout)
			timeout = timeout or 60
			local found = instance:FindFirstChild(descendantName, true)
			if found then
				return found
			end

			if timeout < 1e6 and timeout > 0 then
				coroutine.wrap(function()
					wait(timeout)
					if not found then
						warn("Roblox.waitForDescendant(%s, %s) is taking too long")
					end
				end)()
			end

			while not found do
				local newDescendant = instance.DescendantAdded:Wait()
				if newDescendant.Name == descendantName then
					found = newDescendant
					return newDescendant
				end
			end
		end

		function Roblox.create(className)
			return function(props)
				local instance = Instance.new(className)
				for key, val in pairs(props) do
					if key ~= "Parent" then
						instance[key] = val
					end
				end
				instance.Parent = props.Parent
				return instance
			end
		end

		function Roblox.weldModel(model)
			local rootPart = model.PrimaryPart
			for _, part in pairs(model:GetDescendants()) do
				if part:IsA("BasePart") and part ~= rootPart then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = rootPart
					weld.Part1 = part
					weld.Parent = part
				end
			end
		end

		function Roblox.setNetworkOwner(model, owner)
			if not model then warn("Cannot setNetworkOwner on nil model") return end
			for _, part in pairs(model:GetDescendants()) do
				if part:IsA("BasePart") and not part.Anchored then
					part:SetNetworkOwner(owner)
				end
			end
		end

		function Roblox.createMotor6D(root, child)
			local motor = Instance.new("Motor6D")
			motor.Part0 = root
			motor.Part1 = child

			motor.C0 = root.CFrame:toObjectSpace(child.CFrame)
			motor.C1 = CFrame.new()

			motor.Parent = root
			return motor
		end

		function Roblox.getTotalMass(part)
			local allConnected = part:GetConnectedParts(true)
			local total = 0
			for _, v in pairs(allConnected) do
				total = total + v:GetMass()
			end
			return total
		end

		function Roblox.waitForTween(tweenInstance, tweenInfo, tweenProps)
			local tween = TweenService:Create(tweenInstance, tweenInfo, tweenProps)
			tween:Play()
			tween.Completed:wait()
		end

		function Roblox.tween(tweenInstance, tweenInfo, tweenProps)
			local tween = TweenService:Create(tweenInstance, tweenInfo, tweenProps)
			tween:Play()
		end

		function Roblox.fadeAway(gui, duration, level)
			duration = duration or 0.5
			level = level or 0

			local tweenInfo = TweenInfo.new(duration)
			local tweenProps = { BackgroundTransparency = 1 }

			if gui:IsA("TextButton") or gui:IsA("TextLabel") or gui:IsA("TextBox") then
				tweenProps.TextTransparency = 1
				tweenProps.TextStrokeTransparency = 1
			elseif gui:IsA("ImageLabel") or gui:IsA("ImageButton") then
				tweenProps.ImageTransparency = 1
			else
				return
			end

			for _, v in pairs(gui:GetChildren()) do
				Roblox.fadeAway(v, duration, level + 1)
			end


			if level == 0 then
				coroutine.wrap(function()
					Roblox.waitForTween(gui, tweenInfo, tweenProps)
					gui:Destroy()
				end)()
			else
				Roblox.tween(gui, tweenInfo, tweenProps)
			end
		end

		function Roblox.setModelAnchored(model, anchored)
			for _, part in pairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = anchored
				end
			end
		end

		function Roblox.setModelLocalVisible(model, visible)
			for _, part in pairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = visible and 0 or 1
				elseif part:IsA("SurfaceGui") then
					part.Enabled = visible
				elseif part:IsA("Decal") then
					part.Transparency = visible and 0 or 1
				end
			end
		end

		function Roblox.forAllTagged(tagName, enterFunc, exitFunc)
			for _, obj in pairs(CollectionService:GetTagged(tagName)) do
				if enterFunc then
					enterFunc(obj, tagName)
				end
			end
			if enterFunc then
				CollectionService:GetInstanceAddedSignal(tagName):Connect(function(obj) enterFunc(obj, tagName) end)
			end
			if exitFunc then
				CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(obj) exitFunc(obj, tagName) end)
			end
		end

		function Roblox.getHumanoidFromCharacterPart(part)
			local currentNode = part
			while currentNode do
				local humanoid = currentNode:FindFirstChildOfClass("Humanoid")
				if humanoid then return humanoid end
				currentNode = currentNode.Parent
			end
			return nil
		end

		local addEsEndings = {
			s = true,
			sh = true,
			ch = true,
			x = true,
			z = true
		}
		local vowels = {
			a = true,
			e = true,
			i = true,
			o = true,
			u = true
		}
		function Roblox.formatPlural(num, name, wordOnly)
			if num ~= 1 then
				local lastTwo = name:sub(-2):lower()
				local lastOne = name:sub(-1):lower()

				local suffix = "s"
				if addEsEndings[lastTwo] or addEsEndings[lastOne] then
					suffix = "es"
				elseif lastOne == "o" and #lastTwo == 2 then
					local secondToLast = lastTwo:sub(1, 1)
					if not vowels[secondToLast] then
						suffix = "es"
					end
				end
				name = name .. suffix
			end
			if not wordOnly then
				return ("%s %s"):format(Roblox.formatInteger(num), name)
			else
				return name
			end
		end

		function Roblox.formatNumberTight(number)
			local order = math.log10(number)
			if order >= 3 and order < 6 then
				return ("%.1fK"):format(number / (10^3))
			end
			if order >= 6 and order < 9 then
				return ("%.1fM"):format(number / (10^6))
			end
			if order >= 9 then
				return ("%.1fB"):format(number / (10^9))
			end

			return tostring(math.floor(number + 0.5))
		end

		function Roblox.formatInteger(amount)
			amount = math.floor(amount + 0.5)
			local formatted = amount
			local numMatches
			repeat
				formatted, numMatches = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
			until numMatches == 0
			return formatted
		end

		function Roblox.round(val, decimal)
			if decimal then
				return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
			else
				return math.floor(val + 0.5)
			end
		end

		function Roblox.formatNumber(number)
			local result, integral, fractional

			integral, fractional = math.modf(number)
			result = Roblox.formatInteger(integral)

			if fractional ~= 0 then
				result = result .. "." .. string.sub(tostring(math.abs(fractional)),3)
			end
			if number < 0 then
				result = "-" .. result
			end

			return result
		end

		function Roblox.isPointInsidePart(point, part)
			local localPos = part.CFrame:pointToObjectSpace(point)
			return math.abs(localPos.X) <= part.Size.X * 0.5 and math.abs(localPos.Y) <= part.Size.Y * 0.5 and math.abs(localPos.Z) <= part.Size.Z * 0.5
		end

		function Roblox.rayPlaneIntersect(ray, pointOnPlane, planeNormal)
			local Vd = planeNormal:Dot(ray.Direction)
			if Vd == 0 then -- parallel, no intersection
				return nil
			end

			local V0 = planeNormal:Dot(pointOnPlane - ray.Origin)
			local t = V0 / Vd
			if t < 0 then --plane is behind ray origin, and thus there is no intersection
				return nil
			end

			return ray.Origin + ray.Direction * t
		end

		function Roblox.debugPrint(t, level)
			level = level or 0
			local tabs = string.rep("\t", level)
			if typeof(t) == "table" then
				for key, val in pairs(t) do
					print(tabs, key, "=", val)
					if typeof(val) == "table" then
						Roblox.debugPrint(val, level + 1)
					end
				end
			end
		end

		local function findInstanceImpl(root, path, getChildFunc)
			local currentInstance = root

			while true do
				local nextChildName
				local nextSeparator = path:find("%.")
				if not nextSeparator then
					nextChildName = path
				else
					nextChildName = path:sub(1, nextSeparator - 1)
					path = path:sub(nextSeparator + 1)
				end

				local child = getChildFunc(currentInstance, nextChildName)
				if child then
					currentInstance = child
				else
					return nil
				end
			end
		end

		local function findFirstChildImpl(parent, childName)
			return parent:FindFirstChild(childName)
		end
		local function waitForChildImpl(parent, childName)
			return parent:WaitForChild(childName)
		end

		function Roblox.findInstance(root, path)
			return findInstanceImpl(root, path, findFirstChildImpl)
		end

		function Roblox.waitForInstance(root, path)
			return findInstanceImpl(root, path, waitForChildImpl)
		end

		function Roblox.penetrateCast(ray, ignoreList)
			debug.profilebegin("penetrateCast")
			local tries = 0
			local hitPart, hitPoint, hitNormal, hitMaterial = nil, ray.Origin + ray.Direction, Vector3.new(0, 1, 0), Enum.Material.Air
			while tries < 50 do
				tries = tries + 1
				hitPart, hitPoint, hitNormal, hitMaterial = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList, false, true)
				if hitPart and (not hitPart.CanCollide or CollectionService:HasTag(hitPart, "DroppedItemPart") or CollectionService:HasTag(hitPart, "Hidden")) and hitPart.Parent:FindFirstChildOfClass("Humanoid") == nil then
					table.insert(ignoreList, hitPart)
				else
					break
				end
			end
			debug.profileend()
			return hitPart, hitPoint, hitNormal, hitMaterial
		end

		function Roblox.posInGuiObject(pos, guiObject)
			local guiMin = guiObject.AbsolutePosition
			local guiMax = guiMin + guiObject.AbsoluteSize
			return pos.X >= guiMin.X and pos.X <= guiMax.X and pos.Y >= guiMin.Y and pos.Y <= guiMax.Y
		end

		function Roblox.getUTCTime()
			local dateInfo = os.date("!*t")
			return string.format("%04d-%02d-%02d %02d:%02d:%02d", dateInfo.year, dateInfo.month, dateInfo.day, dateInfo.hour, dateInfo.min, dateInfo.sec)
		end

		function Roblox.getUTCTimestamp()
			return os.time(os.date("!*t"))
		end

		local DURATION_TOKENS = {
			{ "years",   "y",  31536000 },
			{ "months",  "mo", 2592000 },
			{ "weeks",   "w",  604800 },
			{ "days",    "d",  86400 },
			{ "hours",   "h",  3600 },
			{ "minutes", "m",  60 },
			{ "seconds", "s",  1 },
		}
		function Roblox.parseDurationInSeconds(inputStr)
			local tokensFound = {}
			local totalDurationSeconds = 0
			for _, tokenInfo in pairs(DURATION_TOKENS) do
				local numFound = string.match(inputStr, "(%d+)" .. tokenInfo[2])
				if numFound then
					local num = tonumber(numFound) or 0
					if num > 0 then
						table.insert(tokensFound, string.format("%d %s", num, tokenInfo[1]))
					end
					totalDurationSeconds = totalDurationSeconds + (num * tokenInfo[3])
				end
			end

			local outputStr = table.concat(tokensFound, ", ")
			return totalDurationSeconds, outputStr
		end

		local random = Random.new()
		function Roblox.chooseWeighted(choiceTable)
			local sum = 0
			for _, weight in pairs(choiceTable) do
				sum = sum + weight
			end

			local roll = random:NextNumber(0, 1)
			local choiceSum = 0
			for choiceName, weight in pairs(choiceTable) do
				local chance = weight / sum
				if roll >= choiceSum and roll < choiceSum + chance then
					return choiceName
				else
					choiceSum = choiceSum + chance
				end
			end

			return nil
		end

		function Roblox.hasMatchingTag(instance, tagPattern)
			for _, tagName in pairs(CollectionService:GetTags(instance)) do
				if tagName:match(tagPattern) ~= nil then
					return true
				end
			end
			return false
		end

		local highlightTweens = setmetatable({}, { __mode = 'k' })
		function Roblox.showHighlight(instance, show)
			local highlightInstance = instance:FindFirstChild("Highlight")
			if not highlightInstance or not highlightInstance:IsA("ImageLabel") then
				return
			end

			local existingTween = highlightTweens[instance]
			if existingTween then
				if show then
					return
				else
					existingTween:Cancel()
					highlightTweens[instance] = nil
					highlightInstance.ImageTransparency = 1
				end
			else
				if not show then
					return
				else
					coroutine.wrap(function()
						highlightInstance.ImageTransparency = 1
						local newTween = TweenService:Create(highlightInstance, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut, 0, true), { ImageTransparency = 0 })
						highlightTweens[instance] = newTween
						while highlightTweens[instance] == newTween do
							newTween:Play()
							newTween.Completed:Wait()
						end
					end)()
				end
			end
		end

		function Roblox.getClickVerb(capitalize)
			local verb = "Click"
			if UserInputService.TouchEnabled then
				verb = "Tap"
			end

			if not capitalize then
				verb = verb:lower()
			end
			return verb
		end

		function Roblox.computeLaunchAngle(relativePoint, launchVelocity)
			local dx, dy = -relativePoint.Z, relativePoint.Y

			local g = workspace.Gravity
			local invRoot = (launchVelocity ^ 4) - (g * ((g * dx * dx) + (2 * dy * launchVelocity * launchVelocity)))
			if invRoot <= 0 then
				return math.pi / 4
			end

			local root = math.sqrt(invRoot)
			local angle1 = math.atan(((launchVelocity * launchVelocity) + root) / (g * dx))
			local angle2 = math.atan(((launchVelocity * launchVelocity) - root) / (g * dx))

			local chosenAngle = math.min(angle1, angle2)

			return chosenAngle
		end

		function Roblox.getClosestPointOnLine(line0, line1, point, doClamp)
			local lineVec = line1 - line0
			local pointFromLine0 = point - line0

			local dotProduct = lineVec:Dot(pointFromLine0)
			local t = dotProduct / (lineVec.Magnitude ^ 2)
			if doClamp ~= false then
				t = math.clamp(t, 0, 1)
			end
			local pointOnLine = line0:Lerp(line1, t)
			return pointOnLine, t, (point - pointOnLine).Magnitude
		end

		function Roblox.getClosestPointOnLines(referencePoint, lines)
			local closestPoint, closestDist, closestLine, closestT = nil, math.huge, nil, 0
			for i = 1, #lines do
				local lineA, lineB = lines[i][1], lines[i][2]

				local point, t, dist = Roblox.getClosestPointOnLine(lineA, lineB, referencePoint)
				if dist < closestDist then
					closestPoint = point
					closestDist = dist
					closestLine = i
					closestT = t
				end
			end

			return closestPoint, closestDist, closestLine, closestT
		end

		function Roblox.getPointInFrontOnLines(referencePoint, forwardOffset, lines)
			local closestPoint, _, closestLine, closestT = Roblox.getClosestPointOnLines(referencePoint, lines)
			if closestPoint then
				local pointOffset = closestPoint
				local offsetBudget = forwardOffset

				if closestLine == 1 and closestT == 0 then
					local beforeDist = (lines[1][1] - Roblox.getClosestPointOnLine(lines[1][1], lines[1][2], referencePoint, false)).Magnitude
					offsetBudget = offsetBudget - beforeDist
				end

				local lineDir = Vector3.new(0, 0, 0)
				while offsetBudget > 0 and closestLine <= #lines do
					local lineA, lineB = lines[closestLine][1], lines[closestLine][2]
					local lineVec = lineB - lineA
					local lineLength = lineVec.Magnitude
					local pointDistAlongLine = (pointOffset - lineA).Magnitude
					local distLeftOnLine = lineLength - pointDistAlongLine
					lineDir = lineVec.Unit

					if offsetBudget > distLeftOnLine then
						offsetBudget = offsetBudget - distLeftOnLine
						pointOffset = lineB
						closestLine = closestLine + 1
					else
						break
					end
				end
				pointOffset = pointOffset + lineDir * offsetBudget

				return pointOffset
			end
			return closestPoint
		end

		function Roblox.applySpread(unspreadDir, randomGenerator, minSpread, maxSpread)
			local spreadRotation = randomGenerator:NextNumber(-math.pi, math.pi)
			local spreadOffset = randomGenerator:NextNumber(minSpread, maxSpread)
			local spreadTransform = CFrame.fromAxisAngle(Vector3.new(math.cos(spreadRotation), math.sin(spreadRotation), 0), spreadOffset)
			local unspreadCFrame = CFrame.new(Vector3.new(), unspreadDir)
			return (unspreadCFrame * spreadTransform).LookVector
		end

		return Roblox
	end
	
	Utils.ScreenCulling = function()
		local RunService = game:GetService("RunService")
		local Workspace = game:GetService("Workspace")

		local Camera = Workspace.CurrentCamera

		local CamCF, PortSize, H, PX, PY, SX, SY, RScaleX, RScaleY

		local function UpdateScreenCulling(NewCamCF, NewPortSize, NewFOV)
			CamCF = NewCamCF
			PortSize = NewPortSize
			H = NewFOV * math.pi / 180 / 2
			PY = PortSize.Y
			PX = PortSize.X
			SY = math.tan(H)
			SX = PX / PY * SY
			RScaleY = (1 + SY * SY) ^ 0.5
			RScaleX = (1 + SX * SX) ^ 0.5
		end

		UpdateScreenCulling(Camera.CFrame, Camera.ViewportSize, Camera.FieldOfView)

		RunService.RenderStepped:Connect(function(dt)
			UpdateScreenCulling(Camera.CFrame, Camera.ViewportSize, Camera.FieldOfView)
		end)

		return function(Position, Radius)
			local R = CFrame.new().pointToObjectSpace(CamCF, Position)
			local RZ = -R.Z
			local RX = R.X
			local RY = R.Y
			return -RZ * SX < RX + RScaleX * Radius and RX - RScaleX * Radius < RZ * SX and -RZ * SY < RY + RScaleY * Radius and RY - RScaleY * Radius < RZ * SY and RZ > -Radius
		end
	end
	
	Utils.Signal = function()
		--[[
	Creates signals via a modulized version of RbxUtility (It was deprecated so This will be released for people who would like to keep using it.
	
	This creates RBXScriptSignals.
	
	API:
		table Signal:connect(Function f) --Will run f when the event fires.
		void Signal:wait() --Will wait until the event fires
		void Signal:disconnectAll() --Will disconnect ALL connections created on this signal
		void Signal:fire(Tuple args) --Cause the event to fire with your own arguments
		
		
		Connect, Wait, DisconnectAll, and Fire are also acceptable for calling (An uppercase letter rather than a lowercase one)
		
		
	Standard creation:
	
		local SignalModule = require(this module)
		local Signal = SignalModule:CreateNewSignal()
		
		function OnEvent()
			print("Event fired!")
		end
		
		Signal:Connect(OnEvent) --Unlike objects, this does not do "object.SomeEvent:Connect()" - Instead, the Signal variable is the event itself.
		
		Signal:Fire() --Fire it.
--]]

		local Signal = {}

		function Signal:CreateNewSignal()
			local This = {}

			local mBindableEvent = Instance.new('BindableEvent')
			local mAllCns = {} --All connection objects returned by mBindableEvent::connect

			function This:connect(Func)
				if typeof(Func) ~= "function" then
					error("Argument #1 of Connect must be a function, got a "..typeof(Func), 2)
				end
				local Con = mBindableEvent.Event:Connect(Func)
				mAllCns[Con] = true
				local ScrSig = {}
				function ScrSig:disconnect()
					Con:Disconnect()
					mAllCns[Con] = nil
				end

				ScrSig.Disconnect = ScrSig.disconnect

				return ScrSig
			end

			function This:disconnectAll()
				for Connection, _ in pairs(mAllCns) do
					Connection:Disconnect()
					mAllCns[Connection] = nil
				end
			end

			function This:wait()
				return mBindableEvent.Event:Wait()
			end

			function This:fire(...)
				mBindableEvent:Fire(...)
			end

			This.Connect = This.connect
			This.DisconnectAll = This.disconnectAll
			This.Wait = This.wait
			This.Fire = This.fire

			return This
		end

		return Signal
	end
	
	Utils.Spring = function()
		local physics = {}

		do
			physics.spring = {}
			do
				local spring = {}
				physics.spring = spring
				local e = 2.718281828459045
				function spring.new(init)
					local null = 0 * (init or 0)
					local d = 1
					local s = 1
					local p0 = init or null
					local v0 = null
					local p1 = init or null
					local t0 = os.clock()
					local h = 0
					local c1 = null
					local c2 = null
					local self = {}
					local meta = {}
					local function UpdateConstants()
						if s == 0 then
							h = 0
							c1 = null
							c2 = null
						elseif d < 0.99999999 then
							h = (1 - d * d) ^ 0.5
							c1 = p0 - p1
							c2 = d / h * c1 + v0 / (h * s)
						elseif d < 1.00000001 then
							h = 0
							c1 = p0 - p1
							c2 = c1 + v0 / s
						else
							h = (d * d - 1) ^ 0.5
							local a = -v0 / (2 * s * h)
							local b = -(p1 - p0) / 2
							c1 = (1 - d / h) * b + a
							c2 = (1 + d / h) * b - a
						end
					end
					local function Pos(x)
						if x < 0.001 then
							return p0
						end
						if s == 0 then
							return p0
						elseif d < 0.99999999 then
							local co = math.cos(h * s * x)
							local si = math.sin(h * s * x)
							local ex = e ^ (d * s * x)
							return co / ex * c1 + si / ex * c2 + p1
						elseif d < 1.00000001 then
							local ex = e ^ (s * x)
							return (c1 + s * x * c2) / ex + p1
						else
							local co = e ^ ((-d - h) * s * x)
							local si = e ^ ((-d + h) * s * x)
							return c1 * co + c2 * si + p1
						end
					end
					local function Vel(x)
						if x < 0.001 then
							return v0
						end
						if s == 0 then
							return p0
						elseif d < 0.99999999 then
							local co = math.cos(h * s * x)
							local si = math.sin(h * s * x)
							local ex = e ^ (d * s * x)
							return s * (co * h - d * si) / ex * c2 - s * (co * d + h * si) / ex * c1
						elseif d < 1.00000001 then
							local ex = e ^ (s * x)
							return -s / ex * (c1 + (s * x - 1) * c2)
						else
							local co = e ^ ((-d - h) * s * x)
							local si = e ^ ((-d + h) * s * x)
							return si * (h - d) * s * c2 - co * (d + h) * s * c1
						end
					end
					local function PosVel(x)
						if s == 0 then
							return p0
						elseif d < 0.99999999 then
							local co = math.cos(h * s * x)
							local si = math.sin(h * s * x)
							local ex = e ^ (d * s * x)
							return co / ex * c1 + si / ex * c2 + p1, s * (co * h - d * si) / ex * c2 - s * (co * d + h * si) / ex * c1
						elseif d < 1.00000001 then
							local ex = e ^ (s * x)
							return (c1 + s * x * c2) / ex + p1, -s / ex * (c1 + (s * x - 1) * c2)
						else
							local co = e ^ ((-d - h) * s * x)
							local si = e ^ ((-d + h) * s * x)
							return c1 * co + c2 * si + p1, si * (h - d) * s * c2 - co * (d + h) * s * c1
						end
					end
					UpdateConstants()
					function self.GetPosVel()
						return PosVel(os.clock() - t0)
					end
					function self.SetPosVel(p, v)
						local time = os.clock()
						p0, v0 = p, v
						t0 = time
						UpdateConstants()
					end
					function self:Accelerate(a)
						local time = os.clock()
						local p, v = PosVel(time - t0)
						p0, v0 = p, v + a
						t0 = time
						UpdateConstants()
					end
					function meta:__index(index)
						local time = os.clock()
						if index == "p" then
							return Pos(time - t0)
						elseif index == "v" then
							return Vel(time - t0)
						elseif index == "t" then
							return p1
						elseif index == "d" then
							return d
						elseif index == "s" then
							return s
						end
					end
					function meta:__newindex(index, value)
						local time = os.clock()
						if index == "p" then
							p0, v0 = value, Vel(time - t0)
						elseif index == "v" then
							p0, v0 = Pos(time - t0), value
						elseif index == "t" then
							p0, v0 = PosVel(time - t0)
							p1 = value
						elseif index == "d" then
							if value == nil then
								warn("nil value for d")
								warn(debug.stacktrace())
								value = d
							end
							p0, v0 = PosVel(time - t0)
							d = value
						elseif index == "s" then
							if value == nil then
								warn("nil value for s")
								warn(debug.stacktrace())
								value = s
							end
							p0, v0 = PosVel(time - t0)
							s = value
						elseif index == "a" then
							local p, v = PosVel(time - t0)
							p0, v0 = p, v + value
						end
						t0 = time
						UpdateConstants()
					end
					return setmetatable(self, meta)
				end
			end
		end

		return physics
	end
	
	Utils.Table = function()
		--[[
	To use: local table = require(this)
	(Yes, override table.)

	Written by EtiTheSpirit. Adds custom functions to the `table` value provided by roblox (in normal cases, this would simply modify `table`, but Roblox has disabled that so we need to use a proxy)
	
	CHANGES:
		3 December 2019 @ 11:07 PM CST:
			+ Added table.join
			
			
		21 November 2019 @ 6:50 PM CST:
			+ Added new method bodies to skip/take using Luau's new methods. Drastic speed increases achieved. CREDITS: Halalaluyafail3 (See https://devforum.roblox.com/t/sandboxed-table-system-add-custom-methods-to-table/391177/12?u=etithespirit)
			+ Added table.retrieve as proposed by ^ under the name "table.range" as this name relays what it does a bit better, I think.
			+ Added table.skipAndTake as an alias method.

--]]

		local RNG = Random.new()
		local RobloxTable = table
		local Table = {}

		-- Returns true if the table contains the specified value.
		Table.contains = function (tbl, value)
			return Table.indexOf(tbl, value) ~= nil -- This is kind of cheatsy but it promises the best performance.
		end

		-- A combo of table.find and table.keyOf -- This first attempts to find the ordinal index of your value, then attempts to find the lookup key if it can't find an ordinal index.
		Table.indexOf = function (tbl, value)
			local fromFind = table.find(tbl, value)
			if fromFind then return fromFind end

			return Table.keyOf(tbl, value)
		end

		-- Returns the key of the specified value, or nil if it could not be found. Unlike IndexOf, this searches every key in the table, not just ordinal indices (arrays)
		-- This is inherently slower due to how lookups work, so if your table is structured like an array, use table.find
		Table.keyOf = function (tbl, value)
			for index, obj in pairs(tbl) do
				if obj == value then
					return index
				end
			end
			return nil
		end

		-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Skips *n* objects in the table, and returns a new table that contains indices (n + 1) to (end of table)
		Table.skip = function (tbl, n)
			return table.move(tbl, n+1, #tbl, 1, table.create(#tbl-n))
		end

		-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Takes *n* objects from a table and returns a new table only containing those objects.
		Table.take = function (tbl, n)
			return table.move(tbl, 1, n, 1, table.create(n))
		end

		-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Takes the range of entries in this table in the range [start, finish] and returns that range as a table.
		Table.range = function (tbl, start, finish)
			return table.move(tbl, start, finish, 1, table.create(finish - start + 1))
		end

		-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). An alias that calls table.skip(skip), and then takes [take] entries from the resulting table.
		Table.skipAndTake = function (tbl, skip, take)
			return table.move(tbl, skip + 1, skip + take, 1, table.create(take))
		end

		-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Selects a random object out of tbl
		Table.random = function (tbl)
			return tbl[RNG:NextInteger(1, #tbl)]
		end

		-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Merges tbl0 and tbl1 together.
		Table.join = function (tbl0, tbl1)
			local nt = table.create(#tbl0 + #tbl1)
			local t2 = table.move(tbl0, 1, #tbl0, 1, nt)
			return table.move(tbl1, 1, #tbl1, #tbl0 + 1, nt)
		end

		-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Removes the specified object from this array.
		Table.removeObject = function (tbl, obj)
			local index = Table.indexOf(tbl, obj)
			if index then
				table.remove(tbl, index)
			end
		end

		return setmetatable({}, {
			__index = function(tbl, index)
				if Table[index] ~= nil then
					return Table[index]
				else
					return RobloxTable[index]
				end
			end;

			__newindex = function(tbl, index, value)
				error("Add new table entries by editing the Module itself.")
			end;
		})
	end
	
	Utils.Thread = function()
		local RunService = game:GetService("RunService")
		local Timer = require(Utils.Timer)

		local Thread = {}

--[[
function Thread:Wait(t)
	if t ~= nil then
		local TotalTime = 0
		TotalTime = TotalTime + RunService.Heartbeat:Wait()
		while TotalTime < t do
			TotalTime = TotalTime + RunService.Heartbeat:Wait()
		end
	else
		RunService.Heartbeat:Wait()
	end
end

function Thread:Spawn(callback)
	coroutine.resume(coroutine.create(callback))
end

function Thread:Delay(t, callback)
	local timer = Timer.new()
	timer:SetActive(true)
	timer:FireOnTimeReached(t, function()
		self:Spawn(callback)
		timer:Destroy()
	end)
end
]]

		function Thread:Wait(t)
			if t ~= nil then
				task.wait(t)
			else
				task.wait()
			end
		end

		function Thread:Spawn(callback)
			task.spawn(callback)
		end

		function Thread:Delay(t, callback)
			task.delay(t, callback)
		end

		return Thread
	end
	
	Utils.Timer = function()
		local RunService = game:GetService("RunService")

		local Timer = {}
		Timer.__index = Timer

		function Timer.new(startTime, isClient)
			local self = setmetatable({}, Timer)

			self.Active = false
			self.Time = startTime or 0
			self.Events = {}

			self.TimerEvent = (isClient and RunService.RenderStepped or RunService.Heartbeat):Connect(function(dt)
				if (self.Active) then
					self.Time = self.Time + dt

					local events = self.Events
					for i = #events, 1, -1 do
						if (self.Time >= events[i][1]) then
							events[i][2](self.Time)
							table.remove(events, i)
						end
					end
				end
			end)

			return self
		end

		function Timer:SetActive(bool)
			self.Active = bool
		end

		function Timer:FireOnTimeReached(t, f)
			table.insert(self.Events, {t, f})
		end

		function Timer:Destroy()
			self.TimerEvent:Disconnect()
		end

		return Timer
	end
	
	return setmetatable({}, {
		__index = function(p1, p2)
			return require(Utils[p2])
		end
	})
end

local ProjectileHandler = {}

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Events = ReplicatedStorage:WaitForChild("Events")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ParticleFramework = require(Modules.ParticleFramework)
local DamageModule = require(Modules.DamageModule)
local Utilities = require(Modules.Utilities)
local Thread = Utilities.Thread
local ScreenCulling = Utilities.ScreenCulling
local Math = Utilities.Math

local InflictTarget = Remotes.InflictTarget
local VisualizeBullet = Remotes.VisualizeBullet
local VisualizeHitEffect = Remotes.VisualizeHitEffect
local ShatterGlass = Remotes.ShatterGlass

-- Properties
local OptimalEffects = false
local RenderDistance = 400
local ScreenCullingEnabled = true
local ScreenCullingRadius = 16

local Beam = Instance.new("Beam")
Beam.TextureSpeed = 0
Beam.LightEmission = 0
Beam.LightInfluence = 1
Beam.Transparency = NumberSequence.new(0)

local function AddressTableValue(enabled, level, v1, v2)
	if v1 ~= nil and enabled and level then
		return ((level == 1 and v1.Level1) or (level == 2 and v1.Level2) or (level == 3 and v1.Level3) or v2)
	else
		return v2
	end
end

local function MakeImpactFX(Hit, Position, Normal, Material, ParentToPart, ClientModule, Miscs, Replicate, IsMelee)
	local SurfaceCF = CFrame.new(Position, Position + Normal)
	local HitEffectEnabled = ClientModule.HitEffectEnabled
	local HitSoundIDs = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.HitSoundIDs, ClientModule.HitSoundIDs)
	local HitSoundPitchMin = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.HitSoundPitchMin, ClientModule.HitSoundPitchMin)
	local HitSoundPitchMax = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.HitSoundPitchMax, ClientModule.HitSoundPitchMax)
	local HitSoundVolume = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.HitSoundVolume, ClientModule.HitSoundVolume)
	local CustomHitEffect = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.CustomHitEffect, ClientModule.CustomHitEffect)
	
	local BulletHoleEnabled = ClientModule.BulletHoleEnabled
	local BulletHoleSize = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.BulletHoleSize, ClientModule.BulletHoleSize)
	local BulletHoleTexture = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.BulletHoleTexture, ClientModule.BulletHoleTexture)
	local PartColor = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.PartColor, ClientModule.PartColor)
	local BulletHoleVisibleTime = ClientModule.BulletHoleVisibleTime
	local BulletHoleFadeTime = ClientModule.BulletHoleFadeTime
	
	if IsMelee then
		HitEffectEnabled = ClientModule.MeleeHitEffectEnabled
		HitSoundIDs = ClientModule.MeleeHitSoundIDs
		HitSoundPitchMin = ClientModule.MeleeHitSoundPitchMin
		HitSoundPitchMax = ClientModule.MeleeHitSoundPitchMax
		HitSoundVolume = ClientModule.MeleeHitSoundVolume
		CustomHitEffect = ClientModule.CustomMeleeHitEffect
		
		BulletHoleEnabled = ClientModule.MarkerEffectEnabled
		BulletHoleSize = ClientModule.MarkerEffectSize
		BulletHoleTexture = ClientModule.MarkerEffectTexture
		BulletHoleVisibleTime = ClientModule.MarkerEffectVisibleTime
		BulletHoleFadeTime = ClientModule.MarkerEffectFadeTime
		PartColor = ClientModule.MarkerPartColor
	end
	
	if HitEffectEnabled then
		local Attachment = Instance.new("Attachment")
		Attachment.CFrame = SurfaceCF
		Attachment.Parent = Workspace.Terrain
		local Sound
		
		local function Spawner(material)
			if Miscs.HitEffectFolder[material.Name]:FindFirstChild("MaterialSounds") then
				local tracks = Miscs.HitEffectFolder[material.Name].MaterialSounds:GetChildren()
				local rn = math.random(1, #tracks)
				local track = tracks[rn]
				if track ~= nil then
					Sound = track:Clone()
					if track:FindFirstChild("Pitch") then
						Sound.PlaybackSpeed = Random.new():NextNumber(track.Pitch.Min.Value, track.Pitch.Max.Value)
					else
						Sound.PlaybackSpeed = Random.new():NextNumber(HitSoundPitchMin, HitSoundPitchMax)
					end
					if track:FindFirstChild("Volume") then
						Sound.Volume = Random.new():NextNumber(track.Volume.Min.Value, track.Volume.Max.Value)
					else
						Sound.Volume = HitSoundVolume
					end
					Sound.Parent = Attachment
				end
			else
				Sound = Instance.new("Sound",Attachment)
				Sound.SoundId = "rbxassetid://"..HitSoundIDs[math.random(1, #HitSoundIDs)]
				Sound.PlaybackSpeed = Random.new():NextNumber(HitSoundPitchMin, HitSoundPitchMax)
				Sound.Volume = HitSoundVolume
			end
			for i, v in pairs(Miscs.HitEffectFolder[material.Name]:GetChildren()) do
				if v.ClassName == "ParticleEmitter" then
					local Count = 1
					local Particle = v:Clone()
					Particle.Parent = Attachment
					if Particle:FindFirstChild("EmitCount") then
						Count = Particle.EmitCount.Value
					end
					if Particle.PartColor.Value then
						local HitPartColor = Hit and Hit.Color or Color3.fromRGB(255, 255, 255)
						if Hit and Hit:IsA("Terrain") then
							HitPartColor = Workspace.Terrain:GetMaterialColor(Material or Enum.Material.Sand)
						end
						Particle.Color = ColorSequence.new(HitPartColor, HitPartColor)
					end
					Thread:Delay(0.01, function()
						if OptimalEffects then
							local QualityLevel = UserSettings().GameSettings.SavedQualityLevel
							if QualityLevel == Enum.SavedQualitySetting.Automatic then
								local Compressor = 1 / 2
								Particle:Emit(Count * Compressor)
							else
								local Compressor = QualityLevel.Value / 21
								Particle:Emit(Count * Compressor)
							end
						else
							Particle:Emit(Count)
						end
						Debris:AddItem(Particle, Particle.Lifetime.Max)
					end)					
				end
			end
			Sound:Play()
			
			if BulletHoleEnabled then
				local Hole = Instance.new("Attachment")
				Hole.Parent = ParentToPart and Hit or Workspace.Terrain
				Hole.WorldCFrame = SurfaceCF * CFrame.Angles(math.rad(90), math.rad(180), 0)
				if ParentToPart then
					local Scale = BulletHoleSize
					if Miscs.HitEffectFolder[material.Name]:FindFirstChild("MaterialHoleSize") then
						Scale = Miscs.HitEffectFolder[material.Name].MaterialHoleSize.Value
					end
					local A0 = Instance.new("Attachment")
					local A1 = Instance.new("Attachment")
					local BeamClone = Beam:Clone()
					BeamClone.Width0 = Scale
					BeamClone.Width1 = Scale
					if Miscs.HitEffectFolder[material.Name]:FindFirstChild("MaterialDecals") then
						local Decals = Miscs.HitEffectFolder[material.Name].MaterialDecals:GetChildren()
						local Chosen = math.random(1, #Decals)
						local Decal = Decals[Chosen]
						if Decal ~= nil then
							BeamClone.Texture = "rbxassetid://"..Decal.Value
							if Decal.PartColor.Value then
								local HitPartColor = Hit and Hit.Color or Color3.fromRGB(255, 255, 255)
								if Hit and Hit:IsA("Terrain") then
									HitPartColor = Workspace.Terrain:GetMaterialColor(Material or Enum.Material.Sand)
								end
								BeamClone.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, HitPartColor), ColorSequenceKeypoint.new(1, HitPartColor)})
							end
						end
					else
						BeamClone.Texture = "rbxassetid://"..BulletHoleTexture[math.random(1, #BulletHoleTexture)]
						if PartColor then
							local HitPartColor = Hit and Hit.Color or Color3.fromRGB(255, 255, 255)
							if Hit and Hit:IsA("Terrain") then
								HitPartColor = Workspace.Terrain:GetMaterialColor(Material or Enum.Material.Sand)
							end
							BeamClone.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, HitPartColor), ColorSequenceKeypoint.new(1, HitPartColor)})
						end
					end
					BeamClone.Attachment0 = A0
					BeamClone.Attachment1 = A1
					A0.Parent = Hit
					A1.Parent = Hit
					A0.WorldCFrame = Hole.WorldCFrame * CFrame.new(Scale / 2, -0.01, 0) * CFrame.Angles(math.rad(90), 0, 0)
					A1.WorldCFrame = Hole.WorldCFrame * CFrame.new(-Scale / 2, -0.01, 0) * CFrame.Angles(math.rad(90), math.rad(180), 0)
					BeamClone.Parent = Workspace.Terrain
					Thread:Delay(BulletHoleVisibleTime, function()
						if BulletHoleVisibleTime > 0 then
							if OptimalEffects then
								if Replicate then
									local t0 = os.clock()
									while Hole ~= nil do
										local Alpha = math.min((os.clock() - t0) / BulletHoleFadeTime, 1)
										if BeamClone then BeamClone.Transparency = NumberSequence.new(Math.Lerp(0, 1, Alpha)) end
										if Alpha == 1 then break end
										Thread:Wait()
									end
									if A0 then A0:Destroy() end
									if A1 then A1:Destroy() end
									if BeamClone then BeamClone:Destroy() end
									if Hole then Hole:Destroy() end
								else
									if A0 then A0:Destroy() end
									if A1 then A1:Destroy() end
									if BeamClone then BeamClone:Destroy() end
									if Hole then Hole:Destroy() end
								end
							else
								local t0 = os.clock()
								while Hole ~= nil do
									local Alpha = math.min((os.clock() - t0) / BulletHoleFadeTime, 1)
									if BeamClone then BeamClone.Transparency = NumberSequence.new(Math.Lerp(0, 1, Alpha)) end
									if Alpha == 1 then break end
									Thread:Wait()
								end
								if A0 then A0:Destroy() end
								if A1 then A1:Destroy() end
								if BeamClone then BeamClone:Destroy() end
								if Hole then Hole:Destroy() end
							end
						else
							if A0 then A0:Destroy() end
							if A1 then A1:Destroy() end
							if BeamClone then BeamClone:Destroy() end
							if Hole then Hole:Destroy() end
						end
					end)
				else
					Debris:AddItem(Hole, 5)
				end
			end
		end
		
		if not CustomHitEffect then
			--[[
			if Miscs.HitEffectFolder:FindFirstChild(Hit.Material) then
				Spawner(Hit.Material)
			else
				Spawner(Miscs.HitEffectFolder.Custom)
			end
			]]
			
		else
			Spawner(Miscs.HitEffectFolder.Custom)
		end
		
		Debris:AddItem(Attachment, 10)				
	end
end

local function MakeBloodFX(Hit, Position, Normal, Material, ParentToPart, ClientModule, Miscs, Replicate, IsMelee)
	local SurfaceCF = CFrame.new(Position, Position + Normal)
	
	local BloodEnabled = ClientModule.BloodEnabled
	local HitCharSndIDs = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.HitCharSndIDs, ClientModule.HitCharSndIDs)
	local HitCharSndPitchMin = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.HitCharSndPitchMin, ClientModule.HitCharSndPitchMin)
	local HitCharSndPitchMax = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.HitCharSndPitchMax, ClientModule.HitCharSndPitchMax)
	local HitCharSndVolume = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.HitCharSndVolume, ClientModule.HitCharSndVolume)
	
	local BloodWoundEnabled = ClientModule.BloodWoundEnabled
	local BloodWoundTexture = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.BloodWoundTexture, ClientModule.BloodWoundTexture)
	local BloodWoundSize = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.BloodWoundSize, ClientModule.BloodWoundSize)
	local BloodWoundTextureColor = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.BloodWoundTextureColor, ClientModule.BloodWoundTextureColor)
	local BloodWoundPartColor = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.BloodWoundPartColor, ClientModule.BloodWoundPartColor)
	local BloodWoundVisibleTime = ClientModule.BloodWoundVisibleTime
	local BloodWoundFadeTime = ClientModule.BloodWoundFadeTime
	
	if IsMelee then
		BloodEnabled = ClientModule.MeleeBloodEnabled
		HitCharSndIDs = ClientModule.MeleeHitCharSndIDs
		HitCharSndPitchMin = ClientModule.MeleeHitCharSndPitchMin
		HitCharSndPitchMax = ClientModule.MeleeHitCharSndPitchMax
		HitCharSndVolume = ClientModule.MeleeHitCharSndVolume

		BloodWoundEnabled = ClientModule.MeleeBloodWoundEnabled
		BloodWoundTexture = ClientModule.MeleeBloodWoundSize
		BloodWoundSize = ClientModule.MeleeBloodWoundTexture
		BloodWoundTextureColor = ClientModule.MeleeBloodWoundTextureColor
		BloodWoundPartColor = ClientModule.MeleeBloodWoundVisibleTime
		BloodWoundVisibleTime = ClientModule.MeleeBloodWoundFadeTime
		BloodWoundFadeTime = ClientModule.MeleeBloodWoundPartColor
	end
	
	if BloodEnabled then
		local Attachment = Instance.new("Attachment")
		Attachment.CFrame = SurfaceCF
		Attachment.Parent = Workspace.Terrain
		local Sound = Instance.new("Sound")
		Sound.SoundId = "rbxassetid://"..HitCharSndIDs[math.random(1, #HitCharSndIDs)]
		Sound.PlaybackSpeed = Random.new():NextNumber(HitCharSndPitchMin, HitCharSndPitchMax)
		Sound.Volume = HitCharSndVolume
		Sound.Parent = Attachment
		for i, v in pairs(Miscs.BloodEffectFolder:GetChildren()) do
			if v.ClassName == "ParticleEmitter" then
				local Count = 1
				local Particle = v:Clone()
				Particle.Parent = Attachment
				if Particle:FindFirstChild("EmitCount") then
					Count = Particle.EmitCount.Value
				end
				Thread:Delay(0.01, function()
					if OptimalEffects then
						local QualityLevel = UserSettings().GameSettings.SavedQualityLevel
						if QualityLevel == Enum.SavedQualitySetting.Automatic then
							local Compressor = 1 / 2
							Particle:Emit(Count * Compressor)
						else
							local Compressor = QualityLevel.Value / 21
							Particle:Emit(Count * Compressor)
						end
					else
						Particle:Emit(Count)
					end
					Debris:AddItem(Particle, Particle.Lifetime.Max)
				end)
			end
		end
		Sound:Play()
		Debris:AddItem(Attachment, 10)
		
		if BloodWoundEnabled then
			local Hole = Instance.new("Attachment")
			Hole.Parent = ParentToPart and Hit or Workspace.Terrain
			Hole.WorldCFrame = SurfaceCF * CFrame.Angles(math.rad(90), math.rad(180), 0)
			if ParentToPart then
				local A0 = Instance.new("Attachment")
				local A1 = Instance.new("Attachment")
				local BeamClone = Beam:Clone()
				BeamClone.Width0 = BloodWoundSize
				BeamClone.Width1 = BloodWoundSize
				BeamClone.Texture = "rbxassetid://"..BloodWoundTexture[math.random(1, #BloodWoundTexture)]
				BeamClone.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, BloodWoundTextureColor), ColorSequenceKeypoint.new(1, BloodWoundTextureColor)})
				if BloodWoundPartColor then
					local HitPartColor = Hit and Hit.Color or Color3.fromRGB(255, 255, 255)
					if Hit and Hit:IsA("Terrain") then
						HitPartColor = Workspace.Terrain:GetMaterialColor(Material or Enum.Material.Sand)
					end
					BeamClone.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, HitPartColor), ColorSequenceKeypoint.new(1, HitPartColor)})
				end				
				BeamClone.Attachment0 = A0
				BeamClone.Attachment1 = A1
				A0.Parent = Hit
				A1.Parent = Hit
				A0.WorldCFrame = Hole.WorldCFrame * CFrame.new(BloodWoundSize / 2, -0.01, 0) * CFrame.Angles(math.rad(90), 0, 0)
				A1.WorldCFrame = Hole.WorldCFrame * CFrame.new(-BloodWoundSize / 2, -0.01, 0) * CFrame.Angles(math.rad(90), math.rad(180), 0)
				BeamClone.Parent = Workspace.Terrain
				Thread:Delay(BloodWoundVisibleTime, function()
					if BloodWoundVisibleTime > 0 then
						if OptimalEffects then
							if Replicate then
								local t0 = os.clock()
								while Hole ~= nil do
									local Alpha = math.min((os.clock() - t0) / BloodWoundFadeTime, 1)
									if BeamClone then BeamClone.Transparency = NumberSequence.new(Math.Lerp(0, 1, Alpha)) end
									if Alpha == 1 then break end
									Thread:Wait()
								end
								if A0 then A0:Destroy() end
								if A1 then A1:Destroy() end
								if BeamClone then BeamClone:Destroy() end
								if Hole then Hole:Destroy() end
							else
								if A0 then A0:Destroy() end
								if A1 then A1:Destroy() end
								if BeamClone then BeamClone:Destroy() end
								if Hole then Hole:Destroy() end
							end
						else
							local t0 = os.clock()
							while Hole ~= nil do
								local Alpha = math.min((os.clock() - t0) / BloodWoundFadeTime, 1)
								if BeamClone then BeamClone.Transparency = NumberSequence.new(Math.Lerp(0, 1, Alpha)) end
								if Alpha == 1 then break end
								Thread:Wait()
							end
							if A0 then A0:Destroy() end
							if A1 then A1:Destroy() end
							if BeamClone then BeamClone:Destroy() end
							if Hole then Hole:Destroy() end
						end
					else
						if A0 then A0:Destroy() end
						if A1 then A1:Destroy() end
						if BeamClone then BeamClone:Destroy() end
						if Hole then Hole:Destroy() end
					end
				end)
			else
				Debris:AddItem(Hole, 5)
			end
		end
	end
end

local function OnRayHit(Origin, Direction, Hit, Position, Normal, Material, Tool, ClientModule, Miscs, Replicate)
	local ShowEffects = ScreenCullingEnabled and (ScreenCulling(Position, ScreenCullingRadius) and (Position - Camera.CFrame.p).Magnitude <= RenderDistance) or (Position - Camera.CFrame.p).Magnitude <= RenderDistance
	if not AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosiveEnabled, ClientModule.ExplosiveEnabled) then
		if Hit and Hit.Parent then
			if Hit.Name == "_glass" then
				if Replicate then
					ShatterGlass:FireServer(Hit, Position, Direction)
				end
			else
				local Distance = (Position - Origin).Magnitude
				local Target = Hit:FindFirstAncestorOfClass("Model")
				local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
				local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
				if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
					if ShowEffects then
						MakeBloodFX(Hit, Position, Normal, Material, true, ClientModule, Miscs, Replicate)
					end
					if Replicate then
						if TargetHumanoid.Health > 0 then							
							Thread:Spawn(function()
								InflictTarget:InvokeServer("Gun", Tool, ClientModule, TargetHumanoid, TargetTorso, Hit, Miscs, Distance)
							end)
							if Tool and Tool.GunClient:FindFirstChild("MarkerEvent") then
								Tool.GunClient.MarkerEvent:Fire(ClientModule, Hit.Name == "Head" and ClientModule.HeadshotEnabled)
							end
						end
					end
				else
					if ShowEffects then
						MakeImpactFX(Hit, Position, Normal, Material, true, ClientModule, Miscs, Replicate)
					end
				end				
			end
		end
	else
		if ClientModule.ExplosionSoundEnabled then
			local SoundTable = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionSoundIDs, ClientModule.ExplosionSoundIDs)
			local Attachment = Instance.new("Attachment")
			Attachment.CFrame = CFrame.new(Position)
			Attachment.Parent = Workspace.Terrain
			local Sound = Instance.new("Sound")
			Sound.SoundId = "rbxassetid://"..SoundTable[math.random(1, #SoundTable)]
			Sound.PlaybackSpeed = Random.new():NextNumber(AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionSoundPitchMin, ClientModule.ExplosionSoundPitchMin), AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionSoundPitchMax, ClientModule.ExplosionSoundPitchMax))
			Sound.Volume = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionSoundVolume, ClientModule.ExplosionSoundVolume)
			Sound.Parent = Attachment
			Sound:Play()
			Debris:AddItem(Attachment, 10)		
		end

		local Explosion = Instance.new("Explosion")
		Explosion.BlastRadius = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionRadius, ClientModule.ExplosionRadius)
		Explosion.BlastPressure = 0
		Explosion.ExplosionType = Enum.ExplosionType.NoCraters
		Explosion.Position = Position
		Explosion.Parent = Camera

		local SurfaceCF = CFrame.new(Position, Position + Normal)

		if ClientModule.CustomExplosion then
			Explosion.Visible = false

			if ShowEffects then
				local Attachment = Instance.new("Attachment")
				Attachment.CFrame = SurfaceCF
				Attachment.Parent = Workspace.Terrain

				for i, v in pairs(Miscs.ExplosionEffectFolder:GetChildren()) do
					if v.ClassName == "ParticleEmitter" then
						local Count = 1
						local Particle = v:Clone()
						Particle.Parent = Attachment
						if Particle:FindFirstChild("EmitCount") then
							Count = Particle.EmitCount.Value
						end
						Thread:Delay(0.01, function()
							if OptimalEffects then
								local QualityLevel = UserSettings().GameSettings.SavedQualityLevel
								if QualityLevel == Enum.SavedQualitySetting.Automatic then
									local Compressor = 1 / 2
									Particle:Emit(Count * Compressor)
								else
									local Compressor = QualityLevel.Value / 21
									Particle:Emit(Count * Compressor)
								end
							else
								Particle:Emit(Count)
							end
							Debris:AddItem(Particle, Particle.Lifetime.Max)
						end)
					end
				end
				
				Debris:AddItem(Attachment, 10)
			end
		end	

		local HitHumanoids = {}

		Explosion.Hit:Connect(function(HitPart, HitDist)
			if HitPart and Replicate then
				if HitPart.Parent and HitPart.Name == "HumanoidRootPart" or HitPart.Name == "Head" then
					local Target = HitPart:FindFirstAncestorOfClass("Model")
					local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
					local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
					if TargetHumanoid then
						if TargetHumanoid.Health > 0 then
							if not HitHumanoids[TargetHumanoid] then
								if ClientModule.ExplosionKnockback then
									local Multipler = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionKnockbackMultiplierOnTarget, ClientModule.ExplosionKnockbackMultiplierOnTarget)
									local DistanceFactor = HitDist / AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionRadius, ClientModule.ExplosionRadius)
									DistanceFactor = 1 - DistanceFactor
									local VelocityMod = (TargetTorso.Position - Explosion.Position).Unit * AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionKnockbackPower, ClientModule.ExplosionKnockbackPower) --* DistanceFactor
									local AirVelocity = TargetTorso.Velocity - Vector3.new(0, TargetTorso.Velocity.y, 0) + Vector3.new(VelocityMod.X, 0, VelocityMod.Z)
									if DamageModule.CanDamage(Target, Tool.Parent, ClientModule.FriendlyFire) then
										local TorsoFly = Instance.new("BodyVelocity")
										TorsoFly.MaxForce = Vector3.new(math.huge, 0, math.huge)
										TorsoFly.Velocity = AirVelocity
										TorsoFly.Parent = TargetTorso
										TargetTorso.Velocity = TargetTorso.Velocity + Vector3.new(0, VelocityMod.Y * Multipler, 0)
										Debris:AddItem(TorsoFly, 0.25)	
									else
										if TargetHumanoid.Parent.Name == Player.Name then
											Multipler = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionKnockbackMultiplierOnPlayer, ClientModule.ExplosionKnockbackMultiplierOnPlayer)
											local TorsoFly = Instance.new("BodyVelocity")
											TorsoFly.MaxForce = Vector3.new(math.huge, 0, math.huge)
											TorsoFly.Velocity = AirVelocity
											TorsoFly.Parent = TargetTorso
											TargetTorso.Velocity = TargetTorso.Velocity + Vector3.new(0, VelocityMod.Y * Multipler, 0)
											Debris:AddItem(TorsoFly, 0.25)
										end
									end							
								end
								Thread:Spawn(function()
									InflictTarget:InvokeServer("Gun", Tool, ClientModule, TargetHumanoid, TargetTorso, Hit, Miscs, HitDist)
								end)
								if Tool and Tool.GunClient:FindFirstChild("MarkerEvent") then
									Tool.GunClient.MarkerEvent:Fire(ClientModule, Hit.Name == "Head" and ClientModule.HeadshotEnabled)
								end
								HitHumanoids[TargetHumanoid] = true
							end   	
						end
					end
				elseif HitPart.Name == "_glass" then
					ShatterGlass:FireServer(HitPart, HitPart.Position, Direction)
				end
			end
		end)
	end
end

local function OnRayBounced(Origin, Direction, Hit, Position, Normal, Material, Tool, ClientModule, Miscs, NoExplosion, Replicate)
	local ShowEffects = ScreenCullingEnabled and (ScreenCulling(Position, ScreenCullingRadius) and (Position - Camera.CFrame.p).Magnitude <= RenderDistance) or (Position - Camera.CFrame.p).Magnitude <= RenderDistance
	if not AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosiveEnabled, ClientModule.ExplosiveEnabled) then
		if Hit and Hit.Parent then
			if Hit.Name == "_glass" then
				if Replicate then
					ShatterGlass:FireServer(Hit, Position, Direction)
				end
			else
				local Distance = (Position - Origin).Magnitude
				local Target = Hit:FindFirstAncestorOfClass("Model")
				local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
				local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
				if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
					if ShowEffects then
						MakeBloodFX(Hit, Position, Normal, Material, true, ClientModule, Miscs, Replicate)
					end
					if Replicate then
						if TargetHumanoid.Health > 0 then							
							Thread:Spawn(function()
								InflictTarget:InvokeServer("Gun", Tool, ClientModule, TargetHumanoid, TargetTorso, Hit, Miscs, Distance)
							end)
							if Tool and Tool.GunClient:FindFirstChild("MarkerEvent") then
								Tool.GunClient.MarkerEvent:Fire(ClientModule, Hit.Name == "Head" and ClientModule.HeadshotEnabled)
							end							
						end
					end
				else
					if ShowEffects then
						MakeImpactFX(Hit, Position, Normal, Material, true, ClientModule, Miscs, Replicate)
					end
				end				
			end
		end
	else
		if NoExplosion then
			if Hit ~= nil and Hit.Parent ~= nil then
				if Hit.Name == "_glass" then
					if Replicate then
						ShatterGlass:FireServer(Hit, Position, Direction)
					end
				else
					local Distance = (Position - Origin).Magnitude
					local Target = Hit:FindFirstAncestorOfClass("Model")
					local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
					local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
					if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
						if ShowEffects then
							MakeBloodFX(Hit, Position, Normal, Material, true, ClientModule, Miscs, Replicate)
						end
						if Replicate then
							if TargetHumanoid.Health > 0 then							
								Thread:Spawn(function()
									InflictTarget:InvokeServer("Gun", Tool, ClientModule, TargetHumanoid, TargetTorso, Hit, Miscs, Distance)
								end)
								if Tool and Tool.GunClient:FindFirstChild("MarkerEvent") then
									Tool.GunClient.MarkerEvent:Fire(ClientModule, Hit.Name == "Head" and ClientModule.HeadshotEnabled)
								end								
							end
						end
					else
						if ShowEffects then
							MakeImpactFX(Hit, Position, Normal, Material, true, ClientModule, Miscs, Replicate)
						end
					end					
				end
			end
		else
			if ClientModule.ExplosionSoundEnabled then
				local SoundTable = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionSoundIDs, ClientModule.ExplosionSoundIDs)
				local Attachment = Instance.new("Attachment")
				Attachment.CFrame = CFrame.new(Position)
				Attachment.Parent = Workspace.Terrain
				local Sound = Instance.new("Sound")
				Sound.SoundId = "rbxassetid://"..SoundTable[math.random(1, #SoundTable)]
				Sound.PlaybackSpeed = Random.new():NextNumber(AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionSoundPitchMin, ClientModule.ExplosionSoundPitchMin), AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionSoundPitchMax, ClientModule.ExplosionSoundPitchMax))
				Sound.Volume = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionSoundVolume, ClientModule.ExplosionSoundVolume)
				Sound.Parent = Attachment
				Sound:Play()
				Debris:AddItem(Attachment, 10)		
			end

			local Explosion = Instance.new("Explosion")
			Explosion.BlastRadius = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionRadius, ClientModule.ExplosionRadius)
			Explosion.BlastPressure = 0
			Explosion.ExplosionType = Enum.ExplosionType.NoCraters
			Explosion.Position = Position
			Explosion.Parent = Camera

			local SurfaceCF = CFrame.new(Position, Position + Normal)

			if ClientModule.CustomExplosion then
				Explosion.Visible = false

				if ShowEffects then
					local Attachment = Instance.new("Attachment")
					Attachment.CFrame = SurfaceCF
					Attachment.Parent = Workspace.Terrain

					for i, v in pairs(Miscs.ExplosionEffectFolder:GetChildren()) do
						if v.ClassName == "ParticleEmitter" then
							local Count = 1
							local Particle = v:Clone()
							Particle.Parent = Attachment
							if Particle:FindFirstChild("EmitCount") then
								Count = Particle.EmitCount.Value
							end
							Thread:Delay(0.01, function()
								if OptimalEffects then
									local QualityLevel = UserSettings().GameSettings.SavedQualityLevel
									if QualityLevel == Enum.SavedQualitySetting.Automatic then
										local Compressor = 1 / 2
										Particle:Emit(Count * Compressor)
									else
										local Compressor = QualityLevel.Value / 21
										Particle:Emit(Count * Compressor)
									end
								else
									Particle:Emit(Count)
								end
								Debris:AddItem(Particle, Particle.Lifetime.Max)
							end)
						end
					end

					Debris:AddItem(Attachment, 10)
				end
			end	

			local HitHumanoids = {}

			Explosion.Hit:Connect(function(HitPart, HitDist)
				if HitPart and Replicate then
					if HitPart.Parent and HitPart.Name == "HumanoidRootPart" or HitPart.Name == "Head" then
						local Target = HitPart:FindFirstAncestorOfClass("Model")
						local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
						local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
						if TargetHumanoid then
							if TargetHumanoid.Health > 0 then
								if not HitHumanoids[TargetHumanoid] then
									if ClientModule.ExplosionKnockback then
										local Multipler = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionKnockbackMultiplierOnTarget, ClientModule.ExplosionKnockbackMultiplierOnTarget)
										local DistanceFactor = HitDist / AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionRadius, ClientModule.ExplosionRadius)
										DistanceFactor = 1 - DistanceFactor
										local VelocityMod = (TargetTorso.Position - Explosion.Position).Unit * AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionKnockbackPower, ClientModule.ExplosionKnockbackPower) --* DistanceFactor
										local AirVelocity = TargetTorso.Velocity - Vector3.new(0, TargetTorso.Velocity.y, 0) + Vector3.new(VelocityMod.X, 0, VelocityMod.Z)
										if DamageModule.CanDamage(Target, Tool.Parent, ClientModule.FriendlyFire) then
											local TorsoFly = Instance.new("BodyVelocity")
											TorsoFly.MaxForce = Vector3.new(math.huge, 0, math.huge)
											TorsoFly.Velocity = AirVelocity
											TorsoFly.Parent = TargetTorso
											TargetTorso.Velocity = TargetTorso.Velocity + Vector3.new(0, VelocityMod.Y * Multipler, 0)
											Debris:AddItem(TorsoFly, 0.25)	
										else
											if TargetHumanoid.Parent.Name == Player.Name then
												Multipler = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ExplosionKnockbackMultiplierOnPlayer, ClientModule.ExplosionKnockbackMultiplierOnPlayer)
												local TorsoFly = Instance.new("BodyVelocity")
												TorsoFly.MaxForce = Vector3.new(math.huge, 0, math.huge)
												TorsoFly.Velocity = AirVelocity
												TorsoFly.Parent = TargetTorso
												TargetTorso.Velocity = TargetTorso.Velocity + Vector3.new(0, VelocityMod.Y * Multipler, 0)
												Debris:AddItem(TorsoFly, 0.25)
											end
										end							
									end
									Thread:Spawn(function()
										InflictTarget:InvokeServer("Gun", Tool, ClientModule, TargetHumanoid, TargetTorso, Hit, Miscs, HitDist)
									end)
									if Tool and Tool.GunClient:FindFirstChild("MarkerEvent") then
										Tool.GunClient.MarkerEvent:Fire(ClientModule, Hit.Name == "Head" and ClientModule.HeadshotEnabled)
									end									
									HitHumanoids[TargetHumanoid] = true
								end   	
							end
						end
					elseif HitPart.Name == "_glass" then
						ShatterGlass:FireServer(HitPart, HitPart.Position, Direction)
					end
				end
			end)
		end
	end
end

local function OnRayPenetrated(Origin, Direction, Hit, Position, Normal, Material, Tool, ClientModule, Miscs, Replicate)
	local ShowEffects = ScreenCullingEnabled and (ScreenCulling(Position, ScreenCullingRadius) and (Position - Workspace.CurrentCamera.CFrame.p).Magnitude <= RenderDistance) or (Position - Workspace.CurrentCamera.CFrame.p).Magnitude <= RenderDistance	
	if Hit and Hit.Parent then
		if Hit.Name == "_glass" then
			if Replicate then
				ShatterGlass:FireServer(Hit, Position, Direction)
			end
		else
			local Distance = (Position - Origin).Magnitude
			local Target = Hit:FindFirstAncestorOfClass("Model")
			local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
			local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
			if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
				if ShowEffects then
					MakeBloodFX(Hit, Position, Normal, Material, true, ClientModule, Miscs, Replicate)
				end
				if Replicate then
					if TargetHumanoid.Health > 0 then							
						Thread:Spawn(function()
							InflictTarget:InvokeServer("Gun", Tool, ClientModule, TargetHumanoid, TargetTorso, Hit, Miscs, Distance)
						end)
						if Tool and Tool.GunClient:FindFirstChild("MarkerEvent") then
							Tool.GunClient.MarkerEvent:Fire(ClientModule, Hit.Name == "Head" and ClientModule.HeadshotEnabled)
						end						
					end
				end
			else
				if ShowEffects then
					MakeImpactFX(Hit, Position, Normal, Material, true, ClientModule, Miscs, Replicate)
				end
			end			
		end
	end
end

local function OnRayExited(Origin, Direction, Hit, Position, Normal, Material, Tool, ClientModule, Miscs, Replicate)
	local ShowEffects = ScreenCullingEnabled and (ScreenCulling(Position, ScreenCullingRadius) and (Position - Camera.CFrame.p).Magnitude <= RenderDistance) or (Position - Camera.CFrame.p).Magnitude <= RenderDistance
	if Hit and Hit.Parent then
		local Target = Hit:FindFirstAncestorOfClass("Model")
		local TargetHumanoid = Target and Target:FindFirstChildOfClass("Humanoid")
		local TargetTorso = Target and (Target:FindFirstChild("HumanoidRootPart") or Target:FindFirstChild("Head"))
		if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
			if ShowEffects then
				MakeBloodFX(Hit, Position, Normal, Material, true, ClientModule, Miscs, Replicate)
			end
		else
			if ShowEffects then
				MakeImpactFX(Hit, Position, Normal, Material, true, ClientModule, Miscs, Replicate)
			end
		end		
	end
end

function ProjectileHandler:VisualizeHitEffect(Type, Hit, Position, Normal, Material, ClientModule, Miscs, Replicate)
	if Replicate then
		VisualizeHitEffect:FireServer(Type, Hit, Position, Normal, Material, ClientModule, Miscs, nil)
	end
	local ShowEffects = ScreenCullingEnabled and (ScreenCulling(Position, ScreenCullingRadius) and (Position - Camera.CFrame.p).Magnitude <= RenderDistance) or (Position - Camera.CFrame.p).Magnitude <= RenderDistance
	if ShowEffects then
		if Type == "Normal" then
			MakeImpactFX(Hit, Position, Normal, Material, true, ClientModule, Miscs, Replicate, true)
		elseif Type == "Blood" then
			MakeBloodFX(Hit, Position, Normal, Material, true, ClientModule, Miscs, Replicate, true)
		end
	end
end

function ProjectileHandler:SimulateProjectile(Tool, Handle, VMHandle, ClientModule, CLDirections, SVDirections, FirePointObject, MuzzlePointObject, Miscs, Replicate)
	if ClientModule and Tool and Handle then
		if Replicate then 
			VisualizeBullet:FireServer(Tool, Handle, nil, ClientModule, nil, SVDirections, FirePointObject, MuzzlePointObject, Miscs, nil)
		end
		
		local MuzzleObject = MuzzlePointObject
		local Directions = SVDirections

		if VMHandle ~= nil then
			MuzzleObject = VMHandle:FindFirstChild("GunMuzzlePoint"..ClientModule.ModuleName)
			Directions = CLDirections
		end

		if ClientModule.MuzzleFlashEnabled then		
			for i, v in pairs(Miscs.MuzzleFolder:GetChildren()) do
				if v.ClassName == "ParticleEmitter" then
					local Count = 1
					local Particle = v:Clone()
					Particle.Parent = MuzzleObject
					if Particle:FindFirstChild("EmitCount") then
						Count = Particle.EmitCount.Value
					end
					Thread:Delay(0.01, function()
						Particle:Emit(Count)
						Debris:AddItem(Particle, Particle.Lifetime.Max)
					end)
				end
			end	
		end

		if ClientModule.MuzzleLightEnabled then
			local Light = Instance.new("PointLight")
			Light.Brightness = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.LightBrightness, ClientModule.LightBrightness)
			Light.Color = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.LightColor, ClientModule.LightColor)
			Light.Range = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.LightRange, ClientModule.LightRange)
			Light.Shadows = ClientModule.LightShadows
			Light.Enabled = true
			Light.Parent = MuzzleObject
			Debris:AddItem(Light, ClientModule.VisibleTime)
		end
		
		for _, Direction in pairs(Directions) do
			if FirePointObject ~= nil then
				local CFrm = FirePointObject.WorldCFrame
				local Origin, Dir = FirePointObject.WorldPosition, Direction
				
				if VMHandle ~= nil then
					CFrm = VMHandle:FindFirstChild("GunFirePoint"..ClientModule.ModuleName).WorldCFrame
					Origin = VMHandle:FindFirstChild("GunFirePoint"..ClientModule.ModuleName).WorldPosition
				end
				
				local IgnoreList = {Camera, Tool, Tool.Parent}

				local HumanoidRootPart = Tool.Parent:WaitForChild("HumanoidRootPart", 1)
				local TipCFrame = CFrm
				local TipPos = TipCFrame.Position
				local TipDir = TipCFrame.LookVector
				local AmountToCheatBack = math.abs((HumanoidRootPart.Position - TipPos):Dot(TipDir)) + 1
				local GunRay = Ray.new(TipPos - TipDir.Unit * AmountToCheatBack, TipDir.Unit * AmountToCheatBack)
				local HitPart, HitPoint = Workspace:FindPartOnRayWithIgnoreList(GunRay, IgnoreList, false, true)
				if HitPart and math.abs((TipPos - HitPoint).Magnitude) > 0 then
					Origin = HitPoint - TipDir.Unit * 0.1
					--Dir = TipDir.Unit
				end
				

				local Vel = Dir * AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.BulletSpeed, ClientModule.BulletSpeed)
				
				ParticleFramework.new({
					position = Origin,
					velocity = Vel,
					acceleration = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.BulletAcceleration, ClientModule.BulletAcceleration),
					visible = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.VisibleBullet, ClientModule.VisibleBullet),
					motionblur = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.MotionBlur, ClientModule.MotionBlur),
					size = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.BulletSize, ClientModule.BulletSize),
					bloom = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.BulletBloom, ClientModule.BulletBloom),
					brightness = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.BulletBrightness, ClientModule.BulletBrightness),
					windspeed = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.WindSpeed, ClientModule.WindSpeed),
					windresistance = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.WindResistance, ClientModule.WindResistance),
					life = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.BulletLifetime, ClientModule.BulletLifetime),
					visualorigin = Origin,
					visualdirection = Dir,
					penetrationtype = ClientModule.PenetrationType,
					penetrationdepth = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.PenetrationDepth, ClientModule.PenetrationDepth),
					penetrationamount = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.PenetrationAmount, ClientModule.PenetrationAmount),
					ricochetamount = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.RicochetAmount, ClientModule.RicochetAmount),
					bounceelasticity = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.BounceElasticity, ClientModule.BounceElasticity),
					frictionconstant = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.FrictionConstant, ClientModule.FrictionConstant),
					noexplosionwhilebouncing = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.NoExplosionWhileBouncing, ClientModule.NoExplosionWhileBouncing),
					stopbouncingonhithumanoid = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.StopBouncingOnHitHumanoid, ClientModule.StopBouncingOnHitHumanoid),
					superricochet = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.SuperRicochet, ClientModule.SuperRicochet),
					bullettype = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.BulletType, ClientModule.BulletType),
					projectiletype = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.ProjectileType, ClientModule.ProjectileType),
					canspinpart = ClientModule.CanSpinPart,
					spinx = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.SpinX, ClientModule.SpinX),
					spiny = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.SpinY, ClientModule.SpinY),
					spinz = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.SpinZ, ClientModule.SpinZ),
					homing = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.Homing, ClientModule.Homing),
					homingdistance = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.HomingDistance, ClientModule.HomingDistance),
					turnratepersecond = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.TurnRatePerSecond, ClientModule.TurnRatePerSecond),
					homethroughwall = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.HomeThroughWall, ClientModule.HomeThroughWall),
					lockononhovering = ClientModule.LockOnOnHovering,
					lockedentity = Miscs.LockedEntity,
					toucheventontimeout = AddressTableValue(ClientModule.ChargedShotAdvanceEnabled, Miscs.ChargeLevel, ClientModule.ChargeAlterTable.TouchEventOnTimeout, ClientModule.TouchEventOnTimeout),
					hitscan = ClientModule.HitscanMode,
					character = Tool.Parent,
					friendlyfire = ClientModule.FriendlyFire,
					physicsignore = IgnoreList,
					ontouch = function(self, part, pos, norm, material)
						OnRayHit(Origin,
							Dir,
							part,
							pos,
							norm,
							material,
							Tool,
							ClientModule,
							Miscs,
							Replicate)
					end,
					onenter = function(self, part, pos, norm, material, exited)
						OnRayPenetrated(Origin,
							Dir,
							part,
							pos,
							norm,
							material,
							Tool,
							ClientModule,
							Miscs,
							Replicate)
					end,
					onexit = function(self, exitpart, exitpos, exitnorm, exitmaterial)
						OnRayExited(Origin,
							Dir,
							exitpart,
							exitpos,
							exitnorm,
							exitmaterial,
							Tool,
							ClientModule,
							Miscs,
							Replicate)
					end,
					onbounce = function(self, part, pos, norm, material, noexplosion)
						OnRayBounced(Origin,
							Dir,
							part,
							pos,
							norm,
							material,
							Tool,
							ClientModule,
							Miscs,
							noexplosion,
							Replicate)
					end,
					onstep = function(part, dt)
						if ClientModule.WhizSoundEnabled then
							if not Replicate then
								local vel = part.velocity
								local dpos = dt * vel
								local pos = part.position - dpos
								local headpos = Camera.CFrame.p
								local d = Vector3.new().Dot(headpos - pos, dpos) / Vector3.new().Dot(dpos, dpos)
								--print(d)
								if d > 0 and d < 1 then
									local dist = (pos + d * dpos - headpos).Magnitude
									dist = dist < 2 and 2 or dist
									if dist < ClientModule.WhizDistance then --128
										--local loudness = 1 - (mag / ClientModule.WhizDistance)
										local sound = Instance.new("Sound")
										sound.SoundId = "rbxassetid://"..ClientModule.WhizSoundID[math.random(1, #ClientModule.WhizSoundID)]
										sound.Volume = ClientModule.WhizSoundVolume --loudness
										sound.PlaybackSpeed = Random.new():NextNumber(ClientModule.WhizSoundPitchMin, ClientModule.WhizSoundPitchMax)
										sound.Parent = SoundService				
										sound:Play()
										
										repeat task.wait() until sound.TimeLength > 0
										
										Debris:AddItem(sound, sound.TimeLength / sound.PlaybackSpeed)
									end
								end
							end
						end
					end
				})			
			end
		end
	end
end

return ProjectileHandler
