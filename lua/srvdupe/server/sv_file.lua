net.Receive("SrvDupe_FileClientToServer", SrvDupe.HandleFileStream)

net.Receive("SrvDupe_AskServerForFile", function(_, ply)
    if SERVER then
        if not SrvDupe.CheckPlyWritePermissions(ply) then
            SrvDupe.Notify("Not enough permissions", 1, nil, ply, true)
            return
        end
    end
    local path = net.ReadString()
    local dataFolder = SrvDupe.DataFolder
    local fullPath = dataFolder .. "/" .. path

    local fileExists = file.Exists(fullPath, "DATA")
    if not fileExists then
        SrvDupe.Notify("File does not exists anymore!", 1, nil, ply, true)
        return
    end

    local content = file.Read(fullPath, "DATA")
    local pathSplits = string.Split(path, "/")
    local fileName = pathSplits[#pathSplits]

    SrvDupe.SendFile(fileName, content, ply)
end)