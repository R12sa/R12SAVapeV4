--[[
	ANTILAG MODULE FOR VAPE V4
	Reduces FPS and ping spikes through optimizations
	- Frame-rate aware task waits
	- HTTP request debouncing
	- Loop optimization
	- Memory efficiency improvements
	- Render performance optimization
]]

local antilag = {}
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

-- Configuration
local CONFIG = {
	OPTIMAL_FRAMETIME = 1/60, -- 60 FPS target
	HTTP_REQUEST_DEBOUNCE = 0.5, -- seconds
	LOOP_THROTTLE_INTERVAL = 0.016, -- ~60 FPS
	MEMORY_CHECK_INTERVAL = 5, -- seconds
	MAX_PENDING_REQUESTS = 3,
	RENDER_THROTTLE = 0.016, -- throttle excessive renders
	MAX_FRAME_TIME = 0.05, -- cap frame time at 50ms
}

-- Internal state
local lastHttpTime = 0
local pendingHttpRequests = 0
local deltaTime = 0
local lastFrameTime = tick()
local gcCollectInterval = 0
local lastRenderTime = 0
local renderFrameCount = 0

-- Cache for repeated file operations
local fileCache = {}
local fileCacheMaxSize = 50

--[[ ===== PERFORMANCE MONITORING ===== ]]

function antilag.GetFrameTime()
	return deltaTime
end

function antilag.GetFPS()
	return 1 / math.max(deltaTime, 0.001)
end

-- Monitor frame times to detect lag - IMPROVED version
task.spawn(function()
	while true do
		local currentTime = tick()
		deltaTime = math.min(currentTime - lastFrameTime, CONFIG.MAX_FRAME_TIME)
		lastFrameTime = currentTime
		RunService.RenderStepped:Wait()
		renderFrameCount = renderFrameCount + 1
	end
end)

--[[ ===== HTTP REQUEST OPTIMIZATION ===== ]]

function antilag.HttpGet(url, noCache)
	-- Check if we're already at max pending requests
	if pendingHttpRequests >= CONFIG.MAX_PENDING_REQUESTS then
		task.wait(0.1)
		return antilag.HttpGet(url, noCache)
	end

	local cache = fileCache[url]
	if cache and not noCache and (tick() - cache.timestamp) < CONFIG.HTTP_REQUEST_DEBOUNCE then
		return cache.data
	end

	pendingHttpRequests = pendingHttpRequests + 1
	local result = game:HttpGet(url)
	pendingHttpRequests = pendingHttpRequests - 1
	
	if result then
		fileCache[url] = {data = result, timestamp = tick()}
	end

	return result
end

--[[ ===== FILE OPTIMIZATION ===== ]]

function antilag.ReadFileOptimized(path)
	local cache = fileCache[path]
	if cache then
		return cache.data
	end

	local success, result = pcall(function()
		return readfile(path)
	end)

	if success and result then
		if fileCache[path] then
			fileCache[path].data = result
			fileCache[path].timestamp = tick()
		else
			if #fileCache >= fileCacheMaxSize then
				-- Remove oldest cache entry
				local oldestKey = next(fileCache)
				fileCache[oldestKey] = nil
			end
			fileCache[path] = {data = result, timestamp = tick()}
		end
		return result
	end
	
	return nil
end

function antilag.WriteFileOptimized(path, content)
	local success, err = pcall(function()
		writefile(path, content)
	end)
	
	if success then
		-- Update cache
		fileCache[path] = {data = content, timestamp = tick()}
	else
		warn('[ANTILAG] Write file failed: ' .. tostring(err))
	end
	
	return success
end

--[[ ===== LOOP OPTIMIZATION ===== ]]

function antilag.ThrottledWait(customInterval)
	local interval = customInterval or CONFIG.LOOP_THROTTLE_INTERVAL
	
	-- Adaptive wait based on current frame time
	local adjustedInterval = math.max(interval, deltaTime)
	if adjustedInterval > 0 then
		task.wait(adjustedInterval)
	else
		RunService.RenderStepped:Wait()
	end
end

function antilag.OptimizedLoop(condition, callback, maxWaitTime)
	maxWaitTime = maxWaitTime or 30
	local startTime = tick()
	
	while condition() do
		if (tick() - startTime) > maxWaitTime then
			warn('[ANTILAG] Loop timeout after ' .. maxWaitTime .. ' seconds')
			break
		end
		
		callback()
		antilag.ThrottledWait()
	end
end

--[[ ===== MEMORY OPTIMIZATION ===== ]]

function antilag.OptimizeMemory()
	collectgarbage('collect')
	fileCache = {} -- Clear file cache to free memory
end

-- Periodic garbage collection
task.spawn(function()
	while true do
		task.wait(CONFIG.MEMORY_CHECK_INTERVAL)
		gcCollectInterval = gcCollectInterval + CONFIG.MEMORY_CHECK_INTERVAL
		
		if gcCollectInterval >= 30 then
			antilag.OptimizeMemory()
			gcCollectInterval = 0
		end
	end
end)

--[[ ===== EVENT OPTIMIZATION ===== ]]

function antilag.DebounceFunction(func, delay)
	local lastCallTime = 0
	
	return function(...)
		local currentTime = tick()
		if currentTime - lastCallTime >= delay then
			lastCallTime = currentTime
			return func(...)
		end
	end
end

function antilag.ThrottleFunction(func, interval)
	local lastCallTime = 0
	local pending = false
	
	return function(...)
		local currentTime = tick()
		if currentTime - lastCallTime >= interval then
			lastCallTime = currentTime
			pending = false
			return func(...)
		elseif not pending then
			pending = true
			task.delay(interval - (currentTime - lastCallTime), function()
				if pending then
					lastCallTime = tick()
					pending = false
					func(...)
				end
			end)
		end
	end
end

--[[ ===== RENDER OPTIMIZATION ===== ]]

function antilag.ThrottleRender(func, interval)
	local lastRenderTime = 0
	interval = interval or CONFIG.RENDER_THROTTLE
	
	return function(...)
		local currentTime = tick()
		if currentTime - lastRenderTime >= interval then
			lastRenderTime = currentTime
			return func(...)
		end
	end
end

--[[ ===== OPTIMIZATION REPORT ===== ]]

function antilag.GetStatus()
	return {
		fps = antilag.GetFPS(),
		frameTime = deltaTime,
		pendingRequests = pendingHttpRequests,
		cachedFiles = #fileCache,
		renderFrames = renderFrameCount,
	}
end

function antilag.PrintStatus()
	local status = antilag.GetStatus()
	print('[ANTILAG] FPS: ' .. math.floor(status.fps) .. ' | Frame Time: ' .. math.floor(status.frameTime * 1000) .. 'ms | Pending Requests: ' .. status.pendingRequests .. ' | Cached Files: ' .. status.cachedFiles .. ' | Render Frames: ' .. status.renderFrameCount)
end

--[[ ===== CLEANUP ===== ]]

function antilag.Cleanup()
	fileCache = {}
	renderFrameCount = 0
	collectgarbage('collect')
end

return antilag
