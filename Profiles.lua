﻿local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;
local ADD = LibStub("AddonDropDown-1.0");
local WQT_Utils = addon.WQT_Utils;
local WQT_Profiles = addon.WQT_Profiles;

local _profileReferenceList = {};


-- TODO

-- Make active profile per character

local function ReferenceListSort(a, b)
	-- Default always on top, and in case of duplicate labels
	if (a.arg1 == 0 or b.arg1 == 0) then
		return a.arg1 < b.arg1;
	end
	
	if(a.label:lower() == b.label:lower()) then
		if(a.label == b.label) then
			-- Juuuust incase
			return a.arg1 < b.arg1;
		end
		return a.label < b.label;
	end
	
	-- Alphabetical 
	return a.label:lower() < b.label:lower();
end

local function ProfileNameIsAvailable(name)
	for k, v in pairs(WQT.db.global.profiles) do
		if (v.name == name) then
			return false;
		end
	end
	return true;
end

local function CopyIfNil(a, b)
	for k, v in pairs(b) do
		local curVal = a[k];
		if (curVal == nil) then
			-- No value, add the default one
			if (type(v) == "table") then
				a[k] = CopyTable(v);
			else
				a[k] = v;
			end
		elseif (type(curVal) == "table") then
			CopyIfNil(curVal, v);
		end
	end
end

local function AddCategoryDefaults(category)
	if (not _V["WQT_DEFAULTS"].global[category]) then
		return;
	end
	-- In case a setting doesn't have a newer category yet
	if (not WQT.settings[category]) then
		WQT.settings[category] = {};
	end
	
	CopyIfNil(WQT.settings[category], _V["WQT_DEFAULTS"].global[category]);
end

local function AddDefaultsToActive()
	AddCategoryDefaults("general");
	AddCategoryDefaults("list");
	AddCategoryDefaults("pin");
	AddCategoryDefaults("filters");
end

local function LoadProfileInternal(id, profile)
	WQT.db.char.activeProfile = id;
	WQT.settings = profile;
	AddDefaultsToActive();
end

local function ConvertDefaultProfile()
	local profile = {
		["name"] = DEFAULT
		,["general"] = CopyTable(WQT.db.global.general or {})
		,["list"] = CopyTable(WQT.db.global.list or {})
		,["pin"] = CopyTable(WQT.db.global.pin or {})
		,["filters"] = CopyTable(WQT.db.global.filters or {})
	}
	WQT.db.global.general = nil;
	WQT.db.global.list = nil;
	WQT.db.global.pin = nil;
	WQT.db.global.filters = nil;
	
	WQT.db.global.profiles[0] = profile;
	LoadProfileInternal(0, profile);
end

local function GetProfileById(id)
	for index, profile in ipairs(_profileReferenceList) do
		if (profile.arg1 == id) then
			return profile, index
		end
	end
end

local function AddProfileToReferenceList(id, name)
	if (not GetProfileById(id)) then
		tinsert(_profileReferenceList, {["label"] = name, ["arg1"] = id});
	end
end

function WQT_Profiles:InitSettings()
	WQT.settings = {["general"] = {}, ["list"] = {}, ["pin"] = {}, ["filters"] = {}};
	if (not WQT.db.global.profiles[0]) then
		ConvertDefaultProfile();
	end
	
	for id, profile in pairs(WQT.db.global.profiles) do
		AddProfileToReferenceList(id, profile.name);
	end
	
	self:Load(WQT.db.char.activeProfile);
end

function WQT_Profiles:GetProfiles()
	-- Make sure names are up to date
	for index, refProfile in ipairs(_profileReferenceList) do
		local profile = WQT.db.global.profiles[refProfile.arg1];
		if (profile) then
			refProfile.label = profile.name;
		end
	end
	
	-- Sort
	table.sort(_profileReferenceList, ReferenceListSort);

	return _profileReferenceList;
end

function WQT_Profiles:CreateNew()
	local id = time();
	if (GetProfileById(id)) then
		-- Profile for current timestamp already exists. Don't spam the bloody button
		return;
	end
	
	-- Get current settings to copy over
	local currentSettings = WQT.db.global.profiles[WQT.db.char.activeProfile];

	if (not currentSettings) then
		return;
	end
	
	-- Create new profile
	local profile = {
		["name"] = self:GetFirstValidProfileName()
		,["general"] = CopyTable(currentSettings.general or {})
		,["list"] = CopyTable(currentSettings.list or {})
		,["pin"] = CopyTable(currentSettings.pin or {})
		,["filters"] = CopyTable(currentSettings.filters or {})
	}
	
	WQT.db.global.profiles[id] = profile;
	AddProfileToReferenceList(id, profile.name);
	self:Load(id);
end

function WQT_Profiles:LoadIndex(index)
	local profile = _profileReferenceList[index];
	
	if (profile) then
		self:LoadDefault();
		return;
	end
	
	self:Load(profile.id);
end

function WQT_Profiles:Load(id)
	WQT_Profiles:ClearDefaultsFromActive();

	if (not id or id == 0) then
		self:LoadDefault();
		return;
	end

	local profile = WQT.db.global.profiles[id];
	
	if (not profile) then
		-- Profile not found
		self:LoadDefault();
		return;
	end
	LoadProfileInternal(id, profile);
end

function WQT_Profiles:Delete(id)
	if (not id or id == 0) then
		-- Trying to delete the default profile? That's a paddlin'
		return;
	end
	
	local profile, index = GetProfileById(id);
	
	if (index) then
		tremove(_profileReferenceList, index);
		WQT.db.global.profiles[id] = nil;
	end

	self:LoadDefault();
end

function WQT_Profiles:LoadDefault()
	LoadProfileInternal(0, WQT.db.global.profiles[0]);
end

function WQT_Profiles:DefaultIsActive()
	return not WQT or not WQT.db.global or not WQT.db.char.activeProfile or WQT.db.char.activeProfile == 0
end

function WQT_Profiles:IsValidProfileId(id)
	if (not id or id == 0) then 
		return false;
	end
	return WQT.db.global.profiles[id] and true or false;
end

function WQT_Profiles:GetFirstValidProfileName(baseName)
	if(not baseName) then
		local playerName = UnitName("player"); -- Realm still returns nill, sick
		local realmName = GetRealmName();
		baseName = ITEM_SUFFIX_TEMPLATE:format(playerName, realmName);
	end
	
	if (ProfileNameIsAvailable(baseName)) then
		return baseName;
	end
	-- Add a number
	local suffix = 2;
	local combinedName = ITEM_SUFFIX_TEMPLATE:format(baseName, suffix);
	
	while (not ProfileNameIsAvailable(combinedName)) do
		suffix = suffix + 1;
		combinedName = ITEM_SUFFIX_TEMPLATE:format(baseName, suffix);
	end
	
	return combinedName;
end

function WQT_Profiles:ChangeActiveProfileName(newName)
	local profileId = self:GetActiveProfileId();
	if (not profileId or profileId == 0) then
		-- Don't change the default profile name
		return;
	end
	-- Add suffix number in case of duplicate
	newName = WQT_Profiles:GetFirstValidProfileName(newName);
	
	local profile = GetProfileById(profileId);
	if(profile) then
		profile.label = newName;
		WQT.db.global.profiles[profileId].name = newName;
	end
end

function WQT_Profiles:GetActiveProfileId()
	return WQT.db.char.activeProfile;
end

function WQT_Profiles:GetIndexById(id)
	local profile, index = GetProfileById(id);
	return index or 0;
end

function WQT_Profiles:GetActiveProfileName()
	local activeProfile = WQT.db.char.activeProfile;
	if(activeProfile == 0) then
		return DEFAULT;
	end
	
	local profile = WQT.db.global.profiles[activeProfile or 0];
	
	return profile and profile.name or "Invalid Profile";
end

local function test(a, b)
	for k, v in pairs(b) do
		if (type(a[k]) == "table" and type(v) == "table") then
			test(a[k], v);
			if (next(a[k]) == nil) then
				a[k] = nil;
			end
		elseif (a[k] ~= nil and a[k] == v) then
			a[k] = nil;
		end
	end
end

function WQT_Profiles:ClearDefaultsFromActive()
	local category = "general";
	
	test(WQT.settings[category], _V["WQT_DEFAULTS"].global[category]);
	category = "list";
	test(WQT.settings[category], _V["WQT_DEFAULTS"].global[category]);
	category = "pin";
	test(WQT.settings[category], _V["WQT_DEFAULTS"].global[category]);
	category = "filters";
	test(WQT.settings[category], _V["WQT_DEFAULTS"].global[category]);
end

