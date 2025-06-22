local function getServerDataContent()
    local res = {}

    local function _recDataContent(path, tbl)
        local files, dirs = file.Find(SrvDupe.DataFolder .. "/" .. path .. "/*", "DATA", "nameasc")

        for _, d in pairs(dirs) do
            tbl[d] = {}
            _recDataContent(path .. "/" .. d, tbl[d])
        end

        for _, f in pairs(files) do
            table.insert(tbl, f)
        end
    end

    _recDataContent("", res)
    return res
end

net.Receive("SrvDupe_AskServerDataContent", function(_, ply)
    if not SrvDupe.CheckPlyWritePermissions(ply) then
        SrvDupe.Notify("Not enough permissions", 1, nil, ply, true)
        return
    end

    local tbl = getServerDataContent() or {}

    net.Start("SrvDupe_SendServerDataContent")
        net.WriteTable(tbl)
    net.Send(ply)
end)