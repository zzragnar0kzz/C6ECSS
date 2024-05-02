--[[ =========================================================================
	C6ECSS : Enhanced City-States Selection for Civilization VI
    Copyright (c) 2024 zzragnar0kzz
    All rights reserved.
=========================================================================== ]]

--[[ =========================================================================
	this is the built-in CityStatePicker.lua script with modifications
=========================================================================== ]]
include("InstanceManager");
include("PlayerSetupLogic");
include("Civ6Common");

print("[i]: Enhanced City-States Selection (ECSS) v1 (2024-01-27)");
print("[+]: Loading CityStatePicker.lua . . .");

-- ===========================================================================
-- CONSTANTS
-- ===========================================================================

local XP2_RULESETUP:string = "RULESET_EXPANSION_2";
local XP1_RULESETUP:string = "RULESET_EXPANSION_1";

-- ===========================================================================
-- Members
-- ===========================================================================

local m_pItemIM:table = InstanceManager:new("ItemInstance",	"Button", Controls.ItemsPanel);

local m_kParameter:table = nil		-- Reference to the parameter being used. 
local m_kSelectedValues:table = nil	-- Table of string->boolean that represents checked off items.
local m_kItemList:table = nil;		-- Table of controls for select all/none

local m_bInvertSelection:boolean = false;

local m_kCityStateDataCache:table = {};

local m_kCityStateCountParam:table = nil;

local m_RulesetType:string = "";

local m_numSelected:number = 0;

-- Track the number of city-states to spawn when opening the picker
-- Used to revert to that number in case the user modifies the parameter then backs out of the picker
local m_OriginalCityStateCount:number = 0;

-- ECSS: additional members >>>
local m_kPriority:table         = nil;    -- reference to the priority list
local m_kPriorityValues:table   = nil;    -- table of string->boolean that represents prioritized items
local m_bInvertPriority:boolean = false;  -- 
local m_numPriority:number      = 0;      -- 
-- <<< ECSS

-- ===========================================================================
function Close()	
	-- Clear any temporary global variables.
	m_kParameter = nil;
	m_kSelectedValues = nil;
	m_kPriorityValues = nil;  -- ECSS

	ContextPtr:SetHide(true);
end

--[[ =========================================================================
	ECSS: validate priority selections
=========================================================================== ]]
function IsItemPrioritized(item: table) 
	return m_kPriorityValues[item.Value] == true;
end

-- ===========================================================================
function IsItemSelected(item: table) 
	return m_kSelectedValues[item.Value] == true;
end

-- ===========================================================================
function OnBackButton()
	Close();
	LuaEvents.CityStatePicker_SetParameterValue(m_kCityStateCountParam.ParameterId, m_OriginalCityStateCount);
end

-- ===========================================================================
function OnConfirmChanges()
	-- Generate sorted list from selected values.
	local values = {}
	for k, v in pairs(m_kSelectedValues) do
		if (v) then
			table.insert(values, k);
		end
	end

	-- ECSS: generate sorted priority list >>>
	local priority = {};
	for k, v in pairs(m_kPriorityValues) do 
		if (v) then 
			table.insert(priority, k);
		end
	end
	-- <<< ECSS

	LuaEvents.CityStatePicker_SetParameterValues(m_kParameter.ParameterId, values);

	-- ECSS: update priority list parameter settings and log changes to selection and priority lists >>>
	GameConfiguration.SetValue("PRIORITY_CITY_STATES", priority);
	GameConfiguration.SetValue("PRIORITY_CITY_STATES_COUNT", #priority);
	print(string.format("[i]: Confirming %d %s and %d priority %s", #values, (#values ~= 1) and "exclusions" or "exclusion", #priority, (#priority ~= 1) and "selections" or "selection"));
	-- <<< ECSS

	Close();
end

--[[ =========================================================================
	ECSS: (de)prioritize an item
=========================================================================== ]]
function OnItemPrioritize(item :table, checkBox :table, priority :table)
	local value = item.Value;
	local prioritized = not m_kPriorityValues[value];

	-- ensure this item's selection box is checked when it is prioritized
	if (prioritized == true) and m_kSelectedValues[item.Value] then 
		m_kSelectedValues[item.Value] = false;
		checkBox:SetCheck(true);
	end

	m_kPriorityValues[item.Value] = prioritized;
	if m_bInvertPriority then
		priority:SetCheck(not prioritized);
	else
		priority:SetCheck(prioritized);
	end

	m_numPriority = prioritized and (m_numPriority + 1) or (m_numPriority - 1);
	GameConfiguration.SetValue("PRIORITY_CITY_STATES_COUNT", m_numPriority);
	RefreshCountWarning();
end

-- ===========================================================================
function OnItemSelect(item :table, checkBox :table, priority :table)
	local value = item.Value;
	local selected:boolean = not m_kSelectedValues[value];

	-- ECSS: ensure this item is not prioritized when its selection box is unchecked >>>
	if (selected == true) and m_kPriorityValues[item.Value] then 
		m_kPriorityValues[item.Value] = false;
		priority:SetCheck(false);
		m_numPriority = (m_numPriority - 1);
		GameConfiguration.SetValue("PRIORITY_CITY_STATES_COUNT", m_numPriority);
	end
	-- <<< ECSS

	m_kSelectedValues[item.Value] = selected;
	if m_bInvertSelection then
		checkBox:SetCheck(not selected);
	else
		checkBox:SetCheck(selected);
	end

	RefreshCountWarning();
end

--[[ =========================================================================
	ECSS: cycle selected --> prioritized --> deselected for this item
=========================================================================== ]]
function CycleCheckboxes(item :table, checkBox :table, priority :table) 
	local value = item.Value;
	if m_kSelectedValues[value] and not m_kPriorityValues[value] then 
		OnItemSelect(item, checkBox, priority);
	elseif not m_kSelectedValues[value] and not m_kPriorityValues[value] then 
		OnItemPrioritize(item, checkBox, priority);
	elseif not m_kSelectedValues[value] and m_kPriorityValues[value] then 
		OnItemSelect(item, checkBox, priority);
	end
end

-- ===========================================================================
function OnItemFocus(item :table)
	if(item) then
		Controls.FocusedItemName:SetText(item.Name);

		local backColor:number, frontColor:number = UI.GetPlayerColorValues(item.Value, 0);
		local kCityStateData:table = GetCityStateData(item.Value);

		local description:string = Locale.ToUpper("LOC_CITY_STATES_SUZERAIN_BONUSES");

        if kCityStateData ~= nil then
            if kCityStateData.Bonus_XP2 ~= nil and m_RulesetType == XP2_RULESETUP and IsExpansion2Enabled() then
                description = description .. "[NEWLINE]" .. Locale.Lookup(kCityStateData.Bonus_XP2);
            elseif kCityStateData.Bonus_XP1 ~= nil and (m_RulesetType == XP1_RULESETUP or m_RulesetType == XP2_RULESETUP) and IsExpansion1Enabled() then
                description = description .. "[NEWLINE]" .. Locale.Lookup(kCityStateData.Bonus_XP1);
            elseif kCityStateData ~= nil then
                description = description .. "[NEWLINE]" .. Locale.Lookup(kCityStateData.Bonus);
            end
        end

		Controls.FocusedItemDescription:LocalizeAndSetText(description);

		-- Icon
		Controls.FocusedItemIcon:SetIcon(item.Icon);
		Controls.FocusedItemIcon:SetHide(false);
		Controls.FocusedItemIcon:SetColor(frontColor);
	end
end

-- ===========================================================================
function GetCityStateData( civType:string )
	-- Refresh the cache if needed
	if m_kCityStateDataCache[civType] == nil then

		m_kCityStateDataCache[civType] = {};

		local query:string = "SELECT CityStateCategory, Bonus, Bonus_XP1, Bonus_XP2 from CityStates where CivilizationType = ?";
		local kResults:table = DB.ConfigurationQuery(query, civType);
		if(kResults) then
			for i,v in ipairs(kResults) do
				for name, value in pairs(v) do
					m_kCityStateDataCache[civType][name] = value;
				end
			end
		end
	end

	return m_kCityStateDataCache[civType];
end

--[[ =========================================================================
	ECSS: (de)prioritize all items
=========================================================================== ]]
function PrioritizeAllItems(bState: boolean)
	m_numPriority = bState and 0 or m_numPriority;
	for _, node in ipairs(m_kItemList) do
		local item:table = node["item"];
		local priority:table = node["priority"];

		priority:SetCheck(bState);
		if m_bInvertPriority then
			m_kPriorityValues[item.Value] = not bState;
		else
			m_kPriorityValues[item.Value] = bState;
		end
		m_numPriority = bState and (m_numPriority + 1) or (m_numPriority - 1);
	end
	m_numPriority = (m_numPriority < 0) and 0 or m_numPriority;
	GameConfiguration.SetValue("PRIORITY_CITY_STATES_COUNT", m_numPriority);
end

-- ===========================================================================
function SetAllItems(bState: boolean)
	for _, node in ipairs(m_kItemList) do
		local item:table = node["item"];
		local checkBox:table = node["checkbox"];

		checkBox:SetCheck(bState);
		if m_bInvertSelection then
			m_kSelectedValues[item.Value] = not bState;
		else
			m_kSelectedValues[item.Value] = bState;
		end
	end
end

--[[ =========================================================================
	ECSS: prioritize all items; ensure all items are selected first
=========================================================================== ]]
function OnPrioritizeAll()
	SetAllItems(true);
	PrioritizeAllItems(true);
	RefreshCountWarning();
end

-- ===========================================================================
function OnSelectAll()
	SetAllItems(true);
	RefreshCountWarning();
end

--[[ =========================================================================
	ECSS: deprioritize all items
=========================================================================== ]]
function OnPrioritizeNone()
	PrioritizeAllItems(false);
	RefreshCountWarning();
end

-- ===========================================================================
function OnSelectNone()
	PrioritizeAllItems(false);  -- ECSS: deprioritize all items before deselecting them
	SetAllItems(false);
	RefreshCountWarning();
end

-- ===========================================================================
function ParameterInitialize(parameter : table, pGameParameters:table)
	m_kParameter = parameter;
	m_kSelectedValues = {};

	m_kCityStateCountParam = pGameParameters.Parameters["CityStateCount"];
	m_OriginalCityStateCount = m_kCityStateCountParam.Value;

	local kRulesetParam = pGameParameters.Parameters["Ruleset"];
	m_RulesetType = kRulesetParam.Value.Value;

	if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
		m_bInvertSelection = true;
	else
		m_bInvertSelection = false;
	end

	if(parameter.Value) then
		for i,v in ipairs(parameter.Value) do
			m_kSelectedValues[v.Value] = true;
		end
	end

	-- ECSS: priority selections >>>
	-- m_kPriority = pGameParameters.Parameters["CityStatesPriority"];
	m_kPriorityValues = {};
	m_numPriority = GameConfiguration.GetValue("PRIORITY_CITY_STATES_COUNT") or 0;

	local priorityCityStatesConfig = GameConfiguration.GetValue("PRIORITY_CITY_STATES");
	if (priorityCityStatesConfig and #priorityCityStatesConfig > 0) then 
		for i, v in ipairs(priorityCityStatesConfig) do 
			m_kPriorityValues[v] = true;
		end
		m_numPriority = #priorityCityStatesConfig;
		GameConfiguration.SetValue("PRIORITY_CITY_STATES_COUNT", m_numPriority);
	end
	-- <<< ECSS

	-- Controls.TopDescription:SetText(parameter.Description);
	Controls.TopDescription:SetText(Locale.Lookup("LOC_CITY_STATES_PICKER_DESC"));  -- ECSS: set extended top description
	Controls.WindowTitle:SetText(parameter.Name);
	m_pItemIM:ResetInstances();

	RefreshList();
	RefreshCountWarning()

	InitCityStateCountSlider(pGameParameters);
	InitSortByFilter();

	OnItemFocus(parameter.Values[1]);
end

-- ===========================================================================
function RefreshList( sortByFunc )

	m_numSelected = 0;
	-- m_numPriority = 0;  -- ECSS: 
	m_kItemList = {};

	-- Sort list
	table.sort(m_kParameter.Values, sortByFunc ~= nil and sortByFunc or SortByName);

	-- Update UI
	m_pItemIM:ResetInstances();
	for i, v in ipairs(m_kParameter.Values) do
		InitializeItem(v);
	end
end

-- ===========================================================================
function RefreshCountWarning()
	if m_kParameter ~= nil then
		local numSelected:number = 0;

		for i, v in ipairs(m_kParameter.Values) do
			if not IsItemSelected(v) then
				numSelected = numSelected + 1;
			end
		end

		if numSelected < m_kCityStateCountParam.Value then
			Controls.ConfirmButton:SetDisabled(true);
			Controls.CountWarning:SetText(Locale.ToUpper(Locale.Lookup("LOC_CITY_STATE_PICKER_COUNT_WARNING", m_kCityStateCountParam.Value, m_kCityStateCountParam.Value - numSelected)));
		else
			Controls.ConfirmButton:SetDisabled(false);
			Controls.CountWarning:SetText("");
		end
	end
end

-- ===========================================================================
function SortByName(kItemA:table, kItemB:table)
	return Locale.Compare(kItemA.Name, kItemB.Name) == -1;
end

-- ===========================================================================
function SortByType(kItemA:table, kItemB:table)
	local kItemDataA:table = GetCityStateData(kItemA.Value);
	local kItemDataB:table = GetCityStateData(kItemB.Value);

	if kItemDataA.CityStateCategory ~= nil and kItemDataB.CityStateCategory ~= nil then
		return Locale.Compare(kItemDataA.CityStateCategory, kItemDataB.CityStateCategory) == -1;
	else
		return false;
	end
end

-- ===========================================================================
function InitCityStateCountSlider( pGameParameters:table )

	local kValues:table = m_kCityStateCountParam.Values;

	Controls.CityStateCountNumber:SetText(m_kCityStateCountParam.Value);
	Controls.CityStateCountSlider:SetNumSteps(kValues.MaximumValue - kValues.MinimumValue);
	Controls.CityStateCountSlider:SetStep(m_kCityStateCountParam.Value - kValues.MinimumValue);

	Controls.CityStateCountSlider:RegisterSliderCallback(function()
		local stepNum:number = Controls.CityStateCountSlider:GetStep();
		local value:number = m_kCityStateCountParam.Values.MinimumValue + stepNum;
			
		-- This method can get called pretty frequently, try and throttle it.
		if(m_kCityStateCountParam.Value ~= value) then
			pGameParameters:SetParameterValue(m_kCityStateCountParam, value);
			Controls.CityStateCountNumber:SetText(value);
			Network.BroadcastGameConfig();
			RefreshCountWarning();
		end
	end);

end

-- ===========================================================================
function InitSortByFilter()

	local uiButton:object = Controls.SortByPulldown:GetButton();
	uiButton:SetText(Locale.Lookup("LOC_CITY_STATE_PICKER_SORT_NAME"));

	Controls.SortByPulldown:ClearEntries();

	local pNameEntryInst:object = {};
	Controls.SortByPulldown:BuildEntry( "InstanceOne", pNameEntryInst );
	pNameEntryInst.Button:SetText(Locale.Lookup("LOC_CITY_STATE_PICKER_SORT_NAME"));
	pNameEntryInst.Button:RegisterCallback( Mouse.eLClick, 
		function() 
			Controls.SortByPulldown:GetButton():SetText(Locale.Lookup("LOC_CITY_STATE_PICKER_SORT_NAME"));
			RefreshList(SortByName);
		end );

	local pTypeEntryInst:object = {};
	Controls.SortByPulldown:BuildEntry( "InstanceOne", pTypeEntryInst );
	pTypeEntryInst.Button:SetText(Locale.Lookup("LOC_CITY_STATE_PICKER_SORT_TYPE"));
	pTypeEntryInst.Button:RegisterCallback( Mouse.eLClick, 
		function() 
			Controls.SortByPulldown:GetButton():SetText(Locale.Lookup("LOC_CITY_STATE_PICKER_SORT_TYPE"));
			RefreshList(SortByType);
		end );

	Controls.SortByPulldown:CalculateInternals();
end

-- ===========================================================================
function InitializeItem(item:table)
	local c: table = m_pItemIM:GetInstance();
	c.Name:SetText(item.Name);

	local backColor, frontColor = UI.GetPlayerColorValues(item.Value, 0);

	c.Icon:SetIcon(item.Icon);
	c.Icon:SetColor(frontColor);
	c.IconBacking:SetColor(backColor);

	c.Button:RegisterCallback( Mouse.eMouseEnter, function() OnItemFocus(item); end );
	c.Button:RegisterCallback( Mouse.eLClick, function() CycleCheckboxes(item, c.Selected, c.Priority); end );     -- ECSS: cycle selected --> prioritized --> deselected
	c.Button:SetToolTipString(Locale.Lookup("LOC_CS_BUTTON_TT_TEXT"));                                             -- ECSS: update button tooltip text
	c.Selected:RegisterCallback( Mouse.eLClick, function() OnItemSelect(item, c.Selected, c.Priority); end );      -- ECSS: (un)check the selection box
	c.Selected:SetToolTipString(Locale.Lookup("LOC_CS_SELECTED_TT_TEXT"));                                         -- ECSS: update selected checkbox tooltip text
	c.Priority:RegisterCallback( Mouse.eLClick, function() OnItemPrioritize(item, c.Selected, c.Priority); end );  -- ECSS: (un)check the priority box
	c.Priority:SetToolTipString(Locale.Lookup("LOC_CS_PRIORITY_TT_TEXT"));                                         -- ECSS: update priority checkbox tooltip text
	if m_bInvertSelection then
		c.Selected:SetCheck(not IsItemSelected(item));
	else
		c.Selected:SetCheck(IsItemSelected(item));
		m_numSelected = m_numSelected + 1;
	end
	-- ECSS: m_bInvertPriority should always be false, so this can probably be shortened >>>
	if m_bInvertPriority then 
		c.Priority:SetCheck(not IsItemPrioritized(item));
	else 
		c.Priority:SetCheck(IsItemPrioritized(item));
		-- m_numPriority = m_numPriority + 1;
	end
	-- <<< ECSS

	local listItem:table = {};
	listItem["item"] = item;
	listItem["checkbox"] = c.Selected;
	listItem["priority"] = c.Priority;  -- ECSS: add the priority box to listItem
	table.insert(m_kItemList, listItem);
end

-- ===========================================================================
function OnShutdown()
	Close();
	m_pItemIM:DestroyInstances();
	LuaEvents.CityStatePicker_Initialize.Remove( ParameterInitialize );
end

-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then
		local key:number = pInputStruct:GetKey();
		if key == Keys.VK_ESCAPE then
			OnBackButton();
		end
	end
	return true;
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetInputHandler( OnInputHandler, true );

	local OnMouseEnter = function() UI.PlaySound("Main_Menu_Mouse_Over"); end;

	Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnBackButton );
	Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, OnMouseEnter);
	Controls.ConfirmButton:RegisterCallback( Mouse.eLClick, OnConfirmChanges );
	Controls.ConfirmButton:RegisterCallback( Mouse.eMouseEnter, OnMouseEnter);
	Controls.SelectAllButton:RegisterCallback( Mouse.eLClick, OnSelectAll);
	Controls.SelectAllButton:RegisterCallback( Mouse.eMouseEnter, OnMouseEnter);
	Controls.SelectNoneButton:RegisterCallback( Mouse.eLClick, OnSelectNone);
	Controls.SelectNoneButton:RegisterCallback( Mouse.eMouseEnter, OnMouseEnter);
	-- ECSS: prioritize all and none controls >>>
	-- Controls.PrioritizeAllButton:RegisterCallback( Mouse.eLClick, OnPrioritizeAll);
	-- Controls.PrioritizeAllButton:RegisterCallback( Mouse.eMouseEnter, OnMouseEnter);    -- ENWS: prioritizing all would essentially turn the priority list into the selection list
	Controls.PrioritizeNoneButton:RegisterCallback( Mouse.eLClick, OnPrioritizeNone);
	Controls.PrioritizeNoneButton:RegisterCallback( Mouse.eMouseEnter, OnMouseEnter);
	-- <<< ECSS

	LuaEvents.CityStatePicker_Initialize.Add( ParameterInitialize );
end
Initialize();
