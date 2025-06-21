SrvDupe = {
    DataFolder = "srvdupe"
}

print("[SrvDupe]\tHello World!")

if not file.Exists(SrvDupe.DataFolder, "DATA") then
    file.CreateDir(SrvDupe.DataFolder)
end

AddCSLuaFile("config/sh_config.lua")
AddCSLuaFile("srvdupe/client/cl_control_panel_menu.lua")
AddCSLuaFile("srvdupe/file_browser.lua")

include("config/sh_config.lua")
include("srvdupe/file_browser.lua")