local function deleteFile(relativePath)
    local dataFolder = SrvDupe.DataFolder
    local fullPath = dataFolder .. "/" .. relativePath

    if file.Exists(fullPath, "DATA") then
        file.Delete(fullPath)
        --print(fullPath .. " deleted")
    end
end

local function deleteFolder(relativePath)
    local dataFolder = SrvDupe.DataFolder
    local pathFolder = dataFolder .. "/" .. relativePath

    if not file.Exists(pathFolder, "DATA") then
        return
    end

    local files, folders = file.Find(pathFolder .. "/*", "DATA")
    if files then
        for _, fileName in ipairs(files) do
            deleteFile(relativePath .. "/" .. fileName)
        end
    end

    if folders then
        for _, folderName in ipairs(folders) do
            deleteFolder(relativePath .. "/" .. folderName)
        end
    end

    file.Delete(pathFolder)
    --print(pathFolder .. " deleted")
end

local function deleteFileOrFolder(relativePath, ply)
    local dataFolder = SrvDupe.DataFolder
    local fullPath = dataFolder .. "/" .. relativePath

    if not file.Exists(fullPath, "DATA") then
        SrvDupe.Notify("File or folder does not exist!", 1, nil, ply, false)
        return
    end

    if file.IsDir(fullPath, "DATA") then
        deleteFolder(relativePath)
    else
        deleteFile(relativePath)
    end
end

net.Receive("SrvDupe_FileClientToServer", SrvDupe.HandleFileStream)

net.Receive("SrvDupe_AskServerForFile", function(_, ply)
    if not SrvDupe.CheckPlyWritePermissions(ply) then
        SrvDupe.Notify("Not enough permissions", 1, nil, ply, true)
        return
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

net.Receive("SrvDupe_AskServerForFileDelete", function(_, ply)
    if not SrvDupe.CheckPlyWritePermissions(ply) then
        SrvDupe.Notify("Not enough permissions", 1, nil, ply, true)
        return
    end

    local relativePath = net.ReadString()

    deleteFileOrFolder(relativePath, ply)

    SrvDupe.Notify("Deleted successfully!", 0, nil, ply, false)
    net.Start("SrvDupe_BroadcastChange")
    net.Broadcast()
end)

net.Receive("SrvDupe_AskServerForAddFolder", function(_, ply)
    if not SrvDupe.CheckPlyWritePermissions(ply) then
        SrvDupe.Notify("Not enough permissions", 1, nil, ply, true)
        return
    end

    local relativePath = net.ReadString()
    local dataFolder = SrvDupe.DataFolder
    local fullPath = dataFolder .. "/" .. relativePath

    if file.Exists(fullPath, "DATA") then
        SrvDupe.Notify("Folder already exists!", 1, nil, ply)
        return
    end

    file.CreateDir(fullPath)

    SrvDupe.Notify("Folder created successfully!", 0, nil, ply, false)
    net.Start("SrvDupe_BroadcastChange")
    net.Broadcast()
end)

net.Receive("SrvDupe_AskServerForFileMove", function(_, ply)
    if not SrvDupe.CheckPlyWritePermissions(ply) then
        SrvDupe.Notify("Not enough permissions", 1, nil, ply, true)
        return
    end

    local oldPath = net.ReadString()
    local newPath = net.ReadString()

    local dataFolder = SrvDupe.DataFolder
    local fullOldPath = dataFolder .. "/" .. oldPath
    local fullNewPath = dataFolder .. "/" .. newPath

    if not file.Exists(fullOldPath, "DATA") then
        SrvDupe.Notify("File does not exist!", 1, nil, ply, true)
        return
    end

    if file.Exists(fullNewPath, "DATA") then
        SrvDupe.Notify("File already exists at the new location!", 1, nil, ply, true)
        return
    end

    local contentOld = file.Read(fullOldPath, "DATA")

    file.Write(fullNewPath, contentOld)
    file.Delete(fullOldPath)

    SrvDupe.Notify("File moved successfully!", 0, nil, ply, false)
    net.Start("SrvDupe_BroadcastChange")
    net.Broadcast()
end)