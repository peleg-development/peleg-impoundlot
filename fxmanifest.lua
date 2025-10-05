fx_version 'cerulean'

game 'gta5'
lua54 'yes'

author 'Peleg-Development'
description 'NPC Tow & Impound System'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'configs/config.lua',
    'src/shared/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'configs/sv_config.lua',
    'src/server/db.lua',
    'src/server/main.lua',
    'src/server/version.lua',
}

client_scripts {
    'src/client/*.lua',
}

ui_page 'src/web/dist/index.html'

files {
    'src/web/images/*.png',
    'src/web/dist/index.html',
    'src/web/dist/assets/*.js',
    'src/web/dist/assets/*.css',
}

dependencies {
    'ox_lib',
}
