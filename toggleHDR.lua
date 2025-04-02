require "mp.msg"
require "mp.options"

local HDRCMD = '"C:\\Program Files\\HDRTray\\HDRCmd.exe"'

local handle = io.popen(HDRCMD .. " status")
local result
if handle then
    result = handle:read("*l")
    handle:close()
end
if result and result:match("on$") then
    return
end

mp.observe_property("video-params/primaries", "string", function(_, primaries)
    if primaries == nil then
        return
    end
    
    if primaries == "bt.2020" then
        os.execute(HDRCMD .. " on")
    end
    
    print(mp.get_property("width"), "x", mp.get_property("height"), primaries)
    
    local function offHDR()
        if primaries == "bt.2020" then
            os.execute(HDRCMD .. " off")
        end
    end
    
    mp.register_event("end-file", offHDR)
end)