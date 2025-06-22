SrvDupe = {
    DataFolder = "srvdupe"
}

print("[SrvDupe]\tHello World!")

if not file.Exists(SrvDupe.DataFolder, "DATA") then
    file.CreateDir(SrvDupe.DataFolder)
end

function SrvDupe.Notify(msg, typ, dur, ply, showsrv)
    net.Start("SrvDupe_Notify")
    net.WriteString(msg)
    net.WriteUInt(typ or 0, 8)
    net.WriteFloat(dur or 5)
    net.Send(ply)

    if(showsrv==true)then
        print("[SrvDupe]\t"..ply:Nick()..": "..msg)
    end
end

function SrvDupe.CheckPlyWritePermissions(ply)
    local roles = SrvDupe.Config.AllowedRolesWrite or {}
    return table.HasValue(roles, ply:GetUserGroup())
end

AddCSLuaFile("config/sh_config.lua")
AddCSLuaFile("srvdupe/sh_codec.lua")
AddCSLuaFile("srvdupe/sh_codec_legacy.lua")
AddCSLuaFile("srvdupe/sh_file.lua")
AddCSLuaFile("srvdupe/client/cl_control_panel_menu.lua")
AddCSLuaFile("srvdupe/client/cl_file.lua")
AddCSLuaFile("srvdupe/client/cl_file_browser.lua")


include("config/sh_config.lua")
include("srvdupe/sh_codec.lua")
include("srvdupe/sh_codec_legacy.lua")
include("srvdupe/sh_file.lua")
include("srvdupe/server/sv_file.lua")
include("srvdupe/server/sv_file_browser.lua")


util.AddNetworkString("SrvDupe_Notify")
util.AddNetworkString("SrvDupe_AskServerDataContent")
util.AddNetworkString("SrvDupe_SendServerDataContent")
util.AddNetworkString("SrvDupe_BroadcastChange")
util.AddNetworkString("SrvDupe_FileClientToServer")
util.AddNetworkString("SrvDupe_FileServerToClient")
util.AddNetworkString("SrvDupe_AskServerForFile")

