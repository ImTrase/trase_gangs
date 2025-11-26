if not Config.Features.Turfs.Enabled then return end
local Turfs = lib.class('Turfs')

function Turfs:constructor()
	if Config.Debug then print('[Turfs] Initializing Turfs client...') end
	self.zones = {}
	self.activeTurf = nil
	self.turfPoint = nil
	self.isInTurf = false
	self.overlay = ActivityOverlay:new()
	self.gangStats = {}
	self:loadZones()
	self:registerEvents()
end

function Turfs:loadZones()
	for name, data in pairs(Config.Features.Turfs.Zones) do
		self.zones[name] = data
		local zone = lib.zones.sphere({
			coords = data.coords,
			radius = data.radius,
			debug = Config.Debug,
			onEnter = function()
				if Config.Debug then print('[Turfs] Entered passive turf zone: '..name) end
			end,
			onExit = function()
				if Config.Debug then print('[Turfs] Exited passive turf zone: '..name) end
			end
		})
		data.zoneObject = zone

		data.startPoint = lib.points.new({
			coords = data.coords,
			distance = 3.0
		})
		local inst = self
		function data.startPoint:onEnter()
			inst:_enteredStart(name, data)
		end
		function data.startPoint:onExit()
			inst:_exitedStart(name, data)
		end
	end
end

function Turfs:_enteredStart(name, data)
	if self.activeTurf then return end
	self.startingName = name
	if lib and lib.showTextUI then
		lib.showTextUI('[E] Start Turf')
	end
	if Config.Debug then print('[Turfs] Near turf start marker: '..name) end
	CreateThread(function()
		while self.startingName == name and not self.activeTurf do
			Wait(0)
			local m = Config.Features.Turfs.MarkerColor
			DrawMarker(1, data.coords.x, data.coords.y, data.coords.z-1.0, 0.0,0.0,0.0, 0.0,0.0,0.0, 1.5,1.5,1.0, m.r,m.g,m.b,m.a, false,false,2,false,nil,nil,false)
			if IsControlJustReleased(0, 38) then
				self:startTurfAttempt(name)
			end
		end
	end)
end

function Turfs:_exitedStart(name, data)
	if self.startingName == name then
		self.startingName = nil
		if lib and lib.hideTextUI then lib.hideTextUI() end
		if Config.Debug then print('[Turfs] Left turf start marker: '..name) end
	end
end

function Turfs:startTurfAttempt(name)
	if self.activeTurf then return end
	local gangTbl = LocalPlayer.state.gang
	if not gangTbl then
		if lib and lib.notify then
			lib.notify({ title = TranslateText('turf_title', 'Turf'), description = TranslateText('turf_no_gang', 'You must be in a gang to start a turf'), type = 'error' })
		end
		return
	end
	local success, result = lib.callback.await('trase_gangs:turfs:start', false, name)
	if success then
		if lib and lib.notify then
			lib.notify({ title = TranslateText('turf_title', 'Turf'), description = TranslateText('turf_started', 'Turf "%s" started!'):format(name), type = 'success' })
		end
	else
		local reason = tostring(result)
		local msg = TranslateText('turf_start_failed', 'Failed to start turf: %s'):format(reason)
		if reason == 'no_gang' then msg = TranslateText('turf_no_gang', 'You must be in a gang to start a turf') end
		if reason == 'turf_already_active' then msg = TranslateText('turf_already_active', 'A turf is already active') end
		if lib and lib.notify then
			lib.notify({ title = TranslateText('turf_title', 'Turf'), description = msg, type = 'error' })
		end
	end
end

function Turfs:startTurf(turfData)
	self.activeTurf = turfData
	self.turfPoint = lib.points.new({
		coords = turfData.coords,
		distance = turfData.radius,
	})
	local inst = self
	function self.turfPoint:onEnter()
		if Config.TeleportNonMembers then
			local gang = LocalPlayer.state.gang
			if not gang then
				local center = vector3(turfData.coords.x, turfData.coords.y, turfData.coords.z)
				local coords = GetEntityCoords(PlayerPedId())
				local dir = coords - center
				local dist = #dir
				if dist < 0.1 then dir = vector3(1, 0, 0) end
				local newPos = center + (dir / #dir) * (turfData.radius + 5.0)
				SetEntityCoords(PlayerPedId(), newPos.x, newPos.y, newPos.z, false, false, false, false)
				if lib and lib.notify then
					lib.notify({ type = 'error', description = 'You must be in a gang to enter this zone!' })
				end
				return
			end
		end
		inst.isInTurf = true
		TriggerServerEvent('trase_gangs:turfs:playerEnter')
		SetTimeout(300, function() inst:showOverlay() end)
	end
	function self.turfPoint:onExit()
		inst.isInTurf = false
		TriggerServerEvent('trase_gangs:turfs:playerLeave')
		inst:hideOverlay()
	end
	CreateThread(function()
		while inst.activeTurf do
			Wait(0)
			local c = Config.Features.Turfs.ActiveMarkerColor
			local distance = #(GetEntityCoords(PlayerPedId()) - vector3(turfData.coords.x, turfData.coords.y, turfData.coords.z))
            if distance <= Config.Features.Turfs.DrawDistance then
				DrawMarker(1, turfData.coords.x, turfData.coords.y, turfData.coords.z-10.0,
					0.0,0.0,0.0, 0.0,0.0,0.0,
					turfData.radius*2.0, turfData.radius*2.0, 60.0,
					c.r,c.g,c.b,c.a,
					false,false,2,false,nil,nil,false)
			end
		end
	end)
	if Config.Debug then print('[Turfs] Turf started: '..turfData.name) end
end

function Turfs:endTurf()
	if self.turfPoint then self.turfPoint:remove() self.turfPoint=nil end
	self.isInTurf = false
	self:hideOverlay()
	self.gangStats = {}
	self.activeTurf = nil
	if Config.Debug then print('[Turfs] Turf ended') end
end

function Turfs:showOverlay()
	if not self.activeTurf then return end
	local leaderboard = {}
	for gid, gData in pairs(self.gangStats) do
		leaderboard[#leaderboard+1] = {
			position = #leaderboard+1,
			name = gData.name,
			value = (gData.playerCount or 0)..' Alive',
			color = '#2563eb'
		}
	end
	table.sort(leaderboard, function(a,b)
		local ak = tonumber(a.value:match('%d+')) or 0
		local bk = tonumber(b.value:match('%d+')) or 0
		return ak > bk
	end)
	for i,e in ipairs(leaderboard) do e.position = i end
	self.overlay:Show({
		title = self.activeTurf.name or 'TURF',
		description = 'Compete for control. Most alive members wins.',
		stats = {},
		leaderboard = leaderboard,
		showTimer = true,
		timerDuration = self.activeTurf.duration or Config.Features.Turfs.Duration,
		timerLabel = 'TIME REMAINING'
	})
end

function Turfs:hideOverlay()
	self.overlay:Hide()
end

function Turfs:updateOverlay()
	if self.isInTurf and self.overlay:IsVisible() then
		self:showOverlay()
	end
end

function Turfs:registerEvents()
	RegisterNetEvent('trase_gangs:turfs:start', function(turfData)
		self:startTurf(turfData)
	end)
	RegisterNetEvent('trase_gangs:turfs:end', function()
		self:endTurf()
	end)
	RegisterNetEvent('trase_gangs:turfs:updateStats', function(gangStats)
		self.gangStats = gangStats
		self:updateOverlay()
	end)
	RegisterNetEvent('trase_gangs:turfs:playerKill', function()
		self:updateOverlay()
	end)
	AddEventHandler('gameEventTriggered', function(name, args)
		if name == 'CEventNetworkEntityDamage' then
			local victim = args[1]
			local isFatal = args[6] == 1
			if self.isInTurf and victim == PlayerPedId() and isFatal then
				TriggerServerEvent('trase_gangs:turfs:playerDied')
			end
		end
	end)
end

Turfs:new()
