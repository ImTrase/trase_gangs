function TranslateText(key, default)
    local lang = Config.Language or 'en'
    if Config.Strings[lang] and Config.Strings[lang][key] then
        return Config.Strings[lang][key]
    else
        return default or key
    end
end

if not IsDuplicityVersion() then
    RegisterNUICallback('fetchLocales', function(data, cb)
        local lang = Config.Language or 'en'
        cb(Config.Strings[lang] or {})
    end)
end