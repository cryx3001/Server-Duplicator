SrvDupe = {
    AdvDupe2_Data = "advdupe2"
}

print("[SrvDupe]\tHello World!")

include("config/sh_srvdupe_config.lua")
include("srvdupe/sh_codec.lua")
include("srvdupe/sh_codec_legacy.lua")
include("srvdupe/sh_file.lua")
include("srvdupe/sh_srvdupe.lua")

include("srvdupe/client/cl_file_browser.lua")
include("srvdupe/client/cl_file.lua")
include("srvdupe/client/cl_control_panel_menu.lua")

function SrvDupe.Notify(msg,typ,dur)
    surface.PlaySound(typ == 1 and "buttons/button10.wav" or "ambient/water/drip1.wav")
    GAMEMODE:AddNotify(msg, typ or NOTIFY_GENERIC, dur or 5)
    if not game.SinglePlayer() then print("[SrvDupe]\t"..msg) end
end

net.Receive("SrvDupe_Notify", function()
    SrvDupe.Notify(net.ReadString(), net.ReadUInt(8), net.ReadFloat())
end)

hook.Run("SrvDupe_PostInit")
