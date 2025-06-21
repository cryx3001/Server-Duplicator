function SrvDupe.SaveFile(fileName, content)
    local dataFolder
    if SERVER then
        dataFolder = SrvDupe.DataFolder
    else
        dataFolder = SrvDupe.AdvDupe2_Data
    end

    local extensionFile = string.GetExtensionFromFilename(fileName) or "txt"
    fileName = string.StripExtension(fileName)

    local fileExists = file.Exists(dataFolder .. "/" .. fileName .. "." .. extensionFile, "DATA")

    local i = 1
    local tmpFileName = fileName
    while fileExists and i < 1000 do
        tmpFileName = fileName .. "_" .. i
        fileExists =  file.Exists(dataFolder .. "/" .. tmpFileName .. "." .. extensionFile, "DATA")
        i = i + 1
    end
    fileName = tmpFileName .. "." .. extensionFile

    file.Append(dataFolder .. "/" .. fileName, content)

    if SERVER then
        net.Start("SrvDupe_BroadcastChange")
        net.Broadcast()
    end
end

function SrvDupe.SendFile(fileName, content, ply)
    if SERVER then
        if not SrvDupe.CheckPlyWritePermissions(ply) then
            SrvDupe.Notify(ply, "Not enough permissions", 1, true)
            return
        end
    end

    local netMsg
    if SERVER then
        netMsg = "SrvDupe_FileServerToClient"
    else
        netMsg = "SrvDupe_FileClientToServer"
    end

    net.Start(netMsg)
        net.WriteString(fileName)
        net.WriteStream(content)
    if CLIENT then
        net.SendToServer()
    else
        net.Send(ply)
    end
end

function SrvDupe.HandleFileStream(_, ply)
    if SERVER then
        if not SrvDupe.CheckPlyWritePermissions(ply) then
            SrvDupe.Notify(ply, "Not enough permission", 1, true)
            return
        end
    end

    if CLIENT then
        ply = nil
    end

    local fileName = net.ReadString()
    net.ReadStream(ply, function(data)
        SrvDupe.SaveFile(fileName, data)
    end)
end