local TotalTimePlayed = 0;
local IgnoreEvents = false

tutorial_text = {
	"Questgivers have exclamation marks over their heads.  Talk to questgivers by moving close to them and right clicking on them..",
	"You can move with the ASDW keys, with the arrow keys or by holding down both the left and right mouse buttons.",
	"You can rotate your camera view by dragging the left mouse button in the play field.  You can rotate your character and your view at the same time by dragging the right mouse button in the play field.",
	"Left-Click selects a target and Right-Click interacts with them.",
	"You enter combat mode by right clicking on your target and then moving into combat range.  You will automatically start swinging at your target.",
	"You can cast spells and use special abilities on the enemy by clicking on the buttons in your action bar along the lower left portion of the screen.",
	"Right-Click on a creature’s corpse to loot it.  You can then right click on items in the loot pane to place them in your backpack.",
	"An item went into your backpack. You can click on the backpack button in the lower right part of the screen to open your backpack.  Move the mouse over the item to see what it is.",
	"Right click on items to use them.  You can drag usable items to your action bar if you want to be able to use it without opening your backpack.",
	"You can put bags in the empty bag spaces in the lower right part of your screen next to the backpack, and then click on them to open them.",
	"You can eat some food to regain your health faster.  Click on the food icon in the action bar across the bottom left of your screen.  Food will not work in combat however.",
	"You can drink to regain your mana faster.  Click on the drink icon in the action bar across the bottom left of your screen.  The mana regeneration will stop if you do any other ability or get in combat.",
	"You can learn a new talent in the talent interface.  The talent interface is brought up by clicking on the character button in your action panel and then selecting the talents tab.",
	"You can go to your trainer in your the starting area and learn a new skill.  You may have to search around a little to find your trainer.",
	"You can move spells and abilities to your action bar by opening the abilities page with the button in the bottom center of the screen and then dragging the ability icon to your action bar.  You can also use a spell or ability from the abilities page by clicking on it.",
	"You can look at your reputation with different groups in the world in the character pane under the reputation tab.",
	"You can respond to that player by hitting the R key and then typing a message, or by typing /tell <theirname> and then the message.",
	"You can invite another player to your group by right clicking on their portrait and selecting the Invite option from the popup menu.",
}

-- Might be able to trigger this by hooking to some inventory event later on.
-- TUTORIAL_ITEMS = "An item went into your backpack. You can click on the backpack button in the lower right part of the screen to open your backpack.  Move the mouse over the item to see what it is.";

tutorial_tittle = {
	"Questgivers",
	"Movement",
	"Cameras",
	"Targeting",
	"Combat Mode",
	"Spells and Abilities",
	"Looting",
	"Backpack",
	"Using Items",
	"Bags",
	"Food",
	"Drink",
	"Learning Talents",
	"Trainers",
	"Spells and Abilities Book",
	"Reputation",
	"Replying to Tells",
	"Grouping",
}

TUTORIALFRAME_QUEUE = {};

function TutorialExtend_OnLoad()
	local currXP = UnitXP("player");
	-- Only hook to events if experience equals 0 (New Player)
	if( currXP == 0 ) then
		this:RegisterEvent("TIME_PLAYED_MSG");
		this:RegisterEvent("PLAYER_ENTERING_WORLD");
	end
end

function TutorialExtend_OnEvent()
	-- On entering world, request time played, which will later trigger 'TIME_PLAYED_MSG'
	if( event == "PLAYER_ENTERING_WORLD" ) then
		RequestTimePlayed();
	end
	
	if( event == "TIME_PLAYED_MSG" ) then
		TotalTimePlayed = floor(arg1);
		-- Check if TotalTimePlayed is less than 5 seconds.
		if( TotalTimePlayed < 5 ) then
			InitializeTutorials();
		end
	end
end

function InitializeTutorials()
	
	local currXP = UnitXP("player");
	if currXP == 0 then
		for i=1, 18 do
			TutorialFrame_NewTutorial(i);
		end
	end
end