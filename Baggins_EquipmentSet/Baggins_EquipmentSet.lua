-- Add EquipmentSet category/section/bags in Baggins
local ADDON_NAME, ns = ...

-- TODO:
--	Baggins takes a lot of time when saving an equipment set
--	localization

if not Baggins then return end

local dewdrop = AceLibrary("Dewdrop-2.0")
if not dewdrop then return end

-- Constants
local EquipmentSetBagName = "EquipmentSet" -- localizable
local EquipmentSetBankBagName = "BankEquipmentSet" -- localizable
-- local ArmorCategoryName = "Armure" -- localizable
-- local WeaponsCategoryName = "Armes" -- localizable
local RuleTypeOne = "EquipmentSet"
local RuleTypeAny = "AnyEquipmentSet"

-- tekDebug
local tekWarningDisplayed = false
local tekDebugFrame = tekDebug and tekDebug:GetFrame(ADDON_NAME) -- tekDebug support
local function debug(lvl, ...)
	local params = strjoin(" ", ...)
	if tekDebugFrame then
		tekDebugFrame:AddMessage(params)
	else
		if not tekWarningDisplayed then
			print("tekDebug not found. Debug message disabled")
			tekWarningDisplayed = true
		end
	end
end

-- Add custom rule (a particular equipment set)
Baggins:AddCustomRule(RuleTypeOne, {
	DisplayName = "Equipment Set", -- localizable
	Description = "Filter by equipment set", -- localizable
	Matches = function(bag, slot, rule)
		local isInSet, setName = GetContainerItemEquipmentSetInfo(bag, slot) -- setName is a CSV of sets
		if isInSet then
			local tokens = { strsplit(", ", setName) }
			for _, token in ipairs(tokens) do
				if token == rule.setName then
					return true
				end
			end
		end
		return false
	end,
	GetName = function(rule) 
		return rule.setName
	end,
	DewDropOptions = function(rule, level, value) 
		if level == 1 then
			dewdrop:AddLine("text", "Equipment Set Options", "isTitle", true) -- localizable
			dewdrop:AddLine("text", "Equipment Set", "hasArrow", true, "value", "EquipmentSetList") -- localizable
		elseif level == 2 and value == "EquipmentSetList" then
			local numSets = GetNumEquipmentSets()
			for i = 1, numSets, 1 do
				local equipmentSetName = GetEquipmentSetInfo(i)
				dewdrop:AddLine(
					"text", equipmentSetName,
					"checked", rule.setName == equipmentSetName,
					"func", function(equipmentSetName) 
						rule.setName = equipmentSetName
						Baggins:OnRuleChanged()
					end,
					"arg1", equipmentSetName
				)
			end
		end
	end,
})

-- Add custom rule (any equipment set)
Baggins:AddCustomRule(RuleTypeAny, {
	DisplayName = "Any equipment Set", -- localizable
	Description = "Filter if in an equipment set", -- localizable
	Matches = function(bag, slot, rule)
		-- local texture, itemCount, locked, quality, readable, lootable, itemLink = GetContainerItemInfo(bag, slot)
		local isInSet, setName = GetContainerItemEquipmentSetInfo(bag, slot)
		-- if isInSet then
			-- print("ANY:"..tostring(texture).."  "..tostring(isInSet).."  "..tostring(setName))
		-- end
		if isInSet then
			return true
		else
			return false
		end
	end,
	GetName = function(rule) 
		return "Any equipment Set"
	end,
	DewDropOptions = function(rule, level, value) 
		if level == 1 then
			dewdrop:AddLine("text", "Any equipment Set", "isTitle", true) -- localizable
		end
	end,
})

-- Get EquipmentSet bag and create it if not found
local function GetBag(bagName, isBank)
	local bagID
	local bagFound = false
	for index, bag in ipairs(Baggins.db.profile.bags) do
		if bag.name == bagName then
			bagID = index
			bagFound = true
			break
		end
	end
	if not bagFound then
		debug(100, "Create bag:"..bagName.." bank:"..tostring(isBank))
		Baggins:NewBag(bagName)
		bagID = #Baggins.db.profile.bags
	end
	local bag = Baggins.db.profile.bags[bagID]
	bag.isBank = isBank
	bag.openWithAll = true
	--debug(100,"bag:"..tostring(bag).." "..tostring(bagID).." "..tostring(bagName))
	return bag, bagID
end

-- Set categories rule and create new category if needed
local function UpdateCategories()
	local numSets = GetNumEquipmentSets()
	for i = 1, numSets, 1 do
		local equipmentSetName = GetEquipmentSetInfo(i)
		local categoryName = "EquipmentSet"..i
		local category = Baggins.db.profile.categories[categoryName]
		if not category then
			-- Create category
			debug(100, "Create category:"..categoryName)
			Baggins:NewCategory(categoryName)
			category = Baggins.db.profile.categories[categoryName]
		end
		-- Set rule to category
		table.remove(category, 1) -- only one rule
		debug(100, "Assign rule "..RuleTypeOne.."["..tostring(equipmentSetName).."] to category "..categoryName)
		local rule = {type = RuleTypeOne, operation = "OR", setName = equipmentSetName}
		table.insert(category, rule)
	end
	-- -- Disable unused categories
	-- for i = numSets+1, 100, 1 do
		-- local categoryName = "EquipmentSet"..i
		-- local category = Baggins.db.profile.categories[categoryName]
		-- if not category then
			-- break
		-- end
		-- debug(100, "Disable category:"..categoryName)
		-- table.remove(category, 1) -- only one rule
	-- end
	-- Delete unused categories
	for i = numSets+1, 100, 1 do
		local categoryName = "EquipmentSet"..i
		local category = Baggins.db.profile.categories[categoryName]
		if not category then
			break
		end
		debug(100, "Delete category:"..categoryName)
		Baggins:RemoveCategory(categoryName)
	end
end

-- Rename sections in EquipmentSet bag and create new sections if needed
local function UpdateSections(bag, bagID)
	local numSets = GetNumEquipmentSets()
	-- Update/Create sections
	for i = 1, numSets, 1 do
		local sectionName = GetEquipmentSetInfo(i)
		local section = bag.sections[i]
		if section then
			-- Update section name
			section.name = sectionName
		else
			-- Create a new section
			debug(100, "Create section:"..sectionName)
			Baggins:NewSection(bagID, sectionName)
			section = bag.sections[i]
		end
		-- Set category
		section.cats = {} -- remove any categories
		local categoryName = "EquipmentSet"..i
		debug(100, "Assign category "..categoryName.." to section "..sectionName.." in bag "..bag.name)
		Baggins:AddCategory(bagID, i, categoryName)
	end
	---- Disable unused sections
	-- for i = numSets+1, #bag.sections, 1 do
		-- local section = bag.sections[i]
		-- debug(100, "Disable section:"..section.name)
		-- section.cats = {} -- remove any categories
	-- end
	-- Remove unused sections
	local numSectionsToRemove = #bag.sections - numSets
	for i = 1, numSectionsToRemove, 1 do
		local index = numSets+1
		local section = bag.sections[index]
		debug(100, "Delete section:"..section.name)
		Baggins:RemoveSection(bagID, index)
	end
end

local function UpdateBagginsEquipmentSet()
	-- Update categories
	UpdateCategories()

	-- Update bag
	local bag, bagID = GetBag(EquipmentSetBagName, false)
	UpdateSections(bag, bagID)
	-- Update bank bag
	local bankBag, bankBagID = GetBag(EquipmentSetBankBagName, true)
	UpdateSections(bankBag, bankBagID)

	-- Update baggins
	Baggins:ResortSections()
	Baggins:BuildWaterfallTree()
	Baggins:ForceFullRefresh()
	Baggins:UpdateBags()
	Baggins:UpdateLayout()
end

-- local function UpdateBagginsArmorWeaponsCategories()
	-- -- Get armor category
	-- local armorCategory = Baggins.db.profile.categories[ArmorCategoryName]
	-- if armorCategory then
-- print("armor category found")
	-- end

	-- local weaponsCategory = Baggins.db.profile.categories[WeaponsCategoryName]
	-- if weaponsCategory then
-- print("weapons category found")
	-- end
-- end

local _Baggins_OnEnable = Baggins.OnEnable -- save original function
function Baggins:OnEnable(firstload)
	-- call original function
	_Baggins_OnEnable(self, firstload)

	if not Baggins.db.profile.bags or not Baggins.db.profile.categories then return end

	UpdateBagginsEquipmentSet()
	-- UpdateBagginsArmorWeaponsCategories()
end

local handler = CreateFrame("Frame", "Baggins_EquipmentSet")
handler:RegisterEvent("EQUIPMENT_SETS_CHANGED")
handler:SetScript("OnEvent", function(self, event)
	debug(100, "EQUIPMENT_SETS_CHANGED")
	UpdateBagginsEquipmentSet()
end)


--[[
function Baggins:OnEnable(firstload)
	-- call original function
	_Baggins_OnEnable(self, firstload)

	if not Baggins.db.profile.bags or not Baggins.db.profile.categories then return end

	-- Create EquipmentSet bag if not found
	local bagID
	local bagFound = false
	for index, bag in ipairs(Baggins.db.profile.bags) do
		if bag.name == EquipmentSetBagName then
			bagID = index
			bagFound = true
			break
		end
	end
	if not bagFound then
		debug(100, "Create bag:"..EquipmentSetBagName)
		Baggins:NewBag(EquipmentSetBagName)
		bagID = #Baggins.db.profile.bags
	end
	local bag = Baggins.db.profile.bags[bagID]
	debug(100,"bag:"..tostring(bag).." "..tostring(bagID).." "..tostring(EquipmentSetBagName))

	-- Create a section/category for each EquipmentSet if not found
	local numSets = 1--GetNumEquipmentSets()
	for i = 1, numSets, 1 do
		local equipmentSetName = GetEquipmentSetInfo(i)
		-- section
		local sectionName = equipmentSetName
		local sectionFound = false
		local sectionID
		for index, section in ipairs(bag.sections) do
			if section.name == sectionName then
				sectionFound = true
				sectionID = index
				break
			end
		end
		if not sectionFound then
			debug(100, "Create section:"..sectionName)
			Baggins:NewSection(bagID, sectionName)
			sectionID = #bag.sections
		end
		local section = bag.sections[sectionID]
		debug(100,"section:"..tostring(section).." "..tostring(sectionID).." "..tostring(sectionName))
		-- category
		local categoryName = EquipmentSetBagName..equipmentSetName
		if not Baggins.db.profile.categories[categoryName] then
			debug(100, "Create category:"..categoryName)
			Baggins:NewCategory(categoryName)
			-- add rule to category
			local category = Baggins.db.profile.categories[categoryName]
			debug(100, "Assigning rule "..RuleTypeOne.." to category "..categoryName)
			local rule = {type = RuleTypeOne, operation = "OR", setName = equipmentSetName}
			table.insert(category, rule)
		end
		debug(100,"category:"..tostring(categoryName))
		-- add category to section if not found
		local categoryFound = false
		for index, category in ipairs(section.cats) do
			debug(100, "category "..tostring(index).."  "..tostring(category.name))
			if category.name == categoryName then
				categoryFound = true
				break
			end
		end
		if not categoryFound then
			debug(100, "Add category "..categoryName.." to section "..sectionName.." in bag "..EquipmentSetBagName)
			Baggins:AddCategory(bagID, sectionID, categoryName)
		end
	end
end
--]]