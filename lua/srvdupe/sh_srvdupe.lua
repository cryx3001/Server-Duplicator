function SrvDupe.CheckPlyWritePermissions(ply)
    local roles = SrvDupe.Config.AllowedRolesWrite or {}
    local steamIDs = SrvDupe.Config.AllowedSteamIDWrite or {}
    return table.HasValue(roles, ply:GetUserGroup()) or table.HasValue(steamIDs, ply:SteamID())
end
