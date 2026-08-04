run(function()
    local Killaura
    local Continue
    local Targets
    local Mode
    local Sort
    local SwingRange
    local AttackRange
    local AirChance
    local SwingTime
    local Hitreg
    local Dynamic
    local Sync = {}
    local Attackable
    local AngleSlider
    local MaxTargets
    local Mouse
    local Swing
    local GUI
    local BoxRender
    local BoxSwingColor
    local BoxAttackColor
    local ParticleTexture
    local ParticleColor1
    local ParticleColor2
    local ParticleSize
    local Face
    local Animation
    local AnimationMode
    local AnimationSpeed
    local AnimationTween
    local Limit
    local LegitAura
    local Particles, Boxes, Rings = {}, {}, {}
    local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
    local AttackRemote = {FireServer = function(self, ...) end}
    local SwingMissRemote = {FireServer = function(self, ...) end}
    local projectileRemote = {InvokeServer = function(self, ...) end}
    task.spawn(function()
        AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
    end)
    task.spawn(function()
        SwingMissRemote = bedwars.Client:Get('SwordSwingMiss').instance
    end)
    task.spawn(function()
    	projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    end)

    local FastHits
    local Legit
    local FireRate
    local Whitelist
    local FireRates = {}

    local function getAmmo(check)
    	for _, item in store.inventory.inventory.items do
    		if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
    			return item.itemType
    		end
    	end
    	return nil
    end
    local function getProjectiles()
    	local items = {}
    	for _, item in store.inventory.inventory.items do
    		local proj = bedwars.ItemMeta[item.itemType].projectileSource
    		local ammo = proj and getAmmo(proj)
    		if ammo and not proj.maxStrengthChargeSec and (table.find(Whitelist.ListEnabled, ammo) or table.find(Whitelist.ListEnabled, item.itemType)) then
    			table.insert(items, {
    				item,
    				ammo,
    				proj.projectileType(ammo),
    				proj,
    			})
    		end
    	end
    	return items
    end
    local function getAttackData()
        if Mouse.Enabled then
            if not inputService:IsMouseButtonPressed(0) then return false end
        end
    
        if Attackable.Enabled then
            if not entitylib.isAlive then return false end
            if (lplr.Character:GetAttribute('StunnedUntilTime') or 0) > workspace:GetServerTimeNow() then return false end
            if lplr.Character:FindFirstChild('elk') then return false end
            if bedwars.StatusEffectUtil:isActive(lplr.Character, 'frozen') then return false end
        end
    
        if GUI.Enabled then
            if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
        end
    
        local sword = Limit.Enabled and store.hand or store.tools.sword
        if not sword or not sword.tool then return false end
    
        local meta = bedwars.ItemMeta[sword.tool.Name]
        if Limit.Enabled then
            if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
        end
    
        if LegitAura.Enabled then
            if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
        end
    
        return sword, meta
    end
    
    local part = Instance.new('Part')
    part.Anchored = true
    part.CanCollide = false
    part.Size = Vector3.one
    part.Parent = workspace
    vape:Clean(part)
    
    Killaura = vape.Categories.Blatant:CreateModule({
        Name = 'Killaura',
        Function = function(callback)
            if callback then
                if Animation.Enabled then
                    local fake = {
                        Controllers = {
                            ViewmodelController = {
                                isVisible = function()
                                    return not Attacking
                                end,
                                playAnimation = function(...)
                                    if not Attacking then
                                        bedwars.ViewmodelController:playAnimation(select(2, ...))
                                    end
                                end
                            }
                        }
                    }
                    debug.setupvalue(bedwars.SwordController.playSwordEffect, 7, fake)
                    debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, fake)
    
                    task.spawn(function()
                        local started = false
                        repeat
                            if Attacking then
                                if not armC0 then
                                    armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
                                end
                                local first = not started
                                started = true
    
                                if AnimationMode.Value == 'Random' then
                                    anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
                                end
    
                                for _, v in anims[AnimationMode.Value] do
                                    AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
                                        C0 = armC0 * v.CFrame
                                    })
                                    AnimTween:Play()
                                    AnimTween.Completed:Wait()
                                    first = false
                                    if (not Killaura.Enabled) or (not Attacking) then break end
                                end
                            elseif started then
                                started = false
                                AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
                                    C0 = armC0
                                })
                                AnimTween:Play()
                            end
    
                            if not started then
                                task.wait()
                            end
                        until (not Killaura.Enabled) or (not Animation.Enabled)
                    end)
                end
    
                local swingCooldown, switchCooldown, lastSwing, targetIndex = tick(), tick(), 0, 0
                local lastShot, projectileIndex = tick(), 0
                local lastHit = 0
                local lastRealSend = 0
                repeat
                    local attacked, sword, meta = {}, getAttackData()
                    Attacking = false
                    store.KillauraTarget = nil
                    if sword then
                        local plrs = entitylib.AllPosition({
                            Range = SwingRange.Value,
                            Wallcheck = Targets.Walls.Enabled or nil,
                            Part = 'RootPart',
                            Players = Targets.Players.Enabled,
                            NPCs = Targets.NPCs.Enabled,
                            Limit = Mode.Value == 'Single' and 1 or MaxTargets.Value,
                            Sort = sortmethods[Sort.Value]
                        })
    
                        if #plrs > 0 then
                            switchItem(sword.tool, 0)
                            local selfpos = entitylib.character.RootPart.Position
                            local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
                            if tick() > switchCooldown and Mode.Value == 'Switch' then
    						switchCooldown = tick() + 0.7
    						targetIndex = targetIndex + 1
    					end
                            if not plrs[targetIndex] then
                                targetIndex = 1
                            end
                            for i, v in plrs do
                                if Mode.Value == 'Switch' and i ~= targetIndex then
    						continue
    					end
                                local delta = (v.RootPart.Position - selfpos)
                                local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
                                if angle > (math.rad(AngleSlider.Value) / 2) then continue end
    
                                table.insert(attacked, {
                                    Entity = v,
                                    Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
                                })
                                targetinfo.Targets[v] = tick() + 1
    
                                if not Attacking then
                                    Attacking = true
                                    store.KillauraTarget = v
                                    if not Swing.Enabled and AnimDelay < tick() and not LegitAura.Enabled then
                                        AnimDelay = tick() + math.max(SwingTime.Value, 0.11)
                                        lastSwing = tick()
                                        bedwars.SwordController:playSwordEffect(meta, false)
                                        if meta.displayName:find(' Scythe') then
                                            bedwars.ScytheController:playLocalAnimation()
                                        end
    
                                        if vape.ThreadFix then
                                            setthreadidentity(8)
                                        end
                                    end
                                end
    
                                local minHitInterval = (meta.sword.attackSpeed or 0.33) - 0.009
                                print(string.format("[KA Debug] sword: %s | attackSpeed: %s | minHitInterval: %.4f", tostring(sword.itemType), tostring(meta.sword.attackSpeed), minHitInterval))
                                local current = tick()
                                if delta.Magnitude > AttackRange.Value then
                                    if (current - lastHit) >= minHitInterval then
                                        lastHit = lastHit + minHitInterval
                                        if current - lastHit > minHitInterval then lastHit = current end
                                        pcall(SwingMissRemote.FireServer, SwingMissRemote, {chargeRatio = 0, weapon = sword.tool})
                                    end
                                    continue
                                end

                                local actualRoot = v.Character.PrimaryPart
                                if actualRoot and (not Sync.Enabled or (current - swingCooldown >= SwingTime.Value)) and (v.Humanoid.FloorMaterial ~= Enum.Material.Air or math.random(1, 100) < AirChance.Value) then
                                    if (current - lastHit) >= minHitInterval and (current - lastRealSend) >= minHitInterval then
                                        lastHit = lastHit + minHitInterval
                                        if current - lastHit > minHitInterval then lastHit = current end
                                        lastRealSend = current

                                        local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
                                        local pos = selfpos + dir * math.max(delta.Magnitude - 14.4, 0)
                                        bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
                                        store.attackReach = math.floor(delta.Magnitude * 100) / 100
                                        store.attackReachUpdate = tick() + 1
                                        swingCooldown = tick()

                                        AttackRemote:FireServer({
                                            weapon = sword.tool,
                                            chargedAttack = {chargeRatio = 0},
                                            entityInstance = v.Character,
                                            validate = {
                                                raycast = {
                                                    cameraPosition = {value = pos},
                                                    cursorDirection = {value = dir}
                                                },
                                                targetPosition = {value = actualRoot.Position},
                                                selfPosition = {value = pos}
                                            }
                                        })
    
                                        if FastHits.Enabled and tick() > lastShot and not entitylib.Wallcheck(entitylib.character.RootPart.Position, actualRoot.Position, {gameCamera, lplr.Character, v.Character}) then
                                            local projectiles = getProjectiles()
                                            if #projectiles > 0 then
                                                projectileIndex = projectileIndex + 1
                                                if not projectiles[projectileIndex] then
                                                    projectileIndex = 1
                                                end
                                                
                                                local item, ammo, projectile, itemMeta = unpack(projectiles[projectileIndex])
                                                if tick() > (FireRates[item.itemType] or 0) and not (store.hand.tool and store.hand.tool.Name == 'telepearl') then
                                                    local projmeta = bedwars.ProjectileMeta[projectile]
                                                    local projSpeed = projmeta.launchVelocity
                                                    local gravity = projmeta.gravitationalAcceleration or 196.2
                                                    local oldhotbar, oldtool = store.inventory.hotbarSlot, store.hand.tool
                                                    local hotbar = getHotbar(item.tool)

                                                    if hotbar then
                                                        switchItem(item.tool)
                                                        if Legit.Enabled then hotbarSwitch(hotbar) end
                                                    end

                                                    local calc = prediction.SolveTrajectory(selfpos, projSpeed, gravity, v.RootPart.Position, v.RootPart.Velocity, workspace.Gravity, v.HipHeight, v.Jumping and 42.6 or nil, nil, nil, lplr:GetNetworkPing())
                                                    if calc then
                                                        local sdir, id = CFrame.lookAt(selfpos, calc).LookVector, httpService:GenerateGUID(true)
                                                        local shootPosition = (CFrame.new(selfpos, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position

                                                        bedwars.ProjectileController:createLocalProjectile(itemMeta, ammo, projectile, shootPosition, id, sdir * projSpeed, {drawDurationSeconds = 1})
                                                        local _, res = pcall(function() return projectileRemote:InvokeServer(
                                                            item.tool,
                                                            ammo,
                                                            projectile,
                                                            shootPosition,
                                                            selfpos,
                                                            sdir * projSpeed,
                                                            id,
                                                            {
                                                                drawDurationSeconds = 1,
                                                                shotId = httpService:GenerateGUID(false)
                                                            },
                                                            workspace:GetServerTimeNow() - 0.045
                                                        ) end)
                                                        if res then
                                                            pcall(function()
                                                                res.Parent = replicatedStorage
                                                            end)
                                                            FireRates[item.itemType] = tick() + itemMeta.fireDelaySec
                                                            local shoot = itemMeta.launchSound
                                                            shoot = shoot and shoot[math.random(1, #shoot)] or nil
                                                            if shoot then
                                                                bedwars.SoundManager:playSound(shoot)
                                                            end
                                                        end
                                                        lastShot = tick() + (lplr:GetNetworkPing() + FireRate.Value)
                                                    end
                                                    if oldtool then switchItem(oldtool) end
                                                    task.spawn(function()
                                                        if Legit.Enabled then hotbarSwitch(oldhotbar) end
                                                    end)
                                                end
                                            end
                                        end

                                        if Mode.Value ~= 'Multi' then
                                            break
                                        end
                                    end
                                end
                            end
                        else
                            if (tick() - lastSwing) < Continue:GetRandomValue() and not Swing.Enabled and not LegitAura.Enabled and AnimDelay < tick() then
                                AnimDelay = tick() + math.max(SwingTime.Value, 0.11)
                                if vape.ThreadFix then
    						setthreadidentity(8)
    					end
                                
    					pcall(function()
    						bedwars.SwordController:playSwordEffect(meta, false)
                                    if meta.displayName:find(' Scythe') then
                                        bedwars.ScytheController:playLocalAnimation()
                                    end
    					end)
                            end
                        end
                    end
    
                    for i, v in Boxes do
                        v.Adornee = BoxRender.Value == 'Box' and attacked[i] and attacked[i].Entity.RootPart or nil
                        if v.Adornee then
                            v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
                            v.Transparency = 1 - attacked[i].Check.Opacity
                        end
                    end
    
                    for i, v in Rings do
                        local root = BoxRender.Value == 'Ring' and attacked[i] and attacked[i].Entity.RootPart or nil
                        v.Transparency = 1
                        v.Parent = root and workspace or replicatedStorage
                        v.Position = root and Vector3.new(root.Position.X, (root.Position.Y - 1) + (v.Size.Y / 2), root.Position.Z) or Vector3.zero
                        if root then
                            for i2 = 1, 4 do
                                v[tostring(i2)].Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
                                v[tostring(i2)].Transparency = 1 - attacked[i].Check.Opacity
                            end
                        end
                    end
    
                    for i, v in Particles do
                        v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
                        v.Parent = attacked[i] and gameCamera or nil
                    end
    
                    if Face.Enabled and attacked[1] then
                        local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
                        entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
                    end
    
                    task.wait()
                until not Killaura.Enabled
            else
                store.KillauraTarget = nil
                for _, v in Boxes do
                    v.Adornee = nil
                end
                for _, v in Rings do
                    v.Parent = nil
                end
                for _, v in Particles do
                    v.Parent = nil
                end
                debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 7, bedwars.Knit)
                debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, bedwars.Knit)
                Attacking = false
                if armC0 then
                    AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
                        C0 = armC0
                    })
                    AnimTween:Play()
                end
            end
        end,
        Tooltip = 'Attack players around you\nwithout aiming at them.',
        ExtraText = function()
            return Mode.Value
        end
    })
    Targets = Killaura:CreateTargets({
        Players = true,
        NPCs = true
    })
    Continue = Killaura:CreateTwoSlider({
    	Name = 'Continue Swinging',
    	Min = 0,
    	Max = 2,
    	Decimal = 100,
    	DefaultMin = 0,
    	DefaultMax = 0.1,
    	Suffix = 'seconds',
    	Tooltip = 'Continues to swing ur sword'
    })
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do
        if not table.find(methods, i) then
            table.insert(methods, i)
        end
    end
    SwingRange = Killaura:CreateSlider({
        Name = 'Swing range',
        Min = 1,
        Max = 40,
        Default = 22,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    AttackRange = Killaura:CreateSlider({
        Name = 'Attack range',
        Min = 1,
        Max = 22,
        Default = 22,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    AngleSlider = Killaura:CreateSlider({
        Name = 'Max angle',
        Min = 1,
        Max = 360,
        Default = 360
    })
    AirChance = Killaura:CreateSlider({
        Name = 'Air Hit Chance',
        Min = 0,
    	Max = 100,
    	Default = 100,
    	Suffix = '%'
    })
    SwingTime = Killaura:CreateSlider({
        Name = 'Swing time',
        Min = 0,
        Max = 2,
        Decimal = 100,
        Default = 0.11,
        Suffix = 'seconds'
    })
    Sync = Killaura:CreateToggle({
        Name = 'Sync with hitreg',
        Darker = true,
        Tooltip = 'Syncs the hitreg with swing time'
    })
    FastHits = Killaura:CreateToggle({
    	Name = 'Fast Hits',
    	Tooltip = 'Deals more damage quicker using projectiles',
    	Default = false,
    	Function = function(callback)
            pcall(function()
                Legit.Object.Visible = callback
                FireRate.Object.Visible = callback
                Whitelist.Object.Visible = callback
            end)
    	end
    })
    Whitelist = Killaura:CreateTextList({
        Name = 'Projectiles',
        Default = {'arrow', 'snowball'},
        Darker = true,
        Visible = false,
        Tooltip = 'Projectiles to use for fasthits'
    })
    Legit = Killaura:CreateToggle({
    	Name = 'Legit Switch',
    	Darker = true,
    	Visible = false
    })
    FireRate = Killaura:CreateSlider({
    	Name = 'Fire rate',
    	Suffix = 'seconds',
    	Min = 0,
    	Max = 2,
    	Decimal = 100,
    	Darker = true,
    	Visible = false,
    	Default = 0.05
    })
    MaxTargets = Killaura:CreateSlider({
        Name = 'Max targets',
        Min = 1,
        Max = 5,
        Default = 5
    })
    Mode = Killaura:CreateDropdown({
    	Name = 'Attack Mode',
    	List = {'Single', 'Multi', 'Switch'},
    	Tooltip = 'Single - Attacks one person at a time\nMulti - Attack multiple people at once\nSwitch - Switch between targets',
    	Default = 'Switch',
    	Function = function(val)
    		pcall(function()
    			MaxTargets.Object.Visible = val ~= 'Single'
    		end)
    	end,
    })
    Sort = Killaura:CreateDropdown({
        Name = 'Target Mode',
        List = methods
    })
    Dynamic = Killaura:CreateToggle({
        Name = 'Dynamic hits',
        Tooltip = 'Calculates ur hitreg depending on ur distance'
    })
    Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
    Swing = Killaura:CreateToggle({Name = 'No Swing'})
    GUI = Killaura:CreateToggle({Name = 'GUI check'})
    Killaura:CreateToggle({
        Name = 'Show target',
        Function = function(callback)
            BoxSwingColor.Object.Visible = callback
            BoxAttackColor.Object.Visible = callback
            BoxRender.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local box = Instance.new('BoxHandleAdornment')
                    box.Adornee = nil
                    box.AlwaysOnTop = true
                    box.Size = Vector3.new(3, 5, 3)
                    box.CFrame = CFrame.new(0, -0.5, 0)
                    box.ZIndex = 0
                    box.Parent = vape.gui
                    Boxes[i] = box
                    if vape.ThreadFix then
                        setthreadidentity(8)
                    end
                    local ring = Instance.new('MeshPart')
    				ring.Size = Vector3.new(2.5, 5, 2.5)
    				ring.CanCollide = false
    				ring.Massless = true
                    ring.MeshContent = Content.fromAssetId(12812752257)
                    ring.MeshId = 'rbxassetid://12812752257'
    				ring.Anchored = true
                    local grad = Instance.new('Decal')
                    grad.ColorMapContent = Content.fromAssetId(106171062072708)
                    grad.Face = Enum.NormalId.Front
                    grad.Name = '1'
                    for i, v in {'Back', 'Right', 'Left'} do
                        local new = grad:Clone()
                        new.Name = tostring(i + 1)
                        new.Face = Enum.NormalId[v]
                        new.Parent = ring
                    end
                    grad.Parent = ring
                    Rings[i] = ring
    				bedwars.QueryUtil:setQueryIgnored(ring, true)
                end
            else
                for _, v in Boxes do
                    v:Destroy()
                end
                table.clear(Boxes)
            end
        end
    })
    BoxSwingColor = Killaura:CreateColorSlider({
        Name = 'Target Color',
        Darker = true,
        DefaultHue = 0.6,
        DefaultOpacity = 0.5,
        Visible = false
    })
    BoxAttackColor = Killaura:CreateColorSlider({
        Name = 'Attack Color',
        Darker = true,
        DefaultOpacity = 0.5,
        Visible = false
    })
    BoxRender = Killaura:CreateDropdown({
        Name = 'Render type',
        List = {'Box', 'Ring'},
        Darker = true,
        Default = 'Ring',
        Visible = false
    })
    Killaura:CreateToggle({
        Name = 'Target particles',
        Function = function(callback)
            ParticleTexture.Object.Visible = callback
            ParticleColor1.Object.Visible = callback
            ParticleColor2.Object.Visible = callback
            ParticleSize.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local part = Instance.new('Part')
                    part.Size = Vector3.new(2, 4, 2)
                    part.Anchored = true
                    part.CanCollide = false
                    part.Transparency = 1
                    part.CanQuery = false
                    part.Parent = Killaura.Enabled and gameCamera or nil
                    local particles = Instance.new('ParticleEmitter')
                    particles.Brightness = 1.5
                    particles.Size = NumberSequence.new(ParticleSize.Value)
                    particles.Shape = Enum.ParticleEmitterShape.Sphere
                    particles.Texture = ParticleTexture.Value
                    particles.Transparency = NumberSequence.new(0)
                    particles.Lifetime = NumberRange.new(0.4)
                    particles.Speed = NumberRange.new(16)
                    particles.Rate = 128
                    particles.Drag = 16
                    particles.ShapePartial = 1
                    particles.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
                        ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
                    })
                    particles.Parent = part
                    Particles[i] = part
                end
            else
                for _, v in Particles do
                    v:Destroy()
                end
                table.clear(Particles)
            end
        end
    })
    ParticleTexture = Killaura:CreateTextBox({
        Name = 'Texture',
        Default = 'rbxassetid://14736249347',
        Function = function()
            for _, v in Particles do
                v.ParticleEmitter.Texture = ParticleTexture.Value
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleColor1 = Killaura:CreateColorSlider({
        Name = 'Color Begin',
        Function = function(hue, sat, val)
            for _, v in Particles do
                v.ParticleEmitter.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
                })
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleColor2 = Killaura:CreateColorSlider({
        Name = 'Color End',
        Function = function(hue, sat, val)
            for _, v in Particles do
                v.ParticleEmitter.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
                })
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleSize = Killaura:CreateSlider({
        Name = 'Size',
        Min = 0,
        Max = 1,
        Default = 0.2,
        Decimal = 100,
        Function = function(val)
            for _, v in Particles do
                v.ParticleEmitter.Size = NumberSequence.new(val)
            end
        end,
        Darker = true,
        Visible = false
    })
    Face = Killaura:CreateToggle({Name = 'Face target'})
    Animation = Killaura:CreateToggle({
        Name = 'Custom Animation',
        Function = function(callback)
            AnimationMode.Object.Visible = callback
            AnimationTween.Object.Visible = callback
            AnimationSpeed.Object.Visible = callback
            if Killaura.Enabled then
                Killaura:Toggle()
                Killaura:Toggle()
            end
        end
    })
    local animnames = {}
    for i in anims do
        table.insert(animnames, i)
    end
    AnimationMode = Killaura:CreateDropdown({
        Name = 'Animation Mode',
        List = animnames,
        Darker = true,
        Visible = false
    })
    AnimationSpeed = Killaura:CreateSlider({
        Name = 'Animation Speed',
        Min = 0,
        Max = 2,
        Default = 1,
        Decimal = 10,
        Darker = true,
        Visible = false
    })
    AnimationTween = Killaura:CreateToggle({
        Name = 'No Tween',
        Darker = true,
        Visible = false
    })
    Attackable = Killaura:CreateToggle({
        Name = 'Attackable check',
        Tooltip = 'Checks if your in a state where you can attack'
    })
    Limit = Killaura:CreateToggle({
        Name = 'Limit to items',
        Tooltip = 'Only attacks when the sword is held'
    })
    LegitAura = Killaura:CreateToggle({
        Name = 'Swing only',
        Tooltip = 'Only attacks while swinging manually'
    })
    Killaura:CreateToggle({ Name = 'Multi Swing', Default = false, Tooltip = 'Attack multiple targets per tick' })
    Killaura:CreateSlider({ Name = 'Swing Delay', Min = 0, Max = 200, Default = 0, Suffix = 'ms', Tooltip = 'Random extra delay between swings' })
    Killaura:CreateToggle({ Name = 'Break On Death', Default = true, Tooltip = 'Stop attacking when target dies and pick next' })
end)
