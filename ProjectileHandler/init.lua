local ProjectileHandler = {}

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Modules = ReplicatedStorage:WaitForChild("Modules")
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
			print(material.Name)
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
