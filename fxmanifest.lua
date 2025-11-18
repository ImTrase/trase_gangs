fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Trase'
description 'Advanced gang system for FiveM'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/*.lua',
    'modules/shared.lua',
}

client_scripts {
    'client/client.lua',
    'client/activity_overlay.lua',
    'frameworks/**/client.lua',
    'modules/**/client.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua', -- oxmysql will automatically override this if installed
    'server/server.lua',
    'frameworks/**/server.lua'
}

ui_page 'web/build/index.html'
files {
    'web/build/index.html',
    'web/build/**/*',
    'modules/**/client.lua',
    'locales/*.json'
}

dependencies {
    'ox_lib',
    'mysql-async'
}