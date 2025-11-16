-- PRODUCTION-READY Client-Side Performance Optimization for Roblox
-- Place this in StarterPlayer > StarterPlayerScripts
-- Tag objects with "Cullable", "LODModel", "OptimizePhysics" using CollectionService for best results

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Configuration
local CONFIG = {
	-- Occlusion Culling
	occlusionEnabled = true,
	occlusionCheckInterval = 0.4,
	occlusionNearDistance = 150, -- Always visible within this range
	occlusionFarDistance = 700, -- Start general culling beyond this
	occlusionViewportMargin = 0.25, -- Increased margin to prevent false culling (25%)
	useSmoothTransition = true, -- Fade instead of instant hide
	fadeTime = 0.3,
	
	-- LOD System
	lodEnabled = true,
	lodUpdateInterval = 0.6,
	lodDistances = {
		high = 120,
		medium = 300,
		low = 500,
		cull = 800
	},
	
	-- Distance Culling
	maxRenderDistance = 1200,
	cullPlayersDistance = 300, -- Hide other players beyond this distance
	cullModelsDistance = 400, -- Hide models beyond this distance
	cullMeshesDistance = 500, -- Hide meshes beyond this distance
	particleMaxDistance = 350,
	lightMaxDistance = 250,
	
	-- Performance
	targetFPS = 55,
	autoAdjustQuality = true, -- Disable features if FPS drops
	
	-- Limits (prevent overhead)
	maxCullableParts = 1000, -- Increased to handle players + models + meshes
	maxLODModels = 50,
	maxPhysicsParts = 200,
	
	-- Update intervals
	textureOptimizeInterval = 4.0,
	physicsOptimizeInterval = 1.5,
	fpsCheckInterval = 2.0,
	
	-- Safety
	neverCullCharacters = false, -- Changed to false - now allows culling
	neverCullTools = true,
	preserveGameplayObjects = true,
}

-- Tags for CollectionService
local TAGS = {
	CULLABLE = "Cullable", -- Tag parts that can be hidden when far
	LOD_MODEL = "LODModel", -- Tag models for LOD system
	PHYSICS_OPTIMIZE = "OptimizePhysics", -- Tag for physics optimization
	NEVER_CULL = "NeverCull", -- Tag to protect important objects
}

-- ==================== UTILITY FUNCTIONS ====================
local Utils = {}

function Utils.GetDistanceToCamera(position)
	return (position - camera.CFrame.Position).Magnitude
end

function Utils.IsInViewportWithMargin(worldPosition, margin)
	local viewportPoint, inViewport = camera:WorldToViewportPoint(worldPosition)
	
	-- If behind camera (Z < 0), definitely not visible
	if viewportPoint.Z < 0 then
		return false
	end
	
	local screenSize = camera.ViewportSize
	local marginX = screenSize.X * margin
	local marginY = screenSize.Y * margin
	
	-- Check if within expanded viewport bounds
	return viewportPoint.X > -marginX and 
	       viewportPoint.X < screenSize.X + marginX and
	       viewportPoint.Y > -marginY and 
	       viewportPoint.Y < screenSize.Y + marginY
end

function Utils.GetModelCenter(model)
	-- Calculate center even without PrimaryPart
	if model.PrimaryPart then
		return model.PrimaryPart.Position
	end
	
	local cf, size = model:GetBoundingBox()
	return cf.Position
end

function Utils.ShouldNeverCull(object)
	-- Safety checks for gameplay-critical objects
	if CollectionService:HasTag(object, TAGS.NEVER_CULL) then
		return true
	end
	
	-- Never cull Tools
	if CONFIG.neverCullTools and object:IsA("Tool") then
		return true
	end
	
	-- Allow culling characters/models - removed the safety check
	return false
end

function Utils.TweenTransparency(object, targetTransparency, tweenTime)
	if not CONFIG.useSmoothTransition then
		object.Transparency = targetTransparency
		return
	end
	
	local tween = TweenService:Create(
		object,
		TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = targetTransparency}
	)
	tween:Play()
end

-- ==================== PERFORMANCE MONITOR ====================
local PerformanceMonitor = {
	frameCount = 0,
	lastFPSCheck = 0,
	currentFPS = 60,
	fpsHistory = {},
	qualityReduced = false,
}

function PerformanceMonitor:Update(deltaTime)
	self.frameCount = self.frameCount + 1
	self.lastFPSCheck = self.lastFPSCheck + deltaTime
	
	if self.lastFPSCheck >= CONFIG.fpsCheckInterval then
		self.currentFPS = self.frameCount / self.lastFPSCheck
		
		-- Smooth FPS with rolling average
		table.insert(self.fpsHistory, self.currentFPS)
		if #self.fpsHistory > 5 then
			table.remove(self.fpsHistory, 1)
		end
		
		local sum = 0
		for _, fps in ipairs(self.fpsHistory) do
			sum = sum + fps
		end
		self.currentFPS = sum / #self.fpsHistory
		
		-- Auto-adjust quality if enabled
		if CONFIG.autoAdjustQuality then
			self:AutoAdjustQuality()
		end
		
		self.frameCount = 0
		self.lastFPSCheck = 0
	end
end

function PerformanceMonitor:AutoAdjustQuality()
	local fps = self.currentFPS
	
	-- If FPS is consistently low, reduce quality
	if fps < CONFIG.targetFPS * 0.75 and not self.qualityReduced then
		warn("[Performance] Low FPS detected, reducing quality...")
		CONFIG.occlusionFarDistance = 500 -- More aggressive culling
		CONFIG.particleMaxDistance = 200
		CONFIG.lightMaxDistance = 150
		self.qualityReduced = true
	elseif fps > CONFIG.targetFPS * 1.1 and self.qualityReduced then
		-- Restore quality if FPS improves
		CONFIG.occlusionFarDistance = 700
		CONFIG.particleMaxDistance = 350
		CONFIG.lightMaxDistance = 250
		self.qualityReduced = false
	end
end

function PerformanceMonitor:GetFPS()
	return math.floor(self.currentFPS)
end

-- ==================== OPTIMIZED OCCLUSION CULLING ====================
local OcclusionCuller = {
	trackedParts = {},
	partStates = {},
	lastCheck = 0,
}

function OcclusionCuller:Initialize()
	local tracked = 0
	
	-- Track ALL players (including their characters)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player and plr.Character then
			for _, part in ipairs(plr.Character:GetDescendants()) do
				if part:IsA("BasePart") then
					if tracked >= CONFIG.maxCullableParts then break end
					self:TrackPart(part)
					tracked = tracked + 1
				end
			end
		end
	end
	
	-- Listen for new players
	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function(char)
			task.wait(0.5) -- Wait for character to load
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and #self.trackedParts < CONFIG.maxCullableParts then
					self:TrackPart(part)
				end
			end
		end)
	end)
	
	-- Track all Models in workspace
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") and obj ~= player.Character then
			for _, part in ipairs(obj:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("MeshPart") then
					if tracked >= CONFIG.maxCullableParts then break end
					self:TrackPart(part)
					tracked = tracked + 1
				end
			end
		end
	end
	
	-- Track standalone MeshParts
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("MeshPart") and not obj.Parent:IsA("Model") then
			if tracked >= CONFIG.maxCullableParts then break end
			self:TrackPart(part)
			tracked = tracked + 1
		end
	end
	
	-- Also track tagged objects
	for _, part in ipairs(CollectionService:GetTagged(TAGS.CULLABLE)) do
		if part:IsA("BasePart") then
			if tracked >= CONFIG.maxCullableParts then break end
			self:TrackPart(part)
			tracked = tracked + 1
		end
	end
	
	-- Listen for new tagged objects
	CollectionService:GetInstanceAddedSignal(TAGS.CULLABLE):Connect(function(part)
		if part:IsA("BasePart") and #self.trackedParts < CONFIG.maxCullableParts then
			self:TrackPart(part)
		end
	end)
	
	print("[Occlusion] Tracking " .. tracked .. " cullable parts (including players, models, and meshes)")
end

function OcclusionCuller:TrackPart(part)
	table.insert(self.trackedParts, part)
	self.partStates[part] = {
		originalTransparency = part.Transparency,
		originalCanCollide = part.CanCollide,
		isHidden = false,
		lastStateChange = 0, -- Prevent rapid toggling
	}
end

function OcclusionCuller:ShouldCullPart(part, distance)
	-- BOTH conditions must be true: out of range AND not in viewport
	
	-- First check: Is it out of range?
	local isOutOfRange = false
	
	-- Check if part is a player character
	local isPlayerPart = false
	local ancestor = part.Parent
	while ancestor do
		if ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then
			isPlayerPart = true
			break
		end
		ancestor = ancestor.Parent
	end
	
	-- Check distance based on object type
	if isPlayerPart then
		isOutOfRange = distance > CONFIG.cullPlayersDistance
	elseif part.Parent and part.Parent:IsA("Model") then
		isOutOfRange = distance > CONFIG.cullModelsDistance
	elseif part:IsA("MeshPart") then
		isOutOfRange = distance > CONFIG.cullMeshesDistance
	else
		isOutOfRange = distance > CONFIG.occlusionFarDistance
	end
	
	-- Second check: Is it outside viewport?
	local isOutsideViewport = not Utils.IsInViewportWithMargin(part.Position, CONFIG.occlusionViewportMargin)
	
	-- BOTH must be true to cull
	if isOutOfRange and isOutsideViewport then
		return true
	end
	
	return false
end

function OcclusionCuller:Update(deltaTime)
	if not CONFIG.occlusionEnabled then return end
	
	self.lastCheck = self.lastCheck + deltaTime
	if self.lastCheck < CONFIG.occlusionCheckInterval then
		return
	end
	self.lastCheck = 0
	
	local currentTime = tick()
	
	for i = #self.trackedParts, 1, -1 do
		local part = self.trackedParts[i]
		
		if not part or not part.Parent then
			table.remove(self.trackedParts, i)
			self.partStates[part] = nil
		else
			local state = self.partStates[part]
			if not state then continue end
			
			local distance = Utils.GetDistanceToCamera(part.Position)
			local shouldCull = self:ShouldCullPart(part, distance)
			
			-- Prevent rapid toggling (hysteresis)
			if currentTime - state.lastStateChange < 1.0 then
				continue
			end
			
			if shouldCull and not state.isHidden then
				-- Hide the part
				Utils.TweenTransparency(part, 1, CONFIG.fadeTime)
				part.CanCollide = false
				state.isHidden = true
				state.lastStateChange = currentTime
			elseif not shouldCull and state.isHidden then
				-- Restore the part
				Utils.TweenTransparency(part, state.originalTransparency, CONFIG.fadeTime)
				part.CanCollide = state.originalCanCollide
				state.isHidden = false
				state.lastStateChange = currentTime
			end
		end
	end
end

-- ==================== IMPROVED LOD SYSTEM ====================
local LODSystem = {
	lodModels = {},
	modelStates = {},
	lastUpdate = 0,
}

function LODSystem:Initialize()
	-- Use tagged models
	for _, model in ipairs(CollectionService:GetTagged(TAGS.LOD_MODEL)) do
		if model:IsA("Model") then
			self:RegisterModel(model)
		end
	end
	
	-- Listen for new tagged models
	CollectionService:GetInstanceAddedSignal(TAGS.LOD_MODEL):Connect(function(model)
		if model:IsA("Model") and #self.lodModels < CONFIG.maxLODModels then
			self:RegisterModel(model)
		end
	end)
	
	print("[LOD] Managing " .. #self.lodModels .. " models")
end

function LODSystem:RegisterModel(model)
	if #self.lodModels >= CONFIG.maxLODModels then return end
	
	table.insert(self.lodModels, model)
	
	-- Cache descendants for efficiency
	local descendants = {
		particles = {},
		lights = {},
		guis = {},
		parts = {},
	}
	
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
			table.insert(descendants.particles, obj)
		elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
			table.insert(descendants.lights, obj)
		elseif obj:IsA("SurfaceGui") or obj:IsA("BillboardGui") then
			table.insert(descendants.guis, obj)
		elseif obj:IsA("BasePart") then
			table.insert(descendants.parts, obj)
		end
	end
	
	self.modelStates[model] = {
		currentLOD = "high",
		descendants = descendants,
		originalParent = model.Parent,
	}
end

function LODSystem:GetLODLevel(distance)
	if distance < CONFIG.lodDistances.high then
		return "high"
	elseif distance < CONFIG.lodDistances.medium then
		return "medium"
	elseif distance < CONFIG.lodDistances.low then
		return "low"
	elseif distance < CONFIG.lodDistances.cull then
		return "verylow"
	else
		return "culled"
	end
end

function LODSystem:ApplyLOD(model, lodLevel)
	local state = self.modelStates[model]
	if not state or state.currentLOD == lodLevel then
		return
	end
	
	local desc = state.descendants
	
	-- Apply LOD by disabling expensive features
	if lodLevel == "high" then
		for _, obj in ipairs(desc.particles) do obj.Enabled = true end
		for _, obj in ipairs(desc.lights) do obj.Enabled = true end
		for _, obj in ipairs(desc.guis) do obj.Enabled = true end
	elseif lodLevel == "medium" then
		for _, obj in ipairs(desc.particles) do obj.Enabled = true end
		for _, obj in ipairs(desc.lights) do obj.Enabled = false end
		for _, obj in ipairs(desc.guis) do obj.Enabled = true end
	elseif lodLevel == "low" then
		for _, obj in ipairs(desc.particles) do obj.Enabled = false end
		for _, obj in ipairs(desc.lights) do obj.Enabled = false end
		for _, obj in ipairs(desc.guis) do obj.Enabled = false end
	elseif lodLevel == "verylow" then
		for _, obj in ipairs(desc.particles) do obj.Enabled = false end
		for _, obj in ipairs(desc.lights) do obj.Enabled = false end
		for _, obj in ipairs(desc.guis) do obj.Enabled = false end
		-- Disable shadows for parts
		for _, part in ipairs(desc.parts) do
			part.CastShadow = false
		end
	elseif lodLevel == "culled" then
		-- Use LocalTransparencyModifier instead of removing from Workspace
		-- This preserves scripts and welds
		for _, part in ipairs(desc.parts) do
			part.LocalTransparencyModifier = 1
			part.CanCollide = false
		end
	end
	
	-- Restore if returning from culled state
	if state.currentLOD == "culled" and lodLevel ~= "culled" then
		for _, part in ipairs(desc.parts) do
			part.LocalTransparencyModifier = 0
			part.CanCollide = true
		end
	end
	
	state.currentLOD = lodLevel
end

function LODSystem:Update(deltaTime)
	if not CONFIG.lodEnabled then return end
	
	self.lastUpdate = self.lastUpdate + deltaTime
	if self.lastUpdate < CONFIG.lodUpdateInterval then
		return
	end
	self.lastUpdate = 0
	
	for i = #self.lodModels, 1, -1 do
		local model = self.lodModels[i]
		
		if not model or not model.Parent then
			table.remove(self.lodModels, i)
			self.modelStates[model] = nil
		else
			local center = Utils.GetModelCenter(model)
			local distance = Utils.GetDistanceToCamera(center)
			local lodLevel = self:GetLODLevel(distance)
			self:ApplyLOD(model, lodLevel)
		end
	end
end

-- ==================== SAFE PHYSICS OPTIMIZER ====================
local PhysicsOptimizer = {
	trackedParts = {},
	partStates = {},
	lastUpdate = 0,
	initialized = false,
}

function PhysicsOptimizer:Initialize()
	if self.initialized then return end
	self.initialized = true
	
	-- Use tagged parts
	for _, part in ipairs(CollectionService:GetTagged(TAGS.PHYSICS_OPTIMIZE)) do
		if part:IsA("BasePart") then
			self:TrackPart(part)
		end
	end
	
	-- Fallback: track unanchored parts
	if #self.trackedParts == 0 then
		for _, part in ipairs(Workspace:GetDescendants()) do
			if part:IsA("BasePart") and not part.Anchored and not Utils.ShouldNeverCull(part) then
				if #self.trackedParts >= CONFIG.maxPhysicsParts then break end
				self:TrackPart(part)
			end
		end
	end
	
	print("[Physics] Tracking " .. #self.trackedParts .. " physics parts")
end

function PhysicsOptimizer:TrackPart(part)
	table.insert(self.trackedParts, part)
	-- Snapshot ONCE at initialization
	self.partStates[part] = {
		originalAnchored = part.Anchored,
		isOptimized = false,
	}
end

function PhysicsOptimizer:Update(deltaTime)
	self.lastUpdate = self.lastUpdate + deltaTime
	if self.lastUpdate < CONFIG.physicsOptimizeInterval then
		return
	end
	self.lastUpdate = 0
	
	for i = #self.trackedParts, 1, -1 do
		local part = self.trackedParts[i]
		
		if not part or not part.Parent then
			table.remove(self.trackedParts, i)
			self.partStates[part] = nil
		else
			local state = self.partStates[part]
			if not state then continue end
			
			local distance = Utils.GetDistanceToCamera(part.Position)
			
			-- Anchor if very far AND was originally unanchored
			if distance > CONFIG.maxRenderDistance * 0.7 and not state.originalAnchored then
				if not state.isOptimized then
					part.Anchored = true
					state.isOptimized = true
				end
			else
				-- Restore original state when near
				if state.isOptimized then
					part.Anchored = state.originalAnchored
					state.isOptimized = false
				end
			end
		end
	end
end

-- ==================== EFFICIENT EFFECT OPTIMIZER ====================
local EffectOptimizer = {
	particles = {},
	lights = {},
	decals = {},
	lastUpdate = 0,
	initialized = false,
}

function EffectOptimizer:Initialize()
	if self.initialized then return end
	self.initialized = true
	
	-- Cache all effects once (not every frame)
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
			table.insert(self.particles, obj)
		elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
			table.insert(self.lights, obj)
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			table.insert(self.decals, obj)
			-- Store original transparency
			if not obj:GetAttribute("OriginalTransparency") then
				obj:SetAttribute("OriginalTransparency", obj.Transparency)
			end
		end
	end
	
	print("[Effects] Cached " .. (#self.particles + #self.lights + #self.decals) .. " effects")
end

function EffectOptimizer:Update(deltaTime)
	self.lastUpdate = self.lastUpdate + deltaTime
	if self.lastUpdate < CONFIG.textureOptimizeInterval then
		return
	end
	self.lastUpdate = 0
	
	-- Optimize particles
	for i = #self.particles, 1, -1 do
		local emitter = self.particles[i]
		if not emitter or not emitter.Parent then
			table.remove(self.particles, i)
		else
			local parent = emitter.Parent
			if parent:IsA("BasePart") then
				local distance = Utils.GetDistanceToCamera(parent.Position)
				emitter.Enabled = distance < CONFIG.particleMaxDistance
			end
		end
	end
	
	-- Optimize lights
	for i = #self.lights, 1, -1 do
		local light = self.lights[i]
		if not light or not light.Parent then
			table.remove(self.lights, i)
		else
			local parent = light.Parent
			if parent:IsA("BasePart") then
				local distance = Utils.GetDistanceToCamera(parent.Position)
				light.Enabled = distance < CONFIG.lightMaxDistance
			end
		end
	end
	
	-- Optimize decals/textures
	for i = #self.decals, 1, -1 do
		local decal = self.decals[i]
		if not decal or not decal.Parent then
			table.remove(self.decals, i)
		else
			local parent = decal.Parent
			if parent:IsA("BasePart") then
				local distance = Utils.GetDistanceToCamera(parent.Position)
				local originalTransparency = decal:GetAttribute("OriginalTransparency") or 0
				
				if distance > 900 then
					decal.Transparency = 1
				else
					decal.Transparency = originalTransparency
				end
			end
		end
	end
end

-- ==================== MAIN OPTIMIZATION MANAGER ====================
local OptimizationManager = {
	initialized = false,
	lastFrameTime = tick(),
	stats = {
		occlusionHidden = 0,
		lodModels = 0,
		physicsOptimized = 0,
	}
}

function OptimizationManager:Initialize()
	if self.initialized then return end
	self.initialized = true
	
	print("[OptimizationManager] Initializing systems...")
	
	-- Wait for character
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	task.wait(2) -- Let world load
	
	-- Initialize all systems
	OcclusionCuller:Initialize()
	LODSystem:Initialize()
	PhysicsOptimizer:Initialize()
	EffectOptimizer:Initialize()
	
	print("[OptimizationManager] ✓ All systems active!")
end

function OptimizationManager:Update()
	local currentTime = tick()
	local deltaTime = currentTime - self.lastFrameTime
	self.lastFrameTime = currentTime
	
	-- Update all systems
	PerformanceMonitor:Update(deltaTime)
	OcclusionCuller:Update(deltaTime)
	LODSystem:Update(deltaTime)
	PhysicsOptimizer:Update(deltaTime)
	EffectOptimizer:Update(deltaTime)
	
	-- Update stats
	self.stats.occlusionHidden = #OcclusionCuller.trackedParts
	self.stats.lodModels = #LODSystem.lodModels
	self.stats.physicsOptimized = #PhysicsOptimizer.trackedParts
end

-- ==================== PERFORMANCE GUI ====================
local function CreatePerformanceGUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PerformanceStats"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	
	local frame = Instance.new("TextLabel")
	frame.Size = UDim2.new(0, 240, 0, 120)
	frame.Position = UDim2.new(1, -250, 0, 10)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.TextColor3 = Color3.fromRGB(255, 255, 255)
	frame.TextSize = 13
	frame.Font = Enum.Font.Code
	frame.TextXAlignment = Enum.TextXAlignment.Left
	frame.TextYAlignment = Enum.TextYAlignment.Top
	frame.Text = ""
	frame.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = frame
	
	screenGui.Parent = player:WaitForChild("PlayerGui")
	
	-- Update GUI
	task.spawn(function()
		while true do
			task.wait(0.5)
			
			local fps = PerformanceMonitor:GetFPS()
			local memory = math.floor(game:GetService("Stats"):GetTotalMemoryUsageMb())
			local stats = OptimizationManager.stats
			
			local fpsIndicator = fps >= 55 and "🟢" or fps >= 40 and "🟡" or "🔴"
			local qualityStatus = PerformanceMonitor.qualityReduced and "Reduced" or "Normal"
			
			frame.Text = string.format(
				"%s FPS: %d / %d\n💾 Memory: %d MB\n\n👁️ Culled: %d parts\n📦 LOD: %d models\n⚙️ Physics: %d parts\n🎨 Quality: %s",
				fpsIndicator,
				fps,
				CONFIG.targetFPS,
				memory,
				stats.occlusionHidden,
				stats.lodModels,
				stats.physicsOptimized,
				qualityStatus
			)
		end
	end)
end

-- ==================== STARTUP ====================
OptimizationManager:Initialize()

-- Single unified update loop
RunService.Heartbeat:Connect(function()
	OptimizationManager:Update()
end)

CreatePerformanceGUI()

-- Print configuration
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✓ Performance Optimization Active")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("→ Occlusion Culling: " .. (CONFIG.occlusionEnabled and "ON" or "OFF"))
print("→ LOD System: " .. (CONFIG.lodEnabled and "ON" or "OFF"))
print("→ Auto Quality Adjust: " .. (CONFIG.autoAdjustQuality and "ON" or "OFF"))
print("→ Target FPS: " .. CONFIG.targetFPS)
print("→ Player Cull Distance: " .. CONFIG.cullPlayersDistance)
print("→ Model Cull Distance: " .. CONFIG.cullModelsDistance)
print("→ Mesh Cull Distance: " .. CONFIG.cullMeshesDistance)
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("💡 Tip: Tag objects with 'Cullable', 'LODModel', or 'OptimizePhysics' for best results!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
