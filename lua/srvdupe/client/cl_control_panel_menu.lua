local function isAllowed()
    local roles = SrvDupe.Config.AllowedRolesWrite or {}
    return table.HasValue(roles, LocalPlayer():GetUserGroup())
end

local function BuildControlPanel(CPanel)
    if not isAllowed() then
        CPanel:Help("You don't have the permission to access this menu."):SetColor(Color(150, 50, 0, 255))
        return
    end

    local FileBrowser = vgui.Create("srvdupe_browser")
    CPanel:AddItem(FileBrowser)
    FileBrowser:SetSize(CPanel:GetWide(), 405)
    SrvDupe.FileBrowser = FileBrowser
end

hook.Add("PopulateToolMenu", "AddSrcDupeControlPanelMenu", function()
    spawnmenu.AddToolMenuOption("Utilities", "Admin", "SrvDupeControlPanel", "Server Dupes", "", "", BuildControlPanel, {})
end)