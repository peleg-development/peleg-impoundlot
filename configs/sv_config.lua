Config = Config or {}

-- Discord Webhook Configuration
Config.Discord = {
    enabled = false,  -- Set to true to enable Discord logging
    webhook = '',    -- Your Discord webhook URL
    botName = 'Impound System',  -- Bot name for Discord messages
    botAvatar = '',  -- Bot avatar URL (optional)
    
    -- Logging Events
    logEvents = {
        vehicleImpounded = true,    -- Log when vehicle is impounded
        vehicleReleased = true,     -- Log when vehicle is released
        vehicleReleasedToGarage = true,  -- Log when vehicle is released to garage
        paymentReceived = true,     -- Log when payment is received
        officerAction = true,       -- Log officer actions
    },
    
    -- Message Colors (hex codes)
    colors = {
        impound = 0xFF6B35,        -- Orange for impound events
        release = 0x00FF00,        -- Green for release events
        payment = 0x00BFFF,        -- Blue for payment events
        error = 0xFF0000,          -- Red for error events
        info = 0x808080,           -- Gray for info events
    }
}
