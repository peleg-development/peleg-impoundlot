Config = {}

Config.Framework = 'auto'
Config.DefaultGarage = 'pillboxhill'
Config.KeysIntegration = 'qb-vehiclekeys'
Config.UseOxTarget = true
Config.Fee = 1000
Config.Debug = false
Config.ShowVehiclePreview = true  -- Show physical vehicles in impound lots (false = menu only)

Config.Lots = {
    {
        id = 'missionrow',
        label = 'Mission Row Impound',
        center = vec3(408.96, -1623.59, 29.29),
        heading = 140.0,
        capacity = 10,
        spawn = {
            vec4(401.92, -1631.76, 28.29, 139.0),
            vec4(408.65, -1638.52, 28.90, 227.01),
            vec4(410.49, -1636.31, 28.90, 228.96),
            vec4(410.8471, -1656.3523, 28.8985, 320.3492),
            vec4(408.2474, -1654.5455, 28.8984, 320.9579),
            vec4(405.9094, -1652.2690, 28.8981, 318.7244),
            vec4(403.5911, -1650.7500, 28.9008, 318.5872),
            vec4(401.0051, -1648.3809, 28.8994, 319.6727),
            vec4(398.4296, -1646.8690, 28.8973, 320.1586),
            vec4(396.1111, -1644.6859, 28.8986, 319.8920),
            vec4(408.2474, -1654.5455, 28.8984, 320.9579),
            vec4(420.8165, -1642.1261, 28.8967, 86.3882),
            vec4(420.9339, -1638.9742, 28.8992, 88.3828),
            vec4(421.2837, -1635.8362, 28.8967, 88.7112),
            vec4(419.3470, -1629.8119, 28.8979, 137.9314),
            vec4(417.4296, -1627.5730, 28.8984, 141.2501),

        },
        release_spawn = vec4(411.8318, -1649.0764, 28.8688, 226.8273),
        ped = {
            enabled = true,
            model = 's_m_y_cop_01',
            coords = vec4(408.96, -1623.59, 28.29, 140.0),
            scenario = 'WORLD_HUMAN_CLIPBOARD'
        }
    },
}

Config.DefaultGarage = "pillboxgarage"
Config.Garages = {
    {
        id = 'pillboxgarage',
        label = 'Pillbox Hill Garage',
        description = 'Pillbox Hill Medical Center'
    }
}


-- DO NOT EDIT THIS UNLESS YOU KNOW WHAT YOU ARE DOING
Config.FrameworkTables = {
    qb = {
        table = 'player_vehicles',
        owner = 'citizenid',
        plate = 'plate',
        vehicleJsonAlt = 'vehicle',
        vehicleJsonFallback = 'mods',
        garage = 'garage',
        state = 'state',
        model = 'vehicle',
        hash = 'hash',
        license = 'license',
    },
    esx = {
        table = 'owned_vehicles',
        owner = 'owner',
        plate = 'plate',
        vehicleJsonAlt = 'vehicle',
        vehicleJsonFallback = 'vehicle',
        state = 'stored',
    }
}


