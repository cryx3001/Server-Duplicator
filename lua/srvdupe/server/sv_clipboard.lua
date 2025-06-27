-- From https://github.com/wiremod/advdupe2/blob/master/lua/advdupe2/sv_clipboard.lua

--[[
	Title: Adv. Duplicator 2 Module
	Desc: Provides advanced duplication functionality for the Adv. Dupe 2 tool.
	Author: TB
	Version: 1.0
]]

require( "duplicator" )

SrvDupe.duplicator = {}

SrvDupe.JobManager = {}
SrvDupe.JobManager.PastingHook = false
SrvDupe.JobManager.Queue = {}

local gtSetupTable = {
    SERIAL = {
        [TYPE_BOOL]   = true,
        [TYPE_ANGLE]  = true,
        [TYPE_TABLE]  = true,
        [TYPE_NUMBER] = true,
        [TYPE_VECTOR] = true,
        [TYPE_STRING] = true
    },
    CONSTRAINT = {
        Weld       = true,
        Axis       = true,
        Rope       = true,
        Motor      = true,
        Winch      = true,
        Muscle     = true,
        Pulley     = true,
        Slider     = true,
        Elastic    = true,
        Hydraulic  = true,
        Ballsocket = true
    },
    COMPARE = {
        V1 = Vector(1, 1, 1),
        A0 = Angle (0, 0, 0),
        V0 = Vector(0, 0, 0)
    },
    POS = {
        pos      = true,
        Pos      = true,
        position = true,
        Position = true
    },
    ANG = {
        ang   = true,
        Ang   = true,
        angle = true,
        Angle = true
    },
    MODEL = {
        model = true,
        Model = true
    },
    PLAYER = {
        pl  = true,
        ply = true
    },
    ENT1 = {
        Ent  = true,
        Ent1 = true,
    },
    TVEHICLE = {
        VehicleTable = true
    },
    SPECIAL = {
        Data = true
    }
}

--[[
	Name: CreateConstraintFromTable
	Desc: Creates a constraint from a given table
	Params: <table>Constraint, <table> EntityList, <table> EntityTable
	Returns: <entity> CreatedConstraint
]]
local function CreateConstraintFromTable(Constraint, EntityList, EntityTable, Player, DontEnable)
    local Factory = duplicator.ConstraintType[Constraint.Type]
    if not Factory then return end

    local first, firstindex -- Ent1 or Ent in the constraint's table
    local second, secondindex -- Any other Ent that is not Ent1 or Ent
    local Args = {} -- Build the argument list for the Constraint's spawn function
    for k, Key in ipairs(Factory.Args) do

        local Val = Constraint[Key]

        if gtSetupTable.PLAYER[Key] then Val = Player end

        for i = 1, 4 do
            if (Constraint.Entity and Constraint.Entity[i]) then
                if Key == "Ent" .. i or Key == "Ent" then
                    if (Constraint.Entity[i].World) then
                        Val = game.GetWorld()
                    else
                        Val = EntityList[Constraint.Entity[i].Index]

                        if not IsValid(Val) then
                            if (Player) then
                                Player:ChatPrint("DUPLICATOR: ERROR, " .. Constraint.Type .. " Constraint could not find an entity!")
                            else
                                print("DUPLICATOR: ERROR, " .. Constraint.Type .. " Constraint could not find an entity!")
                            end
                            return
                        else
                            if (IsValid(Val:GetPhysicsObject())) then
                                Val:GetPhysicsObject():EnableMotion(false)
                            end
                            -- Important for perfect duplication
                            -- Get which entity is which so we can reposition them before constraining
                            if (gtSetupTable.ENT1[Key]) then
                                first = Val
                                firstindex = Constraint.Entity[i].Index
                            else
                                second = Val
                                secondindex = Constraint.Entity[i].Index
                            end

                        end
                    end

                end

                if Key == "Bone" .. i or Key == "Bone" then
                    Val = Constraint.Entity[i].Bone or 0
                end

                if Key == "LPos" .. i then
                    if (Constraint.Entity[i].World and Constraint.Entity[i].LPos) then
                        if (i == 2 or i == 4) then
                            Val = Constraint.Entity[i].LPos + EntityList[Constraint.Entity[1].Index]:GetPos()
                        elseif (i == 1) then
                            if (Constraint.Entity[2]) then
                                Val = Constraint.Entity[i].LPos + EntityList[Constraint.Entity[2].Index]:GetPos()
                            else
                                Val = Constraint.Entity[i].LPos + EntityList[Constraint.Entity[4].Index]:GetPos()
                            end
                        end
                    elseif (Constraint.Entity[i].LPos) then
                        Val = Constraint.Entity[i].LPos
                    end
                end

                if Key == "Length" .. i then
                    Val = Constraint.Entity[i].Length
                end
            end
            if Key == "WPos" .. i then
                if (not Constraint.Entity[1].World) then
                    Val = Constraint[Key] + EntityList[Constraint.Entity[1].Index]:GetPos()
                else
                    Val = Constraint[Key] + EntityList[Constraint.Entity[4].Index]:GetPos()
                end
            end

        end

        Args[k] = Val
    end

    local Bone1, Bone1Index, ReEnableFirst
    local Bone2, Bone2Index, ReEnableSecond
    local buildInfo = Constraint.BuildDupeInfo
    if (buildInfo) then

        if first ~= nil and second ~= nil and not second:IsWorld() and buildInfo.EntityPos ~= nil then
            local SecondPhys = second:GetPhysicsObject()
            if IsValid(SecondPhys) then
                if not DontEnable then ReEnableSecond = SecondPhys:IsMoveable() end
                SecondPhys:EnableMotion(false)
                second:SetPos(first:GetPos() - buildInfo.EntityPos)
                if (buildInfo.Bone2) then
                    Bone2Index = buildInfo.Bone2
                    Bone2 = second:GetPhysicsObjectNum(Bone2Index)
                    if IsValid(Bone2) then
                        Bone2:EnableMotion(false)
                        Bone2:SetPos(second:GetPos() + buildInfo.Bone2Pos)
                        Bone2:SetAngles(buildInfo.Bone2Angle)
                    end
                end
            end
        end

        if first ~= nil and not first:IsWorld() and buildInfo.Ent1Ang ~= nil then
            local FirstPhys = first:GetPhysicsObject()
            if IsValid(FirstPhys) then
                if not DontEnable then ReEnableFirst = FirstPhys:IsMoveable() end
                FirstPhys:EnableMotion(false)
                first:SetAngles(buildInfo.Ent1Ang)
                if (buildInfo.Bone1) then
                    Bone1Index = buildInfo.Bone1
                    Bone1 = first:GetPhysicsObjectNum(Bone1Index)
                    if IsValid(Bone1) then
                        Bone1:EnableMotion(false)
                        Bone1:SetPos(first:GetPos() + buildInfo.Bone1Pos)
                        Bone1:SetAngles(buildInfo.Bone1Angle)
                    end
                end
            end
        end

        if second ~= nil and not second:IsWorld() then
            if buildInfo.Ent2Ang ~= nil then
                second:SetAngles(buildInfo.Ent2Ang)
            elseif buildInfo.Ent4Ang ~= nil then
                second:SetAngles(buildInfo.Ent4Ang)
            end
        end
    end

    local ok, Ent = pcall(Factory.Func, unpack(Args, 1, #Factory.Args))

    if not ok or not Ent then
        if (Player) then
            SrvDupe.Notify("ERROR, Failed to create " .. Constraint.Type .. " Constraint!", 0, nil, Player)
        else
            print("DUPLICATOR: ERROR, Failed to create " .. Constraint.Type .. " Constraint!")
        end
        return
    end

    Ent.BuildDupeInfo = table.Copy(buildInfo)

    -- Move the entities back after constraining them. No point in moving the world though.
    if (EntityTable) then
        local fEnt = EntityTable[firstindex]
        local sEnt = EntityTable[secondindex]

        if (first ~= nil and not first:IsWorld()) then
            first:SetPos(fEnt.BuildDupeInfo.PosReset)
            first:SetAngles(fEnt.BuildDupeInfo.AngleReset)
            if (IsValid(Bone1) and Bone1Index ~= 0) then
                Bone1:SetPos(fEnt.BuildDupeInfo.PosReset +
                        fEnt.BuildDupeInfo.PhysicsObjects[Bone1Index].Pos)
                Bone1:SetAngles(fEnt.PhysicsObjects[Bone1Index].Angle)
            end

            local FirstPhys = first:GetPhysicsObject()
            if IsValid(FirstPhys) then
                if ReEnableFirst then
                    FirstPhys:EnableMotion(true)
                end
            end
        end

        if (second ~= nil and not second:IsWorld()) then
            second:SetPos(sEnt.BuildDupeInfo.PosReset)
            second:SetAngles(sEnt.BuildDupeInfo.AngleReset)
            if (IsValid(Bone2) and Bone2Index ~= 0) then
                Bone2:SetPos(sEnt.BuildDupeInfo.PosReset +
                        sEnt.BuildDupeInfo.PhysicsObjects[Bone2Index].Pos)
                Bone2:SetAngles(sEnt.PhysicsObjects[Bone2Index].Angle)
            end

            local SecondPhys = second:GetPhysicsObject()
            if IsValid(SecondPhys) then
                if ReEnableSecond then
                    SecondPhys:EnableMotion(true)
                end
            end
        end
    end

    if (Ent and Ent.length) then
        Ent.length = Constraint["length"]
    end -- Fix for weird bug with ropes

    return Ent
end

local function ApplyEntityModifiers(Player, Ent)
    if not Ent.EntityMods then return end
    if Ent.EntityMods.trail then
        Ent.EntityMods.trail.EndSize = math.Clamp(tonumber(Ent.EntityMods.trail.EndSize) or 0, 0, 1024)
        Ent.EntityMods.trail.StartSize = math.Clamp(tonumber(Ent.EntityMods.trail.StartSize) or 0, 0, 1024)
    end

    for Type, Data in SortedPairs(Ent.EntityMods) do
        local ModFunction = duplicator.EntityModifiers[Type]
        if (ModFunction) then
            local ok, err = pcall(ModFunction, Player, Ent, Data)
            if (not ok) then
                if (Player) then
                    Player:ChatPrint('Error applying entity modifer, "' .. tostring(Type) .. '". ERROR: ' .. err)
                else
                    print('Error applying entity modifer, "' .. tostring(Type) .. '". ERROR: ' .. err)
                end
            end
        end
    end
    if (Ent.EntityMods["mass"] and duplicator.EntityModifiers["mass"]) then
        local ok, err = pcall(duplicator.EntityModifiers["mass"], Player, Ent, Ent.EntityMods["mass"])
        if (not ok) then
            if (Player) then
                Player:ChatPrint('Error applying entity modifer, "mass". ERROR: ' .. err)
            else
                print('Error applying entity modifer, "' .. tostring(Type) .. '". ERROR: ' .. err)
            end
        end
    end
    if(Ent.EntityMods["buoyancy"] and duplicator.EntityModifiers["buoyancy"]) then
        local ok, err = pcall(duplicator.EntityModifiers["buoyancy"], Player, Ent, Ent.EntityMods["buoyancy"])
        if (not ok) then
            if (Player) then
                Player:ChatPrint('Error applying entity modifer, "buoyancy". ERROR: ' .. err)
            else
                print('Error applying entity modifer, "' .. tostring(Type) .. '". ERROR: ' .. err)
            end
        end
    end
end

local function ApplyBoneModifiers(Player, Ent)
    if (not Ent.BoneMods or not Ent.PhysicsObjects) then return end

    for Type, ModFunction in pairs(duplicator.BoneModifiers) do
        for Bone, Args in pairs(Ent.PhysicsObjects) do
            if (Ent.BoneMods[Bone] and Ent.BoneMods[Bone][Type]) then
                local PhysObj = Ent:GetPhysicsObjectNum(Bone)
                if (Ent.PhysicsObjects[Bone]) then
                    local ok, err = pcall(ModFunction, Player, Ent, Bone, PhysObj, Ent.BoneMods[Bone][Type])
                    if (not ok) then
                        Player:ChatPrint('Error applying bone modifer, "' .. tostring(Type) .. '". ERROR: ' .. err)
                    end
                end
            end
        end
    end
end

--[[
	Name: DoGenericPhysics
	Desc: Applies bone data, generically.
	Params: <player> Player, <table> data
	Returns: <entity> Entity, <table> data
]]
local function DoGenericPhysics(Entity, data, Player)

    if (not data) then return end
    if (not data.PhysicsObjects) then return end
    local Phys
    if (Player) then
        for Bone, Args in pairs(data.PhysicsObjects) do
            Phys = Entity:GetPhysicsObjectNum(Bone)
            if (IsValid(Phys)) then
                Phys:SetPos(Args.Pos)
                Phys:SetAngles(Args.Angle)
                Phys:EnableMotion(false)
                Player:AddFrozenPhysicsObject(Entity, Phys)
            end
        end
    else
        for Bone, Args in pairs(data.PhysicsObjects) do
            Phys = Entity:GetPhysicsObjectNum(Bone)
            if (IsValid(Phys)) then
                Phys:SetPos(Args.Pos)
                Phys:SetAngles(Args.Angle)
                Phys:EnableMotion(false)
            end
        end
    end
end

local function reportclass(ply, class)
    net.Start("SrvDupe_ReportClass")
    net.WriteString(class)
    net.Send(ply)
end

local function reportmodel(ply, model)
    net.Start("SrvDupe_ReportModel")
    net.WriteString(model)
    net.Send(ply)
end

local strictConvar = GetConVar("SrvDupe_Strict")

--[[
	Name: GenericDuplicatorFunction
	Desc: Override the default duplicator's GenericDuplicatorFunction function
	Params: <table> data, <player> Player
	Returns: <entity> Entity
]]
local function GenericDuplicatorFunction(data, Player)

    local Entity = ents.Create(data.Class)
    if (not IsValid(Entity)) then
        if (Player) then
            reportclass(Player, data.Class)
        else
            print("ServerDupe Invalid Class: " .. data.Class)
        end
        return nil
    end

    if (not util.IsValidModel(data.Model) and not file.Exists(data.Model, "GAME")) then
        if (Player) then
            reportmodel(Player, data.Model)
        else
            print("ServerDupe Invalid Model: " .. data.Model)
        end
        return nil
    end

    duplicator.DoGeneric(Entity, data)
    if (Player) then Entity:SetCreator(Player) end
    Entity:Spawn()
    Entity:Activate()
    DoGenericPhysics(Entity, data, Player)

    if (not strictConvar:GetBool()) then
        table.Add(Entity:GetTable(), data)
    end
    return Entity
end

--[[
	Name: MakeProp
	Desc: Make prop without spawn effects
	Params: <player> Player, <vector> Pos, <angle> Ang, <string> Model, <table> PhysicsObject, <table> Data
	Returns: <entity> Prop
]]
local function MakeProp(Player, Pos, Ang, Model, PhysicsObject, Data)

    if Data.ModelScale then Data.ModelScale = math.Clamp(Data.ModelScale, 1e-5, 1e5) end

    if (not util.IsValidModel(Model) and not file.Exists(Data.Model, "GAME")) then
        if (Player) then
            reportmodel(Player, Data.Model)
        else
            print("ServerDupe Invalid Model: " .. Model)
        end
        return nil
    end

    Data.Pos = Pos
    Data.Angle = Ang
    Data.Model = Model
    Data.Frozen = true
    -- Make sure this is allowed
    --if (Player) then
    --    if (not gamemode.Call("PlayerSpawnProp", Player, Model)) then
    --        return false
    --    end
    --end

    local Prop = ents.Create("prop_physics")
    if not IsValid(Prop) then return false end

    duplicator.DoGeneric(Prop, Data)
    if (Player) then Prop:SetCreator(Player) end
    Prop:Spawn()
    Prop:Activate()
    DoGenericPhysics(Prop, Data, Player)
    if (Data.Flex) then
        duplicator.DoFlex(Prop, Data.Flex, Data.FlexScale)
    end

    return Prop
end

local function RestoreBodyGroups(ent, BodyG)
    for k, v in pairs(BodyG) do
        ent:SetBodygroup(k, v)
    end
end

local function CreateEntityFromTable(EntTable, Player)
    hook.Run("AdvDupe_PreCreateEntity", EntTable, Player)

    local EntityClass = duplicator.FindEntityClass(EntTable.Class)
    local sent = false
    local status, valid
    local GENERIC = false
    local CreatedEntities = {}

    -- This class is unregistered. Instead of failing try using a generic
    -- Duplication function to make a new copy.
    if (not EntityClass) then
        GENERIC = true
        sent = true

        if Player then
            if(EntTable.Class=="prop_effect")then
                sent = gamemode.Call( "PlayerSpawnEffect", Player, EntTable.Model)
            else
                local weapon = list.Get("Weapon")[EntTable.Class]

                if weapon then
                    sent = gamemode.Call("PlayerSpawnSWEP", Player, EntTable.Class, weapon)
                else
                    sent = gamemode.Call("PlayerSpawnSENT", Player, EntTable.Class)
                end
            end
        else
            sent = true
        end

        if (sent == false) then
            print("ServerDupe: Creation rejected for class, : " .. EntTable.Class)
            return nil
        else
            sent = true
        end

        status, valid = pcall(GenericDuplicatorFunction, EntTable, Player)

        --if IsAllowed(Player, EntTable.Class, EntityClass) then
        --    status, valid = pcall(GenericDuplicatorFunction, EntTable, Player)
        --else
        --    print("ServerDupe: ENTITY CLASS IS BLACKLISTED, CLASS NAME: " .. EntTable.Class)
        --    return nil
        --end
    end

    if (not GENERIC) then

        -- Build the argument list for the Entitie's spawn function
        local ArgList, Arg = {}

        for iNumber, Key in pairs(EntityClass.Args) do

            Arg = nil
            -- Translate keys from old system
            if (gtSetupTable.POS[Key]) then Key = "Pos" end
            if (gtSetupTable.ANG[Key]) then Key = "Angle" end
            if (gtSetupTable.MODEL[Key]) then Key = "Model" end
            if (gtSetupTable.TVEHICLE[Key] and EntTable[Key] and EntTable[Key].KeyValues) then
                EntTable[Key].KeyValues = {
                    limitview     = EntTable[Key].KeyValues.limitview,
                    vehiclescript = EntTable[Key].KeyValues.vehiclescript
                }
            end

            Arg = EntTable[Key]

            -- Special keys
            if (gtSetupTable.SPECIAL[Key]) then
                Arg = EntTable
            end

            ArgList[iNumber] = Arg

        end

        -- Create and return the entity
        if (EntTable.Class == "prop_physics") then
            valid = MakeProp(Player, unpack(ArgList, 1, #EntityClass.Args)) -- Create prop_physics like this because if the model doesn't exist it will cause
        else
            -- Create sents using their spawn function with the arguments we stored earlier
            sent = true

            if Player then
                if (not EntTable.BuildDupeInfo.IsVehicle and not EntTable.BuildDupeInfo.IsNPC and EntTable.Class ~= "prop_ragdoll" and EntTable.Class ~= "prop_effect") then
                    local weapon = list.Get("Weapon")[EntTable.Class]

                    if weapon then
                        sent = gamemode.Call("PlayerSpawnSWEP", Player, EntTable.Class, weapon)
                    else
                        sent = gamemode.Call("PlayerSpawnSENT", Player, EntTable.Class)
                        --local ent = ents.Create(EntTable.Class)
                        --sent = true
                    end
                end
            else
                sent = true
            end

            if (sent == false) then
                print("ServerDupe: Creation rejected for class, : " .. EntTable.Class)
                return nil
            else
                sent = true
            end

            hook.Add( "OnEntityCreated", "SrvDupe_GetLastEntitiesCreated", function( ent )
                table.insert( CreatedEntities, ent )
            end )

            status, valid = xpcall(EntityClass.Func, ErrorNoHaltWithStack, Player, unpack(ArgList, 1, #EntityClass.Args))

            hook.Remove( "OnEntityCreated", "SrvDupe_GetLastEntitiesCreated" )
        end
    end

    -- If its a valid entity send it back to the entities list so we can constrain it
    if (status ~= false and IsValid(valid)) then
        if (sent) then
            local iNumPhysObjects = valid:GetPhysicsObjectCount()
            local PhysObj
            if (Player) then
                for Bone = 0, iNumPhysObjects - 1 do
                    PhysObj = valid:GetPhysicsObjectNum(Bone)
                    if IsValid(PhysObj) then
                        PhysObj:EnableMotion(false)
                        Player:AddFrozenPhysicsObject(valid, PhysObj)
                    end
                end
            else
                for Bone = 0, iNumPhysObjects - 1 do
                    PhysObj = valid:GetPhysicsObjectNum(Bone)
                    if IsValid(PhysObj) then
                        PhysObj:EnableMotion(false)
                    end
                end
            end
            if (EntTable.Skin) then valid:SetSkin(EntTable.Skin) end
            if (EntTable.BodyG) then RestoreBodyGroups(valid, EntTable.BodyG) end

            if valid.RestoreNetworkVars then
                valid:RestoreNetworkVars(EntTable.DT)
            end

            if GENERIC and Player then
                if(EntTable.Class=="prop_effect")then
                    gamemode.Call("PlayerSpawnedEffect", Player, valid:GetModel(), valid)
                elseif valid:IsWeapon() then
                    gamemode.Call("PlayerSpawnedSWEP", Player, valid)
                else
                    gamemode.Call("PlayerSpawnedSENT", Player, valid)
                end
            end

        elseif (Player) then
            gamemode.Call("PlayerSpawnedProp", Player, valid:GetModel(), valid)
        end

        return valid
    else
        if (status == false) then
            print("ServerDupe: Error creating entity, removing last created entities")
            for _, CreatedEntity in pairs(CreatedEntities) do
                SafeRemoveEntity(CreatedEntity)
            end
        end

        if (valid == false) then
            return false
        else
            return nil
        end
    end
end

function SrvDupe.FinishPasting(Player, Paste)
    if(Paste) then SrvDupe.Notify("Finished Pasting!", 0, nil, Player, false) end
end

--[[
	Name: Paste
	Desc: Override the default duplicator's paste function
	Params: <player> Player, <table> Entities, <table> Constraints
	Returns: <table> Entities, <table> Constraints
]]
function SrvDupe.duplicator.Paste(Player, EntityList, ConstraintList, Position, AngleOffset, OrigPos, Parenting, onUndoCallback)

    local CreatedEntities = {}
    --
    -- Create entities
    --
    local proppos
    DisablePropCreateEffect = true
    for k, v in pairs(EntityList) do
        if (not v.BuildDupeInfo) then v.BuildDupeInfo = {} end
        v.BuildDupeInfo.PhysicsObjects = table.Copy(v.PhysicsObjects)
        proppos = v.PhysicsObjects[0].Pos
        v.BuildDupeInfo.PhysicsObjects[0].Pos = Vector(0, 0, 0)

        -- removed if origPos (will never have origPos here)
        for i, p in pairs(v.BuildDupeInfo.PhysicsObjects) do
            v.PhysicsObjects[i].Pos, v.PhysicsObjects[i].Angle =
            LocalToWorld(p.Pos + proppos, p.Angle, Position, AngleOffset)
            v.PhysicsObjects[i].Frozen = true
        end
        v.Pos = v.PhysicsObjects[0].Pos
        v.BuildDupeInfo.PosReset = v.Pos
        v.Angle = v.PhysicsObjects[0].Angle
        v.BuildDupeInfo.AngleReset = v.Angle

        SrvDupe.SpawningEntity = true
        SrvDupe.ApplyCustomRestrictions()
        local Ent = CreateEntityFromTable(v, Player)
        SrvDupe.SpawningEntity = false
        SrvDupe.RevertCustomRestrictions()

        if Ent then
            if (Player) then Player:AddCleanup("SrvDupe", Ent) end
            Ent.BoneMods = table.Copy(v.BoneMods)
            Ent.EntityMods = table.Copy(v.EntityMods)
            Ent.PhysicsObjects = table.Copy(v.PhysicsObjects)
            if (v.CollisionGroup) then Ent:SetCollisionGroup(v.CollisionGroup) end
            if (Ent.OnDuplicated) then Ent:OnDuplicated(v) end
            ApplyEntityModifiers(Player, Ent)
            ApplyBoneModifiers(Player, Ent)
            Ent.SolidMod = not Ent:IsSolid()
            Ent:SetNotSolid(true)
        elseif (Ent == false) then
            Ent = nil
            -- ConstraintList = {}
            -- break
        else
            Ent = nil
        end
        CreatedEntities[k] = Ent
    end

    local CreatedConstraints, Entity = {}
    --
    -- Create constraints
    --
    for k, Constraint in pairs(ConstraintList) do
        Entity = CreateConstraintFromTable(Constraint, CreatedEntities, EntityList, Player)
        if (IsValid(Entity)) then
            table.insert(CreatedConstraints, Entity)
        end
    end

    --if false then
    if (Player) then
        local undotxt = "SrvDupe"..(Player.SrvDupe.Name and (" ("..tostring(Player.SrvDupe.Name)..")") or "")

        undo.Create(undotxt)
        for _, v in pairs(CreatedEntities) do
            -- If the entity has a PostEntityPaste function tell it to use it now
            if v.PostEntityPaste then
                local status, valid = pcall(v.PostEntityPaste, v, Player, v, CreatedEntities)
                if (not status) then
                    print("ServerDupe PostEntityPaste Error: " .. tostring(valid))
                end
            end

            if IsValid(v:GetPhysicsObject()) then
                v:GetPhysicsObject():EnableMotion(false)
            end

            if (EntityList[_].BuildDupeInfo.DupeParentID and Parenting) then
                v:SetParent(CreatedEntities[EntityList[_].BuildDupeInfo.DupeParentID])
            end
            v:SetNotSolid(v.SolidMod)
            undo.AddEntity(v)
        end
        undo.SetPlayer(Player)
        if (onUndoCallback) then
            undo.AddFunction(onUndoCallback)
        end
        undo.Finish()

        -- if(Tool)then SrvDupe.FinishPasting(Player, true) end
    else

        for _, v in pairs(CreatedEntities) do
            -- If the entity has a PostEntityPaste function tell it to use it now
            if v.PostEntityPaste then
                local status, valid = pcall(v.PostEntityPaste, v, Player, v, CreatedEntities)
                if (not status) then
                    print("ServerDupe PostEntityPaste Error: " .. tostring(valid))
                end
            end

            if IsValid(v:GetPhysicsObject()) then
                v:GetPhysicsObject():EnableMotion(false)
            end

            if (EntityList[_].BuildDupeInfo.DupeParentID and Parenting) then
                v:SetParent(CreatedEntities[EntityList[_].BuildDupeInfo.DupeParentID])
            end

            v:SetNotSolid(v.SolidMod)
        end
    end
    DisablePropCreateEffect = nil

    SrvDupe.ApplyCustomRestrictions()
    hook.Call("AdvDupe_FinishPasting", nil, {
        {
            EntityList = EntityList,
            CreatedEntities = CreatedEntities,
            ConstraintList = ConstraintList,
            CreatedConstraints = CreatedConstraints,
            HitPos = Position,
            Player = Player,
            IsServerDupe = true
        }
    }, 1)
    SrvDupe.RevertCustomRestrictions()

    return CreatedEntities, CreatedConstraints
end

local function SrvDupe_Spawn()

    local Queue = SrvDupe.JobManager.Queue[SrvDupe.JobManager.CurrentPaste]

    if (not Queue or not IsValid(Queue.Player)) then
        if Queue then
            table.remove(SrvDupe.JobManager.Queue, SrvDupe.JobManager.CurrentPaste)
        end

        if (#SrvDupe.JobManager.Queue == 0) then
            hook.Remove("Tick", "SrvDupe_Spawning")
            DisablePropCreateEffect = nil
            SrvDupe.JobManager.PastingHook = false
        end
        return
    end

    if (Queue.Entity) then
        if (Queue.Current > #Queue.SortedEntities) then
            Queue.Entity = false
            Queue.Constraint = true
            Queue.Current = 1
            return
        end
        if (not Queue.SortedEntities[Queue.Current]) then
            Queue.Current = Queue.Current + 1
            return
        end

        local k = Queue.SortedEntities[Queue.Current]
        local v = Queue.EntityList[k]

        if (not v.BuildDupeInfo) then v.BuildDupeInfo = {} end
        if Queue.Revision < 1 and v.LocalPos then
            for i, _ in pairs(v.PhysicsObjects) do
                v.PhysicsObjects[i] = {Pos = v.LocalPos, Angle = v.LocalAngle}
            end
        end

        v.BuildDupeInfo.PhysicsObjects = table.Copy(v.PhysicsObjects)
        local proppos = v.PhysicsObjects[0].Pos
        v.BuildDupeInfo.PhysicsObjects[0].Pos = Vector(0, 0, 0)
        if (Queue.OrigPos) then
            for i, p in pairs(v.BuildDupeInfo.PhysicsObjects) do
                v.PhysicsObjects[i].Pos = p.Pos + proppos + Queue.OrigPos
                v.PhysicsObjects[i].Frozen = true
            end
            v.Pos = v.PhysicsObjects[0].Pos
            v.Angle = v.PhysicsObjects[0].Angle
            v.BuildDupeInfo.PosReset = v.Pos
            v.BuildDupeInfo.AngleReset = v.Angle
        else
            for i, p in pairs(v.BuildDupeInfo.PhysicsObjects) do
                v.PhysicsObjects[i].Pos, v.PhysicsObjects[i].Angle =
                LocalToWorld(p.Pos + proppos, p.Angle, Queue.PositionOffset, Queue.AngleOffset)
                v.PhysicsObjects[i].Frozen = true
            end
            v.Pos = v.PhysicsObjects[0].Pos
            v.BuildDupeInfo.PosReset = v.Pos
            v.Angle = v.PhysicsObjects[0].Angle
            v.BuildDupeInfo.AngleReset = v.Angle
        end

        SrvDupe.SpawningEntity = true
        SrvDupe.ApplyCustomRestrictions()
        local Ent = CreateEntityFromTable(v, Queue.Player)
        SrvDupe.SpawningEntity = false
        SrvDupe.RevertCustomRestrictions()

        if Ent then
            Queue.Player:AddCleanup("SrvDupe", Ent)
            Ent.BoneMods = table.Copy(v.BoneMods)
            Ent.EntityMods = table.Copy(v.EntityMods)
            Ent.PhysicsObjects = table.Copy(v.PhysicsObjects)
            Ent.SolidMod = not Ent:IsSolid()

            local Phys = Ent:GetPhysicsObject()
            if (IsValid(Phys)) then Phys:EnableMotion(false) end
            if (not Queue.DisableProtection) then Ent:SetNotSolid(true) end
            if (v.CollisionGroup) then Ent:SetCollisionGroup(v.CollisionGroup) end
            if (Ent.OnDuplicated) then Ent:OnDuplicated(v) end
        elseif (Ent == false) then
            Ent = nil
        else
            Ent = nil
        end
        Queue.CreatedEntities[k] = Ent

        Queue.Current = Queue.Current + 1
        if (Queue.Current > #Queue.SortedEntities) then

            for _, Ent in pairs(Queue.CreatedEntities) do
                ApplyEntityModifiers(Queue.Player, Ent)
                ApplyBoneModifiers(Queue.Player, Ent)

                -- If the entity has a PostEntityPaste function tell it to use it now
                if Ent.PostEntityPaste then
                    local status, valid = pcall(Ent.PostEntityPaste, Ent, Queue.Player, Ent, Queue.CreatedEntities)
                    if (not status) then
                        print("ServerDupe PostEntityPaste Error: " .. tostring(valid))
                    end
                end
            end

            Queue.Entity = false
            Queue.Constraint = true
            Queue.Current = 1
        end

        if (#SrvDupe.JobManager.Queue >= SrvDupe.JobManager.CurrentPaste + 1) then
            SrvDupe.JobManager.CurrentPaste = SrvDupe.JobManager.CurrentPaste + 1
        else
            SrvDupe.JobManager.CurrentPaste = 1
        end
    else
        if (#Queue.ConstraintList > 0) then

            if (#SrvDupe.JobManager.Queue == 0) then
                hook.Remove("Tick", "SrvDupe_Spawning")
                DisablePropCreateEffect = nil
                SrvDupe.JobManager.PastingHook = false
            end
            if (not Queue.ConstraintList[Queue.Current]) then
                Queue.Current = Queue.Current + 1
                return
            end

            local Entity = CreateConstraintFromTable(Queue.ConstraintList[Queue.Current], Queue.CreatedEntities,
                    Queue.EntityList, Queue.Player, true)
            if IsValid(Entity) then
                table.insert(Queue.CreatedConstraints, Entity)
            end
        elseif (next(Queue.ConstraintList) ~= nil) then
            local tbl = {}
            for k, v in pairs(Queue.ConstraintList) do
                table.insert(tbl, v)
            end
            Queue.ConstraintList = tbl
            Queue.Current = 0
        end

        Queue.Current = Queue.Current + 1

        if (Queue.Current > #Queue.ConstraintList) then

            --local unfreeze = tobool(Queue.Player:GetInfo("srvdupe_paste_unfreeze")) or false
            --local preservefrozenstate = tobool(Queue.Player:GetInfo("srvdupe_preserve_freeze")) or false
            -- TODO: Implement option (convar?)
            local unfreeze = false
            local preservefrozenstate = false

            -- Remove the undo for stopping pasting
            local undotxt = "SrvDupe"..(Queue.Name and (" ("..tostring(Queue.Name)..")") or "")
            local undos = undo.GetTable()[Queue.Player:UniqueID()]
            for i = #undos, 1, -1 do
                if (undos[i] and undos[i].Name == undotxt) then
                    undos[i] = nil
                    -- Undo module netmessage
                    net.Start("Undo_Undone")
                    net.WriteInt(i, 16)
                    net.Send(Queue.Player)
                    break
                end
            end

            undo.Create(undotxt)
            local phys, edit, mass
            for k, v in pairs(Queue.CreatedEntities) do
                if (not IsValid(v)) then
                    v = nil
                else
                    edit = true
                    if (Queue.EntityList[k].BuildDupeInfo.DupeParentID ~= nil and Queue.Parenting) then
                        v:SetParent(Queue.CreatedEntities[Queue.EntityList[k].BuildDupeInfo.DupeParentID])
                        if (v.Constraints ~= nil) then
                            for i, c in pairs(v.Constraints) do
                                if (c and gtSetupTable.CONSTRAINT[c.Type]) then
                                    edit = false
                                    break
                                end
                            end
                        end
                        if (edit and IsValid(v:GetPhysicsObject())) then
                            mass = v:GetPhysicsObject():GetMass()
                            v:PhysicsInitShadow(false, false)
                            v:SetCollisionGroup(COLLISION_GROUP_WORLD)
                            v:GetPhysicsObject():EnableMotion(false)
                            v:GetPhysicsObject():Sleep()
                            v:GetPhysicsObject():SetMass(mass)
                        end
                    else
                        edit = false
                    end

                    local physCount = v:GetPhysicsObjectCount() - 1

                    if (unfreeze) then
                        for i = 0, physCount do
                            phys = v:GetPhysicsObjectNum(i)
                            if (IsValid(phys)) then
                                phys:EnableMotion(true) -- Unfreeze the entitiy and all of its objects
                                phys:Wake()
                            end
                        end
                    elseif (preservefrozenstate) then
                        for i = 0, physCount do
                            phys = v:GetPhysicsObjectNum(i)
                            if (IsValid(phys)) then
                                if (Queue.EntityList[k].BuildDupeInfo.PhysicsObjects[i].Frozen) then
                                    phys:EnableMotion(true) -- Restore the entity and all of its objects to their original frozen state
                                    phys:Wake()
                                else
                                    Queue.Player:AddFrozenPhysicsObject(v, phys)
                                end
                            end
                        end
                    else
                        for i = 0, physCount do
                            phys = v:GetPhysicsObjectNum(i)
                            if (IsValid(phys)) then
                                if (phys:IsMoveable()) then
                                    phys:EnableMotion(false) -- Freeze the entitiy and all of its objects
                                    Queue.Player:AddFrozenPhysicsObject(v, phys)
                                end
                            end
                        end
                    end

                    if (not edit or not Queue.DisableParents) then
                        v:SetNotSolid(v.SolidMod)
                    end

                    undo.AddEntity(v)
                end
            end
            undo.SetPlayer(Queue.Player)
            if (Queue.onUndoCallback) then
                undo.AddFunction(Queue.onUndoCallback)
            end
            undo.Finish()

            SrvDupe.ApplyCustomRestrictions()
            hook.Call("AdvDupe_FinishPasting", nil, {
                {
                    EntityList = Queue.EntityList,
                    CreatedEntities = Queue.CreatedEntities,
                    ConstraintList = Queue.ConstraintList,
                    CreatedConstraints = Queue.CreatedConstraints,
                    HitPos = Queue.PositionOffset,
                    Player = Queue.Player,
                    IsServerDupe = true
                }
            }, 1)
            SrvDupe.FinishPasting(Queue.Player, true)
            SrvDupe.RevertCustomRestrictions()

            table.remove(SrvDupe.JobManager.Queue, SrvDupe.JobManager.CurrentPaste)
            if (#SrvDupe.JobManager.Queue == 0) then
                hook.Remove("Tick", "SrvDupe_Spawning")
                DisablePropCreateEffect = nil
                SrvDupe.JobManager.PastingHook = false
            end
        end
        if (#SrvDupe.JobManager.Queue >= SrvDupe.JobManager.CurrentPaste + 1) then
            SrvDupe.JobManager.CurrentPaste = SrvDupe.JobManager.CurrentPaste + 1
        else
            SrvDupe.JobManager.CurrentPaste = 1
        end
    end
end

local ticktotal = 0
local function ErrorCatchSpawning()

    ticktotal = ticktotal + math.max(GetConVarNumber("SrvDupe_SpawnRate"), 0.01)
    while ticktotal >= 1 do
        ticktotal = ticktotal - 1
        local status, err = pcall(SrvDupe_Spawn)

        if (not status) then
            -- PUT ERROR LOGGING HERE

            if (not SrvDupe.JobManager.Queue) then
                print("[SrvDupeNotify]\t" .. err)
                SrvDupe.JobManager.Queue = {}
                return
            end

            local Queue = SrvDupe.JobManager.Queue[SrvDupe.JobManager.CurrentPaste]
            if (not Queue) then
                print("[SrvDupeNotify]\t" .. err)
                return
            end

            if (IsValid(Queue.Player)) then
                SrvDupe.Notify(err, 1, nil, Queue.Player)

                local undos = undo.GetTable()[Queue.Player:UniqueID()]
                local undotxt = Queue.Name and ("SrvDupe ("..Queue.Name..")") or "SrvDupe"
                for i = #undos, 1, -1 do
                    if (undos[i] and undos[i].Name == undotxt) then
                        undos[i] = nil
                        -- Undo module netmessage
                        net.Start("Undo_Undone")
                        net.WriteInt(i, 16)
                        net.Send(Queue.Player)
                        break
                    end
                end
            else
                print("[SrvDupeNotify]\t" .. err)
            end

            for k, v in pairs(Queue.CreatedEntities) do
                if (IsValid(v)) then v:Remove() end
            end

            if (IsValid(Queue.Player)) then
                SrvDupe.FinishPasting(Queue.Player, true)
            end

            table.remove(SrvDupe.JobManager.Queue, SrvDupe.JobManager.CurrentPaste)

            if (#SrvDupe.JobManager.Queue == 0) then
                hook.Remove("Tick", "SrvDupe_Spawning")
                DisablePropCreateEffect = nil
                SrvDupe.JobManager.PastingHook = false
            else
                if (#Queue < SrvDupe.JobManager.CurrentPaste) then
                    SrvDupe.JobManager.CurrentPaste = 1
                end
            end

        end
    end
end

local function RemoveSpawnedEntities(tbl, i)
    if (not SrvDupe.JobManager.Queue[i]) then return end -- Without this some errors come up, double check the errors without this line

    for k, v in pairs(SrvDupe.JobManager.Queue[i].CreatedEntities) do
        if (IsValid(v)) then v:Remove() end
    end

    SrvDupe.FinishPasting(SrvDupe.JobManager.Queue[i].Player, false)
    table.remove(SrvDupe.JobManager.Queue, i)
    if (#SrvDupe.JobManager.Queue == 0) then
        hook.Remove("Tick", "SrvDupe_Spawning")
        DisablePropCreateEffect = nil
        SrvDupe.JobManager.PastingHook = false
    end
end

function SrvDupe.InitPastingQueue(Player, PositionOffset, AngleOffset, Entities, Constraints, NameDupe, RevisionDupe, onUndoCallback)
    local i = #SrvDupe.JobManager.Queue + 1

    local Queue = {
        Player = Player,
        SortedEntities = {},
        ConstraintList = Constraints,
        EntityList = table.Copy(Entities),
        Current = 1,
        Name = NameDupe or "",
        Entity = true,
        Constraint = false,
        Parenting = true,
        DisableParents = false,
        DisableProtection = true,
        CreatedEntities = {},
        CreatedConstraints = {},
        PositionOffset = PositionOffset or Vector(0, 0, 0),
        AngleOffset = AngleOffset or Angle(0, 0, 0),
        Revision = RevisionDupe,
        onUndoCallback = onUndoCallback,
    }
    SrvDupe.JobManager.Queue[i] = Queue

    for k, v in pairs(Entities) do
        table.insert(Queue.SortedEntities, k)
    end

    if (NameDupe) then
        print(
                "[SrvDupeNotifyPaste]\t Player: " .. Player:Nick() .. " Pasted File, " .. NameDupe .. " with, " ..
                        #Queue.SortedEntities .. " Entities and " .. #Queue.ConstraintList .. " Constraints.")
    else
        print("[SrvDupeNotifyPaste]\t Player: " .. Player:Nick() .. " Pasted, " .. #Queue.SortedEntities ..
                " Entities and " .. #Queue.ConstraintList .. " Constraints.")
    end

    if (not SrvDupe.JobManager.PastingHook) then
        DisablePropCreateEffect = true
        hook.Add("Tick", "SrvDupe_Spawning", ErrorCatchSpawning)
        SrvDupe.JobManager.PastingHook = true
        SrvDupe.JobManager.CurrentPaste = 1
    end

    local undotxt = "SrvDupe"..(NameDupe and (" ("..tostring(NameDupe)..")") or "")
    undo.Create(undotxt)
    undo.SetPlayer(Player)
    undo.AddFunction(RemoveSpawnedEntities, i)
    if (onUndoCallback) then
        undo.AddFunction(onUndoCallback)
    end
    undo.Finish()
end

local function GetDupeElevation(dupe)
    local enz = (tonumber(dupe.HeadEnt.Z) or 0)
    return math.Clamp(enz, -32000, 32000)
end

function SrvDupe.LoadFile(path)
    local fullPath = SrvDupe.DataFolder .. "/" .. path
    local content = file.Read(fullPath, "DATA")
    if not content then
        print("[SrvDupe]\tFailed to load file: " .. fullPath)
        return false
    end

    local success, dupe, info, moreinfo = SrvDupe.Decode(content)
    if not success then
        print("[SrvDupe]\tFailed to decode file: " .. fullPath)
        return false
    end

    return success, dupe, info, moreinfo
end

function SrvDupe.LoadAndPaste(path, position, angle, plyRequestor, onUndoCallback)
    local success, dupe, info, moreinfo = SrvDupe.LoadFile(path)

    if not success then
        return false
    end

    print("[SrvDupe]\t".. path .. " loaded successfully.")

    local pathSplits = string.Split(path, "/")
    local nameDupe = string.StripExtension(pathSplits[#pathSplits])
    local revDupe = info["revision"]

    local Tab = {Entities=dupe["Entities"], Constraints=dupe["Constraints"], HeadEnt=dupe["HeadEnt"]}
    SrvDupe.InitPastingQueue(plyRequestor, position + Vector(0,0, GetDupeElevation(dupe)) , angle, Tab.Entities, Tab.Constraints, nameDupe, revDupe, onUndoCallback)

    return true
end
