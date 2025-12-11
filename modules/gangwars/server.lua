local GangWars = {}
GangWars.active = false
GangWars.data = {}

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

local function GetSourceFromIdentifier(targetIdentifier)
    local players = GetPlayers()
    for _, src in ipairs(players) do
        local ids = GetPlayerIdentifiers(src)
        for _, id in ipairs(ids) do
            if id == targetIdentifier then
                return tonumber(src)
            end
        end
    end
    return nil
end

function GangWars:Start(gang1Id, gang2Id, opts)
	if self.active then return false, 'war_already_active' end
	if not gang1Id or not gang2Id or gang1Id == gang2Id then return false, 'invalid_gangs' end
	-- Normalize IDs to numbers to avoid key mismatch between strings and numbers
	gang1Id = tonumber(gang1Id)
	gang2Id = tonumber(gang2Id)
	if not gang1Id or not gang2Id or gang1Id == gang2Id then
		print('[GangWars] Start called with invalid gang IDs:', tostring(gang1Id), tostring(gang2Id))
		return false, 'invalid_gangs'
	end

	-- Get Handler from exports
	local Handler = exports['trase_gangs']:GetHandler()
	if not Handler then
		print('[GangWars] Failed to get Handler from exports')
		return false, 'handler_not_found'
	end

	local target = (opts and opts.targetKills) or Config.Features.GangWars.TargetKills or 50
    local wager = (opts and opts.wager) or 0

	self.active = true
	print('[GangWars] Starting war between ' .. tostring(gang1Id) .. ' and ' .. tostring(gang2Id) .. ' targetKills: ' .. tostring(target))
	local g1Label = (Handler.gangs and Handler.gangs[gang1Id] and (Handler.gangs[gang1Id].label or Handler.gangs[gang1Id].name)) or ('Gang '..tostring(gang1Id))
	local g2Label = (Handler.gangs and Handler.gangs[gang2Id] and (Handler.gangs[gang2Id].label or Handler.gangs[gang2Id].name)) or ('Gang '..tostring(gang2Id))
	self.data = {
		startedAt = os.time(),
		gangs = {},
		targetKills = target,
        wager = wager
	}
	-- Ensure keys are numeric
	self.data.gangs[gang1Id] = { name = (opts and opts.gang1Name) or g1Label, kills = 0, players = {} }
	self.data.gangs[gang2Id] = { name = (opts and opts.gang2Name) or g2Label, kills = 0, players = {} }

    -- Helper to add members from a gang
    local function AddGangMembers(gid)
        if Handler.gangs[gid] and Handler.gangs[gid].members then
            for identifier, _ in pairs(Handler.gangs[gid].members) do
                local src = GetSourceFromIdentifier(identifier)
                if src then
                    print('[GangWars] Adding member ' .. identifier .. ' (source: ' .. src .. ') to war for gang ' .. gid)
                    self.data.gangs[gid].players[src] = true
                    TriggerClientEvent('trase_gangs:gangwars:start', src, {
                        gang1Id = gang1Id,
                        gang2Id = gang2Id,
                        targetKills = target,
                        wager = wager,
                        names = {
                            [tonumber(gang1Id)] = self.data.gangs[gang1Id].name,
                            [tonumber(gang2Id)] = self.data.gangs[gang2Id].name,
                        }
                    })
                end
            end
        end
    end

    AddGangMembers(gang1Id)
    AddGangMembers(gang2Id)

	self:Broadcast()
	return true, self.data
end

function GangWars:End(winnerGangId)
	if not self.active then return end
	
	local Handler = exports['trase_gangs']:GetHandler()
	
	-- Get gang IDs and scores for database update
	local gang1Id, gang2Id
	local gang1Score, gang2Score = 0, 0
	local loserGangId
	
	for gid, g in pairs(self.data.gangs) do
		if not gang1Id then
			gang1Id = gid
			gang1Score = g.kills or 0
		else
			gang2Id = gid
			gang2Score = g.kills or 0
		end
		
		if gid == winnerGangId then
			-- This is the winner
		else
			loserGangId = gid
		end
	end
	
	-- Handle wager transfer
	local wager = self.data.wager or 0
	if wager > 0 and winnerGangId and loserGangId and Handler then
		-- Withdraw from loser's bank and deposit to winner's bank
		local withdrawSuccess = Handler:WithdrawBank(loserGangId, wager)
		if withdrawSuccess then
			Handler:DepositBank(winnerGangId, wager)
			print('[GangWars] Transferred wager $' .. wager .. ' from gang ' .. loserGangId .. ' to gang ' .. winnerGangId)
			
			-- Add audit logs for wager transfer
			local winnerName = self.data.gangs[winnerGangId] and self.data.gangs[winnerGangId].name or 'Unknown'
			local loserName = self.data.gangs[loserGangId] and self.data.gangs[loserGangId].name or 'Unknown'
			Handler:AddAuditLog(winnerGangId, 'system', 'gang_war_wager_won', nil, 'Won $' .. wager .. ' wager from ' .. loserName)
			Handler:AddAuditLog(loserGangId, 'system', 'gang_war_wager_lost', nil, 'Lost $' .. wager .. ' wager to ' .. winnerName)
		else
			print('[GangWars] Failed to withdraw wager from losing gang ' .. loserGangId)
		end
	end
	
	if winnerGangId and Handler then
		Handler:UpdateGangStats(winnerGangId, 'gangwar_wins', 1)
		if loserGangId then
			Handler:UpdateGangStats(loserGangId, 'gangwar_losses', 1)
		end
		
		-- Add audit logs for both gangs
		local winnerName = self.data.gangs[winnerGangId] and self.data.gangs[winnerGangId].name or 'Unknown'
		local loserName = loserGangId and self.data.gangs[loserGangId] and self.data.gangs[loserGangId].name or 'Unknown'
		
		Handler:AddAuditLog(winnerGangId, 'system', 'gang_war_won', nil, 'Won gang war against ' .. loserName)
		if loserGangId then
			Handler:AddAuditLog(loserGangId, 'system', 'gang_war_lost', nil, 'Lost gang war against ' .. winnerName)
		end
	end
	
	-- Update database with war results
	-- Find the active war in the database and update it
	if gang1Id and gang2Id then
		MySQL.update.await([[
			UPDATE trase_gang_war_history 
			SET status = 'completed', 
				winner_gang_id = ?, 
				gang_1_score = ?,
				gang_2_score = ?,
				ended_at = NOW()
			WHERE status = 'active' 
				AND ((gang_1_id = ? AND gang_2_id = ?) OR (gang_1_id = ? AND gang_2_id = ?))
		]], {
			winnerGangId,
			gang1Score,
			gang2Score,
			gang1Id, gang2Id,
			gang2Id, gang1Id
		})
	end

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
	local payload = { kills = {}, names = {}, targetKills = self.data.targetKills, wager = self.data.wager }
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
            wager = self.data.wager,
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
	
	-- Debug logging
	print('[GangWars] RecordKill called - killer:', killerSrc, 'victim:', victimSrc)
	print('[GangWars] Killer gang:', tostring(killerGang), 'Victim gang:', tostring(victimGang))
	
	if not killerGang or not victimGang then 
		print('[GangWars] Missing gang for killer or victim')
		return 
	end
	if killerGang == victimGang then 
		print('[GangWars] Same gang - friendly fire, ignoring')
		return 
	end
	
	-- Normalize gang IDs to numbers to match self.data.gangs keys
	killerGang = tonumber(killerGang)
	victimGang = tonumber(victimGang)
	
	print('[GangWars] Normalized killer gang:', tostring(killerGang), 'victim gang:', tostring(victimGang))
	print('[GangWars] Active gangs in war:', json.encode(self.data.gangs and (function() local keys = {} for k in pairs(self.data.gangs) do keys[#keys+1] = k end return keys end)() or {}))
	
	if not self.data.gangs[killerGang] or not self.data.gangs[victimGang] then 
		print('[GangWars] One or both gangs not part of this war')
		return 
	end

	self.data.gangs[killerGang].kills = self.data.gangs[killerGang].kills + 1
	print('[GangWars] Kill recorded! Gang', killerGang, 'now has', self.data.gangs[killerGang].kills, 'kills')
	
	if self.data.gangs[killerGang].kills >= self.data.targetKills then
		self:Broadcast()
		self:End(killerGang)
		return
	end
	self:Broadcast()
end

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

RegisterNetEvent('trase_gangs:gangwars:accept', function(gang1Id, gang2Id, targetKills, wager)
	gang1Id = tonumber(gang1Id)
	gang2Id = tonumber(gang2Id)
	print('[GangWars] Received accept event, starting war for', tostring(gang1Id), tostring(gang2Id), 'target', tostring(targetKills), 'wager', tostring(wager))
	GangWars:Start(gang1Id, gang2Id, { targetKills = targetKills, wager = wager })
end)

RegisterNetEvent('trase_gangs:gangwars:recordKill', function(victimId)
	GangWars:RecordKill(source, victimId)
end)

AddEventHandler('playerJoining', function()
	GangWars:OnJoin(source)
end)

if Config.Debug then print('[GangWars] Server module loaded') end

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
