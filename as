-- CONFIG
local owner = getgenv().Owner or "unknown"
getgenv().Owner = owner

local offset = Vector3.new(-5, 0, 5)
local following = false
local followConnection

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local TargPlr = nil
local TargTp = false
local lastShot = 0

-- UTILS
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getRootPart(Character)
    return Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart")
end

-- AUTO ARMOR
local AutoArmor = { Enabled = true }
local lastBuy = 0
local cooldown = 5

local function getArmorValue()
    local character = getCharacter()
    local bodyEffects = character:FindFirstChild("BodyEffects")
    local armor = bodyEffects and bodyEffects:FindFirstChild("Armor")
    return armor and armor.Value or 0
end

local function getBestArmorShop()
    local ignored = Workspace:FindFirstChild("Ignored")
    local shop = ignored and ignored:FindFirstChild("Shop")
    local bestArmor = nil
    local bestValue = -1

    if shop then
        for _, item in ipairs(shop:GetChildren()) do
            if item:IsA("Model") and item.Name:lower():find("armor") and item:FindFirstChild("Head") and item:FindFirstChildWhichIsA("ClickDetector") then
                local price = tonumber(item.Name:match("%$(%d+)")) or 0
                if price > bestValue then
                    bestArmor = item
                    bestValue = price
                end
            end
        end
    end

    return bestArmor
end

local function tryBuyArmor(model)
    local head = model:FindFirstChild("Head")
    local clickDetector = model:FindFirstChildWhichIsA("ClickDetector")
    local rootPart = getRootPart(getCharacter())
    if not (head and clickDetector and rootPart) then return end

    local originalCFrame = rootPart.CFrame
    rootPart.CFrame = head.CFrame + Vector3.new(0, 3, 0)
    task.wait(0.3)
    fireclickdetector(clickDetector)
    task.wait(0.3)
    rootPart.CFrame = originalCFrame
    print("✓ Armor equipped!")
    lastBuy = tick()
end

RunService.Heartbeat:Connect(function()
    if not AutoArmor.Enabled then return end
    if tick() - lastBuy < cooldown then return end
    if getArmorValue() > 100 then return end

    local armorModel = getBestArmorShop()
    if armorModel then
        tryBuyArmor(armorModel)
    end
end)

-- VANISH
local vanishConnection

local function vanishDesync()
    local hrp = getRootPart(getCharacter())
    local originalCFrame = hrp.CFrame
    vanishConnection = RunService.Heartbeat:Connect(function()
        if hrp and hrp.Parent then
            hrp.CFrame = CFrame.new(Vector3.new(math.random(-500, 500), 1e12 + math.random(0, 10000), math.random(-500, 500)))
            task.wait(0.03)
            hrp.CFrame = originalCFrame.Position + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
            task.wait(0.03)
        end
    end)
end

-- FLING
local flingActive = false
local flingConnection

local function flingLoop(targetPlayer)
    local lp = Players.LocalPlayer
    local movel = 0.1
    if flingConnection then flingConnection:Disconnect() end
    flingConnection = RunService.Heartbeat:Connect(function()
        if not flingActive then return end
        local myChar = lp.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local targetLeg = targetPlayer.Character and (
            targetPlayer.Character:FindFirstChild("Left Leg") or
            targetPlayer.Character:FindFirstChild("LeftLowerLeg") or
            targetPlayer.Character:FindFirstChild("Right Leg") or
            targetPlayer.Character:FindFirstChild("RightLowerLeg")
        )
        if myHRP and targetLeg then
            local vel = myHRP.Velocity
            myHRP.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
            RunService.RenderStepped:Wait()
            myHRP.Velocity = vel
            RunService.Stepped:Wait()
            myHRP.Velocity = vel + Vector3.new(0, movel, 0)
            movel = -movel
            myHRP.CFrame = targetLeg.CFrame + Vector3.new(0, 1, 0)
        end
    end)
end

-- SHOOTING
local function getAmmo()
    local gun = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("[Revolver]")
    local ammo = gun and gun:FindFirstChild("Ammo")
    return ammo and ammo.Value or 0
end

local function reloadTool()
    local remote = ReplicatedStorage:WaitForChild("MainRemotes"):WaitForChild("MainRemoteEvent")
    local revolver = LocalPlayer.Character:FindFirstChild("[Revolver]") or LocalPlayer.Backpack:FindFirstChild("[Revolver]")
    if revolver then
        if revolver.Parent == LocalPlayer.Backpack then
            LocalPlayer.Character.Humanoid:EquipTool(revolver)
            task.wait(0.2)
        end
        remote:FireServer("Reload", revolver)
    end
end

local function autoFireAt(target)
    if tick() - lastShot < 0.1 then return end
    lastShot = tick()
    if getAmmo() <= 0 then
        reloadTool()
        return
    end
    local gun = LocalPlayer.Character:FindFirstChild("[Revolver]")
    if not gun then return end
    local handle = gun:FindFirstChild("Handle")
    local targetPart = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not (handle and targetPart) then return end
    local origin = handle.Position
    local hitPos = targetPart.Position + Vector3.new(0, 1, 0)
    local normal = Vector3.new(0, 1, 0)
    local remote = ReplicatedStorage:WaitForChild("MainRemotes"):WaitForChild("MainRemoteEvent")
    remote:FireServer("ShootGun", handle, origin, hitPos, targetPart, normal)
end

RunService.Heartbeat:Connect(function()
    if not TargTp or not TargPlr then return end
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot = TargPlr.Character and TargPlr.Character:FindFirstChild("HumanoidRootPart")
    if not (root and targetRoot) then return end
    local time = tick() * 300000000
    local offset = Vector3.new(
        math.cos(time) * 15,
        math.sin(time) * 10,
        math.sin(time) * 15
    )
    root.CFrame = targetRoot.CFrame * CFrame.new(offset)
    Workspace.CurrentCamera.CFrame = CFrame.new(Workspace.CurrentCamera.CFrame.Position, targetRoot.Position)
    autoFireAt(TargPlr)
end)

-- STOP ALL
local function stopAll()
    following = false
    if followConnection then followConnection:Disconnect() end
    if vanishConnection then vanishConnection:Disconnect() end
    flingActive = false
    if flingConnection then flingConnection:Disconnect() end
    TargTp = false
    TargPlr = nil
end

-- COMMAND LISTENER (new chat system)
TextChatService.OnIncomingMessage = function(message)
    if not message.TextSource then return end
    local plr = Players:GetPlayerByUserId(message.TextSource.UserId)
    if not plr then return end

    local msg = trim(message.Text):lower()
    local playerName = plr.Name

    -- debug print
    print("[CHAT CMD]", playerName, "said:", msg)

    if msg == ";summon" and playerName == getgenv().Owner then
        local hrp = getRootPart(getCharacter())
        local ownerHRP = plr.Character and getRootPart(plr.Character)
        if hrp and ownerHRP then
            hrp.CFrame = ownerHRP.CFrame * CFrame.new(offset)
            print("✨ Summoned near owner.")
        end

    elseif msg == ";vanish" and playerName == getgenv().Owner then
        vanishDesync()
        print("👻 Vanish activated.")

    elseif msg == ";rejoin" and playerName == getgenv().Owner then
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
        print("🔄 Rejoining...")

    elseif msg == ";alt stop" and playerName == getgenv().Owner then
        stopAll()
        print("⛔ Stopped everything.")

    elseif msg:sub(1, 4) == "atc " and playerName == getgenv().Owner then
        local targetName = trim(msg:sub(5))
        for _, plr2 in pairs(Players:GetPlayers()) do
            if plr2.Name:lower():find(targetName:lower()) then
                TargPlr = plr2
                TargTp = true
                print("🔫 Attacking " .. plr2.Name)
                return
            end
        end
        print("❌ Player not found: " .. targetName)

    elseif msg:sub(1, 6) == "fling " and playerName == getgenv().Owner then
        local targetName = trim(msg:sub(7))
        for _, plr2 in pairs(Players:GetPlayers()) do
            if plr2.Name:lower():find(targetName:lower()) then
                flingActive = true
                flingLoop(plr2)
                print("🌀 Flinging " .. plr2.Name)
                return
            end
        end
        print("❌ Player not found: " .. targetName)
    end
end

print("✅ Stand script loaded. Use ;summon / ;vanish / ;rejoin / ;alt stop / atc <name> / fling <name> in chat.")
