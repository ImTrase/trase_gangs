local Turfs = {}
Turfs.activeTurf = nil
Turfs.turfData = {}

local function GetPrimaryIdentifier(src)
	local ids = GetPlayerIdentifiers(src)
	local first
	for _, id in ipairs(ids) do
		first = first or id
		if id:find('license:', 1, true) == 1 then
			return id
		end
	end
	return first
end

function Turfs:StartTurf(turfName, turfCfg)
	if self.activeTurf then return false, 'turf_already_active' end
	if self.isStarting then return false, 'turf_starting' end
	if not turfCfg then return false, 'turf_not_found' end

	if Config.Debug then print('[Turfs] Starting turf sequence: '..turfName) end

	self.isStarting = true
	if AlertServer then
		AlertServer(-1, turfName .. " Turf is starting in 10 Seconds get there now and take it over")
	end

	SetTimeout(10000, function()
		self.isStarting = false
		if self.activeTurf then return end

		self.activeTurf = turfName
		self.turfData = {
			name = turfName,
			coords = turfCfg.coords,
			radius = turfCfg.radius,
			startTime = os.time(),
			duration = Config.Features.Turfs.Duration,
			gangs = {},
			players = {},
			playersInside = {},
			winner = nil
		}

		if AlertServer then
			AlertServer(-1, turfName .. " Turf has started!")
		end

		TriggerClientEvent('trase_gangs:turfs:start', -1, {
			name = turfName,
			coords = turfCfg.coords,
			radius = turfCfg.radius,
			duration = self.turfData.duration
		})

		SetTimeout(self.turfData.duration * 1000, function()
			self:EndTurf()
		end)
	end)

	return true, { message = "Turf starting in 10 seconds" }
end

function Turfs:EndTurf()
	if not self.activeTurf then return false, 'no_active_turf' end
	
	-- Calculate winner based on most alive members inside
	local winnerGangId = nil
	local maxAlive = -1
	local tied = false

	for gid, _ in pairs(self.turfData.gangs) do
		local aliveCount = self:CountGangPlayers(gid)
		if aliveCount > maxAlive then
			maxAlive = aliveCount
			winnerGangId = gid
			tied = false
		elseif aliveCount == maxAlive then
			tied = true
		end
	end

	if winnerGangId and maxAlive > 0 and not tied then
		local winnerName = self.turfData.gangs[winnerGangId].name
		if Config.Debug then print('[Turfs] Winner: '..winnerName..' with '..maxAlive..' alive members') end
		
		local Handler = exports['trase_gangs']:GetHandler()
		if Handler then
			Handler:UpdateGangStats(winnerGangId, 'turf_wins', 1)
			for gid, _ in pairs(self.turfData.gangs) do
				if gid ~= winnerGangId then
					Handler:UpdateGangStats(gid, 'turf_losses', 1)
				end
			end
		end

		if AlertServer then
			AlertServer(-1, "Turf " .. self.activeTurf .. " ended! Winner: " .. winnerName)
		end

		TriggerClientEvent('trase_gangs:turfs:winner', -1, {
			gangId = winnerGangId,
			gangName = winnerName,
			aliveCount = maxAlive
		})
	else
		if Config.Debug then print('[Turfs] No winner (tie or no alive members)') end
		if AlertServer then
			AlertServer(-1, "Turf " .. self.activeTurf .. " ended in a tie or no winner!")
		end
		TriggerClientEvent('trase_gangs:turfs:winner', -1, nil)
	end

	if Config.Debug then print('[Turfs] Ending turf: '..self.activeTurf) end
	TriggerClientEvent('trase_gangs:turfs:end', -1)
	self.activeTurf = nil
	self.turfData = {}
	return true
end

function Turfs:PlayerEnter(src)
	if not self.activeTurf then return end
	local ident = GetPrimaryIdentifier(src)
	if not ident then return end
	local ply = Player(src)
	local gangTbl = ply and ply.state and ply.state.gang or nil
	local gangId = gangTbl and gangTbl.id or nil
	local gangLabel = gangTbl and (gangTbl.label or gangTbl.name) or nil

	self.turfData.playersInside[src] = true
	if not self.turfData.players[src] then
		self.turfData.players[src] = { kills = 0, gangId = gangId, identifier = ident, isDead = false }
	else
		self.turfData.players[src].isDead = false -- Reset death status on re-entry
	end

	if gangId and not self.turfData.gangs[gangId] then
		self.turfData.gangs[gangId] = { name = gangLabel or ('Gang '..gangId), kills = 0, players = {} }
	end
	if gangId then
		self.turfData.gangs[gangId].players[src] = true
	end

	self:BroadcastStats()
	if Config.Debug then
		print(('[Turfs] Player %d entered turf. Gang: %s'):format(src, gangLabel or 'none'))
	end
end

function Turfs:PlayerLeave(src)
	if not self.activeTurf then return end
	self.turfData.playersInside[src] = nil
	local pdata = self.turfData.players[src]
	if pdata and pdata.gangId and self.turfData.gangs[pdata.gangId] then
		self.turfData.gangs[pdata.gangId].players[src] = nil
		-- Check if gang has any alive players left
		if self:CountGangPlayers(pdata.gangId) == 0 then
			self.turfData.gangs[pdata.gangId] = nil
		end
	end
	self:BroadcastStats()
	if Config.Debug then print(('[Turfs] Player %d left turf'):format(src)) end
end

function Turfs:PlayerDied(src)
	if not self.activeTurf then return end
	local pdata = self.turfData.players[src]
	if pdata then
		pdata.isDead = true
		if pdata.gangId and self.turfData.gangs[pdata.gangId] then
			-- Check if gang has any alive players left
			if self:CountGangPlayers(pdata.gangId) == 0 then
				self.turfData.gangs[pdata.gangId] = nil
			end
		end
		self:BroadcastStats()
	end
end

function Turfs:RecordKill(killer, victim)
	if not self.activeTurf then return end
	local kData = self.turfData.players[killer]
	if not kData then return end
	kData.kills = kData.kills + 1
	if kData.gangId and self.turfData.gangs[kData.gangId] then
		self.turfData.gangs[kData.gangId].kills = self.turfData.gangs[kData.gangId].kills + 1
	end
	TriggerClientEvent('trase_gangs:turfs:playerKill', killer)
	self:BroadcastStats()
	if Config.Debug then
		print(('[Turfs] Kill recorded killer=%d kills=%d gang=%s'):format(killer, kData.kills, tostring(kData.gangId)))
	end
end

function Turfs:CountGangPlayers(gid)
	local g = self.turfData.gangs[gid]
	if not g then return 0 end
	local c = 0
	for src, _ in pairs(g.players) do
		local p = self.turfData.players[src]
		if p and not p.isDead and self.turfData.playersInside[src] then
			c = c + 1
		end
	end
	return c
end

function Turfs:BroadcastStats()
	if not self.activeTurf then return end
	local gangStats = {}
	for gid, gData in pairs(self.turfData.gangs) do
		gangStats[gid] = {
			name = gData.name,
			kills = gData.kills,
			playerCount = self:CountGangPlayers(gid)
		}
	end
	for pid, _ in pairs(self.turfData.playersInside) do
		TriggerClientEvent('trase_gangs:turfs:updateStats', pid, gangStats)
	end
end

lib.callback.register('trase_gangs:turfs:checkActive', function(source)
	return Turfs.activeTurf ~= nil, Turfs.activeTurf, Turfs.turfData
end)

lib.callback.register('trase_gangs:turfs:start', function(source, turfName)
	local ply = Player(source)
	local gangTbl = ply and ply.state and ply.state.gang or nil
	if not gangTbl then
		return false, 'no_gang'
	end
	local cfg = Config.Features.Turfs.Zones[turfName]
	if not cfg then return false, 'turf_not_found' end
	local ok, res = Turfs:StartTurf(turfName, cfg)
	return ok, res
end)

RegisterNetEvent('trase_gangs:turfs:playerEnter', function()
	Turfs:PlayerEnter(source)
end)

RegisterNetEvent('trase_gangs:turfs:playerLeave', function()
	Turfs:PlayerLeave(source)
end)

RegisterNetEvent('trase_gangs:turfs:playerDied', function()
	Turfs:PlayerDied(source)
end)

RegisterNetEvent('trase_gangs:turfs:recordKill', function(victimId)
	Turfs:RecordKill(source, victimId)
end)

if Config.Debug then print('[Turfs] Server module loaded') end

return Turfs