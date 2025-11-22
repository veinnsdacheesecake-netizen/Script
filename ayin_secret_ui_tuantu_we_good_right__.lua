local Players = game:GetService('Players')
if #Players:GetPlayers() > 1 then
    Players.LocalPlayer:Kick("stop using this in public.")
    return
end
Players.PlayerAdded:Connect(function()
    if #Players:GetPlayers() > 1 then
        Players.LocalPlayer:Kick("am not letting you ruin other ppl fun anymore.")
    end
end)

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({Name = 'ayin work ui', LoadingTitle = 'loading'})
local Players = game:GetService('Players')
local RepStorage = game:GetService('ReplicatedStorage')
local LocalPlayer = Players.LocalPlayer
local function listChildren(folder)
	local t = {}
	if folder then
		for _, v in ipairs(folder:GetChildren()) do
			table.insert(t, v.Name)
		end
	end
	table.sort(t)
	return t
end
local function getFolder(root, ...)
	local cur = root
	for i = 1, select('#', ...) do
		local n = select(i, ...)
		if not cur then return nil end
		cur = cur:FindFirstChild(n)
	end
	return cur
end
local function normalizeSelected(v)
	if type(v) == 'string' then return v end
	if typeof(v) == 'Instance' then return v.Name end
	if type(v) == 'table' then
		if v[1] then return v[1] end
		if v.Name then return v.Name end
	end
	return tostring(v)
end
local function titleCase(s)
	if not s or #s == 0 then return '' end
	return string.upper(string.sub(s, 1, 1)) .. string.lower(string.sub(s, 2))
end
local function getAbnoNames()
	return listChildren(getFolder(workspace, 'Abnormalities'))
end
local function getTalentNames()
	return listChildren(getFolder(RepStorage, 'Assets', 'Talents'))
end
local abnoList = getAbnoNames()
local talentList = getTalentNames()
local selectedWork = 'Instinct'
local selectedTalentRaw = talentList[1] or ''
local selectedAbnos = {}
local Tab = Window:CreateTab('abno working')
Tab:CreateSection('Controls')
Tab:CreateSection('Select Abnormalities')
for _, abno in ipairs(abnoList) do
	Tab:CreateToggle({
		Name = abno,
		CurrentValue = false,
		Callback = function(Value)
			if Value then
				if not table.find(selectedAbnos, abno) then
					table.insert(selectedAbnos, abno)
				end
			else
				for i, v in ipairs(selectedAbnos) do
					if v == abno then
						table.remove(selectedAbnos, i)
						break
					end
				end
			end
		end,
	})
end
Tab:CreateButton({
	Name = 'Clear Selection',
	Callback = function()
		selectedAbnos = {}
	end,
})
Tab:CreateDropdown({
	Name = 'Work Type',
	Options = { 'Instinct', 'Insight', 'Attachment', 'Repression' },
	CurrentOption = selectedWork,
	Callback = function(opt)
		selectedWork = opt
	end,
})
Tab:CreateButton({
	Name = 'Work',
	Callback = function()
		pcall(function()
			if #selectedAbnos == 0 then return end
			local abnoRoot = getFolder(workspace, 'Abnormalities')
			if not abnoRoot then return end
			local remote = getFolder(RepStorage, 'Assets', 'RemoteEvents', 'WorkEvent')
			if not remote then return end
			local flavor = titleCase(normalizeSelected(selectedWork))
			for _, abnoName in ipairs(selectedAbnos) do
				local sel = normalizeSelected(abnoName)
				local abno = abnoRoot:FindFirstChild(sel)
				if abno then
					local wt = abno:FindFirstChild('WorkTablet')
					if wt then remote:FireServer(wt, flavor) end
				end
			end
		end)
	end,
})
local CardTab = Window:CreateTab('card selector')
CardTab:CreateSection('Talent')
CardTab:CreateDropdown({
	Name = 'Talent',
	Options = talentList,
	CurrentOption = selectedTalentRaw,
	Callback = function(opt)
		selectedTalentRaw = opt
	end,
})
CardTab:CreateButton({
	Name = 'Select card',
	Callback = function()
		pcall(function()
			local sel = normalizeSelected(selectedTalentRaw)
			if sel == '' then return end
			local remote = getFolder(RepStorage, 'Assets', 'RemoteEvents', 'SelectCardEvent')
			if not remote then return end
			remote:FireServer(sel)
		end)
	end,
})
local WeaponTab = Window:CreateTab('weapon mod')
WeaponTab:CreateSection('Hitbox Settings')
local hitboxSize = 10
WeaponTab:CreateInput({
	Name = 'Hitbox Size',
	PlaceholderText = '10',
	Callback = function(text)
		local v = tonumber(text)
		if v and v > 0 then hitboxSize = v end
	end,
})
local function applyHitboxToWeapon(tool)
    if tool and tool:IsA("Tool") then
        local anims = tool:FindFirstChild("Animations")
        if anims then
            local attackAnims = anims:FindFirstChild("AttackAnimations")
            if attackAnims then
                for _, animFolder in ipairs(attackAnims:GetChildren()) do
                    local hitboxValue = animFolder:FindFirstChild("HitboxSize")
                    if hitboxValue and hitboxValue:IsA("Vector3Value") then
                        hitboxValue.Value = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                    end
                end
            end
        end
    end
end
local function applyHitboxToAllWeapons()
	local character = LocalPlayer.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then applyHitboxToWeapon(child) end
		end
	end
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") then applyHitboxToWeapon(child) end
		end
	end
end
WeaponTab:CreateButton({
	Name = 'Apply Hitbox Size',
	Callback = function()
		applyHitboxToAllWeapons()
	end,
})
WeaponTab:CreateSection('Damage Settings')
local dmgMax = 1500
local dmgMin = 1500
WeaponTab:CreateInput({
	Name = 'Max Damage',
	PlaceholderText = '50',
	Callback = function(text)
		local v = tonumber(text)
		if v then dmgMax = v end
	end,
})
WeaponTab:CreateInput({
	Name = 'Min Damage',
	PlaceholderText = '50',
	Callback = function(text)
		local v = tonumber(text)
		if v then dmgMin = v end
	end,
})
WeaponTab:CreateSection('Attack Speed')
local attackSpeedValue = 5
local infiniteAttackSpeed = false
WeaponTab:CreateInput({
	Name = 'Attack Speed',
	PlaceholderText = '5',
	Callback = function(text)
		local v = tonumber(text)
		if v then attackSpeedValue = v end
	end,
})
local function setAttackSpeedValue(val)
	pcall(function()
		local units = workspace:WaitForChild('Units', 2)
		local playerUnit = units and units:FindFirstChild(LocalPlayer.Name)
		local charStats = playerUnit and playerUnit:FindFirstChild('CharStats')
		local attackSpeed = charStats and charStats:FindFirstChild('AttackSpeed')
		if attackSpeed then attackSpeed.Value = val end
	end)
end
WeaponTab:CreateToggle({
	Name = 'Infinite Attack Speed',
	CurrentValue = false,
	Callback = function(Value)
		infiniteAttackSpeed = Value
		if infiniteAttackSpeed then
			setAttackSpeedValue(math.huge)
		else
			setAttackSpeedValue(attackSpeedValue)
		end
	end,
})
WeaponTab:CreateButton({
	Name = 'Apply Attack Speed',
	Callback = function()
		if infiniteAttackSpeed then
			setAttackSpeedValue(math.huge)
		else
			setAttackSpeedValue(attackSpeedValue)
		end
	end,
})
WeaponTab:CreateSection('Utilities')
WeaponTab:CreateButton({
    Name = "Load Unit Tracker",
    Callback = function()
        pcall(function()
			local Players=game:GetService("Players");local UIS=game:GetService("UserInputService");local player=Players.LocalPlayer;local old=player:WaitForChild("PlayerGui"):FindFirstChild("UnitTracker");if old then old:Destroy()end;local screenGui=Instance.new("ScreenGui");screenGui.Name="UnitTracker";screenGui.ResetOnSpawn=false;screenGui.Parent=player:WaitForChild("PlayerGui");local frame=Instance.new("Frame");frame.Name="MainFrame";frame.Size=UDim2.new(0,300,0,300);frame.Position=UDim2.new(0.5,-150,0.5,-150);frame.BackgroundColor3=Color3.fromRGB(25,25,25);frame.BorderSizePixel=0;frame.Parent=screenGui;local dragging=false;local dragStart,startPos;local function updateDrag(input)local delta=input.Position-dragStart;frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)end;frame.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;dragStart=input.Position;startPos=frame.Position;input.Changed:Connect(function()if input.UserInputState==Enum.UserInputState.End then dragging=false end end)end end);UIS.InputChanged:Connect(function(input)if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then updateDrag(input)end end);local title=Instance.new("TextLabel");title.Size=UDim2.new(1,0,0,30);title.BackgroundColor3=Color3.fromRGB(35,35,35);title.Text="Unit Tracker";title.TextColor3=Color3.fromRGB(255,255,255);title.TextSize=16;title.Font=Enum.Font.SourceSansBold;title.Parent=frame;local scroll=Instance.new("ScrollingFrame");scroll.Size=UDim2.new(1,0,1,-30);scroll.Position=UDim2.new(0,0,0,30);scroll.BackgroundTransparency=1;scroll.CanvasSize=UDim2.new(0,0,0,0);scroll.ScrollBarThickness=6;scroll.Parent=frame;local listLayout=Instance.new("UIListLayout");listLayout.Parent=scroll;listLayout.Padding=UDim.new(0,4);local function updateList()for _,obj in ipairs(scroll:GetChildren())do if obj:IsA("TextButton")then obj:Destroy()end end;local unitsFolder=workspace:FindFirstChild("Units");if not unitsFolder then return end;for _,unit in ipairs(unitsFolder:GetChildren())do if unit:IsA("Model")and unit.Name~="Clerk"then local btn=Instance.new("TextButton");btn.Size=UDim2.new(1,-10,0,25);btn.BackgroundColor3=Color3.fromRGB(50,50,50);btn.Text=unit.Name;btn.TextColor3=Color3.fromRGB(255,255,255);btn.TextSize=14;btn.Font=Enum.Font.SourceSans;btn.Parent=scroll;btn.MouseButton1Click:Connect(function()local char=player.Character;local hrp=char and char:FindFirstChild("HumanoidRootPart");if hrp and unit and unit.PrimaryPart then local pivot=unit:GetPivot().Position;local rayOrigin=pivot;local rayDirection=Vector3.new(0,-50,0);local rayParams=RaycastParams.new();rayParams.FilterDescendantsInstances={unit};rayParams.FilterType=Enum.RaycastFilterType.Exclude;local result=workspace:Raycast(rayOrigin,rayDirection,rayParams);local targetPos=result and result.Position or pivot;hrp.CFrame=CFrame.new(targetPos+Vector3.new(0,3,0))end end)end end;scroll.CanvasSize=UDim2.new(0,0,0,listLayout.AbsoluteContentSize.Y+10)end;task.spawn(function()while task.wait(3)do updateList()end end);updateList();local resizeHandle=Instance.new("Frame");resizeHandle.Size=UDim2.new(0,16,0,16);resizeHandle.AnchorPoint=Vector2.new(1,1);resizeHandle.Position=UDim2.new(1,0,1,0);resizeHandle.BackgroundColor3=Color3.fromRGB(70,70,70);resizeHandle.BorderSizePixel=0;resizeHandle.Active=true;resizeHandle.Parent=frame;local resizing=false;resizeHandle.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then resizing=true end end);resizeHandle.InputEnded:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then resizing=false end end);UIS.InputChanged:Connect(function(input)if resizing and input.UserInputType==Enum.UserInputType.MouseMovement then local newSizeX=math.clamp(input.Position.X-frame.AbsolutePosition.X,200,800);local newSizeY=math.clamp(input.Position.Y-frame.AbsolutePosition.Y,150,600);frame.Size=UDim2.new(0,newSizeX,0,newSizeY)end end)
        end)
    end,
})
local function applyDamageToTool(tool)
	if tool:IsA('Tool') then
		local settings = tool:FindFirstChild('SettingValues')
		if settings then
			local maxVal = settings:FindFirstChild('MaxDamageValue')
			local minVal = settings:FindFirstChild('MinDamageValue')
			if maxVal then pcall(function() maxVal.Value = dmgMax end) end
			if minVal then pcall(function() minVal.Value = dmgMin end) end
		end
	end
end
local function applyAllDamageToWeapons()
	local bp = LocalPlayer:FindFirstChild('Backpack')
	if bp then
		for _, tool in ipairs(bp:GetChildren()) do applyDamageToTool(tool) end
	end
	local char = LocalPlayer.Character
	if char then
		for _, tool in ipairs(char:GetChildren()) do applyDamageToTool(tool) end
	end
end
LocalPlayer.Backpack.ChildAdded:Connect(function(child)
    if child:IsA("Tool") then
        applyHitboxToWeapon(child)
		applyDamageToTool(child)
    end
end)
LocalPlayer.CharacterAdded:Connect(function(character)
	task.wait(1)
	if infiniteAttackSpeed then
		setAttackSpeedValue(math.huge)
	else
		setAttackSpeedValue(attackSpeedValue)
	end
	applyAllDamageToWeapons()
    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            applyHitboxToWeapon(child)
			applyDamageToTool(child)
        end
    end)
end)
task.spawn(function()
	while task.wait(1) do
		applyAllDamageToWeapons()
	end
end)local Players = game:GetService('Players')
if #Players:GetPlayers() > 1 then
    Players.LocalPlayer:Kick("stop using this in public.")
    return
end
Players.PlayerAdded:Connect(function()
    if #Players:GetPlayers() > 1 then
        Players.LocalPlayer:Kick("am not letting you ruin other ppl fun anymore.")
    end
end)

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({Name = 'ayin work ui', LoadingTitle = 'loading'})
local Players = game:GetService('Players')
local RepStorage = game:GetService('ReplicatedStorage')
local LocalPlayer = Players.LocalPlayer
local function listChildren(folder)
	local t = {}
	if folder then
		for _, v in ipairs(folder:GetChildren()) do
			table.insert(t, v.Name)
		end
	end
	table.sort(t)
	return t
end
local function getFolder(root, ...)
	local cur = root
	for i = 1, select('#', ...) do
		local n = select(i, ...)
		if not cur then return nil end
		cur = cur:FindFirstChild(n)
	end
	return cur
end
local function normalizeSelected(v)
	if type(v) == 'string' then return v end
	if typeof(v) == 'Instance' then return v.Name end
	if type(v) == 'table' then
		if v[1] then return v[1] end
		if v.Name then return v.Name end
	end
	return tostring(v)
end
local function titleCase(s)
	if not s or #s == 0 then return '' end
	return string.upper(string.sub(s, 1, 1)) .. string.lower(string.sub(s, 2))
end
local function getAbnoNames()
	return listChildren(getFolder(workspace, 'Abnormalities'))
end
local function getTalentNames()
	return listChildren(getFolder(RepStorage, 'Assets', 'Talents'))
end
local abnoList = getAbnoNames()
local talentList = getTalentNames()
local selectedWork = 'Instinct'
local selectedTalentRaw = talentList[1] or ''
local selectedAbnos = {}
local Tab = Window:CreateTab('abno working')
Tab:CreateSection('Controls')
Tab:CreateSection('Select Abnormalities')
for _, abno in ipairs(abnoList) do
	Tab:CreateToggle({
		Name = abno,
		CurrentValue = false,
		Callback = function(Value)
			if Value then
				if not table.find(selectedAbnos, abno) then
					table.insert(selectedAbnos, abno)
				end
			else
				for i, v in ipairs(selectedAbnos) do
					if v == abno then
						table.remove(selectedAbnos, i)
						break
					end
				end
			end
		end,
	})
end
Tab:CreateButton({
	Name = 'Clear Selection',
	Callback = function()
		selectedAbnos = {}
	end,
})
Tab:CreateDropdown({
	Name = 'Work Type',
	Options = { 'Instinct', 'Insight', 'Attachment', 'Repression' },
	CurrentOption = selectedWork,
	Callback = function(opt)
		selectedWork = opt
	end,
})
Tab:CreateButton({
	Name = 'Work',
	Callback = function()
		pcall(function()
			if #selectedAbnos == 0 then return end
			local abnoRoot = getFolder(workspace, 'Abnormalities')
			if not abnoRoot then return end
			local remote = getFolder(RepStorage, 'Assets', 'RemoteEvents', 'WorkEvent')
			if not remote then return end
			local flavor = titleCase(normalizeSelected(selectedWork))
			for _, abnoName in ipairs(selectedAbnos) do
				local sel = normalizeSelected(abnoName)
				local abno = abnoRoot:FindFirstChild(sel)
				if abno then
					local wt = abno:FindFirstChild('WorkTablet')
					if wt then remote:FireServer(wt, flavor) end
				end
			end
		end)
	end,
})
local CardTab = Window:CreateTab('card selector')
CardTab:CreateSection('Talent')
CardTab:CreateDropdown({
	Name = 'Talent',
	Options = talentList,
	CurrentOption = selectedTalentRaw,
	Callback = function(opt)
		selectedTalentRaw = opt
	end,
})
CardTab:CreateButton({
	Name = 'Select card',
	Callback = function()
		pcall(function()
			local sel = normalizeSelected(selectedTalentRaw)
			if sel == '' then return end
			local remote = getFolder(RepStorage, 'Assets', 'RemoteEvents', 'SelectCardEvent')
			if not remote then return end
			remote:FireServer(sel)
		end)
	end,
})
local WeaponTab = Window:CreateTab('weapon mod')
WeaponTab:CreateSection('Hitbox Settings')
local hitboxSize = 10
WeaponTab:CreateInput({
	Name = 'Hitbox Size',
	PlaceholderText = '10',
	Callback = function(text)
		local v = tonumber(text)
		if v and v > 0 then hitboxSize = v end
	end,
})
local function applyHitboxToWeapon(tool)
    if tool and tool:IsA("Tool") then
        local anims = tool:FindFirstChild("Animations")
        if anims then
            local attackAnims = anims:FindFirstChild("AttackAnimations")
            if attackAnims then
                for _, animFolder in ipairs(attackAnims:GetChildren()) do
                    local hitboxValue = animFolder:FindFirstChild("HitboxSize")
                    if hitboxValue and hitboxValue:IsA("Vector3Value") then
                        hitboxValue.Value = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                    end
                end
            end
        end
    end
end
local function applyHitboxToAllWeapons()
	local character = LocalPlayer.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then applyHitboxToWeapon(child) end
		end
	end
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") then applyHitboxToWeapon(child) end
		end
	end
end
WeaponTab:CreateButton({
	Name = 'Apply Hitbox Size',
	Callback = function()
		applyHitboxToAllWeapons()
	end,
})
WeaponTab:CreateSection('Damage Settings')
local dmgMax = 1500
local dmgMin = 1500
WeaponTab:CreateInput({
	Name = 'Max Damage',
	PlaceholderText = '50',
	Callback = function(text)
		local v = tonumber(text)
		if v then dmgMax = v end
	end,
})
WeaponTab:CreateInput({
	Name = 'Min Damage',
	PlaceholderText = '50',
	Callback = function(text)
		local v = tonumber(text)
		if v then dmgMin = v end
	end,
})
WeaponTab:CreateSection('Attack Speed')
local attackSpeedValue = 5
local infiniteAttackSpeed = false
WeaponTab:CreateInput({
	Name = 'Attack Speed',
	PlaceholderText = '5',
	Callback = function(text)
		local v = tonumber(text)
		if v then attackSpeedValue = v end
	end,
})
local function setAttackSpeedValue(val)
	pcall(function()
		local units = workspace:WaitForChild('Units', 2)
		local playerUnit = units and units:FindFirstChild(LocalPlayer.Name)
		local charStats = playerUnit and playerUnit:FindFirstChild('CharStats')
		local attackSpeed = charStats and charStats:FindFirstChild('AttackSpeed')
		if attackSpeed then attackSpeed.Value = val end
	end)
end
WeaponTab:CreateToggle({
	Name = 'Infinite Attack Speed',
	CurrentValue = false,
	Callback = function(Value)
		infiniteAttackSpeed = Value
		if infiniteAttackSpeed then
			setAttackSpeedValue(math.huge)
		else
			setAttackSpeedValue(attackSpeedValue)
		end
	end,
})
WeaponTab:CreateButton({
	Name = 'Apply Attack Speed',
	Callback = function()
		if infiniteAttackSpeed then
			setAttackSpeedValue(math.huge)
		else
			setAttackSpeedValue(attackSpeedValue)
		end
	end,
})
WeaponTab:CreateSection('Utilities')
WeaponTab:CreateButton({
    Name = "Load Unit Tracker",
    Callback = function()
        pcall(function()
			local Players=game:GetService("Players");local UIS=game:GetService("UserInputService");local player=Players.LocalPlayer;local old=player:WaitForChild("PlayerGui"):FindFirstChild("UnitTracker");if old then old:Destroy()end;local screenGui=Instance.new("ScreenGui");screenGui.Name="UnitTracker";screenGui.ResetOnSpawn=false;screenGui.Parent=player:WaitForChild("PlayerGui");local frame=Instance.new("Frame");frame.Name="MainFrame";frame.Size=UDim2.new(0,300,0,300);frame.Position=UDim2.new(0.5,-150,0.5,-150);frame.BackgroundColor3=Color3.fromRGB(25,25,25);frame.BorderSizePixel=0;frame.Parent=screenGui;local dragging=false;local dragStart,startPos;local function updateDrag(input)local delta=input.Position-dragStart;frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)end;frame.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;dragStart=input.Position;startPos=frame.Position;input.Changed:Connect(function()if input.UserInputState==Enum.UserInputState.End then dragging=false end end)end end);UIS.InputChanged:Connect(function(input)if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then updateDrag(input)end end);local title=Instance.new("TextLabel");title.Size=UDim2.new(1,0,0,30);title.BackgroundColor3=Color3.fromRGB(35,35,35);title.Text="Unit Tracker";title.TextColor3=Color3.fromRGB(255,255,255);title.TextSize=16;title.Font=Enum.Font.SourceSansBold;title.Parent=frame;local scroll=Instance.new("ScrollingFrame");scroll.Size=UDim2.new(1,0,1,-30);scroll.Position=UDim2.new(0,0,0,30);scroll.BackgroundTransparency=1;scroll.CanvasSize=UDim2.new(0,0,0,0);scroll.ScrollBarThickness=6;scroll.Parent=frame;local listLayout=Instance.new("UIListLayout");listLayout.Parent=scroll;listLayout.Padding=UDim.new(0,4);local function updateList()for _,obj in ipairs(scroll:GetChildren())do if obj:IsA("TextButton")then obj:Destroy()end end;local unitsFolder=workspace:FindFirstChild("Units");if not unitsFolder then return end;for _,unit in ipairs(unitsFolder:GetChildren())do if unit:IsA("Model")and unit.Name~="Clerk"then local btn=Instance.new("TextButton");btn.Size=UDim2.new(1,-10,0,25);btn.BackgroundColor3=Color3.fromRGB(50,50,50);btn.Text=unit.Name;btn.TextColor3=Color3.fromRGB(255,255,255);btn.TextSize=14;btn.Font=Enum.Font.SourceSans;btn.Parent=scroll;btn.MouseButton1Click:Connect(function()local char=player.Character;local hrp=char and char:FindFirstChild("HumanoidRootPart");if hrp and unit and unit.PrimaryPart then local pivot=unit:GetPivot().Position;local rayOrigin=pivot;local rayDirection=Vector3.new(0,-50,0);local rayParams=RaycastParams.new();rayParams.FilterDescendantsInstances={unit};rayParams.FilterType=Enum.RaycastFilterType.Exclude;local result=workspace:Raycast(rayOrigin,rayDirection,rayParams);local targetPos=result and result.Position or pivot;hrp.CFrame=CFrame.new(targetPos+Vector3.new(0,3,0))end end)end end;scroll.CanvasSize=UDim2.new(0,0,0,listLayout.AbsoluteContentSize.Y+10)end;task.spawn(function()while task.wait(3)do updateList()end end);updateList();local resizeHandle=Instance.new("Frame");resizeHandle.Size=UDim2.new(0,16,0,16);resizeHandle.AnchorPoint=Vector2.new(1,1);resizeHandle.Position=UDim2.new(1,0,1,0);resizeHandle.BackgroundColor3=Color3.fromRGB(70,70,70);resizeHandle.BorderSizePixel=0;resizeHandle.Active=true;resizeHandle.Parent=frame;local resizing=false;resizeHandle.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then resizing=true end end);resizeHandle.InputEnded:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then resizing=false end end);UIS.InputChanged:Connect(function(input)if resizing and input.UserInputType==Enum.UserInputType.MouseMovement then local newSizeX=math.clamp(input.Position.X-frame.AbsolutePosition.X,200,800);local newSizeY=math.clamp(input.Position.Y-frame.AbsolutePosition.Y,150,600);frame.Size=UDim2.new(0,newSizeX,0,newSizeY)end end)
        end)
    end,
})
local function applyDamageToTool(tool)
	if tool:IsA('Tool') then
		local settings = tool:FindFirstChild('SettingValues')
		if settings then
			local maxVal = settings:FindFirstChild('MaxDamageValue')
			local minVal = settings:FindFirstChild('MinDamageValue')
			if maxVal then pcall(function() maxVal.Value = dmgMax end) end
			if minVal then pcall(function() minVal.Value = dmgMin end) end
		end
	end
end
local function applyAllDamageToWeapons()
	local bp = LocalPlayer:FindFirstChild('Backpack')
	if bp then
		for _, tool in ipairs(bp:GetChildren()) do applyDamageToTool(tool) end
	end
	local char = LocalPlayer.Character
	if char then
		for _, tool in ipairs(char:GetChildren()) do applyDamageToTool(tool) end
	end
end
LocalPlayer.Backpack.ChildAdded:Connect(function(child)
    if child:IsA("Tool") then
        applyHitboxToWeapon(child)
		applyDamageToTool(child)
    end
end)
LocalPlayer.CharacterAdded:Connect(function(character)
	task.wait(1)
	if infiniteAttackSpeed then
		setAttackSpeedValue(math.huge)
	else
		setAttackSpeedValue(attackSpeedValue)
	end
	applyAllDamageToWeapons()
    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            applyHitboxToWeapon(child)
			applyDamageToTool(child)
        end
    end)
end)
task.spawn(function()
	while task.wait(1) do
		applyAllDamageToWeapons()
	end
end)
