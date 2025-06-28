SrvDupe = {
    DataFolder = "srvdupe",
    old_CheckLimit = nil,
    old_CheckRestriction = nil,
    old_AddCount = nil,
}

print("[SrvDupe]\tHello World!")

if not file.Exists(SrvDupe.DataFolder, "DATA") then
    file.CreateDir(SrvDupe.DataFolder)
end

AddCSLuaFile("config/sh_srvdupe_config.lua")
AddCSLuaFile("srvdupe/sh_codec.lua")
AddCSLuaFile("srvdupe/sh_codec_legacy.lua")
AddCSLuaFile("srvdupe/sh_file.lua")
AddCSLuaFile("srvdupe/sh_srvdupe.lua")

AddCSLuaFile("srvdupe/client/cl_control_panel_menu.lua")
AddCSLuaFile("srvdupe/client/cl_file.lua")
AddCSLuaFile("srvdupe/client/cl_file_browser.lua")


include("config/sh_srvdupe_config.lua")
include("srvdupe/sh_codec.lua")
include("srvdupe/sh_codec_legacy.lua")
include("srvdupe/sh_file.lua")
include("srvdupe/sh_srvdupe.lua")

include("srvdupe/server/sv_clipboard.lua")
include("srvdupe/server/sv_file.lua")
include("srvdupe/server/sv_file_browser.lua")

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

function SrvDupe.ApplyCustomRestrictions()
    if SrvDupe.old_CheckLimit or SrvDupe.old_CheckRestriction then return end

    local ENT = FindMetaTable("Player")

    SrvDupe.old_CheckLimit = ENT.CheckLimit
    SrvDupe.old_CheckRestriction = ENT.CheckRestriction
    SrvDupe.old_AddCount = ENT.AddCount

    ENT.CheckLimit = function(ply, ent) return true end
    ENT.CheckRestriction = function(ply, ent) return true end
    ENT.AddCount = function (str, ent) return end
end

function SrvDupe.RevertCustomRestrictions()
    if not SrvDupe.old_CheckLimit or not SrvDupe.old_CheckRestriction then return end

    local ENT = FindMetaTable("Player")

    ENT.CheckLimit = SrvDupe.old_CheckLimit
    ENT.CheckRestriction = SrvDupe.old_CheckRestriction
    ENT.AddCount = SrvDupe.old_AddCount

    SrvDupe.old_CheckLimit = nil
    SrvDupe.old_CheckRestriction = nil
    SrvDupe.old_AddCount = nil
end

hook.Add("PlayerInitialSpawn","SrvDupe_AddPlayerTable",function(ply)
    ply.SrvDupe = {}
end)

--concommand.Add("srvdupe_spawn", function(ply, cmd, args)
--    if not SrvDupe.CheckPlyWritePermissions(ply) then
--        SrvDupe.Notify("Not enough permissions", 1, nil, ply, true)
--        return
--    end
--
--    local relativePath = args[1]
--    if not relativePath then
--        SrvDupe.Notify("No path specified", 1, nil, ply, false)
--        return
--    end
--
--    SrvDupe.LoadAndPaste(relativePath, nil, nil, ply)
--end)

util.AddNetworkString("SrvDupe_Notify")
util.AddNetworkString("SrvDupe_AskServerDataContent")
util.AddNetworkString("SrvDupe_SendServerDataContent")
util.AddNetworkString("SrvDupe_BroadcastChange")
util.AddNetworkString("SrvDupe_FileClientToServer")
util.AddNetworkString("SrvDupe_FileServerToClient")
util.AddNetworkString("SrvDupe_AskServerForFile")
util.AddNetworkString("SrvDupe_AskServerForFileDelete")
util.AddNetworkString("SrvDupe_AskServerForAddFolder")
util.AddNetworkString("SrvDupe_AskServerForFileMove")

CreateConVar("SrvDupe_SpawnRate", "1", {FCVAR_ARCHIVE})
CreateConVar("SrvDupe_Strict", "0", {FCVAR_ARCHIVE}, "Prevents entities from being duped with unauthorized data. Can fix certain exploits at the cost of some entities potentially duping incorrectly")

hook.Run("SrvDupe_PostInit")

