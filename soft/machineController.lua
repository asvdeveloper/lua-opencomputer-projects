local asvutils = require("asvutils")
local settLib = require("settings")
local comp = require("computer")
local objectsAndSets = {}

local hardSett = {
    loadDefaultIfParseFromFileError = false,
    useScreenOutput = true,
}

local defaultSettings = {
    --Warning! Don't edit this table. You can edit your solution in /etc/settings/machineController.set(serialized table).
    --If the path to the file does not exist(or table is damaged) then run the program, the path and the file with the default settings will be created automatically.

    actionMode = 1,
    --actionMode - set action type(file, function or single mode)
    ---1: function mode - action write as function
    ---2: file mode - action write as path to program
    ---3: single file - actions write as library
    ---(A table with functions checkFunction, action, actionOnPrint should be returned).
    ---The file path should be in checkFunction

    machineGroups = {
        defaultGroupName = {
            title = "Default Group",
            enable = true,
            checkFunction = "local a={...}for _,mh in pairs(a[1].machines)do opt=mh.options;return{math.ceil(require(\"computer\").uptime()%opt.num1)==opt.num2,require(\"computer\").uptime()}end",
            action = "local a={...}local opt=a[1].options.returned.checkFunction;print(opt[1], opt[2])",
            actionOnPrint = "",
            machines = {"defaultMachineName"},
            options = {returned = {}},
            executeEvery = 7
        }
    },
    --current machineGroup object are passed as first argument
    --also stores the second return parameter in options.returned.(can be either a table or another arbitrary type)

    machines = {
        defaultMachineName = {
            title = "Default machine title",
            enable = true,
            options = {address = "1meh", num1=5, num2=2}
        }
    },
    --title - Custom parameter. Not used.
    --machineGroup - The text value of the index in the machineGroups table.
}

local items = {
    machineGroupsItem = {
        --user parameters
        title = "Default group title", checkFunction = "", action = "",actionOnPrint = "", options = {returned = {}}, executeEvery = 60, enable = false, machines = {},
        --service parameters
        lastExecution = 0
    },
    machinesItem = {
        --user parameters
        title = "Default machine title", options = {}, enable = false,
        --service parameters
        groupObjects = {}
    }
}

if hardSett.useScreenOutput then
    require("term").clear()
end

local function print(text, err)
    if hardSett.useScreenOutput then
        if err then
            io.stderr:write(text.."\n")
        else
            io.stdout:write(text.."\n")
        end
    end
end

local function printErr(text)
    print(text, true)
end

local function loadSettings()
    local status
    status, objectsAndSets = settLib.getSettings("machineController", defaultSettings)
    if not status then
        printErr("error loading settings: "..objectsAndSets)
        if not hardSett.loadDefaultIfParseFromFileError then
            return false
        end
        printErr("loading default settings")
        objectsAndSets = defaultSettings
    end
    return true
end

local function correctItems()
    for key, value in pairs(objectsAndSets.machineGroups) do
        objectsAndSets.machineGroups[key] = asvutils.correctTableStructure(value, items.machineGroupsItem)
    end

    for key, value in pairs(objectsAndSets.machines) do
        objectsAndSets.machines[key] = asvutils.correctTableStructure(value, items.machinesItem)
    end
end

local function createLinks()
    for key, value in pairs(objectsAndSets.machineGroups) do
        local machinesObj = {}
        for _, valueM in pairs(value.machines) do
            if not objectsAndSets.machines[valueM] then
                printErr("group `"..valueM.."` not found")
                return false
            end

            if value.enable and objectsAndSets.machines[valueM].enable then
                --add link to machinesObjects
                machinesObj[valueM] = objectsAndSets.machines[valueM]

                --add link to machineGroups
                objectsAndSets.machines[valueM].groupObjects[key] = value
            end
        end
        value.machines = machinesObj
    end
    return true
end

local function loadFunctions()
    if objectsAndSets.actionMode >= 1 and objectsAndSets.actionMode <= 3 then
        local functionKeys = {
            "checkFunction", "action"
        }

        for keyGroup, item in pairs(objectsAndSets.machineGroups) do
            if item.enable then
                if objectsAndSets.actionMode == 1 or objectsAndSets.actionMode == 2 then
                    for _, value in pairs(functionKeys) do
                        if objectsAndSets.actionMode == 1 then
                            local func, reason = load(objectsAndSets.machineGroups[keyGroup][value])
                            if reason then
                                printErr("Function "..value.." in "..keyGroup.." loading error: "..reason);
                                return false
                            end
                            objectsAndSets.machineGroups[keyGroup][value] = func
                        else
                            local func, reason = loadfile(objectsAndSets.machineGroups[keyGroup][value])
                            if reason then
                                printErr("File "..objectsAndSets.machineGroups[keyGroup][value].." in "..keyGroup.." loading error: "..reason);
                                return false
                            end
                            objectsAndSets.machineGroups[keyGroup][value] = func
                        end
                    end
                else
                    local table, reason = loadfile(objectsAndSets.machineGroups[keyGroup].checkFunction)()
                    if reason then
                        printErr("Functions in "..keyGroup.." loading error: "..reason);
                        return false
                    end
                    for _, value in pairs(functionKeys) do
                        objectsAndSets.machineGroups[keyGroup][value] = table[value]
                    end
                end
            end
        end
    else
        printErr("parameter actionMode is not correct")
        return false
    end
    return true
end

local function main()
    --searching minimum delay
    local delay = -1
    for _, value in pairs(objectsAndSets.machineGroups) do
        if value.enable then
            if value.executeEvery < delay or delay == -1 then
                delay = value.executeEvery
            end
        end
    end

    while true do
        for key in pairs(objectsAndSets.machineGroups) do
            local currentGroup = objectsAndSets.machineGroups[key]
            if currentGroup.enable then
                local time = comp.uptime()
                if time - currentGroup.lastExecution >= currentGroup.executeEvery then
                    local functionKeys = {
                        "checkFunction", "action"
                    }

                    for _, value in pairs(functionKeys) do
                        local succes, data = pcall(currentGroup[value], currentGroup)
                        if not succes then
                            printErr("Group: `"..currentGroup.title.."` Func: `"..value.."` Error: `"..data.."`")
                            break
                        end
                        currentGroup.options.returned[value] = data
                    end

                    currentGroup.lastExecution = comp.uptime()
                end
            end
        end
        os.sleep(delay)
    end
end

--init
print("loading settings")
if not loadSettings() then
    os.exit()
end

print("correct items")
correctItems()

print("create links")
if not createLinks() then
    os.exit()
end

print("loading functions")
if not loadFunctions() then
    os.exit()
end

--main cycle
print("start working\n")
main()