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
	if not turfCfg then return false, 'turf_not_found' end

	if Config.Debug then print('[Turfs] Starting turf: '..turfName) end

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

	TriggerClientEvent('trase_gangs:turfs:start', -1, {
		name = turfName,
		coords = turfCfg.coords,
		radius = turfCfg.radius,
		duration = self.turfData.duration
	})

	SetTimeout(self.turfData.duration * 1000, function()
		self:EndTurf()
	end)

	return true, self.turfData
end

function Turfs:EndTurf()
	if not self.activeTurf then return false, 'no_active_turf' end
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
		self.turfData.players[src] = { kills = 0, gangId = gangId, identifier = ident }
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
	end
	self:BroadcastStats()
	if Config.Debug then print(('[Turfs] Player %d left turf'):format(src)) end
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
	for _ in pairs(g.players) do c = c + 1 end
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

RegisterNetEvent('trase_gangs:turfs:recordKill', function(victimId)
	Turfs:RecordKill(source, victimId)
end)

if Config.Debug then print('[Turfs] Server module loaded') end

return Turfs