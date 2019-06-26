--[[---------------------------------------------------------------------------
	TitanEquipmentManager 

	This provides integration with the built-in equipment manager allowing
	for the changing of equipment sets via a button / drop down on a 
	titan bar.
-----------------------------------------------------------------------------]]

TitanEquipmentManager = { id="TitanEquipmentMaanger" }

local TEM_POPUP_FRAME_PADDING = 5
local TEM_SETITEM_HEIGHT = 22
local TEM_MIN_POPUP_WIDTH = 180
local TEM_UPDATE_DELAY = 0.50
local TEM_NONE_TEXT = "<none>"

--[[---------------------------------------------------------------------------
	onLoad
		Handles the initialization of our LDB object and registering 
		any events we are interested in.
-----------------------------------------------------------------------------]]
function TitanEquipmentManager:onLoad(frame)
	frame:SetBackdropColor(0,0,0,1)
	frame:SetClipsChildren(true)
	frame:Hide()
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("EQUIPMENT_SETS_CHANGED")
	frame:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
	frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	
	self.mainFrame = frame;	
	self.version = GetAddOnMetadata(self.id, "Version");
	self.author = GetAddOnMetadata(self.id, "Author");
	self.lastUpdate = 0
	self.sets = {}
	
	self.ldbFrame = CreateFrame("Frame");
	self.ldbFrame.obj = LibStub("LibDataBroker-1.1"):NewDataObject(self.id,
		{	
			type ="data source",
			text = TEM_NONE_TEXT,
			label = "Set",
			icon = "Interface\\PaperDollInfoFrame\\UI-EquipmentManager-Toggle.blp",
			OnEnter  = function(frame) TitanEquipmentManager:onEnter(frame) end,
		});	
end

--[[---------------------------------------------------------------------------
	updateButton
		This determines the text for the button on the titan panel bar, 
		this will list all of the active sets, or "<none>" if there are 
		no active sets.

		Note: Sets with missing items are colored red
-----------------------------------------------------------------------------]]
function TitanEquipmentManager:updateButton()
	local text = nil;
	for setIndex = 1,GetNumEquipmentSets() do
	local name, setIcon, _, active, _, _, _, lostItems = GetEquipmentSetInfo(setIndex);
		if active then
			if ((icon == nil) and (setIcon ~= nil)) then
				icon = setIcon;
			end

			if (lostItems > 0) then
				text = (RED_FONT_COLOR_CODE .. name .. FONT_COLOR_CODE_CLOSE);
			end
			
			if (text ~= nil) then
				text = (text .. ", " .. name);
			else
				text = name;
			end
		end
	end

	if (text ~= nil) then
		self.ldbFrame.obj.text = text;
	else
		self.ldbFrame.obj.text = (GRAY_FONT_COLOR_CODE .. TEM_NONE_TEXT .. FONT_COLOR_CODE_CLOSE);
	end
end

--[[---------------------------------------------------------------------------
	updateSetList
		This updates the item set button in our popup frame, these are 
		reused so that we do not create a bunch of uncessary frames. 

		When a set is missing items, it will be disabled in the popup
		and colored red.  
		
		These behave the same way the "equip" button does in the built-in
		equipment manager, it is NOT a toggle.
-----------------------------------------------------------------------------]]
function TitanEquipmentManager:updateSetList()
	local numSets = C_EquipmentSet.GetNumEquipmentSets()
	
	if (numSets ~= 0) then
		local mainFrameHeight = (2 * TEM_POPUP_FRAME_PADDING) + (TEM_SETITEM_HEIGHT * numSets)
		
		self.mainFrame:SetHeight(mainFrameHeight)
		for _,v in pairs(self.sets) do
			v:Hide();
		end

		for index,setId in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
			local name, texture, _, active, items, _, _, lostItems = C_EquipmentSet.GetEquipmentSetInfo(setId)
			local setFrameName =  ("TEM_Popup_ItemSet_" .. index);
			local setFrame = self.sets[index];

			if (setFrame == nil) then	
				setFrame = CreateFrame("Button", setFrameName, self.mainFrame, "TitanEquipmentManager_ItemSetButton");
				self.sets[index] = setFrame;
			end

			local yOffset = - TEM_POPUP_FRAME_PADDING + ((index - 1) * (-TEM_SETITEM_HEIGHT))
			setFrame:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", TEM_POPUP_FRAME_PADDING, yOffset);
			setFrame:SetPoint("TOPRIGHT", self.mainFrame, "TOPRIGHT", -TEM_POPUP_FRAME_PADDING, yOffset);
			setFrame.itemSetName = name;
			setFrame.itemSetId = setId;
			
			if (active) then
				setFrame.Check:Show()
			else
				setFrame.Check:Hide()
			end

			if (texture) then
				setFrame.Icon:SetTexture(texture)
			else
				setFrame.Icon:Hide()
			end
			
			if (lostItems and lostItems > 0) then
				name = (RED_FONT_COLOR_CODE .. name .. FONT_COLOR_CODE_CLOSE)
				setFrame:Disable()
			else
				setFrame:Enable()
			end
		
			local itemText = string.format(" (%d Items)", items)
			if (items == 1) then
				itemText = string.format(" (%d Item)", items)
			end

			setFrame:SetFormattedText("%s%s", name, itemText)
			setFrame:Show()
		end
	end
end

--[[---------------------------------------------------------------------------
	onEnter
		Process the mouse over titan button, this will refresh the popup
		and allow the user select an item set.

		Note: If there are no sets defined, or the player is currently
		in combat this will do nothing.
-----------------------------------------------------------------------------]]
function TitanEquipmentManager:onEnter(buttonFrame)
	local numSets = C_EquipmentSet.GetNumEquipmentSets()
	if (numSets ~= 0 or not UnitAffectingCombat("player")) then
		local width = math.max(TEM_MIN_POPUP_WIDTH, buttonFrame:GetWidth())
		self.buttonFrame = buttonFrame
		self.mainFrame:SetWidth(width)
		self:updateSetList();

		self.mainFrame:ClearAllPoints()
		if (TITAN_PANEL_PLACE_TOP == TitanUtils_GetRealPosition(self.id)) then
			self.mainFrame:SetPoint("TOPLEFT", buttonFrame, "BOTTOMLEFT", 0, -(2 * TEM_POPUP_FRAME_PADDING))
		else
			self.mainFrame:SetPoint("BOTTOMLEFT", buttonFrame, "TOPLEFT", 0, (2 * TEM_POPUP_FRAME_PADDING))
		end
		
		self.mainFrame:Show()
	end
end

--[[---------------------------------------------------------------------------
	onUpdate
		Called perodically for the popup frame, we use this hide popup
		frame when the user has moused-off either the popup or the titan 
		bar button;
-----------------------------------------------------------------------------]]
function TitanEquipmentManager:onUpdate(elapsed)
	if (self.mainFrame:IsVisible()) then
		self.lastUpdate = self.lastUpdate + elapsed
		if (self.lastUpdate > TEM_UPDATE_DELAY) then
			self.lastUpdate = 0
			if (not MouseIsOver(self.mainFrame) and 
				(self.buttonFrame and not MouseIsOver(self.buttonFrame))) then
				self.buttonFrame = nil
				self.mainFrame:Hide()
			end
		end
	end
end

--[[---------------------------------------------------------------------------
	onSetClicked
		Handles clicking on a set item
-----------------------------------------------------------------------------]]
function TitanEquipmentManager:onSetClicked(setButton)
	if (setButton.itemSetId ~= nil) then
		C_EquipmentSet.UseEquipmentSet(setButton.itemSetId)
	end
end

--[[---------------------------------------------------------------------------
	onEvent
		Handles dispatching events 
-----------------------------------------------------------------------------]]
function TitanEquipmentManager:onEvent(event, ...)
	if ((event == "EQUIPMENT_SETS_CHANGED") or 
	    (event == "PLAYER_EQUIPMENT_CHANGED") or
	    (event == "PLAYER_ENTERING_WORLD")) then
		self:updateButton();
		if (self.mainFrame:IsVisible()) then
			self:updateSetList()		
		end
	end
end
