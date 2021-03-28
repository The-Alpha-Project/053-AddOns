TARGETDISTANCE_UPDATE_RATE = 0.1

local textureHeight = nil;
local textureWidth = nil;
local mapFileName = nil;

function TargetDistance_OnLoad()
	TargetDistanceFrame.TimeSinceLastUpdate = 0;
	
	if(not (Cosmos_RegisterConfiguration == nil)) then
		Cosmos_RegisterConfiguration("COS_TARGETDISTANCEHEADER", "SEPARATOR", TARGETDISTANCE_SEP, TARGETDISTANCE_SEP_INFO );
		Cosmos_RegisterConfiguration("COS_TARGETDISTANCE", "CHECKBOX", 
			TARGETDISTANCE_CHECK, 
			TARGETDISTANCE_CHECK_INFO,
			TargetDistance_Toggle,
			1
			);
	else
		-- ADD STANDALONE CONFIG HERE
	end
	
end

function TargetDistance_Toggle(toggle)
	if ( toggle == 1 ) then 
		ShowUIPanel(TargetDistanceFrame);
	else
		HideUIPanel(TargetDistanceFrame);
	end
end

function TargetDistance_OnUpdate(arg1)
	if ( (( TaxiFrame ) and ( TaxiFrame:IsVisible() )) or (( MerchantFrame ) and ( MerchantFrame:IsVisible() )) or ((TradeSkillFrame) and (TradeSkillFrame:IsVisible())) or ((SuggestFrame) and (SuggestFrame:IsVisible())) or ((WhoFrame) and (WhoFrame:IsVisible())) or ((AuctionFrame) and (AuctionFrame:IsVisible())) or ((MailFrame) and (MailFrame:IsVisible())) ) then
		TargetDistanceText:SetText("Disabled");
		return;
	end
	TargetDistanceFrame.TimeSinceLastUpdate = TargetDistanceFrame.TimeSinceLastUpdate + arg1;
	if(not TargetFrame:IsShown()) then
		return;
	end

	if( TargetDistanceFrame.TimeSinceLastUpdate > TARGETDISTANCE_UPDATE_RATE ) then
		if ( TargetDistance_SetContinent() == 1) then
			local distance = TargetDistance_GetDistanceText();
			if (distance) then
				TargetDistanceText:SetText(format(TARGETDISTANCE_DISTANCE,distance));
			else
				TargetDistanceText:SetText("Disabled");
			end
		else
			TargetDistanceText:SetText("Disabled");
		end
		TargetDistanceFrame.TimeSinceLastUpdate = 0;
	end
end

function TargetDistance_GetDistanceText()
	if (mapFileName==nil or textureHeight==nil or textureWidth==nil) then
		return nil;
	end
	local tx, ty = GetPlayerMapPosition("target"); 
	local px, py = GetPlayerMapPosition("player");
	
	if(tx == 0 and ty == 0) then
		  -- probably in an instance, no map position
		return nil;
	end
	
	if(px == 0 and py == 0) then
		  -- probably in an instance, no map position
		return nil;
	end

	tx = textureWidth * tx;
	ty = textureHeight * ty;

	px = textureWidth * px;
	py = textureHeight * py;

	local xdelta = tx-px;
	local ydelta = ty-py;

	local distance = 0;
	
	  -- For some reason I had to weight the distance formula in favor of the exponentiated xdelta
	  -- otherwise the distance is reported incorrectly along the x axis, and correctly along the y axis.
	distance = sqrt(math.pow(xdelta,2)*2+math.pow(ydelta,2));
	
	  -- until a better way of finding distance comes around, these formulas
	  -- roughly calibrate the calculated distance to yards via tested constants
	  -- on the respective continents
	if((string.find("Azeroth",mapFileName) ~= nil)) then
		distance = math.floor((math.floor(distance*10000)/7450)*10);
	elseif((string.find("Kalimdor",mapFileName) ~= nil)) then
		distance = math.floor((math.floor(distance*10000)/7000)*10);
	else
		return nil;
	end

	return distance.."";
end

function TargetDistance_SetContinent()
	local x, y = GetPlayerMapPosition("player");
	local continent = GetCurrentMapContinent();
	
	if(x == 0 and y == 0) then
		if ( continent == 1) then
			continent = 2;
		elseif( continent == 2) then
			continent = 1;
		else
			return 0;
		end
	end

	if (continent) then
		SetMapZoom(continent, nil);
	else
		return 0;
	end
	
	mapFileName, textureHeight, textureWidth = GetMapInfo();
	return 1;
end