fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Distortionz'
description 'Distortionz Trucking — depot ped trucking job with realistic trailer hookup and tiered cargo payouts.'
version '1.0.9'
repository 'https://github.com/Distortionzz/Distortionz_Trucking'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua',
    'version_check.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'ox_inventory'
}
