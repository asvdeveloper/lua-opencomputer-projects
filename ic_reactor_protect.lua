--user settings
local sideOut = 0
local sideIn = 1
local alarm = false
local sideAlarm = 2
local connectType = 0
--0 - connect to reactor chamber
--1 - connect to core
--2 - connect by id
local reactor_id = "0" --fill this if connectType = 2 (you can fill unique start of address e.g. "6afd")
--end user settings

local cmp = require("component")
local rs = cmp.proxy(cmp.get("000"))
local rs1 = cmp.proxy(cmp.get("111"))
local counter = 0
local objects = {}

function printInfo(data)
	require("term").clear()
	print("Reactor heat: "..tostring(data.heat/data.maxHeat*100).."%")
	print("Reactor output: "..math.floor(data.reactorEUOutput).." EU")
	local reactorStateString = "";
	if data.reactorState then
		reactorStateString = "Enable"
	else
		reactorStateString = "Disable"
	end
	print("Reactor state: "..reactorStateString)
end

function getInfo()
	local data = {
	heat = 0,
	maxHeat = 0,
	reactorEUOutput = 0,
	reactorState = false
	}	
	
	if objects.reactor == nil then
		if connectType == 0 then
			objects.reactor = cmp.reactor_chamber
		elseif connectType == 1 then
			objects.reactor = cmp.reactor
		elseif connectType == 2 then
			objects.reactor = cmp.proxy(cmp.get(reactor_id))
		else
			print("error connectType")
			os.sleep(5);
			os.exit();
		end
	end
	
	data.heat = objects.reactor.getHeat()
	data.maxHeat = objects.reactor.getMaxHeat()
	data.reactorEUOutput = objects.reactor.getReactorEUOutput()
	data.reactorState = objects.reactor.producesEnergy()
	
	return data
end

cmp.gpu.setResolution(25, 5)
while true do
	local succes, data = pcall(getInfo)
	if not succes then
		print("Error", data)
		rs.setOutput(sideOut, 0)
		if alarm then
			rs1.setOutput(sideAlarm, 15)
		end
		os.exit();
	end

	if (data.heat/data.maxHeat*100 >= 80.0) then
		rs.setOutput(sideOut, 0)
		if alarm then
			rs1.setOutput(sideAlarm, 15)
		end
	else
		if rs1.getInput(sideIn) > 0 then
			rs.setOutput(sideOut, rs1.getInput(sideIn))
		else
			rs.setOutput(sideOut, 0)
		end
		if alarm then
			rs1.setOutput(sideAlarm, 0)
		end
	end
	if counter == 3 then
		printInfo(data)
		counter = 0
	end
	counter = counter + 1
	os.sleep(0.1)
end
