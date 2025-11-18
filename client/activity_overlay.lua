-- Activity Overlay System
-- Allows registering and displaying custom activity overlays

local ActivityOverlay = {}
ActivityOverlay.__index = ActivityOverlay

-- Constructor
function ActivityOverlay:new()
    local self = setmetatable({}, ActivityOverlay)
    self.visible = false
    self.title = "ACTIVITY"
    self.description = ""
    self.stats = {}
    self.leaderboard = {}
    self.showTimer = false
    self.timerDuration = 0
    self.timerLabel = "TIME REMAINING"
    return self
end

-- Show the overlay with initial data
function ActivityOverlay:Show(data)
    self.visible = true
    self.title = data.title or "ACTIVITY"
    self.description = data.description or ""
    self.stats = data.stats or {}
    self.leaderboard = data.leaderboard or {}
    self.showTimer = data.showTimer or false
    self.timerDuration = data.timerDuration or 0
    self.timerLabel = data.timerLabel or "TIME REMAINING"
    
    SendNUIMessage({
        action = 'showActivityOverlay',
        data = {
            title = self.title,
            description = self.description,
            stats = self.stats,
            leaderboard = self.leaderboard,
            showTimer = self.showTimer,
            timerDuration = self.timerDuration,
            timerLabel = self.timerLabel
        }
    })
end

-- Hide the overlay
function ActivityOverlay:Hide()
    self.visible = false
    SendNUIMessage({
        action = 'hideActivityOverlay'
    })
end

-- Update statistics cards
function ActivityOverlay:UpdateStats(stats)
    self.stats = stats
    SendNUIMessage({
        action = 'updateActivityStats',
        data = {
            stats = stats
        }
    })
end

-- Update leaderboard entries
function ActivityOverlay:UpdateLeaderboard(leaderboard)
    self.leaderboard = leaderboard
    SendNUIMessage({
        action = 'updateActivityLeaderboard',
        data = {
            leaderboard = leaderboard
        }
    })
end

-- Add a stat card
function ActivityOverlay:AddStat(label, value)
    table.insert(self.stats, {
        label = label,
        value = value
    })
    self:UpdateStats(self.stats)
end

-- Add a leaderboard entry
function ActivityOverlay:AddLeaderboardEntry(position, name, value, color)
    table.insert(self.leaderboard, {
        position = position,
        name = name,
        value = value,
        color = color or "#6b7280"
    })
    self:UpdateLeaderboard(self.leaderboard)
end

-- Clear all stats
function ActivityOverlay:ClearStats()
    self.stats = {}
    self:UpdateStats(self.stats)
end

-- Clear leaderboard
function ActivityOverlay:ClearLeaderboard()
    self.leaderboard = {}
    self:UpdateLeaderboard(self.leaderboard)
end

-- Check if visible
function ActivityOverlay:IsVisible()
    return self.visible
end

-- Set timer
function ActivityOverlay:SetTimer(duration, label)
    self.showTimer = true
    self.timerDuration = duration
    self.timerLabel = label or "TIME REMAINING"
    
    -- Re-show with updated timer
    SendNUIMessage({
        action = 'showActivityOverlay',
        data = {
            title = self.title,
            description = self.description,
            stats = self.stats,
            leaderboard = self.leaderboard,
            showTimer = self.showTimer,
            timerDuration = self.timerDuration,
            timerLabel = self.timerLabel
        }
    })
end

-- Hide timer
function ActivityOverlay:HideTimer()
    self.showTimer = false
    self:SetTimer(0)
end

-- Export
return ActivityOverlay
