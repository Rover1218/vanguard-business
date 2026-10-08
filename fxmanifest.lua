fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vanguard-business'
author 'Rover'
description 'Vanguard Business - player-run food businesses for QBCore, Qbox and ESX'
version '1.2.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'shared/rules.lua',
    'shared/pending.lua',
    'shared/types.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
    'client/world.lua',
    'client/doors.lua',
    'client/placement.lua',
    'client/cooking.lua',
    'client/panels.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/db.lua',
    'server/businesses.lua',
    'server/staff.lua',
    'server/stations.lua',
    'server/access.lua',
    'server/router.lua',
    'server/admin.lua',
    'server/boss.lua',
    'server/supplier.lua',
    'server/cooking.lua',
    'server/doors.lua',
    'server/register.lua',
    'server/items.lua',
    'server/payroll.lua',
    'server/main.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'images/*.png',
}

dependencies {
    'oxmysql',
}
