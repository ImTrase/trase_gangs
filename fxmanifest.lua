fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Trase'
description 'Advanced gang system for FiveM'
version '1.0.4'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/*.lua',
    'modules/shared.lua',
}

client_scripts {
    'client/activity_overlay.lua',
    'client/client.lua',
    'frameworks/**/client.lua',
    'modules/**/client.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/*.lua',
    'modules/**/server.lua',
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
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'frameworks/**/*.lua',
}