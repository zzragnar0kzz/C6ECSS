--[[ =========================================================================
	C6ECSS : Enhanced City-States Selection for Civilization VI
    Copyright (c) 2024 zzragnar0kzz
    All rights reserved.
=========================================================================== ]]

--[[ =========================================================================
	begin gamesetuplogic_ecss.lua configuration script
=========================================================================== ]]
print("[+]: Loading GameSetupLogic_ECSS.lua . . .");

--[[ =========================================================================
	globals
=========================================================================== ]]
SlotStatus.SS_RESERVED = 5;

g_tSlotStatusKeys = {};
for key, value in pairs(SlotStatus) do
	g_tSlotStatusKeys[value] = key;
end

g_tCivilizationLevelKeys = {};
for key, value in pairs(CivilizationLevelTypes) do
	g_tCivilizationLevelKeys[value] = key;
end

g_sCityStatesQuery = "SELECT * FROM CityStates WHERE Domain = ?";

g_tCityStateDomains = {
	["RULESET_STANDARD"]	= "StandardCityStates", 
	["RULESET_EXPANSION_1"]	= "Expansion1CityStates", 
	["RULESET_EXPANSION_2"]	= "Expansion2CityStates", 
};

g_tPlayerDomains = {
	["RULESET_STANDARD"]	= "Players:StandardPlayers", 
	["RULESET_EXPANSION_1"]	= "Players:Expansion1_Players", 
	["RULESET_EXPANSION_2"]	= "Players:Expansion2_Players", 
};

g_tMaxCityStatesByMapSize = {
	[DB.MakeHash("MAPSIZE_DUEL")]     = 6, 
	[DB.MakeHash("MAPSIZE_TINY")]     = 9, 
	[DB.MakeHash("MAPSIZE_SMALL")]    = 15, 
	[DB.MakeHash("MAPSIZE_STANDARD")] = 21, 
	[DB.MakeHash("MAPSIZE_LARGE")]    = 24, 
	[DB.MakeHash("MAPSIZE_HUGE")]     = 30, 
};
if g_bIsEnabledYnAMP then 
	g_tMaxCityStatesByMapSize[DB.MakeHash("MAPSIZE_SMALL21")]    = 15;
	g_tMaxCityStatesByMapSize[DB.MakeHash("MAPSIZE_STANDARD21")] = 21;
	g_tMaxCityStatesByMapSize[DB.MakeHash("MAPSIZE_LARGE21")]    = 24;
	g_tMaxCityStatesByMapSize[DB.MakeHash("MAPSIZE_HUGE21")]     = 30;
	g_tMaxCityStatesByMapSize[DB.MakeHash("MAPSIZE_ENORMOUS21")] = 34;
	g_tMaxCityStatesByMapSize[DB.MakeHash("MAPSIZE_ENORMOUS")]   = 34;
	g_tMaxCityStatesByMapSize[DB.MakeHash("MAPSIZE_GIANT")]      = 36;
	g_tMaxCityStatesByMapSize[DB.MakeHash("MAPSIZE_LUDICROUS")]  = 38;
	g_tMaxCityStatesByMapSize[DB.MakeHash("MAPSIZE_OVERSIZED")]  = 40;
end

--[[ =========================================================================
	NEW: 
=========================================================================== ]]
function ShuffleTable(t) 
	if #t < 2 then return t; end
	local s = {};
    for i = 1, #t do s[i] = t[i]; end
	if not MapConfiguration.GetValue("RANDOM_SEED") then 
		GenerateNewSeed("map");
	end
	math.randomseed(MapConfiguration.GetValue("RANDOM_SEED"));
    for i = #t, 2, -1 do 
        local j = math.random(i);
        s[i], s[j] = s[j], s[i];
    end
    return s;
end

--[[ =========================================================================
	NEW: 
=========================================================================== ]]
function GetLeaderFromMinorCivilizationType(sCivType) 
	local sLeaderType = string.gsub(sCivType, "CIVILIZATION", "LEADER_MINOR_CIV");
	local sLeaderName = string.find(sCivType, "CIVILIZATION_CSE_") and string.format("LOC_%s_NAME", sLeaderType) or string.format("LOC_%s_NAME", sCivType);
	return sLeaderType, sLeaderName;
end

--[[ =========================================================================
	NEW: 
=========================================================================== ]]
function AdjustCityStatesSliderRange(c, minimumValue, b) 
	local sRuleset = GameConfiguration.GetValue("RULESET");
	local iMapSizeType = MapConfiguration.GetMapSize();
	local bFreeCities = (sRuleset == "RULESET_EXPANSION_1" or sRuleset == "RULESET_EXPANSION_2");
	local iNumPlayers = #(GameConfiguration.GetParticipatingPlayerIDs());
	local iMaxPlayers = bFreeCities and 62 or 63;
	local bUncapCityStates = GameConfiguration.GetValue("UNCAP_CITY_STATES");

	local maximumValue = bUncapCityStates and (iMaxPlayers - iNumPlayers) or g_tMaxCityStatesByMapSize[iMapSizeType] and g_tMaxCityStatesByMapSize[iMapSizeType] or 30;

	local numSteps = maximumValue - minimumValue;
	local stepNum = c.OptionSlider:GetStep();
	c.OptionSlider:SetNumSteps(numSteps);
	if b and (stepNum > numSteps) then 
		c.OptionSlider:SetStep(numSteps);
		c.NumberDisplay:SetText(tostring(numSteps));
	end

	return maximumValue, stepNum;
end

--[[ =========================================================================
	NEW: 
=========================================================================== ]]
Pre_ECSS_GameParameters_UI_DefaultCreateParameterDriver  = GameParameters_UI_DefaultCreateParameterDriver;
function GameParameters_UI_DefaultCreateParameterDriver(o, parameter, parent) 
	-- store the original value of parent if the original function must be called, which is the most likely outcome
	local ORIGINAL_parent = parent;

	if(parent == nil) then
		parent = GetControlStack(parameter.GroupId);
	end

	local control;
	
	-- If there is no parent, don't visualize the control.  This is most likely a player parameter.
	if(parent == nil) then
		return;
	end;

	if (g_bIsEnabledECSS and parameter.ParameterId == "CityStateCount") then	-- configure the City-States slider
		local minimumValue = parameter.Values.MinimumValue;
		local maximumValue = parameter.Values.MaximumValue;

		-- Get the UI instance
		local c = g_SliderParameterManager:GetInstance();	

		-- Store the root control, NOT the instance table.
		g_SortingMap[tostring(c.Root)] = parameter;

		c.Root:ChangeParent(parent);
		if c.StringName ~= nil then
			c.StringName:SetText(parameter.Name);
		end

		c.OptionTitle:SetText(parameter.Name);
		c.Root:SetToolTipString(parameter.Description);
		c.OptionSlider:RegisterSliderCallback(function() 
			local maximumValue, stepNum = AdjustCityStatesSliderRange(c, minimumValue, true);
			
			-- This method can get called pretty frequently, try and throttle it.
			if(parameter.Value ~= minimumValue + stepNum) then
				o:SetParameterValue(parameter, minimumValue + stepNum);
				BroadcastGameConfigChanges();
			end
		end);

		control = {
			Control = c,
			UpdateValue = function(value) 
				local maximumValue, stepNum = AdjustCityStatesSliderRange(c, minimumValue, false);

				if(value) then 
					if value > maximumValue then value = maximumValue; end
					c.OptionSlider:SetStep(value - minimumValue);
					c.NumberDisplay:SetText(tostring(value));
				end
			end,
			UpdateValues = function(values) 
				local maximumValue, stepNum = AdjustCityStatesSliderRange(c, values.MinimumValue, true);
			end,
			SetEnabled = function(enabled, parameter)
				c.OptionSlider:SetHide(not enabled or parameter.Values == nil or parameter.Values.MinimumValue == parameter.Values.MaximumValue);
			end,
			SetVisible = function(visible, parameter)
				c.Root:SetHide(not visible or parameter.Value == nil );
			end,
			Destroy = function()
				g_SliderParameterManager:ReleaseInstance(c);
			end,
		};	
	else -- call original function with ORIGINAL_parent in case parent changed above
		control = Pre_ECSS_GameParameters_UI_DefaultCreateParameterDriver(o, parameter, ORIGINAL_parent);
	end

	return control;
end

--[[ =========================================================================
	NEW: 
=========================================================================== ]]
Pre_ECSS_CreateSimpleParameterDriver = CreateSimpleParameterDriver;
function CreateSimpleParameterDriver(o, parameter, parent) 
	-- store the original value of parent if the original function must be called, which is the most likely outcome
	local ORIGINAL_parent = parent;

	if(parent == nil) then
		parent = GetControlStack(parameter.GroupId);
	end

	local control;
	
	-- If there is no parent, don't visualize the control.  This is most likely a player parameter.
	if(parent == nil) then
		return;
	end;

	if (g_bIsEnabledECSS and parameter.ParameterId == "CityStateCount") then	-- configure the City-States slider
		local minimumValue = parameter.Values.MinimumValue;
		local maximumValue = parameter.Values.MaximumValue;

		-- Get the UI instance
		local c = g_SliderParameterManager:GetInstance();	

		-- Store the root control, NOT the instance table.
		g_SortingMap[tostring(c.Root)] = parameter;

		c.Root:ChangeParent(parent);
		if c.StringName ~= nil then
			c.StringName:SetText(parameter.Name);
		end

		c.OptionTitle:SetText(parameter.Name);
		c.Root:SetToolTipString(parameter.Description);
		c.OptionSlider:RegisterSliderCallback(function() 
			local maximumValue, stepNum = AdjustCityStatesSliderRange(c, minimumValue, true);
			
			-- This method can get called pretty frequently, try and throttle it.
			if(parameter.Value ~= minimumValue + stepNum) then
				o:SetParameterValue(parameter, minimumValue + stepNum);
				BroadcastGameConfigChanges();
			end
		end);

		control = {
			Control = c,
			UpdateValue = function(value) 
				local maximumValue, stepNum = AdjustCityStatesSliderRange(c, minimumValue, false);

				if(value) then 
					if value > maximumValue then value = maximumValue; end
					c.OptionSlider:SetStep(value - minimumValue);
					c.NumberDisplay:SetText(tostring(value));
				end
			end,
			UpdateValues = function(values) 
				local maximumValue, stepNum = AdjustCityStatesSliderRange(c, values.MinimumValue, true);
			end,
			SetEnabled = function(enabled, parameter)
				c.OptionSlider:SetHide(not enabled or parameter.Values == nil or parameter.Values.MinimumValue == parameter.Values.MaximumValue);
			end,
			SetVisible = function(visible, parameter)
				c.Root:SetHide(not visible or parameter.Value == nil );
			end,
			Destroy = function()
				g_SliderParameterManager:ReleaseInstance(c);
			end,
		};	
	else -- call original function with ORIGINAL_parent in case parent changed above
		control = Pre_ECSS_CreateSimpleParameterDriver(o, parameter, ORIGINAL_parent);
	end

	return control;
end

--[[ =========================================================================
	NEW: 
=========================================================================== ]]
function GenerateNewSeed(s) 
	if type(s) ~= "string" then 
		print("[i]: Invalid argument type, aborting");
		return;
	end
	s = string.upper(s);
	if (s ~= "GAME" and s ~= "MAP" and s ~= "BOTH") then 
		print(string.format("[i]: Argument %s is invalid, aborting", s));
		return;
	end
	local iGameSeed = GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED");
	local iMapSeed = MapConfiguration.GetValue("RANDOM_SEED");
	print(string.format("[i]: Current seeds: Game %d | Map %d", tostring(iGameSeed), tostring(iMapSeed)));
	print(string.format("[i]: Generating new seeds (%s) . . .", s));
	GameConfiguration.RegenerateSeeds();
	if (s == "GAME") then 
		if iMapSeed then 
			print(string.format("[i]: Restoring previous Map seed (%d) . . .", iMapSeed));
			MapConfiguration.SetValue("RANDOM_SEED", iMapSeed);
		else 
			print("[i]: Previous Map seed was invalid, keeping new seed");
		end
	elseif (s == "MAP") then 
		if iGameSeed then 
			print(string.format("[i]: Restoring previous Game seed (%d) . . .", iGameSeed));
			GameConfiguration.SetValue("GAME_SYNC_RANDOM_SEED", iGameSeed);
		else 
			print("[i]: Previous Game seed was invalid, keeping new seed");
		end
	end
	iGameSeed = GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED");
	iMapSeed = MapConfiguration.GetValue("RANDOM_SEED");
	print(string.format("[i]: New seeds: Game %d | Map %d", iGameSeed, iMapSeed));
end

--[[ =========================================================================
	NEW: 
	l is the table of localized City-States names
	a is the assignment counter
	n is the number of assignments to make
	p is the pool of City-States to make assignments from
	s is the list of valid Player slots
	b indicates whether assignments should be reserved (true) or active (false)
	r is the reservation counter
=========================================================================== ]]
function AssignMinorPlayerSlots(l, a, n, p, s, b, r) 
	a = (a > 0) and a or 0;
	r = (b and r > 0) and r or 0;
	local iStatus = b and SlotStatus.SS_RESERVED or SlotStatus.SS_COMPUTER;
	while (a < n and #p > 0 and #s > 0) do 
		local iSlotID = s[#s];
		local pPlayerConfig = PlayerConfigurations[iSlotID];
		local sCivilizationType = p[#p].CivilizationType;
		local sCivilizationName = l[sCivilizationType];
		local sLeaderType, sLeaderName = GetLeaderFromMinorCivilizationType(sCivilizationType);
		pPlayerConfig:SetSlotStatus(iStatus);
		pPlayerConfig:SetLeaderName(sLeaderName);
		pPlayerConfig:SetLeaderTypeName(sLeaderType);
		pPlayerConfig:SetCivilizationTypeName(sCivilizationType);
		print(string.format("[%d]: Slot %s %s", iSlotID, b and "reserved for" or "assigned to", sCivilizationName));
		a = a + 1;
		if b then r = r + 1; end
		table.remove(p);
		table.remove(s);
	end
	return a, p, s, r;
end

--[[ =========================================================================
	NEW: 
=========================================================================== ]]
function SetMinorPlayers() 
	local iLoggingLevel = GameConfiguration.GetValue("GAME_ECFE_LOGGING");
	-- local print = (iLoggingLevel > 1) and print or function (s, ...) return; end;    -- disable print function when logging level is not Normal or higher
	print(g_sRowOfDashes);
	
	-- abort here if the city-states slider value is zero
	local iNumCityStates = GameConfiguration.GetValue("CITY_STATE_COUNT");
	if iNumCityStates == 0 then 
		print("[ECSS]: The City-States slider value is 'zero' at game start; skipping custom assignment");
		return;
	end

	-- abort here if YnAMP is enabled and the selected map enforces TSL
	-- local sSelectCS = MapConfiguration.GetValue("SelectCityStates");
	local bOnlyTSL = g_bIsEnabledYnAMP and MapConfiguration.GetValue("OnlyLeadersWithTSL") or false;
	if bOnlyTSL then 
		print("[ECSS]: YnAMP is enabled and using only TSL; skipping custom assignment");
		return;
	end

	-- fetch all available city-states values and count from the config DB
	local sRuleset = GameConfiguration.GetValue("RULESET");
	local sCityStateDomain = g_tCityStateDomains[sRuleset] and g_tCityStateDomains[sRuleset] or "StandardCityStates";
	local sPlayerDomain = g_tPlayerDomains[sRuleset] and g_tPlayerDomains[sRuleset] or "Players:StandardPlayers";
	local tFullList = DB.ConfigurationQuery(g_sCityStatesQuery, sCityStateDomain);
	local iNumCityStatesAvailable = (tFullList and #tFullList > 0) and #tFullList or 0;
	local sCityStatesAvailable = string.format("[ECSS]: %d City-State%s available in the pool at game start", iNumCityStatesAvailable, (iNumCityStatesAvailable ~= 1) and "s are" or " is");
	-- abort here if there are no available city-states
	if iNumCityStatesAvailable == 0 then 
		print(string.format("%s; skipping custom assignment", sCityStatesAvailable));
		return;
	else 
		print(sCityStatesAvailable);
	end

	-- fetch excluded city-states values and count from setup parameter
	local tExcludedCityStates = {};
	local tExclusionList = GameConfiguration.GetValue("EXCLUDE_CITY_STATES");
	local iNumCityStatesExcluded = (tExclusionList and #tExclusionList > 0) and #tExclusionList or 0;
	local sCityStatesExcluded = string.format("[ECSS]: %d City-State%s been 'excluded' from consideration", iNumCityStatesExcluded, (iNumCityStatesExcluded ~= 1) and "s have" or " has");
	-- abort here if every available city-state has been excluded; otherwise parse the exclusion list
	if iNumCityStatesExcluded == iNumCityStatesAvailable then 
		print(string.format("%s; skipping custom assignment", sCityStatesExcluded));
		return;
	else 
		print(sCityStatesExcluded);
		if iNumCityStatesExcluded > 0 then 
			for _, cs in ipairs(tExclusionList) do 
				tExcludedCityStates[cs] = true;
			end
		end
	end

	-- initialize the city-states pool
	local tCityStatesPool = {};

	-- fetch priority city-states values and count from setup parameter
	local tPriorityCityStates = {};
	local tPriorityList = GameConfiguration.GetValue("PRIORITY_CITY_STATES");
	local iNumCityStatesPrioritized = (tPriorityList and #tPriorityList > 0) and #tPriorityList or 0;
	local sCityStatesPrioritized = string.format("[ECSS]: %d City-State%s been selected for priority consideration", iNumCityStatesPrioritized, (iNumCityStatesPrioritized ~= 1) and "s have" or " has");
	-- abort here if the priority list is empty, or if every available city-state has been prioritized; otherwise parse the shuffled priority list and add priority city-states to the pool
	if (iNumCityStatesPrioritized == 0) or (iNumCityStatesPrioritized == iNumCityStatesAvailable) then 
		print(string.format("%s; skipping custom assignment", sCityStatesPrioritized));
		return;
	else 
		print(sCityStatesPrioritized);
		if iNumCityStatesPrioritized > 0 then 
			for _, cs in ipairs(ShuffleTable(tPriorityList)) do 
				if not tExcludedCityStates[cs] then 
					tPriorityCityStates[cs] = true;
					table.insert(tCityStatesPool, { Priority = (#tCityStatesPool + 1), CivilizationType = cs, });
				end
			end
		end
	end

	-- initialize the table of localized City-State names
	local tLocalizedNames = {};

	-- use the full list and the exclusion and priority tables to determine the contents of the selection list
	local tSelectionList = {};
	local iNumCityStatesSelected = iNumCityStatesAvailable - iNumCityStatesExcluded - iNumCityStatesPrioritized;
	print(string.format("[ECSS]: %d City-State%s been selected for normal consideration", iNumCityStatesSelected, (iNumCityStatesSelected ~= 1) and "s have" or " has"));
	print(g_sRowOfDashes);
	for _, v in ipairs(tFullList) do 
		cs = v.CivilizationType;
		name = Locale.Lookup(v.Name);
		tLocalizedNames[cs] = name;
		if tExcludedCityStates[cs] then 
			print(string.format("[-]: %s will 'NOT' be considered for assignment", name));
		elseif tPriorityCityStates[cs] then 
			print(string.format("[*]: %s will be considered for *PRIORITY* assignment", name));
		else 
			table.insert(tSelectionList, cs);
			print(string.format("[+]: %s will be considered for normal assignment", name));
		end
	end
	-- if the selection list is not empty, shuffle it, parse it, and add selected city-states to the pool
	if iNumCityStatesSelected > 0 then 
		for _, cs in ipairs(ShuffleTable(tSelectionList)) do 
			table.insert(tCityStatesPool, { Priority = (#tCityStatesPool + 1), CivilizationType = cs, });
		end
	end
	-- sort the pool in descending order of priority value; this will filter priority selections to the end of the pool, where they will be operated on first
	table.sort(tCityStatesPool, function (a, b) return a.Priority > b.Priority; end);
	
	local bBarbarianClans = GameConfiguration.GetValue("GAMEMODE_BARBARIAN_CLANS");
	local bFreeCities = (sRuleset == "RULESET_EXPANSION_1" or sRuleset == "RULESET_EXPANSION_2");
	local tPlayerIDs = GameConfiguration.GetParticipatingPlayerIDs();
	local iNumPlayers = #tPlayerIDs;
	local iMaxPlayers = bFreeCities and 62 or 63;
	local iMaxPlayerID = iMaxPlayers - 1;
	local iMaxCityStates = iMaxPlayers - iNumPlayers;
	local tAvailableSlotsList = {};
	print(g_sRowOfDashes);
	for slot = iNumPlayers, iMaxPlayerID do 
		local pPlayerConfig = PlayerConfigurations[slot];
		if (pPlayerConfig:GetSlotStatus() == SlotStatus.SS_CLOSED) then 
			table.insert(tAvailableSlotsList, slot);
		end
	end
	local iNumAvailableSlots = (tAvailableSlotsList and #tAvailableSlotsList > 0) and #tAvailableSlotsList or 0;
	local sAvailableSlots = string.format("[ECSS]: Identified %d available Player slot%s", iNumAvailableSlots, (iNumAvailableSlots ~= 1) and "s" or "");
	if iNumAvailableSlots == 0 then 
		print(string.format("%s; skipping custom assignment", sAvailableSlots));
		return;
	else 
		print(sAvailableSlots);
	end
	-- sort the list of available Player slots in descending order of slot ID
	table.sort(tAvailableSlotsList, function (a, b) return a > b; end);
	local iNumAssignments, iNumReservations = 0, 0;
	print(string.format("[ECSS]: Attempting to assign %d City-State%s beginning with Player slot %d . . .", iNumCityStates, (iNumCityStates ~= 1) and "s" or "", tAvailableSlotsList[#tAvailableSlotsList]));
	iNumAssignments, tCityStatesPool, tAvailableSlotsList, iNumReservations = AssignMinorPlayerSlots(tLocalizedNames, iNumAssignments, iNumCityStates, tCityStatesPool, tAvailableSlotsList, false, 0);
	local sAssignments = string.format("[ECSS]: Successfully assigned %d City-State%s", iNumAssignments, (iNumAssignments ~= 1) and "s" or "");
	if (#tCityStatesPool == 0 or #tAvailableSlotsList == 0) then 
		local sTerminate = (#tCityStatesPool == 0) and "there are 'zero' City-States remaining in the pool" or "there are 'zero' valid Player slots remaining";
		print(string.format("%s; %s", sAssignments, sTerminate));
		return;
	else 
		print(sAssignments);
	end
	if bBarbarianClans then 
		print(string.format("[ECSS]: Attempting to reserve %d remaining Player slot%s for Barbarian Clans . . .", #tAvailableSlotsList, (#tAvailableSlotsList ~= 1) and "s" or ""));
		iNumAssignments, tCityStatesPool, tAvailableSlotsList, iNumReservations = AssignMinorPlayerSlots(tLocalizedNames, iNumAssignments, iMaxCityStates, tCityStatesPool, tAvailableSlotsList, true, iNumReservations);
		print(string.format("[ECSS]: Successfully reserved %d Player slot%s for Barbarian Clans", iNumReservations, (iNumReservations ~= 1) and "s" or ""));
	end
end

--[[ =========================================================================
	OVERRIDE: 
=========================================================================== ]]

--[[ =========================================================================
	log successful loading of this component
=========================================================================== ]]
print("[i]: Finished loading GameSetupLogic_ECSS.lua, proceeding . . .");

--[[ =========================================================================
	end gamesetuplogic_ecss.lua configuration script
=========================================================================== ]]
