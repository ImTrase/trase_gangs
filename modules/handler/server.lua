local Handler = {}
Handler.gangs = {} -- Cache of all gangs
Handler.playerGangs = {} -- Cache of player identifier -> gang_id

-- Create database tables if they don't exist
function Handler:CreateTables()
    if Config.Debug then
        print('[Handler] Checking database tables...')
    end
    
    -- Main gangs table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `trase_gangs` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(100) NOT NULL,
            `label` VARCHAR(100) NOT NULL,
            `owner_identifier` VARCHAR(60) NOT NULL,
            `max_members` INT(11) DEFAULT 10,
            `max_ranks` INT(11) DEFAULT 5,
            `bank` INT(11) DEFAULT 0,
            `reputation` INT(11) DEFAULT 0,
            `total_revenue` INT(11) DEFAULT 0,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `name` (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    
    -- Gang members table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `trase_gang_members` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `gang_id` INT(11) NOT NULL,
            `identifier` VARCHAR(60) NOT NULL,
            `name` VARCHAR(100) DEFAULT NULL,
            `rank_id` INT(11) DEFAULT NULL,
            `joined_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `last_online` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `gang_member` (`gang_id`, `identifier`),
            FOREIGN KEY (`gang_id`) REFERENCES `trase_gangs`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    
    -- Gang ranks table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `trase_gang_ranks` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `gang_id` INT(11) NOT NULL,
            `name` VARCHAR(50) NOT NULL,
            `grade` INT(11) NOT NULL DEFAULT 0,
            `permissions` LONGTEXT DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `gang_rank` (`gang_id`, `grade`),
            FOREIGN KEY (`gang_id`) REFERENCES `trase_gangs`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    
    -- Gang member stats table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `trase_gang_member_stats` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `gang_id` INT(11) NOT NULL,
            `identifier` VARCHAR(60) NOT NULL,
            `turf_kills` INT(11) DEFAULT 0,
            `turf_deaths` INT(11) DEFAULT 0,
            `drugzone_kills` INT(11) DEFAULT 0,
            `drugzone_deaths` INT(11) DEFAULT 0,
            `gangwar_kills` INT(11) DEFAULT 0,
            `gangwar_deaths` INT(11) DEFAULT 0,
            PRIMARY KEY (`id`),
            UNIQUE KEY `member_stats` (`gang_id`, `identifier`),
            FOREIGN KEY (`gang_id`) REFERENCES `trase_gangs`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    
    -- Gang statistics table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `trase_gang_stats` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `gang_id` INT(11) NOT NULL,
            `turf_wins` INT(11) DEFAULT 0,
            `turf_losses` INT(11) DEFAULT 0,
            `drugzone_wins` INT(11) DEFAULT 0,
            `drugzone_losses` INT(11) DEFAULT 0,
            `gangwar_wins` INT(11) DEFAULT 0,
            `gangwar_losses` INT(11) DEFAULT 0,
            PRIMARY KEY (`id`),
            UNIQUE KEY `gang_stats` (`gang_id`),
            FOREIGN KEY (`gang_id`) REFERENCES `trase_gangs`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    
    -- Audit log table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `trase_gang_audit_log` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `gang_id` INT(11) NOT NULL,
            `actor_identifier` VARCHAR(60) NOT NULL,
            `action` VARCHAR(100) NOT NULL,
            `target_identifier` VARCHAR(60) DEFAULT NULL,
            `details` TEXT DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `gang_audit` (`gang_id`),
            FOREIGN KEY (`gang_id`) REFERENCES `trase_gangs`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    
    -- Gang unlocks table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `trase_gang_unlocks` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `gang_id` INT(11) NOT NULL,
            `unlock_type` VARCHAR(50) NOT NULL,
            `level` INT(11) DEFAULT 1,
            `unlocked_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `gang_unlock` (`gang_id`, `unlock_type`),
            FOREIGN KEY (`gang_id`) REFERENCES `trase_gangs`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    
    -- Gang invites table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `trase_gang_invites` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `gang_id` INT(11) NOT NULL,
            `inviter_identifier` VARCHAR(60) NOT NULL,
            `invitee_identifier` VARCHAR(60) NOT NULL,
            `status` ENUM('pending', 'accepted', 'declined') DEFAULT 'pending',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `expires_at` TIMESTAMP DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `gang_invite` (`gang_id`),
            FOREIGN KEY (`gang_id`) REFERENCES `trase_gangs`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    
    if Config.Debug then
        print('[Handler] Database tables verified/created')
    end
end

-- Initialize handler
function Handler:Init()
    if Config.Debug then
        print('[Handler] Initializing gang handler...')
    end
    
    self:CreateTables()
    self:LoadAllGangs()
    
    if Config.Debug then
        print('[Handler] Gang handler initialized with ' .. #self.gangs .. ' gangs')
    end
end

-- Load all gangs from database into cache
function Handler:LoadAllGangs()
    local gangs = MySQL.query.await('SELECT * FROM trase_gangs', {})
    
    for _, gang in ipairs(gangs) do
        self.gangs[gang.id] = gang
        
        -- Load gang members
        local members = MySQL.query.await('SELECT * FROM trase_gang_members WHERE gang_id = ?', {gang.id})
        gang.members = {}
        for _, member in ipairs(members) do
            print('[LoadAllGangs] Loading member:', member.identifier, 'name:', member.name, 'rank_id:', member.rank_id)
            gang.members[member.identifier] = {
                identifier = member.identifier,
                name = member.name,
                rank_id = member.rank_id,
                joined_at = member.joined_at,
                last_online = member.last_online
            }
            self.playerGangs[member.identifier] = gang.id
        end
        
        -- Load gang ranks
        local ranks = MySQL.query.await('SELECT * FROM trase_gang_ranks WHERE gang_id = ? ORDER BY grade DESC', {gang.id})
        gang.ranks = {}
        for _, rank in ipairs(ranks) do
            rank.permissions = json.decode(rank.permissions) or {}
            gang.ranks[rank.grade] = rank
        end
        
        -- Load gang stats
        local stats = MySQL.single.await('SELECT * FROM trase_gang_stats WHERE gang_id = ?', {gang.id})
        gang.stats = stats or {
            turf_wins = 0, turf_losses = 0,
            drugzone_wins = 0, drugzone_losses = 0,
            gangwar_wins = 0, gangwar_losses = 0
        }
    end
end

-- Create a new gang
function Handler:CreateGang(data)
    if Config.Debug then
        print('[Handler] Creating gang: ' .. data.name)
    end
    
    -- Check if gang name already exists
    for _, gang in pairs(self.gangs) do
        if gang.name == data.name then
            return false, 'gang_name_exists'
        end
    end
    
    local insertId = MySQL.insert.await([[
        INSERT INTO trase_gangs (name, label, owner_identifier, max_members, max_ranks)
        VALUES (?, ?, ?, ?, ?)
    ]], {
        data.name,
        data.label or data.name,
        data.owner,
        data.max_members or Config.Handler.DefaultMaxMembers,
        data.max_ranks or Config.Handler.DefaultMaxRanks
    })
    
    if not insertId then
        return false, 'database_error'
    end
    
    -- Create default ranks
    local defaultRanks = {
        { grade = 4, name = 'Boss', permissions = {
            manage_members = true, manage_ranks = true, manage_bank = true,
            invite_members = true, kick_members = true, promote_members = true,
            access_stash = true, view_audit = true, manage_unlocks = true
        }},
        { grade = 3, name = 'Co-Boss', permissions = {
            manage_members = true, invite_members = true, kick_members = true,
            promote_members = true, access_stash = true, view_audit = true
        }},
        { grade = 2, name = 'Captain', permissions = {
            invite_members = true, access_stash = true
        }},
        { grade = 1, name = 'Member', permissions = {
            access_stash = true
        }},
        { grade = 0, name = 'Recruit', permissions = {} }
    }
    
    for _, rank in ipairs(defaultRanks) do
        MySQL.insert.await([[
            INSERT INTO trase_gang_ranks (gang_id, name, grade, permissions)
            VALUES (?, ?, ?, ?)
        ]], {
            insertId,
            rank.name,
            rank.grade,
            json.encode(rank.permissions)
        })
    end
    
    -- Create gang stats entry
    MySQL.insert.await('INSERT INTO trase_gang_stats (gang_id) VALUES (?)', {insertId})
    
    -- Add owner as member with highest rank
    self:AddMember(insertId, data.owner, 4, data.owner, true)
    
    -- Reload gangs
    self:LoadAllGangs()
    
    self:AddAuditLog(insertId, data.owner, 'gang_created', nil, 'Gang created')
    
    return true, insertId
end

-- Delete a gang
function Handler:DeleteGang(gangId, actorIdentifier)
    if Config.Debug then
        print('[Handler] Deleting gang: ' .. gangId)
    end
    
    local gang = self.gangs[gangId]
    if not gang then
        return false, 'gang_not_found'
    end
    
    MySQL.query.await('DELETE FROM trase_gangs WHERE id = ?', {gangId})
    
    -- Clear cache
    for identifier, _ in pairs(gang.members) do
        self.playerGangs[identifier] = nil
    end
    self.gangs[gangId] = nil
    
    if Config.Debug then
        print('[Handler] Gang deleted: ' .. gangId)
    end
    
    return true
end

-- Add member to gang
function Handler:AddMember(gangId, identifier, rankGrade, actorIdentifier, skipInvite)
    local gang = self.gangs[gangId]
    if not gang then
        return false, 'gang_not_found'
    end
    
    -- Check if member already in a gang
    if self.playerGangs[identifier] then
        return false, 'already_in_gang'
    end
    
    -- Check max members
    local memberCount = 0
    for _ in pairs(gang.members) do memberCount = memberCount + 1 end
    if memberCount >= gang.max_members then
        return false, 'max_members_reached'
    end
    
    -- Check if rank exists
    if not gang.ranks[rankGrade] then
        rankGrade = 0 -- Default to lowest rank
    end
    
    local rankId = gang.ranks[rankGrade].id
    
    -- Get player name if they're online
    local playerName = nil
    for _, player in ipairs(GetPlayers()) do
        local xPlayer = GetPlayerFromId(player)
        if xPlayer and xPlayer.identifier == identifier then
            playerName = GetPlayerName(player)
            break
        end
    end
    
    MySQL.insert.await([[
        INSERT INTO trase_gang_members (gang_id, identifier, name, rank_id)
        VALUES (?, ?, ?, ?)
    ]], {gangId, identifier, playerName, rankId})
    
    -- Create member stats
    MySQL.insert.await([[
        INSERT INTO trase_gang_member_stats (gang_id, identifier)
        VALUES (?, ?)
    ]], {gangId, identifier})
    
    -- Update cache
    gang.members[identifier] = {
        identifier = identifier,
        name = playerName,
        rank_id = rankId,
        joined_at = os.date('%Y-%m-%d %H:%M:%S')
    }
    self.playerGangs[identifier] = gangId
    
    if not skipInvite then
        self:AddAuditLog(gangId, actorIdentifier, 'member_added', identifier, 'Member added to gang')
    end
    
    return true
end

-- Remove member from gang
function Handler:RemoveMember(gangId, identifier, actorIdentifier)
    local gang = self.gangs[gangId]
    if not gang then
        return false, 'gang_not_found'
    end
    
    -- Cannot kick owner
    if gang.owner_identifier == identifier then
        return false, 'cannot_kick_owner'
    end
    
    MySQL.query.await('DELETE FROM trase_gang_members WHERE gang_id = ? AND identifier = ?', {gangId, identifier})
    
    -- Update cache
    gang.members[identifier] = nil
    self.playerGangs[identifier] = nil
    
    self:AddAuditLog(gangId, actorIdentifier, 'member_removed', identifier, 'Member removed from gang')
    
    return true
end

-- Promote/demote member
function Handler:SetMemberRank(gangId, identifier, newRankGrade, actorIdentifier, forceOwnerChange)
    local gang = self.gangs[gangId]
    if not gang then
        return false, 'gang_not_found'
    end
    
    if not gang.members[identifier] then
        return false, 'member_not_found'
    end
    
    if not gang.ranks[newRankGrade] then
        return false, 'rank_not_found'
    end
    
    -- Cannot change owner rank (unless forced by admin command)
    if gang.owner_identifier == identifier and not forceOwnerChange then
        return false, 'cannot_change_owner_rank'
    end
    
    local newRankId = gang.ranks[newRankGrade].id
    
    MySQL.query.await([[
        UPDATE trase_gang_members SET rank_id = ? WHERE gang_id = ? AND identifier = ?
    ]], {newRankId, gangId, identifier})
    
    gang.members[identifier].rank_id = newRankId
    
    self:AddAuditLog(gangId, actorIdentifier, 'member_rank_changed', identifier, 
        'Rank changed to ' .. gang.ranks[newRankGrade].name)
    
    return true
end

-- Create/Update gang rank
function Handler:SaveRank(gangId, rankData, actorIdentifier)
    local gang = self.gangs[gangId]
    if not gang then
        return false, 'gang_not_found'
    end
    
    local permissionsJson = json.encode(rankData.permissions or {})
    
    if rankData.id then
        -- Update existing rank
        MySQL.query.await([[
            UPDATE trase_gang_ranks SET name = ?, permissions = ? WHERE id = ? AND gang_id = ?
        ]], {rankData.name, permissionsJson, rankData.id, gangId})
        
        self:AddAuditLog(gangId, actorIdentifier, 'rank_updated', nil, 'Rank updated: ' .. rankData.name)
    else
        -- Create new rank
        local rankCount = 0
        for _ in pairs(gang.ranks) do rankCount = rankCount + 1 end
        if rankCount >= gang.max_ranks then
            return false, 'max_ranks_reached'
        end
        
        -- Shift all existing ranks up by 1 grade (update in descending order to avoid duplicate key errors)
        MySQL.query.await([[
            UPDATE trase_gang_ranks 
            SET grade = grade + 1 
            WHERE gang_id = ?
            ORDER BY grade DESC
        ]], {gangId})
        
        -- Insert new rank at grade 0
        local insertId = MySQL.insert.await([[
            INSERT INTO trase_gang_ranks (gang_id, name, grade, permissions)
            VALUES (?, ?, 0, ?)
        ]], {gangId, rankData.name, permissionsJson})
        
        self:AddAuditLog(gangId, actorIdentifier, 'rank_created', nil, 'Rank created: ' .. rankData.name)
        
        -- Store the new rank ID for return
        rankData.id = insertId
    end
    
    -- Reload gangs to update cache
    self:LoadAllGangs()
    
    -- Get updated gang data and calculate member count
    gang = self.gangs[gangId]
    local memberCount = 0
    if gang then
        for _, member in pairs(gang.members) do
            if member.rank_id == rankData.id then
                memberCount = memberCount + 1
            end
        end
    end
    
    -- Return the rank data with proper structure for UI
    local updatedRank = {
        id = rankData.id,
        name = rankData.name,
        grade = 0,  -- New ranks are always inserted at grade 0
        permissions = rankData.permissions,
        memberCount = memberCount
    }
    
    return true, updatedRank
end

-- Reorder rank (swap with another rank)
function Handler:ReorderRank(gangId, rankId, direction, actorIdentifier)
    local gang = self.gangs[gangId]
    if not gang then
        return false, 'gang_not_found'
    end
    
    -- Find the rank being moved
    local currentRank = nil
    for _, rank in pairs(gang.ranks) do
        if rank.id == rankId then
            currentRank = rank
            break
        end
    end
    
    if not currentRank then
        return false, 'rank_not_found'
    end
    
    local currentGrade = currentRank.grade
    local targetGrade
    
    print('[ReorderRank] Current rank:', currentRank.name, 'grade:', currentGrade, 'direction:', direction)
    
    if direction == 'up' then
        targetGrade = currentGrade + 1
    elseif direction == 'down' then
        targetGrade = currentGrade - 1
    else
        return false, 'invalid_direction'
    end
    
    print('[ReorderRank] Looking for target grade:', targetGrade)
    
    -- Check if target grade exists
    local targetRank = nil
    for _, rank in pairs(gang.ranks) do
        print('[ReorderRank] Checking rank:', rank.name, 'grade:', rank.grade)
        if rank.grade == targetGrade then
            targetRank = rank
            break
        end
    end
    
    if not targetRank then
        print('[ReorderRank] No rank found with grade:', targetGrade)
        return false, 'no_rank_to_swap'
    end
    
    print('[ReorderRank] Swapping', currentRank.name, 'with', targetRank.name)
    
    -- Swap grades using a three-step process to avoid unique constraint violation
    -- Step 1: Set current rank to temporary negative grade
    local tempGrade = -999
    MySQL.query.await('UPDATE trase_gang_ranks SET grade = ? WHERE id = ? AND gang_id = ?', {tempGrade, rankId, gangId})
    
    -- Step 2: Set target rank to current rank's grade
    MySQL.query.await('UPDATE trase_gang_ranks SET grade = ? WHERE id = ? AND gang_id = ?', {currentGrade, targetRank.id, gangId})
    
    -- Step 3: Set current rank to target grade
    MySQL.query.await('UPDATE trase_gang_ranks SET grade = ? WHERE id = ? AND gang_id = ?', {targetGrade, rankId, gangId})
    
    self:AddAuditLog(gangId, actorIdentifier, 'rank_reordered', nil, 'Rank reordered: ' .. currentRank.name)
    
    -- Reload gangs to update cache
    self:LoadAllGangs()
    
    -- Build updated ranks list for UI
    local updatedRanks = {}
    gang = self.gangs[gangId]
    if gang then
        for _, rank in pairs(gang.ranks) do
            local memberCount = 0
            for _, member in pairs(gang.members) do
                if member.rank_id == rank.id then
                    memberCount = memberCount + 1
                end
            end
            
            table.insert(updatedRanks, {
                id = rank.id,
                name = rank.name,
                grade = rank.grade,
                permissions = rank.permissions,
                memberCount = memberCount
            })
        end
        
        table.sort(updatedRanks, function(a, b) return a.grade > b.grade end)
    end
    
    return true, updatedRanks
end

-- Delete gang rank
function Handler:DeleteRank(gangId, rankId, actorIdentifier)
    local gang = self.gangs[gangId]
    if not gang then
        return false, 'gang_not_found'
    end
    
    -- Get the grade of the rank being deleted
    local deletedGrade = nil
    for _, rank in pairs(gang.ranks) do
        if rank.id == rankId then
            deletedGrade = rank.grade
            break
        end
    end
    
    if not deletedGrade then
        return false, 'rank_not_found'
    end
    
    -- Find the rank with grade one below the deleted rank (to demote members to)
    local demoteToRankId = nil
    for _, rank in pairs(gang.ranks) do
        if rank.grade == deletedGrade - 1 then
            demoteToRankId = rank.id
            break
        end
    end
    
    -- If members have this rank, demote them to the next lower rank
    if demoteToRankId then
        MySQL.query.await([[
            UPDATE trase_gang_members 
            SET rank_id = ? 
            WHERE gang_id = ? AND rank_id = ?
        ]], {demoteToRankId, gangId, rankId})
    else
        -- If there's no lower rank, we cannot delete this rank (it's the lowest)
        local memberCount = MySQL.scalar.await('SELECT COUNT(*) FROM trase_gang_members WHERE gang_id = ? AND rank_id = ?', {gangId, rankId})
        if memberCount and memberCount > 0 then
            return false, 'no_lower_rank'
        end
    end
    
    -- Delete the rank
    MySQL.query.await('DELETE FROM trase_gang_ranks WHERE id = ? AND gang_id = ?', {rankId, gangId})
    
    -- Shift all higher grades down by 1
    MySQL.query.await([[
        UPDATE trase_gang_ranks 
        SET grade = grade - 1 
        WHERE gang_id = ? AND grade > ?
    ]], {gangId, deletedGrade})
    
    self:AddAuditLog(gangId, actorIdentifier, 'rank_deleted', nil, 'Rank deleted and members adjusted')
    
    -- Reload gangs to update cache
    self:LoadAllGangs()
    
    -- Build updated ranks list with member counts for UI
    local updatedRanks = {}
    gang = self.gangs[gangId] -- Get fresh data after reload
    if gang then
        for _, rank in pairs(gang.ranks) do
            local memberCount = 0
            for _, member in pairs(gang.members) do
                if member.rank_id == rank.id then
                    memberCount = memberCount + 1
                end
            end
            
            table.insert(updatedRanks, {
                id = rank.id,
                name = rank.name,
                grade = rank.grade,
                permissions = rank.permissions,
                memberCount = memberCount
            })
        end
        
        -- Sort by grade descending
        table.sort(updatedRanks, function(a, b) return a.grade > b.grade end)
    end
    
    return true, updatedRanks
end

-- Update gang info
function Handler:UpdateGangInfo(gangId, data, actorIdentifier)
    local gang = self.gangs[gangId]
    if not gang then
        return false, 'gang_not_found'
    end
    
    local updates = {}
    local values = {}
    
    if data.label then
        table.insert(updates, 'label = ?')
        table.insert(values, data.label)
    end
    
    if #updates == 0 then
        return false, 'no_updates'
    end
    
    table.insert(values, gangId)
    
    local query = string.format('UPDATE trase_gangs SET %s WHERE id = ?', table.concat(updates, ', '))
    MySQL.query.await(query, values)
    
    -- Update cache
    for key, value in pairs(data) do
        gang[key] = value
    end
    
    self:AddAuditLog(gangId, actorIdentifier, 'gang_updated', nil, 'Gang info updated')
    
    return true
end

-- Update gang settings (admin only)
function Handler:UpdateGangSettings(gangId, data)
    local gang = self.gangs[gangId]
    if not gang then
        return false, 'gang_not_found'
    end
    
    local updates = {}
    local values = {}
    
    if data.max_members then
        table.insert(updates, 'max_members = ?')
        table.insert(values, data.max_members)
        gang.max_members = data.max_members
    end
    
    if data.max_ranks then
        table.insert(updates, 'max_ranks = ?')
        table.insert(values, data.max_ranks)
        gang.max_ranks = data.max_ranks
    end
    
    if #updates == 0 then
        return false, 'no_updates'
    end
    
    table.insert(values, gangId)
    
    local query = string.format('UPDATE trase_gangs SET %s WHERE id = ?', table.concat(updates, ', '))
    MySQL.query.await(query, values)
    
    return true
end

-- Get player's gang
function Handler:GetPlayerGang(identifier)
    local gangId = self.playerGangs[identifier]
    if not gangId then
        return nil
    end
    
    return self.gangs[gangId]
end

-- Check if player has permission
function Handler:HasPermission(identifier, permission)
    local gang = self:GetPlayerGang(identifier)
    if not gang then
        return false
    end
    
    -- Owner has all permissions
    if gang.owner_identifier == identifier then
        return true
    end
    
    local member = gang.members[identifier]
    if not member then
        return false
    end
    
    -- Find member's rank
    local memberRank = nil
    for _, rank in pairs(gang.ranks) do
        if rank.id == member.rank_id then
            memberRank = rank
            break
        end
    end
    
    if not memberRank then
        return false
    end
    
    return memberRank.permissions[permission] == true
end

-- Add reputation to gang
function Handler:AddReputation(gangId, amount, reason)
    local gang = self.gangs[gangId]
    if not gang then
        return false
    end
    
    gang.reputation = (gang.reputation or 0) + amount
    
    MySQL.query.await('UPDATE trase_gangs SET reputation = ? WHERE id = ?', {gang.reputation, gangId})
    
    if Config.Debug then
        print('[Handler] Added ' .. amount .. ' reputation to gang ' .. gangId .. ' (' .. reason .. ')')
    end
    
    return true
end

-- Add revenue to gang
function Handler:AddRevenue(gangId, amount)
    local gang = self.gangs[gangId]
    if not gang then
        return false
    end
    
    gang.total_revenue = (gang.total_revenue or 0) + amount
    gang.bank = (gang.bank or 0) + amount
    
    MySQL.query.await([[
        UPDATE trase_gangs SET total_revenue = ?, bank = ? WHERE id = ?
    ]], {gang.total_revenue, gang.bank, gangId})
    
    return true
end

-- Update gang stats
function Handler:UpdateGangStats(gangId, statType, increment)
    local gang = self.gangs[gangId]
    if not gang then
        return false
    end
    
    if not gang.stats[statType] then
        gang.stats[statType] = 0
    end
    
    gang.stats[statType] = gang.stats[statType] + (increment or 1)
    
    MySQL.query.await(
        string.format('UPDATE trase_gang_stats SET %s = ? WHERE gang_id = ?', statType),
        {gang.stats[statType], gangId}
    )
    
    return true
end

-- Update member stats
function Handler:UpdateMemberStats(gangId, identifier, statType, increment)
    MySQL.query.await(
        string.format('UPDATE trase_gang_member_stats SET %s = %s + ? WHERE gang_id = ? AND identifier = ?', statType, statType),
        {increment or 1, gangId, identifier}
    )
    
    return true
end

-- Get member stats
function Handler:GetMemberStats(gangId, identifier)
    local stats = MySQL.single.await([[
        SELECT * FROM trase_gang_member_stats WHERE gang_id = ? AND identifier = ?
    ]], {gangId, identifier})
    
    return stats
end

-- Add audit log entry
function Handler:AddAuditLog(gangId, actorIdentifier, action, targetIdentifier, details)
    MySQL.insert.await([[
        INSERT INTO trase_gang_audit_log (gang_id, actor_identifier, action, target_identifier, details)
        VALUES (?, ?, ?, ?, ?)
    ]], {gangId, actorIdentifier, action, targetIdentifier or '', details or ''})
end

-- Get audit logs
function Handler:GetAuditLogs(gangId, limit)
    limit = limit or 50
    
    local logs = MySQL.query.await([[
        SELECT * FROM trase_gang_audit_log WHERE gang_id = ? ORDER BY created_at DESC LIMIT ?
    ]], {gangId, limit})
    
    return logs
end

-- Get all gangs (for leaderboards, etc)
function Handler:GetAllGangs()
    return self.gangs
end

-- Create gang invite
function Handler:CreateInvite(gangId, inviterIdentifier, inviteeIdentifier)
    local gang = self.gangs[gangId]
    if not gang then
        return false, 'gang_not_found'
    end
    
    -- Check if player already in gang
    if self.playerGangs[inviteeIdentifier] then
        return false, 'already_in_gang'
    end
    
    -- Check for existing pending invite
    local existing = MySQL.single.await([[
        SELECT id FROM trase_gang_invites 
        WHERE gang_id = ? AND invitee_identifier = ? AND status = 'pending'
    ]], {gangId, inviteeIdentifier})
    
    if existing then
        return false, 'invite_already_sent'
    end
    
    local expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + (Config.Handler.InviteExpiryTime or 3600))
    
    MySQL.insert.await([[
        INSERT INTO trase_gang_invites (gang_id, inviter_identifier, invitee_identifier, expires_at)
        VALUES (?, ?, ?, ?)
    ]], {gangId, inviterIdentifier, inviteeIdentifier, expiresAt})
    
    self:AddAuditLog(gangId, inviterIdentifier, 'invite_sent', inviteeIdentifier, 'Gang invite sent')
    
    return true
end

-- Accept gang invite
function Handler:AcceptInvite(inviteId, inviteeIdentifier)
    local invite = MySQL.single.await([[
        SELECT * FROM trase_gang_invites WHERE id = ? AND invitee_identifier = ? AND status = 'pending'
    ]], {inviteId, inviteeIdentifier})
    
    if not invite then
        return false, 'invite_not_found'
    end
    
    -- Check if expired
    local expiresAt = os.time({
        year = string.sub(invite.expires_at, 1, 4),
        month = string.sub(invite.expires_at, 6, 7),
        day = string.sub(invite.expires_at, 9, 10),
        hour = string.sub(invite.expires_at, 12, 13),
        min = string.sub(invite.expires_at, 15, 16),
        sec = string.sub(invite.expires_at, 18, 19)
    })
    
    if os.time() > expiresAt then
        MySQL.query.await('UPDATE trase_gang_invites SET status = "declined" WHERE id = ?', {inviteId})
        return false, 'invite_expired'
    end
    
    -- Add member to gang
    local success, err = self:AddMember(invite.gang_id, inviteeIdentifier, 0, invite.inviter_identifier, true)
    if not success then
        return false, err
    end
    
    -- Update invite status
    MySQL.query.await('UPDATE trase_gang_invites SET status = "accepted" WHERE id = ?', {inviteId})
    
    self:AddAuditLog(invite.gang_id, inviteeIdentifier, 'invite_accepted', inviteeIdentifier, 'Member accepted invite')
    
    return true
end

-- Decline gang invite
function Handler:DeclineInvite(inviteId, inviteeIdentifier)
    MySQL.query.await([[
        UPDATE trase_gang_invites SET status = 'declined' 
        WHERE id = ? AND invitee_identifier = ?
    ]], {inviteId, inviteeIdentifier})
    
    return true
end

-- Get player's pending invites
function Handler:GetPlayerInvites(identifier)
    local invites = MySQL.query.await([[
        SELECT i.*, g.label as gang_label
        FROM trase_gang_invites i
        JOIN trase_gangs g ON i.gang_id = g.id
        WHERE i.invitee_identifier = ? AND i.status = 'pending'
        ORDER BY i.created_at DESC
    ]], {identifier})
    
    return invites
end

-- Initialize on resource start
CreateThread(function()
    Wait(1000) -- Wait for database to be ready
    Handler:Init()
end)

-- Callbacks
lib.callback.register('trase_gangs:server:getPlayerGang', function(source)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return nil end
    
    return Handler:GetPlayerGang(xPlayer.identifier)
end)

lib.callback.register('trase_gangs:server:hasPermission', function(source, permission)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return false end
    
    return Handler:HasPermission(xPlayer.identifier, permission)
end)

-- Admin callbacks
lib.callback.register('trase_gangs:server:admin:createGang', function(source, data)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return false, 'player_not_found' end
    
    if not IsAdmin(source) then
        return false, 'no_permission'
    end
    
    local targetServerId = tonumber(data.owner)
    if not targetServerId then
        return false, 'invalid_server_id'
    end
    
    local targetPlayer = GetPlayerFromId(targetServerId)
    if not targetPlayer then
        return false, 'player_not_online'
    end
    
    data.owner = targetPlayer.identifier
    
    return Handler:CreateGang(data)
end)

lib.callback.register('trase_gangs:server:admin:deleteGang', function(source, gangId)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return false, 'player_not_found' end
    
    if not IsAdmin(source) then
        return false, 'no_permission'
    end
    
    return Handler:DeleteGang(gangId, xPlayer.identifier)
end)

lib.callback.register('trase_gangs:server:admin:updateGangSettings', function(source, gangId, data)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return false, 'player_not_found' end
    
    if not IsAdmin(source) then
        return false, 'no_permission'
    end
    
    return Handler:UpdateGangSettings(gangId, data)
end)

lib.callback.register('trase_gangs:server:admin:getAllGangs', function(source)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then 
        print('[Server] getAllGangs: xPlayer is nil for source', source)
        return {} 
    end
    
    if not IsAdmin(source) then
        print('[Server] getAllGangs: Player', source, 'is not admin')
        return {}
    end
    
    print('[Server] getAllGangs: Admin check passed for source', source)
    
    local allGangs = Handler:GetAllGangs()
    
    -- Count gangs properly (it's a dictionary, not array)
    local gangCount = 0
    for _ in pairs(allGangs) do gangCount = gangCount + 1 end
    print('[Server] getAllGangs: Retrieved', gangCount, 'gangs from cache')
    
    local formattedGangs = {}
    
    for gangId, gang in pairs(allGangs) do
        local memberCount = 0
        local rankCount = 0
        
        for _ in pairs(gang.members) do memberCount = memberCount + 1 end
        for _ in pairs(gang.ranks) do rankCount = rankCount + 1 end
        
        local ownerName = "Unknown"
        local ownerPlayer = GetPlayerFromIdentifier(gang.owner_identifier)
        if ownerPlayer then
            ownerName = ownerPlayer.getName()
        end
        
        local membersList = {}
        for identifier, member in pairs(gang.members) do
            local memberRank = nil
            for _, rank in pairs(gang.ranks) do
                if rank.id == member.rank_id then
                    memberRank = rank
                    break
                end
            end
            
            local memberPlayer = GetPlayerFromIdentifier(identifier)
            local isOnline = memberPlayer ~= nil
            -- Use saved name from DB if available, otherwise get from player or use identifier
            local memberName = member.name or (isOnline and memberPlayer.getName()) or identifier
            
            -- Update name in DB if player is online and name is different
            if isOnline and memberPlayer.getName() ~= member.name then
                MySQL.query.await('UPDATE trase_gang_members SET name = ? WHERE gang_id = ? AND identifier = ?', {memberPlayer.getName(), gang.id, identifier})
                member.name = memberPlayer.getName()
                memberName = memberPlayer.getName()
            end
            
            table.insert(membersList, {
                name = memberName,
                identifier = identifier,
                rank = memberRank and memberRank.name or "Unknown",
                online = isOnline,
                joined = member.joined_at
            })
        end
        
        local ranksList = {}
        for grade, rank in pairs(gang.ranks) do
            local rankMemberCount = 0
            for _, member in pairs(gang.members) do
                if member.rank_id == rank.id then
                    rankMemberCount = rankMemberCount + 1
                end
            end
            
            local permissions = {}
            if rank.permissions then
                for perm, enabled in pairs(rank.permissions) do
                    if enabled then
                        table.insert(permissions, perm)
                    end
                end
            end
            
            if #permissions == 0 then
                permissions = {"None"}
            end
            
            table.insert(ranksList, {
                name = rank.name,
                grade = rank.grade,
                members = rankMemberCount,
                permissions = permissions
            })
        end
        
        table.sort(ranksList, function(a, b) return a.grade > b.grade end)
        
        table.insert(formattedGangs, {
            id = gangId,
            name = gang.name,
            label = gang.label,
            owner = ownerName,
            owner_identifier = gang.owner_identifier,
            members = memberCount,
            ranks = rankCount,
            created = gang.created_at,
            membersList = membersList,
            ranksList = ranksList
        })
    end
    
    print('[Server] getAllGangs: Returning', #formattedGangs, 'formatted gangs')
    if #formattedGangs > 0 then
        print('[Server] First gang:', json.encode(formattedGangs[1]))
    end
    
    return formattedGangs
end)

lib.callback.register('trase_gangs:server:getGangDataForUI', function(source)
    print('[Server] getGangDataForUI called for source:', source)
    local identifier = GetPrimaryIdentifier(source)
    print('[Server] getGangDataForUI identifier:', identifier)
    if not identifier then 
        print('[Server] getGangDataForUI: No identifier found')
        return nil 
    end
    
    -- Reload gang data from database to get fresh data
    local gangId = Handler.playerGangs[identifier]
    if gangId then
        print('[Server] getGangDataForUI: Reloading all gangs cache')
        Handler:LoadAllGangs()
    end
    
    local gang = Handler:GetPlayerGang(identifier)
    print('[Server] getGangDataForUI gang:', gang and gang.name or 'nil')
    if gang then
        print('[Server] getGangDataForUI: Gang has', gang.ranks and #gang.ranks or 0, 'ranks in cache')
    end
    if not gang then 
        print('[Server] getGangDataForUI: No gang found for identifier:', identifier)
        return nil 
    end
    
    local isOwner = gang.owner_identifier == identifier
    local hasPermission = isOwner or Handler:HasPermission(identifier, 'manage_ranks')
    
    local membersList = {}
    for memberIdentifier, member in pairs(gang.members) do
        -- Find the rank for this member
        local memberRank = nil
        for _, rank in pairs(gang.ranks) do
            if rank.id == member.rank_id then
                memberRank = rank
                break
            end
        end
        
        local isOnline = false
        for _, playerId in ipairs(GetPlayers()) do
            local playerIdentifier = GetPrimaryIdentifier(playerId)
            if playerIdentifier == memberIdentifier then
                isOnline = true
                break
            end
        end
        
        -- Use saved name from DB, or identifier as fallback
        local memberName = member.name or memberIdentifier
        
        print('[getGangDataForUI] Member:', memberIdentifier, 'name from DB:', member.name, 'final name:', memberName)
        
        table.insert(membersList, {
            identifier = memberIdentifier,
            name = memberName,
            rank = memberRank and memberRank.name or 'Unknown',
            rankGrade = memberRank and memberRank.grade or 0,
            online = isOnline,
            joined = member.joined_at
        })
    end
    
    local ranksList = {}
    for grade, rank in pairs(gang.ranks) do
        local rankMemberCount = 0
        for _, member in pairs(gang.members) do
            if member.rank_id == rank.id then
                rankMemberCount = rankMemberCount + 1
            end
        end
        
        table.insert(ranksList, {
            id = rank.id,
            name = rank.name,
            grade = rank.grade,
            members = rankMemberCount,
            permissions = rank.permissions or {}
        })
    end
    
    table.sort(ranksList, function(a, b) return a.grade > b.grade end)
    
    print('[getGangDataForUI] Sending', #membersList, 'members to UI')
    for i, m in ipairs(membersList) do
        print('[getGangDataForUI] Member', i, ':', m.identifier, 'name:', m.name)
    end
    
    return {
        gang = {
            id = gang.id,
            name = gang.name,
            label = gang.label,
            owner_identifier = gang.owner_identifier,
            max_members = gang.max_members,
            max_ranks = gang.max_ranks,
            bank = gang.bank or 0,
            reputation = gang.reputation or 0,
            total_revenue = gang.total_revenue or 0,
            created_at = gang.created_at
        },
        members = membersList,
        ranks = ranksList,
        stats = gang.stats or {},
        isOwner = isOwner,
        hasManagePermission = hasPermission,
        playerIdentifier = identifier
    }
end)

-- Member management callbacks
lib.callback.register('trase_gangs:server:inviteMember', function(source, targetServerId)
    local xPlayer = GetPlayerFromId(source)
    local targetPlayer = GetPlayerFromId(targetServerId)

    print('[Server] inviteMember called by source:', source, 'targetServerId:', targetServerId)
    
    if not xPlayer or not targetPlayer then
        return false, 'player_not_found'
    end
    
    if not Handler:HasPermission(xPlayer.identifier, 'invite_members') then
        return false, 'no_permission'
    end
    
    local gang = Handler:GetPlayerGang(xPlayer.identifier)
    if not gang then
        return false, 'not_in_gang'
    end
    
    local success, err = Handler:CreateInvite(gang.id, xPlayer.identifier, targetPlayer.identifier)
    
    if success then
        TriggerClientEvent('trase_gangs:client:inviteReceived', targetServerId, {
            gang_id = gang.id,
            gang_label = gang.label,
            inviter_name = xPlayer.getName()
        })
    end
    
    return success, err
end)

lib.callback.register('trase_gangs:server:kickMember', function(source, identifier)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return false, 'player_not_found' end
    
    if not Handler:HasPermission(xPlayer.identifier, 'kick_members') then
        return false, 'no_permission'
    end
    
    local gang = Handler:GetPlayerGang(xPlayer.identifier)
    if not gang then
        return false, 'not_in_gang'
    end
    
    local success, err = Handler:RemoveMember(gang.id, identifier, xPlayer.identifier)
    
    if success then
        local targetPlayer = GetPlayerFromIdentifier(identifier)
        if targetPlayer then
            TriggerClientEvent('trase_gangs:client:gangRemoved', targetPlayer.source)
        end
    end
    
    return success, err
end)

lib.callback.register('trase_gangs:server:setMemberRank', function(source, identifier, rankGrade)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return false, 'player_not_found' end
    
    if not Handler:HasPermission(xPlayer.identifier, 'promote_members') then
        return false, 'no_permission'
    end
    
    local gang = Handler:GetPlayerGang(xPlayer.identifier)
    if not gang then
        return false, 'not_in_gang'
    end
    
    local success, err = Handler:SetMemberRank(gang.id, identifier, rankGrade, xPlayer.identifier)
    
    if success then
        local targetPlayer = GetPlayerFromIdentifier(identifier)
        if targetPlayer then
            local updatedGang = Handler:GetPlayerGang(identifier)
            TriggerClientEvent('trase_gangs:client:gangUpdated', targetPlayer.source, updatedGang)
        end
    end
    
    return success, err
end)

-- Gang info management
lib.callback.register('trase_gangs:server:updateGangInfo', function(source, data)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return false, 'player_not_found' end
    
    local gang = Handler:GetPlayerGang(xPlayer.identifier)
    if not gang then
        return false, 'not_in_gang'
    end
    
    if gang.owner_identifier ~= xPlayer.identifier then
        return false, 'no_permission'
    end
    
    return Handler:UpdateGangInfo(gang.id, data, xPlayer.identifier)
end)

lib.callback.register('trase_gangs:server:saveRank', function(source, rankData)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return false, 'player_not_found' end
    
    if not Handler:HasPermission(xPlayer.identifier, 'manage_ranks') then
        return false, 'no_permission'
    end
    
    local gang = Handler:GetPlayerGang(xPlayer.identifier)
    if not gang then
        return false, 'not_in_gang'
    end
    
    return Handler:SaveRank(gang.id, rankData, xPlayer.identifier)
end)

lib.callback.register('trase_gangs:server:deleteRank', function(source, rankId)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return false, 'player_not_found' end
    
    if not Handler:HasPermission(xPlayer.identifier, 'manage_ranks') then
        return false, 'no_permission'
    end
    
    local gang = Handler:GetPlayerGang(xPlayer.identifier)
    if not gang then
        return false, 'not_in_gang'
    end
    
    return Handler:DeleteRank(gang.id, rankId, xPlayer.identifier)
end)

lib.callback.register('trase_gangs:server:reorderRank', function(source, rankId, direction)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return {success = false, result = 'player_not_found'} end
    
    local gang = Handler:GetPlayerGang(xPlayer.identifier)
    if not gang then return {success = false, result = 'not_in_gang'} end
    
    local isOwner = gang.owner_identifier == xPlayer.identifier
    local hasPermission = Handler:HasPermission(xPlayer.identifier, 'manage_ranks')
    if not isOwner and not hasPermission then
        return {success = false, result = 'no_permission'}
    end
    
    local success, result = Handler:ReorderRank(gang.id, rankId, direction, xPlayer.identifier)
    return {success = success, result = result, updatedRanks = result}
end)

lib.callback.register('trase_gangs:server:getMemberStats', function(source, identifier)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return nil end
    
    local gang = Handler:GetPlayerGang(xPlayer.identifier)
    if not gang then return nil end
    
    return Handler:GetMemberStats(gang.id, identifier)
end)

lib.callback.register('trase_gangs:server:getAuditLogs', function(source, limit)
    local xPlayer = GetPlayerFromId(source)
    print('[getAuditLogs] Player:', xPlayer and xPlayer.identifier or 'nil')
    if not xPlayer then 
        print('[getAuditLogs] No xPlayer, returning empty')
        return {} 
    end
    
    local gang = Handler:GetPlayerGang(xPlayer.identifier)
    print('[getAuditLogs] Gang:', gang and gang.name or 'nil', 'id:', gang and gang.id or 'nil')
    if not gang then 
        print('[getAuditLogs] No gang, returning empty')
        return {} 
    end
    
    local logs = Handler:GetAuditLogs(gang.id, limit)
    print('[getAuditLogs] Returning', logs and #logs or 0, 'logs')
    if logs and #logs > 0 then
        print('[getAuditLogs] First log:', json.encode(logs[1]))
    end
    return logs or {}
end)

lib.callback.register('trase_gangs:server:acceptInvite', function(source, inviteId)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return false, 'player_not_found' end
    
    local success, err = Handler:AcceptInvite(inviteId, xPlayer.identifier)
    
    if success then
        local gang = Handler:GetPlayerGang(xPlayer.identifier)
        TriggerClientEvent('trase_gangs:client:gangUpdated', source, gang)
    end
    
    return success, err
end)

lib.callback.register('trase_gangs:server:declineInvite', function(source, inviteId)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return false end
    
    return Handler:DeclineInvite(inviteId, xPlayer.identifier)
end)

lib.callback.register('trase_gangs:server:getPendingInvites', function(source)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return {} end
    
    return Handler:GetPlayerInvites(xPlayer.identifier)
end)

lib.callback.register('trase_gangs:server:leaveGang', function(source)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return false, 'player_not_found' end
    
    local gang = Handler:GetPlayerGang(xPlayer.identifier)
    if not gang then
        return false, 'not_in_gang'
    end
    
    if gang.owner_identifier == xPlayer.identifier then
        return false, 'owner_cannot_leave'
    end
    
    local success, err = Handler:RemoveMember(gang.id, xPlayer.identifier, xPlayer.identifier)
    
    if success then
        TriggerClientEvent('trase_gangs:client:gangRemoved', source)
    end
    
    return success, err
end)

lib.callback.register('trase_gangs:server:getOnlineMembers', function(source)
    local xPlayer = GetPlayerFromId(source)
    if not xPlayer then return {} end
    
    local gang = Handler:GetPlayerGang(xPlayer.identifier)
    if not gang then return {} end
    
    local onlineMembers = {}
    for identifier, _ in pairs(gang.members) do
        local targetPlayer = GetPlayerFromIdentifier(identifier)
        if targetPlayer then
            table.insert(onlineMembers, {
                identifier = identifier,
                name = targetPlayer.getName(),
                source = targetPlayer.source
            })
        end
    end
    
    return onlineMembers
end)

-- Leaderboards
lib.callback.register('trase_gangs:server:getLeaderboard', function(source, category)
    local gangs = Handler:GetAllGangs()
    local leaderboard = {}
    
    for gangId, gang in pairs(gangs) do
        local memberCount = 0
        for _ in pairs(gang.members) do memberCount = memberCount + 1 end
        
        local wins = 0
        if category == 'turfs' then
            wins = gang.stats.turf_wins or 0
        elseif category == 'drugzones' then
            wins = gang.stats.drugzone_wins or 0
        elseif category == 'gangwars' then
            wins = gang.stats.gangwar_wins or 0
        end
        
        table.insert(leaderboard, {
            id = gangId,
            name = gang.label,
            reputation = gang.reputation or 0,
            wins = wins,
            members = memberCount
        })
    end
    
    -- Sort by wins
    table.sort(leaderboard, function(a, b)
        return a.wins > b.wins
    end)
    
    return leaderboard
end)

-- Combined leaderboards callback (fetch all categories at once)
lib.callback.register('trase_gangs:server:getLeaderboards', function(source, opts)
    local gangs = Handler:GetAllGangs()
    local maxEntries = (opts and opts.limit) or 25

    local function build(sortKey)
        local list = {}
        for gangId, gang in pairs(gangs) do
            local memberCount = 0
            for _ in pairs(gang.members) do memberCount = memberCount + 1 end

            local wins = 0
            if sortKey == 'drugzones' then
                wins = gang.stats and (gang.stats.drugzone_wins or 0) or 0
            elseif sortKey == 'turfs' then
                wins = gang.stats and (gang.stats.turf_wins or 0) or 0
            elseif sortKey == 'gangwars' then
                wins = gang.stats and (gang.stats.gangwar_wins or 0) or 0
            end

            table.insert(list, {
                id = gangId,
                name = gang.label,
                reputation = gang.reputation or 0,
                wins = wins,
                members = memberCount
            })
        end

        table.sort(list, function(a, b)
            return a.wins > b.wins
        end)

        local out = {}
        local count = 0
        for i = 1, #list do
            out[#out+1] = list[i]
            count = count + 1
            if count >= maxEntries then break end
        end
        return out
    end

    -- Reputation leaderboard
    local reputation = {}
    for gangId, gang in pairs(gangs) do
        local memberCount = 0
        for _ in pairs(gang.members) do memberCount = memberCount + 1 end
        table.insert(reputation, {
            id = gangId,
            name = gang.label,
            reputation = gang.reputation or 0,
            wins = 0,
            members = memberCount
        })
    end
    table.sort(reputation, function(a, b)
        return a.reputation > b.reputation
    end)
    local repOut = {}
    for i = 1, math.min(#reputation, maxEntries) do repOut[i] = reputation[i] end

    return {
        drugzones = build('drugzones'),
        turfs = build('turfs'),
        gangwars = build('gangwars'),
        reputation = repOut
    }
end)

-- Command to open leaderboards UI for any player
RegisterCommand(Config.Commands.GangLeaderboard, function(source)
    if source == 0 then return end
    TriggerClientEvent('trase_gangs:client:openLeaderboard', source)
end, false)

-- Exports
exports('GetHandler', function()
    return Handler
end)

-- Helper: get primary identifier (license preferred)
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

-- When a player loads in, set their replicated state with gang info
RegisterNetEvent('trase_gangs:server:playerReady', function()
    local src = source
    local identifier = GetPrimaryIdentifier(src)
    if not identifier then return end

    local gang = Handler:GetPlayerGang(identifier)
    local ply = Player(src)
    if ply and ply.state then
        ply.state.gang = gang or nil
    end
end)

RegisterCommand(Config.Commands.GangManage, function(source)
    if source == 0 then return end

    local identifier = GetPrimaryIdentifier(source)
    if not identifier then 
        print('[GangManage] Could not get identifier for source', source)
        return 
    end

    print('[GangManage] Player identifier:', identifier)
    
    -- Debug: Show what's in playerGangs cache
    print('[GangManage] playerGangs cache has', Handler.playerGangs[identifier] and 'FOUND' or 'NOT FOUND', 'for this identifier')
    if Handler.playerGangs[identifier] then
        print('[GangManage] Cached gang ID:', Handler.playerGangs[identifier])
    end
    
    -- Debug: Show all cached identifiers
    local cacheCount = 0
    for cachedIdentifier, gangId in pairs(Handler.playerGangs) do
        cacheCount = cacheCount + 1
        print('[GangManage] Cache entry:', cachedIdentifier, '-> Gang', gangId)
    end
    print('[GangManage] Total entries in playerGangs cache:', cacheCount)
    
    local gang = Handler:GetPlayerGang(identifier)
    
    if not gang then
        print('[GangManage] Player not in a gang')
        SendNotification(source, {
            title = 'Gang Manager',
            description = 'You are not in a gang',
            type = 'error'
        })
        return
    end

    print('[GangManage] Player in gang:', gang.name, 'Owner:', gang.owner_identifier)
    
    -- Check if owner OR has manage_members permission
    local isOwner = gang.owner_identifier == identifier
    local hasPermission = Handler:HasPermission(identifier, 'manage_members')
    
    print('[GangManage] Is Owner:', isOwner, 'Has Permission:', hasPermission)
    
    if isOwner or hasPermission then
        print('[GangManage] Opening dashboard for player')
        
        -- Prepare gang data with all members, ranks, stats, etc.
        local membersList = {}
        for memberIdentifier, member in pairs(gang.members) do
            local memberRank = nil
            for _, rank in pairs(gang.ranks) do
                if rank.id == member.rank_id then
                    memberRank = rank
                    break
                end
            end
            
            local memberPlayer = GetPlayerFromIdentifier(memberIdentifier)
            local isOnline = memberPlayer ~= nil
            local memberName = isOnline and memberPlayer.getName() or member.name or memberIdentifier
            
            table.insert(membersList, {
                name = memberName,
                identifier = memberIdentifier,
                rank = memberRank and memberRank.name or "Unknown",
                rankGrade = memberRank and memberRank.grade or 0,
                online = isOnline,
                joined = member.joined_at
            })
        end
        
        local ranksList = {}
        for grade, rank in pairs(gang.ranks) do
            local rankMemberCount = 0
            for _, member in pairs(gang.members) do
                if member.rank_id == rank.id then
                    rankMemberCount = rankMemberCount + 1
                end
            end
            
            table.insert(ranksList, {
                id = rank.id,
                name = rank.name,
                grade = rank.grade,
                members = rankMemberCount,
                permissions = rank.permissions or {}
            })
        end
        
        table.sort(ranksList, function(a, b) return a.grade > b.grade end)
        
        local dashboardData = {
            gang = {
                id = gang.id,
                name = gang.name,
                label = gang.label,
                owner_identifier = gang.owner_identifier,
                max_members = gang.max_members,
                max_ranks = gang.max_ranks,
                bank = gang.bank or 0,
                reputation = gang.reputation or 0,
                total_revenue = gang.total_revenue or 0,
                created_at = gang.created_at
            },
            members = membersList,
            ranks = ranksList,
            stats = gang.stats or {},
            isOwner = isOwner,
            hasManagePermission = hasPermission,
            playerIdentifier = identifier
        }
        
        TriggerClientEvent('trase_gangs:client:openDashboard', source, dashboardData)
    else
        print('[GangManage] Player does not have permission')
        SendNotification(source, {
            title = 'Gang Manager',
            description = 'You do not have permission to manage the gang',
            type = 'error'
        })
    end
end, false)

RegisterCommand(Config.Commands.ServerManagement, function(source)
    if source == 0 then return end

    if not IsAdmin(source) then
        SendNotification(source, {
            title = 'Server Management',
            description = 'You do not have permission to use this command',
            type = 'error'
        })
        return
    end

    TriggerClientEvent('trase_gangs:client:openServerManagement', source)
end, false)

RegisterCommand('setgang', function(source, args)
    if source == 0 then return end
    
    -- Check if admin
    if not IsAdmin(source) then
        SendNotification(source, {
            title = 'Set Gang',
            description = 'You do not have permission to use this command',
            type = 'error'
        })
        return
    end
    
    -- Check arguments
    if #args < 3 then
        SendNotification(source, {
            title = 'Set Gang',
            description = 'Usage: /setgang [player id] [gang name] [rank grade]',
            type = 'info'
        })
        return
    end
    
    local targetId = tonumber(args[1])
    local gangName = args[2]
    local rankGrade = tonumber(args[3])
    
    if not targetId or not rankGrade then
        SendNotification(source, {
            title = 'Set Gang',
            description = 'Invalid player ID or rank grade',
            type = 'error'
        })
        return
    end
    
    -- Get target player
    local targetPlayer = GetPlayerFromId(targetId)
    if not targetPlayer then
        SendNotification(source, {
            title = 'Set Gang',
            description = 'Player not found or not online',
            type = 'error'
        })
        return
    end
    
    local targetIdentifier = GetPlayerIdentifier(targetId)
    if not targetIdentifier then
        SendNotification(source, {
            title = 'Set Gang',
            description = 'Could not get player identifier',
            type = 'error'
        })
        return
    end
    
    -- Find gang by name
    local targetGang = nil
    local targetGangId = nil
    for gangId, gang in pairs(Handler.gangs) do
        if gang.name:lower() == gangName:lower() then
            targetGang = gang
            targetGangId = gangId
            break
        end
    end
    
    if not targetGang then
        SendNotification(source, {
            title = 'Set Gang',
            description = 'Gang "' .. gangName .. '" not found',
            type = 'error'
        })
        return
    end
    
    -- Check if rank exists
    if not targetGang.ranks[rankGrade] then
        SendNotification(source, {
            title = 'Set Gang',
            description = 'Rank grade ' .. rankGrade .. ' does not exist in this gang',
            type = 'error'
        })
        return
    end
    
    -- Check if trying to set as owner (grade 4) but gang already has different owner
    if rankGrade == 4 and targetGang.owner_identifier ~= targetIdentifier then
        SendNotification(source, {
            title = 'Set Gang',
            description = 'This gang already has an owner. Remove the current owner first.',
            type = 'error'
        })
        return
    end
    
    -- Check if player is already in a gang
    if Handler.playerGangs[targetIdentifier] then
        local currentGangId = Handler.playerGangs[targetIdentifier]
        local currentGang = Handler.gangs[currentGangId]
        
        -- If already in the same gang, just update rank
        if currentGangId == targetGangId then
            -- If setting as owner (grade 4), update the gang's owner_identifier first
            if rankGrade == 4 then
                MySQL.update.await('UPDATE trase_gangs SET owner_identifier = ? WHERE id = ?', {
                    targetIdentifier,
                    targetGangId
                })
                targetGang.owner_identifier = targetIdentifier
            end
            
            local success, result = Handler:SetMemberRank(targetGangId, targetIdentifier, rankGrade, targetIdentifier, true)
            if success then
                -- Reload all gangs to refresh cache
                Handler:LoadAllGangs()
                
                -- Update player state with fresh data
                local ply = Player(targetId)
                if ply and ply.state then
                    ply.state.gang = Handler:GetPlayerGang(targetIdentifier)
                end
                
                SendNotification(source, {
                    title = 'Set Gang',
                    description = 'Updated ' .. GetPlayerName(targetId) .. ' rank to grade ' .. rankGrade,
                    type = 'success'
                })
            else
                SendNotification(source, {
                    title = 'Set Gang',
                    description = 'Failed to update rank: ' .. (result or 'unknown error'),
                    type = 'error'
                })
            end
            return
        end
        
        -- Remove from current gang first
        Handler:RemoveMember(currentGangId, targetIdentifier, targetIdentifier)
    end
    
    -- Add to new gang
    local success, result = Handler:AddMember(targetGangId, targetIdentifier, rankGrade, targetIdentifier, true)
    
    if success then
        -- If setting as owner (grade 4), update the gang's owner_identifier
        if rankGrade == 4 then
            MySQL.update.await('UPDATE trase_gangs SET owner_identifier = ? WHERE id = ?', {
                targetIdentifier,
                targetGangId
            })
            targetGang.owner_identifier = targetIdentifier
        end
        
        -- Reload all gangs to refresh cache
        Handler:LoadAllGangs()
        
        -- Update player state with fresh data
        local ply = Player(targetId)
        if ply and ply.state then
            ply.state.gang = Handler:GetPlayerGang(targetIdentifier)
        end
        
        -- Notify admin
        SendNotification(source, {
            title = 'Set Gang',
            description = 'Added ' .. GetPlayerName(targetId) .. ' to gang "' .. targetGang.label .. '" with rank grade ' .. rankGrade,
            type = 'success'
        })
        
        -- Notify target player
        SendNotification(targetId, {
            title = 'Gang Assignment',
            description = 'You have been added to gang "' .. targetGang.label .. '"',
            type = 'success'
        })
    else
        SendNotification(source, {
            title = 'Set Gang',
            description = 'Failed to add player to gang: ' .. (result or 'unknown error'),
            type = 'error'
        })
    end
end, false)

-- Gang War Callbacks

lib.callback.register('trase_gangs:server:getGangWarData', function(source)
    local identifier = GetPrimaryIdentifier(source)
    if not identifier then return nil end
    
    local gang = Handler:GetPlayerGang(identifier)
    if not gang then return nil end
    
    -- Get all gangs except current gang
    local gangs = {}
    local result = MySQL.query.await('SELECT id, label as name, (SELECT COUNT(*) FROM trase_gang_members WHERE gang_id = trase_gangs.id) as memberCount FROM trase_gangs WHERE id != ?', {gang.id})
    if result then
        for _, g in ipairs(result) do
            table.insert(gangs, {
                id = g.id,
                name = g.name,
                memberCount = g.memberCount or 0
            })
        end
    end
    
    -- Get war history for this gang
    local history = {}
    local historyResult = MySQL.query.await([[
        SELECT 
            h.id,
            h.gang_1_score,
            h.gang_2_score,
            h.wager_amount,
            h.winner_gang_id,
            h.ended_at,
            CASE WHEN h.gang_1_id = ? THEN g2.label ELSE g1.label END as opponentGang,
            CASE WHEN h.gang_1_id = ? THEN h.gang_1_score ELSE h.gang_2_score END as myScore,
            CASE WHEN h.gang_1_id = ? THEN h.gang_2_score ELSE h.gang_1_score END as opponentScore
        FROM trase_gang_war_history h
        JOIN trase_gangs g1 ON h.gang_1_id = g1.id
        JOIN trase_gangs g2 ON h.gang_2_id = g2.id
        WHERE (h.gang_1_id = ? OR h.gang_2_id = ?) AND h.status = 'completed'
        ORDER BY h.ended_at DESC
        LIMIT 50
    ]], {gang.id, gang.id, gang.id, gang.id, gang.id})
    
    if historyResult then
        for _, war in ipairs(historyResult) do
            table.insert(history, {
                id = war.id,
                opponentGang = war.opponentGang,
                result = (war.winner_gang_id == gang.id) and 'win' or 'loss',
                kills = war.myScore,
                deaths = war.opponentScore,
                wager = war.wager_amount,
                date = war.ended_at
            })
        end
    end
    
    -- Get incoming war requests
    local requests = {}
    local requestsResult = MySQL.query.await([[
        SELECT 
            r.id,
            r.wager_amount,
            r.created_at,
            g.label as fromGang
        FROM trase_gang_war_requests r
        JOIN trase_gangs g ON r.challenger_gang_id = g.id
        WHERE r.target_gang_id = ? AND r.status = 'pending' AND r.expires_at > NOW()
        ORDER BY r.created_at DESC
    ]], {gang.id})
    
    if requestsResult then
        for _, req in ipairs(requestsResult) do
            table.insert(requests, {
                id = req.id,
                fromGang = req.fromGang,
                killsToWin = 25, -- Default value, can be added to DB later
                wager = req.wager_amount,
                sentAt = req.created_at
            })
        end
    end
    
    -- Get outgoing war requests (requests sent by this gang)
    local outgoing = {}
    local outgoingResult = MySQL.query.await([[
        SELECT 
            r.id,
            r.target_gang_id,
            r.wager_amount,
            r.created_at,
            g.label as toGang
        FROM trase_gang_war_requests r
        JOIN trase_gangs g ON r.target_gang_id = g.id
        WHERE r.challenger_gang_id = ? AND r.status = 'pending' AND r.expires_at > NOW()
        ORDER BY r.created_at DESC
    ]], {gang.id})
    
    if outgoingResult then
        for _, req in ipairs(outgoingResult) do
            table.insert(outgoing, {
                id = req.id,
                toGang = req.toGang,
                toGangId = req.target_gang_id,
                killsToWin = 25, -- Default value, can be added to DB later
                wager = req.wager_amount,
                sentAt = req.created_at
            })
        end
    end
    
    return {
        gangs = gangs,
        history = history,
        requests = requests,
        outgoing = outgoing
    }
end)

lib.callback.register('trase_gangs:server:sendGangWarInvite', function(source, data)
    local identifier = GetPrimaryIdentifier(source)
    if not identifier then return false, 'invalid_identifier' end
    
    local gang = Handler:GetPlayerGang(identifier)
    if not gang then return false, 'not_in_gang' end
    
    -- Check if owner or has permission
    local isOwner = gang.owner_identifier == identifier
    local hasPermission = Handler:HasPermission(identifier, 'manage_wars')
    
    if not isOwner and not hasPermission then
        return false, 'no_permission'
    end
    
    local targetGangId = data.gangId
    local wagerAmount = data.wager or 0
    
    -- Check if target gang exists
    local targetGang = MySQL.query.await('SELECT id, label FROM trase_gangs WHERE id = ?', {targetGangId})
    if not targetGang or #targetGang == 0 then
        return false, 'gang_not_found'
    end
    
    -- Check if already has pending request
    local existing = MySQL.query.await('SELECT id FROM trase_gang_war_requests WHERE challenger_gang_id = ? AND target_gang_id = ? AND status = "pending" AND expires_at > NOW()', {gang.id, targetGangId})
    if existing and #existing > 0 then
        return false, 'request_already_sent'
    end
    
    -- Insert war request
    local requestId = MySQL.insert.await('INSERT INTO trase_gang_war_requests (challenger_gang_id, target_gang_id, wager_amount, requested_by) VALUES (?, ?, ?, ?)', {
        gang.id,
        targetGangId,
        wagerAmount,
        identifier
    })
    
    if requestId then
        -- Notify target gang members
        for targetIdentifier, _ in pairs(Handler.playerGangs) do
            if Handler.playerGangs[targetIdentifier] == targetGangId then
                local targetSource = GetPlayerSourceByIdentifier(targetIdentifier)
                if targetSource then
                    SendNotification(targetSource, {
                        title = 'Gang War Request',
                        description = gang.label .. ' has challenged your gang to a war!',
                        type = 'info'
                    })
                end
            end
        end
        
        -- Add audit log
        Handler:AddAuditLog(gang.id, identifier, 'gang_war_sent', nil, 'Sent war request to ' .. targetGang[1].label)
        
        -- Return success with the request data for UI
        return {
            success = true,
            request = {
                id = requestId,
                toGang = targetGang[1].label,
                toGangId = targetGangId,
                killsToWin = 25,
                wager = wagerAmount,
                sentAt = os.date('%Y-%m-%d %H:%M:%S')
            }
        }
    end
    
    return { success = false, error = 'database_error' }
end)

lib.callback.register('trase_gangs:server:cancelGangWarInvite', function(source, data)
    local identifier = GetPrimaryIdentifier(source)
    if not identifier then return false, 'invalid_identifier' end
    
    local gang = Handler:GetPlayerGang(identifier)
    if not gang then return false, 'not_in_gang' end
    
    -- Check permission
    local isOwner = gang.owner_identifier == identifier
    local hasPermission = Handler:HasPermission(identifier, 'manage_wars')
    
    if not isOwner and not hasPermission then
        return false, 'no_permission'
    end
    
    local requestId = data.requestId
    
    -- Verify the request belongs to this gang
    local request = MySQL.query.await('SELECT target_gang_id FROM trase_gang_war_requests WHERE id = ? AND challenger_gang_id = ? AND status = "pending"', {requestId, gang.id})
    if not request or #request == 0 then
        return false, 'request_not_found'
    end
    
    -- Delete the request
    MySQL.query.await('DELETE FROM trase_gang_war_requests WHERE id = ?', {requestId})
    
    -- Add audit log
    Handler:AddAuditLog(gang.id, identifier, 'gang_war_cancelled', nil, 'Cancelled outgoing war request')
    
    return true, 'request_cancelled'
end)

lib.callback.register('trase_gangs:server:acceptGangWarRequest', function(source, data)
    local identifier = GetPrimaryIdentifier(source)
    if not identifier then return false, 'invalid_identifier' end
    
    local gang = Handler:GetPlayerGang(identifier)
    if not gang then return false, 'not_in_gang' end
    
    -- Check permission
    local isOwner = gang.owner_identifier == identifier
    local hasPermission = Handler:HasPermission(identifier, 'manage_wars')
    
    if not isOwner and not hasPermission then
        return false, 'no_permission'
    end
    
    local requestId = data.requestId
    
    -- Get request details
    local request = MySQL.query.await('SELECT * FROM trase_gang_war_requests WHERE id = ? AND target_gang_id = ? AND status = "pending"', {requestId, gang.id})
    if not request or #request == 0 then
        return false, 'request_not_found'
    end
    
    request = request[1]
    
    -- Update request status
    MySQL.update.await('UPDATE trase_gang_war_requests SET status = "accepted" WHERE id = ?', {requestId})
    
    -- Create war history entry
    local warId = MySQL.insert.await('INSERT INTO trase_gang_war_history (request_id, gang_1_id, gang_2_id, wager_amount, status) VALUES (?, ?, ?, ?, "active")', {
        requestId,
        request.challenger_gang_id,
        gang.id,
        request.wager_amount
    })
    
    if warId then
        -- Notify both gangs
        for playerIdentifier, gangId in pairs(Handler.playerGangs) do
            if gangId == request.challenger_gang_id or gangId == gang.id then
                local playerSource = GetPlayerSourceByIdentifier(playerIdentifier)
                if playerSource then
                    SendNotification(playerSource, {
                        title = 'Gang War Started!',
                        description = 'The war has begun! Fight for your gang!',
                        type = 'success'
                    })
                end
            end
        end
        
        -- Add audit logs
        Handler:AddAuditLog(gang.id, identifier, 'gang_war_accepted', nil, 'Accepted war request')
        
        return true, 'war_started'
    end
    
    return false, 'database_error'
end)

lib.callback.register('trase_gangs:server:declineGangWarRequest', function(source, data)
    local identifier = GetPrimaryIdentifier(source)
    if not identifier then return false, 'invalid_identifier' end
    
    local gang = Handler:GetPlayerGang(identifier)
    if not gang then return false, 'not_in_gang' end
    
    -- Check permission
    local isOwner = gang.owner_identifier == identifier
    local hasPermission = Handler:HasPermission(identifier, 'manage_wars')
    
    if not isOwner and not hasPermission then
        return false, 'no_permission'
    end
    
    local requestId = data.requestId
    
    -- Get request details
    local request = MySQL.query.await('SELECT challenger_gang_id FROM trase_gang_war_requests WHERE id = ? AND target_gang_id = ? AND status = "pending"', {requestId, gang.id})
    if not request or #request == 0 then
        return false, 'request_not_found'
    end
    
    -- Update request status
    MySQL.update.await('UPDATE trase_gang_war_requests SET status = "declined" WHERE id = ?', {requestId})
    
    -- Notify challenger gang
    for playerIdentifier, gangId in pairs(Handler.playerGangs) do
        if gangId == request[1].challenger_gang_id then
            local playerSource = GetPlayerSourceByIdentifier(playerIdentifier)
            if playerSource then
                SendNotification(playerSource, {
                    title = 'Gang War Declined',
                    description = gang.label .. ' has declined your war request',
                    type = 'error'
                })
            end
        end
    end
    
    -- Add audit log
    Handler:AddAuditLog(gang.id, identifier, 'gang_war_declined', nil, 'Declined war request')
    
    return true, 'request_declined'
end)

-- Export Handler
exports('GetServerHandler', function()
    return Handler
end)

return Handler
