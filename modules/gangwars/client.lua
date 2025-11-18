local GangWars = lib.class('GangWars')
local ActivityOverlay = require('client.activity_overlay')

function GangWars:constructor()
	self.active = false
	self.data = nil
	self.overlay = ActivityOverlay:new()
	self.kills = {}
	self.enemyMarkers = true
	self:registerEvents()
end

function GangWars:start(data)
	self.active = true
	self.data = data
	self.kills = { [data.gang1Id] = 0, [data.gang2Id] = 0 }
	self:showOverlay()
	self:startEnemyMarkers()
end

function GangWars:showOverlay()
	if not self.active then return end
	local leaderboard = {
		{ position = 1, name = self.data.names[self.data.gang1Id] or ('Gang '..self.data.gang1Id), value = (self.kills[self.data.gang1Id] or 0)..' / '..self.data.targetKills },
		{ position = 2, name = self.data.names[self.data.gang2Id] or ('Gang '..self.data.gang2Id), value = (self.kills[self.data.gang2Id] or 0)..' / '..self.data.targetKills },
	}
	table.sort(leaderboard, function(a,b)
		local av = tonumber(a.value:match('%d+')) or 0
		local bv = tonumber(b.value:match('%d+')) or 0
		return av > bv
	end)
	for i,e in ipairs(leaderboard) do e.position = i end
	self.overlay:Show({
		title = 'GANG WAR',
		description = 'First to '..self.data.targetKills..' kills wins',
		stats = {},
		leaderboard = leaderboard,
		showTimer = false
	})
end

function GangWars:update(payload)
	if not self.active then return end
	if payload.kills then self.kills = payload.kills end
	if payload.targetKills then self.data.targetKills = payload.targetKills end
	self:showOverlay()
end

function GangWars:endWar(data)
	self.active = false
	self.data = nil
	self.kills = {}
	self.overlay:Hide()
end

function GangWars:startEnemyMarkers()
	CreateThread(function()
		while self.active do
			Wait(0)
			local myGangTbl = LocalPlayer.state.gang
			local myGangId = myGangTbl and myGangTbl.id or nil
			if myGangId ~= self.data.gang1Id and myGangId ~= self.data.gang2Id then
				goto continue
			end
			for _, id in ipairs(GetActivePlayers()) do
				local pid = GetPlayerServerId(id)
				local state = Player(pid) and Player(pid).state or nil
				local g = state and state.gang or nil
				local gid = g and g.id or nil
				if gid and gid ~= myGangId and (gid == self.data.gang1Id or gid == self.data.gang2Id) then
					local ped = GetPlayerPed(id)
					local coords = GetEntityCoords(ped)
					DrawMarker(25, coords.x, coords.y, coords.z-1.0, 0.0,0.0,0.0, 0.0,0.0,0.0, 0.3,0.3,0.2, 255,0,0,160, false,false,2,false,nil,nil,false)
				end
			end
			::continue::
		end
	end)
end

function GangWars:registerEvents()
	RegisterNetEvent('trase_gangs:gangwars:start', function(data)
		self:start(data)
	end)
	RegisterNetEvent('trase_gangs:gangwars:update', function(payload)
		self:update(payload)
	end)
	RegisterNetEvent('trase_gangs:gangwars:end', function(data)
		self:endWar(data)
	end)
end

GangWars:new()

