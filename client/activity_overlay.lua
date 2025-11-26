ActivityOverlay = {}
ActivityOverlay.__index = ActivityOverlay

function ActivityOverlay:new()
    local self = setmetatable({}, ActivityOverlay)
    self.visible = false
    self.title = "ACTIVITY"
    self.description = ""
    self.stats = {}
    self.leaderboard = {}
    self.showTimer = false
    self.timerDuration = 0
    self.totalDuration = 0
    self.timerLabel = "TIME REMAINING"
    return self
end

function ActivityOverlay:Show(data)
    self.visible = true
    self.title = data.title or "ACTIVITY"
    self.description = data.description or ""
    self.stats = data.stats or {}
    self.leaderboard = data.leaderboard or {}
    self.showTimer = data.showTimer or false
    self.timerDuration = data.timerDuration or 0
    self.totalDuration = data.totalDuration or 0
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
            totalDuration = self.totalDuration,
            timerLabel = self.timerLabel
        }
    })
end

function ActivityOverlay:Hide()
    self.visible = false
    SendNUIMessage({
        action = 'hideActivityOverlay'
    })
end

function ActivityOverlay:UpdateStats(stats)
    self.stats = stats
    SendNUIMessage({
        action = 'updateActivityStats',
        data = {
            stats = stats
        }
    })
end

function ActivityOverlay:UpdateLeaderboard(leaderboard)
    self.leaderboard = leaderboard
    SendNUIMessage({
        action = 'updateActivityLeaderboard',
        data = {
            leaderboard = leaderboard
        }
    })
end

function ActivityOverlay:AddStat(label, value)
    table.insert(self.stats, {
        label = label,
        value = value
    })
    self:UpdateStats(self.stats)
end

function ActivityOverlay:AddLeaderboardEntry(position, name, value, color)
    table.insert(self.leaderboard, {
        position = position,
        name = name,
        value = value,
        color = color or "#6b7280"
    })
    self:UpdateLeaderboard(self.leaderboard)
end

function ActivityOverlay:ClearStats()
    self.stats = {}
    self:UpdateStats(self.stats)
end

function ActivityOverlay:ClearLeaderboard()
    self.leaderboard = {}
    self:UpdateLeaderboard(self.leaderboard)
end

function ActivityOverlay:IsVisible()
    return self.visible
end

function ActivityOverlay:SetTimer(duration, label)
    self.showTimer = true
    self.timerDuration = duration
    self.timerLabel = label or "TIME REMAINING"
    
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

function ActivityOverlay:HideTimer()
    self.showTimer = false
    self:SetTimer(0)
end