require "mp.msg"
require "mp.options"

local HDR_CMD = '"C:\\path\\to\\HDRCmd.exe"'

local handle = io.popen(HDR_CMD .. " status")
local result
if handle then
    result = handle:read("*l")
    handle:close()
end
if result and result:match("on$") then
    return
end

local HDR_enabled = false

mp.register_event("end-file", function()
    if HDR_enabled then
        os.execute(HDR_CMD .. " off")
        HDR_enabled = false
    end
end)

mp.observe_property("video-params", "native", function(_, params)
    if not params or not params.primaries or not params.gamma then
        return
    end
    
    if params.primaries == "bt.2020" and (params.gamma == "pq" or params.gamma == "hlg") then
        if not HDR_enabled then
            os.execute(HDR_CMD .. " on")
            HDR_enabled = true
        end
    elseif HDR_enabled then
        os.execute(HDR_CMD .. " off")
        HDR_enabled = false
    end
end)