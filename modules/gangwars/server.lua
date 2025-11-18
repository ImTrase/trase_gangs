local GangWars = {}
local Handler = require 'modules.handler.server'
GangWars.active = false
GangWars.data = {}

-- Helpers
local function PrimaryIdentifier(src)
	local ids = GetPlayerIdentifiers(src)
	local first
	for _, id in ipairs(ids) do
		first = first or id
		if id:find('license:', 1, true) == 1 then return id end
	end
	return first
end

local function getPlayerGang(src)
	local ply = Player(src)
	local g = ply and ply.state and ply.state.gang or nil
	if not g then return nil end
	return g.id, (g.label or g.name or ('Gang '..tostring(g.id)))
end

function GangWars:Start(gang1Id, gang2Id, opts)
	if self.active then return false, 'war_already_active' end
	if not gang1Id or not gang2Id or gang1Id == gang2Id then return false, 'invalid_gangs' end

	local target = (opts and opts.targetKills) or Config.Features.GangWars.TargetKills or 50

	self.active = true
	local g1Label = (Handler and Handler.gangs and Handler.gangs[gang1Id] and (Handler.gangs[gang1Id].label or Handler.gangs[gang1Id].name)) or ('Gang '..tostring(gang1Id))
	local g2Label = (Handler and Handler.gangs and Handler.gangs[gang2Id] and (Handler.gangs[gang2Id].label or Handler.gangs[gang2Id].name)) or ('Gang '..tostring(gang2Id))
	self.data = {
		startedAt = os.time(),
		gangs = {
			[gang1Id] = { name = (opts and opts.gang1Name) or g1Label, kills = 0, players = {} },
			[gang2Id] = { name = (opts and opts.gang2Name) or g2Label, kills = 0, players = {} }
		},
		targetKills = target
	}

	-- Enroll current online players from these gangs
	for _, id in ipairs(GetPlayers()) do
		local src = tonumber(id)
		local gid = getPlayerGang(src)
		if gid and self.data.gangs[gid] then
			self.data.gangs[gid].players[src] = true
			TriggerClientEvent('trase_gangs:gangwars:start', src, {
				gang1Id = gang1Id,
				gang2Id = gang2Id,
				targetKills = target,
				names = {
					[tonumber(gang1Id)] = self.data.gangs[gang1Id].name,
					[tonumber(gang2Id)] = self.data.gangs[gang2Id].name,
				}
			})
		end
	end

	self:Broadcast()
	return true, self.data
end

function GangWars:End(winnerGangId)
	if not self.active then return end
	for gid, g in pairs(self.data.gangs) do
		for src, _ in pairs(g.players) do
			TriggerClientEvent('trase_gangs:gangwars:end', src, { winner = winnerGangId })
		end
	end
	self.active = false
	self.data = {}
end

function GangWars:Broadcast()
	if not self.active then return end
	local payload = { kills = {}, names = {}, targetKills = self.data.targetKills }
	for gid, g in pairs(self.data.gangs) do
		payload.kills[gid] = g.kills
		payload.names[gid] = g.name
	end
	for gid, g in pairs(self.data.gangs) do
		for src, _ in pairs(g.players) do
			TriggerClientEvent('trase_gangs:gangwars:update', src, payload)
		end
	end
end

function GangWars:OnJoin(src)
	if not self.active then return end
	local gid = getPlayerGang(src)
	if gid and self.data.gangs[gid] then
		self.data.gangs[gid].players[src] = true
		TriggerClientEvent('trase_gangs:gangwars:start', src, {
			gang1Id = (next(self.data.gangs)),
			gang2Id = (function(t) for k in pairs(t) do if k ~= gid then return k end end end)(self.data.gangs),
			targetKills = self.data.targetKills,
			names = (function()
				local n = {}
				for id, g in pairs(self.data.gangs) do n[id] = g.name end
				return n
			end)()
		})
		self:Broadcast()
	end
end

function GangWars:RecordKill(killerSrc, victimSrc)
	if not self.active then return end
	local killerGang = getPlayerGang(killerSrc)
	local victimGang = getPlayerGang(victimSrc)
	if not killerGang or not victimGang or killerGang == victimGang then return end
	if not self.data.gangs[killerGang] or not self.data.gangs[victimGang] then return end

	self.data.gangs[killerGang].kills = self.data.gangs[killerGang].kills + 1
	if self.data.gangs[killerGang].kills >= self.data.targetKills then
		self:Broadcast()
		self:End(killerGang)
		return
	end
	self:Broadcast()
end

-- Public API for UI
lib.callback.register('trase_gangs:gangwars:startWar', function(source, opponentGangId, targetKills)
	local myGangId = getPlayerGang(source)
	if not myGangId then return false, 'no_gang' end
	if tonumber(opponentGangId) == myGangId then return false, 'invalid_opponent' end
	local ok, data = GangWars:Start(myGangId, opponentGangId, { targetKills = targetKills })
	return ok, data
end)

lib.callback.register('trase_gangs:gangwars:isActive', function(source)
	return GangWars.active, GangWars.data
end)

-- Basic events for integration
RegisterNetEvent('trase_gangs:gangwars:accept', function(gang1Id, gang2Id, targetKills)
	GangWars:Start(gang1Id, gang2Id, { targetKills = targetKills })
end)

RegisterNetEvent('trase_gangs:gangwars:recordKill', function(victimId)
	GangWars:RecordKill(source, victimId)
end)

AddEventHandler('playerJoining', function()
	GangWars:OnJoin(source)
end)

if Config.Debug then print('[GangWars] Server module loaded') end

-- Debug/test command: /gwstart <opponentGangId> [targetKills]
RegisterCommand('gwstart', function(src, args)
	if src == 0 then return end
	local myGang = getPlayerGang(src)
	if not myGang then
		TriggerClientEvent('chat:addMessage', src, { args = {'GangWars', 'You are not in a gang'} })
		return
	end
	local opp = tonumber(args[1])
	local target = tonumber(args[2]) or (Config.Features.GangWars.TargetKills or 50)
	if not opp then
		TriggerClientEvent('chat:addMessage', src, { args = {'GangWars', 'Usage: /gwstart <opponentGangId> [targetKills]'} })
		return
	end
	GangWars:Start(myGang, opp, { targetKills = target })
end, false)

return GangWars
