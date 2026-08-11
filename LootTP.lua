run(function()
	local LootTP
	local Height
	local VelocityMultiplier
	local Network

	local function safeCollection(tag, owner)
		if typeof(collection) ~= 'function' then return {} end
		local ok, res = pcall(function() return collection(tag, owner) end)
		if ok and res then return res end
		return {}
	end

	local function safeGetPickupRemote()
		if not remotes or not remotes.PickupItem then return nil end
		if not bedwars or not bedwars.Client then return nil end
		local ok, remote = pcall(function() return bedwars.Client:Get(remotes.PickupItem) end)
		if ok and remote and remote.CallServerAsync then
			return remote
		end
		return nil
	end

	local function safeNotify(title, text)
		pcall(function()
			if vape and vape.CreateNotification then
				vape:CreateNotification(title, text, 5)
			end
		end)
	end

	LootTP = vape and vape.Categories and vape.Categories.Utility and vape.Categories.Utility:CreateModule({
		Name = 'LootTP',
		Function = function(callback)
			if callback then
				-- quick sanity checks for required systems
				if not entitylib or not entitylib.character then
					safeNotify('LootTP', 'entitylib.character not present - LootTP disabled')
					return
				end

				repeat
					local items = safeCollection('ItemDrop', LootTP)

					if entitylib and entitylib.isAlive and entitylib.character and entitylib.character.RootPart then
						local localPosition = entitylib.character.RootPart.Position

						for _, v in items do
							if not v then continue end

							local clientDropTime = 0
							if v.GetAttribute then
								pcall(function() clientDropTime = v:GetAttribute('ClientDropTime') or 0 end)
							end
							if tick() - (clientDropTime or 0) < 2 then continue end

							local vPos = nil
							pcall(function() vPos = v.Position end)
							if not vPos then continue end

							-- Check if item is in the void (below a certain Y position)
							if vPos.Y < -100 then
								local canNetwork = Network and Network.Enabled
								local hasOwnerCheck = type(isnetworkowner) == 'function'
								local charHum = entitylib.character and entitylib.character.Humanoid

								if hasOwnerCheck and canNetwork and charHum and charHum.Health and charHum.Health > 0 then
									local skyHeight = (Height and Height.Value) or 200
									local velMul = (VelocityMultiplier and VelocityMultiplier.Value) or 1.5

									-- safe calc of target / direction
									local ok1, targetPosition, ok2, direction, ok3, distance = pcall(function()
										local tp = localPosition + Vector3.new(0, skyHeight, 0)
										local dir = (tp - vPos).Unit
										local dist = (tp - vPos).Magnitude
										return tp, dir, dist
									end)

									if ok1 and targetPosition and direction and distance then
										local velocity = direction * (distance * velMul)

										pcall(function()
										if v:FindFirstChild('BodyVelocity') then
											v.BodyVelocity.Velocity = velocity
										elseif v.IsA and v:IsA('BasePart') then
											v.AssemblyLinearVelocity = velocity
										end
									end)

									pcall(function()
										v.CFrame = CFrame.new(targetPosition)
									end)
								end
							end

							-- Bring it back to player once it's falling (safe distance checks)
							local okDist, distCheck = pcall(function()
								return (localPosition - vPos).Magnitude
							end)
							if okDist and distCheck and distCheck <= 50 and vPos.Y < localPosition.Y then
								local pickupRemote = safeGetPickupRemote()
								if pickupRemote then
									task.spawn(function()
										pcall(function()
											pickupRemote:CallServerAsync({ itemDrop = v }):andThen(function(suc)
												if suc and bedwars and bedwars.SoundList and bedwars.SoundManager then
													pcall(function()
														bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)
													end)
													local okMeta, sound = pcall(function()
														return bedwars.ItemMeta and bedwars.ItemMeta[v.Name] and bedwars.ItemMeta[v.Name].pickUpOverlaySound
													end)
													if okMeta and sound then
														pcall(function()
															bedwars.SoundManager:playSound(sound, {
															position = v.Position,
															volumeMultiplier = 0.9
														})
														end)
													end
											end)
										end)
									end)
								end
							end
						end
					else
						-- if no character exists, warn once and exit the loop
						safeNotify('LootTP', 'No local character available - skipping LootTP loop')
						break
					end

					task.wait(0.1)
				until not LootTP.Enabled
			end
		end,
		Tooltip = 'Teleports dropped items from the void back to you'
	}) or (function() safeNotify('LootTP', 'vape.Categories.Utility not available - module not created') end)()

	Height = LootTP and LootTP.CreateSlider and LootTP:CreateSlider({
		Name = 'Sky Height',
		Min = 50,
		Max = 500,
		Default = 200,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	}) or nil

	VelocityMultiplier = LootTP and LootTP.CreateSlider and LootTP:CreateSlider({
		Name = 'Velocity Multiplier',
		Min = 0.1,
		Max = 5,
		Default = 1.5,
		Decimal = 10
	}) or nil

	Network = LootTP and LootTP.CreateToggle and LootTP:CreateToggle({
		Name = 'Network TP',
		Default = true
	}) or nil
end)
