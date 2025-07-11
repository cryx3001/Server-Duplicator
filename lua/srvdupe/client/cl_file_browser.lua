--[[
	Title: Adv. Dupe 2 File Browser

	Desc: Displays and interfaces with duplication files.

	Author: TB

	Version: 1.0
]]

if SERVER then return end

local History = {}
local Narrow = {}

local switch = true
local count = 0
local srvdupe_folder = nil

local function AddHistory(txt)
    txt = string.lower(txt)
    local char1 = txt[1]
    local char2
    for i = 1, #History do
        char2 = History[i][1]
        if (char1 == char2) then
            if (History[i] == txt) then
                return
            end
        elseif (char1 < char2) then
            break
        end
    end

    table.insert(History, txt)
    table.sort(History, function(a, b) return a < b end)
end

local function NarrowHistory(txt, last)
    txt = string.lower(txt)
    local temp = {}
    if (last <= #txt and last ~= 0 and #txt ~= 1) then
        for i = 1, #Narrow do
            if (Narrow[i][last + 1] == txt[last + 1]) then
                table.insert(temp, Narrow[i])
            elseif (Narrow[i][last + 1] ~= '') then
                break
            end
        end
    else
        local char1 = txt[1]
        local char2
        for i = 1, #History do
            char2 = History[i][1]
            if (char1 == char2) then
                if (#txt > 1) then
                    for k = 2, #txt do
                        if (txt[k] ~= History[i][k]) then
                            break
                        end
                        if (k == #txt) then
                            table.insert(temp, History[i])
                        end
                    end
                else
                    table.insert(temp, History[i])
                end
            elseif (char1 < char2) then
                break
            end
        end
    end

    Narrow = temp
end

local function tableSortNodes(tbl)
    for k, v in ipairs(tbl) do tbl[k] = {string.lower(v.Label:GetText()), v} end
    table.sort(tbl, function(a,b) return a[1]<b[1] end)
    for k, v in ipairs(tbl) do tbl[k] = v[2] end
end

local BROWSERPNL = {}
AccessorFunc(BROWSERPNL, "m_bBackground", "PaintBackground", FORCE_BOOL)
AccessorFunc(BROWSERPNL, "m_bgColor", "BackgroundColor")
Derma_Hook(BROWSERPNL, "Paint", "Paint", "Panel")
Derma_Hook(BROWSERPNL, "PerformLayout", "Layout", "Panel")

local setbrowserpnlsize
local function SetBrowserPnlSize(self, x, y)
    setbrowserpnlsize(self, x, y)
    self.pnlCanvas:SetWide(x)
    self.pnlCanvas.VBar:SetUp(y, self.pnlCanvas:GetTall())
end

function BROWSERPNL:Init()
    setbrowserpnlsize = self.SetSize
    self.SetSize = SetBrowserPnlSize
    self.pnlCanvas = vgui.Create("srvdupe_browser_tree", self)

    self:SetPaintBackground(true)
    self:SetPaintBackgroundEnabled(false)
    self:SetPaintBorderEnabled(false)
    self:SetBackgroundColor(self:GetSkin().text_bright)
end

function BROWSERPNL:OnVScroll(iOffset)
    self.pnlCanvas:SetPos(0, iOffset)
end

derma.DefineControl("srvdupe_browser_panel", "Server Dupe File Browser", BROWSERPNL, "Panel")

local BROWSER = {}
AccessorFunc(BROWSER, "m_pSelectedItem", "SelectedItem")
Derma_Hook(BROWSER, "Paint", "Paint", "Panel")

local origSetTall
local function SetTall(self, val)
    origSetTall(self, val)
    self.VBar:SetUp(self:GetParent():GetTall(), self:GetTall())
end

function BROWSER:Init()
    self:SetTall(0)
    origSetTall = self.SetTall
    self.SetTall = SetTall

    self.VBar = vgui.Create("DVScrollBar", self:GetParent())
    self.VBar:Dock(RIGHT)
    self.Nodes = 0
    self.ChildrenExpanded = {}
    self.ChildList = self
    self.m_bExpanded = true
    self.Folders = {}
    self.Files = {}
    self.LastClick = CurTime()
end

local function GetNodePath(node)
    local path = node.Label:GetText()
    local area = 0
    local name = ""
    node = node.ParentNode
    if (not node.ParentNode) then
        if (path == "Server Dupes") then
            area = 1
        end
        return "", area
    end

    while (true) do
        name = node.Label:GetText()
        if (name == "advdupe2/") then
            break
        elseif (name == "Server Dupes") then
            area = 1
            break
        end
        path = name .. "/" .. path
        node = node.ParentNode
    end

    return path, area
end

function BROWSER:DoNodeLeftClick(node)
    if (self.m_pSelectedItem == node and CurTime() - self.LastClick <= 0.25) then -- Check for double click
        if (node.Derma.ClassName == "srvdupe_browser_folder") then
            if (node.Expander) then
                node:SetExpanded() -- It's a folder, expand/collapse it
            end
        end
    else
        self:SetSelected(node) -- A node was clicked, select it
    end
    self.LastClick = CurTime()
end

local function CollapseChildren(node)
    node.m_bExpanded = false
    if (node.Expander) then
        node.Expander:SetExpanded(false)
        node.ChildList:SetTall(0)
        for i = 1, #node.ChildrenExpanded do
            CollapseChildren(node.ChildrenExpanded[i])
        end
        node.ChildrenExpanded = {}
    end
end

local function GetFullPath(node)
    local path, area = GetNodePath(node)
    if (area == 0) then
        path = SrvDupe.AdvDupe2_Data .. "/" .. path .. "/"
    elseif (area == 1) then

    else
        path = "adv_duplicator/" .. path .. "/"
    end
    return path
end

local function addOptionsFileClientside(Menu, node)
    Menu:AddOption("Upload", function()
        local path, _ = GetNodePath(node)
        local dataFolder = SrvDupe.AdvDupe2_Data
        local fullPath = dataFolder .. "/" .. path

        local fileExists = file.Exists(fullPath, "DATA")
        if not fileExists then
            SrvDupe.Notify("File does not exists anymore!", 1, nil)
            return
        end

        local content = file.Read(fullPath, "DATA")

        SrvDupe.SendFile(node.Label:GetText(), content)
    end)
end

local function optionDelete(node, parent)
    parent.Submit:SetMaterial("icon16/bin_empty.png")
    parent.Submit:SetTooltip("Delete File")
    parent.FileName:SetVisible(false)
    parent.Desc:SetVisible(false)
    if (#node.Label:GetText() > 22) then
        parent.Info:SetText(
            'Are you sure that you want to delete \nthe FILE, "' ..
                node.Label:GetText() .. '" \nSERVERSIDE?')
    else
        parent.Info:SetText(
            'Are you sure that you want to delete \nthe FILE, "' ..
                node.Label:GetText() .. '" SERVERSIDE?')
    end
    parent.Info:SetTextColor(color_black)
    parent.Info:SizeToContents()
    parent.Info:SetVisible(true)
    SrvDupe.FileBrowser:Slide(true)
    parent.Submit.DoClick = function()
        local path, _ = GetNodePath(node)
        if not path or path == "" then
            return
        end

        net.Start("SrvDupe_AskServerForFileDelete")
        net.WriteString(path)
        net.SendToServer()
        
        SrvDupe.FileBrowser:Slide(false)
    end
end

local function addOptionsFileServerside(Menu, node, parent)
    Menu:AddOption("Rename", function()

    end)

    Menu:AddOption("Move", function()
        parent.Submit:SetMaterial("icon16/page_paste.png")
        parent.Submit:SetTooltip("Move file")
        parent.FileName:SetVisible(false)
        parent.Desc:SetVisible(false)
        parent.Info:SetText(
            "Select the folder you want to move \nthe file to.")
        parent.Info:SetTextColor(color_black)
        parent.Info:SizeToContents()
        parent.Info:SetVisible(true)
        SrvDupe.FileBrowser:Slide(true)
        node.Control.ActionNode = node
        parent.Submit.DoClick = function()
            local selectedNode = node.Control.m_pSelectedItem
            if (not selectedNode) then
                SrvDupe.Notify("No folder selected", 1, nil)
                return
            end

            local node2 = selectedNode.Control.ActionNode
            local path, area = GetNodePath(node2)
            local path2, area2 = GetNodePath(selectedNode)

            if (area ~= area2 or path == path2) then
                SrvDupe.Notify("You can't move files to this folder", 1, nil)
                return
            end

            local newPath = path2 .. "/" .. node2.Label:GetText()
            local oldPath = path

            net.Start("SrvDupe_AskServerForFileMove")
            net.WriteString(oldPath)
            net.WriteString(newPath)
            net.SendToServer()

            SrvDupe.FileBrowser:Slide(false)
            SrvDupe.FileBrowser.Info:SetVisible(false)
        end
    end)

    Menu:AddOption("Delete", function()
        optionDelete(node, parent)
    end)

    Menu:AddOption("Copy path to clipboard", function()
        local path, _ = GetNodePath(node)
        SetClipboardText(path)
        SrvDupe.Notify("Copied to clipboard!", 0, nil)
    end)

    Menu:AddSpacer()

    Menu:AddOption("Download", function()
        local path, _ = GetNodePath(node)

        net.Start("SrvDupe_AskServerForFile")
            net.WriteString(path)
        net.SendToServer()
    end)
end

local function addOptionsFolderServerside(Menu, node, parent)
    Menu:AddOption("New Folder", function()
        if (parent.Expanding) then return end
        parent.Submit:SetMaterial("icon16/folder_add.png")
        parent.Submit:SetTooltip("Add new folder")
        if (parent.FileName:GetValue() == "file_name") then
            parent.FileName:SetText("folder_name")
        end
        parent.Desc:SetVisible(false)
        parent.Info:SetVisible(false)
        parent.FileName.FirstChar = true
        parent.FileName.PrevText = parent.FileName:GetValue()
        parent.FileName:SetVisible(true)
        parent.FileName:SelectAllOnFocus(true)
        parent.FileName:OnMousePressed()
        parent.FileName:RequestFocus()
        parent.Expanding = true
        SrvDupe.FileBrowser:Slide(true)

        parent.Submit.DoClick = function()
            if not node.Control then
                return
            end
            local Controller = node.Control:GetParent():GetParent()
            local name = Controller.FileName:GetValue() or ""
            local char = string.match(name, "[^%w_ ]")
            if char or name == "" then
                SrvDupe.Notify("Invalid folder name", 1, nil)
                return
            end

            local path, _ = GetNodePath(node)
            if not path then
                return
            end
            path = path .. "/" .. name

            net.Start("SrvDupe_AskServerForAddFolder")
            net.WriteString(path)
            net.SendToServer()

            SrvDupe.FileBrowser:Slide(false)
        end
        parent.FileName.OnEnter = parent.Submit.DoClick
    end)

    Menu:AddOption("Delete", function()
        optionDelete(node, parent)
    end)
end

function BROWSER:DoNodeRightClick(node)
    self:SetSelected(node)

    local parent = self:GetParent():GetParent()
    parent.FileName:KillFocus()
    parent.Desc:KillFocus()
    local Menu = DermaMenu()

    local path, area = GetNodePath(node)

    if (node.Derma.ClassName == "srvdupe_browser_file") then
        if area == 0 then
            addOptionsFileClientside(Menu, node)
        end
        if area == 1 then
            addOptionsFileServerside(Menu, node, parent)
        end
    end

    if node.Derma.ClassName == "srvdupe_browser_folder" then
        if area == 1 then
            addOptionsFolderServerside(Menu, node, parent)
        end
    end

    Menu:Open()
end

local function CollapseParents(node, val)
    if (not node) then return end
    node.ChildList:SetTall(node.ChildList:GetTall() - val)
    CollapseParents(node.ParentNode, val)
end

function BROWSER:RemoveNode(node)
    local parent = node.ParentNode
    parent.Nodes = parent.Nodes - 1
    if (node.IsFolder) then
        if (node.m_bExpanded) then
            CollapseParents(parent, node.ChildList:GetTall() + 20)
            for i = 1, #parent.ChildrenExpanded do
                if (node == parent.ChildrenExpanded[i]) then
                    table.remove(parent.ChildrenExpanded, i)
                    break
                end
            end
        elseif (parent.m_bExpanded) then
        CollapseParents(parent, 20)
        end
        for i = 1, #parent.Folders do
            if (node == parent.Folders[i]) then
                table.remove(parent.Folders, i)
            end
        end
        node.ChildList:Remove()
        node:Remove()
    else
        for i = 1, #parent.Files do
            if (node == parent.Files[i]) then
                table.remove(parent.Files, i)
            end
        end
        CollapseParents(parent, 20)
        node:Remove()
        if (#parent.Files == 0 and #parent.Folders == 0) then
            parent.Expander:Remove()
            parent.Expander = nil
            parent.m_bExpanded = false
        end
    end
    if (self.VBar.Scroll > self.VBar.CanvasSize) then
        self.VBar:SetScroll(self.VBar.Scroll)
    end
    if (self.m_pSelectedItem) then
        self.m_pSelectedItem = nil
    end
end

function BROWSER:OnMouseWheeled(dlta)
    return self.VBar:OnMouseWheeled(dlta)
end

function BROWSER:AddFolder(text)
    local node = vgui.Create("srvdupe_browser_folder", self)
    node.Control = self

    node.Offset = 0
    node.ChildrenExpanded = {}
    node.Icon:SetPos(18, 1)
    node.Label:SetPos(44, 0)
    node.Label:SetText(text)
    node.Label:SizeToContents()
    node.ParentNode = self
    node.IsFolder = true
    self.Nodes = self.Nodes + 1
    node.Folders = {}
    node.Files = {}
    table.insert(self.Folders, node)
    self:SetTall(self:GetTall() + 20)

    return node
end

function BROWSER:AddFile(text)
    local node = vgui.Create("srvdupe_browser_file", self)
    node.Control = self
    node.Offset = 0
    node.Icon:SetPos(18, 1)
    node.Label:SetPos(44, 0)
    node.Label:SetText(text)
    node.Label:SizeToContents()
    node.ParentNode = self
    self.Nodes = self.Nodes + 1
    table.insert(self.Files, node)
    self:SetTall(self:GetTall() + 20)

    return node
end

function BROWSER:Sort(node)
    tableSortNodes(node.Folders)
    tableSortNodes(node.Files)

    for i = 1, #node.Folders do
        node.Folders[i]:SetParent(nil)
        node.Folders[i]:SetParent(node.ChildList)
        node.Folders[i].ChildList:SetParent(nil)
        node.Folders[i].ChildList:SetParent(node.ChildList)
    end
    for i = 1, #node.Files do
        node.Files[i]:SetParent(nil)
        node.Files[i]:SetParent(node.ChildList)
    end
end

function BROWSER:SetSelected(node)
    if (IsValid(self.m_pSelectedItem)) then
        self.m_pSelectedItem:SetSelected(false)
    end
    self.m_pSelectedItem = node
    if (node) then node:SetSelected(true) end
end

local function ExpandParents(node, val)
    if (not node) then return end
    node.ChildList:SetTall(node.ChildList:GetTall() + val)
    ExpandParents(node.ParentNode, val)
end

function BROWSER:Expand(node)
    node.ChildList:SetTall(node.Nodes * 20)
    table.insert(node.ParentNode.ChildrenExpanded, node)
    ExpandParents(node.ParentNode, node.Nodes * 20)
end

local function ExtendParents(node)
    if (not node) then return end
    node.ChildList:SetTall(node.ChildList:GetTall() + 20)
    ExtendParents(node.ParentNode)
end

function BROWSER:Extend(node)
    node.ChildList:SetTall(node.ChildList:GetTall() + 20)
    ExtendParents(node.ParentNode)
end

function BROWSER:Collapse(node)
    CollapseParents(node.ParentNode, node.ChildList:GetTall())

    for i = 1, #node.ParentNode.ChildrenExpanded do
        if (node.ParentNode.ChildrenExpanded[i] == node) then
            table.remove(node.ParentNode.ChildrenExpanded, i)
            break
        end
    end
    CollapseChildren(node)
end

derma.DefineControl("srvdupe_browser_tree", "Server Dupe File Browser", BROWSER, "Panel")

local FOLDER = {}

AccessorFunc(FOLDER, "m_bBackground", "PaintBackground", FORCE_BOOL)
AccessorFunc(FOLDER, "m_bgColor", "BackgroundColor")

Derma_Hook(FOLDER, "Paint", "Paint", "Panel")

function FOLDER:Init()
    self:SetMouseInputEnabled(true)

    self:SetTall(20)
    self:SetPaintBackground(true)
    self:SetPaintBackgroundEnabled(false)
    self:SetPaintBorderEnabled(false)
    self:SetBackgroundColor(Color(0, 0, 0, 0))

    self.Icon = vgui.Create("DImage", self)
    self.Icon:SetImage("icon16/folder.png")

    self.Icon:SizeToContents()

    self.Label = vgui.Create("DLabel", self)
    self.Label:SetDark(true)

    self.m_bExpanded = false
    self.Nodes = 0
    self.ChildrenExpanded = {}

    self:Dock(TOP)

    self.ChildList = vgui.Create("Panel", self:GetParent())
    self.ChildList:Dock(TOP)
    self.ChildList:SetTall(0)
end

local function ExpandNode(self)
    self:GetParent():SetExpanded()
end

function FOLDER:AddFolder(text)
    if (self.Nodes == 0) then
        self.Expander = vgui.Create("DExpandButton", self)
        self.Expander.DoClick = ExpandNode
        self.Expander:SetPos(self.Offset, 2)
    end

    local node = vgui.Create("srvdupe_browser_folder", self.ChildList)
    node.Control = self.Control

    node.Offset = self.Offset + 20

    node.Icon:SetPos(18 + node.Offset, 1)
    node.Label:SetPos(44 + node.Offset, 0)
    node.Label:SetText(text)
    node.Label:SizeToContents()
    node.Label:SetDark(true)
    node.ParentNode = self
    node.IsFolder = true
    node.Folders = {}
    node.Files = {}

    self.Nodes = self.Nodes + 1
    self.Folders[#self.Folders + 1] = node

    if (self.m_bExpanded) then
        self.Control:Extend(self)
    end
    self.Control:Sort(self)

    return node
end

function FOLDER:Clear()
    for _, node in ipairs(self.Folders) do
        node:Remove() end
    for _, node in ipairs(self.Files) do
        node:Remove() end
    self.Nodes = 0
end

function FOLDER:DeepClear()
    for _, node in ipairs(self.Folders) do
        node:Clear()
    end
    self:Clear()
end

function FOLDER:AddFile(text)
    if (self.Nodes == 0) then
        self.Expander = vgui.Create("DExpandButton", self)
        self.Expander.DoClick = ExpandNode
        self.Expander:SetPos(self.Offset, 2)
    end

    local node = vgui.Create("srvdupe_browser_file", self.ChildList)
    node.Control = self.Control
    node.Offset = self.Offset + 20
    node.Icon:SetPos(18 + node.Offset, 1)
    node.Label:SetPos(44 + node.Offset, 0)
    node.Label:SetText(text)
    node.Label:SizeToContents()
    node.Label:SetDark(true)
    node.ParentNode = self

    self.Nodes = self.Nodes + 1
    table.insert(self.Files, node)

    if (self.m_bExpanded) then
        self.Control:Extend(self)
    end

    return node
end

local function LoadServerDataContent(tbl, ParentNode)
    local function rec_LoadContent(_tbl, _ParentNode)
        for k, v in pairs(_tbl) do
            local isDir = istable(v)

            if isDir then
                local folder = _ParentNode:AddFolder(k)
                rec_LoadContent(v, folder)
            else
                _ParentNode:AddFile(v)
            end
        end
    end

    rec_LoadContent(tbl, ParentNode)
    ParentNode.Control:Sort(ParentNode)
end

function FOLDER:LoadDataFolder(folderPath)
    if folderPath == "SERVER_DATA" then
        net.Start("SrvDupe_AskServerDataContent")
        net.SendToServer()
        return
    end

    self:Clear()
    self.LoadingPath = folderPath
    self.LoadingFiles, self.LoadingDirectories = file.Find(folderPath .. "*", "DATA", "nameasc")
    if self.LoadingFiles == nil then self.LoadingFiles = {} end
    if self.LoadingDirectories == nil then self.LoadingDirectories = {} end
    self.FileI, self.DirI = 1, 1
    self.LoadingFirst = true
end

function FOLDER:Think()
    if self.LoadingPath then
        local path, files, dirs, fileI, dirI = self.LoadingPath, self.LoadingFiles, self.LoadingDirectories, self.FileI, self.DirI
        if dirI > #dirs then
            if fileI > #files then
                self.LoadingPath = nil
                return
            else
                local fileName = files[fileI]
                local fileNode = self:AddFile(fileName)
                fileI = fileI + 1
            end
        else
            local dirName = dirs[dirI]
            local dirNode = self:AddFolder(dirName)
            dirNode:LoadDataFolder(path .. dirName .. "/")
            dirI = dirI + 1
        end

        self.FileI = fileI
        self.DirI = dirI
    end
end


function FOLDER:SetExpanded(bool)
    if (not self.Expander) then return end
    if (bool == nil) then
        self.m_bExpanded = not self.m_bExpanded
    else
        self.m_bExpanded = bool
    end
    self.Expander:SetExpanded(self.m_bExpanded)
    if (self.m_bExpanded) then
        self.Control:Expand(self)
    else
        self.Control:Collapse(self)
    end
end

function FOLDER:SetSelected(bool)
    if (bool) then
        self:SetBackgroundColor(self:GetSkin().bg_color_bright)
    else
        self:SetBackgroundColor(Color(0, 0, 0, 0))
    end
end

function FOLDER:OnMousePressed(code)
    if (code == 107) then
        self.Control:DoNodeLeftClick(self)
    elseif (code == 108) then
        self.Control:DoNodeRightClick(self)
    end
end

derma.DefineControl("srvdupe_browser_folder", "Server Dupe Browser Folder node", FOLDER, "Panel")

local FILE = {}

AccessorFunc(FILE, "m_bBackground", "PaintBackground", FORCE_BOOL)
AccessorFunc(FILE, "m_bgColor", "BackgroundColor")
Derma_Hook(FILE, "Paint", "Paint", "Panel")

function FILE:Init()
    self:SetMouseInputEnabled(true)

    self:SetTall(20)
    self:SetPaintBackground(true)
    self:SetPaintBackgroundEnabled(false)
    self:SetPaintBorderEnabled(false)
    self:SetBackgroundColor(Color(0, 0, 0, 0))

    self.Icon = vgui.Create("DImage", self)
    self.Icon:SetImage("icon16/page.png")

    self.Icon:SizeToContents()

    self.Label = vgui.Create("DLabel", self)
    self.Label:SetDark(true)

    self:Dock(TOP)
end

function FILE:SetSelected(bool)
    if (bool) then
        self:SetBackgroundColor(self:GetSkin().bg_color_bright)
    else
        self:SetBackgroundColor(Color(0, 0, 0, 0))
    end
end

function FILE:OnMousePressed(code)
    if (code == 107) then
        self.Control:DoNodeLeftClick(self)
    elseif (code == 108) then
        self.Control:DoNodeRightClick(self)
    end
end

derma.DefineControl("srvdupe_browser_file", "Server Dupe Browser File node", FILE, "Panel")

local PANEL = {}
AccessorFunc(PANEL, "m_bBackground", "PaintBackground", FORCE_BOOL)
AccessorFunc(PANEL, "m_bgColor", "BackgroundColor")
Derma_Hook(PANEL, "Paint", "Paint", "Panel")
Derma_Hook(PANEL, "PerformLayout", "Layout", "Panel")

function PANEL:PerformLayout()
    if (self:GetWide() == self.LastX) then return end
    local x = self:GetWide()

    if (self.Search) then
        self.Search:SetWide(x)
    end

    self.Browser:SetWide(x)
    local x2, y2 = self.Browser:GetPos()
    local BtnX = x - self.Help:GetWide() - 5
    self.Help:SetPos(BtnX, 3)
    BtnX = BtnX - self.Refresh:GetWide() - 5
    self.Refresh:SetPos(BtnX, 3)

    BtnX = x - self.Submit:GetWide() - 15
    self.Cancel:SetPos(BtnX, self.Browser:GetTall() + 20)
    BtnX = BtnX - self.Submit:GetWide() - 5
    self.Submit:SetPos(BtnX, self.Browser:GetTall() + 20)

    self.FileName:SetWide(BtnX - 10)
    self.FileName:SetPos(5, self.Browser:GetTall() + 20)
    self.Desc:SetWide(x - 10)
    self.Desc:SetPos(5, self.Browser:GetTall() + 39)
    self.Info:SetPos(5, self.Browser:GetTall() + 20)

    self.LastX = x
end

local pnlorigsetsize
local function PanelSetSize(self, x, y)
    if (not self.LaidOut) then
        pnlorigsetsize(self, x, y)

        self.Browser:SetSize(x, y - 20)
        self.Browser:SetPos(0, 20)

        if (self.Search) then
            self.Search:SetSize(x, y - 20)
            self.Search:SetPos(0, 20)
        end

        self.LaidOut = true
    else
        pnlorigsetsize(self, x, y)
    end

end

local function UpdateClientFiles()
    if not SrvDupe.FileBrowser or not SrvDupe.FileBrowser.Browser then return end

    local pnlCanvas = SrvDupe.FileBrowser.Browser.pnlCanvas

    for i = 1, 2 do
        if (pnlCanvas.Folders[1]) then
            pnlCanvas:RemoveNode(pnlCanvas.Folders[1])
        end
    end

    local advdupe2 = pnlCanvas:AddFolder("advdupe2/")
    srvdupe_folder = pnlCanvas:AddFolder("Server Dupes")

    advdupe2:LoadDataFolder("advdupe2/")
    srvdupe_folder:LoadDataFolder("SERVER_DATA")

--[[
    if (pnlCanvas.Folders[2]) then
        if (#pnlCanvas.Folders[2].Folders == 0 and #pnlCanvas.Folders[2].Files == 0) then
            pnlCanvas:RemoveNode(pnlCanvas.Folders[2])
        end

        pnlCanvas.Folders[1]:SetParent(nil)
        pnlCanvas.Folders[1]:SetParent(pnlCanvas.ChildList)
        pnlCanvas.Folders[1].ChildList:SetParent(nil)
        pnlCanvas.Folders[1].ChildList:SetParent(pnlCanvas.ChildList)
    end
]]

end

function PANEL:Init()

    SrvDupe.FileBrowser = self
    self.Expanded = false
    self.Expanding = false
    self.LastX = 0
    self.LastY = 0
    pnlorigsetsize = self.SetSize
    self.SetSize = PanelSetSize

    self:SetPaintBackground(true)
    self:SetPaintBackgroundEnabled(false)
    self:SetBackgroundColor(self:GetSkin().bg_color_bright)

    self.Browser = vgui.Create("srvdupe_browser_panel", self)
    UpdateClientFiles()
    self.Refresh = vgui.Create("DImageButton", self)
    self.Refresh:SetMaterial("icon16/arrow_refresh.png")
    self.Refresh:SizeToContents()
    self.Refresh:SetTooltip("Refresh Files")
    self.Refresh.DoClick = function(button) UpdateClientFiles() end

    self.Help = vgui.Create("DImageButton", self)
    self.Help:SetMaterial("icon16/help.png")
    self.Help:SizeToContents()
    self.Help:SetTooltip("Help Section")
    self.Help.DoClick = function(btn)
        --[[
        local Menu = DermaMenu()
        Menu:AddOption("Bug Reporting", function()
            gui.OpenURL("https://github.com/wiremod/advdupe2/issues")
        end)
        Menu:AddOption("Controls", function()
            gui.OpenURL("https://github.com/wiremod/advdupe2/wiki/Controls")
        end)
        Menu:AddOption("Commands", function()
            gui.OpenURL(
                    "https://github.com/wiremod/advdupe2/wiki/Server-settings")
        end)
        Menu:Open()
        ]]--
    end

    self.Submit = vgui.Create("DImageButton", self)
    self.Submit:SetMaterial("icon16/page_save.png")
    self.Submit:SizeToContents()
    self.Submit:SetTooltip("Confirm Action")
    self.Submit.DoClick = function()
        self.Expanding = true
        SrvDupe.FileBrowser:Slide(false)
    end

    self.Cancel = vgui.Create("DImageButton", self)
    self.Cancel:SetMaterial("icon16/cross.png")
    self.Cancel:SizeToContents()
    self.Cancel:SetTooltip("Cancel Action")
    self.Cancel.DoClick = function()
        self.Expanding = true
        SrvDupe.FileBrowser:Slide(false)
    end

    self.FileName = vgui.Create("DTextEntry", self)
    self.FileName:SetAllowNonAsciiCharacters(true)
    self.FileName:SetText("file_name")
    self.FileName.Last = 0

    self.FileName.OnEnter = function()
        self.FileName:KillFocus()
        self.Desc:SelectAllOnFocus(true)
        self.Desc.OnMousePressed()
        self.Desc:RequestFocus()
    end
    self.FileName.OnMousePressed = function()
        self.FileName:OnGetFocus()
        if (self.FileName:GetValue() == "file_name" or
                self.FileName:GetValue() == "folder_name") then
            self.FileName:SelectAllOnFocus(true)
        end
    end
    self.FileName:SetUpdateOnType(true)
    self.FileName.OnTextChanged = function()

        if (self.FileName.FirstChar) then
            if (string.lower(self.FileName:GetValue()[1] or "") == string.lower(input.LookupBinding("menu") or "q")) then
                self.FileName:SetText(self.FileName.PrevText)
                self.FileName:SelectAll()
                self.FileName.FirstChar = false
            else
                self.FileName.FirstChar = false
            end
        end

        local new, changed = self.FileName:GetValue():gsub("[^%w_ ]", "")
        if changed > 0 then
            self.FileName:SetText(new)
            self.FileName:SetCaretPos(#new)
        end
        if (#self.FileName:GetValue() > 0) then
            NarrowHistory(self.FileName:GetValue(), self.FileName.Last)
            local options = {}
            if (#Narrow > 4) then
                for i = 1, 4 do table.insert(options, Narrow[i]) end
            else
                options = Narrow
            end
            if (#options ~= 0 and #self.FileName:GetValue() ~= 0) then
                self.FileName.HistoryPos = 0
                self.FileName:OpenAutoComplete(options)
                self.FileName.Menu.Attempts = 1
                if (#Narrow > 4) then
                    self.FileName.Menu:AddOption("...", function() end)
                end
            elseif (IsValid(self.FileName.Menu)) then
                self.FileName.Menu:Remove()
            end
        end
        self.FileName.Last = #self.FileName:GetValue()
    end
    self.FileName.OnKeyCodeTyped = function(txtbox, code)
        txtbox:OnKeyCode(code)

        if (code == KEY_ENTER and not txtbox:IsMultiline() and txtbox:GetEnterAllowed()) then
            if (txtbox.HistoryPos == 5 and txtbox.Menu:ChildCount() == 5) then
                if ((txtbox.Menu.Attempts + 1) * 4 < #Narrow) then
                    for i = 1, 4 do
                        txtbox.Menu:GetChild(i):SetText(Narrow[i + txtbox.Menu.Attempts * 4])
                    end
                else
                    txtbox.Menu:GetChild(5):Remove()
                    for i = 4, (txtbox.Menu.Attempts * 4 - #Narrow) * -1 + 1, -1 do
                        txtbox.Menu:GetChild(i):Remove()
                    end

                    for i = 1, #Narrow - txtbox.Menu.Attempts * 4 do
                        txtbox.Menu:GetChild(i):SetText(Narrow[i + txtbox.Menu.Attempts * 4])
                    end
                end
                txtbox.Menu:ClearHighlights()
                txtbox.Menu:HighlightItem(txtbox.Menu:GetChild(1))
                txtbox.HistoryPos = 1
                txtbox.Menu.Attempts = txtbox.Menu.Attempts + 1
                return true
            end

            if (IsValid(txtbox.Menu)) then
                txtbox.Menu:Remove()
            end
            txtbox:FocusNext()
            txtbox:OnEnter()
            txtbox.HistoryPos = 0
        end

        if (txtbox.m_bHistory or IsValid(txtbox.Menu)) then
            if (code == KEY_UP) then
                txtbox.HistoryPos = txtbox.HistoryPos - 1;
                if (txtbox.HistoryPos ~= -1 or txtbox.Menu:ChildCount() ~= 5) then
                    txtbox:UpdateFromHistory()
                else
                    txtbox.Menu:ClearHighlights()
                    txtbox.Menu:HighlightItem(txtbox.Menu:GetChild(5))
                    txtbox.HistoryPos = 5
                end
            end
            if (code == KEY_DOWN or code == KEY_TAB) then
                txtbox.HistoryPos = txtbox.HistoryPos + 1;
                if (txtbox.HistoryPos ~= 5 or txtbox.Menu:ChildCount() ~= 5) then
                    txtbox:UpdateFromHistory()
                else
                    txtbox.Menu:ClearHighlights()
                    txtbox.Menu:HighlightItem(txtbox.Menu:GetChild(5))
                end
            end

        end
    end
    self.FileName.OnValueChange = function()
        if (self.FileName:GetValue() ~= "file_name" and
                self.FileName:GetValue() ~= "folder_name") then
            local new, changed = self.FileName:GetValue():gsub("[^%w_ ]", "")
            if changed > 0 then
                self.FileName:SetText(new)
                self.FileName:SetCaretPos(#new)
            end
        end
    end

    self.Desc = vgui.Create("DTextEntry", self)
    self.Desc.OnEnter = self.Submit.DoClick
    self.Desc:SetText("Description...")
    self.Desc.OnMousePressed = function()
        self.Desc:OnGetFocus()
        if (self.Desc:GetValue() == "Description...") then
            self.Desc:SelectAllOnFocus(true)
        end
    end

    self.Info = vgui.Create("DLabel", self)
    self.Info:SetVisible(false)

end

function PANEL:Slide(expand)
    if (expand) then
        if (self.Expanded) then
            self:SetTall(self:GetTall() - 40)
            self.Expanded = false
        else
            self:SetTall(self:GetTall() + 5)
        end
    else
        if (not self.Expanded) then
            self:SetTall(self:GetTall() + 40)
            self.Expanded = true
        else
            self:SetTall(self:GetTall() - 5)
        end
    end
    count = count + 1
    if (count < 9) then
        timer.Simple(0.01, function() self:Slide(expand) end)
    else
        if (expand) then
            self.Expanded = true
        else
            self.Expanded = false
        end
        self.Expanding = false
        count = 0
    end
end

function PANEL:GetFullPath(node)
    return GetFullPath(node)
end

function PANEL:GetNodePath(node)
    return GetNodePath(node)
end

net.Receive("SrvDupe_SendServerDataContent", function()
    local tbl = net.ReadTable()
    LoadServerDataContent(tbl, srvdupe_folder)

    --timer.Create("SrvDupe_autoRefresh", 5, 0, function()
    --    net.Start("SrvDupe_AskServerDataContent")
    --    net.SendToServer()
    --    return
    --end)
end)

if (game.SinglePlayer()) then
    net.Receive("SrvDupe_AddFile", function()
        local asvNode = SrvDupe.FileBrowser.AutoSaveNode
        local actNode = SrvDupe.FileBrowser.Browser.pnlCanvas.ActionNode
        if (net.ReadBool()) then
            if (IsValid(asvNode)) then
                local name = net.ReadString()
                for iD = 1, #asvNode.Files do
                    if (name == asvNode.Files[i]) then return end
                end
                asvNode:AddFile(name)
                asvNode.Control:Sort(asvNode)
            end
        else
            actNode:AddFile(net.ReadString())
            actNode.Control:Sort(actNode)
        end
    end)
end

net.Receive("SrvDupe_BroadcastChange", function()
    UpdateClientFiles()
end)

vgui.Register("srvdupe_browser", PANEL, "Panel")