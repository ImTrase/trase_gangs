local ActivityOverlay = require('client.activity_overlay')

local function StartGangWarOverlay()
    local gangWarOverlay = ActivityOverlay:new()
    
    gangWarOverlay:Show({
        title = "GANG WAR",
        description = "30 KILLS TO WIN",
        stats = {
            { label = "Kill Streak", value = "8 Kills" }
        },
        leaderboard = {
            { position = 1, name = "Woo Gang", value = "44 Kills", color = "#22c55e" },
            { position = 2, name = "BD Gang", value = "44 Kills", color = "#6b7280" }
        },
        showTimer = true,
        timerDuration = 300,
        timerLabel = "TIME REMAINING"
    })
    
    CreateThread(function()
        local kills = 8
        while gangWarOverlay:IsVisible() do
            Wait(5000)
            kills = kills + 1
            
            gangWarOverlay:UpdateStats({
                { label = "Kill Streak", value = kills .. " Kills" }
            })
            
            gangWarOverlay:UpdateLeaderboard({
                { position = 1, name = "Woo Gang", value = (44 + kills) .. " Kills", color = "#22c55e" },
                { position = 2, name = "BD Gang", value = "44 Kills", color = "#6b7280" }
            })
        end
    end)
    
    SetTimeout(60000, function()
        gangWarOverlay:Hide()
    end)
end

local function StartTurfCaptureOverlay()
    local turfOverlay = ActivityOverlay:new()
    
    turfOverlay:Show({
        title = "TURF WAR",
        description = "CAPTURING TERRITORY",
        stats = {
            { label = "Capture Progress", value = "45%" },
            { label = "Defenders Killed", value = "12" }
        },
        leaderboard = {
            { position = 1, name = "Attackers", value = "12 Kills", color = "#ef4444" },
            { position = 2, name = "Defenders", value = "8 Kills", color = "#3b82f6" }
        },
        showTimer = true,
        timerDuration = 180,
        timerLabel = "CAPTURE TIME"
    })
    
    CreateThread(function()
        local progress = 45
        while turfOverlay:IsVisible() and progress < 100 do
            Wait(2000)
            progress = progress + 5
            
            turfOverlay:UpdateStats({
                { label = "Capture Progress", value = progress .. "%" },
                { label = "Defenders Killed", value = "12" }
            })
        end
        
        if progress >= 100 then
            turfOverlay:Hide()
        end
    end)
end

local function StartDrugzoneOverlay()
    local drugOverlay = ActivityOverlay:new()
    
    drugOverlay:Show({
        title = "DRUGZONE",
        description = "DEFEND THE ZONE",
        stats = {
            { label = "Time Remaining", value = "5:00" },
            { label = "Bags Collected", value = "15/30" }
        },
        leaderboard = {
            { position = 1, name = "Your Gang", value = "15 Bags", color = "#8b5cf6" },
            { position = 2, name = "Rival Gang", value = "8 Bags", color = "#6b7280" }
        }
    })
    
    CreateThread(function()
        local timeLeft = 300
        while drugOverlay:IsVisible() and timeLeft > 0 do
            Wait(1000)
            timeLeft = timeLeft - 1
            
            local minutes = math.floor(timeLeft / 60)
            local seconds = timeLeft % 60
            
            drugOverlay:UpdateStats({
                { label = "Time Remaining", value = string.format("%d:%02d", minutes, seconds) },
                { label = "Bags Collected", value = "15/30" }
            })
        end
        
        drugOverlay:Hide()
    end)
end

local function DynamicOverlayExample()
    local overlay = ActivityOverlay:new()
    
    overlay:Show({
        title = "ACTIVITY",
        description = "TRACKING PROGRESS",
        stats = {},
        leaderboard = {}
    })
    
    overlay:AddStat("Score", 0)
    overlay:AddStat("Kills", 0)
    
    overlay:AddLeaderboardEntry(1, "Player 1", "100 Points", "#22c55e")
    overlay:AddLeaderboardEntry(2, "Player 2", "85 Points", "#eab308")
    overlay:AddLeaderboardEntry(3, "Player 3", "70 Points", "#ef4444")
    
    Wait(10000)
    overlay:ClearStats()
    overlay:ClearLeaderboard()
    overlay:Hide()
end

RegisterCommand('testgangwar', function()
    StartGangWarOverlay()
end, false)

RegisterCommand('testturf', function()
    StartTurfCaptureOverlay()
end, false)

RegisterCommand('testdrugzone', function()
    StartDrugzoneOverlay()
end, false)

RegisterCommand('testdynamic', function()
    DynamicOverlayExample()
end, false)

exports('CreateActivityOverlay', function()
    return ActivityOverlay:new()
end)