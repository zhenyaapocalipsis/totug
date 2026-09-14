-- SCRIPTED BY jkk - https://steamcommunity.com/id/creamymello/myworkshopfiles/
TESTING = false
testingVars = { buttonZone = 'ee993f', seatedPlayers = {'Blue', 'Teal', 'Purple'} }

playerVars = {
	Red = {
		playMatGuid = '9831b4',
		allZoneGuid = 'a17fdd',
		troopBagGuid = 'd2d6a6',
		troopCounterZoneGuid = '25c5d4',
		deckZoneGuid = '618a08',
		discardZoneGuid = '419e24',
		circleZoneGuid = '134a6a',
		promoteCounterZoneGuid = '88dcce',
		trophyZoneGuid = 'b65e62',
		trophyCounterZoneGuid = 'fdcd9d',
		trophyTroopPosition = {-79.92, 4.76, 13.81},
		playZoneGuid = '840caa',
		playButtonZoneGuid = '7a92e7',
		spyZoneGuids = {'6c6800', '51af56', '10bbd6', 'afb963', '6bf79c'},
		firstPlayerPosition = {-75.80, 1.48, -3.00},
		housePowerPosition = {-58.45, 2.60, 20.09},
		controlMarkerPositions = { {-38.00, 1.68, 5.60}, {-38.00, 1.68, 10.10}, {-38.00, 1.68, 1.10}, {-48.00, 1.68, 13.60}, {-52.50, 1.68, 13.60}, {-57.00, 1.68, 13.60} }
	},
	Blue = {
		playMatGuid = '42a4c6',
		allZoneGuid = 'd27c4a',
		troopBagGuid = 'aff669',
		troopCounterZoneGuid = '45b281',
		deckZoneGuid = '891985',
		discardZoneGuid = '05d893',
		circleZoneGuid = 'b7d7b8',
		promoteCounterZoneGuid = '939800',
		trophyZoneGuid = '05cd29',
		trophyCounterZoneGuid = '14ba24',
		trophyTroopPosition = {71.41, 4.76, 13.85},
		playZoneGuid = '36cb61',
		playButtonZoneGuid = '6bf28a',
		spyZoneGuids = {'34da58', 'b9a6df', '35c10c', 'e5f0b7', '4663fd'},
		firstPlayerPosition = {75.80, 1.48, -3.00},
		housePowerPosition = {58.55, 2.60, 20.10},
		controlMarkerPositions = { {38.00, 1.68, 5.60}, {38.00, 1.68, 10.10}, {38.00, 1.68, 1.10}, {48.00, 1.68, 13.60}, {52.50, 1.68, 13.60}, {57.00, 1.68, 13.60} }
	},
	Purple = {
		playMatGuid = '539004',
		allZoneGuid = 'e80e0a',
		troopBagGuid = '518963',
		troopCounterZoneGuid = '87f88c',
		deckZoneGuid = '04f77b',
		discardZoneGuid = '5d3873',
		circleZoneGuid = 'c5c8b9',
		promoteCounterZoneGuid = 'd429eb',
		trophyZoneGuid = '887fe5',
		trophyCounterZoneGuid = '27ebab',
		trophyTroopPosition = {71.40, 4.76, -24.14},
		playZoneGuid = '8d5cfa',
		playButtonZoneGuid = 'e64af3',
		spyZoneGuids = {'795d46', '75a5e7', 'f91e07', 'c83401', '0e5ece'},
		firstPlayerPosition = {75.80, 1.50, -41.00},
		housePowerPosition = {58.55, 2.60, -17.86},
		controlMarkerPositions = { {38.00, 1.68, -32.40}, {38.00, 1.68, -27.90}, {38.00, 1.68, -36.90}, {48.00, 1.68, -24.40}, {52.50, 1.68, -24.40}, {57.00, 1.68, -24.40} }
	},
	Teal = {
		playMatGuid = 'ff1d1f',
		allZoneGuid = 'b4d12e',
		troopBagGuid = '1e77fa',
		troopCounterZoneGuid = 'e520b5',
		deckZoneGuid = '8e5286',
		discardZoneGuid = '690977',
		circleZoneGuid = 'da8a23',
		promoteCounterZoneGuid = 'a796c9',
		trophyZoneGuid = 'a74f00',
		trophyCounterZoneGuid = '6ba5cc',
		trophyTroopPosition = {-79.85, 4.76, -24.17},
		playZoneGuid = 'f4f328',
		playButtonZoneGuid = 'fe2033',
		spyZoneGuids = {'373806', 'd04a01', '3bec52', '37c0cd', '36f93e'},
		firstPlayerPosition = {-75.80, 1.50, -41.00},
		housePowerPosition = {-58.45, 2.60, -17.78},
		controlMarkerPositions = { {-38.00, 1.68, -32.40}, {-38.00, 1.68, -27.90}, {-38.00, 1.68, -36.90}, {-48.00, 1.68, -24.40}, {-52.50, 1.68, -24.40}, {-57.00, 1.68, -24.40} }
	}
}
seatedPlayerColors = {}

-- Power/Influence resource pool (see "resourcePoolEnabled" toggle under Extras). Per the rulebook (p.7-8)
-- these aren't tracked with physical pieces in the real game - you gain them from cards and must expend them
-- the same turn or lose them - so by default the mod leaves this on the honor system like it always has.
-- When the toggle is on, this table tracks each seated player's current pool, a button pair on their play
-- area displays it live, and the four base actions with a fixed Power cost (Deploy/Assassinate/Return enemy
-- spy) automatically check and deduct from it. Recruit's Influence cost isn't auto-deducted (the mod has no
-- parsed "cost" field per card to read), so the Influence counter can be adjusted manually: left-click the
-- button to spend 1, right-click to refund/add 1.
resourcePool = { Red = {power = 0, influence = 0}, Blue = {power = 0, influence = 0}, Purple = {power = 0, influence = 0}, Teal = {power = 0, influence = 0} }
demonwebPowerCosts = { deploy = 1, assassinate = 3, returnSpy = 3 }

-- Mercenaries card automation state (see "mercenariesCardMenus" and demonwebResolveEndOfTurnEffects()).
-- demonwebFreeActions: credits granted by a card's own "Deploy a troop"/"Assassinate a troop"/"Return an
-- enemy spy" instruction (free, per rulebook p.9 - cards' own instructions aren't the same as the paid
-- resource-pool action) - consumed by the existing hotkeys/context-menu items instead of charging Power.
-- (Kept as their own top-level globals rather than fields on "status" below, since these are initialized
-- here, before "status" itself is declared further down the file.)
demonwebFreeActions = { Red = {deploy = 0, assassinate = 0, returnSpy = 0}, Blue = {deploy = 0, assassinate = 0, returnSpy = 0}, Purple = {deploy = 0, assassinate = 0, returnSpy = 0}, Teal = {deploy = 0, assassinate = 0, returnSpy = 0} }
demonwebCheapAssassinateDiscount = {}	-- [playerColor] = true for the rest of their turn (Hobgoblin Warlord)
demonwebStealOnRecruit = {}		-- [playerColor] = true for the rest of their turn (Xanathar Zushaxx)
demonwebPendingPromote = {}		-- [playerColor] = guid of the card to exclude, resolved at end of turn (Xanathar Smuggler)
demonwebStolenMarkers = {}		-- [controlMarkerGuid] = thief playerColor, until the start of their next turn (Bregan D'aerthe Spy)

playerRatings = {}		-- [steamId] = {name = <last known display name>, rating = <number>, games = <count>} -
						-- local cache only now; the source of truth is the Google Sheet behind
						-- ratingsApiUrl, shared across every save file/device rather than tied to this one
ratingStartingValue = 1200
ratingKFactor = 32
ratingsApiUrl = 'https://script.google.com/macros/s/AKfycbzNdRRsGg-eXNci277u9_P_-BoIKfR8XjdjDIJV0RybrQ4GyQyIVsjoJr9Do2RVwYVd/exec'	-- paste the deployed Google Apps Script /exec URL here (see
												-- Code.gs) - ratings are disabled (silently) until this is set
hexColors = { White = '[ffffff]', Brown = '[713b17]', Red = '[da1a18]', Orange = '[f4641d]', Yellow = '[e7e52c]', Green = '[31b32b]', Teal = '[21b19b]', Blue = '[1e87ff]', Purple = '[a020f0]', Pink = '[f570ce]', Black = '[404040]', Grey = '[808080]' }
faceup = {0,180,0}
facedown = {0,180,180}
tileY = 1.60

boardSections = {
	left = {
		controlMarkers = {
			{name = 'Gauntlgrym', totalControlVp = 1, guid = 'fbdd4d', buttonZoneGuid = '405f7f', siteZoneGuid = '6f7cc7'},
			{name = "Ch'Chitl", totalControlVp = 1, guid = '66ab70', buttonZoneGuid = 'f023cc', siteZoneGuid = '38b07a'}
		},
		siteZoneGuids = { '7e86a6', '6f7cc7',  'b30d72', '101cfe',  'd38f93', '38b07a' },
		whiteTroopPositions = { {-23.39, 1.98, 28.63}, {-22.08, 1.98, 28.62}, {-23.07, 1.98, 11.37}, {-23.14, 1.98, 3.07}, {-21.84, 1.98, 3.07}, {-23.41, 1.98, -11.50}, {-22.13, 1.98, -11.50} }
	},
	right = {
		controlMarkers = {
			{name = 'The Phaerlin', totalControlVp = 1, guid = '8c9a11', buttonZoneGuid = 'de0671', siteZoneGuid = '5dbedf'},
			{name = "Ss'zuraass'nee", totalControlVp = 1, guid = 'b993de', buttonZoneGuid = 'bc6df3', siteZoneGuid = '4f6598'}
		},
		siteZoneGuids = { '0415af', '5dbedf',  '74df09', 'dc04ba',  '4f6598'},
		whiteTroopPositions = { {19.48, 1.98, 22.67}, {20.76, 1.98, 22.66}, {16.94, 1.98, 13.56}, {18.24, 1.98, 13.57}, {19.26, 1.98, 3.53}, {20.57, 1.98, 3.53}, {17.83, 1.98, -12.75}, {19.12, 1.98, -12.73} }
	},
	center = {
		controlMarkers = {
			{name = 'Menzoberranzan', totalControlVp = 2, guid = 'dd834c', buttonZoneGuid = 'c815f6', siteZoneGuid = 'eaeacf'},
			{name = 'Araumycos', totalControlVp = 3, guid = '2a2981', buttonZoneGuid = '801598', siteZoneGuid = 'e58429'},
			{name = 'Tsenviilyq', totalControlVp = 1, guid = '94b849', buttonZoneGuid = '418f33', siteZoneGuid = '63546d'}
		},
		siteZoneGuids = {  '6fa038', 'eaeacf',  'd14d31', '0e9119',  '309fde', '3588ca', 'a4d91e', 'a091c3',  'e58429', '60aef9',  '377510', '37c56b', '9e10d1', 'a8df27', '63546d' },
		whiteTroopPositions = { {-8.10, 1.98, 31.61}, {-6.79, 1.98, 31.59}, {-7.38, 1.98, 28.31}, {-1.24, 1.98, 28.74}, {0.05, 1.98, 28.76}, {1.39, 1.98, 28.75}, {-9.99, 1.98, 23.49}, {-8.65, 1.98, 23.48}, {-12.24, 1.98, 16.88}, {-10.97, 1.98, 16.88}, {10.27, 1.98, 16.90}, {2.04, 1.98, 13.04}, {-12.20, 1.98, 9.56}, {-4.12, 1.98, 7.74}, {6.39, 1.98, 5.09}, {-0.06, 1.98, 4.23}, {1.25, 1.98, 4.22}, {-0.03, 1.98, 3.03}, {1.25, 1.98, 3.05}, {0.12, 1.98, 0.68}, {-12.43, 1.98, -0.02}, {-11.17, 1.98, -0.03}, {0.15, 1.98, -13.22}, {1.47, 1.98, -13.20}, {2.78, 1.98, -13.21} }
	}
}
market = {
	top = { '94a58d', 'a4f699', '5b8124', 'f8ff5c', 'f2f8ab', '78735e' },
	bottom = { 'fea283', 'cf43c3', 'ae0841', '02e99b' }
}
devourZoneGuid = '0bb5b2'
halfDeckZones = { Drow = 'dc0dab', Dragons = 'a6c606', Demons = '136966', Elementals = 'c30c04', Aberrations = 'e3bb05', Undead = '837a1a', Mercenaries = '05cf23', Siege = '4288c1', custom = '1dc643' }
housePowersZoneGuid = '7fd6a1'		-- zone/deck for the optional "House Powers" permanent player-artifact cards (not a half-deck; not used for recruiting)
-- Alternate art for the 7 site control-marker tiles (optional, cosmetic - see "Alt Site Markers" toggle).
-- Applied directly via setCustomObject()+reload() rather than TTS "States", so the tile carries no alternate
-- state a player could cycle through with the number-key hotkey to see other variants ahead of time.
-- Per site: standardFace/standardBack (the tile's original look) and 3 variants; only variant 1's back actually
-- prints a VP value (the other two show a different, unautomated bonus) - vpOnTotalControl marks that.
altMarkerData = {
	['fbdd4d'] = { -- Gauntlgrym
		standardFace = 'https://steamusercontent-a.akamaihd.net/ugc/1856048428669822529/476CA1D21A772F86656BF5D27EF93A71A8EC8A69/',
		standardBack = 'https://steamusercontent-a.akamaihd.net/ugc/1856048428669822491/87911F1FEEF46D2B34AFFC66586D55BE791DF2AF/',
		altFace = 'https://lh3.googleusercontent.com/d/17Pon4RzPlBuzhGqw6vgNpnS724swH7d9',
		variants = {
			{back = 'https://lh3.googleusercontent.com/d/1Ci_fw8ZZ_-o7eN0R-CPq5dRyMrvIfD1S', vpOnTotalControl = true},
			{back = 'https://lh3.googleusercontent.com/d/111BmIGAR8UBXBfsyOlRQ1RQpkwlH2pX_', vpOnTotalControl = false},
			{back = 'https://lh3.googleusercontent.com/d/1nBIHAZu2N-6cnkpTUQETG3pAd8QaapfK', vpOnTotalControl = false}
		}
	},
	['66ab70'] = { -- Ch'Chitl
		standardFace = 'https://steamusercontent-a.akamaihd.net/ugc/1856048428669822455/17AAA416646670EED41503603F0D4A3DB6F40DEF/',
		standardBack = 'https://steamusercontent-a.akamaihd.net/ugc/1856048428669822420/DEE40391E0493169A3EB9982355B5CCFF81803A9/',
		altFace = 'https://lh3.googleusercontent.com/d/1QsfgXyJKSbH4suSmbk8ixClCrPijDC9V',
		variants = {
			{back = 'https://lh3.googleusercontent.com/d/10yy4Bt_reFD30puyt9jukQdYC0OJfOpR', vpOnTotalControl = true},
			{back = 'https://lh3.googleusercontent.com/d/1vIaTd5m0PeKduP2Lnhybd2wQzrVOlfVa', vpOnTotalControl = false},
			{back = 'https://lh3.googleusercontent.com/d/1inPuA0D573lv_FLxezAj4jY5e2zw7MqQ', vpOnTotalControl = false}
		}
	},
	['8c9a11'] = { -- The Phaerlin
		standardFace = 'https://steamusercontent-a.akamaihd.net/ugc/1856048428669822681/B4598DB3116530C21FEDB1348C2A73CA31EB2CED/',
		standardBack = 'https://steamusercontent-a.akamaihd.net/ugc/1856048428669822644/2CE152CB9EA431951457DD7BC75A47E8E09A7AD3/',
		altFace = 'https://lh3.googleusercontent.com/d/1BulzaYi-vpBdp9x5siLQgIud-waG8xiq',
		variants = {
			{back = 'https://lh3.googleusercontent.com/d/1FKd-QjPEZ7pEroRx5kyfeQ4T2T69yYur', vpOnTotalControl = true},
			{back = 'https://lh3.googleusercontent.com/d/1kn847lCJ6R31bJFY8GINHP4jTN2bNRfL', vpOnTotalControl = false},
			{back = 'https://lh3.googleusercontent.com/d/1HWrs9W8C-RGiHzWMlEth2EWkEiLzCUDf', vpOnTotalControl = false}
		}
	},
	['b993de'] = { -- Ss'zuraass'nee
		standardFace = 'https://steamusercontent-a.akamaihd.net/ugc/1856048428669822746/65102C87C90653275135A4762267FB08D496E658/',
		standardBack = 'https://steamusercontent-a.akamaihd.net/ugc/1856048428669822716/E499E916BD6D6C2ED3E84B5AF49FE25209EBC93B/',
		altFace = 'https://lh3.googleusercontent.com/d/174cLOHW6jgyakmJ3kCGN_orty294dd15',
		variants = {
			{back = 'https://lh3.googleusercontent.com/d/1-rqAndchjrCDRNShd29dWvW05-ogEg1h', vpOnTotalControl = true},
			{back = 'https://lh3.googleusercontent.com/d/1Dofs1xsbhIee_jwRrzqjfSCvsrX36NwW', vpOnTotalControl = false},
			{back = 'https://lh3.googleusercontent.com/d/1wjgk2IrMpUUWV8NEu5ZJ367_ag6c4o1z', vpOnTotalControl = false}
		}
	},
	['dd834c'] = { -- Menzoberranzan
		standardFace = 'https://steamusercontent-a.akamaihd.net/ugc/1856048428669822603/15DED5603C1C11BED7178A4AB0C2ED99EE8ED73E/',
		standardBack = 'https://steamusercontent-a.akamaihd.net/ugc/1856048428669822566/DFD4ABAF7944E6C2827303D00BC650CF5D214967/',
		altFace = 'https://lh3.googleusercontent.com/d/1RdzxIYuJDqrvu-kvKdPXxqIvR3QLpQs1',
		variants = {
			{back = 'https://lh3.googleusercontent.com/d/1waPx1ZoqBJBssO5Fp0WnzVeaytyQcsPx', vpOnTotalControl = true},
			{back = 'https://lh3.googleusercontent.com/d/1IrANPEwbidtFwVUiLa7_yURfYKHQqcBj', vpOnTotalControl = false},
			{back = 'https://lh3.googleusercontent.com/d/1hng-l_4VdPv6uSv_qCQliYW_GebX1ANI', vpOnTotalControl = false}
		}
	},
	['2a2981'] = { -- Araumycos
		standardFace = 'https://steamusercontent-a.akamaihd.net/ugc/1856048428669822378/8057EB3967DBC0674007E91CDB328CB923B2BA9A/',
		standardBack = 'https://steamusercontent-a.akamaihd.net/ugc/1856048428669822330/55069B8273CD3185B0C099A2BD56ECDB0D381683/',
		altFace = 'https://lh3.googleusercontent.com/d/1qRqJ6D74TdvQuex58fPGgBzIEwrZxx7w',
		variants = {
			{back = 'https://lh3.googleusercontent.com/d/1tg5PCchrf6b_5kMJOzhW09hrHn1DD2Ji', vpOnTotalControl = true},
			{back = 'https://lh3.googleusercontent.com/d/18Efrh5phWygiCWYqwNHJ0Or1HfKHTh6B', vpOnTotalControl = false},
			{back = 'https://lh3.googleusercontent.com/d/1jtAG7iKY3wicPFB-Xg4cEcuwHy18d7pS', vpOnTotalControl = false}
		}
	},
	['94b849'] = { -- Tsenviilyq
		standardFace = 'https://steamusercontent-a.akamaihd.net/ugc/1856048428669822839/181FB32C812135AE6796FCED2AD315F0CAEA6CD0/',
		standardBack = 'https://steamusercontent-a.akamaihd.net/ugc/1856048428669822790/98C7F25CE178D2E3715D7154B6D24184DB9D39B6/',
		altFace = 'https://lh3.googleusercontent.com/d/1Mh7MebwVEkmt8xBgS0T-hIpNcs_R0zJz',
		variants = {
			{back = 'https://lh3.googleusercontent.com/d/1kdZYtBAzqJtfJKDUrAxGCBQCIOt7I0oV', vpOnTotalControl = true},
			{back = 'https://lh3.googleusercontent.com/d/1PsZ4_9vNTphzsSPcaIA2cCLPbxP1krli', vpOnTotalControl = false},
			{back = 'https://lh3.googleusercontent.com/d/1YNBhnz9JsQJJSgIRT4pjAhuPQpVzqBPX', vpOnTotalControl = false}
		}
	}
}
altMarkerVpDisabled = {}		-- guids of markers whose currently-shown alt variant grants no VP on total control (see deliverTotalControlVps)

---------------------- DEMONWEB MODULAR MAP (2-PLAYER, PHASE 1: BOARD ASSEMBLY ONLY)
-- Alternate procedurally-assembled hex board (fan expansion). Simplified to match how a working reference
-- implementation of this same expansion does it: fixed, pre-authored position+rotation per board "slot"
-- (no hex-grid math, no per-tile rotation optimization) - a random tile is just dropped into each slot and
-- given that slot's fixed rotation, exactly as the rulebook itself allows ("if a dispute over connections,
-- the owner decides" / dead-ends can simply be treated as blocked). B1 (Menzoberranzan) is a fixed anchor
-- hex, not part of the random draw - matching the reference mod, which never randomizes it. Site control/VP
-- for this map is tracked manually by players for now, same as individual card abilities elsewhere in this mod.

-- the standard board tile and its 7 built-in site control markers, with their original positions/rotations,
-- so they can be tucked away by default (until the player explicitly picks the Standard board) and restored
-- cleanly if the Standard board is chosen instead of the modular one
-- ordered list of GUIDs matching standardBoardObjectJSON, so spawning/destroying can iterate them all
standardBoardObjectGuids = {
	'203c91','fbdd4d','66ab70','8c9a11','b993de','dd834c','2a2981','94b849',
	'7e86a6','6f7cc7','b30d72','101cfe','d38f93','38b07a',
	'0415af','5dbedf','74df09','dc04ba','4f6598',
	'6fa038','eaeacf','d14d31','0e9119','309fde','3588ca','a4d91e','a091c3','e58429','60aef9','377510','37c56b','9e10d1','a8df27','63546d',
	'405f7f','f023cc','de0671','bc6df3','c815f6','801598','418f33'
}

-- spawns the standard board tile, all 7 control markers, and all 33 associated zones from their saved JSON
-- snapshots (standardBoardObjectJSON) - used only when the player picks Standard board mode at game start
function demonwebSpawnStandardBoard()
	for _, guid in ipairs(standardBoardObjectGuids) do
		if getObjectFromGUID(guid) == nil then
			spawnObjectJSON({json = standardBoardObjectJSON[guid]})
		end
	end
end

-- destroys the standard board tile, all 7 control markers, and all 33 associated zones - used when the
-- player picks Modular board mode, so none of the standard board's objects linger on the table at all.
-- Looks up markers by their CURRENT (possibly alt-marker-reloaded) guid via boardSections, and everything
-- else by its fixed original guid, since only the markers can change guid at runtime.
function demonwebDestroyStandardBoard()
	local obj = getObjectFromGUID(standardBoardObjectGuids[1])	-- the board tile itself, guid never changes
	if obj ~= nil then obj.destruct() end
	for _, section in pairs(boardSections) do
		for _, markerInfo in ipairs(section.controlMarkers) do
			local marker = getObjectFromGUID(markerInfo.guid)
			if marker ~= nil then marker.destruct() end
		end
	end
	for i = 9, #standardBoardObjectGuids do	-- everything after the board+7 original marker guids: the 33 zones
		local zone = getObjectFromGUID(standardBoardObjectGuids[i])
		if zone ~= nil then zone.destruct() end
	end
end

-- full JSON snapshots of the standard board tile, its 7 control markers, and all 33 associated
-- zones (26 site-counting zones + 7 marker button zones), captured once from the original save.
-- These objects are NOT present in the save at load time at all (removed entirely) - they are
-- spawned fresh from this data only when Standard board mode is chosen, and destroyed again if
-- Modular is chosen instead, mirroring how the Demonweb board only exists when generated.
standardBoardObjectJSON = {}
standardBoardObjectJSON['203c91'] = [==[{"GUID": "203c91", "Name": "Custom_Tile", "Transform": {"posX": 0.0, "posY": 1.48, "posZ": 11.0, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 26.0, "scaleY": 1.0, "scaleZ": 26.0}, "Nickname": "", "Description": "Board", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 0.249994576, "g": 0.249994576, "b": 0.249994576}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": false, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "CustomImage": {"ImageURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669803014/6D39F7CB983FD57492EE46D580975EFC164EE228/", "ImageSecondaryURL": "", "ImageScalar": 1.0, "WidthScale": 0.0, "CustomTile": {"Type": 0, "Thickness": 0.1, "Stackable": false, "Stretch": true}}, "LuaScript": "", "LuaScriptState": "", "XmlUI": "", "AttachedSnapPoints": [{"Position": {"x": -0.7864208, "y": 0.10000018, "z": 0.9117383}, "Rotation": {"x": -7.422351e-07, "y": 9.562265e-05, "z": -1.0514762e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.735491037, "y": 0.100000195, "z": 0.912634}, "Rotation": {"x": 3.88524626e-08, "y": 5.4641514e-05, "z": -2.24678018e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.6856307, "y": 0.100000195, "z": 0.9134566}, "Rotation": {"x": -7.17299542e-07, "y": 6.83018952e-05, "z": 1.04794829e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.570649266, "y": 0.100000165, "z": 0.6854273}, "Rotation": {"x": -7.806583e-07, "y": 4.09811364e-05, "z": 5.140807e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.519162834, "y": 0.100000128, "z": 0.5845996}, "Rotation": {"x": -7.133285e-07, "y": 5.4641514e-05, "z": -1.40894954e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.8168376, "y": 0.100000151, "z": 0.521683633}, "Rotation": {"x": -6.90973e-08, "y": 6.83018952e-05, "z": -2.95064325e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.841161549, "y": 0.100000143, "z": 0.331315577}, "Rotation": {"x": 1.4323696e-07, "y": 5.4641514e-05, "z": -3.08363724e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.7907183, "y": 0.100000143, "z": 0.330776125}, "Rotation": {"x": -3.04621e-07, "y": 5.4641514e-05, "z": -1.16526707e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.7402755, "y": 0.100000031, "z": 0.331444472}, "Rotation": {"x": 9.398122e-08, "y": 4.09811364e-05, "z": -2.532328e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.8411778, "y": 0.100000069, "z": 0.285930842}, "Rotation": {"x": -1.78739668e-07, "y": 6.83018952e-05, "z": -1.415526e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.7911939, "y": 0.100000069, "z": 0.287287116}, "Rotation": {"x": -1.04140861e-06, "y": -1.09651009e-15, "z": 1.20654676e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.740591049, "y": 0.100000195, "z": 0.287277043}, "Rotation": {"x": -2.02042628e-07, "y": 4.09811364e-05, "z": -1.35727632e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.6170323, "y": 0.10000018, "z": 0.319588244}, "Rotation": {"x": -1.19818253e-07, "y": 5.4641514e-05, "z": -1.53713771e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.813742638, "y": 0.100000113, "z": 0.0557061248}, "Rotation": {"x": -4.24742375e-08, "y": 4.09811364e-05, "z": -3.44943544e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.591206849, "y": 0.1000001, "z": 0.0201389268}, "Rotation": {"x": -5.39291534e-07, "y": 8.196227e-05, "z": -4.97568237e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.70169425, "y": 0.100000188, "z": -0.098841846}, "Rotation": {"x": 5.78692578e-08, "y": 4.09811364e-05, "z": -3.29860853e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.6517009, "y": 0.100000069, "z": -0.09852364}, "Rotation": {"x": -4.735075e-07, "y": 5.4641514e-05, "z": -3.1336333e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.527168155, "y": 0.100000247, "z": -0.09974597}, "Rotation": {"x": -6.79776463e-07, "y": 5.4641514e-05, "z": 3.63090926e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.851576447, "y": 0.100000262, "z": -0.197851777}, "Rotation": {"x": -1.39737679e-07, "y": 8.196227e-05, "z": -5.824147e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.7119696, "y": 0.100000143, "z": -0.297436953}, "Rotation": {"x": -1.03465572e-06, "y": 4.09811364e-05, "z": -1.89913574e-09}, "Tags": ["troop"]}, {"Position": {"x": -0.8486088, "y": 0.100000106, "z": -0.448542565}, "Rotation": {"x": -7.69161147e-07, "y": 5.4641514e-05, "z": -2.07999889e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.7984449, "y": 0.100000106, "z": -0.448385179}, "Rotation": {"x": 1.06260076e-08, "y": 0.000245886826, "z": -5.2643037e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.749110758, "y": 0.1000001, "z": -0.4486677}, "Rotation": {"x": -3.519749e-07, "y": 6.83018952e-05, "z": -3.71453183e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.552609, "y": 0.100000165, "z": -0.6141708}, "Rotation": {"x": 1.78124111e-07, "y": -4.09811364e-05, "z": -5.108804e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.567288458, "y": 0.100000091, "z": -0.740332544}, "Rotation": {"x": 1.48347652e-07, "y": 4.09811364e-05, "z": -2.43155966e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.518004239, "y": 0.100000083, "z": -0.7410103}, "Rotation": {"x": 2.2572101e-07, "y": -3.333013e-16, "z": -1.69206729e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.5923452, "y": 0.09999995, "z": -0.7853574}, "Rotation": {"x": -1.26031779e-07, "y": 0.000177584923, "z": 5.80468452e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.5432279, "y": 0.100000069, "z": -0.7853322}, "Rotation": {"x": 4.4098134e-09, "y": -2.7320757e-05, "z": -2.17560114e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.493798077, "y": 0.10000018, "z": -0.784753442}, "Rotation": {"x": -3.80784343e-07, "y": 4.09811364e-05, "z": 2.57473147e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.39632684, "y": 0.100000083, "z": -0.6898959}, "Rotation": {"x": 4.52714843e-08, "y": 9.562265e-05, "z": -1.9003123e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.106956236, "y": 0.100000083, "z": 0.9311196}, "Rotation": {"x": 5.678063e-08, "y": 4.09811364e-05, "z": -1.84019029e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.05655723, "y": 0.100000091, "z": 0.930653751}, "Rotation": {"x": -3.35092864e-07, "y": 5.4641514e-05, "z": -1.23060047e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.005892145, "y": 0.10000021, "z": 0.931565166}, "Rotation": {"x": 1.83083856e-07, "y": 5.4641514e-05, "z": -8.554557e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.1310636, "y": 0.100000083, "z": 0.836117}, "Rotation": {"x": -2.43584225e-07, "y": 6.83018952e-05, "z": -3.359286e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.220454887, "y": 0.100000158, "z": 0.9265943}, "Rotation": {"x": 7.995073e-09, "y": 5.4641514e-05, "z": -2.1241587e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.3570165, "y": 0.100000188, "z": 0.8557662}, "Rotation": {"x": 5.4954775e-08, "y": 6.83018952e-05, "z": -5.073384e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4076918, "y": 0.100000195, "z": 0.855804145}, "Rotation": {"x": 4.323053e-08, "y": 5.4641514e-05, "z": -1.955191e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.455930859, "y": 0.100000069, "z": 0.8563245}, "Rotation": {"x": -3.65879146e-07, "y": 5.4641514e-05, "z": -3.76916574e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.294736832, "y": 0.100000061, "z": 0.6875983}, "Rotation": {"x": -5.76576e-07, "y": 4.09811364e-05, "z": -1.51230537e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.426977783, "y": 0.100000128, "z": 0.659239}, "Rotation": {"x": -3.47279538e-08, "y": 5.4641514e-05, "z": -3.21477671e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.231832713, "y": 0.100000113, "z": 0.563093}, "Rotation": {"x": -2.76775971e-08, "y": 5.4641514e-05, "z": -3.48317684e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.000627097266, "y": 0.100000091, "z": 0.539936841}, "Rotation": {"x": -3.14919873e-07, "y": 4.09811364e-05, "z": -3.3873377e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.05126633, "y": 0.100000091, "z": 0.5403133}, "Rotation": {"x": 6.54188952e-08, "y": 5.4641514e-05, "z": -2.29099243e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.1006845, "y": 0.10000021, "z": 0.539888263}, "Rotation": {"x": -4.48709415e-07, "y": 5.4641514e-05, "z": -1.02727348e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.176813409, "y": 0.100000091, "z": 0.5147679}, "Rotation": {"x": 5.07998621e-08, "y": 8.196227e-05, "z": -1.47892e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.277509481, "y": 0.100000188, "z": 0.6496129}, "Rotation": {"x": -1.25558671e-07, "y": 4.09811364e-05, "z": -2.79818835e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.305141658, "y": 0.100000121, "z": 0.5154639}, "Rotation": {"x": 9.68804557e-08, "y": 5.4641514e-05, "z": -3.50781448e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.3533314, "y": 0.100000136, "z": 0.5160048}, "Rotation": {"x": -2.27904273e-08, "y": 4.09811364e-05, "z": -2.666333e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.325868666, "y": 0.100000106, "z": 0.380166829}, "Rotation": {"x": 1.033606e-07, "y": 6.83018952e-05, "z": -2.227597e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.385574728, "y": 0.100000039, "z": 0.3103113}, "Rotation": {"x": -2.53059937e-07, "y": 5.4641514e-05, "z": -3.85456076e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.245713383, "y": 0.100000188, "z": 0.227346554}, "Rotation": {"x": -3.685041e-08, "y": 4.09811364e-05, "z": -2.65311e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.004653071, "y": 0.100000054, "z": 0.396768451}, "Rotation": {"x": -4.912758e-07, "y": 5.4641514e-05, "z": -2.23376e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.404302329, "y": 0.1, "z": 0.468289375}, "Rotation": {"x": -7.237965e-07, "y": 4.09811364e-05, "z": -7.71364e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.453679562, "y": 0.1, "z": 0.467526436}, "Rotation": {"x": 1.86696866e-07, "y": 5.4641514e-05, "z": -3.842655e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.379435629, "y": 0.100000113, "z": 0.423960537}, "Rotation": {"x": -3.25228228e-07, "y": 8.196227e-05, "z": -7.834468e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.429628, "y": 0.099999994, "z": 0.42416054}, "Rotation": {"x": 7.605476e-09, "y": 5.4641514e-05, "z": -2.6035562e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4780354, "y": 0.1000001, "z": 0.423820972}, "Rotation": {"x": -8.031034e-07, "y": 5.4641514e-05, "z": -7.33406154e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.405386925, "y": 0.10000018, "z": 0.277246684}, "Rotation": {"x": -7.459923e-07, "y": 5.4641514e-05, "z": -3.42660211e-09}, "Tags": ["troop"]}, {"Position": {"x": 0.429525, "y": 0.100000031, "z": 0.155497536}, "Rotation": {"x": 1.16170739e-07, "y": 6.83018952e-05, "z": -1.81467229e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.00134328054, "y": 0.100000061, "z": 0.306656778}, "Rotation": {"x": 6.847061e-08, "y": 5.4641514e-05, "z": -2.75814415e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.0481604822, "y": 0.100000069, "z": 0.305874765}, "Rotation": {"x": -7.69572e-07, "y": 5.4641514e-05, "z": 5.752573e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.04823315, "y": 0.100000113, "z": 0.2607574}, "Rotation": {"x": 3.46521176e-08, "y": 4.09811364e-05, "z": -1.78962722e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.00213938113, "y": 0.100000113, "z": 0.2603982}, "Rotation": {"x": 2.79264185e-08, "y": 5.4641514e-05, "z": -2.27702046e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.405867159, "y": 0.1000002, "z": 0.2090352}, "Rotation": {"x": 1.38716388e-07, "y": 5.4641514e-05, "z": -2.682177e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.4564721, "y": 0.100000188, "z": 0.208606}, "Rotation": {"x": -2.41477636e-07, "y": 4.09811364e-05, "z": -3.70181226e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.455088079, "y": 0.100000136, "z": 0.164117068}, "Rotation": {"x": -4.866614e-07, "y": 8.196227e-05, "z": -4.41588632e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.406595528, "y": 0.1, "z": 0.164322123}, "Rotation": {"x": 2.007004e-08, "y": 5.4641514e-05, "z": -5.414088e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.158630043, "y": 0.10000018, "z": 0.125336081}, "Rotation": {"x": -6.90606953e-07, "y": 4.09811364e-05, "z": -2.7637978e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.229710743, "y": 0.100000188, "z": 0.0410436131}, "Rotation": {"x": 2.76361671e-08, "y": 5.4641514e-05, "z": -3.56568961e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.369862348, "y": 0.100000262, "z": 0.05465671}, "Rotation": {"x": -2.159071e-08, "y": 6.83018952e-05, "z": -2.82054685e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4190495, "y": 0.0999999046, "z": 0.0543358438}, "Rotation": {"x": 4.92904135e-08, "y": 5.4641514e-05, "z": -4.300786e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.469230354, "y": 0.0999999046, "z": 0.05521932}, "Rotation": {"x": -7.84846463e-07, "y": 8.196227e-05, "z": 6.982712e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.07829274, "y": 0.100000292, "z": -0.07845683}, "Rotation": {"x": 1.07429734e-07, "y": 4.09811364e-05, "z": -3.08111339e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.401256561, "y": 0.100000151, "z": -0.08286511}, "Rotation": {"x": -1.165478e-06, "y": 0.000109283028, "z": 1.37846683e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.335542977, "y": 0.100000173, "z": -0.110677242}, "Rotation": {"x": 1.29428386e-07, "y": 4.09811364e-05, "z": -2.81193138e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.3579095, "y": 0.100000083, "z": 0.00298474822}, "Rotation": {"x": -8.989771e-09, "y": 4.09811364e-05, "z": -2.587451e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.395151258, "y": 0.10000027, "z": -0.2267869}, "Rotation": {"x": -5.77262369e-07, "y": 6.83018952e-05, "z": -3.09254915e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.34555766, "y": 0.100000262, "z": -0.227018744}, "Rotation": {"x": 1.59392783e-07, "y": 8.196227e-05, "z": -4.72505945e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.06869899, "y": 0.100000158, "z": -0.199770913}, "Rotation": {"x": -7.91047e-07, "y": 4.09811364e-05, "z": -1.80930186e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.0881706253, "y": 0.100000143, "z": -0.2373622}, "Rotation": {"x": -4.73386166e-08, "y": 5.4641514e-05, "z": -3.55263e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.226863042, "y": 0.100000121, "z": -0.206166074}, "Rotation": {"x": 1.10812142e-08, "y": 4.09811364e-05, "z": -3.74568174e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.420987457, "y": 0.100000247, "z": -0.1809664}, "Rotation": {"x": -4.33666656e-07, "y": 6.83018952e-05, "z": -2.14196e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4704384, "y": 0.09999988, "z": -0.18121843}, "Rotation": {"x": -5.13217842e-08, "y": 5.4641514e-05, "z": -3.776932e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4220026, "y": 0.100000061, "z": -0.226003557}, "Rotation": {"x": -1.84460325e-09, "y": 6.83018952e-05, "z": -2.8417162e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.470707327, "y": 0.100000046, "z": -0.226329014}, "Rotation": {"x": -9.18720744e-08, "y": 5.4641514e-05, "z": -4.18205644e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.381316453, "y": 0.100000158, "z": -0.344041377}, "Rotation": {"x": 1.5743791e-07, "y": 9.562265e-05, "z": -2.00137265e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.357775956, "y": 0.100000083, "z": -0.4357368}, "Rotation": {"x": -2.7842313e-07, "y": 4.09811364e-05, "z": -2.51146872e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.3072332, "y": 0.100000076, "z": -0.4352719}, "Rotation": {"x": -3.31464411e-09, "y": 4.09811364e-05, "z": -2.397607e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.282465667, "y": 0.10000018, "z": -0.4805707}, "Rotation": {"x": -3.55464351e-08, "y": 4.09811364e-05, "z": -2.18146354e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.332543582, "y": 0.09999994, "z": -0.479849815}, "Rotation": {"x": 1.08149774e-08, "y": 6.83018952e-05, "z": -4.861492e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.384280264, "y": 0.09999996, "z": -0.480288923}, "Rotation": {"x": 7.296329e-08, "y": 6.83018952e-05, "z": -3.65225731e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.138906941, "y": 0.100000076, "z": -0.3571349}, "Rotation": {"x": -1.17491815e-07, "y": 6.83018952e-05, "z": -2.853865e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.121766359, "y": 0.100000076, "z": -0.493198842}, "Rotation": {"x": 2.04398738e-08, "y": 4.09811364e-05, "z": -1.8048533e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.143243179, "y": 0.100000136, "z": -0.626665}, "Rotation": {"x": -5.24954977e-08, "y": 5.4641514e-05, "z": -3.062289e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.284010142, "y": 0.100000128, "z": -0.665755451}, "Rotation": {"x": -2.43994378e-07, "y": 4.09811364e-05, "z": -4.87693057e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.3113752, "y": 0.099999994, "z": -0.792696}, "Rotation": {"x": -4.778215e-08, "y": 4.09811364e-05, "z": -3.952462e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.261276841, "y": 0.100000113, "z": -0.7918057}, "Rotation": {"x": -6.7009637e-07, "y": 5.4641514e-05, "z": -6.251466e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.0478779748, "y": 0.100000307, "z": -0.6823796}, "Rotation": {"x": -1.13848529e-07, "y": 4.09811364e-05, "z": -3.16787776e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.00182310957, "y": 0.100000188, "z": -0.682990849}, "Rotation": {"x": -2.19775287e-09, "y": 5.4641514e-05, "z": -2.83826381e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.0535315461, "y": 0.100000173, "z": -0.6825084}, "Rotation": {"x": -5.92172341e-07, "y": 5.4641514e-05, "z": -2.22497132e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.05271411, "y": 0.100000016, "z": -0.638223052}, "Rotation": {"x": 1.22585021e-07, "y": 5.4641514e-05, "z": -2.76540675e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.00135535782, "y": 0.100000151, "z": -0.6379968}, "Rotation": {"x": 1.943802e-07, "y": 5.4641514e-05, "z": 7.007041e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.0490297675, "y": 0.100000031, "z": -0.6386673}, "Rotation": {"x": 8.81251054e-08, "y": 5.4641514e-05, "z": -1.802394e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.0388980471, "y": 0.100000225, "z": -0.502511442}, "Rotation": {"x": -4.59199242e-07, "y": 5.4641514e-05, "z": -8.601463e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.0404235274, "y": 0.100000061, "z": -0.3794196}, "Rotation": {"x": 1.19212924e-08, "y": 5.4641514e-05, "z": -4.58157842e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.252658546, "y": 0.100000173, "z": -0.3293708}, "Rotation": {"x": 1.00608382e-07, "y": 5.4641514e-05, "z": -3.8066176e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.412008882, "y": 0.100000151, "z": -0.369046569}, "Rotation": {"x": 9.42578353e-08, "y": 5.4641514e-05, "z": -2.38599569e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.369120747, "y": 0.100000069, "z": -0.45999974}, "Rotation": {"x": -1.83162615e-06, "y": 1.36603785e-05, "z": -1.78557471e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.3200154, "y": 0.100000069, "z": -0.4599998}, "Rotation": {"x": 1.9296111e-07, "y": 6.83018952e-05, "z": -1.22664323e-06}, "Tags": ["troop"]}, {"Position": {"x": -0.271154135, "y": 0.10000018, "z": -0.459955037}, "Rotation": {"x": -9.925366e-07, "y": 4.09811364e-05, "z": -1.55565616e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.241680861, "y": 0.100000165, "z": -0.5932392}, "Rotation": {"x": -9.798289e-07, "y": 4.09811364e-05, "z": -2.62157045e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.1949771, "y": 0.100000069, "z": -0.708090663}, "Rotation": {"x": 7.466929e-08, "y": 5.4641514e-05, "z": -2.96619419e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.6034918, "y": 0.100000158, "z": 0.849898}, "Rotation": {"x": 4.66048959e-08, "y": 4.09811364e-05, "z": -1.73365763e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8002731, "y": 0.100000173, "z": 0.866063654}, "Rotation": {"x": 2.24701466e-08, "y": 4.09811364e-05, "z": -4.17679615e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8509787, "y": 0.10000018, "z": 0.8652216}, "Rotation": {"x": -8.80763366e-07, "y": 4.09811364e-05, "z": 1.41693846e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.900194764, "y": 0.100000173, "z": 0.8653954}, "Rotation": {"x": 7.796591e-10, "y": -5.4641514e-05, "z": -2.17714827e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.833583653, "y": 0.100000195, "z": 0.450195223}, "Rotation": {"x": 5.693362e-07, "y": 4.09811364e-05, "z": -3.534259e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8898815, "y": 0.10000024, "z": 0.304951847}, "Rotation": {"x": 1.08443047e-07, "y": 4.09811364e-05, "z": -4.929707e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8400153, "y": 0.100000121, "z": 0.30510807}, "Rotation": {"x": -2.24019672e-07, "y": 4.09811364e-05, "z": -5.457454e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.7103866, "y": 0.100000121, "z": 0.291271031}, "Rotation": {"x": -7.431119e-07, "y": 4.09811364e-05, "z": -3.30988e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.629915, "y": 0.100000158, "z": 0.373731554}, "Rotation": {"x": -2.19312454e-07, "y": 5.4641514e-05, "z": -4.17384967e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8326854, "y": 0.100000113, "z": 0.118012927}, "Rotation": {"x": 2.762502e-08, "y": 6.83018952e-05, "z": -5.591051e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.887121, "y": 0.100000173, "z": -0.0142108174}, "Rotation": {"x": -1.29400576e-07, "y": 4.09811364e-05, "z": -4.26654e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8392526, "y": 0.100000173, "z": -0.0157595184}, "Rotation": {"x": 6.53122356e-08, "y": 5.4641514e-05, "z": -2.077129e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.7881551, "y": 0.100000165, "z": -0.0161310881}, "Rotation": {"x": -2.46802642e-07, "y": 4.09811364e-05, "z": -4.54026576e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.6500772, "y": 0.100000151, "z": -0.00553656043}, "Rotation": {"x": -5.15198337e-07, "y": 5.4641514e-05, "z": -2.76159938e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.831166267, "y": 0.09999998, "z": -0.176085174}, "Rotation": {"x": -2.45651677e-08, "y": 9.562265e-05, "z": -1.5535359e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8848577, "y": 0.100000143, "z": -0.307518125}, "Rotation": {"x": -5.287997e-07, "y": 6.83018952e-05, "z": -4.37239152e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8340373, "y": 0.100000128, "z": -0.3087641}, "Rotation": {"x": 1.72678138e-08, "y": 8.196227e-05, "z": -2.870735e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8337044, "y": 0.100000173, "z": -0.353691041}, "Rotation": {"x": -5.67178631e-07, "y": 0.000122943413, "z": -4.669032e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8862277, "y": 0.100000076, "z": -0.353006333}, "Rotation": {"x": -1.842881e-07, "y": 4.09811364e-05, "z": -3.75713057e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.639165938, "y": 0.09999994, "z": -0.301028222}, "Rotation": {"x": -4.45228e-09, "y": 0.000122943413, "z": -2.14795023e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.856630743, "y": 0.100000165, "z": -0.531583369}, "Rotation": {"x": -5.98e-09, "y": 4.09811364e-05, "z": -2.392624e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8997876, "y": 0.100000113, "z": -0.6781479}, "Rotation": {"x": -5.952824e-07, "y": 8.196227e-05, "z": -2.705941e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8490432, "y": 0.100000225, "z": -0.6778483}, "Rotation": {"x": 5.246039e-07, "y": 0.000150264168, "z": -1.90423037e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.798461854, "y": 0.1000001, "z": -0.679553151}, "Rotation": {"x": -1.198982e-07, "y": 4.09811364e-05, "z": -1.29855422e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.527647257, "y": 0.100000143, "z": -0.5558938}, "Rotation": {"x": 7.588723e-07, "y": 5.4641514e-05, "z": -8.41620249e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.599036157, "y": 0.100000128, "z": -0.734418631}, "Rotation": {"x": -1.791522e-07, "y": 5.4641514e-05, "z": -4.00994651e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.5489999, "y": 0.100000121, "z": -0.7353946}, "Rotation": {"x": -5.89386843e-07, "y": -1.36603785e-05, "z": -2.44787628e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.499571741, "y": 0.100000359, "z": -0.7347821}, "Rotation": {"x": -1.80369824e-07, "y": -6.83018952e-05, "z": 2.63472572e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.828875959, "y": 0.100000471, "z": 0.67187953}, "Rotation": {"x": -1.04460627e-08, "y": -3.44991949e-18, "z": 3.78450373e-08}, "Tags": ["control"]}, {"Position": {"x": -0.08049196, "y": 0.1000006, "z": 0.734508634}, "Rotation": {"x": 2.06513348e-10, "y": -0.00442596246, "z": -5.673507e-09}, "Tags": ["control"]}, {"Position": {"x": -0.0451759435, "y": 0.100000642, "z": 0.06579076}, "Rotation": {"x": 1.843012e-08, "y": 5.4641514e-05, "z": -1.6647574e-08}, "Tags": ["control"]}, {"Position": {"x": -0.8201211, "y": 0.100000404, "z": -0.640820146}, "Rotation": {"x": -6.83094736e-09, "y": -0.0006966793, "z": -1.06858087e-08}, "Tags": ["control"]}, {"Position": {"x": -0.0258299, "y": 0.100000367, "z": -0.874223053}, "Rotation": {"x": -3.7452363e-08, "y": -5.4641514e-05, "z": 1.76832913e-08}, "Tags": ["control"]}, {"Position": {"x": 0.8263526, "y": 0.1000003, "z": -0.868528068}, "Rotation": {"x": 8.21207e-09, "y": 0.000614717, "z": 9.019995e-09}, "Tags": ["control"]}, {"Position": {"x": 0.9284009, "y": 0.100000076, "z": 0.7984941}, "Rotation": {"x": -5.14817145e-07, "y": 1.36603785e-05, "z": 2.677156e-08}, "Tags": ["spy"]}, {"Position": {"x": 0.863016367, "y": 0.100000083, "z": 0.7984941}, "Rotation": {"x": -2.29185474e-07, "y": 4.09811364e-05, "z": -6.48747744e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.7976318, "y": 0.10000021, "z": 0.79849416}, "Rotation": {"x": 1.18135929e-07, "y": -1.01067876e-15, "z": -9.803558e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.7322472, "y": 0.100000218, "z": 0.7984941}, "Rotation": {"x": 1.87596783e-07, "y": -8.750105e-16, "z": -5.34491164e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.48911953, "y": 0.100000113, "z": 0.7836856}, "Rotation": {"x": -5.14486146e-07, "y": 2.26427662e-15, "z": -5.043226e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.423734754, "y": 0.100000121, "z": 0.7836855}, "Rotation": {"x": -1.42310981e-07, "y": 2.7320757e-05, "z": -9.533074e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3583503, "y": 0.100000247, "z": 0.783685565}, "Rotation": {"x": -4.64145415e-07, "y": 1.78054415e-15, "z": -4.39593578e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.292965651, "y": 0.100000255, "z": 0.783685446}, "Rotation": {"x": -4.8696927e-07, "y": 2.58883084e-15, "z": -6.09192739e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.0219074152, "y": 0.099999994, "z": 0.8671818}, "Rotation": {"x": -1.396765e-07, "y": 6.792246e-16, "z": -5.572405e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.04368886, "y": 0.100000121, "z": 0.867181659}, "Rotation": {"x": 7.356413e-07, "y": 0.00394784939, "z": -3.48484463e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.109707713, "y": 0.10000024, "z": 0.8671817}, "Rotation": {"x": 2.83693026e-07, "y": 0.016091926, "z": -3.170495e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.174552247, "y": 0.100000136, "z": 0.8671817}, "Rotation": {"x": 1.95997572e-07, "y": 0.03173308, "z": -6.63904643e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.656055331, "y": 0.09999999, "z": 0.848656}, "Rotation": {"x": -3.40793576e-07, "y": 3.0308408e-15, "z": -1.01911769e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.721439838, "y": 0.100000113, "z": 0.8486559}, "Rotation": {"x": 1.65591359e-07, "y": 1.36603785e-05, "z": -8.87224942e-08}, "Tags": ["spy"]}, {"Position": {"x": -0.786824644, "y": 0.10000024, "z": 0.848656}, "Rotation": {"x": -4.78484253e-07, "y": 6.031042e-15, "z": -1.44436638e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.8522092, "y": 0.100000009, "z": 0.848656}, "Rotation": {"x": 6.479253e-08, "y": -4.12867549e-17, "z": -7.301943e-08}, "Tags": ["spy"]}, {"Position": {"x": -0.263131827, "y": 0.10000027, "z": 0.446059972}, "Rotation": {"x": -1.09762277e-06, "y": 3.4637424e-15, "z": -3.616139e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.328516454, "y": 0.100000277, "z": 0.446059972}, "Rotation": {"x": -8.24513165e-07, "y": 2.7320757e-05, "z": -4.97279757e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.459285676, "y": 0.0999999344, "z": 0.446059972}, "Rotation": {"x": -8.176792e-07, "y": 4.551755e-16, "z": -6.378941e-08}, "Tags": ["spy"]}, {"Position": {"x": -0.39390108, "y": 0.100000165, "z": 0.446059972}, "Rotation": {"x": -3.65982373e-07, "y": 1.5213167e-15, "z": -4.7633452e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.0697782561, "y": 0.100000151, "z": 0.47151342}, "Rotation": {"x": -6.70487964e-07, "y": 1.15246049e-14, "z": -1.96964379e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.00439362926, "y": 0.100000143, "z": 0.47151342}, "Rotation": {"x": -5.104154e-07, "y": 5.24365646e-16, "z": -1.17723474e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.0609910265, "y": 0.100000255, "z": 0.4715135}, "Rotation": {"x": 1.50064253e-07, "y": 1.36603785e-05, "z": -7.08555547e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.126375675, "y": 0.100000247, "z": 0.4715135}, "Rotation": {"x": -1.41785893e-06, "y": -4.093468e-15, "z": 3.308347e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.307667345, "y": 0.100000031, "z": 0.347549736}, "Rotation": {"x": 1.67485084e-07, "y": -6.53829444e-16, "z": -4.47343353e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3730519, "y": 0.100000143, "z": 0.347549736}, "Rotation": {"x": 4.18110773e-07, "y": -1.45489926e-15, "z": -3.98744049e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.438436568, "y": 0.100000136, "z": 0.3475498}, "Rotation": {"x": -1.98596638e-07, "y": 2.7320757e-05, "z": -1.28494651e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.503821254, "y": 0.100000128, "z": 0.347549736}, "Rotation": {"x": -3.125423e-07, "y": 2.30239479e-15, "z": -8.441577e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.919649, "y": 0.100000195, "z": 0.208966464}, "Rotation": {"x": -4.50410681e-07, "y": 1.36603785e-05, "z": -7.770561e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.854264438, "y": 0.100000061, "z": 0.208966389}, "Rotation": {"x": -1.77239951e-06, "y": -3.966704e-13, "z": -6.75019351e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.788879633, "y": 0.100000173, "z": 0.208966389}, "Rotation": {"x": -8.323891e-07, "y": 4.09811364e-05, "z": -6.004858e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.7234951, "y": 0.100000165, "z": 0.208966464}, "Rotation": {"x": 3.61953084e-07, "y": -2.50165633e-15, "z": -7.92005153e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.5400126, "y": 0.1000001, "z": 0.0876253}, "Rotation": {"x": 5.242067e-07, "y": -2.58057778e-15, "z": -5.641142e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.4746278, "y": 0.100000091, "z": 0.0876253}, "Rotation": {"x": -1.84650776e-06, "y": -4.19471044e-13, "z": 7.67044355e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.4092435, "y": 0.100000083, "z": 0.08762546}, "Rotation": {"x": -3.518949e-07, "y": 1.36603785e-05, "z": -6.57227e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.3438586, "y": 0.100000076, "z": 0.08762551}, "Rotation": {"x": 6.25037657e-08, "y": -1.93645218e-16, "z": -3.55020347e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.143322065, "y": 0.100000143, "z": 0.197700158}, "Rotation": {"x": -5.67118263e-07, "y": 3.35676023e-15, "z": -6.782648e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.07793727, "y": 0.100000016, "z": 0.1977001}, "Rotation": {"x": -2.790247e-07, "y": 1.87918177e-15, "z": -7.71753832e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.0125529561, "y": 0.100000009, "z": 0.197700068}, "Rotation": {"x": 5.82769758e-07, "y": 2.7320757e-05, "z": 7.247457e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.0528316461, "y": 0.100000121, "z": 0.197700128}, "Rotation": {"x": -1.76232035e-07, "y": 2.670425e-16, "z": -1.7363935e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.302057564, "y": 0.100000136, "z": -0.0177875031}, "Rotation": {"x": -1.11165161e-06, "y": 6.57609656e-15, "z": -6.778789e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.367442131, "y": 0.100000009, "z": -0.01778735}, "Rotation": {"x": -5.4996093e-07, "y": 5.975455e-15, "z": -1.24506437e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.432826757, "y": 0.100000121, "z": -0.0177874174}, "Rotation": {"x": -5.76111461e-07, "y": 2.7320757e-05, "z": -1.3192531e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.498211354, "y": 0.100000113, "z": -0.01778734}, "Rotation": {"x": -3.713536e-07, "y": 2.521561e-15, "z": -7.7809824e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.7292276, "y": 0.09999999, "z": -0.08903507}, "Rotation": {"x": 1.62217489e-07, "y": -1.07888429e-15, "z": -7.621313e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.794611752, "y": 0.1000001, "z": -0.08903495}, "Rotation": {"x": -1.505604e-06, "y": -2.7320757e-05, "z": 1.42605813e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.859996438, "y": 0.100000091, "z": -0.0890348852}, "Rotation": {"x": -1.49045525e-06, "y": -2.13684745e-14, "z": 1.64288508e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.925380945, "y": 0.100000083, "z": -0.08903502}, "Rotation": {"x": -1.76472236e-06, "y": -2.7320757e-05, "z": 9.996256e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.7431043, "y": 0.100000151, "z": -0.428273618}, "Rotation": {"x": 6.471919e-08, "y": 1.36603785e-05, "z": -1.18804758e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.8084887, "y": 0.100000262, "z": -0.428273529}, "Rotation": {"x": -4.48019533e-09, "y": 5.469234e-17, "z": -1.3988855e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.873873532, "y": 0.100000136, "z": -0.428273916}, "Rotation": {"x": 1.87053814e-07, "y": 4.09811364e-05, "z": -1.28535032e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.939258158, "y": 0.100000128, "z": -0.428273618}, "Rotation": {"x": 1.21495688e-07, "y": 1.36603785e-05, "z": -1.09358155e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.750268936, "y": 0.10000018, "z": -0.7444}, "Rotation": {"x": 8.062764e-07, "y": 2.9943214e-15, "z": 4.25566157e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.8156536, "y": 0.100000054, "z": -0.7444}, "Rotation": {"x": 9.930745e-07, "y": 3.88195932e-13, "z": -2.18262153e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.881038, "y": 0.100000165, "z": -0.7443998}, "Rotation": {"x": 9.890075e-07, "y": 3.8852683e-13, "z": -2.15326054e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.9464227, "y": 0.100000039, "z": -0.7443998}, "Rotation": {"x": 9.45008651e-07, "y": 1.36603785e-05, "z": 4.11411833e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.625069, "y": 0.100000136, "z": -0.809376836}, "Rotation": {"x": -4.08450717e-07, "y": 6.83018952e-05, "z": -8.65594757e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.559686244, "y": 0.100000143, "z": -0.809377134}, "Rotation": {"x": 1.17435981e-07, "y": 4.09811364e-05, "z": -7.109428e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.494301647, "y": 0.10000027, "z": -0.809376836}, "Rotation": {"x": 7.891975e-07, "y": 1.36603785e-05, "z": -3.49014528e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.4289167, "y": 0.100000158, "z": -0.809376836}, "Rotation": {"x": -4.36923955e-07, "y": 6.83018952e-05, "z": 5.426494e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3384615, "y": 0.100000128, "z": -0.18849948}, "Rotation": {"x": -8.72855139e-07, "y": -0.000232226434, "z": -3.63481576e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.338461518, "y": 0.100000136, "z": -0.260246515}, "Rotation": {"x": -3.21443224e-07, "y": 1.76873206e-15, "z": -6.30536761e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.443052858, "y": 0.099999994, "z": -0.2979046}, "Rotation": {"x": -5.07656e-07, "y": -4.09811364e-05, "z": -1.778798e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.5084374, "y": 0.100000106, "z": -0.2979042}, "Rotation": {"x": 4.5308667e-08, "y": -5.528934e-16, "z": -1.39834e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.4156479, "y": 0.100000106, "z": -0.553855}, "Rotation": {"x": -1.92510061e-06, "y": -4.019903e-13, "z": -3.04810527e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3502634, "y": 0.100000113, "z": -0.5538549}, "Rotation": {"x": -1.72456475e-06, "y": 1.36603785e-05, "z": -4.504669e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.2848788, "y": 0.10000024, "z": -0.5538547}, "Rotation": {"x": -8.488211e-07, "y": 1.07806906e-14, "z": -1.4554023e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.219494149, "y": 0.100000247, "z": -0.5538547}, "Rotation": {"x": -9.036166e-07, "y": 1.36603785e-05, "z": -9.16257136e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.35368675, "y": 0.1, "z": -0.8709405}, "Rotation": {"x": -8.47634453e-07, "y": 2.7320757e-05, "z": 1.23319762e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.2883023, "y": 0.100000247, "z": -0.8709408}, "Rotation": {"x": -1.57109156e-07, "y": 4.09811364e-05, "z": 9.718927e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.2229177, "y": 0.100000136, "z": -0.8709405}, "Rotation": {"x": -2.45614331e-07, "y": 1.36603785e-05, "z": -5.303256e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.157533258, "y": 0.100000262, "z": -0.8709408}, "Rotation": {"x": -2.99975227e-07, "y": 2.84417549e-15, "z": -1.08648487e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.07986431, "y": 0.100000255, "z": -0.7465019}, "Rotation": {"x": 1.10500923e-06, "y": 4.06253617e-13, "z": -8.891141e-08}, "Tags": ["spy"]}, {"Position": {"x": 0.0144797442, "y": 0.100000143, "z": -0.746502042}, "Rotation": {"x": 1.36230472e-06, "y": 2.7320757e-05, "z": -1.14112208e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.0509049, "y": 0.100000151, "z": -0.746502042}, "Rotation": {"x": 1.8136227e-06, "y": 3.73348325e-13, "z": -2.13325347e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.1162895, "y": 0.100000158, "z": -0.7465019}, "Rotation": {"x": 2.20334573e-06, "y": 8.032488e-13, "z": -5.706931e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.274112552, "y": 0.10000021, "z": -0.5279073}, "Rotation": {"x": 8.154738e-07, "y": -2.7320757e-05, "z": 1.25010411e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.339497149, "y": 0.100000218, "z": -0.5279074}, "Rotation": {"x": 1.07793778e-06, "y": 1.14264821e-14, "z": 1.21470691e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.4048819, "y": 0.100000225, "z": -0.527907252}, "Rotation": {"x": 4.301153e-07, "y": -2.7320757e-05, "z": -1.87476269e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.470266432, "y": 0.100000232, "z": -0.527907}, "Rotation": {"x": 1.225917e-06, "y": 1.2156655e-14, "z": 1.13633314e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.0532106534, "y": 0.100000128, "z": -0.298076332}, "Rotation": {"x": 1.07926809e-07, "y": 2.7320757e-05, "z": -5.685484e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.118595228, "y": 0.100000255, "z": -0.298075885}, "Rotation": {"x": 2.79777282e-07, "y": -1.82126462e-15, "z": -7.45956e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.169230759, "y": 0.100000218, "z": -0.241916433}, "Rotation": {"x": 2.52706e-07, "y": 1.1022228e-15, "z": 4.998118e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.169230774, "y": 0.100000091, "z": -0.171802089}, "Rotation": {"x": -9.01983242e-07, "y": 0.00133871706, "z": -3.37435523e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.3320212, "y": 0.100000143, "z": -0.3049357}, "Rotation": {"x": -1.16054161e-06, "y": -3.31234415e-15, "z": 3.27059951e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.397405922, "y": 0.100000151, "z": -0.3049354}, "Rotation": {"x": -6.967085e-07, "y": 4.09811364e-05, "z": -1.0637347e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.4627906, "y": 0.100000277, "z": -0.304935247}, "Rotation": {"x": -1.201822e-06, "y": 1.36603785e-05, "z": -3.73949518e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.478181, "y": 0.100000151, "z": -0.240965128}, "Rotation": {"x": 5.154046e-07, "y": 3.9728946e-13, "z": -2.18365722e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.589483738, "y": 0.100000054, "z": -0.172540709}, "Rotation": {"x": -5.324382e-07, "y": -2.7320757e-05, "z": 1.07597934e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.6548682, "y": 0.10000018, "z": -0.17254056}, "Rotation": {"x": -1.12496923e-06, "y": -1.69132066e-15, "z": 1.72281233e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.72025305, "y": 0.100000195, "z": -0.172540531}, "Rotation": {"x": -6.4416497e-07, "y": -4.09811364e-05, "z": -4.94309063e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.7856377, "y": 0.1000002, "z": -0.172540471}, "Rotation": {"x": 5.32079136e-09, "y": 1.36603785e-05, "z": -6.52353037e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.719842, "y": 0.100000247, "z": -0.5161715}, "Rotation": {"x": -1.815563e-06, "y": -5.4641514e-05, "z": 8.12418534e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.785226643, "y": 0.100000255, "z": -0.516171634}, "Rotation": {"x": -1.35893413e-06, "y": -2.7320757e-05, "z": 1.02473132e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.8506112, "y": 0.100000262, "z": -0.516171336}, "Rotation": {"x": -9.61286e-07, "y": -6.83018952e-05, "z": 7.444861e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.9159957, "y": 0.10000027, "z": -0.516171634}, "Rotation": {"x": -1.81002179e-06, "y": 6.83018952e-05, "z": -1.35284722e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.460974842, "y": 0.10000024, "z": -0.866706431}, "Rotation": {"x": -5.67137448e-08, "y": 1.36603785e-05, "z": -8.17933255e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.5263594, "y": 0.100000247, "z": -0.866706431}, "Rotation": {"x": 6.14519e-07, "y": 5.4641514e-05, "z": -4.4613472e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.591744065, "y": 0.100000255, "z": -0.866706431}, "Rotation": {"x": 1.91792381e-07, "y": 4.09811364e-05, "z": -7.70617135e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.6571283, "y": 0.100000381, "z": -0.8667067}, "Rotation": {"x": 2.474828e-07, "y": 5.4641514e-05, "z": -1.249917e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.7565385, "y": 0.100000151, "z": 0.7249999}, "Rotation": {"x": 6.5417054e-09, "y": 359.9662, "z": -1.01503925e-08}, "Tags": ["control"]}, {"Position": {"x": 0.9212581, "y": 0.100000091, "z": 0.206158131}, "Rotation": {"x": 2.10405886e-07, "y": 0.0005190944, "z": -5.470662e-08}, "Tags": ["spy"]}, {"Position": {"x": 0.8018371, "y": 0.100000069, "z": 0.206158116}, "Rotation": {"x": 9.38258438e-07, "y": 8.196227e-05, "z": 3.941973e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.8615476, "y": 0.1000002, "z": 0.206158131}, "Rotation": {"x": -5.55372637e-08, "y": -0.00215833983, "z": -7.589825e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.742126644, "y": 0.100000061, "z": 0.206158116}, "Rotation": {"x": -1.79172318e-07, "y": 5.4641514e-05, "z": -2.92270755e-07}, "Tags": ["spy"]}], "States": {"2": {"GUID": "1e4605", "Name": "Custom_Tile", "Transform": {"posX": 0.0, "posY": 1.48, "posZ": 11.0, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 26.0, "scaleY": 1.0, "scaleZ": 26.0}, "Nickname": "", "Description": "Board", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 0.2499997, "g": 0.2499997, "b": 0.2499997}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": false, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "CustomImage": {"ImageURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669803077/E68A27FA6F131AC0F3E176EDDC419728419A93D3/", "ImageSecondaryURL": "", "ImageScalar": 1.0, "WidthScale": 0.0, "CustomTile": {"Type": 0, "Thickness": 0.1, "Stackable": false, "Stretch": true}}, "LuaScript": "", "LuaScriptState": "", "XmlUI": "", "AttachedSnapPoints": [{"Position": {"x": -0.106956236, "y": 0.100000083, "z": 0.9311196}, "Rotation": {"x": 5.678063e-08, "y": 4.09811364e-05, "z": -1.84019029e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.05655723, "y": 0.100000091, "z": 0.930653751}, "Rotation": {"x": -3.35092864e-07, "y": 5.4641514e-05, "z": -1.23060047e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.005892145, "y": 0.10000021, "z": 0.931565166}, "Rotation": {"x": 1.83083856e-07, "y": 5.4641514e-05, "z": -8.554557e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.1310636, "y": 0.100000083, "z": 0.836117}, "Rotation": {"x": -2.43584225e-07, "y": 6.83018952e-05, "z": -3.359286e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.220454887, "y": 0.100000158, "z": 0.9265943}, "Rotation": {"x": 7.995073e-09, "y": 5.4641514e-05, "z": -2.1241587e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.3570165, "y": 0.100000188, "z": 0.8557662}, "Rotation": {"x": 5.4954775e-08, "y": 6.83018952e-05, "z": -5.073384e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4076918, "y": 0.100000195, "z": 0.855804145}, "Rotation": {"x": 4.323053e-08, "y": 5.4641514e-05, "z": -1.955191e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.455930859, "y": 0.100000069, "z": 0.8563245}, "Rotation": {"x": -3.65879146e-07, "y": 5.4641514e-05, "z": -3.76916574e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.294736832, "y": 0.100000061, "z": 0.6875983}, "Rotation": {"x": -5.76576e-07, "y": 4.09811364e-05, "z": -1.51230537e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.426977783, "y": 0.100000128, "z": 0.659239}, "Rotation": {"x": -3.47279538e-08, "y": 5.4641514e-05, "z": -3.21477671e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.231832713, "y": 0.100000113, "z": 0.563093}, "Rotation": {"x": -2.76775971e-08, "y": 5.4641514e-05, "z": -3.48317684e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.000627097266, "y": 0.100000091, "z": 0.539936841}, "Rotation": {"x": -3.14919873e-07, "y": 4.09811364e-05, "z": -3.3873377e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.05126633, "y": 0.100000091, "z": 0.5403133}, "Rotation": {"x": 6.54188952e-08, "y": 5.4641514e-05, "z": -2.29099243e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.1006845, "y": 0.10000021, "z": 0.539888263}, "Rotation": {"x": -4.48709415e-07, "y": 5.4641514e-05, "z": -1.02727348e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.176813409, "y": 0.100000091, "z": 0.5147679}, "Rotation": {"x": 5.07998621e-08, "y": 8.196227e-05, "z": -1.47892e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.277509481, "y": 0.100000188, "z": 0.6496129}, "Rotation": {"x": -1.25558671e-07, "y": 4.09811364e-05, "z": -2.79818835e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.305141658, "y": 0.100000121, "z": 0.5154639}, "Rotation": {"x": 9.68804557e-08, "y": 5.4641514e-05, "z": -3.50781448e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.3533314, "y": 0.100000136, "z": 0.5160048}, "Rotation": {"x": -2.27904273e-08, "y": 4.09811364e-05, "z": -2.666333e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.325868666, "y": 0.100000106, "z": 0.380166829}, "Rotation": {"x": 1.033606e-07, "y": 6.83018952e-05, "z": -2.227597e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.385574728, "y": 0.100000039, "z": 0.3103113}, "Rotation": {"x": -2.53059937e-07, "y": 5.4641514e-05, "z": -3.85456076e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.245713383, "y": 0.100000188, "z": 0.227346554}, "Rotation": {"x": -3.685041e-08, "y": 4.09811364e-05, "z": -2.65311e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.004653071, "y": 0.100000054, "z": 0.396768451}, "Rotation": {"x": -4.912758e-07, "y": 5.4641514e-05, "z": -2.23376e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.404302329, "y": 0.1, "z": 0.468289375}, "Rotation": {"x": -7.237965e-07, "y": 4.09811364e-05, "z": -7.71364e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.453679562, "y": 0.1, "z": 0.467526436}, "Rotation": {"x": 1.86696866e-07, "y": 5.4641514e-05, "z": -3.842655e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.379435629, "y": 0.100000113, "z": 0.423960537}, "Rotation": {"x": -3.25228228e-07, "y": 8.196227e-05, "z": -7.834468e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.429628, "y": 0.099999994, "z": 0.42416054}, "Rotation": {"x": 7.605476e-09, "y": 5.4641514e-05, "z": -2.6035562e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4780354, "y": 0.1000001, "z": 0.423820972}, "Rotation": {"x": -8.031034e-07, "y": 5.4641514e-05, "z": -7.33406154e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.405386925, "y": 0.10000018, "z": 0.277246684}, "Rotation": {"x": -7.459923e-07, "y": 5.4641514e-05, "z": -3.42660211e-09}, "Tags": ["troop"]}, {"Position": {"x": 0.429525, "y": 0.100000031, "z": 0.155497536}, "Rotation": {"x": 1.16170739e-07, "y": 6.83018952e-05, "z": -1.81467229e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.00134328054, "y": 0.100000061, "z": 0.306656778}, "Rotation": {"x": 6.847061e-08, "y": 5.4641514e-05, "z": -2.75814415e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.0481604822, "y": 0.100000069, "z": 0.305874765}, "Rotation": {"x": -7.69572e-07, "y": 5.4641514e-05, "z": 5.752573e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.04823315, "y": 0.100000113, "z": 0.2607574}, "Rotation": {"x": 3.46521176e-08, "y": 4.09811364e-05, "z": -1.78962722e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.00213938113, "y": 0.100000113, "z": 0.2603982}, "Rotation": {"x": 2.79264185e-08, "y": 5.4641514e-05, "z": -2.27702046e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.405867159, "y": 0.1000002, "z": 0.2090352}, "Rotation": {"x": 1.38716388e-07, "y": 5.4641514e-05, "z": -2.682177e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.4564721, "y": 0.100000188, "z": 0.208606}, "Rotation": {"x": -2.41477636e-07, "y": 4.09811364e-05, "z": -3.70181226e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.455088079, "y": 0.100000136, "z": 0.164117068}, "Rotation": {"x": -4.866614e-07, "y": 8.196227e-05, "z": -4.41588632e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.406595528, "y": 0.1, "z": 0.164322123}, "Rotation": {"x": 2.007004e-08, "y": 5.4641514e-05, "z": -5.414088e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.158630043, "y": 0.10000018, "z": 0.125336081}, "Rotation": {"x": -6.90606953e-07, "y": 4.09811364e-05, "z": -2.7637978e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.229710743, "y": 0.100000188, "z": 0.0410436131}, "Rotation": {"x": 2.76361671e-08, "y": 5.4641514e-05, "z": -3.56568961e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.369862348, "y": 0.100000262, "z": 0.05465671}, "Rotation": {"x": -2.159071e-08, "y": 6.83018952e-05, "z": -2.82054685e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4190495, "y": 0.0999999046, "z": 0.0543358438}, "Rotation": {"x": 4.92904135e-08, "y": 5.4641514e-05, "z": -4.300786e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.469230354, "y": 0.0999999046, "z": 0.05521932}, "Rotation": {"x": -7.84846463e-07, "y": 8.196227e-05, "z": 6.982712e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.07829274, "y": 0.100000292, "z": -0.07845683}, "Rotation": {"x": 1.07429734e-07, "y": 4.09811364e-05, "z": -3.08111339e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.401256561, "y": 0.100000151, "z": -0.08286511}, "Rotation": {"x": -1.165478e-06, "y": 0.000109283028, "z": 1.37846683e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.335542977, "y": 0.100000173, "z": -0.110677242}, "Rotation": {"x": 1.29428386e-07, "y": 4.09811364e-05, "z": -2.81193138e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.3579095, "y": 0.100000083, "z": 0.00298474822}, "Rotation": {"x": -8.989771e-09, "y": 4.09811364e-05, "z": -2.587451e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.395151258, "y": 0.10000027, "z": -0.2267869}, "Rotation": {"x": -5.77262369e-07, "y": 6.83018952e-05, "z": -3.09254915e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.34555766, "y": 0.100000262, "z": -0.227018744}, "Rotation": {"x": 1.59392783e-07, "y": 8.196227e-05, "z": -4.72505945e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.06869899, "y": 0.100000158, "z": -0.199770913}, "Rotation": {"x": -7.91047e-07, "y": 4.09811364e-05, "z": -1.80930186e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.0881706253, "y": 0.100000143, "z": -0.2373622}, "Rotation": {"x": -4.73386166e-08, "y": 5.4641514e-05, "z": -3.55263e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.226863042, "y": 0.100000121, "z": -0.206166074}, "Rotation": {"x": 1.10812142e-08, "y": 4.09811364e-05, "z": -3.74568174e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.420987457, "y": 0.100000247, "z": -0.1809664}, "Rotation": {"x": -4.33666656e-07, "y": 6.83018952e-05, "z": -2.14196e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4704384, "y": 0.09999988, "z": -0.18121843}, "Rotation": {"x": -5.13217842e-08, "y": 5.4641514e-05, "z": -3.776932e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4220026, "y": 0.100000061, "z": -0.226003557}, "Rotation": {"x": -1.84460325e-09, "y": 6.83018952e-05, "z": -2.8417162e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.470707327, "y": 0.100000046, "z": -0.226329014}, "Rotation": {"x": -9.18720744e-08, "y": 5.4641514e-05, "z": -4.18205644e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.381316453, "y": 0.100000158, "z": -0.344041377}, "Rotation": {"x": 1.5743791e-07, "y": 9.562265e-05, "z": -2.00137265e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.357775956, "y": 0.100000083, "z": -0.4357368}, "Rotation": {"x": -2.7842313e-07, "y": 4.09811364e-05, "z": -2.51146872e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.3072332, "y": 0.100000076, "z": -0.4352719}, "Rotation": {"x": -3.31464411e-09, "y": 4.09811364e-05, "z": -2.397607e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.282465667, "y": 0.10000018, "z": -0.4805707}, "Rotation": {"x": -3.55464351e-08, "y": 4.09811364e-05, "z": -2.18146354e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.332543582, "y": 0.09999994, "z": -0.479849815}, "Rotation": {"x": 1.08149774e-08, "y": 6.83018952e-05, "z": -4.861492e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.384280264, "y": 0.09999996, "z": -0.480288923}, "Rotation": {"x": 7.296329e-08, "y": 6.83018952e-05, "z": -3.65225731e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.138906941, "y": 0.100000076, "z": -0.3571349}, "Rotation": {"x": -1.17491815e-07, "y": 6.83018952e-05, "z": -2.853865e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.121766359, "y": 0.100000076, "z": -0.493198842}, "Rotation": {"x": 2.04398738e-08, "y": 4.09811364e-05, "z": -1.8048533e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.143243179, "y": 0.100000136, "z": -0.626665}, "Rotation": {"x": -5.24954977e-08, "y": 5.4641514e-05, "z": -3.062289e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.284010142, "y": 0.100000128, "z": -0.665755451}, "Rotation": {"x": -2.43994378e-07, "y": 4.09811364e-05, "z": -4.87693057e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.3113752, "y": 0.099999994, "z": -0.792696}, "Rotation": {"x": -4.778215e-08, "y": 4.09811364e-05, "z": -3.952462e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.261276841, "y": 0.100000113, "z": -0.7918057}, "Rotation": {"x": -6.7009637e-07, "y": 5.4641514e-05, "z": -6.251466e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.0478779748, "y": 0.100000307, "z": -0.6823796}, "Rotation": {"x": -1.13848529e-07, "y": 4.09811364e-05, "z": -3.16787776e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.00182310957, "y": 0.100000188, "z": -0.682990849}, "Rotation": {"x": -2.19775287e-09, "y": 5.4641514e-05, "z": -2.83826381e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.0535315461, "y": 0.100000173, "z": -0.6825084}, "Rotation": {"x": -5.92172341e-07, "y": 5.4641514e-05, "z": -2.22497132e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.05271411, "y": 0.100000016, "z": -0.638223052}, "Rotation": {"x": 1.22585021e-07, "y": 5.4641514e-05, "z": -2.76540675e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.00135535782, "y": 0.100000151, "z": -0.6379968}, "Rotation": {"x": 1.943802e-07, "y": 5.4641514e-05, "z": 7.007041e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.0490297675, "y": 0.100000031, "z": -0.6386673}, "Rotation": {"x": 8.81251054e-08, "y": 5.4641514e-05, "z": -1.802394e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.0388980471, "y": 0.100000225, "z": -0.502511442}, "Rotation": {"x": -4.59199242e-07, "y": 5.4641514e-05, "z": -8.601463e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.0404235274, "y": 0.100000061, "z": -0.3794196}, "Rotation": {"x": 1.19212924e-08, "y": 5.4641514e-05, "z": -4.58157842e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.252658546, "y": 0.100000173, "z": -0.3293708}, "Rotation": {"x": 1.00608382e-07, "y": 5.4641514e-05, "z": -3.8066176e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.412008882, "y": 0.100000151, "z": -0.369046569}, "Rotation": {"x": 9.42578353e-08, "y": 5.4641514e-05, "z": -2.38599569e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.369120747, "y": 0.100000069, "z": -0.45999974}, "Rotation": {"x": -1.83162615e-06, "y": 1.36603785e-05, "z": -1.78557471e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.3200154, "y": 0.100000069, "z": -0.4599998}, "Rotation": {"x": 1.9296111e-07, "y": 6.83018952e-05, "z": -1.22664323e-06}, "Tags": ["troop"]}, {"Position": {"x": -0.271154135, "y": 0.10000018, "z": -0.459955037}, "Rotation": {"x": -9.925366e-07, "y": 4.09811364e-05, "z": -1.55565616e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.241680861, "y": 0.100000165, "z": -0.5932392}, "Rotation": {"x": -9.798289e-07, "y": 4.09811364e-05, "z": -2.62157045e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.1949771, "y": 0.100000069, "z": -0.708090663}, "Rotation": {"x": 7.466929e-08, "y": 5.4641514e-05, "z": -2.96619419e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.08049196, "y": 0.1000006, "z": 0.734508634}, "Rotation": {"x": 2.06513348e-10, "y": -0.00442596246, "z": -5.673507e-09}, "Tags": ["control"]}, {"Position": {"x": -0.0451759435, "y": 0.100000642, "z": 0.06579076}, "Rotation": {"x": 1.843012e-08, "y": 5.4641514e-05, "z": -1.6647574e-08}, "Tags": ["control"]}, {"Position": {"x": -0.0258299, "y": 0.100000367, "z": -0.874223053}, "Rotation": {"x": -3.7452363e-08, "y": -5.4641514e-05, "z": 1.76832913e-08}, "Tags": ["control"]}, {"Position": {"x": 0.48911953, "y": 0.100000113, "z": 0.7836856}, "Rotation": {"x": -5.14486146e-07, "y": 2.26427662e-15, "z": -5.043226e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.423734754, "y": 0.100000121, "z": 0.7836855}, "Rotation": {"x": -1.42310981e-07, "y": 2.7320757e-05, "z": -9.533074e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3583503, "y": 0.100000247, "z": 0.783685565}, "Rotation": {"x": -4.64145415e-07, "y": 1.78054415e-15, "z": -4.39593578e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.292965651, "y": 0.100000255, "z": 0.783685446}, "Rotation": {"x": -4.8696927e-07, "y": 2.58883084e-15, "z": -6.09192739e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.0219074152, "y": 0.099999994, "z": 0.8671818}, "Rotation": {"x": -1.396765e-07, "y": 6.792246e-16, "z": -5.572405e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.04368886, "y": 0.100000121, "z": 0.867181659}, "Rotation": {"x": 7.356413e-07, "y": 0.00394784939, "z": -3.48484463e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.109707713, "y": 0.10000024, "z": 0.8671817}, "Rotation": {"x": 2.83693026e-07, "y": 0.016091926, "z": -3.170495e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.174552247, "y": 0.100000136, "z": 0.8671817}, "Rotation": {"x": 1.95994346e-07, "y": 0.03173308, "z": -6.63904643e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.263131827, "y": 0.10000027, "z": 0.446059972}, "Rotation": {"x": -1.09762277e-06, "y": 3.4637424e-15, "z": -3.616139e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.328516454, "y": 0.100000277, "z": 0.446059972}, "Rotation": {"x": -8.24513165e-07, "y": 2.7320757e-05, "z": -4.97279757e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.459285676, "y": 0.0999999344, "z": 0.446059972}, "Rotation": {"x": -8.176792e-07, "y": 4.551755e-16, "z": -6.378941e-08}, "Tags": ["spy"]}, {"Position": {"x": -0.39390108, "y": 0.100000165, "z": 0.446059972}, "Rotation": {"x": -3.65982373e-07, "y": 1.5213167e-15, "z": -4.7633452e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.0697782561, "y": 0.100000151, "z": 0.47151342}, "Rotation": {"x": -6.70487964e-07, "y": 1.15246049e-14, "z": -1.96964379e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.00439362926, "y": 0.100000143, "z": 0.47151342}, "Rotation": {"x": -5.104154e-07, "y": 5.24365646e-16, "z": -1.17723474e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.0609910265, "y": 0.100000255, "z": 0.4715135}, "Rotation": {"x": 1.50064253e-07, "y": 1.36603785e-05, "z": -7.08555547e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.126375675, "y": 0.100000247, "z": 0.4715135}, "Rotation": {"x": -1.41785893e-06, "y": -4.093468e-15, "z": 3.308347e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.307667345, "y": 0.100000031, "z": 0.347549736}, "Rotation": {"x": 1.67485084e-07, "y": -6.53829444e-16, "z": -4.47343353e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3730519, "y": 0.100000143, "z": 0.347549736}, "Rotation": {"x": 4.18110773e-07, "y": -1.45489926e-15, "z": -3.98744049e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.438436568, "y": 0.100000136, "z": 0.3475498}, "Rotation": {"x": -1.98596638e-07, "y": 2.7320757e-05, "z": -1.28494651e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.503821254, "y": 0.100000128, "z": 0.347549736}, "Rotation": {"x": -3.125423e-07, "y": 2.30239479e-15, "z": -8.441577e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.5400126, "y": 0.1000001, "z": 0.0876253}, "Rotation": {"x": 5.242067e-07, "y": -2.58057778e-15, "z": -5.641142e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.4746278, "y": 0.100000091, "z": 0.0876253}, "Rotation": {"x": -1.84650776e-06, "y": -4.19471044e-13, "z": 7.67044355e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.4092435, "y": 0.100000083, "z": 0.08762546}, "Rotation": {"x": -3.518949e-07, "y": 1.36603785e-05, "z": -6.57227e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.3438586, "y": 0.100000076, "z": 0.08762551}, "Rotation": {"x": 6.25037657e-08, "y": -1.93645218e-16, "z": -3.55020347e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.143322065, "y": 0.100000143, "z": 0.197700158}, "Rotation": {"x": -5.67118263e-07, "y": 3.35676023e-15, "z": -6.782648e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.07793727, "y": 0.100000016, "z": 0.1977001}, "Rotation": {"x": -2.790247e-07, "y": 1.87918177e-15, "z": -7.71753832e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.0125529561, "y": 0.100000009, "z": 0.197700068}, "Rotation": {"x": 5.82769758e-07, "y": 2.7320757e-05, "z": 7.247457e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.0528316461, "y": 0.100000121, "z": 0.197700128}, "Rotation": {"x": -1.76232035e-07, "y": 2.670425e-16, "z": -1.7363935e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.302057564, "y": 0.100000136, "z": -0.0177875031}, "Rotation": {"x": -1.11165161e-06, "y": 6.57609656e-15, "z": -6.778789e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.367442131, "y": 0.100000009, "z": -0.01778735}, "Rotation": {"x": -5.4996093e-07, "y": 5.975455e-15, "z": -1.24506437e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.432826757, "y": 0.100000121, "z": -0.0177874174}, "Rotation": {"x": -5.76111461e-07, "y": 2.7320757e-05, "z": -1.3192531e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.498211354, "y": 0.100000113, "z": -0.01778734}, "Rotation": {"x": -3.713536e-07, "y": 2.521561e-15, "z": -7.7809824e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3384615, "y": 0.100000128, "z": -0.18849948}, "Rotation": {"x": -8.72855139e-07, "y": -0.000232226434, "z": -3.63481576e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.338461518, "y": 0.100000136, "z": -0.260246515}, "Rotation": {"x": -3.21443224e-07, "y": 1.76873206e-15, "z": -6.30536761e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.443052858, "y": 0.099999994, "z": -0.2979046}, "Rotation": {"x": -5.07656e-07, "y": -4.09811364e-05, "z": -1.778798e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.5084374, "y": 0.100000106, "z": -0.2979042}, "Rotation": {"x": 4.5308667e-08, "y": -5.528934e-16, "z": -1.39834e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.4156479, "y": 0.100000106, "z": -0.553855}, "Rotation": {"x": -1.92510061e-06, "y": -4.019903e-13, "z": -3.04810527e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3502634, "y": 0.100000113, "z": -0.5538549}, "Rotation": {"x": -1.72456475e-06, "y": 1.36603785e-05, "z": -4.504669e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.2848788, "y": 0.10000024, "z": -0.5538547}, "Rotation": {"x": -8.488211e-07, "y": 1.07806906e-14, "z": -1.4554023e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.219494149, "y": 0.100000247, "z": -0.5538547}, "Rotation": {"x": -9.036166e-07, "y": 1.36603785e-05, "z": -9.16257136e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.35368675, "y": 0.1, "z": -0.8709405}, "Rotation": {"x": -8.47634453e-07, "y": 2.7320757e-05, "z": 1.23319762e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.2883023, "y": 0.100000247, "z": -0.8709408}, "Rotation": {"x": -1.57109156e-07, "y": 4.09811364e-05, "z": 9.718927e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.2229177, "y": 0.100000136, "z": -0.8709405}, "Rotation": {"x": -2.45614331e-07, "y": 1.36603785e-05, "z": -5.303256e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.157533258, "y": 0.100000262, "z": -0.8709408}, "Rotation": {"x": -2.99975227e-07, "y": 2.84417549e-15, "z": -1.08648487e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.07986431, "y": 0.100000255, "z": -0.7465019}, "Rotation": {"x": 1.10500923e-06, "y": 4.06253617e-13, "z": -8.891141e-08}, "Tags": ["spy"]}, {"Position": {"x": 0.0144797442, "y": 0.100000143, "z": -0.746502042}, "Rotation": {"x": 1.36230472e-06, "y": 2.7320757e-05, "z": -1.14112208e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.0509049, "y": 0.100000151, "z": -0.746502042}, "Rotation": {"x": 1.8136227e-06, "y": 3.73348325e-13, "z": -2.13325347e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.1162895, "y": 0.100000158, "z": -0.7465019}, "Rotation": {"x": 2.20334573e-06, "y": 8.032488e-13, "z": -5.706931e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.274112552, "y": 0.10000021, "z": -0.5279073}, "Rotation": {"x": 8.154738e-07, "y": -2.7320757e-05, "z": 1.25010411e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.339497149, "y": 0.100000218, "z": -0.5279074}, "Rotation": {"x": 1.07793778e-06, "y": 1.14264821e-14, "z": 1.21470691e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.4048819, "y": 0.100000225, "z": -0.527907252}, "Rotation": {"x": 4.301153e-07, "y": -2.7320757e-05, "z": -1.87476269e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.470266432, "y": 0.100000232, "z": -0.527907}, "Rotation": {"x": 1.225917e-06, "y": 1.2156655e-14, "z": 1.13633314e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.0532106534, "y": 0.100000128, "z": -0.298076332}, "Rotation": {"x": 1.07926809e-07, "y": 2.7320757e-05, "z": -5.685484e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.118595228, "y": 0.100000255, "z": -0.298075885}, "Rotation": {"x": 2.79777282e-07, "y": -1.82126462e-15, "z": -7.45956e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.169230759, "y": 0.100000218, "z": -0.241916433}, "Rotation": {"x": 2.52706e-07, "y": 1.1022228e-15, "z": 4.998118e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.169230774, "y": 0.100000091, "z": -0.171802089}, "Rotation": {"x": -9.01983242e-07, "y": 0.00133871706, "z": -3.37435523e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.3320212, "y": 0.100000143, "z": -0.3049357}, "Rotation": {"x": -1.16054161e-06, "y": -3.31234415e-15, "z": 3.27059951e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.397405922, "y": 0.100000151, "z": -0.3049354}, "Rotation": {"x": -6.967085e-07, "y": 4.09811364e-05, "z": -1.0637347e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.4627906, "y": 0.100000277, "z": -0.304935247}, "Rotation": {"x": -1.201822e-06, "y": 1.36603785e-05, "z": -3.73949518e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.478181, "y": 0.100000151, "z": -0.240965128}, "Rotation": {"x": 5.154046e-07, "y": 3.9728946e-13, "z": -2.18365722e-06}, "Tags": ["spy"]}]}, "3": {"GUID": "8f7ed8", "Name": "Custom_Tile", "Transform": {"posX": 0.0, "posY": 1.48, "posZ": 11.0, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 26.0, "scaleY": 1.0, "scaleZ": 26.0}, "Nickname": "", "Description": "Board", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 0.249999553, "g": 0.249999553, "b": 0.249999553}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": false, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "CustomImage": {"ImageURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669803132/4EC6B9C91A4C058656EA1EFA0CAB04F208311942/", "ImageSecondaryURL": "", "ImageScalar": 1.0, "WidthScale": 0.0, "CustomTile": {"Type": 0, "Thickness": 0.1, "Stackable": false, "Stretch": true}}, "LuaScript": "", "LuaScriptState": "", "XmlUI": "", "AttachedSnapPoints": [{"Position": {"x": -0.106956236, "y": 0.100000083, "z": 0.9311196}, "Rotation": {"x": 5.678063e-08, "y": 4.09811364e-05, "z": -1.84019029e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.05655723, "y": 0.100000091, "z": 0.930653751}, "Rotation": {"x": -3.35092864e-07, "y": 5.4641514e-05, "z": -1.23060047e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.005892145, "y": 0.10000021, "z": 0.931565166}, "Rotation": {"x": 1.83083856e-07, "y": 5.4641514e-05, "z": -8.554557e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.1310636, "y": 0.100000083, "z": 0.836117}, "Rotation": {"x": -2.43584225e-07, "y": 6.83018952e-05, "z": -3.359286e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.220454887, "y": 0.100000158, "z": 0.9265943}, "Rotation": {"x": 7.995073e-09, "y": 5.4641514e-05, "z": -2.1241587e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.3570165, "y": 0.100000188, "z": 0.8557662}, "Rotation": {"x": 5.4954775e-08, "y": 6.83018952e-05, "z": -5.073384e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4076918, "y": 0.100000195, "z": 0.855804145}, "Rotation": {"x": 4.323053e-08, "y": 5.4641514e-05, "z": -1.955191e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.455930859, "y": 0.100000069, "z": 0.8563245}, "Rotation": {"x": -3.65879146e-07, "y": 5.4641514e-05, "z": -3.76916574e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.294736832, "y": 0.100000061, "z": 0.6875983}, "Rotation": {"x": -5.76576e-07, "y": 4.09811364e-05, "z": -1.51230537e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.426977783, "y": 0.100000128, "z": 0.659239}, "Rotation": {"x": -3.47279538e-08, "y": 5.4641514e-05, "z": -3.21477671e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.231832713, "y": 0.100000113, "z": 0.563093}, "Rotation": {"x": -2.76775971e-08, "y": 5.4641514e-05, "z": -3.48317684e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.000627097266, "y": 0.100000091, "z": 0.539936841}, "Rotation": {"x": -3.14919873e-07, "y": 4.09811364e-05, "z": -3.3873377e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.05126633, "y": 0.100000091, "z": 0.5403133}, "Rotation": {"x": 6.54188952e-08, "y": 5.4641514e-05, "z": -2.29099243e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.1006845, "y": 0.10000021, "z": 0.539888263}, "Rotation": {"x": -4.48709415e-07, "y": 5.4641514e-05, "z": -1.02727348e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.176813409, "y": 0.100000091, "z": 0.5147679}, "Rotation": {"x": 5.07998621e-08, "y": 8.196227e-05, "z": -1.47892e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.277509481, "y": 0.100000188, "z": 0.6496129}, "Rotation": {"x": -1.25558671e-07, "y": 4.09811364e-05, "z": -2.79818835e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.305141658, "y": 0.100000121, "z": 0.5154639}, "Rotation": {"x": 9.68804557e-08, "y": 5.4641514e-05, "z": -3.50781448e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.3533314, "y": 0.100000136, "z": 0.5160048}, "Rotation": {"x": -2.27904273e-08, "y": 4.09811364e-05, "z": -2.666333e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.325868666, "y": 0.100000106, "z": 0.380166829}, "Rotation": {"x": 1.033606e-07, "y": 6.83018952e-05, "z": -2.227597e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.385574728, "y": 0.100000039, "z": 0.3103113}, "Rotation": {"x": -2.53059937e-07, "y": 5.4641514e-05, "z": -3.85456076e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.245713383, "y": 0.100000188, "z": 0.227346554}, "Rotation": {"x": -3.685041e-08, "y": 4.09811364e-05, "z": -2.65311e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.004653071, "y": 0.100000054, "z": 0.396768451}, "Rotation": {"x": -4.912758e-07, "y": 5.4641514e-05, "z": -2.23376e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.404302329, "y": 0.1, "z": 0.468289375}, "Rotation": {"x": -7.237965e-07, "y": 4.09811364e-05, "z": -7.71364e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.453679562, "y": 0.1, "z": 0.467526436}, "Rotation": {"x": 1.86696866e-07, "y": 5.4641514e-05, "z": -3.842655e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.379435629, "y": 0.100000113, "z": 0.423960537}, "Rotation": {"x": -3.25228228e-07, "y": 8.196227e-05, "z": -7.834468e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.429628, "y": 0.099999994, "z": 0.42416054}, "Rotation": {"x": 7.605476e-09, "y": 5.4641514e-05, "z": -2.6035562e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4780354, "y": 0.1000001, "z": 0.423820972}, "Rotation": {"x": -8.031034e-07, "y": 5.4641514e-05, "z": -7.33406154e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.405386925, "y": 0.10000018, "z": 0.277246684}, "Rotation": {"x": -7.459923e-07, "y": 5.4641514e-05, "z": -3.42660211e-09}, "Tags": ["troop"]}, {"Position": {"x": 0.429525, "y": 0.100000031, "z": 0.155497536}, "Rotation": {"x": 1.16170739e-07, "y": 6.83018952e-05, "z": -1.81467229e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.00134328054, "y": 0.100000061, "z": 0.306656778}, "Rotation": {"x": 6.847061e-08, "y": 5.4641514e-05, "z": -2.75814415e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.0481604822, "y": 0.100000069, "z": 0.305874765}, "Rotation": {"x": -7.69572e-07, "y": 5.4641514e-05, "z": 5.752573e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.04823315, "y": 0.100000113, "z": 0.2607574}, "Rotation": {"x": 3.46521176e-08, "y": 4.09811364e-05, "z": -1.78962722e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.00213938113, "y": 0.100000113, "z": 0.2603982}, "Rotation": {"x": 2.79264185e-08, "y": 5.4641514e-05, "z": -2.27702046e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.405867159, "y": 0.1000002, "z": 0.2090352}, "Rotation": {"x": 1.38716388e-07, "y": 5.4641514e-05, "z": -2.682177e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.4564721, "y": 0.100000188, "z": 0.208606}, "Rotation": {"x": -2.41477636e-07, "y": 4.09811364e-05, "z": -3.70181226e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.455088079, "y": 0.100000136, "z": 0.164117068}, "Rotation": {"x": -4.866614e-07, "y": 8.196227e-05, "z": -4.41588632e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.406595528, "y": 0.1, "z": 0.164322123}, "Rotation": {"x": 2.007004e-08, "y": 5.4641514e-05, "z": -5.414088e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.158630043, "y": 0.10000018, "z": 0.125336081}, "Rotation": {"x": -6.90606953e-07, "y": 4.09811364e-05, "z": -2.7637978e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.229710743, "y": 0.100000188, "z": 0.0410436131}, "Rotation": {"x": 2.76361671e-08, "y": 5.4641514e-05, "z": -3.56568961e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.369862348, "y": 0.100000262, "z": 0.05465671}, "Rotation": {"x": -2.159071e-08, "y": 6.83018952e-05, "z": -2.82054685e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4190495, "y": 0.0999999046, "z": 0.0543358438}, "Rotation": {"x": 4.92904135e-08, "y": 5.4641514e-05, "z": -4.300786e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.469230354, "y": 0.0999999046, "z": 0.05521932}, "Rotation": {"x": -7.84846463e-07, "y": 8.196227e-05, "z": 6.982712e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.07829274, "y": 0.100000292, "z": -0.07845683}, "Rotation": {"x": 1.07429734e-07, "y": 4.09811364e-05, "z": -3.08111339e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.401256561, "y": 0.100000151, "z": -0.08286511}, "Rotation": {"x": -1.165478e-06, "y": 0.000109283028, "z": 1.37846683e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.335542977, "y": 0.100000173, "z": -0.110677242}, "Rotation": {"x": 1.29428386e-07, "y": 4.09811364e-05, "z": -2.81193138e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.3579095, "y": 0.100000083, "z": 0.00298474822}, "Rotation": {"x": -8.989771e-09, "y": 4.09811364e-05, "z": -2.587451e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.395151258, "y": 0.10000027, "z": -0.2267869}, "Rotation": {"x": -5.77262369e-07, "y": 6.83018952e-05, "z": -3.09254915e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.34555766, "y": 0.100000262, "z": -0.227018744}, "Rotation": {"x": 1.59392783e-07, "y": 8.196227e-05, "z": -4.72505945e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.06869899, "y": 0.100000158, "z": -0.199770913}, "Rotation": {"x": -7.91047e-07, "y": 4.09811364e-05, "z": -1.80930186e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.0881706253, "y": 0.100000143, "z": -0.2373622}, "Rotation": {"x": -4.73386166e-08, "y": 5.4641514e-05, "z": -3.55263e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.226863042, "y": 0.100000121, "z": -0.206166074}, "Rotation": {"x": 1.10812142e-08, "y": 4.09811364e-05, "z": -3.74568174e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.420987457, "y": 0.100000247, "z": -0.1809664}, "Rotation": {"x": -4.33666656e-07, "y": 6.83018952e-05, "z": -2.14196e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4704384, "y": 0.09999988, "z": -0.18121843}, "Rotation": {"x": -5.13217842e-08, "y": 5.4641514e-05, "z": -3.776932e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4220026, "y": 0.100000061, "z": -0.226003557}, "Rotation": {"x": -1.84460325e-09, "y": 6.83018952e-05, "z": -2.8417162e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.470707327, "y": 0.100000046, "z": -0.226329014}, "Rotation": {"x": -9.18720744e-08, "y": 5.4641514e-05, "z": -4.18205644e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.381316453, "y": 0.100000158, "z": -0.344041377}, "Rotation": {"x": 1.5743791e-07, "y": 9.562265e-05, "z": -2.00137265e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.357775956, "y": 0.100000083, "z": -0.4357368}, "Rotation": {"x": -2.7842313e-07, "y": 4.09811364e-05, "z": -2.51146872e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.3072332, "y": 0.100000076, "z": -0.4352719}, "Rotation": {"x": -3.31464411e-09, "y": 4.09811364e-05, "z": -2.397607e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.282465667, "y": 0.10000018, "z": -0.4805707}, "Rotation": {"x": -3.55464351e-08, "y": 4.09811364e-05, "z": -2.18146354e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.332543582, "y": 0.09999994, "z": -0.479849815}, "Rotation": {"x": 1.08149774e-08, "y": 6.83018952e-05, "z": -4.861492e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.384280264, "y": 0.09999996, "z": -0.480288923}, "Rotation": {"x": 7.296329e-08, "y": 6.83018952e-05, "z": -3.65225731e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.138906941, "y": 0.100000076, "z": -0.3571349}, "Rotation": {"x": -1.17491815e-07, "y": 6.83018952e-05, "z": -2.853865e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.121766359, "y": 0.100000076, "z": -0.493198842}, "Rotation": {"x": 2.04398738e-08, "y": 4.09811364e-05, "z": -1.8048533e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.143243179, "y": 0.100000136, "z": -0.626665}, "Rotation": {"x": -5.24954977e-08, "y": 5.4641514e-05, "z": -3.062289e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.284010142, "y": 0.100000128, "z": -0.665755451}, "Rotation": {"x": -2.43994378e-07, "y": 4.09811364e-05, "z": -4.87693057e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.3113752, "y": 0.099999994, "z": -0.792696}, "Rotation": {"x": -4.778215e-08, "y": 4.09811364e-05, "z": -3.952462e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.261276841, "y": 0.100000113, "z": -0.7918057}, "Rotation": {"x": -6.7009637e-07, "y": 5.4641514e-05, "z": -6.251466e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.0478779748, "y": 0.100000307, "z": -0.6823796}, "Rotation": {"x": -1.13848529e-07, "y": 4.09811364e-05, "z": -3.16787776e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.00182310957, "y": 0.100000188, "z": -0.682990849}, "Rotation": {"x": -2.19775287e-09, "y": 5.4641514e-05, "z": -2.83826381e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.0535315461, "y": 0.100000173, "z": -0.6825084}, "Rotation": {"x": -5.92172341e-07, "y": 5.4641514e-05, "z": -2.22497132e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.05271411, "y": 0.100000016, "z": -0.638223052}, "Rotation": {"x": 1.22585021e-07, "y": 5.4641514e-05, "z": -2.76540675e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.00135535782, "y": 0.100000151, "z": -0.6379968}, "Rotation": {"x": 1.943802e-07, "y": 5.4641514e-05, "z": 7.007041e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.0490297675, "y": 0.100000031, "z": -0.6386673}, "Rotation": {"x": 8.81251054e-08, "y": 5.4641514e-05, "z": -1.802394e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.0388980471, "y": 0.100000225, "z": -0.502511442}, "Rotation": {"x": -4.59199242e-07, "y": 5.4641514e-05, "z": -8.601463e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.0404235274, "y": 0.100000061, "z": -0.3794196}, "Rotation": {"x": 1.19212924e-08, "y": 5.4641514e-05, "z": -4.58157842e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.252658546, "y": 0.100000173, "z": -0.3293708}, "Rotation": {"x": 1.00608382e-07, "y": 5.4641514e-05, "z": -3.8066176e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.412008882, "y": 0.100000151, "z": -0.369046569}, "Rotation": {"x": 9.42578353e-08, "y": 5.4641514e-05, "z": -2.38599569e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.369120747, "y": 0.100000069, "z": -0.45999974}, "Rotation": {"x": -1.83162615e-06, "y": 1.36603785e-05, "z": -1.78557471e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.3200154, "y": 0.100000069, "z": -0.4599998}, "Rotation": {"x": 1.9296111e-07, "y": 6.83018952e-05, "z": -1.22664323e-06}, "Tags": ["troop"]}, {"Position": {"x": -0.271154135, "y": 0.10000018, "z": -0.459955037}, "Rotation": {"x": -9.925366e-07, "y": 4.09811364e-05, "z": -1.55565616e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.241680861, "y": 0.100000165, "z": -0.5932392}, "Rotation": {"x": -9.798289e-07, "y": 4.09811364e-05, "z": -2.62157045e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.1949771, "y": 0.100000069, "z": -0.708090663}, "Rotation": {"x": 7.466929e-08, "y": 5.4641514e-05, "z": -2.96619419e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.6034918, "y": 0.100000158, "z": 0.849898}, "Rotation": {"x": 4.66048959e-08, "y": 4.09811364e-05, "z": -1.73365763e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8002731, "y": 0.100000173, "z": 0.866063654}, "Rotation": {"x": 2.24701466e-08, "y": 4.09811364e-05, "z": -4.17679615e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8509787, "y": 0.10000018, "z": 0.8652216}, "Rotation": {"x": -8.80763366e-07, "y": 4.09811364e-05, "z": 1.41693846e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.900194764, "y": 0.100000173, "z": 0.8653954}, "Rotation": {"x": 7.796591e-10, "y": -5.4641514e-05, "z": -2.17714827e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.833583653, "y": 0.100000195, "z": 0.450195223}, "Rotation": {"x": 5.693362e-07, "y": 4.09811364e-05, "z": -3.534259e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8898815, "y": 0.10000024, "z": 0.304951847}, "Rotation": {"x": 1.08443047e-07, "y": 4.09811364e-05, "z": -4.929707e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8400153, "y": 0.100000121, "z": 0.30510807}, "Rotation": {"x": -2.24019672e-07, "y": 4.09811364e-05, "z": -5.457454e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.7103866, "y": 0.100000121, "z": 0.291271031}, "Rotation": {"x": -7.431119e-07, "y": 4.09811364e-05, "z": -3.30988e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.629915, "y": 0.100000158, "z": 0.373731554}, "Rotation": {"x": -2.19312454e-07, "y": 5.4641514e-05, "z": -4.17384967e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8326854, "y": 0.100000113, "z": 0.118012927}, "Rotation": {"x": 2.762502e-08, "y": 6.83018952e-05, "z": -5.591051e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.887121, "y": 0.100000173, "z": -0.0142108174}, "Rotation": {"x": -1.29400576e-07, "y": 4.09811364e-05, "z": -4.26654e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8392526, "y": 0.100000173, "z": -0.0157595184}, "Rotation": {"x": 6.53122356e-08, "y": 5.4641514e-05, "z": -2.077129e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.7881551, "y": 0.100000165, "z": -0.0161310881}, "Rotation": {"x": -2.46802642e-07, "y": 4.09811364e-05, "z": -4.54026576e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.6500772, "y": 0.100000151, "z": -0.00553656043}, "Rotation": {"x": -5.15198337e-07, "y": 5.4641514e-05, "z": -2.76159938e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.831166267, "y": 0.09999998, "z": -0.176085174}, "Rotation": {"x": -2.45651677e-08, "y": 9.562265e-05, "z": -1.5535359e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8848577, "y": 0.100000143, "z": -0.307518125}, "Rotation": {"x": -5.287997e-07, "y": 6.83018952e-05, "z": -4.37239152e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8340373, "y": 0.100000128, "z": -0.3087641}, "Rotation": {"x": 1.72678138e-08, "y": 8.196227e-05, "z": -2.870735e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8337044, "y": 0.100000173, "z": -0.353691041}, "Rotation": {"x": -5.67178631e-07, "y": 0.000122943413, "z": -4.669032e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8862277, "y": 0.100000076, "z": -0.353006333}, "Rotation": {"x": -1.842881e-07, "y": 4.09811364e-05, "z": -3.75713057e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.639165938, "y": 0.09999994, "z": -0.301028222}, "Rotation": {"x": -4.45228e-09, "y": 0.000122943413, "z": -2.14795023e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.856630743, "y": 0.100000165, "z": -0.531583369}, "Rotation": {"x": -5.98e-09, "y": 4.09811364e-05, "z": -2.392624e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8997876, "y": 0.100000113, "z": -0.6781479}, "Rotation": {"x": -5.952824e-07, "y": 8.196227e-05, "z": -2.705941e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.8490432, "y": 0.100000225, "z": -0.6778483}, "Rotation": {"x": 5.246039e-07, "y": 0.000150264168, "z": -1.90423037e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.798461854, "y": 0.1000001, "z": -0.679553151}, "Rotation": {"x": -1.198982e-07, "y": 4.09811364e-05, "z": -1.29855422e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.527647257, "y": 0.100000143, "z": -0.5558938}, "Rotation": {"x": 7.588723e-07, "y": 5.4641514e-05, "z": -8.41620249e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.599036157, "y": 0.100000128, "z": -0.734418631}, "Rotation": {"x": -1.791522e-07, "y": 5.4641514e-05, "z": -4.00994651e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.5489999, "y": 0.100000121, "z": -0.7353946}, "Rotation": {"x": -5.89386843e-07, "y": -1.36603785e-05, "z": -2.44787628e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.499571741, "y": 0.100000359, "z": -0.7347821}, "Rotation": {"x": -1.80369824e-07, "y": -6.83018952e-05, "z": 2.63472572e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.828875959, "y": 0.100000471, "z": 0.67187953}, "Rotation": {"x": -1.04460627e-08, "y": -3.44991949e-18, "z": 3.78450373e-08}, "Tags": ["control"]}, {"Position": {"x": -0.08049196, "y": 0.1000006, "z": 0.734508634}, "Rotation": {"x": 2.06513348e-10, "y": -0.00442596246, "z": -5.673507e-09}, "Tags": ["control"]}, {"Position": {"x": -0.0451759435, "y": 0.100000642, "z": 0.06579076}, "Rotation": {"x": 1.843012e-08, "y": 5.4641514e-05, "z": -1.6647574e-08}, "Tags": ["control"]}, {"Position": {"x": -0.0258299, "y": 0.100000367, "z": -0.874223053}, "Rotation": {"x": -3.7452363e-08, "y": -5.4641514e-05, "z": 1.76832913e-08}, "Tags": ["control"]}, {"Position": {"x": 0.8263526, "y": 0.1000003, "z": -0.868528068}, "Rotation": {"x": 8.21207e-09, "y": 0.000614717, "z": 9.019995e-09}, "Tags": ["control"]}, {"Position": {"x": 0.9284009, "y": 0.100000076, "z": 0.7984941}, "Rotation": {"x": -5.14817145e-07, "y": 1.36603785e-05, "z": 2.677156e-08}, "Tags": ["spy"]}, {"Position": {"x": 0.863016367, "y": 0.100000083, "z": 0.7984941}, "Rotation": {"x": -2.29185474e-07, "y": 4.09811364e-05, "z": -6.48747744e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.7976318, "y": 0.10000021, "z": 0.79849416}, "Rotation": {"x": 1.18135929e-07, "y": -1.01067876e-15, "z": -9.803558e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.7322472, "y": 0.100000218, "z": 0.7984941}, "Rotation": {"x": 1.87596783e-07, "y": -8.750105e-16, "z": -5.34491164e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.48911953, "y": 0.100000113, "z": 0.7836856}, "Rotation": {"x": -5.14486146e-07, "y": 2.26427662e-15, "z": -5.043226e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.423734754, "y": 0.100000121, "z": 0.7836855}, "Rotation": {"x": -1.42310981e-07, "y": 2.7320757e-05, "z": -9.533074e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3583503, "y": 0.100000247, "z": 0.783685565}, "Rotation": {"x": -4.64145415e-07, "y": 1.78054415e-15, "z": -4.39593578e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.292965651, "y": 0.100000255, "z": 0.783685446}, "Rotation": {"x": -4.8696927e-07, "y": 2.58883084e-15, "z": -6.09192739e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.0219074152, "y": 0.099999994, "z": 0.8671818}, "Rotation": {"x": -1.396765e-07, "y": 6.792246e-16, "z": -5.572405e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.04368886, "y": 0.100000121, "z": 0.867181659}, "Rotation": {"x": 7.356413e-07, "y": 0.00394784939, "z": -3.48484463e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.109707713, "y": 0.10000024, "z": 0.8671817}, "Rotation": {"x": 2.83693026e-07, "y": 0.016091926, "z": -3.170495e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.174552247, "y": 0.100000136, "z": 0.8671817}, "Rotation": {"x": 1.95994417e-07, "y": 0.03173308, "z": -6.63904643e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.263131827, "y": 0.10000027, "z": 0.446059972}, "Rotation": {"x": -1.09762277e-06, "y": 3.4637424e-15, "z": -3.616139e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.328516454, "y": 0.100000277, "z": 0.446059972}, "Rotation": {"x": -8.24513165e-07, "y": 2.7320757e-05, "z": -4.97279757e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.459285676, "y": 0.0999999344, "z": 0.446059972}, "Rotation": {"x": -8.176792e-07, "y": 4.551755e-16, "z": -6.378941e-08}, "Tags": ["spy"]}, {"Position": {"x": -0.39390108, "y": 0.100000165, "z": 0.446059972}, "Rotation": {"x": -3.65982373e-07, "y": 1.5213167e-15, "z": -4.7633452e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.0697782561, "y": 0.100000151, "z": 0.47151342}, "Rotation": {"x": -6.70487964e-07, "y": 1.15246049e-14, "z": -1.96964379e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.00439362926, "y": 0.100000143, "z": 0.47151342}, "Rotation": {"x": -5.104154e-07, "y": 5.24365646e-16, "z": -1.17723474e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.0609910265, "y": 0.100000255, "z": 0.4715135}, "Rotation": {"x": 1.50064253e-07, "y": 1.36603785e-05, "z": -7.08555547e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.126375675, "y": 0.100000247, "z": 0.4715135}, "Rotation": {"x": -1.41785893e-06, "y": -4.093468e-15, "z": 3.308347e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.307667345, "y": 0.100000031, "z": 0.347549736}, "Rotation": {"x": 1.67485084e-07, "y": -6.53829444e-16, "z": -4.47343353e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3730519, "y": 0.100000143, "z": 0.347549736}, "Rotation": {"x": 4.18110773e-07, "y": -1.45489926e-15, "z": -3.98744049e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.438436568, "y": 0.100000136, "z": 0.3475498}, "Rotation": {"x": -1.98596638e-07, "y": 2.7320757e-05, "z": -1.28494651e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.503821254, "y": 0.100000128, "z": 0.347549736}, "Rotation": {"x": -3.125423e-07, "y": 2.30239479e-15, "z": -8.441577e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.5400126, "y": 0.1000001, "z": 0.0876253}, "Rotation": {"x": 5.242067e-07, "y": -2.58057778e-15, "z": -5.641142e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.4746278, "y": 0.100000091, "z": 0.0876253}, "Rotation": {"x": -1.84650776e-06, "y": -4.19471044e-13, "z": 7.67044355e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.4092435, "y": 0.100000083, "z": 0.08762546}, "Rotation": {"x": -3.518949e-07, "y": 1.36603785e-05, "z": -6.57227e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.3438586, "y": 0.100000076, "z": 0.08762551}, "Rotation": {"x": 6.25037657e-08, "y": -1.93645218e-16, "z": -3.55020347e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.143322065, "y": 0.100000143, "z": 0.197700158}, "Rotation": {"x": -5.67118263e-07, "y": 3.35676023e-15, "z": -6.782648e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.07793727, "y": 0.100000016, "z": 0.1977001}, "Rotation": {"x": -2.790247e-07, "y": 1.87918177e-15, "z": -7.71753832e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.0125529561, "y": 0.100000009, "z": 0.197700068}, "Rotation": {"x": 5.82769758e-07, "y": 2.7320757e-05, "z": 7.247457e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.0528316461, "y": 0.100000121, "z": 0.197700128}, "Rotation": {"x": -1.76232035e-07, "y": 2.670425e-16, "z": -1.7363935e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.302057564, "y": 0.100000136, "z": -0.0177875031}, "Rotation": {"x": -1.11165161e-06, "y": 6.57609656e-15, "z": -6.778789e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.367442131, "y": 0.100000009, "z": -0.01778735}, "Rotation": {"x": -5.4996093e-07, "y": 5.975455e-15, "z": -1.24506437e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.432826757, "y": 0.100000121, "z": -0.0177874174}, "Rotation": {"x": -5.76111461e-07, "y": 2.7320757e-05, "z": -1.3192531e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.498211354, "y": 0.100000113, "z": -0.01778734}, "Rotation": {"x": -3.713536e-07, "y": 2.521561e-15, "z": -7.7809824e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.7292276, "y": 0.09999999, "z": -0.08903507}, "Rotation": {"x": 1.62217489e-07, "y": -1.07888429e-15, "z": -7.621313e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.794611752, "y": 0.1000001, "z": -0.08903495}, "Rotation": {"x": -1.505604e-06, "y": -2.7320757e-05, "z": 1.42605813e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.859996438, "y": 0.100000091, "z": -0.0890348852}, "Rotation": {"x": -1.49045525e-06, "y": -2.13684745e-14, "z": 1.64288508e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.925380945, "y": 0.100000083, "z": -0.08903502}, "Rotation": {"x": -1.76472236e-06, "y": -2.7320757e-05, "z": 9.996256e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.7431043, "y": 0.100000151, "z": -0.428273618}, "Rotation": {"x": 6.471919e-08, "y": 1.36603785e-05, "z": -1.18804758e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.8084887, "y": 0.100000262, "z": -0.428273529}, "Rotation": {"x": -4.48019533e-09, "y": 5.469234e-17, "z": -1.3988855e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.873873532, "y": 0.100000136, "z": -0.428273916}, "Rotation": {"x": 1.87053814e-07, "y": 4.09811364e-05, "z": -1.28535032e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.939258158, "y": 0.100000128, "z": -0.428273618}, "Rotation": {"x": 1.21495688e-07, "y": 1.36603785e-05, "z": -1.09358155e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.750268936, "y": 0.10000018, "z": -0.7444}, "Rotation": {"x": 8.062764e-07, "y": 2.9943214e-15, "z": 4.25566157e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.8156536, "y": 0.100000054, "z": -0.7444}, "Rotation": {"x": 9.930745e-07, "y": 3.88195932e-13, "z": -2.18262153e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.881038, "y": 0.100000165, "z": -0.7443998}, "Rotation": {"x": 9.890075e-07, "y": 3.8852683e-13, "z": -2.15326054e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.9464227, "y": 0.100000039, "z": -0.7443998}, "Rotation": {"x": 9.45008651e-07, "y": 1.36603785e-05, "z": 4.11411833e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.625069, "y": 0.100000136, "z": -0.809376836}, "Rotation": {"x": -4.08450717e-07, "y": 6.83018952e-05, "z": -8.65594757e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.559686244, "y": 0.100000143, "z": -0.809377134}, "Rotation": {"x": 1.17435981e-07, "y": 4.09811364e-05, "z": -7.109428e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.494301647, "y": 0.10000027, "z": -0.809376836}, "Rotation": {"x": 7.891975e-07, "y": 1.36603785e-05, "z": -3.49014528e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.4289167, "y": 0.100000158, "z": -0.809376836}, "Rotation": {"x": -4.36923955e-07, "y": 6.83018952e-05, "z": 5.426494e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3384615, "y": 0.100000128, "z": -0.18849948}, "Rotation": {"x": -8.72855139e-07, "y": -0.000232226434, "z": -3.63481576e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.338461518, "y": 0.100000136, "z": -0.260246515}, "Rotation": {"x": -3.21443224e-07, "y": 1.76873206e-15, "z": -6.30536761e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.443052858, "y": 0.099999994, "z": -0.2979046}, "Rotation": {"x": -5.07656e-07, "y": -4.09811364e-05, "z": -1.778798e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.5084374, "y": 0.100000106, "z": -0.2979042}, "Rotation": {"x": 4.5308667e-08, "y": -5.528934e-16, "z": -1.39834e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.4156479, "y": 0.100000106, "z": -0.553855}, "Rotation": {"x": -1.92510061e-06, "y": -4.019903e-13, "z": -3.04810527e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3502634, "y": 0.100000113, "z": -0.5538549}, "Rotation": {"x": -1.72456475e-06, "y": 1.36603785e-05, "z": -4.504669e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.2848788, "y": 0.10000024, "z": -0.5538547}, "Rotation": {"x": -8.488211e-07, "y": 1.07806906e-14, "z": -1.4554023e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.219494149, "y": 0.100000247, "z": -0.5538547}, "Rotation": {"x": -9.036166e-07, "y": 1.36603785e-05, "z": -9.16257136e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.35368675, "y": 0.1, "z": -0.8709405}, "Rotation": {"x": -8.47634453e-07, "y": 2.7320757e-05, "z": 1.23319762e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.2883023, "y": 0.100000247, "z": -0.8709408}, "Rotation": {"x": -1.57109156e-07, "y": 4.09811364e-05, "z": 9.718927e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.2229177, "y": 0.100000136, "z": -0.8709405}, "Rotation": {"x": -2.45614331e-07, "y": 1.36603785e-05, "z": -5.303256e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.157533258, "y": 0.100000262, "z": -0.8709408}, "Rotation": {"x": -2.99975227e-07, "y": 2.84417549e-15, "z": -1.08648487e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.07986431, "y": 0.100000255, "z": -0.7465019}, "Rotation": {"x": 1.10500923e-06, "y": 4.06253617e-13, "z": -8.891141e-08}, "Tags": ["spy"]}, {"Position": {"x": 0.0144797442, "y": 0.100000143, "z": -0.746502042}, "Rotation": {"x": 1.36230472e-06, "y": 2.7320757e-05, "z": -1.14112208e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.0509049, "y": 0.100000151, "z": -0.746502042}, "Rotation": {"x": 1.8136227e-06, "y": 3.73348325e-13, "z": -2.13325347e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.1162895, "y": 0.100000158, "z": -0.7465019}, "Rotation": {"x": 2.20334573e-06, "y": 8.032488e-13, "z": -5.706931e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.274112552, "y": 0.10000021, "z": -0.5279073}, "Rotation": {"x": 8.154738e-07, "y": -2.7320757e-05, "z": 1.25010411e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.339497149, "y": 0.100000218, "z": -0.5279074}, "Rotation": {"x": 1.07793778e-06, "y": 1.14264821e-14, "z": 1.21470691e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.4048819, "y": 0.100000225, "z": -0.527907252}, "Rotation": {"x": 4.301153e-07, "y": -2.7320757e-05, "z": -1.87476269e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.470266432, "y": 0.100000232, "z": -0.527907}, "Rotation": {"x": 1.225917e-06, "y": 1.2156655e-14, "z": 1.13633314e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.0532106534, "y": 0.100000128, "z": -0.298076332}, "Rotation": {"x": 1.07926809e-07, "y": 2.7320757e-05, "z": -5.685484e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.118595228, "y": 0.100000255, "z": -0.298075885}, "Rotation": {"x": 2.79777282e-07, "y": -1.82126462e-15, "z": -7.45956e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.169230759, "y": 0.100000218, "z": -0.241916433}, "Rotation": {"x": 2.52706e-07, "y": 1.1022228e-15, "z": 4.998118e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.169230774, "y": 0.100000091, "z": -0.171802089}, "Rotation": {"x": -9.01983242e-07, "y": 0.00133871706, "z": -3.37435523e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.3320212, "y": 0.100000143, "z": -0.3049357}, "Rotation": {"x": -1.16054161e-06, "y": -3.31234415e-15, "z": 3.27059951e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.397405922, "y": 0.100000151, "z": -0.3049354}, "Rotation": {"x": -6.967085e-07, "y": 4.09811364e-05, "z": -1.0637347e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.4627906, "y": 0.100000277, "z": -0.304935247}, "Rotation": {"x": -1.201822e-06, "y": 1.36603785e-05, "z": -3.73949518e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.478181, "y": 0.100000151, "z": -0.240965128}, "Rotation": {"x": 5.154046e-07, "y": 3.9728946e-13, "z": -2.18365722e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.9212581, "y": 0.100000143, "z": 0.206158131}, "Rotation": {"x": 3.228777e-08, "y": -4.09811364e-05, "z": 7.06543858e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.8615476, "y": 0.100000143, "z": 0.206158116}, "Rotation": {"x": 2.074457e-06, "y": 0.000491773651, "z": -1.24352016e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.8018371, "y": 0.100000143, "z": 0.206158116}, "Rotation": {"x": -2.2074633e-07, "y": 0.000491773651, "z": 2.57477637e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.7421266, "y": 0.100000143, "z": 0.206158116}, "Rotation": {"x": 2.00288878e-06, "y": 0.000491773651, "z": -1.35349194e-06}, "Tags": ["spy"]}]}, "4": {"GUID": "1d1f42", "Name": "Custom_Tile", "Transform": {"posX": 0.0, "posY": 1.48, "posZ": 11.0, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 26.0, "scaleY": 1.0, "scaleZ": 26.0}, "Nickname": "", "Description": "Board", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 0.249999732, "g": 0.249999732, "b": 0.249999732}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": false, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "CustomImage": {"ImageURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669803203/1BD4837CAB47318CDF5B6295E0FDAD519E02FDE2/", "ImageSecondaryURL": "", "ImageScalar": 1.0, "WidthScale": 0.0, "CustomTile": {"Type": 0, "Thickness": 0.1, "Stackable": false, "Stretch": true}}, "LuaScript": "", "LuaScriptState": "", "XmlUI": "", "AttachedSnapPoints": [{"Position": {"x": -0.7864208, "y": 0.10000018, "z": 0.9117383}, "Rotation": {"x": -7.422351e-07, "y": 9.562265e-05, "z": -1.0514762e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.735491037, "y": 0.100000195, "z": 0.912634}, "Rotation": {"x": 3.88524626e-08, "y": 5.4641514e-05, "z": -2.24678018e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.6856307, "y": 0.100000195, "z": 0.9134566}, "Rotation": {"x": -7.17299542e-07, "y": 6.83018952e-05, "z": 1.04794829e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.570649266, "y": 0.100000165, "z": 0.6854273}, "Rotation": {"x": -7.806583e-07, "y": 4.09811364e-05, "z": 5.140807e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.519162834, "y": 0.100000128, "z": 0.5845996}, "Rotation": {"x": -7.133285e-07, "y": 5.4641514e-05, "z": -1.40894954e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.8168376, "y": 0.100000151, "z": 0.521683633}, "Rotation": {"x": -6.90973e-08, "y": 6.83018952e-05, "z": -2.95064325e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.841161549, "y": 0.100000143, "z": 0.331315577}, "Rotation": {"x": 1.4323696e-07, "y": 5.4641514e-05, "z": -3.08363724e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.7907183, "y": 0.100000143, "z": 0.330776125}, "Rotation": {"x": -3.04621e-07, "y": 5.4641514e-05, "z": -1.16526707e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.7402755, "y": 0.100000031, "z": 0.331444472}, "Rotation": {"x": 9.398122e-08, "y": 4.09811364e-05, "z": -2.532328e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.8411778, "y": 0.100000069, "z": 0.285930842}, "Rotation": {"x": -1.78739668e-07, "y": 6.83018952e-05, "z": -1.415526e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.7911939, "y": 0.100000069, "z": 0.287287116}, "Rotation": {"x": -1.04140861e-06, "y": -1.09651009e-15, "z": 1.20654676e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.740591049, "y": 0.100000195, "z": 0.287277043}, "Rotation": {"x": -2.02042628e-07, "y": 4.09811364e-05, "z": -1.35727632e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.6170323, "y": 0.10000018, "z": 0.319588244}, "Rotation": {"x": -1.19818253e-07, "y": 5.4641514e-05, "z": -1.53713771e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.813742638, "y": 0.100000113, "z": 0.0557061248}, "Rotation": {"x": -4.24742375e-08, "y": 4.09811364e-05, "z": -3.44943544e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.591206849, "y": 0.1000001, "z": 0.0201389268}, "Rotation": {"x": -5.39291534e-07, "y": 8.196227e-05, "z": -4.97568237e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.70169425, "y": 0.100000188, "z": -0.098841846}, "Rotation": {"x": 5.78692578e-08, "y": 4.09811364e-05, "z": -3.29860853e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.6517009, "y": 0.100000069, "z": -0.09852364}, "Rotation": {"x": -4.735075e-07, "y": 5.4641514e-05, "z": -3.1336333e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.527168155, "y": 0.100000247, "z": -0.09974597}, "Rotation": {"x": -6.79776463e-07, "y": 5.4641514e-05, "z": 3.63090926e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.851576447, "y": 0.100000262, "z": -0.197851777}, "Rotation": {"x": -1.39737679e-07, "y": 8.196227e-05, "z": -5.824147e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.7119696, "y": 0.100000143, "z": -0.297436953}, "Rotation": {"x": -1.03465572e-06, "y": 4.09811364e-05, "z": -1.89913574e-09}, "Tags": ["troop"]}, {"Position": {"x": -0.8486088, "y": 0.100000106, "z": -0.448542565}, "Rotation": {"x": -7.69161147e-07, "y": 5.4641514e-05, "z": -2.07999889e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.7984449, "y": 0.100000106, "z": -0.448385179}, "Rotation": {"x": 1.06260076e-08, "y": 0.000245886826, "z": -5.2643037e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.749110758, "y": 0.1000001, "z": -0.4486677}, "Rotation": {"x": -3.519749e-07, "y": 6.83018952e-05, "z": -3.71453183e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.552609, "y": 0.100000165, "z": -0.6141708}, "Rotation": {"x": 1.78124111e-07, "y": -4.09811364e-05, "z": -5.108804e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.567288458, "y": 0.100000091, "z": -0.740332544}, "Rotation": {"x": 1.48347652e-07, "y": 4.09811364e-05, "z": -2.43155966e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.518004239, "y": 0.100000083, "z": -0.7410103}, "Rotation": {"x": 2.2572101e-07, "y": -3.333013e-16, "z": -1.69206729e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.5923452, "y": 0.09999995, "z": -0.7853574}, "Rotation": {"x": -1.26031779e-07, "y": 0.000177584923, "z": 5.80468452e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.5432279, "y": 0.100000069, "z": -0.7853322}, "Rotation": {"x": 4.4098134e-09, "y": -2.7320757e-05, "z": -2.17560114e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.493798077, "y": 0.10000018, "z": -0.784753442}, "Rotation": {"x": -3.80784343e-07, "y": 4.09811364e-05, "z": 2.57473147e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.39632684, "y": 0.100000083, "z": -0.6898959}, "Rotation": {"x": 4.52714843e-08, "y": 9.562265e-05, "z": -1.9003123e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.106956236, "y": 0.100000083, "z": 0.9311196}, "Rotation": {"x": 5.678063e-08, "y": 4.09811364e-05, "z": -1.84019029e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.05655723, "y": 0.100000091, "z": 0.930653751}, "Rotation": {"x": -3.35092864e-07, "y": 5.4641514e-05, "z": -1.23060047e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.005892145, "y": 0.10000021, "z": 0.931565166}, "Rotation": {"x": 1.83083856e-07, "y": 5.4641514e-05, "z": -8.554557e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.1310636, "y": 0.100000083, "z": 0.836117}, "Rotation": {"x": -2.43584225e-07, "y": 6.83018952e-05, "z": -3.359286e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.220454887, "y": 0.100000158, "z": 0.9265943}, "Rotation": {"x": 7.995073e-09, "y": 5.4641514e-05, "z": -2.1241587e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.3570165, "y": 0.100000188, "z": 0.8557662}, "Rotation": {"x": 5.4954775e-08, "y": 6.83018952e-05, "z": -5.073384e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4076918, "y": 0.100000195, "z": 0.855804145}, "Rotation": {"x": 4.323053e-08, "y": 5.4641514e-05, "z": -1.955191e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.455930859, "y": 0.100000069, "z": 0.8563245}, "Rotation": {"x": -3.65879146e-07, "y": 5.4641514e-05, "z": -3.76916574e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.294736832, "y": 0.100000061, "z": 0.6875983}, "Rotation": {"x": -5.76576e-07, "y": 4.09811364e-05, "z": -1.51230537e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.426977783, "y": 0.100000128, "z": 0.659239}, "Rotation": {"x": -3.47279538e-08, "y": 5.4641514e-05, "z": -3.21477671e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.231832713, "y": 0.100000113, "z": 0.563093}, "Rotation": {"x": -2.76775971e-08, "y": 5.4641514e-05, "z": -3.48317684e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.000627097266, "y": 0.100000091, "z": 0.539936841}, "Rotation": {"x": -3.14919873e-07, "y": 4.09811364e-05, "z": -3.3873377e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.05126633, "y": 0.100000091, "z": 0.5403133}, "Rotation": {"x": 6.54188952e-08, "y": 5.4641514e-05, "z": -2.29099243e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.1006845, "y": 0.10000021, "z": 0.539888263}, "Rotation": {"x": -4.48709415e-07, "y": 5.4641514e-05, "z": -1.02727348e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.176813409, "y": 0.100000091, "z": 0.5147679}, "Rotation": {"x": 5.07998621e-08, "y": 8.196227e-05, "z": -1.47892e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.277509481, "y": 0.100000188, "z": 0.6496129}, "Rotation": {"x": -1.25558671e-07, "y": 4.09811364e-05, "z": -2.79818835e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.305141658, "y": 0.100000121, "z": 0.5154639}, "Rotation": {"x": 9.68804557e-08, "y": 5.4641514e-05, "z": -3.50781448e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.3533314, "y": 0.100000136, "z": 0.5160048}, "Rotation": {"x": -2.27904273e-08, "y": 4.09811364e-05, "z": -2.666333e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.325868666, "y": 0.100000106, "z": 0.380166829}, "Rotation": {"x": 1.033606e-07, "y": 6.83018952e-05, "z": -2.227597e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.385574728, "y": 0.100000039, "z": 0.3103113}, "Rotation": {"x": -2.53059937e-07, "y": 5.4641514e-05, "z": -3.85456076e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.245713383, "y": 0.100000188, "z": 0.227346554}, "Rotation": {"x": -3.685041e-08, "y": 4.09811364e-05, "z": -2.65311e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.004653071, "y": 0.100000054, "z": 0.396768451}, "Rotation": {"x": -4.912758e-07, "y": 5.4641514e-05, "z": -2.23376e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.404302329, "y": 0.1, "z": 0.468289375}, "Rotation": {"x": -7.237965e-07, "y": 4.09811364e-05, "z": -7.71364e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.453679562, "y": 0.1, "z": 0.467526436}, "Rotation": {"x": 1.86696866e-07, "y": 5.4641514e-05, "z": -3.842655e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.379435629, "y": 0.100000113, "z": 0.423960537}, "Rotation": {"x": -3.25228228e-07, "y": 8.196227e-05, "z": -7.834468e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.429628, "y": 0.099999994, "z": 0.42416054}, "Rotation": {"x": 7.605476e-09, "y": 5.4641514e-05, "z": -2.6035562e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4780354, "y": 0.1000001, "z": 0.423820972}, "Rotation": {"x": -8.031034e-07, "y": 5.4641514e-05, "z": -7.33406154e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.405386925, "y": 0.10000018, "z": 0.277246684}, "Rotation": {"x": -7.459923e-07, "y": 5.4641514e-05, "z": -3.42660211e-09}, "Tags": ["troop"]}, {"Position": {"x": 0.429525, "y": 0.100000031, "z": 0.155497536}, "Rotation": {"x": 1.16170739e-07, "y": 6.83018952e-05, "z": -1.81467229e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.00134328054, "y": 0.100000061, "z": 0.306656778}, "Rotation": {"x": 6.847061e-08, "y": 5.4641514e-05, "z": -2.75814415e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.0481604822, "y": 0.100000069, "z": 0.305874765}, "Rotation": {"x": -7.69572e-07, "y": 5.4641514e-05, "z": 5.752573e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.04823315, "y": 0.100000113, "z": 0.2607574}, "Rotation": {"x": 3.46521176e-08, "y": 4.09811364e-05, "z": -1.78962722e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.00213938113, "y": 0.100000113, "z": 0.2603982}, "Rotation": {"x": 2.79264185e-08, "y": 5.4641514e-05, "z": -2.27702046e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.405867159, "y": 0.1000002, "z": 0.2090352}, "Rotation": {"x": 1.38716388e-07, "y": 5.4641514e-05, "z": -2.682177e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.4564721, "y": 0.100000188, "z": 0.208606}, "Rotation": {"x": -2.41477636e-07, "y": 4.09811364e-05, "z": -3.70181226e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.455088079, "y": 0.100000136, "z": 0.164117068}, "Rotation": {"x": -4.866614e-07, "y": 8.196227e-05, "z": -4.41588632e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.406595528, "y": 0.1, "z": 0.164322123}, "Rotation": {"x": 2.007004e-08, "y": 5.4641514e-05, "z": -5.414088e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.158630043, "y": 0.10000018, "z": 0.125336081}, "Rotation": {"x": -6.90606953e-07, "y": 4.09811364e-05, "z": -2.7637978e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.229710743, "y": 0.100000188, "z": 0.0410436131}, "Rotation": {"x": 2.76361671e-08, "y": 5.4641514e-05, "z": -3.56568961e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.369862348, "y": 0.100000262, "z": 0.05465671}, "Rotation": {"x": -2.159071e-08, "y": 6.83018952e-05, "z": -2.82054685e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4190495, "y": 0.0999999046, "z": 0.0543358438}, "Rotation": {"x": 4.92904135e-08, "y": 5.4641514e-05, "z": -4.300786e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.469230354, "y": 0.0999999046, "z": 0.05521932}, "Rotation": {"x": -7.84846463e-07, "y": 8.196227e-05, "z": 6.982712e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.07829274, "y": 0.100000292, "z": -0.07845683}, "Rotation": {"x": 1.07429734e-07, "y": 4.09811364e-05, "z": -3.08111339e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.401256561, "y": 0.100000151, "z": -0.08286511}, "Rotation": {"x": -1.165478e-06, "y": 0.000109283028, "z": 1.37846683e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.335542977, "y": 0.100000173, "z": -0.110677242}, "Rotation": {"x": 1.29428386e-07, "y": 4.09811364e-05, "z": -2.81193138e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.3579095, "y": 0.100000083, "z": 0.00298474822}, "Rotation": {"x": -8.989771e-09, "y": 4.09811364e-05, "z": -2.587451e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.395151258, "y": 0.10000027, "z": -0.2267869}, "Rotation": {"x": -5.77262369e-07, "y": 6.83018952e-05, "z": -3.09254915e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.34555766, "y": 0.100000262, "z": -0.227018744}, "Rotation": {"x": 1.59392783e-07, "y": 8.196227e-05, "z": -4.72505945e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.06869899, "y": 0.100000158, "z": -0.199770913}, "Rotation": {"x": -7.91047e-07, "y": 4.09811364e-05, "z": -1.80930186e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.0881706253, "y": 0.100000143, "z": -0.2373622}, "Rotation": {"x": -4.73386166e-08, "y": 5.4641514e-05, "z": -3.55263e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.226863042, "y": 0.100000121, "z": -0.206166074}, "Rotation": {"x": 1.10812142e-08, "y": 4.09811364e-05, "z": -3.74568174e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.420987457, "y": 0.100000247, "z": -0.1809664}, "Rotation": {"x": -4.33666656e-07, "y": 6.83018952e-05, "z": -2.14196e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4704384, "y": 0.09999988, "z": -0.18121843}, "Rotation": {"x": -5.13217842e-08, "y": 5.4641514e-05, "z": -3.776932e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.4220026, "y": 0.100000061, "z": -0.226003557}, "Rotation": {"x": -1.84460325e-09, "y": 6.83018952e-05, "z": -2.8417162e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.470707327, "y": 0.100000046, "z": -0.226329014}, "Rotation": {"x": -9.18720744e-08, "y": 5.4641514e-05, "z": -4.18205644e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.381316453, "y": 0.100000158, "z": -0.344041377}, "Rotation": {"x": 1.5743791e-07, "y": 9.562265e-05, "z": -2.00137265e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.357775956, "y": 0.100000083, "z": -0.4357368}, "Rotation": {"x": -2.7842313e-07, "y": 4.09811364e-05, "z": -2.51146872e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.3072332, "y": 0.100000076, "z": -0.4352719}, "Rotation": {"x": -3.31464411e-09, "y": 4.09811364e-05, "z": -2.397607e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.282465667, "y": 0.10000018, "z": -0.4805707}, "Rotation": {"x": -3.55464351e-08, "y": 4.09811364e-05, "z": -2.18146354e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.332543582, "y": 0.09999994, "z": -0.479849815}, "Rotation": {"x": 1.08149774e-08, "y": 6.83018952e-05, "z": -4.861492e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.384280264, "y": 0.09999996, "z": -0.480288923}, "Rotation": {"x": 7.296329e-08, "y": 6.83018952e-05, "z": -3.65225731e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.138906941, "y": 0.100000076, "z": -0.3571349}, "Rotation": {"x": -1.17491815e-07, "y": 6.83018952e-05, "z": -2.853865e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.121766359, "y": 0.100000076, "z": -0.493198842}, "Rotation": {"x": 2.04398738e-08, "y": 4.09811364e-05, "z": -1.8048533e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.143243179, "y": 0.100000136, "z": -0.626665}, "Rotation": {"x": -5.24954977e-08, "y": 5.4641514e-05, "z": -3.062289e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.284010142, "y": 0.100000128, "z": -0.665755451}, "Rotation": {"x": -2.43994378e-07, "y": 4.09811364e-05, "z": -4.87693057e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.3113752, "y": 0.099999994, "z": -0.792696}, "Rotation": {"x": -4.778215e-08, "y": 4.09811364e-05, "z": -3.952462e-07}, "Tags": ["troop"]}, {"Position": {"x": 0.261276841, "y": 0.100000113, "z": -0.7918057}, "Rotation": {"x": -6.7009637e-07, "y": 5.4641514e-05, "z": -6.251466e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.0478779748, "y": 0.100000307, "z": -0.6823796}, "Rotation": {"x": -1.13848529e-07, "y": 4.09811364e-05, "z": -3.16787776e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.00182310957, "y": 0.100000188, "z": -0.682990849}, "Rotation": {"x": -2.19775287e-09, "y": 5.4641514e-05, "z": -2.83826381e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.0535315461, "y": 0.100000173, "z": -0.6825084}, "Rotation": {"x": -5.92172341e-07, "y": 5.4641514e-05, "z": -2.22497132e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.05271411, "y": 0.100000016, "z": -0.638223052}, "Rotation": {"x": 1.22585021e-07, "y": 5.4641514e-05, "z": -2.76540675e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.00135535782, "y": 0.100000151, "z": -0.6379968}, "Rotation": {"x": 1.943802e-07, "y": 5.4641514e-05, "z": 7.007041e-08}, "Tags": ["troop"]}, {"Position": {"x": 0.0490297675, "y": 0.100000031, "z": -0.6386673}, "Rotation": {"x": 8.81251054e-08, "y": 5.4641514e-05, "z": -1.802394e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.0388980471, "y": 0.100000225, "z": -0.502511442}, "Rotation": {"x": -4.59199242e-07, "y": 5.4641514e-05, "z": -8.601463e-08}, "Tags": ["troop"]}, {"Position": {"x": -0.0404235274, "y": 0.100000061, "z": -0.3794196}, "Rotation": {"x": 1.19212924e-08, "y": 5.4641514e-05, "z": -4.58157842e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.252658546, "y": 0.100000173, "z": -0.3293708}, "Rotation": {"x": 1.00608382e-07, "y": 5.4641514e-05, "z": -3.8066176e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.412008882, "y": 0.100000151, "z": -0.369046569}, "Rotation": {"x": 9.42578353e-08, "y": 5.4641514e-05, "z": -2.38599569e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.369120747, "y": 0.100000069, "z": -0.45999974}, "Rotation": {"x": -1.83162615e-06, "y": 1.36603785e-05, "z": -1.78557471e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.3200154, "y": 0.100000069, "z": -0.4599998}, "Rotation": {"x": 1.9296111e-07, "y": 6.83018952e-05, "z": -1.22664323e-06}, "Tags": ["troop"]}, {"Position": {"x": -0.271154135, "y": 0.10000018, "z": -0.459955037}, "Rotation": {"x": -9.925366e-07, "y": 4.09811364e-05, "z": -1.55565616e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.241680861, "y": 0.100000165, "z": -0.5932392}, "Rotation": {"x": -9.798289e-07, "y": 4.09811364e-05, "z": -2.62157045e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.1949771, "y": 0.100000069, "z": -0.708090663}, "Rotation": {"x": 7.466929e-08, "y": 5.4641514e-05, "z": -2.96619419e-07}, "Tags": ["troop"]}, {"Position": {"x": -0.08049196, "y": 0.1000006, "z": 0.734508634}, "Rotation": {"x": 2.06513348e-10, "y": -0.00442596246, "z": -5.673507e-09}, "Tags": ["control"]}, {"Position": {"x": -0.0451759435, "y": 0.100000642, "z": 0.06579076}, "Rotation": {"x": 1.843012e-08, "y": 5.4641514e-05, "z": -1.6647574e-08}, "Tags": ["control"]}, {"Position": {"x": -0.8201211, "y": 0.100000404, "z": -0.640820146}, "Rotation": {"x": -6.83094736e-09, "y": -0.0006966793, "z": -1.06858087e-08}, "Tags": ["control"]}, {"Position": {"x": -0.0258299, "y": 0.100000367, "z": -0.874223053}, "Rotation": {"x": -3.7452363e-08, "y": -5.4641514e-05, "z": 1.76832913e-08}, "Tags": ["control"]}, {"Position": {"x": 0.48911953, "y": 0.100000113, "z": 0.7836856}, "Rotation": {"x": -5.14486146e-07, "y": 2.26427662e-15, "z": -5.043226e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.423734754, "y": 0.100000121, "z": 0.7836855}, "Rotation": {"x": -1.42310981e-07, "y": 2.7320757e-05, "z": -9.533074e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3583503, "y": 0.100000247, "z": 0.783685565}, "Rotation": {"x": -4.64145415e-07, "y": 1.78054415e-15, "z": -4.39593578e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.292965651, "y": 0.100000255, "z": 0.783685446}, "Rotation": {"x": -4.8696927e-07, "y": 2.58883084e-15, "z": -6.09192739e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.0219074152, "y": 0.099999994, "z": 0.8671818}, "Rotation": {"x": -1.396765e-07, "y": 6.792246e-16, "z": -5.572405e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.04368886, "y": 0.100000121, "z": 0.867181659}, "Rotation": {"x": 7.356413e-07, "y": 0.00394784939, "z": -3.48484463e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.109707713, "y": 0.10000024, "z": 0.8671817}, "Rotation": {"x": 2.83693026e-07, "y": 0.016091926, "z": -3.170495e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.174552247, "y": 0.100000136, "z": 0.8671817}, "Rotation": {"x": 1.959943e-07, "y": 0.03173308, "z": -6.63904643e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.656055331, "y": 0.09999999, "z": 0.848656}, "Rotation": {"x": -3.40793576e-07, "y": 3.0308408e-15, "z": -1.01911769e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.721439838, "y": 0.100000113, "z": 0.8486559}, "Rotation": {"x": 1.65591359e-07, "y": 1.36603785e-05, "z": -8.87224942e-08}, "Tags": ["spy"]}, {"Position": {"x": -0.786824644, "y": 0.10000024, "z": 0.848656}, "Rotation": {"x": -4.78484253e-07, "y": 6.031042e-15, "z": -1.44436638e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.8522092, "y": 0.100000009, "z": 0.848656}, "Rotation": {"x": 6.479253e-08, "y": -4.12867549e-17, "z": -7.301943e-08}, "Tags": ["spy"]}, {"Position": {"x": -0.263131827, "y": 0.10000027, "z": 0.446059972}, "Rotation": {"x": -1.09762277e-06, "y": 3.4637424e-15, "z": -3.616139e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.328516454, "y": 0.100000277, "z": 0.446059972}, "Rotation": {"x": -8.24513165e-07, "y": 2.7320757e-05, "z": -4.97279757e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.459285676, "y": 0.0999999344, "z": 0.446059972}, "Rotation": {"x": -8.176792e-07, "y": 4.551755e-16, "z": -6.378941e-08}, "Tags": ["spy"]}, {"Position": {"x": -0.39390108, "y": 0.100000165, "z": 0.446059972}, "Rotation": {"x": -3.65982373e-07, "y": 1.5213167e-15, "z": -4.7633452e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.0697782561, "y": 0.100000151, "z": 0.47151342}, "Rotation": {"x": -6.70487964e-07, "y": 1.15246049e-14, "z": -1.96964379e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.00439362926, "y": 0.100000143, "z": 0.47151342}, "Rotation": {"x": -5.104154e-07, "y": 5.24365646e-16, "z": -1.17723474e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.0609910265, "y": 0.100000255, "z": 0.4715135}, "Rotation": {"x": 1.50064253e-07, "y": 1.36603785e-05, "z": -7.08555547e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.126375675, "y": 0.100000247, "z": 0.4715135}, "Rotation": {"x": -1.41785893e-06, "y": -4.093468e-15, "z": 3.308347e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.307667345, "y": 0.100000031, "z": 0.347549736}, "Rotation": {"x": 1.67485084e-07, "y": -6.53829444e-16, "z": -4.47343353e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3730519, "y": 0.100000143, "z": 0.347549736}, "Rotation": {"x": 4.18110773e-07, "y": -1.45489926e-15, "z": -3.98744049e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.438436568, "y": 0.100000136, "z": 0.3475498}, "Rotation": {"x": -1.98596638e-07, "y": 2.7320757e-05, "z": -1.28494651e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.503821254, "y": 0.100000128, "z": 0.347549736}, "Rotation": {"x": -3.125423e-07, "y": 2.30239479e-15, "z": -8.441577e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.919649, "y": 0.100000195, "z": 0.208966464}, "Rotation": {"x": -4.50410681e-07, "y": 1.36603785e-05, "z": -7.770561e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.854264438, "y": 0.100000061, "z": 0.208966389}, "Rotation": {"x": -1.77239951e-06, "y": -3.966704e-13, "z": -6.75019351e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.788879633, "y": 0.100000173, "z": 0.208966389}, "Rotation": {"x": -8.323891e-07, "y": 4.09811364e-05, "z": -6.004858e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.7234951, "y": 0.100000165, "z": 0.208966464}, "Rotation": {"x": 3.61953084e-07, "y": -2.50165633e-15, "z": -7.92005153e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.5400126, "y": 0.1000001, "z": 0.0876253}, "Rotation": {"x": 5.242067e-07, "y": -2.58057778e-15, "z": -5.641142e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.4746278, "y": 0.100000091, "z": 0.0876253}, "Rotation": {"x": -1.84650776e-06, "y": -4.19471044e-13, "z": 7.67044355e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.4092435, "y": 0.100000083, "z": 0.08762546}, "Rotation": {"x": -3.518949e-07, "y": 1.36603785e-05, "z": -6.57227e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.3438586, "y": 0.100000076, "z": 0.08762551}, "Rotation": {"x": 6.25037657e-08, "y": -1.93645218e-16, "z": -3.55020347e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.143322065, "y": 0.100000143, "z": 0.197700158}, "Rotation": {"x": -5.67118263e-07, "y": 3.35676023e-15, "z": -6.782648e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.07793727, "y": 0.100000016, "z": 0.1977001}, "Rotation": {"x": -2.790247e-07, "y": 1.87918177e-15, "z": -7.71753832e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.0125529561, "y": 0.100000009, "z": 0.197700068}, "Rotation": {"x": 5.82769758e-07, "y": 2.7320757e-05, "z": 7.247457e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.0528316461, "y": 0.100000121, "z": 0.197700128}, "Rotation": {"x": -1.76232035e-07, "y": 2.670425e-16, "z": -1.7363935e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.302057564, "y": 0.100000136, "z": -0.0177875031}, "Rotation": {"x": -1.11165161e-06, "y": 6.57609656e-15, "z": -6.778789e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.367442131, "y": 0.100000009, "z": -0.01778735}, "Rotation": {"x": -5.4996093e-07, "y": 5.975455e-15, "z": -1.24506437e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.432826757, "y": 0.100000121, "z": -0.0177874174}, "Rotation": {"x": -5.76111461e-07, "y": 2.7320757e-05, "z": -1.3192531e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.498211354, "y": 0.100000113, "z": -0.01778734}, "Rotation": {"x": -3.713536e-07, "y": 2.521561e-15, "z": -7.7809824e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3384615, "y": 0.100000128, "z": -0.18849948}, "Rotation": {"x": -8.72855139e-07, "y": -0.000232226434, "z": -3.63481576e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.338461518, "y": 0.100000136, "z": -0.260246515}, "Rotation": {"x": -3.21443224e-07, "y": 1.76873206e-15, "z": -6.30536761e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.443052858, "y": 0.099999994, "z": -0.2979046}, "Rotation": {"x": -5.07656e-07, "y": -4.09811364e-05, "z": -1.778798e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.5084374, "y": 0.100000106, "z": -0.2979042}, "Rotation": {"x": 4.5308667e-08, "y": -5.528934e-16, "z": -1.39834e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.4156479, "y": 0.100000106, "z": -0.553855}, "Rotation": {"x": -1.92510061e-06, "y": -4.019903e-13, "z": -3.04810527e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.3502634, "y": 0.100000113, "z": -0.5538549}, "Rotation": {"x": -1.72456475e-06, "y": 1.36603785e-05, "z": -4.504669e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.2848788, "y": 0.10000024, "z": -0.5538547}, "Rotation": {"x": -8.488211e-07, "y": 1.07806906e-14, "z": -1.4554023e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.219494149, "y": 0.100000247, "z": -0.5538547}, "Rotation": {"x": -9.036166e-07, "y": 1.36603785e-05, "z": -9.16257136e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.35368675, "y": 0.1, "z": -0.8709405}, "Rotation": {"x": -8.47634453e-07, "y": 2.7320757e-05, "z": 1.23319762e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.2883023, "y": 0.100000247, "z": -0.8709408}, "Rotation": {"x": -1.57109156e-07, "y": 4.09811364e-05, "z": 9.718927e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.2229177, "y": 0.100000136, "z": -0.8709405}, "Rotation": {"x": -2.45614331e-07, "y": 1.36603785e-05, "z": -5.303256e-07}, "Tags": ["spy"]}, {"Position": {"x": 0.157533258, "y": 0.100000262, "z": -0.8709408}, "Rotation": {"x": -2.99975227e-07, "y": 2.84417549e-15, "z": -1.08648487e-06}, "Tags": ["spy"]}, {"Position": {"x": 0.07986431, "y": 0.100000255, "z": -0.7465019}, "Rotation": {"x": 1.10500923e-06, "y": 4.06253617e-13, "z": -8.891141e-08}, "Tags": ["spy"]}, {"Position": {"x": 0.0144797442, "y": 0.100000143, "z": -0.746502042}, "Rotation": {"x": 1.36230472e-06, "y": 2.7320757e-05, "z": -1.14112208e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.0509049, "y": 0.100000151, "z": -0.746502042}, "Rotation": {"x": 1.8136227e-06, "y": 3.73348325e-13, "z": -2.13325347e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.1162895, "y": 0.100000158, "z": -0.7465019}, "Rotation": {"x": 2.20334573e-06, "y": 8.032488e-13, "z": -5.706931e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.274112552, "y": 0.10000021, "z": -0.5279073}, "Rotation": {"x": 8.154738e-07, "y": -2.7320757e-05, "z": 1.25010411e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.339497149, "y": 0.100000218, "z": -0.5279074}, "Rotation": {"x": 1.07793778e-06, "y": 1.14264821e-14, "z": 1.21470691e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.4048819, "y": 0.100000225, "z": -0.527907252}, "Rotation": {"x": 4.301153e-07, "y": -2.7320757e-05, "z": -1.87476269e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.470266432, "y": 0.100000232, "z": -0.527907}, "Rotation": {"x": 1.225917e-06, "y": 1.2156655e-14, "z": 1.13633314e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.0532106534, "y": 0.100000128, "z": -0.298076332}, "Rotation": {"x": 1.07926809e-07, "y": 2.7320757e-05, "z": -5.685484e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.118595228, "y": 0.100000255, "z": -0.298075885}, "Rotation": {"x": 2.79777282e-07, "y": -1.82126462e-15, "z": -7.45956e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.169230759, "y": 0.100000218, "z": -0.241916433}, "Rotation": {"x": 2.52706e-07, "y": 1.1022228e-15, "z": 4.998118e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.169230774, "y": 0.100000091, "z": -0.171802089}, "Rotation": {"x": -9.01983242e-07, "y": 0.00133871706, "z": -3.37435523e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.3320212, "y": 0.100000143, "z": -0.3049357}, "Rotation": {"x": -1.16054161e-06, "y": -3.31234415e-15, "z": 3.27059951e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.397405922, "y": 0.100000151, "z": -0.3049354}, "Rotation": {"x": -6.967085e-07, "y": 4.09811364e-05, "z": -1.0637347e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.4627906, "y": 0.100000277, "z": -0.304935247}, "Rotation": {"x": -1.201822e-06, "y": 1.36603785e-05, "z": -3.73949518e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.478181, "y": 0.100000151, "z": -0.240965128}, "Rotation": {"x": 5.154046e-07, "y": 3.9728946e-13, "z": -2.18365722e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.589483738, "y": 0.100000054, "z": -0.172540709}, "Rotation": {"x": -5.324382e-07, "y": -2.7320757e-05, "z": 1.07597934e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.6548682, "y": 0.10000018, "z": -0.17254056}, "Rotation": {"x": -1.12496923e-06, "y": -1.69132066e-15, "z": 1.72281233e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.72025305, "y": 0.100000195, "z": -0.172540531}, "Rotation": {"x": -6.4416497e-07, "y": -4.09811364e-05, "z": -4.94309063e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.7856377, "y": 0.1000002, "z": -0.172540471}, "Rotation": {"x": 5.32079136e-09, "y": 1.36603785e-05, "z": -6.52353037e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.719842, "y": 0.100000247, "z": -0.5161715}, "Rotation": {"x": -1.815563e-06, "y": -5.4641514e-05, "z": 8.12418534e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.785226643, "y": 0.100000255, "z": -0.516171634}, "Rotation": {"x": -1.35893413e-06, "y": -2.7320757e-05, "z": 1.02473132e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.8506112, "y": 0.100000262, "z": -0.516171336}, "Rotation": {"x": -9.61286e-07, "y": -6.83018952e-05, "z": 7.444861e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.9159957, "y": 0.10000027, "z": -0.516171634}, "Rotation": {"x": -1.81002179e-06, "y": 6.83018952e-05, "z": -1.35284722e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.460974842, "y": 0.10000024, "z": -0.866706431}, "Rotation": {"x": -5.67137448e-08, "y": 1.36603785e-05, "z": -8.17933255e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.5263594, "y": 0.100000247, "z": -0.866706431}, "Rotation": {"x": 6.14519e-07, "y": 5.4641514e-05, "z": -4.4613472e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.591744065, "y": 0.100000255, "z": -0.866706431}, "Rotation": {"x": 1.91792381e-07, "y": 4.09811364e-05, "z": -7.70617135e-07}, "Tags": ["spy"]}, {"Position": {"x": -0.6571283, "y": 0.100000381, "z": -0.8667067}, "Rotation": {"x": 2.474828e-07, "y": 5.4641514e-05, "z": -1.249917e-06}, "Tags": ["spy"]}, {"Position": {"x": -0.7565385, "y": 0.100000151, "z": 0.7249999}, "Rotation": {"x": 6.54151355e-09, "y": 359.9662, "z": -1.01503925e-08}, "Tags": ["control"]}]}}}]==]
standardBoardObjectJSON['fbdd4d'] = [==[{"GUID": "fbdd4d", "Name": "Custom_Tile", "Transform": {"posX": -21.4850674, "posY": 1.58000016, "posZ": 33.58164, "rotX": 1.16743344e-08, "rotY": 180.000015, "rotZ": 1.74164878e-08, "scaleX": 2.2, "scaleY": 1.0, "scaleZ": 2.2}, "Nickname": "Gauntlgrym Control Marker", "Description": "", "GMNotes": "1left", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 0.239212215, "g": 0.247055352, "b": 0.439212233}, "Tags": ["control"], "LayoutGroupSortIndex": 0, "Value": 0, "Locked": false, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": false, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "CustomImage": {"ImageURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669822529/476CA1D21A772F86656BF5D27EF93A71A8EC8A69/", "ImageSecondaryURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669822491/87911F1FEEF46D2B34AFFC66586D55BE791DF2AF/", "ImageScalar": 1.0, "WidthScale": 0.0, "CustomTile": {"Type": 2, "Thickness": 0.1, "Stackable": false, "Stretch": true}}, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['66ab70'] = [==[{"GUID": "66ab70", "Name": "Custom_Tile", "Transform": {"posX": -21.5507774, "posY": 1.58000016, "posZ": -6.468838, "rotX": 3.70158659e-08, "rotY": 180.000046, "rotZ": 1.99999057e-08, "scaleX": 2.2, "scaleY": 1.0, "scaleZ": 2.2}, "Nickname": "Ch'Chitl Control Marker", "Description": "", "GMNotes": "2left", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 0.239212215, "g": 0.247055352, "b": 0.439212233}, "Tags": ["control"], "LayoutGroupSortIndex": 0, "Value": 0, "Locked": false, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": false, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "CustomImage": {"ImageURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669822455/17AAA416646670EED41503603F0D4A3DB6F40DEF/", "ImageSecondaryURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669822420/DEE40391E0493169A3EB9982355B5CCFF81803A9/", "ImageScalar": 1.0, "WidthScale": 0.0, "CustomTile": {"Type": 2, "Thickness": 0.1, "Stackable": false, "Stretch": true}}, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['8c9a11'] = [==[{"GUID": "8c9a11", "Name": "Custom_Tile", "Transform": {"posX": 21.32315, "posY": 1.58000016, "posZ": 27.6613216, "rotX": -1.363372e-08, "rotY": 180.0, "rotZ": -1.59604046e-08, "scaleX": 2.2, "scaleY": 1.0, "scaleZ": 2.2}, "Nickname": "The Phaerlin Control Marker", "Description": "", "GMNotes": "1right", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 0.239212215, "g": 0.247055352, "b": 0.439212233}, "Tags": ["control"], "LayoutGroupSortIndex": 0, "Value": 0, "Locked": false, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": false, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "CustomImage": {"ImageURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669822681/B4598DB3116530C21FEDB1348C2A73CA31EB2CED/", "ImageSecondaryURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669822644/2CE152CB9EA431951457DD7BC75A47E8E09A7AD3/", "ImageScalar": 1.0, "WidthScale": 0.0, "CustomTile": {"Type": 2, "Thickness": 0.1, "Stackable": false, "Stretch": true}}, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['b993de'] = [==[{"GUID": "b993de", "Name": "Custom_Tile", "Transform": {"posX": 19.6699982, "posY": 1.58000016, "posZ": -7.84996462, "rotX": -4.338061e-10, "rotY": 179.999908, "rotZ": 3.40561e-09, "scaleX": 2.2, "scaleY": 1.0, "scaleZ": 2.2}, "Nickname": "Ss'zuraass'nee Control Marker", "Description": "", "GMNotes": "2right", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 0.239212215, "g": 0.247055352, "b": 0.439212233}, "Tags": ["control"], "LayoutGroupSortIndex": 0, "Value": 0, "Locked": false, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": false, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "CustomImage": {"ImageURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669822746/65102C87C90653275135A4762267FB08D496E658/", "ImageSecondaryURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669822716/E499E916BD6D6C2ED3E84B5AF49FE25209EBC93B/", "ImageScalar": 1.0, "WidthScale": 0.0, "CustomTile": {"Type": 2, "Thickness": 0.1, "Stackable": false, "Stretch": true}}, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['dd834c'] = [==[{"GUID": "dd834c", "Name": "Custom_Tile", "Transform": {"posX": 0.6715663, "posY": 1.58000016, "posZ": 33.7297974, "rotX": 3.689622e-09, "rotY": 180.0, "rotZ": 2.04031814e-08, "scaleX": 2.2, "scaleY": 1.0, "scaleZ": 2.2}, "Nickname": "Menzoberranzan Control Marker", "Description": "", "GMNotes": "1center", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 0.239212215, "g": 0.247055352, "b": 0.439212233}, "Tags": ["control"], "LayoutGroupSortIndex": 0, "Value": 0, "Locked": false, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": false, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "CustomImage": {"ImageURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669822603/15DED5603C1C11BED7178A4AB0C2ED99EE8ED73E/", "ImageSecondaryURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669822566/DFD4ABAF7944E6C2827303D00BC650CF5D214967/", "ImageScalar": 1.0, "WidthScale": 0.0, "CustomTile": {"Type": 2, "Thickness": 0.1, "Stackable": false, "Stretch": true}}, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['2a2981'] = [==[{"GUID": "2a2981", "Name": "Custom_Tile", "Transform": {"posX": 1.17450655, "posY": 1.58000016, "posZ": 9.289549, "rotX": 9.867827e-09, "rotY": 180.0001, "rotZ": -1.05309228e-08, "scaleX": 2.2, "scaleY": 1.0, "scaleZ": 2.2}, "Nickname": "Araumycos Control Marker", "Description": "", "GMNotes": "2center", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 0.239212215, "g": 0.247055352, "b": 0.439212233}, "Tags": ["control"], "LayoutGroupSortIndex": 0, "Value": 0, "Locked": false, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": false, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "CustomImage": {"ImageURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669822378/8057EB3967DBC0674007E91CDB328CB923B2BA9A/", "ImageSecondaryURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669822330/55069B8273CD3185B0C099A2BD56ECDB0D381683/", "ImageScalar": 1.0, "WidthScale": 0.0, "CustomTile": {"Type": 2, "Thickness": 0.1, "Stackable": false, "Stretch": true}}, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['94b849'] = [==[{"GUID": "94b849", "Name": "Custom_Tile", "Transform": {"posX": 2.09088445, "posY": 1.58000016, "posZ": -8.097519, "rotX": -9.297372e-09, "rotY": 179.999985, "rotZ": 4.45938468e-08, "scaleX": 2.2, "scaleY": 1.0, "scaleZ": 2.2}, "Nickname": "Tsenviilyq Control Marker", "Description": "", "GMNotes": "3center", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 0.239212215, "g": 0.247055352, "b": 0.439212233}, "Tags": ["control"], "LayoutGroupSortIndex": 0, "Value": 0, "Locked": false, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": false, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "CustomImage": {"ImageURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669822839/181FB32C812135AE6796FCED2AD315F0CAEA6CD0/", "ImageSecondaryURL": "https://steamusercontent-a.akamaihd.net/ugc/1856048428669822790/98C7F25CE178D2E3715D7154B6D24184DB9D39B6/", "ImageScalar": 1.0, "WidthScale": 0.0, "CustomTile": {"Type": 2, "Thickness": 0.1, "Stackable": false, "Stretch": true}}, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['7e86a6'] = [==[{"GUID": "7e86a6", "Name": "ScriptingTrigger", "Transform": {"posX": -13.5, "posY": 2.0, "posZ": 31.12, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 6.0, "scaleY": 1.0, "scaleZ": 2.0}, "Nickname": "3", "Description": "3", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['6f7cc7'] = [==[{"GUID": "6f7cc7", "Name": "ScriptingTrigger", "Transform": {"posX": -21.5, "posY": 2.5, "posZ": 32.0, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 7.0, "scaleY": 2.0, "scaleZ": 8.0}, "Nickname": "3", "Description": "2", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['b30d72'] = [==[{"GUID": "b30d72", "Name": "ScriptingTrigger", "Transform": {"posX": -21.5, "posY": 2.0, "posZ": 20.6, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 6.0, "scaleY": 1.0, "scaleZ": 3.5}, "Nickname": "4", "Description": "4", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['101cfe'] = [==[{"GUID": "101cfe", "Name": "ScriptingTrigger", "Transform": {"posX": -21.5, "posY": 2.0, "posZ": 12.0, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 6.0, "scaleY": 1.0, "scaleZ": 3.0}, "Nickname": "3", "Description": "3", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['d38f93'] = [==[{"GUID": "d38f93", "Name": "ScriptingTrigger", "Transform": {"posX": -22.2, "posY": 2.0, "posZ": 4.2, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 5.2, "scaleY": 1.0, "scaleZ": 3.3}, "Nickname": "2", "Description": "4", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['38b07a'] = [==[{"GUID": "38b07a", "Name": "ScriptingTrigger", "Transform": {"posX": -21.4, "posY": 2.5, "posZ": -8.0, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 7.0, "scaleY": 2.0, "scaleZ": 8.0}, "Nickname": "3", "Description": "2", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['0415af'] = [==[{"GUID": "0415af", "Name": "ScriptingTrigger", "Transform": {"posX": 14.4, "posY": 2.0, "posZ": 32.0, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 6.0, "scaleY": 1.0, "scaleZ": 3.6}, "Nickname": "5", "Description": "4", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['5dbedf'] = [==[{"GUID": "5dbedf", "Name": "ScriptingTrigger", "Transform": {"posX": 21.6, "posY": 2.5, "posZ": 26.0, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 7.0, "scaleY": 2.0, "scaleZ": 7.5}, "Nickname": "3", "Description": "2", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['74df09'] = [==[{"GUID": "74df09", "Name": "ScriptingTrigger", "Transform": {"posX": 18.0, "posY": 2.0, "posZ": 14.5, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 5.4, "scaleY": 1.0, "scaleZ": 2.8}, "Nickname": "2", "Description": "4", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['dc04ba'] = [==[{"GUID": "dc04ba", "Name": "ScriptingTrigger", "Transform": {"posX": 21.2, "posY": 2.0, "posZ": 4.0, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 6.6, "scaleY": 1.0, "scaleZ": 4.0}, "Nickname": "6", "Description": "5", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['4f6598'] = [==[{"GUID": "4f6598", "Name": "ScriptingTrigger", "Transform": {"posX": 20.0, "posY": 2.5, "posZ": -9.0, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 7.5, "scaleY": 2.0, "scaleZ": 8.0}, "Nickname": "3", "Description": "2", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['6fa038'] = [==[{"GUID": "6fa038", "Name": "ScriptingTrigger", "Transform": {"posX": -6.8, "posY": 2.0, "posZ": 32.59, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 5.5, "scaleY": 1.0, "scaleZ": 2.0}, "Nickname": "2", "Description": "4", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['eaeacf'] = [==[{"GUID": "eaeacf", "Name": "ScriptingTrigger", "Transform": {"posX": 0.8, "posY": 2.5, "posZ": 31.4, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 6.2, "scaleY": 2.0, "scaleZ": 9.0}, "Nickname": "6", "Description": "5", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['d14d31'] = [==[{"GUID": "d14d31", "Name": "ScriptingTrigger", "Transform": {"posX": -8.2, "posY": 2.0, "posZ": 24.0, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 6.4, "scaleY": 1.0, "scaleZ": 3.6}, "Nickname": "5", "Description": "4", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['0e9119'] = [==[{"GUID": "0e9119", "Name": "ScriptingTrigger", "Transform": {"posX": 9.2, "posY": 2.0, "posZ": 23.6, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 6.4, "scaleY": 1.0, "scaleZ": 2.8}, "Nickname": "3", "Description": "3", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['309fde'] = [==[{"GUID": "309fde", "Name": "ScriptingTrigger", "Transform": {"posX": -11.0, "posY": 2.0, "posZ": 17.0, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 4.4, "scaleY": 1.0, "scaleZ": 3.6}, "Nickname": "4", "Description": "3", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['3588ca'] = [==[{"GUID": "3588ca", "Name": "ScriptingTrigger", "Transform": {"posX": 2.6, "posY": 2.0, "posZ": 17.2, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 3.8, "scaleY": 1.0, "scaleZ": 4.0}, "Nickname": "1", "Description": "1", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['a4d91e'] = [==[{"GUID": "a4d91e", "Name": "ScriptingTrigger", "Transform": {"posX": 10.4, "posY": 2.0, "posZ": 17.6, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 4.6, "scaleY": 1.0, "scaleZ": 3.0}, "Nickname": "2", "Description": "3", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['a091c3'] = [==[{"GUID": "a091c3", "Name": "ScriptingTrigger", "Transform": {"posX": -10.4, "posY": 2.0, "posZ": 10.4, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 6.0, "scaleY": 1.0, "scaleZ": 2.6}, "Nickname": "3", "Description": "3", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['e58429'] = [==[{"GUID": "e58429", "Name": "ScriptingTrigger", "Transform": {"posX": 1.3, "posY": 2.5, "posZ": 6.9, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 6.6, "scaleY": 2.0, "scaleZ": 9.0}, "Nickname": "4", "Description": "3", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['60aef9'] = [==[{"GUID": "60aef9", "Name": "ScriptingTrigger", "Transform": {"posX": 11.8, "posY": 2.0, "posZ": 7.2, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 6.0, "scaleY": 1.0, "scaleZ": 3.6}, "Nickname": "4", "Description": "3", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['377510'] = [==[{"GUID": "377510", "Name": "ScriptingTrigger", "Transform": {"posX": -10.8, "posY": 2.0, "posZ": 0.3, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 6.4, "scaleY": 1.0, "scaleZ": 3.6}, "Nickname": "5", "Description": "4", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['37c56b'] = [==[{"GUID": "37c56b", "Name": "ScriptingTrigger", "Transform": {"posX": -0.8, "posY": 2.0, "posZ": -2.2, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 6.2, "scaleY": 1.0, "scaleZ": 3.0}, "Nickname": "3", "Description": "3", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['9e10d1'] = [==[{"GUID": "9e10d1", "Name": "ScriptingTrigger", "Transform": {"posX": 9.4, "posY": 2.0, "posZ": -1.7, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 5.6, "scaleY": 1.0, "scaleZ": 2.4}, "Nickname": "2", "Description": "2", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['a8df27'] = [==[{"GUID": "a8df27", "Name": "ScriptingTrigger", "Transform": {"posX": -10.0, "posY": 2.0, "posZ": -10.4, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 6.0, "scaleY": 1.0, "scaleZ": 3.0}, "Nickname": "3", "Description": "3", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['63546d'] = [==[{"GUID": "63546d", "Name": "ScriptingTrigger", "Transform": {"posX": 2.1, "posY": 2.5, "posZ": -9.5, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 7.0, "scaleY": 2.0, "scaleZ": 8.0}, "Nickname": "3", "Description": "4", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['405f7f'] = [==[{"GUID": "405f7f", "Name": "ScriptingTrigger", "Transform": {"posX": -21.49, "posY": 1.59, "posZ": 33.58, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 2.0, "scaleY": 1.0, "scaleZ": 2.0}, "Nickname": "", "Description": "", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['f023cc'] = [==[{"GUID": "f023cc", "Name": "ScriptingTrigger", "Transform": {"posX": -21.55, "posY": 1.59, "posZ": -6.47, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 2.0, "scaleY": 1.0, "scaleZ": 2.0}, "Nickname": "", "Description": "", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['de0671'] = [==[{"GUID": "de0671", "Name": "ScriptingTrigger", "Transform": {"posX": 21.32, "posY": 1.59, "posZ": 27.66, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 2.0, "scaleY": 1.0, "scaleZ": 2.0}, "Nickname": "", "Description": "", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['bc6df3'] = [==[{"GUID": "bc6df3", "Name": "ScriptingTrigger", "Transform": {"posX": 19.67, "posY": 1.59, "posZ": -7.85, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 2.0, "scaleY": 1.0, "scaleZ": 2.0}, "Nickname": "", "Description": "", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['c815f6'] = [==[{"GUID": "c815f6", "Name": "ScriptingTrigger", "Transform": {"posX": 0.67, "posY": 1.59, "posZ": 33.73, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 2.0, "scaleY": 1.0, "scaleZ": 2.0}, "Nickname": "", "Description": "", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['801598'] = [==[{"GUID": "801598", "Name": "ScriptingTrigger", "Transform": {"posX": 1.17, "posY": 1.59, "posZ": 9.29, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 2.0, "scaleY": 1.0, "scaleZ": 2.0}, "Nickname": "", "Description": "", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]
standardBoardObjectJSON['418f33'] = [==[{"GUID": "418f33", "Name": "ScriptingTrigger", "Transform": {"posX": 2.09, "posY": 1.59, "posZ": -8.1, "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0, "scaleX": 2.0, "scaleY": 1.0, "scaleZ": 2.0}, "Nickname": "", "Description": "", "GMNotes": "", "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0}, "ColorDiffuse": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.509803951}, "LayoutGroupSortIndex": 0, "Value": 0, "Locked": true, "Grid": true, "Snap": true, "IgnoreFoW": false, "MeasureMovement": false, "DragSelectable": true, "Autoraise": true, "Sticky": true, "Tooltip": true, "GridProjection": false, "HideWhenFaceDown": false, "Hands": false, "LuaScript": "", "LuaScriptState": "", "XmlUI": ""}]==]

demonwebOrigin = {0, 1.6, 11}	-- world position of the 'a' (center) slot - same spot as the standard board,
								-- since this is an alternative to it (hide/move the standard board when testing)
demonwebHexScale = 8.5			-- tile scale, kept equal to R (position spacing) per the reference mod's data;
								-- center-to-center neighbor distance = R*sqrt(3) = 14.72
demonwebHexArtReferenceScale = 7	-- the scale every digitized circle/spy/connector-ring/marker coordinate
									-- below (demonwebSiteData, demonwebConnectorRingsByTile, spyOffsets,
									-- markerPos) was measured at. demonwebSpawnSites scales all of those by
									-- demonwebHexScale/demonwebHexArtReferenceScale at the point of use, so
									-- they stay lined up with the actual printed art if demonwebHexScale is
									-- ever changed again - change demonwebHexScale alone, nothing else.

demonwebHexDefs = {
	A1 = 'https://lh3.googleusercontent.com/d/1KwJ4SXkk32C0lBFqlWbLths8nypkdEYb',
	A2 = 'https://lh3.googleusercontent.com/d/1eYmgnEDgWjgIfhXvyFlzdobNKtoXQ_D4',
	A3 = 'https://lh3.googleusercontent.com/d/1LLR_ZzWqudC21rQdpVf1XwFJVyRrwpNy',
	A4 = 'https://lh3.googleusercontent.com/d/17llBObLrzBZroDESHvwB1hGCb3aASAH8',
	A5 = 'https://lh3.googleusercontent.com/d/1a2I1XdUb8iX95jQFFuPNjOYZrJHKNWen',
	A6 = 'https://lh3.googleusercontent.com/d/1HeqT0orBlRKrXfi3DOlkbSGwWuPUq1d4',
	A7 = 'https://lh3.googleusercontent.com/d/13Z_TSDE8uH_c5ZG5DjS_CWUIE8Gpp5C-',
	A8 = 'https://lh3.googleusercontent.com/d/1jsWoJQuW8xKB4-QIKvdIawmLFZO7cL1W',
	A9 = 'https://lh3.googleusercontent.com/d/1VhiSfQKSwmVNd17-TseCOceCN49EyDgV',
	B1 = 'https://lh3.googleusercontent.com/d/1kKnoxW7hOk4DAeqZZW-a8aXCPLI4QDiy',
	B2 = 'https://lh3.googleusercontent.com/d/1MfzQDo_5p6K1sfw5jdKcJI7Sps7rXI01',
	B3 = 'https://lh3.googleusercontent.com/d/1fMyKna-D0YSQiG9DR8cply6yet5fSE7K',
	B4 = 'https://lh3.googleusercontent.com/d/1JMc4NLC3ofERGHB4MkbdzBzg07WA7LMY',
	B5 = 'https://lh3.googleusercontent.com/d/1fxP3N2pfkXOIpD_b8B2b1rD31GtgEDfq',
	B6 = 'https://lh3.googleusercontent.com/d/1B6cACGUZE5KGhsqsbYzuLj3IsmD4-qTo',
	C1 = 'https://lh3.googleusercontent.com/d/1RtwCJmV-hNM_5bFMzwWWkDPMmzMEK0aQ',
	C2 = 'https://lh3.googleusercontent.com/d/1nuSO5PLkTWC4zw0VuXkZX4ArpZe5ea7e',
	C3 = 'https://lh3.googleusercontent.com/d/16_nS6YNP98dDaV-nq3yBUhD-y8VxOVjm',
	C4 = 'https://lh3.googleusercontent.com/d/1xD6mV8gdcq7UKd2o9_dhNhK_MEkrkUZu',
	C5 = 'https://lh3.googleusercontent.com/d/1TI3KCHMqj0DGmHFViAMOYuud8LcL-2hD',
	C6 = 'https://lh3.googleusercontent.com/d/1k-ZBqFMjB5_KLU8Mskqmphs_0eYc2FdS',
	C7 = 'https://lh3.googleusercontent.com/d/15pi5uVWGz6H4P-FLXb6Od4uKEpc6NXaY',
	C8 = 'https://lh3.googleusercontent.com/d/1_T8lRTjG2NL4s_crvwfZo1HE3QHScr_B',
	X1 = 'https://lh3.googleusercontent.com/d/1TtcV5MlLxofmQ0rQsQ_anxxI3qP4dHUW',
	X2 = 'https://lh3.googleusercontent.com/d/1xQSzkQvboMrk3-NyMzBDeFEDH_Z8kRuu',
	X3 = 'https://lh3.googleusercontent.com/d/1e9hPv-1Nb9o8Kp0DskRofhjPfF8OgBtt',
	X4 = 'https://lh3.googleusercontent.com/d/1ME8M_xRTh9AfZPS_MjYz0pfysjhGEZzY'
}

-- Correct pointy-top hex tessellation: edge-sharing neighbors sit at distance R*sqrt(3) from center, at
-- angles 0/60/120/180/240/300 (verified against the actual card art, which is pointy-top - the rulebook's
-- own construction diagram just draws its hex icons flat-top for illustration, which doesn't match the
-- real tile shape).
-- separate the position-spacing radius from the visual tile scale - empirically, TTS doesn't render a
-- Custom_Tile's real size as exactly equal to its "scale" number, so the two need independent tuning.
-- Between demonwebHexScale=5.2 giving overlap at spacing 9.0 and a gap at spacing 10.15, this splits the
-- difference.
local R = demonwebHexScale
-- 9-hex layout matching the rulebook's "2 player setup" diagram: 3 columns of 3. This is an offset-column
-- grid (col=-1,0,1 each with row=-1,0,1) - 6 of the 8 outer cells are true edge-neighbors of A at distance
-- R*sqrt(3); the far corners (col=-1,row=1 and col=1,row=-1, where B1/B2 sit) are one step further out,
-- edge-adjacent to their own 2 nearest grid neighbors instead of directly to A - which is exactly how the
-- diagram shows B1/B2 sitting at the far ends of the board rather than touching the center hex.
local SQRT3 = math.sqrt(3)
-- Board-radius gate used by demonwebDeployTroopsAtPointer and hotkeyPlaceSpy to decide "is the pointer
-- somewhere on the modular board". The farthest hex slot (4-player C7/C8) sits at 2*sqrt(3)*R from the
-- origin; +1 R of margin covers a tile's own extent beyond its center. Expressed as a formula (not a fixed
-- number) so it automatically stays correct if demonwebHexScale ever changes - it must still land well
-- short of the market/recruit area, whose own position is fixed independent of hex scale (measured at
-- ~39-46 from the origin).
demonwebBoardRadius = 2 * SQRT3 * R + R
demonweb2PlayerSlots = {
	a   = {0,          0,           180},
	c_n1 = {-1.5*R, -0.5*SQRT3*R,   180},		-- gets a random C-tile
	c_n2 = { 0,     -SQRT3*R,       180},		-- gets a random C-tile
	c_n3 = { 1.5*R, -0.5*SQRT3*R,   180},		-- gets a random C-tile
	c_s1 = {-1.5*R,  0.5*SQRT3*R,   180},		-- gets a random C-tile
	c_s2 = { 0,      SQRT3*R,       180},		-- gets a random C-tile
	c_s3 = { 1.5*R,  0.5*SQRT3*R,   180},		-- gets a random C-tile
	b1 = {-1.5*R,  1.5*SQRT3*R, 240},	-- Menzoberranzan - fixed anchor, top-left corner of the board (the
										-- reference mod's rotation keeps a +60 offset from the general rotation
										-- for this hex)
	b2 = { 1.5*R, -1.5*SQRT3*R, 180}	-- diagonally opposite corner from B1, bottom-right
}

-- 3-player: same center + 6-ring-of-C as 2-player, but 3 "corner" B-slots spaced 120 degrees apart around the
-- ring instead of 2 diagonally-opposite ones. B1 stays exactly where it was for 2-player (same fixed anchor,
-- same corner) so the two modes look consistent; B2 and a new B3 fill two more of the corner positions.
demonweb3PlayerSlots = {
	a   = {0,          0,           180},
	c_n1 = {-1.5*R, -0.5*SQRT3*R,   180},		-- gets a random C-tile
	c_n2 = { 0,     -SQRT3*R,       180},		-- gets a random C-tile
	c_n3 = { 1.5*R, -0.5*SQRT3*R,   180},		-- gets a random C-tile
	c_s1 = {-1.5*R,  0.5*SQRT3*R,   180},		-- gets a random C-tile
	c_s2 = { 0,      SQRT3*R,       180},		-- gets a random C-tile
	c_s3 = { 1.5*R,  0.5*SQRT3*R,   180},		-- gets a random C-tile
	b1 = {-1.5*R,  1.5*SQRT3*R, 240},	-- Menzoberranzan - fixed anchor, same corner as in the 2-player layout
	b2 = { 3*R,        0,           180},	-- corner position #2 (120 degrees around from B1)
	b3 = {-1.5*R, -1.5*SQRT3*R,     180}	-- corner position #3 (120 degrees around from B2)
}

-- 4-player: same center + 6-ring-of-C, plus ALL 6 corner positions filled (B1 fixed as always, B2-B6 shuffled
-- across the other 5 corners - the 6 corners are spaced 60 degrees apart, at distance 3R, matching the
-- reference mod's "B tiles sit at the far corners of the board" structure). C7/C8 extend two opposite ring
-- positions one more step outward (distance 2*R*sqrt(3)), matching the reference mod's "C7/C8 continue past
-- an existing ring hex" placement.
demonweb4PlayerSlots = {
	a   = {0,          0,           180},
	c_n1 = {-1.5*R, -0.5*SQRT3*R,   180},		-- gets a random C-tile
	c_n2 = { 0,     -SQRT3*R,       180},		-- gets a random C-tile
	c_n3 = { 1.5*R, -0.5*SQRT3*R,   180},		-- gets a random C-tile
	c_s1 = {-1.5*R,  0.5*SQRT3*R,   180},		-- gets a random C-tile
	c_s2 = { 0,      SQRT3*R,       180},		-- gets a random C-tile
	c_s3 = { 1.5*R,  0.5*SQRT3*R,   180},		-- gets a random C-tile
	b1 = {-1.5*R,  1.5*SQRT3*R, 240},	-- Menzoberranzan - fixed anchor, corner at 120 degrees
	corner0   = { 3*R,          0,       180},	-- corner at 0 degrees - gets a random B-tile (B2-B6)
	corner60  = { 1.5*R,  1.5*SQRT3*R,   180},	-- corner at 60 degrees - gets a random B-tile
	corner180 = {-3*R,          0,       180},	-- corner at 180 degrees - gets a random B-tile
	corner240 = {-1.5*R, -1.5*SQRT3*R,   180},	-- corner at 240 degrees - gets a random B-tile
	corner300 = { 1.5*R, -1.5*SQRT3*R,   180},	-- corner at 300 degrees - gets a random B-tile
	c7 = {0,  -2*SQRT3*R, 180},	-- extends c_n2 one more ring-step outward
	c8 = {0,   2*SQRT3*R, 180}	-- extends c_s2 one more ring-step outward (opposite direction)
}

-- shared spawner: given a slot table {name = {dx, dz, rotationY}} and a hexId assigned to each slot name,
-- spawns every tile a moment apart (see note below on why) and reports what was generated
-- Site data for Demonweb hexes (proof-of-concept: B1 only, for now). Local circle offsets are measured at
-- the hex's printed/unrotated orientation, in world units, relative to the hex's own center - they get
-- rotated by the tile's actual placement rotation before being turned into world positions. "circles" lists
-- every troop slot on the site (matches the printed circles, X-marked or not); "initialTroops" is how many
-- of those (counting from the first) start with a neutral/unaligned troop, matching the printed sword icons.

-- Physical control-marker tokens for the 7 "named" Demonweb sites (the ones sharing the hub-ring template,
-- matching the standard board's own 7-marker convention). controlImage is the site's "Control" face - purely
-- visual, no automated delivery (it awards a Web token, a resource this mod has no bag/counter for). variants
-- are the 3 possible "Total Control" backs; one is chosen at random per generation (see demonwebSpawnSites).
-- vp is the VP to auto-deliver from THAT variant specifically - some variants mix VP with other, non-VP
-- effects (Web tokens, promote/assassinate icons); only the VP portion is automated, per instruction.
demonwebMarkerData = {
	B1 = { siteName = 'Council Chamber',
		controlImage = 'https://lh3.googleusercontent.com/d/1m70QgKtr5iP7pWwUi6jXRb1R0f4IQh7a',
		variants = {
			{ image = 'https://lh3.googleusercontent.com/d/1Jb037zFBrRPSc1uz67dt5S55YGhLM5-b', vp = 1 },	-- +2 Web, +1 VP
			{ image = 'https://lh3.googleusercontent.com/d/1EwdSLUf0wxmjuMQWlof_cFnC6LLMrp7y', vp = 0 },	-- hand/hand/X
			{ image = 'https://lh3.googleusercontent.com/d/1xQa8gY-m4qMy0-hs0De42M5mjWrhsdo7', vp = 0 }	-- +1 Web, +1 sword
		}
	},
	B2 = { siteName = 'Lolth Shrine',
		controlImage = 'https://lh3.googleusercontent.com/d/1ayO7vPhT3hWFcDJ_YQFKPJQr3-66A7CP',
		variants = {
			{ image = 'https://lh3.googleusercontent.com/d/17dtHzi_WuyC5UFwAhLwP3pKnuf6WdJc4', vp = 0 },	-- Obedience card
			{ image = 'https://lh3.googleusercontent.com/d/1aORZkto7BACE079FVVhZS_8fnKDTrUQP', vp = 2 },	-- +2 VP
			{ image = 'https://lh3.googleusercontent.com/d/1O06OblbRlKwzjF-lqohlwW6kohIFYqpS', vp = 1 }	-- +2 Web, +1 VP
		}
	},
	B3 = { siteName = 'Xith Idrana',
		controlImage = 'https://lh3.googleusercontent.com/d/1kmWr85Sjt24uruINyD2M2UQ6dI_xEzt1',
		variants = {
			{ image = 'https://lh3.googleusercontent.com/d/1SMC0hGwhZoPJ7CJj3F4fflafxHcNm8l6', vp = 0 },	-- hand
			{ image = 'https://lh3.googleusercontent.com/d/1X--FzNleH7b0cfTjnRs_muR5T-WmWQ4r', vp = 2 },	-- +2 VP
			{ image = 'https://lh3.googleusercontent.com/d/1QVMjtQw5jKMoCf9BPhmeJgFJKsfHnyD7', vp = 0 }	-- sword/shield
		}
	},
	B4 = { siteName = 'Faerholme',
		controlImage = 'https://lh3.googleusercontent.com/d/1SAlisZ6xrY4gI7p0lvyNBS9n-kmb6alA',
		variants = {
			{ image = 'https://lh3.googleusercontent.com/d/1j9SeRrWSlRPpKKqP8OJlYN35i1ilc6R3', vp = 0 },	-- hand/hand/X
			{ image = 'https://lh3.googleusercontent.com/d/153oJ77DmDGMgW9DZ2BH9jQVMFqjJzCyu', vp = 1 },	-- +1 Web, +1 VP
			{ image = 'https://lh3.googleusercontent.com/d/1_B9ahptWeyGN69fa_YtwrTWcu6AHDXo_', vp = 0 }	-- +2 Web
		}
	},
	B5 = { siteName = 'Darklight Realm',
		controlImage = 'https://lh3.googleusercontent.com/d/1b5F2o7Hf3Q3VLA8lWyPGzJ4T5VfELsKx',
		variants = {
			{ image = 'https://lh3.googleusercontent.com/d/1oZ8faq0WxWl1FtP4yaOEU3HYF1f_Hkk5', vp = 1 },	-- +1 Web, +1 VP
			{ image = 'https://lh3.googleusercontent.com/d/1A5gCfsrsGPf-bIy2WpMvYxzv7DTpjfqI', vp = 0 },	-- hand/hand/X
			{ image = 'https://lh3.googleusercontent.com/d/17eJ2h5NO1gBv4RD5-a8mbErI3tYvPuu5', vp = 0 }	-- +2 Web
		}
	},
	B6 = { siteName = 'Shedaklah',
		controlImage = 'https://lh3.googleusercontent.com/d/1pa0Y9tY-sRPglIE2NWL466WLdemLrLJG',
		variants = {
			{ image = 'https://lh3.googleusercontent.com/d/1TLUHYdxF0LcN4ywook8mKynNwop7iPX9', vp = 0 },	-- +2 Web
			{ image = 'https://lh3.googleusercontent.com/d/1EePUvyDrYZTLLggDU89DTOXQNfY8R8a0', vp = 1 },	-- +1 Web, +1 VP
			{ image = 'https://lh3.googleusercontent.com/d/1jDqdXg2qaCw0julEpwpn_qZlXt5tnENZ', vp = 0 }	-- hand/hand/X
		}
	},
	-- A1 and A3 both use the fixed centerHex 'a' slot (see generateDemonwebMap*Player) - whichever of
	-- A1-A9 is picked as the center hex always lands at the same world spot, so markerPos below is a
	-- literal, measured absolute world position rather than a per-generation-relative offset (it's still
	-- rotated to match 'a''s actual placement rotation at spawn time - see the markerPos handling in
	-- demonwebSpawnSites - since 'a' is no longer always placed at a fixed rotation now that hex rotations
	-- are optimized for connections)
	A1 = { siteName = 'The Great Web',
		controlImage = 'https://lh3.googleusercontent.com/d/1EhFuDZLRNCNhutE4HHJpye0REJBNLlqG',
		markerPos = {0.00, 2.20, 12.25},
		variants = {
			{ image = 'https://lh3.googleusercontent.com/d/1hAMCefPeYiKLtxp4Tpz6KKDspwHAr-91', vp = 3 },	-- +1 Web, +3 VP
			{ image = 'https://lh3.googleusercontent.com/d/1QWDZAfs40Ew3eg_3Jx8OqEtNCxcIvP2b', vp = 0 },	-- +3 Web
			{ image = 'https://lh3.googleusercontent.com/d/1FbFCcjjxtDWGdi0O6Wb4ns4vEwWmuRVD', vp = 0 }	-- hand/hand
		}
	},
	-- A3's own 'Great Web' site (the small 2-point hub site, distinct from A1's 8-point 'The Great Web')
	-- reuses the same physical marker artwork as A1 - same token design, just placed on a different hex
	A3 = { siteName = 'Great Web',
		controlImage = 'https://lh3.googleusercontent.com/d/1EhFuDZLRNCNhutE4HHJpye0REJBNLlqG',
		markerPos = {0.00, 2.20, 11.70},
		variants = {
			{ image = 'https://lh3.googleusercontent.com/d/1hAMCefPeYiKLtxp4Tpz6KKDspwHAr-91', vp = 3 },	-- +1 Web, +3 VP
			{ image = 'https://lh3.googleusercontent.com/d/1QWDZAfs40Ew3eg_3Jx8OqEtNCxcIvP2b', vp = 0 },	-- +3 Web
			{ image = 'https://lh3.googleusercontent.com/d/1FbFCcjjxtDWGdi0O6Wb4ns4vEwWmuRVD', vp = 0 }	-- hand/hand
		}
	}
}
demonwebActiveMarkers = {}		-- {guid, siteZoneGuid, vp}, one per marker spawned this generation - populated
								-- in demonwebSpawnSites, read by demonwebMoveControlMarker; cleared in
								-- demonwebClearBoard

-- every site below carries spyOffsets: 4 X-positions for the spy row, centered on the site's own top-row
-- troop circles instead of the old default ("start at the first circle and run ~2.9 units to one side"),
-- which drifted the spy row noticeably off-center for anything narrower than a full 3-wide row. A9 is the
-- one exception, left on its measured spyZOffset/default-X combo (see its own comment below) since that
-- was calibrated directly against an in-game measurement rather than derived from this centering formula.
demonwebSiteData = {
	B1 = {
		{ name = 'Council Chamber', points = 4,
		  circles = {{-1.37,-3.63},{-0.30,-3.64},{0.80,-3.64}}, initialTroops = 2,
		  spyOffsets = {-1.7471, -0.7757, 0.1957, 1.1671} }
	},
	A1 = {
		{ name = 'The Great Web', points = 8,
		  circles = {{-1.40,-2.41},{-0.32,-2.41},{0.76,-2.41},{-1.40,-3.45},{-0.32,-3.46},{0.76,-3.45}}, initialTroops = 6,
		  spyOffsets = {-1.7771, -0.8057, 0.1657, 1.1371} }
	},
	A2 = {
		{ name = 'Fogtown', points = 4, circles = {{-3.11,3.24},{-2.03,3.24},{-0.94,3.24}}, initialTroops = 2,
		  spyOffsets = {-3.4838, -2.5124, -1.5410, -0.5695} },
		{ name = 'Gallenghast', points = 4, circles = {{1.07,-0.44},{2.17,-0.44},{3.24,-0.44}}, initialTroops = 2,
		  spyOffsets = {0.7029, 1.6743, 2.6457, 3.6171} },
		{ name = 'Darkflame', points = 4, circles = {{-2.70,-3.85},{-1.61,-3.85},{-0.53,-3.85}}, initialTroops = 2,
		  spyOffsets = {-3.0705, -2.0990, -1.1276, -0.1562} }
		-- A2's regional "control all 3 at once" bonus is automated in demonwebCheckA2Bonus(), paid out as
		-- physical VP tokens each turn in demonwebDeliverTotalControlVpsCoroutine (+1 VP for controlling all
		-- 3, +4 VP instead if all 3 are Total Controlled)
	},
	-- each of these is a tiny 1-2 circle site, so the default spy-row formula (a 4-point row starting AT
	-- the circle and running ~2.9 units to one side) drags the spy points way off to the side of the
	-- actual marker - spyOffsets below re-centers the same 4-point row on each site's own circle(s) instead
	A3 = {
		{ name = 'Web (N)', points = 2, circles = {{-0.45,4.40}}, initialTroops = 1,
		  spyOffsets = {-1.9071, -0.9357, 0.0357, 1.0071} },
		{ name = 'Web (NE)', points = 2, circles = {{3.54,2.30}}, initialTroops = 1,
		  spyOffsets = {2.0829, 3.0543, 4.0257, 4.9971} },
		{ name = 'Web (NW)', points = 2, circles = {{-4.61,2.07}}, initialTroops = 1,
		  spyOffsets = {-6.0671, -5.0957, -4.1243, -3.1529} },
		{ name = 'Web (SW)', points = 2, circles = {{-3.92,-2.35}}, initialTroops = 1,
		  spyOffsets = {-5.3771, -4.4057, -3.4343, -2.4629} },
		{ name = 'Web (SE)', points = 2, circles = {{3.38,-2.27}}, initialTroops = 1,
		  spyOffsets = {1.9229, 2.8943, 3.8657, 4.8371} },
		{ name = 'Web (S)', points = 2, circles = {{-0.26,-5.28}}, initialTroops = 1,
		  spyOffsets = {-1.7171, -0.7457, 0.2257, 1.1971} },
		{ name = 'Great Web', points = 2, circles = {{-0.83,-2.86},{0.25,-2.86}}, initialTroops = 0,
		  spyOffsets = {-1.7471, -0.7757, 0.1957, 1.1671} }
	},
	A9 = {
		{ name = 'Wells of Darkness', points = 9,
		  circles = {{-1.25,0.85},{-0.15,0.84},{0.93,0.84},{-1.23,-0.20},{-0.16,-0.19},{0.92,-0.19},{-1.25,-1.25},{-0.15,-1.26},{0.93,-1.26}},
		  initialTroops = 0,
		  -- Z still comes from the in-game measurement (world {-1.25, 2.21, 12.88} -> local Z 1.88, giving
		  -- this spyZOffset); X is now centered on the top row like every other site instead of sitting at
		  -- the row's own left edge (that measured point's X happened to equal the default formula's start)
		  spyZOffset = 0.0357,
		  spyOffsets = {-1.6138, -0.6424, 0.3290, 1.3005} }
	}
	-- A4-A8 are pure tunnel/connector hexes with no site cards - nothing to digitize for them
	,
	B2 = {
		-- old +0.6 spyZOffset pushed the spy row ~1.6x farther from the top row than the shared default
		-- gets everywhere else (Xith Idrana, Faerholme, etc.) - removed. spyOffsets centers the 4-point
		-- row on the actual 2-circle-wide top row instead of overshooting ~2 units past it like the
		-- default "start at first circle" formula would for a row this narrow.
		{ name = 'Lolth Shrine', points = 3, circles = {{-0.91,-3.82},{0.17,-3.82},{-0.91,-4.86},{0.17,-4.86}}, initialTroops = 2,
		  spyOffsets = {-1.8271, -0.8557, 0.1157, 1.0871} },
		-- single-circle site - spyOffsets centers the 4-point row on it instead of spreading ~2.9 units
		-- off to one side, same fix as A3's mini-sites
		{ name = 'Vrith', points = 2, circles = {{-0.42,3.70}}, initialTroops = 1,
		  spyOffsets = {-1.8771, -0.9057, 0.0657, 1.0371} }
	},
	C1 = {
		{ name = 'The Twilight', points = 3, circles = {{-2.09,2.63},{-1.01,2.63},{0.07,2.63}}, initialTroops = 0,
		  spyOffsets = {-2.4671, -1.4957, -0.5243, 0.4471} },
		{ name = 'Spiral Desert', points = 3, circles = {{-3.49,-1.88},{-2.42,-1.88},{-1.32,-1.88}}, initialTroops = 0,
		  spyOffsets = {-3.8671, -2.8957, -1.9243, -0.9529} },
		{ name = 'Magma Gate', points = 2, circles = {{3.01,-0.99},{4.10,-0.99}}, initialTroops = 0,
		  spyOffsets = {2.0979, 3.0693, 4.0407, 5.0121} }
	},
	C2 = {
		{ name = 'Araumycos', points = 3, circles = {{0.70,3.33},{1.79,3.33},{0.70,2.29},{1.78,2.28}}, initialTroops = 2,
		  spyOffsets = {-0.2121, 0.7593, 1.7307, 2.7021} },
		{ name = 'Menzoberranzan', points = 5, circles = {{-1.65,-2.86},{-0.56,-2.86},{0.52,-2.85},{-1.65,-3.90},{-0.56,-3.90},{0.52,-3.89}}, initialTroops = 2,
		  spyOffsets = {-2.0205, -1.0490, -0.0776, 0.8938} }
	},
	C3 = {
		{ name = 'Red Forest', points = 4, circles = {{-2.90,3.33},{-1.81,3.32},{-0.73,3.33}}, initialTroops = 1,
		  spyOffsets = {-3.2705, -2.2990, -1.3276, -0.3562} },
		{ name = 'Xal Veldrin', points = 3, circles = {{-0.81,-0.13},{0.27,-0.12},{-0.81,-1.17},{0.27,-1.16}}, initialTroops = 0,
		  spyOffsets = {-1.7271, -0.7557, 0.2157, 1.1871} },
		{ name = 'Iron Wastes', points = 3, circles = {{0.10,-4.21},{1.19,-4.21},{2.28,-4.21}}, initialTroops = 1,
		  spyOffsets = {-0.2671, 0.7043, 1.6757, 2.6471} }
	},
	C4 = {
		{ name = 'Red Gate', points = 4, circles = {{-4.12,1.36},{-3.03,1.36}}, initialTroops = 2,
		  spyOffsets = {-5.0321, -4.0607, -3.0893, -2.1179} },
		{ name = 'Kulggen', points = 4, circles = {{0.68,3.53},{1.78,3.55}}, initialTroops = 2,
		  spyOffsets = {-0.2271, 0.7443, 1.7157, 2.6871} },
		{ name = 'Iblith', points = 1, circles = {{0.05,-0.15}}, initialTroops = 0,
		  spyOffsets = {-1.4071, -0.4357, 0.5357, 1.5071} },
		{ name = 'Caer Sidi', points = 3, circles = {{-0.43,-2.92},{0.66,-2.94},{1.73,-2.91}}, initialTroops = 0,
		  spyOffsets = {-0.8038, 0.1676, 1.1390, 2.1105} }
	},
	C6 = {
		{ name = 'Black Gate', points = 4, circles = {{-3.73,-2.00},{-2.65,-2.00}}, initialTroops = 2,
		  spyOffsets = {-4.6471, -3.6757, -2.7043, -1.7329} },
		{ name = "Zi'Xzolca", points = 2, circles = {{2.41,1.36},{3.49,1.36}}, initialTroops = 0,
		  spyOffsets = {1.4929, 2.4643, 3.4357, 4.4071} }
	},
	C5 = {
		{ name = 'Erelhei-Cinlu', points = 4, circles = {{-3.517,0.622},{-2.440,0.598},{-4.047,-0.414},{-2.971,-0.429},{-1.879,-0.414}}, initialTroops = 2,
		  spyOffsets = {-4.4356, -3.4642, -2.4928, -1.5214} },
		{ name = 'Ath-Qua', points = 3, circles = {{1.991,-1.217},{1.991,-2.260},{3.099,-1.202},{3.099,-2.245}}, initialTroops = 0,
		  spyOffsets = {1.0879, 2.0593, 3.0307, 4.0021} }
	},
	C7 = {
		{ name = 'Spiderhome', points = 5, circles = {{-1.396,3.890},{-0.320,3.897},{0.772,3.890},{-1.396,2.847},{-0.320,2.854},{0.772,2.847}}, initialTroops = 2,
		  spyOffsets = {-1.7718, -0.8004, 0.1710, 1.1425} },
		{ name = 'Thanatos Gate', points = 5, circles = {{-1.467,-3.311},{-0.391,-3.311},{0.701,-3.303},{-1.467,-4.354},{-0.391,-4.354},{0.701,-4.346}}, initialTroops = 2,
		  spyOffsets = {-1.8428, -0.8714, 0.1000, 1.0715} }
	},
	C8 = {
		{ name = 'Enzithir', points = 3, circles = {{-2.488,3.604},{-1.404,3.596}}, initialTroops = 1,
		  spyOffsets = {-3.4031, -2.4317, -1.4603, -0.4889} },
		{ name = 'Xelathir', points = 3, circles = {{2.648,-0.792},{3.740,-0.792}}, initialTroops = 1,
		  spyOffsets = {1.7369, 2.7083, 3.6797, 4.6511} },
		{ name = 'Venathir', points = 3, circles = {{-1.981,-3.280},{-0.905,-3.272}}, initialTroops = 1,
		  spyOffsets = {-2.9001, -1.9287, -0.9573, 0.0141} }
	},
	-- B3-B6 share the exact same "hub" template as B1 (just a different central name and card name) - same
	-- card position, same 3-circle 2X+1-empty layout, so the same spyOffsets apply to all 4
	B3 = { { name = 'Xith Idrana', points = 2, circles = {{-1.53,-4.20},{-0.46,-4.21},{0.64,-4.21}}, initialTroops = 2,
	  spyOffsets = {-1.9071, -0.9357, 0.0357, 1.0071} } },
	B4 = { { name = 'Faerholme', points = 2, circles = {{-1.53,-4.20},{-0.46,-4.21},{0.64,-4.21}}, initialTroops = 2,
	  spyOffsets = {-1.9071, -0.9357, 0.0357, 1.0071} } },
	B5 = { { name = 'Darklight Realm', points = 2, circles = {{-1.53,-4.20},{-0.46,-4.21},{0.64,-4.21}}, initialTroops = 2,
	  spyOffsets = {-1.9071, -0.9357, 0.0357, 1.0071} } },
	B6 = { { name = 'Shedaklah', points = 2, circles = {{-1.53,-4.20},{-0.46,-4.21},{0.64,-4.21}}, initialTroops = 2,
	  spyOffsets = {-1.9071, -0.9357, 0.0357, 1.0071} } },
	X1 = {
		{ name = 'The Barrens', points = 3, circles = {{-1.665,3.395},{-0.581,3.403},{-2.203,2.352},{-1.119,2.360},{-0.035,2.368}}, initialTroops = 0,
		  spyOffsets = {-2.5801, -1.6087, -0.6373, 0.3341} },
		{ name = 'Rotting Plain', points = 3, circles = {{-3.612,-2.114},{-2.528,-2.106},{-1.435,-2.121}}, initialTroops = 2,
		  spyOffsets = {-3.9821, -3.0107, -2.0393, -1.0679} },
		{ name = 'Heaving Hills', points = 3, circles = {{1.564,-1.086},{2.640,-1.086},{3.708,-1.086}}, initialTroops = 2,
		  spyOffsets = {1.1802, 2.1516, 3.1230, 4.0945} }
	},
	X2 = {
		{ name = 'Indifference', points = 4, circles = {{-0.802,0.521},{0.282,0.513},{-0.802,-0.522},{0.282,-0.530}}, initialTroops = 0,
		  spyOffsets = {-1.7171, -0.7457, 0.2257, 1.1971} }
	},
	-- X3 has no site cards, just tunnel paths
	X4 = {
		{ name = 'Fountain of Screams', points = 5, circles = {{-1.396,1.510},{-0.312,1.502},{0.765,1.518}}, initialTroops = 0,
		  spyOffsets = {-1.7715, -0.8000, 0.1714, 1.1428} }
	}
}
demonwebSpawnedGuids = {}		-- GUIDs of all hex tiles currently on the table from a Demonweb generation, so a
								-- fresh generation can clear the old ones first instead of piling up on top
demonwebActiveSiteZoneGuids = {}	-- just the site (not connector-ring) zone GUIDs from the current Demonweb
									-- generation - used for automatic VP/control counting, mirroring what
									-- boardSections[section].siteZoneGuids is for the standard board
demonwebSiteGeometry = {}	-- [zoneGuid] = {x, z, radius, troopSpaces, points, name} - control is checked by
							-- straight-line distance from this stored center, not via the zone object's own
							-- getObjects(), since a piece that arrives by snapping (teleporting straight to
							-- its snap point) doesn't reliably fire the zone's enter-collision the way a
							-- dragged-and-dropped piece does, and every demonweb piece arrives via snapping

-- modular-board equivalent of siteControlCheck() below, keyed by geometry instead of the zone's own physics
-- detection (see demonwebSiteGeometry comment above for why)
-- finds which site's center a world (x,z) point is closest to, among every currently-active demonweb site.
-- Used to keep site-check zones from ever double-counting a piece even when their radii geometrically
-- overlap (e.g. several sites packed close together on one hex) - a piece only ever belongs to its single
-- nearest site, never to two at once.
function demonwebNearestSiteGuid(x, z)
	local bestGuid, bestDist = nil, nil
	for guid, geo in pairs(demonwebSiteGeometry) do
		local dx, dz = x - geo.x, z - geo.z
		local d = dx*dx + dz*dz
		if bestDist == nil or d < bestDist then bestDist = d bestGuid = guid end
	end
	return bestGuid
end

-- A2 hex's regional bonus: controlling all 3 of its sites (Fogtown, Gallenghast, Darkflame) at once, on top of
-- whatever each site pays out individually via demonwebSiteControlCheck. Looked up by site NAME rather than by
-- hexId/zoneGuid tracking, since A2 is drawn from the random 'a' pool (see aChoices) and isn't guaranteed to be
-- on the table every generation - if fewer than all 3 named sites exist this game, the bonus just can't apply.
-- Two tiers, NOT stacked (the stronger one wins if both would otherwise apply): all 3 merely controlled by the
-- same player = +1 VP; all 3 Total Controlled by the same player = +4 VP instead of the +1.
demonwebA2BonusSiteNames = {Fogtown = true, Gallenghast = true, Darkflame = true}

function demonwebCheckA2Bonus()
	local winnerByName, totalControlByName, foundCount = {}, {}, 0
	for guid, geo in pairs(demonwebSiteGeometry) do
		if demonwebA2BonusSiteNames[geo.name] then
			foundCount = foundCount + 1
			local winner, _, totalControl = demonwebSiteControlCheck(guid)
			winnerByName[geo.name] = winner
			totalControlByName[geo.name] = totalControl
		end
	end
	if foundCount < 3 then return nil, false end	-- A2 hex isn't in play this generation
	local commonWinner = winnerByName.Fogtown
	if commonWinner == nil or winnerByName.Gallenghast ~= commonWinner or winnerByName.Darkflame ~= commonWinner then
		return nil, false
	end
	local allTotalControl = totalControlByName.Fogtown and totalControlByName.Gallenghast and totalControlByName.Darkflame
	return commonWinner, allTotalControl
end

function demonwebSiteControlCheck(zoneGuid)
	local geo = demonwebSiteGeometry[zoneGuid]
	if geo == nil then return nil, 0, false end
	local troops = {Red = 0, Blue = 0, Purple = 0, Teal = 0, White = 0}
	local spies = {}
	for _, o in ipairs(getObjectsWithTag('troop')) do
		local p = o.getPosition()
		local dx, dz = p[1]-geo.x, p[3]-geo.z
		if dx*dx + dz*dz <= geo.radius*geo.radius and demonwebNearestSiteGuid(p[1], p[3]) == zoneGuid then
			local c = o.getDescription()
			if troops[c] ~= nil then troops[c] = troops[c] + 1 end
		end
	end
	for _, o in ipairs(getObjectsWithTag('spy')) do
		local p = o.getPosition()
		-- checked against this site's own registered spy points specifically (small radius around each),
		-- not the broader troop-circle radius - keeps a spy on a nearby tunnel connector from being wrongly
		-- claimed by whichever small site's spy-point row happens to reach closest to it
		for _, sp in ipairs(geo.spyPoints or {}) do
			local dx, dz = p[1]-sp[1], p[3]-sp[2]
			if dx*dx + dz*dz <= 0.6*0.6 then
				table.insert(spies, o.getDescription())
				break
			end
		end
	end
	
	local winner = nil
	local winningCount = 0
	for playerColor, count in pairs(troops) do
		if count > 0 then
			if count == winningCount then winner = nil
			elseif count > winningCount then winner = playerColor winningCount = count
			end
		end
	end
	
	local totalControl = false
	if winner == 'White' then winner = nil end
	if winner ~= nil then
		if winningCount == geo.troopSpaces then
			totalControl = true
			for _, spyColor in ipairs(spies) do
				if spyColor ~= winner then totalControl = false break end
			end
		end
	end
	return winner, geo.points, totalControl
end

-- rotates a local (dx,dz) offset (measured at the hex's printed/0-rotation orientation) by the hex's actual
-- placement rotation, matching TTS's left-handed, clockwise-positive rotY convention
function demonwebRotateLocal(dx, dz, rotDeg)
	local rad = math.rad(rotDeg)
	local rx = dx * math.cos(rad) + dz * math.sin(rad)
	local rz = -dx * math.sin(rad) + dz * math.cos(rad)
	return rx, rz
end

-- spawns the troop-counting zone and initial neutral troops for every known site on whichever hex landed in
-- each slot. All tiles with printed sites are digitized (see demonwebSiteData above).
-- every hex's printed art has 6 small connector dots at the same relative position - a fixed radius (as a
-- ratio of demonwebHexScale, measured empirically) at the same 6 angles used for the ring/corner layout
-- itself. Universal across all tiles, so no per-tile digitizing needed.
-- these 6 points aren't at perfectly clean 60-degree increments in the actual artwork (the tunnel paths
-- meander slightly), so each is measured individually rather than derived from a single formula
-- unlike the site troop-circles, these small connector-tunnel rings have no name/points/capacity - each tile's
-- own path layout is unique, so (unlike the earlier universal-formula attempt) every tile is digitized
-- individually. A tile not listed here just has none applied. Values are already in world units (not scaled).
demonwebConnectorRingsByTile = {
	A1 = {{-0.019,4.407},{-3.612,2.074},{3.147,2.684},{3.795,-2.121},{-3.881,-1.882},{-0.098,-5.351}},
	-- A9 has no ring markers on its tunnel paths at all (they run straight from the vertex dots to the
	-- card, unlike B1's) - nothing to digitize here
	-- A3's 6 "Web" sites sit right at the ring's spokes themselves - no separate unnamed connector rings
	A2 = {{-4.822,-0.491},{-5.02,0.282}},
	B1 = {{-0.47,4.400},{-3.881,-1.882},{-3.604,2.074},{3.154,2.692},{3.795,-2.129}},
	B2 = {{3.147,2.692},{-3.62,2.074},{3.788,-2.114},{-3.881,-1.882}},
	C1 = {{-2.591,0.668},{1.168,-2.878},{-1.459,-4.269},{2.775,2.661}},
	C2 = {{-2.987,3.171},{0.456,0.011},{3.756,-3.01}},
	C3 = {{3.7,1.525},{-3.327,-1.689}},
	C4 = {{-2.369,-1.658},{2.949,-0.445},{4.357,-3.218},{0.535,-5.266}},
	C6 = {{2.759,-1.588},{-0.478,-3.914},{-0.81,3.102},{-4.071,1.363},{0.092,-0.282}},
	C5 = {{-0.771,4.029},{-1.119,-3.327}},
	C7 = {{0.092,-0.530},{-3.485,-3.226},{3.843,-3.095},{3.795,2.646},{-3.707,2.507}},
	C8 = {{1.999,-4.200},{0.131,-0.035},{-3.857,0.428},{3.115,2.321}},
	-- B3-B6 share B1's connector layout exactly (same shared hub template)
	B3 = {{-0.47,4.400},{-3.881,-1.882},{-3.604,2.074},{3.154,2.692},{3.795,-2.129}},
	B4 = {{-0.47,4.400},{-3.881,-1.882},{-3.604,2.074},{3.154,2.692},{3.795,-2.129}},
	B5 = {{-0.47,4.400},{-3.881,-1.882},{-3.604,2.074},{3.154,2.692},{3.795,-2.129}},
	B6 = {{-0.47,4.400},{-3.881,-1.882},{-3.604,2.074},{3.154,2.692},{3.795,-2.129}},
	-- A4-A8 are pure decorative connector hexes (no sites), but their tunnel paths still have 7 rings each
	-- (6 outer + 1 near-center hub), shared across all five since they use the same template
	A4 = {{2.292,2.074},{-2.409,1.610},{-0.074,3.264},{0.092,-0.066},{2.767,-1.364},{-2.884,-0.986},{0.013,-2.585}},
	A5 = {{2.292,2.074},{-2.409,1.610},{-0.074,3.264},{0.092,-0.066},{2.767,-1.364},{-2.884,-0.986},{0.013,-2.585}},
	A6 = {{2.292,2.074},{-2.409,1.610},{-0.074,3.264},{0.092,-0.066},{2.767,-1.364},{-2.884,-0.986},{0.013,-2.585}},
	A7 = {{2.292,2.074},{-2.409,1.610},{-0.074,3.264},{0.092,-0.066},{2.767,-1.364},{-2.884,-0.986},{0.013,-2.585}},
	A8 = {{2.292,2.074},{-2.409,1.610},{-0.074,3.264},{0.092,-0.066},{2.767,-1.364},{-2.884,-0.986},{0.013,-2.585}},
	X1 = {{3.780,2.646},{-4.213,1.680},{1.073,-4.037}},
	X2 = {{-3.738,-0.089},{3.843,-0.074},{-1.673,-3.388},{2.521,-3.860}},
	X3 = {{0.021,2.368}},
	X4 = {{-3.738,-0.089},{3.859,-0.074}}
}

---------------------- DEMONWEB ROTATION OPTIMIZATION ("maximize connections" rule)
-- Digitized directly from each tile's printed art (looking at the actual images, not derived from the
-- connector-ring data above, since those rings are just bend-markers along a tunnel path, not a reliable
-- per-edge signal): which of a hex's 6 edges has a tunnel reaching the border there, at the tile's own
-- native (unrotated) printed orientation. Edge names follow the same 6 neighbor directions already used
-- for slot layout (N/NE/SE/S/SW/NW, 60 degrees apart) - see demonwebEdgeWorldDir below for how a tile's
-- actual placement rotation maps these raw/printed edges onto those 6 world directions.
-- A4-A8 (shared decorative template) and most named-site hexes print a tunnel reaching every edge; only a
-- handful of tiles (mostly the smaller C/X connector hexes) have genuine dead ends.
demonwebEdgeConnByTile = {
	A1 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	A2 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	A3 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	A4 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	A5 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	A6 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	A7 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	A8 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	A9 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	B1 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	B2 = {N=true,  NE=true,  SE=true,  S=false, SW=true,  NW=true},
	B3 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	B4 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	B5 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	B6 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	C1 = {N=true,  NE=true,  SE=true,  S=true,  SW=false, NW=false},
	C2 = {N=false, NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	C3 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	C4 = {N=false, NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	C5 = {N=true,  NE=true,  SE=false, S=true,  SW=false, NW=false},
	C6 = {N=true,  NE=false, SE=true,  S=true,  SW=true,  NW=true},
	C7 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	C8 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	X1 = {N=false, NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	X2 = {N=false, NE=true,  SE=true,  S=true,  SW=true,  NW=true},
	X3 = {N=false, NE=true,  SE=false, S=true,  SW=false, NW=true},
	X4 = {N=true,  NE=true,  SE=true,  S=true,  SW=true,  NW=true}
}

-- the 6 neighbor directions, 60 degrees apart, in the same clockwise order TTS rotates a placed tile's
-- texture (rotY clockwise-positive) - rotating a tile by +60 degrees shifts every one of its raw/printed
-- edges one step forward in this list (N->NE->SE->S->SW->NW->N)
demonwebDirCycle = {'N', 'NE', 'SE', 'S', 'SW', 'NW'}
demonwebDirIndex = {N=1, NE=2, SE=3, S=4, SW=5, NW=6}
demonwebOppositeDir = {N='S', NE='SW', SE='NW', S='N', SW='NE', NW='SE'}

-- true if hexId, placed at world rotation rotY (a multiple of 60), has a tunnel connection facing the
-- given WORLD direction (one of demonwebDirCycle) - i.e. maps rotY back to whichever raw/printed edge
-- ends up facing that way, then looks that edge up in demonwebEdgeConnByTile
function demonwebHasConnectionFacing(hexId, worldDir, rotY)
	local conn = demonwebEdgeConnByTile[hexId]
	if conn == nil then return false end
	local worldIdx = demonwebDirIndex[worldDir]
	local shift = math.floor((rotY / 60) + 0.5) % 6
	local rawIdx = ((worldIdx - 1 - shift) % 6 + 6) % 6 + 1
	return conn[demonwebDirCycle[rawIdx]] == true
end

-- exact edge-neighbor adjacency for each modular layout - every pair of slots whose hexes sit truly
-- edge-to-edge (distance R*sqrt(3) apart), tagged with the world direction from the first slot to the
-- second (computed directly from demonweb2Player/3Player/4PlayerSlots, not hand-guessed - a slot not
-- listed as anyone's neighbor here just has fewer possible connections, same as a real board edge)
demonweb2PlayerAdjacency = {
	{a='a', b='c_n1', dir='SW'}, {a='a', b='c_n2', dir='S'}, {a='a', b='c_n3', dir='SE'},
	{a='a', b='c_s1', dir='NW'}, {a='a', b='c_s2', dir='N'}, {a='a', b='c_s3', dir='NE'},
	{a='c_n1', b='c_n2', dir='SE'}, {a='c_n1', b='c_s1', dir='N'},
	{a='c_n2', b='c_n3', dir='NE'}, {a='c_n2', b='b2', dir='SE'},
	{a='c_n3', b='c_s3', dir='N'}, {a='c_n3', b='b2', dir='S'},
	{a='c_s1', b='c_s2', dir='NE'}, {a='c_s1', b='b1', dir='N'},
	{a='c_s2', b='c_s3', dir='SE'}, {a='c_s2', b='b1', dir='NW'}
}
demonweb3PlayerAdjacency = {
	{a='a', b='c_n1', dir='SW'}, {a='a', b='c_n2', dir='S'}, {a='a', b='c_n3', dir='SE'},
	{a='a', b='c_s1', dir='NW'}, {a='a', b='c_s2', dir='N'}, {a='a', b='c_s3', dir='NE'},
	{a='c_n1', b='c_n2', dir='SE'}, {a='c_n1', b='c_s1', dir='N'}, {a='c_n1', b='b3', dir='S'},
	{a='c_n2', b='c_n3', dir='NE'}, {a='c_n2', b='b3', dir='SW'},
	{a='c_n3', b='c_s3', dir='N'}, {a='c_n3', b='b2', dir='NE'},
	{a='c_s1', b='c_s2', dir='NE'}, {a='c_s1', b='b1', dir='N'},
	{a='c_s2', b='c_s3', dir='SE'}, {a='c_s2', b='b1', dir='NW'},
	{a='c_s3', b='b2', dir='SE'}
}
demonweb4PlayerAdjacency = {
	{a='a', b='c_n1', dir='SW'}, {a='a', b='c_n2', dir='S'}, {a='a', b='c_n3', dir='SE'},
	{a='a', b='c_s1', dir='NW'}, {a='a', b='c_s2', dir='N'}, {a='a', b='c_s3', dir='NE'},
	{a='c_n1', b='c_n2', dir='SE'}, {a='c_n1', b='c_s1', dir='N'},
	{a='c_n1', b='corner180', dir='NW'}, {a='c_n1', b='corner240', dir='S'},
	{a='c_n2', b='c_n3', dir='NE'}, {a='c_n2', b='corner240', dir='SW'},
	{a='c_n2', b='corner300', dir='SE'}, {a='c_n2', b='c7', dir='S'},
	{a='c_n3', b='c_s3', dir='N'}, {a='c_n3', b='corner0', dir='NE'}, {a='c_n3', b='corner300', dir='S'},
	{a='c_s1', b='c_s2', dir='NE'}, {a='c_s1', b='b1', dir='N'}, {a='c_s1', b='corner180', dir='SW'},
	{a='c_s2', b='c_s3', dir='SE'}, {a='c_s2', b='b1', dir='NW'},
	{a='c_s2', b='corner60', dir='NE'}, {a='c_s2', b='c8', dir='N'},
	{a='c_s3', b='corner0', dir='SE'}, {a='c_s3', b='corner60', dir='N'},
	{a='b1', b='c8', dir='NE'},
	{a='corner60', b='c8', dir='NW'},
	{a='corner240', b='c7', dir='SE'}, {a='corner300', b='c7', dir='SW'}
}

-- given the tile assigned to each slot, picks a rotation (multiple of 60) per slot to maximize the number
-- of edge-to-edge tunnel connections with already-decided neighbors, implementing the rulebook rotation
-- rule ("each hex should be rotated to make the maximum number of connections with other hexes"). Slots in
-- fixedRotations (B1, the fixed Menzoberranzan anchor) keep that rotation untouched, exactly as before.
-- Processes remaining slots greedily, each time picking whichever undecided slot currently has the most
-- already-decided neighbors (so later picks have the most information to optimize against) - not a true
-- global optimum, but a close, simple, and fast approximation well suited to these small layouts.
-- Dispute resolution ("if there is a dispute... the owner decides, then clockwise around the table other
-- players may decide") is simplified to an automatic random pick among the tied-best rotations, per design
-- discussion - implementing real seat-by-seat player choice would need its own turn/UI flow.
function demonwebOptimizeRotations(hexBySlot, adjacency, fixedRotations)
	local neighborsOf = {}
	for slotName, _ in pairs(hexBySlot) do neighborsOf[slotName] = {} end
	for _, edge in ipairs(adjacency) do
		if hexBySlot[edge.a] ~= nil and hexBySlot[edge.b] ~= nil then
			table.insert(neighborsOf[edge.a], {other = edge.b, dir = edge.dir})
			table.insert(neighborsOf[edge.b], {other = edge.a, dir = demonwebOppositeDir[edge.dir]})
		end
	end

	local rotationBySlot = {}
	local remaining = {}
	for slotName, _ in pairs(hexBySlot) do
		if fixedRotations[slotName] ~= nil then
			rotationBySlot[slotName] = fixedRotations[slotName]
		else
			table.insert(remaining, slotName)
		end
	end

	local rotationChoices = {0, 60, 120, 180, 240, 300}
	while #remaining > 0 do
		local bestSlotIdx, bestSlot, bestKnown = nil, nil, -1
		for i, s in ipairs(remaining) do
			local known = 0
			for _, nb in ipairs(neighborsOf[s]) do
				if rotationBySlot[nb.other] ~= nil then known = known + 1 end
			end
			if known > bestKnown then bestKnown = known; bestSlot = s; bestSlotIdx = i end
		end

		local hexId = hexBySlot[bestSlot]
		local bestScore, bestRots = -1, {}
		for _, rotY in ipairs(rotationChoices) do
			local score = 0
			for _, nb in ipairs(neighborsOf[bestSlot]) do
				local otherRot = rotationBySlot[nb.other]
				if otherRot ~= nil then
					local otherHexId = hexBySlot[nb.other]
					if demonwebHasConnectionFacing(hexId, nb.dir, rotY)
						and demonwebHasConnectionFacing(otherHexId, demonwebOppositeDir[nb.dir], otherRot) then
						score = score + 1
					end
				end
			end
			if score > bestScore then
				bestScore = score
				bestRots = {rotY}
			elseif score == bestScore then
				table.insert(bestRots, rotY)
			end
		end
		rotationBySlot[bestSlot] = bestRots[math.random(#bestRots)]
		table.remove(remaining, bestSlotIdx)
	end

	return rotationBySlot
end

function demonwebSpawnSites(slots, hexBySlot, rotationBySlot)
	local allSnapPoints = {}
	for slotName, hexId in pairs(hexBySlot) do
		local slot = slots[slotName]
		local hexWorldX = demonwebOrigin[1] + slot[1]
		local hexWorldZ = demonwebOrigin[3] + slot[2]
		local hexRot = (rotationBySlot and rotationBySlot[slotName]) or slot[3]
		-- every digitized coordinate below (connector rings, circles, spyOffsets, markerPos) was measured
		-- at demonwebHexArtReferenceScale - scale by this ratio so they still land on the right spot on the
		-- printed art if demonwebHexScale is changed from that reference
		local hexArtScale = demonwebHexScale / demonwebHexArtReferenceScale

		-- each tile's connector-tunnel rings (if digitized) get a snap point too, same as site circles.
		-- Tagged 'troop' (rather than left untagged) so spy-tagged figures don't also get pulled toward
		-- these - an untagged snap point accepts any object regardless of its own tags.
		local connectorRings = demonwebConnectorRingsByTile[hexId]
		if connectorRings ~= nil then
			for _, d in ipairs(connectorRings) do
				local rx, rz = demonwebRotateLocal(d[1] * hexArtScale, d[2] * hexArtScale, hexRot - 180)
				local wx, wz = hexWorldX + rx, hexWorldZ + rz
				table.insert(allSnapPoints, {
					position = {wx - demonwebOrigin[1], 5.3, wz - demonwebOrigin[3]},
					rotation = {0, 0, 0},
					rotation_snap = false,
					tags = {'troop'}
				})
			end
		end
		
		local sites = demonwebSiteData[hexId]
		if sites ~= nil then
			for _, site in ipairs(sites) do
				-- rotate + place every circle, and track the average for the zone's own position
				local worldCircles = {}
				local sumX, sumZ = 0, 0
				for _, c in ipairs(site.circles) do
					-- local offsets were measured from the source artwork, which already reads correctly at
					-- rotation 180 (not 0) - so only the rotation BEYOND that baseline needs to be applied
					local rx, rz = demonwebRotateLocal(c[1] * hexArtScale, c[2] * hexArtScale, hexRot - 180)
					local wx, wz = hexWorldX + rx, hexWorldZ + rz
					table.insert(worldCircles, {wx, wz})
					sumX = sumX + wx
					sumZ = sumZ + wz
					-- local offset from the shared, unrotated, unscaled snap-point anchor (see below) is just
					-- the plain world-space difference - no rotation or scale math needed, since the anchor
					-- itself sits at rotation 0 / scale 1. The anchor is tucked 5 units below the table, so
					-- add that back for the Y component to land the snap point at the right height. Tagged
					-- 'troop' for the same cross-snapping reason as the connector rings above.
					table.insert(allSnapPoints, {
						position = {wx - demonwebOrigin[1], 5.3, wz - demonwebOrigin[3]},
						rotation = {0, 0, 0},
						rotation_snap = false,
						tags = {'troop'}
					})
				end
				local centerX = sumX / #worldCircles
				local centerZ = sumZ / #worldCircles
				
				-- 4 spy snap points per site, in a row above the troop circles: point 1 shares the same local
				-- X as the site's first troop circle, and the rest continue rightward from there, spaced by
				-- distance scaled to the spy figures' own size (currently 2/2/2, scaled down proportionally
				-- from the standard board's 3.5-scale figures and their measured 1.7 spacing / 1.74 offset).
				-- Computed before the zone footprint below, since the zone's detection radius has to reach
				-- the spy points too (otherwise a spy sitting on its point can fall just outside a small
				-- 1-2 circle site's radius and silently fail to block total control there).
				-- A site can override the 4 X-offsets entirely via site.spyOffsets (measured directly
				-- in-game) - needed for layouts the default "row starting at the first circle" formula
				-- doesn't fit, like A9's 3x3 grid, where it drifted the spy row away from the card.
				local localMaxZ = nil
				for _, c in ipairs(site.circles) do
					local scaledZ = c[2] * hexArtScale
					if localMaxZ == nil or scaledZ > localMaxZ then localMaxZ = scaledZ end
				end
				-- spySpacing/spyZOffsetBase are sized to the spy FIGURE itself (spyScale), not to the hex
				-- art, so they deliberately do NOT get hexArtScale applied - a bigger hex doesn't mean a
				-- bigger spy piece
				local spyScale = 3
				local spySpacing = 1.7 * (spyScale / 3.5)
				local spyZOffsetBase = 1.74 * (spyScale / 3.5)
				local firstCircleX = site.circles[1][1] * hexArtScale
				local spyZ = localMaxZ + spyZOffsetBase + (site.spyZOffset or 0) * hexArtScale
				local localSpyPoints = {}
				if site.spyOffsets ~= nil then
					for _, ox in ipairs(site.spyOffsets) do
						table.insert(localSpyPoints, {ox * hexArtScale, spyZ})
					end
				else
					localSpyPoints = {
						{firstCircleX, spyZ},
						{firstCircleX + spySpacing, spyZ},
						{firstCircleX + spySpacing * 2, spyZ},
						{firstCircleX + spySpacing * 3, spyZ}
					}
				end
				local worldSpyPoints = {}
				for _, sp in ipairs(localSpyPoints) do
					local rx, rz = demonwebRotateLocal(sp[1], sp[2], hexRot - 180)
					local wx, wz = hexWorldX + rx, hexWorldZ + rz
					table.insert(worldSpyPoints, {wx, wz})
					table.insert(allSnapPoints, {
						position = {wx - demonwebOrigin[1], 5.3, wz - demonwebOrigin[3]},
						rotation = {0, 0, 0},
						rotation_snap = false,
						tags = {'spy'}
					})
				end
				
				-- troop-detection radius only needs to cover the circles themselves - it stays tight even for
				-- a single-circle site, unlike an earlier version that also stretched it out to reach the spy
				-- points (whose row, for a 1-circle site, extends several units in one direction), which let
				-- the zone reach all the way to a neighboring connector-ring position and wrongly claim a
				-- troop/spy sitting there. Spies are matched separately below, against their own points.
				local maxDist = 0
				for _, wc in ipairs(worldCircles) do
					local d = math.sqrt((wc[1]-centerX)^2 + (wc[2]-centerZ)^2)
					if d > maxDist then maxDist = d end
				end
				local zoneFootprint = maxDist * 2 + 2.5	-- generous margin on each side of the farthest circle
				
				local zone = spawnObject({
					type = 'ScriptingTrigger',
					-- Y range trimmed further still. Checked the standard board's own equivalent site zones
					-- (baked into standardBoardObjectJSON) for comparison: they're only 1-2 units tall
					-- (scaleY), sitting barely above the table - nothing like the 8 (let alone the original
					-- 15) used here. Matching that scale now: enough headroom for a modest stack of troops,
					-- nowhere near tall/wide enough to be the first thing a downward camera ray hits.
					position = {centerX, demonwebOrigin[2] + 1.5, centerZ},
					scale = {zoneFootprint, 3, zoneFootprint},
					callback_function = function(obj)
						obj.setName(tostring(#site.circles))
						obj.setDescription(tostring(site.points))
						obj.setGMNotes(site.name)
						obj.addTag('demonweb')
						obj.setLock(true)	-- matches the standard board's own site zones (Locked=true) - an
											-- unlocked ScriptingTrigger can drift slightly from physics
											-- interaction with nearby pieces, silently pulling it away from
											-- the troops it's supposed to be detecting
						-- THE likely real culprit for the whole "hex isn't considered hovered" saga: this
						-- zone spans a big chunk of the hex both in footprint (zoneFootprint, generous
						-- margin around the site's circles) and in height (Y 1.6 to 9.6 even after the
						-- earlier trim from 15 to 8) - tall and wide enough that a downward camera ray
						-- likely hits THIS object before it ever reaches the hex tile or the hover-catcher
						-- plate sitting just above it, no matter how solid/opaque/fully-fielded we make
						-- those. TTS's `interactable` property specifically governs "if the object can be
						-- interacted with by Players" (as opposed to Locked, which only blocks
						-- moving/rotating it) - turning it off here should let mouse/hover input pass
						-- through this trigger to whatever is physically underneath, while the zone keeps
						-- doing its actual job (getObjects()-based troop/spy detection, which relies on
						-- physics overlap, not on player interaction) untouched.
						obj.interactable = false
						table.insert(demonwebSpawnedGuids, obj.getGUID())
						table.insert(demonwebActiveSiteZoneGuids, obj.getGUID())
						demonwebSiteGeometry[obj.getGUID()] = {
							x = centerX, z = centerZ, radius = zoneFootprint / 2,
							spyPoints = worldSpyPoints,
							troopSpaces = #site.circles, points = site.points, name = site.name
						}
						
						-- one of the 7 "named" sites with a physical control-marker token? spawn it now that
						-- we have the zone's guid to link it to
						local markerData = demonwebMarkerData[hexId]
						if markerData ~= nil and markerData.siteName == site.name then
							local variant = markerData.variants[math.random(1, #markerData.variants)]
							-- the physical marker rests in the middle of the hub ring itself (where the
							-- printed "COUNCIL CHAMBER"-style ring text arcs around), not at the troop
							-- circles' average - confirmed via an in-game coordinate measurement.
							-- markerPos, when set on a hex's demonwebMarkerData entry, overrides this with an
							-- exact absolute world position instead (used for A1/A3, whose 'Great Web' site
							-- always lands on the fixed center 'a' slot regardless of generation, so a literal
							-- measured world coordinate is valid every time)
							local markerX, markerY, markerZ = hexWorldX, demonwebOrigin[2] + 0.4, hexWorldZ
							if markerData.markerPos ~= nil then
								-- markerPos is an absolute world coordinate measured at demonwebHexArtReferenceScale,
								-- with the hex sitting at rotation 180 (the only rotation the 'a' slot ever used
								-- before rotation-optimization was added). Convert to an origin-relative offset,
								-- scale that by hexArtScale like every other digitized coordinate, then rotate it
								-- by however far the tile's ACTUAL placement rotation is from that 180 baseline -
								-- otherwise the marker (and its snap point below) stays stuck at the old fixed spot
								-- and drifts off the printed ring whenever the hex ends up rotated to something
								-- else. Re-applied around the hex's own center, not the origin, in case markerPos
								-- is ever used on a non-center slot. Y (height) has nothing to do with rotation.
								local relX = (markerData.markerPos[1] - demonwebOrigin[1]) * hexArtScale
								local relZ = (markerData.markerPos[3] - demonwebOrigin[3]) * hexArtScale
								local rx, rz = demonwebRotateLocal(relX, relZ, hexRot - 180)
								markerX = hexWorldX + rx
								markerY = markerData.markerPos[2]
								markerZ = hexWorldZ + rz
							end
							-- a 'control'-tagged snap point right there too, so a player-moved marker can
							-- snap cleanly back onto its hex center, the same way troops/spies do
							table.insert(allSnapPoints, {
								position = {markerX - demonwebOrigin[1], 5.3, markerZ - demonwebOrigin[3]},
								rotation = {0, 0, 0},
								rotation_snap = false,
								tags = {'control'}
							})
							-- built as one fully-formed JSON blob and spawned via spawnObjectJSON, matching
							-- how demonwebSpawnStandardBoard() brings back the standard board's own markers -
							-- position/rotation/Locked are baked in from the very first frame the object
							-- exists, so there's no spawn-then-reposition window for physics to displace it in
							local markerJSON = JSON.encode({
								Name = 'Custom_Tile',
								Transform = {
									posX = markerX, posY = markerY, posZ = markerZ,
									rotX = 0, rotY = 180, rotZ = 0,
									-- marker's own physical size scaled too, so it stays proportional to the
									-- bigger/smaller printed ring it sits in
									scaleX = 2.2 * hexArtScale, scaleY = 1.0, scaleZ = 2.2 * hexArtScale
								},
								Nickname = site.name,
								Description = '',
								GMNotes = '',
								Locked = false,
								Grid = true,
								Snap = true,
								Tags = {'demonweb', 'control'},
								CustomImage = {
									ImageURL = markerData.controlImage,
									ImageSecondaryURL = variant.image,
									ImageScalar = 1.0,
									WidthScale = 0.0,
									CustomTile = {Type = 2, Thickness = 0.1, Stackable = false, Stretch = true}
								}
							})
							spawnObjectJSON({
								json = markerJSON,
								callback_function = function(marker)
									table.insert(demonwebSpawnedGuids, marker.getGUID())
									table.insert(demonwebActiveMarkers, {
										guid = marker.getGUID(), siteZoneGuid = obj.getGUID(), vp = variant.vp,
										homePos = {markerX, markerY, markerZ}
									})
								end
							})

							-- "Take" button, on its own small dedicated helper object spawned right at the hex
							-- center (not on the site zone via a scaled local offset - that math turned out
							-- unreliable - and not on the marker itself, which can render through/behind it from
							-- some angles). A tiny, invisible, locked ScriptingTrigger with no rotation makes the
							-- button's own position/rotation params behave as plain world-aligned values.
							spawnObject({
								type = 'ScriptingTrigger',
								position = {markerX, 1.7, markerZ},	-- fixed Y, below the marker so the
																		-- button renders under it
								rotation = {0, 0, 0},
								scale = {1, 1, 1},	-- kept at 1 (not tiny) since a button's width/height also get
												-- scaled by their parent object's own scale - a small scale
												-- here would shrink the button itself down to nothing
								callback_function = function(helper)
									helper.setLock(true)
									helper.addTag('demonweb')
									table.insert(demonwebSpawnedGuids, helper.getGUID())
									helper.createButton({
										function_owner = self,
										label = 'Take',
										click_function = 'demonwebTakeControlMarker' .. obj.getGUID(),
										position = {0, 0, 0},
										rotation = {0, 180, 0},
										width = 1398, height = 762, font_size = 402
									})
								end
							})
							
							_G['demonwebTakeControlMarker' .. obj.getGUID()] = function(clickedObj, clickColor, alt)
								for _, markerInfo in ipairs(demonwebActiveMarkers) do
									if markerInfo.siteZoneGuid == obj.getGUID() then
										demonwebMoveControlMarker(clickColor, markerInfo, {}, true)
										break
									end
								end
							end
						end
					end
				})
				
				for i = 1, site.initialTroops do
					local pos = worldCircles[i]
					local troopBag = getObjectFromGUID(whiteTroopBagGuid)
					if troopBag ~= nil then
						local troop = troopBag.takeObject({position = {pos[1], demonwebOrigin[2] + 0.4, pos[2]}, rotation = faceup})
						if troop ~= nil then
							troop.addTag('demonweb')
							table.insert(demonwebSpawnedGuids, troop.getGUID())
						end
					end
				end
			end
		end
	end
	
	-- one shared, invisible, never-rotated/never-scaled anchor object carries every digitized circle's snap
	-- point - since it has rotation {0,0,0} and scale {1,1,1}, a snap point's local position IS its world
	-- offset from demonwebOrigin, with no further math needed
	if #allSnapPoints > 0 then
		spawnObject({
			type = 'BlockSquare',
			position = {demonwebOrigin[1], demonwebOrigin[2] - 5, demonwebOrigin[3]},	-- tucked below the table, out of sight
			rotation = {0, 0, 0},
			scale = {1, 1, 1},	-- kept at 1 so local snap coordinates definitely aren't scaled, whatever TTS's
								-- exact behavior is here
			callback_function = function(obj)
				obj.setLock(true)
				obj.interactable = false
				obj.setSnapPoints(allSnapPoints)
				obj.addTag('demonweb')
				table.insert(demonwebSpawnedGuids, obj.getGUID())
			end
		})
	end
end

function demonwebClearBoard()
	for _, guid in ipairs(demonwebSpawnedGuids) do
		local obj = getObjectFromGUID(guid)
		if obj ~= nil then obj.destruct() end
	end
	demonwebSpawnedGuids = {}
	demonwebActiveSiteZoneGuids = {}
	demonwebActiveMarkers = {}
	demonwebSiteGeometry = {}
	-- belt-and-braces: also sweep for anything tagged 'demonweb' that the GUID list above might have missed
	-- (e.g. an orphaned object left over from clicking Generate again before a previous generation finished)
	for _, obj in ipairs(getObjectsWithTag('demonweb')) do
		obj.destruct()
	end
end

demonwebGenerationId = 0	-- bumped on every generation; delayed callbacks from a stale (superseded)
							-- generation check this and bail out, so clicking Generate again quickly can't
							-- leave orphaned tiles/anchors that a later clearBoard() never sees

function demonwebSpawnLayout(slots, hexBySlot, label, rotationBySlot)
	demonwebClearBoard()
	demonwebGenerationId = demonwebGenerationId + 1
	local myGenerationId = demonwebGenerationId

	local slotList = {}
	for slotName, hexId in pairs(hexBySlot) do
		table.insert(slotList, {slotName = slotName, hexId = hexId})
	end

	local summary = {}
	for i, entry in ipairs(slotList) do
		table.insert(summary, entry.hexId)
		Wait.time(function()
			if myGenerationId ~= demonwebGenerationId then return end	-- a newer generation started, skip
			local slot = slots[entry.slotName]
			local rotY = (rotationBySlot and rotationBySlot[entry.slotName]) or slot[3]
			local pos = {demonwebOrigin[1] + slot[1], demonwebOrigin[2], demonwebOrigin[3] + slot[2]}
			local url = demonwebHexDefs[entry.hexId]
			spawnObject({
				type = 'Custom_Tile',
				position = pos,
				rotation = {0, rotY, 0},
				scale = {demonwebHexScale, 1, demonwebHexScale},
				callback_function = function(obj)
					obj.setCustomObject({type = 1, image = url, thickness = 0.1, stretch = false})
					local reloaded = obj.reload()
					reloaded.addTag('demonweb')
					table.insert(demonwebSpawnedGuids, reloaded.getGUID())
				end
			})
		end, i * 0.3)
	end
	
	-- site zones/initial troops - placed once all hex tiles are down
	Wait.time(function()
		if myGenerationId ~= demonwebGenerationId then return end	-- a newer generation started, skip
		demonwebSpawnSites(slots, hexBySlot, rotationBySlot)
	end, (#slotList + 1) * 0.3)
	
	broadcastToAll('Demonweb map (' .. label .. ') generated: ' .. table.concat(summary, ', ') .. '. Site control/VP for this map is tracked manually for now.')
end

-- builds the shuffled pool of 6 hex IDs used for the ring slots. Normally that's exactly C1-C6; with the
-- "Demonweb X-Hexes" toggle on, X1/X2/X3/X4 join the pool too and 6 are picked at random from the larger set
-- (so on any given generation, some of C1-C6 may be left out in favor of an X-hex instead)
function demonwebBuildRingPool()
	local pool = {'C1','C2','C3','C4','C5','C6'}
	if UI.getAttribute('demonwebXHexes', 'isOn') == 'True' then
		for _, x in ipairs({'X1','X2','X3','X4'}) do table.insert(pool, x) end
	end
	for i = #pool, 2, -1 do
		local j = math.random(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local picked = {}
	for i = 1, 6 do table.insert(picked, pool[i]) end
	return picked
end

-- "Optimize Hex Rotation" toggle under Settings for Modular Board (off/False by default, matching the
-- reference mod - every slot but the fixed B1 anchor just gets its pre-authored fixed rotation, same as
-- before this feature existed). Switching it on applies the rulebook rotation rule instead (each hex
-- rotated to maximize its connections with already-placed neighbors - see demonwebOptimizeRotations).
function demonwebRotationOptimizeEnabled()
	return UI.getAttribute('demonwebOptimizeRotation', 'isOn') == 'True'
end

-- "Center: A1-A3 Only" toggle under Settings for Modular Board (off/False by default - center hex is drawn
-- from the full A1-A9 pool, same as before this setting existed). Switching it on restricts the center
-- hex draw to just A1/A2/A3 for every modular generation (2/3/4-player and TEST 4p alike).
function demonwebCenterHexChoices()
	if UI.getAttribute('demonwebCenterA1A3Only', 'isOn') == 'True' then
		return {'A1', 'A2', 'A3'}
	end
	return {'A1','A2','A3','A4','A5','A6','A7','A8','A9'}
end

function generateDemonwebMap2Player(player, value, id)
	-- intentionally not gated on isSeated()/seatedPlayerColors, since that's only populated after a normal
	-- menuStart game setup - this tool is meant to be usable standalone, before that.
	
	local aChoices = demonwebCenterHexChoices()
	local centerHex = aChoices[math.random(1, #aChoices)]
	
	-- ring pool: normally C1-C6, or a random 6-of-10 if X-hexes are enabled (see demonwebBuildRingPool)
	local cPool = demonwebBuildRingPool()
	
	local hexBySlot = {
		a = centerHex, b1 = 'B1', b2 = 'B2',
		c_n1 = cPool[1], c_n2 = cPool[2], c_n3 = cPool[3], c_s1 = cPool[4], c_s2 = cPool[5], c_s3 = cPool[6]
	}
	
	-- rotate each hex to make the maximum number of connections with its already-placed neighbors (rulebook
	-- rotation rule), if the "Optimize Hex Rotation" setting is on - B1 stays at its fixed anchor rotation
	-- either way. Off by default: rotationBySlot stays nil and demonwebSpawnLayout/demonwebSpawnSites fall
	-- back to each slot's own fixed pre-authored rotation, same as before this feature existed.
	local rotationBySlot = nil
	if demonwebRotationOptimizeEnabled() then
		rotationBySlot = demonwebOptimizeRotations(hexBySlot, demonweb2PlayerAdjacency, {b1 = 240})
	end

	-- Custom_Tiles spawning several with setCustomObject() in the very same frame can make TTS mix up which
	-- downloaded image lands on which tile, so demonwebSpawnLayout staggers them slightly instead
	demonwebSpawnLayout(demonweb2PlayerSlots, hexBySlot, '2-player', rotationBySlot)
end

function generateDemonwebMap3Player(player, value, id)
	-- intentionally not gated on isSeated()/seatedPlayerColors - see generateDemonwebMap2Player
	
	local aChoices = demonwebCenterHexChoices()
	local centerHex = aChoices[math.random(1, #aChoices)]
	
	local cPool = demonwebBuildRingPool()
	
	local hexBySlot = {
		a = centerHex, b1 = 'B1', b2 = 'B2', b3 = 'B3',
		c_n1 = cPool[1], c_n2 = cPool[2], c_n3 = cPool[3], c_s1 = cPool[4], c_s2 = cPool[5], c_s3 = cPool[6]
	}
	
	local rotationBySlot = nil
	if demonwebRotationOptimizeEnabled() then
		rotationBySlot = demonwebOptimizeRotations(hexBySlot, demonweb3PlayerAdjacency, {b1 = 240})
	end
	demonwebSpawnLayout(demonweb3PlayerSlots, hexBySlot, '3-player', rotationBySlot)
end

function generateDemonwebMap4Player(player, value, id)
	-- intentionally not gated on isSeated()/seatedPlayerColors - see generateDemonwebMap2Player
	
	local aChoices = demonwebCenterHexChoices()
	local centerHex = aChoices[math.random(1, #aChoices)]
	
	local cPool = demonwebBuildRingPool()
	
	-- all 5 remaining B-tiles (B1 is the fixed anchor) shuffled across the other 5 corners
	local bPool = {'B2','B3','B4','B5','B6'}
	for i = #bPool, 2, -1 do
		local j = math.random(1, i)
		bPool[i], bPool[j] = bPool[j], bPool[i]
	end
	
	local cExtraPool = {'C7','C8'}
	if math.random(2) == 1 then cExtraPool = {'C8','C7'} end
	
	local hexBySlot = {
		a = centerHex, b1 = 'B1',
		c_n1 = cPool[1], c_n2 = cPool[2], c_n3 = cPool[3], c_s1 = cPool[4], c_s2 = cPool[5], c_s3 = cPool[6],
		corner0 = bPool[1], corner60 = bPool[2], corner180 = bPool[3], corner240 = bPool[4], corner300 = bPool[5],
		c7 = cExtraPool[1], c8 = cExtraPool[2]
	}
	
	local rotationBySlot = nil
	if demonwebRotationOptimizeEnabled() then
		rotationBySlot = demonwebOptimizeRotations(hexBySlot, demonweb4PlayerAdjacency, {b1 = 240})
	end
	demonwebSpawnLayout(demonweb4PlayerSlots, hexBySlot, '4-player', rotationBySlot)
end
whiteTroopBagGuid = '0bca61'
vpBags = { left = {'f8e8d3', '15ab8b'}, right = {'cff01d', 'c5da77'} }
firstPlayerMarkerGuid = '6365bb'
rulesZoneGuids = {'a9ab7d', '0bce56'}

buttonZoneGuids = {'530012', '5a78a5'}
buttonText = { on = hexColors.Green .. 'ON[-]', off = hexColors.Red .. 'OFF[-]', autoSendToDiscard = 'Automatic\nDiscard and Draw\n', autoTotalControlVp = 'Automatic\nTotal Control VPs\n', promoteCounters = '# Promoted Cards\nCounters\n', trophyCounters = 'Trophy Hall + VP\nCounters\n', resourcePoolEnabled = 'Power/Influence\nResource Pool\n', showSitePoints = 'Show Current\nSite Control\nPoints', displayDecks = "Display Players' Decks" }
buttonMsg = { autoSendToDiscard = 'auto discard and draw', autoTotalControlVp = 'auto VP token delivery', promoteCounters = 'Inner Circle counters', trophyCounters = 'Trophy Hall counters', resourcePoolEnabled = 'Power/Influence resource pool' }
options = {
	autoSendToDiscard = true,
	autoTotalControlVp = true,
	promoteCounters = true,
	trophyCounters = true,
	resourcePoolEnabled = false,
	language = 1
}
timerSettings = {
	duration = 60		-- seconds allotted per player turn (configurable in-game, persisted on save)
}
status = {
	turn = nil,		-- tts bug: the player turn is not set correctly when loading/rewinding
	doneLoading = false,
	setupInProgress = false,
	gameState = 0,
	firstPlayerColor = nil,	-- who started the game - used so an end-game trigger mid-round can let the
							-- timer keep running until play comes back around to them, instead of cutting
							-- some players' turns short
	boardMode = 'standard',	-- 'standard' or 'modular' (Demonweb) - gates all the standard board's automatic
							-- site-control/VP logic off when modular is active, since that map is tracked
							-- manually; persisted across save/load
	ratingsAppliedThisGame = false,	-- guards against applying an ELO update more than once if "Calculate
										-- Scores" gets clicked again (e.g. "Recalculate Scores"); reset to
										-- false whenever a new game starts (see menuStartCoroutine)
	boardSectionsUsed = {'left', 'center', 'right'},
	checkingDeck = false,
	countingTrophies = {Red = false, Blue = false, Purple = false, Teal = false},
	shuffling = {Red = false, Blue = false, Purple = false, Teal = false},
	recruiting = {top1 = false, top2 = false, top3 = false, top4 = false, top5 = false, top6 = false, bottom2 = false, bottom3 = false, bottom4 = false},
	displayed = false,
	timer = {
		active = false,		-- whether the turn timer session is currently running (not persisted; always starts stopped)
		paused = false,		-- whether the countdown is temporarily frozen (session stays active, just not ticking)
		remaining = 0,		-- seconds left in the current player's turn
		epoch = 0,			-- guards against stale/overlapping countdown chains
		suppressNextTurnCleanup = false,	-- see passTurnDueToTimeout()/onPlayerTurn()
		pendingStop = false,	-- an end-game trigger fired mid-round; keep running until the first player's
							-- turn comes back around (see stopTurnTimerAtRoundEnd()), so every seated player
							-- gets the same number of timed turns this round
		numbersHidden = false	-- player preference: hide the countdown digits panel while the timer keeps
								-- running underneath (persisted across save/load)
	}
}

function onSave()
	local data = {seatedPlayerColors = seatedPlayerColors, options = options, turn = status.turn, gameState = status.gameState, boardSectionsUsed = status.boardSectionsUsed, displayed = status.displayed, timerSettings = timerSettings, firstPlayerColor = status.firstPlayerColor, timerNumbersHidden = status.timer.numbersHidden, boardMode = status.boardMode}
	--local data = nil
	return JSON.encode(data)
end

function onLoad(saveState)
	local loadedData = JSON.decode(saveState)
	if loadedData ~= nil then
		-- playerRatings intentionally not loaded from here anymore - ratingsApiUrl (a Google Sheet) is now
		-- the single source of truth, fetched fresh whenever ratings are shown or updated
	end
	if loadedData ~= nil and loadedData.seatedPlayerColors ~= nil then
		seatedPlayerColors = loadedData.seatedPlayerColors
		options = loadedData.options
		status.turn = loadedData.turn
		status.gameState = loadedData.gameState
		status.boardSectionsUsed = loadedData.boardSectionsUsed
		status.displayed = loadedData.displayed
		if loadedData.timerSettings ~= nil then timerSettings = loadedData.timerSettings end
		status.firstPlayerColor = loadedData.firstPlayerColor
		if loadedData.timerNumbersHidden ~= nil then status.timer.numbersHidden = loadedData.timerNumbersHidden end
		if loadedData.boardMode ~= nil then status.boardMode = loadedData.boardMode end
	end
	-- the timer session itself is never resumed automatically after a load/rewind; only the configured duration persists
	status.timer.active = false
	status.timer.pendingStop = false
	if TESTING then
		log(status)
		log(options)
	end
	
	for _, vars in pairs(playerVars) do
		local obj = getObjectFromGUID(vars.playMatGuid)
		if obj ~= nil then obj.interactable = false end
	end
	
	-- NOTE: these 4 actions are no longer registered via addHotkey under their OLD labels
	-- ('Assassinate/Devour' etc.) - they're hard-bound to number keys 2/3/4/5 for every player inside
	-- onObjectNumberTyped instead (see there), which needs no per-player setup. Re-registering under
	-- those same old labels would let a player's own previously-configured binding for that exact label
	-- intercept the physical key before it ever reaches onObjectNumberTyped, silently swallowing the
	-- keypress - this is exactly what caused the original "key 4 does nothing" report.

	-- Optional, additive, hover-independent hotkeys, all under new 'Demonweb: ...' labels (deliberately
	-- NOT reusing the old label text above, for the same collision reason). These don't replace anything -
	-- 2/3/4/5 and Numpad keep working exactly as before whether or not anyone touches this. What they add:
	-- a player can open Options -> Game Keys and bind ANY physical key (including plain top-row '1'/'5',
	-- which onObjectNumberTyped can only ever reach on the modular board when hovering something TTS
	-- recognizes - see the extensive comments on hotkeyPlaceOrReturnSpy/demonwebDeployTroopsAtPointer) to
	-- one of these. addHotkey's callback always fires on keypress and hands over the pointer position and
	-- hovered object directly, with no hover requirement gating whether it fires at all - unlike
	-- onScriptingButtonDown (also hover-independent, but permanently fixed to Numpad, not reassignable to
	-- a top-row key). Covers the same 10 actions the number row does: 1/6/7/8/9/10 troops, 2/3/4/5 context
	-- actions. Whether the hoverObj this hands to the 4 context actions is any more reliable than
	-- onObjectNumberTyped's own for a spy figure specifically is untested - worth confirming in play.
	-- clearHotkeys() first avoids piling up duplicate entries if onLoad runs more than once per TTS
	-- session (e.g. repeated Save & Play during testing).
	clearHotkeys()
	for _, n in ipairs({1, 6, 7, 8, 9, 10}) do
		local troopCount = n
		addHotkey('Demonweb: Deploy ' .. troopCount .. ' Troop' .. (troopCount == 1 and '' or 's'), function(playerColor, hoverObj, pointerPosition, isKeyUp)
			if isKeyUp then return end
			-- Deploy 1 Troop is dual-purpose, same pattern as Assassinate/Devour and Supplant/Promote:
			-- hovering any deck draws 1 card from it into hand instead of deploying a troop. Only applies
			-- to the count-1 hotkey, not 6/7/8/9/10 - those always deploy troops regardless of hover.
			if troopCount == 1 and hoverObj ~= nil and hoverObj.type == 'Deck' then
				hoverObj.deal(1, playerColor)
				return
			end
			demonwebDeployTroopsAtPointer(playerColor, troopCount)
		end)
	end
	addHotkey('Demonweb: Assassinate/Devour', function(playerColor, hoverObj, pointerPosition, isKeyUp)
		if isKeyUp then return end
		hotkeyAssassinateDevour(playerColor, hoverObj)
	end)
	addHotkey('Demonweb: Supplant/Promote', function(playerColor, hoverObj, pointerPosition, isKeyUp)
		if isKeyUp then return end
		hotkeySupplantPromote(playerColor, hoverObj)
	end)
	addHotkey('Demonweb: Return/Take', function(playerColor, hoverObj, pointerPosition, isKeyUp)
		if isKeyUp then return end
		hotkeyReturnTake(playerColor, hoverObj)
	end)
	addHotkey('Demonweb: Place/Return Spy', function(playerColor, hoverObj, pointerPosition, isKeyUp)
		if isKeyUp then return end
		hotkeyPlaceOrReturnSpy(playerColor, hoverObj)
	end)

	if status.gameState == 0 then
		menuToggle(true)
		local pos = getObjectFromGUID(halfDeckZones.custom).getPosition()
		Global.setVectorLines({
			{ points = {{pos.x-2.44, 1.5, pos.z-3.4}, {pos.x+2.44, 1.5, pos.z-3.4}, {pos.x+2.44, 1.5, pos.z+3.4}, {pos.x-2.44, 1.5, pos.z+3.4}, {pos.x-2.44, 1.5, pos.z-3.4}}, color = 'Pink', thickness = 0.16, rotation = {0,0,0} }
		})
	elseif status.gameState == 2 then
		if status.displayed then
			UI.setAttributes('displayDecks', {text =  buttonText.displayDecks, textColor = 'white', color = 'Grey'})
			UI.setAttributes('score', {text = 'Recalculate Scores', textColor = 'white', color = 'Grey'})
		end
		UI.setAttribute('calculateScoreMenu', 'active', true)
	end
	setupButtons()
	setupScoreboards()
	for _, object in ipairs(getObjects()) do
		addMenuItems(object)
	end
	if status.turn ~= nil and Turns.enable and Turns.turn_color ~= status.turn then Turns.turn_color = status.turn end
	setupTimerUI()
	if status.gameState >= 1 then
		UI.setAttribute('timerPanel', 'active', not status.timer.numbersHidden)
		UI.setAttribute('timerControlsPanel', 'active', true)
	end
	Wait.time(function() status.doneLoading = true end, 0.5)
end

---------------------- START MENU UI

function uiCheckboxToggle(player, value, id)
	UI.setAttribute(id, 'isOn', value)
end

function uiButtonColorToggle(player, value, id)
	local attributes = {textColor = 'white', color = 'Blue'}
	if value == 'disable' then attributes.color = 'Grey' end
	for halfdeck, _ in pairs(halfDeckZones) do
		UI.setAttributes(halfdeck, attributes)
	end
end

function menuToggle(option)
	local value = 'false'
	if option then value = 'true' end
	UI.setAttribute('optionsMenuLeft', 'active', value)
	UI.setAttribute('optionsMenuRight', 'active', value)
	UI.setAttribute('optionsMenuButtons', 'active', value)
end

function menuStart(player, value, id)
	status.setupInProgress = true
	local menuChoice = tonumber(value)
	
	-- get seated player colors
	local allColors = {'Red', 'Blue', 'Purple', 'Teal'}
	seatedPlayerColors = {}
	local notSeatedColors = {}
	
	local seatedPlayers = getSeatedPlayers()
	if TESTING then seatedPlayers = testingVars.seatedPlayers end
	
	for _, color in ipairs(allColors) do
		local seated = false
		for _, seatedPlayerColor in ipairs(seatedPlayers) do
			if seatedPlayerColor == color then
				seated = true
				table.insert(seatedPlayerColors, color)
				break
			end
		end
		if not seated then table.insert(notSeatedColors, color) end
	end
	if #seatedPlayerColors == 0 then
		broadcastToAll('All players must select colors before setup.')
		status.setupInProgress = false
		return
	end
	
	-- validate menu selections

	local enabled = {}
	local selected = {}
	local randomCount = {[4] = 6, [5] = 4}
	if menuChoice == 3 then
		selected.custom = true
		local deck = findDeck(getObjectFromGUID(halfDeckZones.custom))
		if deck == nil then
			broadcastToAll('Custom deck not found.')
			status.setupInProgress = false
			return
		end
	else
		for halfdeck, _ in pairs(halfDeckZones) do
			if UI.getAttribute(halfdeck, 'isOn') == 'True' then
				table.insert(enabled, halfdeck)
				selected[halfdeck] = true
			end
		end
		if randomCount[menuChoice] ~= nil then
			local n = randomCount[menuChoice]
			if #enabled < n then
				broadcastToAll('Enable at least ' .. n .. ' half-decks.')
				status.setupInProgress = false
				return
			end
			selected = {}
			for i=1, n do
				local rand = math.random(1, #enabled)
				selected[enabled[rand]] = true
				table.remove(enabled, rand)
			end
		else
			if #enabled < 2 then
				broadcastToAll('Enable at least two half-decks.')
				status.setupInProgress = false
				return
			elseif #enabled == 2 then
				menuChoice = 1
			end
			
			if menuChoice == 1 and #enabled > 2 then
				selected = {}
				for i=1, 2 do
					local rand = math.random(1, #enabled)
					selected[enabled[rand]] = true
					table.remove(enabled, rand)
				end
			end
		end
	end
	
	function menuStartCoroutine()
		menuToggle(false)
		if TESTING then log(options) end
		math.randomseed(os.time())
		status.ratingsAppliedThisGame = false
		
		-- board choice: Standard spawns the built-in board/markers/zones fresh from their saved JSON (they
		-- don't exist in the save at all otherwise); Modular generates a Demonweb layout sized to how many
		-- players are seated. Either way, status.boardMode gates the OTHER board's automatic site-control
		-- logic off entirely, and any leftover objects from the other mode are cleaned up first.
		if UI.getAttribute('boardModular', 'isOn') == 'True' then
			status.boardMode = 'modular'
			demonwebDestroyStandardBoard()
			local playerCount = #seatedPlayerColors
			if playerCount <= 2 then generateDemonwebMap2Player(nil, nil, nil)
			elseif playerCount == 3 then generateDemonwebMap3Player(nil, nil, nil)
			else generateDemonwebMap4Player(nil, nil, nil)
			end
		else
			status.boardMode = 'standard'
			demonwebClearBoard()
			demonwebSpawnStandardBoard()
			wait(0.5)	-- let the freshly spawned board/markers/zones finish loading before anything downstream
						-- (e.g. the board-state switch just below) tries to use them
		end
		
		-- delete unused player objects
		for _, playerColor in ipairs(notSeatedColors) do
			local vars = playerVars[playerColor]
			for _, object in ipairs(getObjectFromGUID(vars.allZoneGuid).getObjects()) do
				object.destruct()
			end
			getObjectFromGUID(vars.circleZoneGuid).destruct()
			getObjectFromGUID(vars.trophyZoneGuid).destruct()
		end
		
		-- switch board
		local boardState = 1
		local boardSectionsNotUsed = {}
		if #seatedPlayerColors == 2 then
			boardState = 2
			status.boardSectionsUsed = {'center'}
			boardSectionsNotUsed = {'left', 'right'}
		elseif #seatedPlayerColors == 3 then
			boardState = math.random(3,4)
			if boardState == 3 then
				status.boardSectionsUsed = {'left', 'center'}
				boardSectionsNotUsed = {'right'}
			else
				status.boardSectionsUsed = {'center', 'right'}
				boardSectionsNotUsed = {'left'}
			end
		end
		
		local boardZone = getObjectFromGUID(boardSections.left.controlMarkers[1].buttonZoneGuid)
		if status.boardMode == 'standard' then
			for _, object in ipairs(boardZone.getObjects()) do
				if object.getDescription() == 'Board' then
					if object.getStateId() ~= boardState then object.setState(boardState) end
					break
				end
			end
		end
		Global.setVectorLines({})
		
		-- decks and rules no longer carry alternate-language States (Spanish/Polish were removed - English
		-- only now), so there is nothing left to switch here; setDeckState only deletes unselected half-decks
		function setDeckState(zoneGuid, delete)
			local deck = findDeck(getObjectFromGUID(zoneGuid))
			if deck ~= nil and delete then deck.destruct() end
		end
		for halfdeck, guid in pairs(halfDeckZones) do
			if not selected[halfdeck] then setDeckState(guid, true) end
		end
		wait(0.5)
		
		-- wait for board and decks to finish spawning
		local halfDecks = {}
		local spawningObjects = {}
		if status.boardMode == 'standard' then
			for _, object in ipairs(boardZone.getObjects()) do
				if object.getDescription() == 'Board' then table.insert(spawningObjects, object) break end
			end
		end
		for halfdeck, _ in pairs(selected) do
			local deck = findDeck(getObjectFromGUID(halfDeckZones[halfdeck]))
			if deck == nil then broadcastToAll(halfdeck .. ' half-deck not found. Please reload the mod.') return end
			halfDecks[halfdeck] = deck
			table.insert(spawningObjects, deck)
		end
		for _, playerColor in ipairs(seatedPlayerColors) do
			local deck = findDeck(getObjectFromGUID(playerVars[playerColor].deckZoneGuid))
			if deck ~= nil then table.insert(spawningObjects, deck) end
		end
		if UI.getAttribute('housePowers', 'isOn') == 'True' then
			local housePowerDeck = findDeck(getObjectFromGUID(housePowersZoneGuid))
			if housePowerDeck ~= nil then table.insert(spawningObjects, housePowerDeck) end
		end
		
		function checkDoneSpawning()
			for _, object in ipairs(spawningObjects) do
				if object.spawning or object.loading_custom then return false end
			end
			return true
		end
		repeat coroutine.yield(0) until checkDoneSpawning()
		
		-- merge selected half-decks
		local fullDeck = nil
		local deckNames = {}
		for halfdeck, deck in pairs(halfDecks) do
			if fullDeck == nil then
				fullDeck = deck
				fullDeck.setName('')
			else
				fullDeck = fullDeck.putObject(deck)
			end
			table.insert(deckNames, halfdeck)
		end
		local deckNamesText = hexColors.Pink .. table.concat(deckNames, '[-], ' .. hexColors.Pink) .. '[-]'
		if menuChoice == 1 then broadcastToAll('Starting game with ' .. deckNamesText .. '.')
		elseif menuChoice == 2 then broadcastToAll('Starting game with '.. hexColors.Pink .. '80 random cards[-] from enabled half-decks.')
		elseif menuChoice == 4 then broadcastToAll('Starting game with ' .. hexColors.Pink .. '80 random cards[-] from 6 random half-decks: ' .. deckNamesText .. '.')
		elseif menuChoice == 5 then broadcastToAll('Starting game with ' .. hexColors.Pink .. '80 random cards[-] from 4 random half-decks: ' .. deckNamesText .. '.')
		else broadcastToAll('Starting game with 80 random cards from ' .. hexColors.Pink .. 'custom deck[-].')
		end
		wait(0.5)
		
		-- place unaligned white troops (standard board only - the modular board tracks its own separately)
		if status.boardMode == 'standard' then
			local troopBag = getObjectFromGUID(whiteTroopBagGuid)
			for _, section in ipairs(status.boardSectionsUsed) do
				for _, toPos in ipairs(boardSections[section].whiteTroopPositions) do
					troopBag.takeObject({position = toPos, rotation = faceup})
				end
			end
			for _, section in ipairs(boardSectionsNotUsed) do
				for _, controlMarker in ipairs(boardSections[section].controlMarkers) do
					getObjectFromGUID(controlMarker.guid).destruct()
				end
			end
			wait(0.2)
			troopBag.destruct()
		end
		
		-- deal House Power cards (optional): one permanent artifact-style card per seated player, kept for the whole game
		if UI.getAttribute('housePowers', 'isOn') == 'True' then
			local housePowerDeck = findDeck(getObjectFromGUID(housePowersZoneGuid))
			if housePowerDeck ~= nil then
				housePowerDeck.shuffle()
				wait(0.32)
				for _, playerColor in ipairs(seatedPlayerColors) do
					housePowerDeck.takeObject({position = playerVars[playerColor].housePowerPosition, rotation = faceup, smooth = false})
				end
				wait(0.3)
				-- remove the leftover, undealt House Power cards from the table once everyone has theirs
				local leftover = findDeck(getObjectFromGUID(housePowersZoneGuid))
				if leftover ~= nil then leftover.destruct() end
			end
		end
		
		-- alternate site-control marker art (optional, cosmetic only). Every game start re-applies a look to
		-- all 7 site markers (standard, or a freshly randomized alt variant) so this is correct regardless of
		-- what a previous game in the same session left them showing. Reset the VP-suppression tracking first.
		altMarkerVpDisabled = {}
		local altMarkersOn = UI.getAttribute('altMarkers', 'isOn') == 'True'
		local markerGuids = {}
		for guid, _ in pairs(altMarkerData) do table.insert(markerGuids, guid) end
		for _, guid in ipairs(markerGuids) do
			if altMarkersOn then setAltMarkerLook(guid, math.random(1, 3))
			else setAltMarkerLook(guid, nil)
			end
		end
		
		-- fill market
		wait(0.6)
		local marketZone = getObjectFromGUID(market.bottom[1])
		local marketPos = marketZone.getPosition()
		if menuChoice == 1 or fullDeck.getQuantity() <= 80 then
			fullDeck.setRotation(facedown)
			fullDeck.setPositionSmooth({marketPos[1], 1.99, marketPos[3]}, false, true)
			wait(0.4)
		elseif menuChoice == 2 or menuChoice == 4 or menuChoice == 5 then
			fullDeck.shuffle()
			wait(0.32)
			fullDeck.shuffle()
			wait(0.5)
			
			local chosenCards = {}
			local aspects = {m=0, g=0, c=0, a=0}
			for _, card in ipairs(fullDeck.getObjects()) do
				local aspect = string.sub(card.gm_notes, 5, 5)
				if aspects[aspect] < 20 and string.len(card.gm_notes) < 6 then
					table.insert(chosenCards, card.guid)
					aspects[aspect] = aspects[aspect] + 1
					if #chosenCards >= 80 then break end
				end
			end
			for _, guid in ipairs(chosenCards) do
				fullDeck.takeObject({guid = guid, position = marketPos, rotation = facedown})
			end
			fullDeck.destruct()
			wait(2.2)
		else
			fullDeck.shuffle()
			wait(0.32)
			fullDeck.shuffle()
			wait(0.5)
			
			local chosenCards = {}
			local notChosenCards = {}
			local aspects = {m=0, g=0, c=0, a=0}
			for _, card in ipairs(fullDeck.getObjects()) do
				local aspect = string.sub(card.gm_notes, 5, 5)
				if aspects[aspect] < 20 and string.len(card.gm_notes) < 6 then
					table.insert(chosenCards, card.guid)
					aspects[aspect] = aspects[aspect] + 1
					if #chosenCards >= 80 then break end
				else table.insert(notChosenCards, card.guid)
				end
			end
			if #chosenCards < 80 then
				for _, guid in ipairs(notChosenCards) do
					table.insert(chosenCards, guid)
					if #chosenCards >= 80 then break end
				end
			end
			for _, guid in ipairs(chosenCards) do
				fullDeck.takeObject({guid = guid, position = marketPos, rotation = facedown})
			end
			wait(2.2)
			fullDeck = findDeck(getObjectFromGUID(halfDeckZones.custom))
			if fullDeck ~= nil then fullDeck.destruct() end
		end
		
		findDeck(marketZone).shuffle()
		wait(0.32)
		fullDeck = findDeck(marketZone)
		fullDeck.shuffle()
		wait(0.5)
		for _, guid in ipairs(market.top) do
			local toPos = getObjectFromGUID(guid).getPosition()
			fullDeck.takeObject({position = {toPos[1], tileY, toPos[3]}, rotation = faceup})
			wait(0.16)
		end
		
		-- shuffle player decks and deal
		local playerDecks = {}
		for _, playerColor in ipairs(seatedPlayerColors) do
			local deck = findDeck(getObjectFromGUID(playerVars[playerColor].deckZoneGuid))
			if deck ~= nil then
				deck.shuffle()
				playerDecks[playerColor] = deck
			end
		end
		wait(0.5)
		for playerColor, playerDeck in pairs(playerDecks) do
			playerDeck.deal(5, playerColor)
		end
		
		wait(0.5)
		status.gameState = 1
		setupButtons()
		setupScoreboards()
		wait(0.4)
		
		local firstPlayerColor = seatedPlayerColors[math.random(1, #seatedPlayerColors)]
		status.firstPlayerColor = firstPlayerColor
		local firstPlayerMarker = getObjectFromGUID(firstPlayerMarkerGuid)
		if firstPlayerMarker ~= nil then
			firstPlayerMarker.lock()
			firstPlayerMarker.setRotation(faceup)
			firstPlayerMarker.setPositionSmooth(playerVars[firstPlayerColor].firstPlayerPosition, false, false)
		end
		Turns.turn_color = firstPlayerColor
		Turns.enable = true
		status.setupInProgress = false
		UI.setAttribute('timerPanel', 'active', not status.timer.numbersHidden)
		UI.setAttribute('timerControlsPanel', 'active', true)
		wait(1.2)
		
		local autoSendToDiscardMsg = 'Auto VP token delivery for site total control is '
		if options.autoSendToDiscard then broadcastToAll(autoSendToDiscardMsg .. buttonText.on)
		else broadcastToAll(autoSendToDiscardMsg .. buttonText.off)
		end
		
		local autoTotalControlVpMsg = 'Auto discard and draw is '
		if options.autoTotalControlVp then
			broadcastToAll(autoTotalControlVpMsg .. buttonText.on)
			wait(1.2)
			broadcastToAll('Deploy starting troops before passing the first turn.')
		else broadcastToAll(autoTotalControlVpMsg .. buttonText.off)
		end
		return 1
	end
	startLuaCoroutine(Global, 'menuStartCoroutine')
end

---------------------- BUTTONS

function setupButtons()
	if TESTING then
		local buttonZone = getObjectFromGUID(testingVars.buttonZone)
		if buttonZone.getButtons() == nil or #buttonZone.getButtons() == 0 then
			local params = {
				function_owner = self,
				label = 'Test 1',
				click_function = 'test1',
				position = {-2.2, 0, 0},
				width = 900,
				height = 500,
				font_size = 240
			}
			buttonZone.createButton(params)
			
			params.label = 'Test 2'
			params.click_function = 'test2'
			params.position = {0, 0, 0}
			buttonZone.createButton(params)
			
			params.label = 'Test 3'
			params.click_function = 'test3'
			params.position = {2.2, 0, 0}
			buttonZone.createButton(params)

			params.label = 'TEST 4p'
			params.click_function = 'test4p'
			params.position = {4.4, 0, 0}
			buttonZone.createButton(params)
		end
	end
	
	if status.gameState < 1 then return end
	local buttonZone = getObjectFromGUID(buttonZoneGuids[2])
	local params = {
		function_owner = self,
		label = buttonText.showSitePoints,
		click_function = 'showSitePoints',
		position = {0, 0, -0.3},
		width = 2100,
		height = 1100,
		font_size = 240
	}
	buttonZone.createButton(params)

	buttonZone.createButton({
		function_owner = self,
		label = 'Show Ratings',
		click_function = 'onShowRatingsClick',
		position = {0, 0, 1.9},
		width = 2100,
		height = 700,
		font_size = 240
	})
	
	buttonZone = getObjectFromGUID(buttonZoneGuids[1])
	params.label = ''
	params.click_function = 'toggleAutoSendToDiscard'
	params.position = {-7.2, 0, 0.2}
	buttonZone.createButton(params)
	editToggleButtonText(0, 'autoSendToDiscard')
	
	params.click_function = 'toggleAutoVp'
	params.position = {-2.4, 0, 0.2}
	buttonZone.createButton(params)
	editToggleButtonText(1, 'autoTotalControlVp')
	
	params.click_function = 'togglePromoteCounters'
	params.position = {2.4, 0, 0.2}
	buttonZone.createButton(params)
	editToggleButtonText(2, 'promoteCounters')
	if options.promoteCounters then setupPromoteCounters() end
	
	params.click_function = 'toggleTrophyCounters'
	params.position = {7.2, 0, 0.2}
	buttonZone.createButton(params)
	editToggleButtonText(3, 'trophyCounters')
	if options.trophyCounters then setupTrophyCounters() end

	params.click_function = 'toggleResourcePool'
	params.position = {-7.2, 0, 2.4}
	buttonZone.createButton(params)
	editToggleButtonText(4, 'resourcePoolEnabled')
	if options.resourcePoolEnabled then setupResourcePoolCounters() end

	-- bag counters
	params = {
		function_owner = self,
		label = '0',
		click_function = 'temp',
		width = 500,
		height = 400,
		font_size = 260
	}
	for _, playerColor in ipairs(seatedPlayerColors) do
		buttonZone = getObjectFromGUID(playerVars[playerColor].troopCounterZoneGuid)
		local bag = getObjectFromGUID(playerVars[playerColor].troopBagGuid)
		if bag ~= nil and (buttonZone.getButtons() == nil or #buttonZone.getButtons() == 0) then
			params.label = bag.getQuantity()
			buttonZone.createButton(params)
		end
	end
	
	-- market deck counter
	params.position = {0, 0, 2.5}
	buttonZone = getObjectFromGUID(market.bottom[1])
	local marketDeck = findDeck(buttonZone)
	if marketDeck == nil then params.label = 0
	else params.label = marketDeck.getQuantity()
	end
	buttonZone.createButton(params)
	
	-- control marker buttons on sites (standard board only - these zones don't exist in modular mode)
	params.width = 700
	params.height = 380
	params.font_size = 200
	if status.boardMode == 'standard' then
		for _, section in ipairs(status.boardSectionsUsed) do
			for _, controlMarkerInfo in ipairs(boardSections[section].controlMarkers) do
				local zone = getObjectFromGUID(controlMarkerInfo.buttonZoneGuid)
				if zone.getButtons() == nil or #zone.getButtons() == 0 then
					params.label = 'Take'
					params.click_function = 'moveControlMarker' .. controlMarkerInfo.guid
					params.position = {0, 0, 0.3}
					zone.createButton(params)
					
					_G['moveControlMarker' .. controlMarkerInfo.guid] = function(obj, clickColor, alt)
						moveControlMarker(clickColor, controlMarkerInfo, {}, true)
					end
				end
			end
		end
	end
	
	-- market
	params = {
		function_owner = self,
		label = 'Recruit',
		click_function = 'temp',
		position = {0, 0, -2.5},
		width = 800,
		height = 380,
		font_size = 200
	}
	for i, guid in ipairs(market.top) do
		params.click_function = 'recruit' .. guid
		getObjectFromGUID(guid).createButton(params)
		
		_G['recruit' .. guid] = function(obj, clickColor, alt)
			recruit(guid, 'top'..i, clickColor, true, alt)
		end
	end
	
	params.position = {0, 0, 2.5}
	for i, guid in ipairs(market.bottom) do
		if i > 1 then
			params.click_function = 'recruit' .. guid
			getObjectFromGUID(guid).createButton(params)
			
			_G['recruit' .. guid] = function(obj, clickColor, alt)
				recruit(guid, 'bottom'..i, clickColor, false, false)
			end
		end
	end
	
	-- player board card management
	for i, playerColor in ipairs(seatedPlayerColors) do
		params.label = 'Refill Deck'
		params.click_function = 'refillDeck' .. i
		params.position = {0, 0, 0}
		params.width = 1100
		getObjectFromGUID(playerVars[playerColor].deckZoneGuid).createButton(params)
		
		_G['refillDeck' .. i] = function(obj, clickColor, alt)
			if status.doneLoading then refillDeck(clickColor, playerColor) end
		end
		
		params.label = 'Lay Hand'
		params.click_function = 'layHand' .. i
		params.position = {-7, 0, 0}
		getObjectFromGUID(playerVars[playerColor].playButtonZoneGuid).createButton(params)
		
		_G['layHand' .. i] = function(obj, clickColor, alt)
			if status.doneLoading then layHand(clickColor, playerColor) end
		end
		
		--[[
		params.label = 'Send to Discard'
		params.click_function = 'sendToDiscard' .. i
		params.position = {5.92, 0, 0}
		params.width = 1600
		getObjectFromGUID(playerVars[playerColor].playButtonZoneGuid).createButton(params)
		
		_G['sendToDiscard' .. i] = function(obj, clickColor, alt)
			if status.doneLoading then sendToDiscard(clickColor, playerColor) end
		end
		--]]
	end
	
	-- vp token bags
	params = {
		function_owner = self,
		label = 'Take',
		click_function = 'takeVp',
		rotation = {0, 180, 0},
		position = {2.5, 0.1, 0},
		width = 800,
		height = 380,
		font_size = 200
	}
	for _, guid in ipairs(vpBags.left) do
		params.click_function = 'takeVp' .. guid
		getObjectFromGUID(guid).createButton(params)
		
		_G['takeVp' .. guid] = function(obj, clickColor, alt)
			if status.doneLoading then takeVp(guid, clickColor) end
		end
	end
	for _, guid in ipairs(vpBags.right) do
		params.position = {-2.5, 0.1, 0}
		params.click_function = 'takeVp' .. guid
		getObjectFromGUID(guid).createButton(params)
		
		_G['takeVp' .. guid] = function(obj, clickColor, alt)
			if status.doneLoading then takeVp(guid, clickColor) end
		end
	end
end

function takeVp(bagGuid, clickColor)
	if playerVars[clickColor] == nil then return end
	local trophyZone = getObjectFromGUID(playerVars[clickColor].trophyZoneGuid)
	if trophyZone ~= nil then
		local bag = getObjectFromGUID(bagGuid)
		local zonePosition = trophyZone.getPosition()
		local x = {-3.3, -1.1, 1.1, 3.3}
		local vp = bag.takeObject()
		vp.setRotation(faceup)
		vp.setPositionSmooth({zonePosition[1] + x[math.random(1,4)], 2.5, zonePosition[3] - 3.4}, false, false)
	end
end

---------------------- MERCENARIES: VP STEAL/BRIBE PRIMITIVES ----------------------
-- VP is tracked as physical tokens ('VP Token', getDescription() = '1' or '5') sitting
-- in each player's trophy zone, drawn from four infinite bags (vpBags.left/right).
-- Because the bags are infinite, an exact-amount transfer between two players doesn't
-- need to move specific physical chips: we pull back enough of the source player's
-- tokens (biggest first) to cover the amount, refund any overshoot to them as change
-- from the bag, then hand the requested amount to the destination player from the bag
-- in the largest denominations that fit. This is how the mod "breaks" a 5-VP chip to
-- pay a smaller debt.

function demonwebVpBagByValue(value)
	for _, side in ipairs({vpBags.left, vpBags.right}) do
		for _, guid in ipairs(side) do
			local bag = getObjectFromGUID(guid)
			if bag ~= nil then
				local contents = bag.getObjects()
				if contents[1] ~= nil and tonumber(contents[1].description) == value then
					return bag
				end
			end
		end
	end
	return nil
end

function demonwebCountVp(playerColor)
	local vars = playerVars[playerColor]
	if vars == nil then return 0 end
	local zone = getObjectFromGUID(vars.trophyZoneGuid)
	if zone == nil then return 0 end
	local total = 0
	for _, object in ipairs(zone.getObjects()) do
		if object.getName() == 'VP Token' then
			total = total + (tonumber(object.getDescription()) or 0)
		end
	end
	return total
end

-- Grants `amount` VP worth of tokens to playerColor from the infinite bags (largest
-- denomination first). Returns the amount actually given (should equal amount unless
-- the bags are somehow missing).
function demonwebGiveVpValue(playerColor, amount)
	local vars = playerVars[playerColor]
	if vars == nil or amount <= 0 then return 0 end
	local zone = getObjectFromGUID(vars.trophyZoneGuid)
	if zone == nil then return 0 end
	local zonePosition = zone.getPosition()
	local x = {-3.3, -1.1, 1.1, 3.3}

	local remaining = amount
	local given = 0
	local fiveBag = demonwebVpBagByValue(5)
	local oneBag = demonwebVpBagByValue(1)
	while remaining >= 5 and fiveBag ~= nil do
		local vp = fiveBag.takeObject()
		vp.setRotation(faceup)
		vp.setPositionSmooth({zonePosition[1] + x[math.random(1,4)], 2.5, zonePosition[3] - 3.4}, false, false)
		remaining = remaining - 5
		given = given + 5
	end
	while remaining >= 1 and oneBag ~= nil do
		local vp = oneBag.takeObject()
		vp.setRotation(faceup)
		vp.setPositionSmooth({zonePosition[1] + x[math.random(1,4)], 2.5, zonePosition[3] - 3.4}, false, false)
		remaining = remaining - 1
		given = given + 1
	end
	return given
end

-- Removes up to `amount` VP worth of tokens from playerColor's trophy zone back to
-- the infinite bags. If playerColor has less than `amount` total, takes everything
-- they have (steal-up-to-what's-available convention). Returns the amount actually
-- removed; any overshoot from breaking a large token is refunded back to the same
-- player as change.
function demonwebTakeVpValue(playerColor, amount)
	local vars = playerVars[playerColor]
	if vars == nil or amount <= 0 then return 0 end
	local zone = getObjectFromGUID(vars.trophyZoneGuid)
	if zone == nil then return 0 end

	local tokens = {}
	for _, object in ipairs(zone.getObjects()) do
		if object.getName() == 'VP Token' then
			table.insert(tokens, {obj = object, value = tonumber(object.getDescription()) or 0})
		end
	end
	table.sort(tokens, function(a, b) return a.value > b.value end)

	local available = 0
	for _, t in ipairs(tokens) do available = available + t.value end
	local need = math.min(amount, available)
	if need <= 0 then return 0 end

	local pulled = 0
	for _, t in ipairs(tokens) do
		if pulled >= need then break end
		t.obj.destruct()
		pulled = pulled + t.value
	end

	local change = pulled - need
	if change > 0 then
		demonwebGiveVpValue(playerColor, change)
	end
	return need
end

-- Steal up to `amount` VP from fromColor and give it to toColor. Returns the amount
-- actually transferred (0 if fromColor had no VP).
function demonwebStealVp(fromColor, toColor, amount)
	local taken = demonwebTakeVpValue(fromColor, amount)
	if taken > 0 then
		demonwebGiveVpValue(toColor, taken)
		printToAll(getPlayerName(toColor, true) .. ' stole ' .. taken .. ' VP from ' .. getPlayerName(fromColor, true) .. '.')
	else
		printToAll(getPlayerName(toColor, true) .. ' tried to steal VP from ' .. getPlayerName(fromColor, true) .. ', but they have none.')
	end
	return taken
end

-- Bribe: fromColor gives exactly 1 VP to toColor. Fails (returns false, no message)
-- if fromColor has no VP to give — matching the rulebook's "cannot bribe if you have
-- no VP".
function demonwebBribeVp(fromColor, toColor)
	if demonwebCountVp(fromColor) < 1 then return false end
	local taken = demonwebTakeVpValue(fromColor, 1)
	if taken > 0 then
		demonwebGiveVpValue(toColor, taken)
		printToAll(getPlayerName(fromColor, true) .. ' bribed ' .. getPlayerName(toColor, true) .. ' with 1 VP.')
		return true
	end
	return false
end

function recruit(marketZoneGuid, index, clickColor, refill, alt)
	if not status.doneLoading or playerVars[clickColor] == nil or status.recruiting[index] then return end
	local fromZone = getObjectFromGUID(marketZoneGuid)
	local toZone = nil
	if alt then toZone = getObjectFromGUID(devourZoneGuid)
	else toZone = getObjectFromGUID(playerVars[clickColor].discardZoneGuid)
	end
	if toZone == nil then return end
	status.recruiting[index] = true
	for _, object in ipairs(fromZone.getObjects()) do
		local cardToMove = nil
		if object.type == 'Card' then
			cardToMove = object
		elseif object.type == 'Deck' then
			cardToMove = object.takeObject()
		end
		if cardToMove ~= nil then
			local toPos = toZone.getPosition()
			cardToMove.setRotation(faceup)
			cardToMove.setPositionSmooth({toPos[1], toPos[2] + 0.5, toPos[3]}, false, true)
			if not alt then
				printToAll(getPlayerName(clickColor, true) .. ' recruited ' .. cardToMove.getName() .. ' (' .. cardToMove.getDescription() .. ').')
				if demonwebStealOnRecruit[clickColor] then	-- Xanathar Zushaxx: "each time you recruit a card, steal 1 VP" for the rest of this turn
					local target = demonwebAutoStealTarget(clickColor)
					if target ~= nil then demonwebStealVp(target, clickColor, 1) end
				end
			end
			break
		end
	end
	if refill then
		Wait.time(
			function()
				refillMarketSpace(marketZoneGuid)
				status.recruiting[index] = false
			end,
		0.4)
	else status.recruiting[index] = false
	end
end

function refillMarketSpace(marketZoneGuid)
	local marketZone = getObjectFromGUID(marketZoneGuid)
	if findDeck(marketZone) == nil then
		local marketDeck = findDeck(getObjectFromGUID(market.bottom[1]))
		if marketDeck ~= nil then
			local cardToMove = marketDeck
			if marketDeck.type == 'Deck' then cardToMove = marketDeck.takeObject() end
			local toPos = marketZone.getPosition()
			cardToMove.setRotation(faceup)
			cardToMove.setPositionSmooth({toPos[1], tileY, toPos[3]}, false, true)
		end
	end
end

function refillDeck(clickColor, buttonColor)
	if not TESTING and clickColor ~= buttonColor then return end
	local fromZone = getObjectFromGUID(playerVars[buttonColor].discardZoneGuid)
	local toZone = getObjectFromGUID(playerVars[buttonColor].deckZoneGuid)
	local toPos = {toZone.getPosition()[1], toZone.getPosition()[2] + 1, toZone.getPosition()[3]}
	for _, object in ipairs(fromZone.getObjects()) do
		if object.type == 'Card' or object.type == 'Deck' then
			object.setRotation(facedown)
			object.setPositionSmooth(toPos, false, true)
		end
	end
	function refillDeckCoroutine()
		wait(0.7)
		for i=1, 2 do
			for _, object in ipairs(toZone.getObjects()) do
				if object.type == 'Deck' then object.shuffle() break end
			end
			wait(0.32)
		end
		return 1
	end
	startLuaCoroutine(Global, 'refillDeckCoroutine')
end

function layHand(clickColor, buttonColor)
	if not TESTING and clickColor ~= buttonColor then return end
	local objects = Player[buttonColor].getHandObjects()
	local cardCount = #objects
	if cardCount > 0 then
		if cardCount > 6 then cardCount = 6 end
		local cardWidth = 4.9
		local zonePosition = getObjectFromGUID(playerVars[buttonColor].playZoneGuid).getPosition()
		local positionX = zonePosition.x - (cardCount / 2 + 0.5) * cardWidth
		local toPos = {positionX, zonePosition[2], zonePosition[3] - 2.2}
		for i=1, cardCount do
			local object = objects[i]
			if object.type == 'Card' then
				object.use_hands = false
				toPos[1] = toPos[1] + cardWidth
				object.setRotationSmooth(faceup, false, true)
				object.setPositionSmooth(toPos, false, false)
				Wait.time(function() object.use_hands = true end, 0.3)
			end
		end
	end
end

function sendToDiscard(clickColor, buttonColor)
	if not TESTING and clickColor ~= buttonColor then return end
	local count = 0
	local fromZone = getObjectFromGUID(playerVars[buttonColor].playZoneGuid)
	local toZone = getObjectFromGUID(playerVars[buttonColor].discardZoneGuid)
	local toPos = toZone.getPosition()
	for _, object in ipairs(fromZone.getObjects()) do
		if object.type == 'Card' or object.type == 'Deck' then
			object.setRotation(faceup)
			object.setPositionSmooth({toPos[1], toPos[2] + 0.5, toPos[3]}, false, true)
			count = count + 1
		end
	end
	return count
end

---------------------- TOGGLE FEATURES

function editToggleButtonText(index, varName, clickColor)
	local buttonZone = getObjectFromGUID(buttonZoneGuids[1])
	if options[varName] then buttonZone.editButton({index = index, label = buttonText[varName] .. buttonText.on})
	else buttonZone.editButton({index = index, label = buttonText[varName] .. buttonText.off})
	end
	
	if clickColor ~= nil then
		local msg = getPlayerName(clickColor, true) .. ' toggled ' .. buttonMsg[varName] .. ' '
		if options[varName] then broadcastToAll(msg .. buttonText.on)
		else broadcastToAll(msg .. buttonText.off)
		end
	end
end

function toggleAutoSendToDiscard(obj, clickColor, alt)
	options.autoSendToDiscard = not options.autoSendToDiscard
	editToggleButtonText(0, 'autoSendToDiscard', clickColor)
end

function toggleAutoVp(obj, clickColor, alt)
	options.autoTotalControlVp = not options.autoTotalControlVp
	editToggleButtonText(1, 'autoTotalControlVp', clickColor)
end

function togglePromoteCounters(obj, clickColor, alt)
	if options.promoteCounters then
		for _, playerColor in ipairs(seatedPlayerColors) do
			local zone = getObjectFromGUID(playerVars[playerColor].promoteCounterZoneGuid)
			if zone.getButtons() ~= nil and #zone.getButtons() > 0 then
				zone.removeButton(0)
			end
		end
	else
		setupPromoteCounters()
	end
	options.promoteCounters = not options.promoteCounters
	editToggleButtonText(2, 'promoteCounters', clickColor)
end

function toggleTrophyCounters(obj, clickColor, alt)
	if options.trophyCounters then
		for _, playerColor in ipairs(seatedPlayerColors) do
			local zone = getObjectFromGUID(playerVars[playerColor].trophyCounterZoneGuid)
			if zone.getButtons() ~= nil and #zone.getButtons() > 0 then
				zone.removeButton(0)
			end
		end
	else
		setupTrophyCounters()
	end
	options.trophyCounters = not options.trophyCounters
	editToggleButtonText(3, 'trophyCounters', clickColor)
end

function toggleResourcePool(obj, clickColor, alt)
	if options.resourcePoolEnabled then
		for _, playerColor in ipairs(seatedPlayerColors) do
			local zone = getObjectFromGUID(playerVars[playerColor].playButtonZoneGuid)
			while zone.getButtons() ~= nil and #zone.getButtons() > 0 do
				zone.removeButton(0)
			end
			resourcePool[playerColor].power = 0
			resourcePool[playerColor].influence = 0
		end
	else
		setupResourcePoolCounters()
	end
	options.resourcePoolEnabled = not options.resourcePoolEnabled
	editToggleButtonText(4, 'resourcePoolEnabled', clickColor)
end

function setupResourcePoolCounters()
	for _, playerColor in ipairs(seatedPlayerColors) do
		local zone = getObjectFromGUID(playerVars[playerColor].playButtonZoneGuid)
		if zone.getButtons() == nil or #zone.getButtons() == 0 then
			zone.createButton({
				function_owner = self,
				label = 'Power: 0',
				click_function = 'resourcePoolPowerClick' .. playerColor,
				position = {-1.5, 0, 0},
				width = 1500,
				height = 500,
				font_size = 260
			})
			zone.createButton({
				function_owner = self,
				label = 'Influence: 0',
				click_function = 'resourcePoolInfluenceClick' .. playerColor,
				position = {1.5, 0, 0},
				width = 1700,
				height = 500,
				font_size = 260
			})
		end
		updateResourcePoolButtons(playerColor)
	end
end

function updateResourcePoolButtons(playerColor)
	local zone = getObjectFromGUID(playerVars[playerColor].playButtonZoneGuid)
	local pool = resourcePool[playerColor]
	if zone == nil or pool == nil or zone.getButtons() == nil or #zone.getButtons() < 2 then return end
	zone.editButton({index = 0, label = 'Power: ' .. pool.power})
	zone.editButton({index = 1, label = 'Influence: ' .. pool.influence})
end

function demonwebResourcePoolEnabled()
	return options.resourcePoolEnabled == true
end

-- Adds to a player's pool (from a card's "+Power"/"+Influence" effect). No-op while the pool feature is off,
-- since without the on-table counter the amount would just be invisible/untrackable.
function demonwebGrantPower(playerColor, amount)
	if not demonwebResourcePoolEnabled() or resourcePool[playerColor] == nil or amount == nil or amount <= 0 then return end
	resourcePool[playerColor].power = resourcePool[playerColor].power + amount
	updateResourcePoolButtons(playerColor)
end

function demonwebGrantInfluence(playerColor, amount)
	if not demonwebResourcePoolEnabled() or resourcePool[playerColor] == nil or amount == nil or amount <= 0 then return end
	resourcePool[playerColor].influence = resourcePool[playerColor].influence + amount
	updateResourcePoolButtons(playerColor)
end

-- Checks and deducts a Power cost for one of the fixed-cost base actions (deploy/assassinate/return enemy
-- spy). Returns true if the action may proceed. While the pool feature is off this always returns true -
-- honor system, unchanged from the mod's previous (and still default) behavior.
function demonwebSpendPower(playerColor, amount)
	if not demonwebResourcePoolEnabled() then return true end
	local pool = resourcePool[playerColor]
	if pool == nil or pool.power < amount then return false end
	pool.power = pool.power - amount
	updateResourcePoolButtons(playerColor)
	return true
end

function demonwebSpendInfluence(playerColor, amount)
	if not demonwebResourcePoolEnabled() then return true end
	local pool = resourcePool[playerColor]
	if pool == nil or pool.influence < amount then return false end
	pool.influence = pool.influence - amount
	updateResourcePoolButtons(playerColor)
	return true
end

-- Unspent Power/Influence is lost at the end of a turn (rulebook p.7). Called from onPlayerTurn for whoever's
-- turn just ended.
function demonwebResetResourcePool(playerColor)
	if not demonwebResourcePoolEnabled() or resourcePool[playerColor] == nil then return end
	resourcePool[playerColor].power = 0
	resourcePool[playerColor].influence = 0
	updateResourcePoolButtons(playerColor)
end

---------------------- MERCENARIES: CARD AUTOMATION HELPERS

function demonwebOpponentColors(playerColor)
	local result = {}
	for _, c in ipairs(seatedPlayerColors) do
		if c ~= playerColor then table.insert(result, c) end
	end
	return result
end

-- Adds one context-menu item per possible opponent (a single, unqualified item when there's only one
-- opponent in the game) that calls fn(clickColor, opponentColor) when clicked. Guards against a player
-- picking themselves as the "opponent" in 3-4 player games, where every seated color needs its own static
-- menu item (TTS context menus can't be built differently per viewer).
function demonwebAddOpponentMenuItems(card, baseLabel, fn)
	if #seatedPlayerColors <= 1 then return end
	if #seatedPlayerColors == 2 then
		card.addContextMenuItem(baseLabel, function(clickColor)
			local opponents = demonwebOpponentColors(clickColor)
			if #opponents == 1 then fn(clickColor, opponents[1]) end
		end)
	else
		for _, targetColor in ipairs(seatedPlayerColors) do
			card.addContextMenuItem(baseLabel .. ' (' .. targetColor .. ')', function(clickColor)
				if clickColor ~= targetColor then fn(clickColor, targetColor) end
			end)
		end
	end
end

-- Same shape as demonwebAddOpponentMenuItems, but the target is who receives the Bribe's 1 VP - effectFn
-- (clickColor) only runs once the bribe payment actually succeeds (fails silently, same as demonwebBribeVp,
-- if the player has no VP to give).
function demonwebAddBribeMenuItems(card, baseLabel, effectFn)
	demonwebAddOpponentMenuItems(card, baseLabel, function(clickColor, targetColor)
		if demonwebBribeVp(clickColor, targetColor) then effectFn(clickColor) end
	end)
end

function demonwebFreeActionsAvailable(playerColor, actionName)
	local bucket = demonwebFreeActions[playerColor]
	return (bucket and bucket[actionName]) or 0
end

function demonwebGrantFreeAction(playerColor, actionName, amount)
	local bucket = demonwebFreeActions[playerColor]
	if bucket == nil then return end
	bucket[actionName] = (bucket[actionName] or 0) + amount
end

function demonwebUseFreeActions(playerColor, actionName, amount)
	local bucket = demonwebFreeActions[playerColor]
	if bucket == nil then return end
	bucket[actionName] = math.max(0, (bucket[actionName] or 0) - amount)
end

function demonwebResetFreeActions(playerColor)
	demonwebFreeActions[playerColor] = {deploy = 0, assassinate = 0, returnSpy = 0}
	demonwebCheapAssassinateDiscount[playerColor] = nil
	demonwebStealOnRecruit[playerColor] = nil
end

-- Bregan D'aerthe Agents (Mercenaries): finds a white (unaligned) troop sitting in any seated player's
-- trophy hall (i.e. one that's already been assassinated), regardless of who assassinated it.
function demonwebFindTrophyWhiteTroop()
	for _, playerColor in ipairs(seatedPlayerColors) do
		local zone = getObjectFromGUID(playerVars[playerColor].trophyZoneGuid)
		if zone ~= nil then
			for _, object in ipairs(zone.getObjects()) do
				if object.hasTag('troop') and object.getDescription() == 'White' then return object end
			end
		end
	end
	return nil
end

-- Bregan D'aerthe Spy (Mercenaries): finds any one of playerColor's own spy figures currently placed on the
-- board (not in their spy rack) to return as this ability's cost.
function demonwebFindPlacedSpy(playerColor)
	for _, object in ipairs(getObjects()) do
		if object.hasTag('spy') and object.getDescription() == playerColor then return object end
	end
	return nil
end

function demonwebBreganSpyStealMarker(playerColor, marker)
	if not isSeated(playerColor) then return end
	local spy = demonwebFindPlacedSpy(playerColor)
	if spy == nil then broadcastToColor('You have no placed spy to return for this.', playerColor) return end
	returnFigure(playerColor, spy)
	demonwebStolenMarkers[marker.getGUID()] = playerColor
	broadcastToAll(getPlayerName(playerColor, true) .. " stole a site control marker (Bregan D'aerthe Spy) - held until the start of their next turn.")
end

-- Reverts any site control markers playerColor stole with Bregan D'aerthe Spy, right as their next turn
-- begins (called from onPlayerTurn/passTurnDueToTimeout) - from then on demonwebMoveControlMarker()/
-- moveControlMarker() go back to computing control from actual troop counts as usual.
function demonwebRevertStolenMarkersForPlayer(playerColor)
	for guid, thief in pairs(demonwebStolenMarkers) do
		if thief == playerColor then demonwebStolenMarkers[guid] = nil end
	end
end

-- Sylgar (Mercenaries): "If this is devoured, promoted or discarded by a card, put it back where it was and
-- gain 1 VP." Best-effort approximation - the mod has no way to tell "devoured/promoted by another card's
-- effect" apart from a player manually clicking Devour/Promote on it, so this fires either way (see promote()/
-- devour() above, which call this instead of their normal move-to-zone behavior whenever the target is
-- Sylgar specifically). Deliberately NOT hooked into the ordinary end-of-turn discard sweep - that would make
-- Sylgar impossible to ever discard normally, which isn't what the card means by "discarded by a card".
function demonwebSylgarBounceBack(playerColor, card)
	local originalPos = card.getPosition()
	local originalRot = card.getRotation()
	Wait.time(function()
		if card ~= nil then
			card.setPositionSmooth(originalPos, false, true)
			card.setRotationSmooth(originalRot, false, true)
		end
	end, 0.5)
	demonwebGiveVpValue(playerColor, 1)
	broadcastToAll('Sylgar returns to where it was, and ' .. getPlayerName(playerColor, true) .. ' gains 1 VP.')
end

function demonwebCountTrophyTroops(playerColor)
	local zone = getObjectFromGUID(playerVars[playerColor].trophyZoneGuid)
	if zone == nil then return 0 end
	local count = 0
	for _, object in ipairs(zone.getObjects()) do
		if object.hasTag('troop') then count = count + 1 end
	end
	return count
end

-- Steal's implicit target when a card doesn't ask the player to pick one (e.g. Xanathar Zushaxx's
-- recruit-triggered steal): the sole opponent in a 2-player game, or whoever currently has the most VP in a
-- 3-4 player game (a reasonable default given the mod can't pop up a per-instance choice mid-recruit).
function demonwebAutoStealTarget(playerColor)
	local opponents = demonwebOpponentColors(playerColor)
	if #opponents == 0 then return nil end
	if #opponents == 1 then return opponents[1] end
	local best, bestVp = nil, -1
	for _, c in ipairs(opponents) do
		local vp = demonwebCountVp(c)
		if vp > bestVp then best, bestVp = c, vp end
	end
	return best
end

-- Draws `count` cards for playerColor, reshuffling their discard pile into their deck if it runs out midway
-- (same logic as the deck-empty branch of discardAndDraw's own draw step).
function demonwebDrawCards(playerColor, count)
	function demonwebDrawCardsCoroutine()
		local drawn = 0
		for _, object in ipairs(getObjectFromGUID(playerVars[playerColor].deckZoneGuid).getObjects()) do
			if drawn >= count then break end
			if object.type == 'Card' then
				object.deal(1, playerColor)
				drawn = drawn + 1
			elseif object.type == 'Deck' then
				local numberToDraw = count - drawn
				if object.getQuantity() >= numberToDraw then drawn = drawn + numberToDraw
				else drawn = drawn + object.getQuantity()
				end
				object.deal(numberToDraw, playerColor)
			end
		end
		if drawn < count then
			if drawn > 0 then wait(0.6) end
			refillDeck(playerColor, playerColor)
			wait(1.52)
			local deck = findDeck(getObjectFromGUID(playerVars[playerColor].deckZoneGuid))
			if deck ~= nil then deck.deal(count - drawn, playerColor)
			else
				local remaining = getObjectFromGUID(playerVars[playerColor].deckZoneGuid).getObjects()
				if remaining[1] ~= nil and remaining[1].type == 'Card' then remaining[1].deal(1, playerColor) end
			end
		end
		return 1
	end
	startLuaCoroutine(Global, 'demonwebDrawCardsCoroutine')
end

-- Resolves deferred "at the end of turn" Mercenaries effects for whoever's turn just ended. Must run before
-- discardAndDraw()/sendToDiscard(), since promoting a card played this turn only makes sense while it's
-- still sitting in the play zone (not yet swept to the discard pile).
function demonwebResolveEndOfTurnEffects(playerColor)
	local excludeGuid = demonwebPendingPromote[playerColor]
	if excludeGuid ~= nil then
		demonwebPendingPromote[playerColor] = nil
		local playZone = getObjectFromGUID(playerVars[playerColor].playZoneGuid)
		if playZone ~= nil then
			for _, object in ipairs(playZone.getObjects()) do
				if object.type == 'Card' and object.getGUID() ~= excludeGuid then
					promote(playerColor, object)
					break
				end
			end
		end
	end
end

for _, resourcePoolColor in ipairs({'Red', 'Blue', 'Purple', 'Teal'}) do
	_G['resourcePoolPowerClick' .. resourcePoolColor] = function(obj, clickColor, alt)
		if clickColor ~= resourcePoolColor then return end
		if alt then demonwebGrantPower(resourcePoolColor, 1)
		else demonwebSpendPower(resourcePoolColor, 1)
		end
	end
	_G['resourcePoolInfluenceClick' .. resourcePoolColor] = function(obj, clickColor, alt)
		if clickColor ~= resourcePoolColor then return end
		if alt then demonwebGrantInfluence(resourcePoolColor, 1)
		else demonwebSpendInfluence(resourcePoolColor, 1)
		end
	end
end

function setupPromoteCounters()
	local params = {
		function_owner = self,
		label = '0',
		click_function = 'temp',
		width = 500,
		height = 400,
		font_size = 260
	}
	for _, playerColor in ipairs(seatedPlayerColors) do
		local zone = getObjectFromGUID(playerVars[playerColor].promoteCounterZoneGuid)
		if zone.getButtons() == nil or #zone.getButtons() == 0 then
			zone.createButton(params)
		end
		updatePromoteCounter(playerColor)
	end
end

function setupTrophyCounters()
	local params = {
		function_owner = self,
		label = '0',
		click_function = 'temp',
		width = 500,
		height = 400,
		font_size = 260
	}
	for _, playerColor in ipairs(seatedPlayerColors) do
		local zone = getObjectFromGUID(playerVars[playerColor].trophyCounterZoneGuid)
		if zone.getButtons() == nil or #zone.getButtons() == 0 then
			zone.createButton(params)
		end
		updateTrophyCounter(playerColor)
	end
end

function updatePromoteCounter(playerColor)
	local circleZone = getObjectFromGUID(playerVars[playerColor].circleZoneGuid)
	local buttonZone = getObjectFromGUID(playerVars[playerColor].promoteCounterZoneGuid)
	if buttonZone.getButtons() ~= nil and #buttonZone.getButtons() == 1 then
		local count = 0
		for _, object in ipairs(circleZone.getObjects()) do
			if object.type == 'Card' then
				count = count + 1
			elseif object.type == 'Deck' then
				count = count + object.getQuantity()
			end
		end
		buttonZone.editButton({index = 0, label = count})
	end
end

function updateTrophyCounter(playerColor)
	local trophyHallZone = getObjectFromGUID(playerVars[playerColor].trophyZoneGuid)
	local buttonZone = getObjectFromGUID(playerVars[playerColor].trophyCounterZoneGuid)
	if buttonZone.getButtons() ~= nil and #buttonZone.getButtons() == 1 then
		local count = 0
		for _, object in ipairs(trophyHallZone.getObjects()) do
			if object.hasTag('troop') then
				count = count + 1
			elseif object.getName() == 'VP Token' then
				count = count + tonumber(object.getDescription())
			end
		end
		buttonZone.editButton({index = 0, label = count})
	end
end

-- modular-board equivalent of moveControlMarker below - same flip + "collect into player's own area" logic,
-- adapted to demonwebActiveMarkers' shape instead of boardSections' controlMarkers. Reuses
-- trackControlMarkersForPlayer() and playerVars[...].controlMarkerPositions unchanged, since those are
-- generic (any object tagged 'control' in the player's play area, regardless of which board it came from).
function demonwebMoveControlMarker(playerColor, markerInfo, playersControlMarkers, messageFlag)
	local winner, points, totalControl = demonwebSiteControlCheck(markerInfo.siteZoneGuid)
	-- Bregan D'aerthe Spy (Mercenaries): overrides the normal troop-count result while stolen, so the thief
	-- holds Total Control of this site regardless of actual troops there, until demonwebRevertStolenMarkersForPlayer()
	-- clears it at the start of their next turn (see onPlayerTurn/passTurnDueToTimeout)
	if demonwebStolenMarkers[markerInfo.guid] ~= nil then
		winner = demonwebStolenMarkers[markerInfo.guid]
		totalControl = true
	end
	local controlMarker = getObjectFromGUID(markerInfo.guid)
	if controlMarker == nil then return nil, false end
	if winner == nil then
		-- return control marker to the site if it isn't there already
		local curPos = controlMarker.getPosition()
		local dx, dz = curPos[1] - markerInfo.homePos[1], curPos[3] - markerInfo.homePos[3]
		if dx*dx + dz*dz > 0.01 then
			controlMarker.setRotationSmooth({0, 180, 0}, false, false)
			controlMarker.setPositionSmooth({markerInfo.homePos[1], markerInfo.homePos[2], markerInfo.homePos[3]}, false, false)
		end
		if controlMarker.is_face_down then controlMarker.flip() end
	else
		-- flip control marker to the correct side
		if (totalControl and not controlMarker.is_face_down) or (not totalControl and controlMarker.is_face_down) then controlMarker.flip() end
		
		-- send control marker to the winning player's own area
		if playersControlMarkers[winner] == nil then
			playersControlMarkers[winner] = trackControlMarkersForPlayer(winner)
		end
		
		local hasPossession = false
		for _, guid in ipairs(playersControlMarkers[winner].possessedControlMarkerGuids) do
			if markerInfo.guid == guid then hasPossession = true break end
		end
		if hasPossession then
			if messageFlag and winner == playerColor then broadcastToColor('You already have this control marker.', playerColor) end
		else
			local toPos = nil
			if #playersControlMarkers[winner].unoccupiedControlPositions == 0 then
				local controlMarkerPositions = playerVars[winner].controlMarkerPositions
				local temp = controlMarkerPositions[#controlMarkerPositions]
				toPos = {temp[1] + 2, temp[2] + 0.5, temp[3]}
			else
				local temp = playersControlMarkers[winner].unoccupiedControlPositions[1]
				toPos = {temp[1], temp[2] + 0.3, temp[3]}
				table.remove(playersControlMarkers[winner].unoccupiedControlPositions, 1)
			end
			controlMarker.setPositionSmooth(toPos, false, false)
		end
	end
	if messageFlag and playerColor ~= winner then broadcastToColor('You do not have control of this site.', playerColor) end
	return winner, totalControl
end

function moveControlMarker(playerColor, controlMarkerInfo, playersControlMarkers, messageFlag)
	if status.boardMode ~= 'standard' then return nil, false end
	local winner, points, totalControl = siteControlCheck(controlMarkerInfo.siteZoneGuid)
	-- Bregan D'aerthe Spy (Mercenaries) - see the matching override in demonwebMoveControlMarker() above
	if demonwebStolenMarkers[controlMarkerInfo.guid] ~= nil then
		winner = demonwebStolenMarkers[controlMarkerInfo.guid]
		totalControl = true
	end
	local controlMarker = getObjectFromGUID(controlMarkerInfo.guid)
	if winner == nil then
		-- return control marker to site if no one has control
		local buttonZone = getObjectFromGUID(controlMarkerInfo.buttonZoneGuid)
		local atSite = false
		for _, object in ipairs(buttonZone.getObjects()) do
			if object.getGUID() == controlMarkerInfo.guid then atSite = true break end
		end
		if not atSite then
			local toPos = buttonZone.getPosition()
			controlMarker.setRotationSmooth(faceup, false, false)
			controlMarker.setPositionSmooth({toPos[1], 1.58, toPos[3]}, false, false)
		end
		-- alt markers: with no controller, the "Control" design (now the back, after the face/back swap in
		-- setAltMarkerLook) should be showing, not whatever face it happened to be left on
		if altMarkerData[controlMarkerInfo.guid] ~= nil and not controlMarker.is_face_down then
			controlMarker.flip()
		end
	else
		-- flip control marker to correct side
		if (totalControl and controlMarker.is_face_down) or (not totalControl and not controlMarker.is_face_down) then controlMarker.flip() end
		
		-- send control marker to player's board
		if playersControlMarkers[winner] == nil then
			playersControlMarkers[winner] = trackControlMarkersForPlayer(winner)
		end
		
		local hasPossession = false
		for _, guid in ipairs(playersControlMarkers[winner].possessedControlMarkerGuids) do
			if controlMarkerInfo.guid == guid then hasPossession = true break end
		end
		if hasPossession then
			if messageFlag and winner == playerColor then broadcastToColor('You already have this control marker.', playerColor) end
		else
			local toPos = nil
			if #playersControlMarkers[winner].unoccupiedControlPositions == 0 then
				local controlMarkerPositions = playerVars[playerColor].controlMarkerPositions
				local temp = controlMarkerPositions[#controlMarkerPositions]
				toPos = {temp[1] + 2, temp[2] + 0.5, temp[3]}
			else
				local temp = playersControlMarkers[winner].unoccupiedControlPositions[1]
				toPos = {temp[1], temp[2] + 0.3, temp[3]}
				table.remove(playersControlMarkers[winner].unoccupiedControlPositions, 1)
			end
			controlMarker.setPositionSmooth(toPos, false, false)
		end
	end
	if messageFlag and playerColor ~= winner then broadcastToColor('You do not have control of this site.', playerColor) end
	return winner, totalControl
end

function trackControlMarkersForPlayer(playerColor)
	-- track which control markers this player has in their play area and which control marker snap points are occupied
	local possessedControlMarkerGuids = {}
	local unoccupiedControlPositions = {}
	for _, position in ipairs(playerVars[playerColor].controlMarkerPositions) do
		table.insert(unoccupiedControlPositions, position)
	end
	for _, object in ipairs(getObjectFromGUID(playerVars[playerColor].playZoneGuid).getObjects()) do
		if object.hasTag('control') then
			table.insert(possessedControlMarkerGuids, object.getGUID())
			local markerPosition = object.getPosition()
			for i, unoccupiedPosition in ipairs(unoccupiedControlPositions) do
				if math.abs(unoccupiedPosition[1] - markerPosition[1]) < 0.1 and math.abs(unoccupiedPosition[3] - markerPosition[3]) < 0.1 then
					table.remove(unoccupiedControlPositions, i)
					break
				end
			end
		end
	end
	return {possessedControlMarkerGuids = possessedControlMarkerGuids, unoccupiedControlPositions = unoccupiedControlPositions}
end

---------------------- SCORING

function setupScoreboards()
	if status.gameState < 1 then return end
	UI.setAttribute('siteScoreboard', 'offsetXY', -30-70* #seatedPlayerColors .. ' -190')
	for i, playerColor in ipairs(seatedPlayerColors) do
		UI.setValue('ss-name' .. playerColor, getPlayerName(playerColor, false))
		UI.setAttribute('siteScoreboard' .. playerColor, 'offsetXY', -30-70*(#seatedPlayerColors-i) .. ' -190')
		
		UI.setValue('name' .. playerColor, getPlayerName(playerColor, false))
		UI.setAttribute('scoreboard' .. playerColor, 'offsetXY', 140+i*70 .. ' -140')
	end
end

function showSitePoints(buttonZone, clickColor, alt)
	if not status.doneLoading or not isSeated(clickColor) and clickColor ~= 'Black' then return end
	local button = buttonZone.getButtons()[1]
	if button.label ~= buttonText.showSitePoints then return end
	
	buttonZone.editButton({index = 0, label = 'Wait...'})
	printToAll(getPlayerName(clickColor, true) .. ' toggled the site control scoreboard.')
	local siteControlPoints, totalControlPoints = countSiteControlPointsPerPlayer()
	
	UI.setAttribute('siteScoreboard', 'active', true)
	for i, playerColor in ipairs(seatedPlayerColors) do
		UI.setValue('ss-siteControl' .. playerColor, siteControlPoints[playerColor])
		UI.setValue('ss-totalControl' .. playerColor, totalControlPoints[playerColor])
		UI.setValue('ss-sum' .. playerColor, siteControlPoints[playerColor] + totalControlPoints[playerColor])
		UI.setAttribute('siteScoreboard' .. playerColor, 'active', true)
	end
	
	Wait.time(function()
		UI.setAttribute('siteScoreboard', 'active', false)
		for playerColor, _ in pairs(playerVars) do
			UI.setAttribute('siteScoreboard' .. playerColor, 'active', false)
		end
		buttonZone.editButton({index = 0, label = buttonText.showSitePoints})
	end, 8)
end

function menuToggleScoreboard(player, value, id)
	if not status.doneLoading or UI.getAttribute('toggleScoreboard', 'color') == 'Grey' or not isSeated(player.color) and player.color ~= 'Black' then return end
	printToAll(getPlayerName(player.color, true) .. ' toggled the scoreboard.')
	if UI.getAttribute('scoreboard', 'active') == 'true' or UI.getAttribute('scoreboard', 'active') == 'True' then
		UI.setAttribute('scoreboard', 'active', false)
		for playerColor, _ in pairs(playerVars) do
			UI.setAttribute('scoreboard' .. playerColor, 'active', false)
		end
	else
		UI.setAttribute('scoreboard', 'active', true)
		for _, playerColor in ipairs(seatedPlayerColors) do
			UI.setAttribute('scoreboard' .. playerColor, 'active', true)
		end
	end
end

function menuDisplayDecks(player, value, id)
	if not status.doneLoading or UI.getAttribute('displayDecks', 'color') == 'Grey' or not isSeated(player.color) and player.color ~= 'Black' then return end
	printToAll(getPlayerName(player.color, true) .. ' clicked the Display Decks button.')
	if UI.getAttribute('displayDecks', 'color') == 'Red' then
		UI.setAttributes('displayDecks', {text =  buttonText.displayDecks, textColor = 'white', color = 'Grey'})
		UI.setAttributes('score', {text = 'Recalculate Scores', textColor = 'white', color = 'Grey'})
		local cardWidth = 5.16
		local cardHeight = 6.84
		local y = 7.2
		for _, playerColor in ipairs(seatedPlayerColors) do
			local deckList = {}
			findCards(playerVars[playerColor].deckZoneGuid, deckList)
			findCards(playerVars[playerColor].discardZoneGuid, deckList)
			findCards(playerVars[playerColor].playZoneGuid, deckList)
			for _, object in ipairs(Player[playerColor].getHandObjects()) do
				if object.type == 'Card' then table.insert(deckList, object) end
			end
			
			table.sort(deckList, function(a, b)
				local descA = tonumber(a.getDescription())
				local descB = tonumber(b.getDescription())
				if descA == nil then descA = 0 end
				if descB == nil then descB = 0 end
				
				if descA == descB then
					return a.getName() < b.getName()
				end
				return descA < descB
			end)
			
			local rows = 5
			if #deckList <= 10 then rows = 2
			elseif #deckList <= 18 then rows = 3
			elseif #deckList <= 32 then rows = 4
			end
			local columns = math.floor(#deckList / rows)
			local zonePos = getObjectFromGUID(playerVars[playerColor].allZoneGuid).getPosition()
			local startPos = {zonePos[1] - (columns/2) * cardWidth, y, zonePos[3] - (rows/2) * cardHeight}
			local xOffset = 0
			local zOffset = 0
			for i, card in ipairs(deckList) do
				local pos = {startPos[1] + xOffset * cardWidth, y, startPos[3] + zOffset * cardHeight}
				xOffset = xOffset + 1
				if xOffset > columns then
					xOffset = 0
					zOffset = zOffset + 1
				end
				card.use_hands = false
				card.setRotationSmooth(faceup, false, true)
				card.setPositionSmooth(pos, false, false)
				Wait.time(function()
					card.lock()
					card.use_hands = true 
				end, 0.3)
			end
		end
		status.displayed = true
	else
		broadcastToAll("Are you sure you want to splay all players' cards?")
		Wait.time(function()
			UI.setAttributes('displayDecks', {text = 'Confirm', textColor = 'white', color = 'Red'})
		end, 0.2)
		Wait.time(function()
			if UI.getAttribute('displayDecks', 'color') == 'Red' then
				UI.setAttributes('displayDecks', {text = buttonText.displayDecks, textColor = 'white', color = 'rgb(0.42, 0.28, 0.60)'})
			end
		end, 3.5)
	end
end

function findCards(zoneGuid, deckList)
	for _, object in ipairs(getObjectFromGUID(zoneGuid).getObjects()) do
		if object.type == 'Card' then table.insert(deckList, object)
		elseif object.type == 'Deck' then
			for i=1, object.getQuantity() do
				local card = object.takeObject()
				table.insert(deckList, card)
			end
		end
	end
end

-- multiplayer ELO update: every pair of seated players is treated as its own 1v1 comparison based on final
-- score (higher score = "win", equal = draw), and each player's rating change is the average delta across
-- all the pairs they're part of - a standard way to extend 1v1 ELO to N players without favoring turn order
-- or requiring a single, all-or-nothing "winner". playersWithScores is a list of {steamId, name, score}.
-- fetches the current rating table from the Google Sheet (see Code.gs). callback receives a list of
-- {steamId, name, rating, games}, or nil if the request failed (network issue, URL not configured, etc).
function fetchPlayerRatings(callback)
	if ratingsApiUrl == 'PLACEHOLDER_RATINGS_API_URL' then
		callback(nil, 'Ratings API URL is not configured yet.')
		return
	end
	WebRequest.get(ratingsApiUrl, function(request)
		if request.is_error or request.response_code ~= 200 then
			callback(nil, 'Ratings request failed: ' .. tostring(request.error))
			return
		end
		local ok, decoded = pcall(function() return JSON.decode(request.text) end)
		if not ok or decoded == nil then
			callback(nil, 'Ratings response was not valid JSON.')
			return
		end
		callback(decoded)
	end)
end

-- pushes updated ratings (a list of {steamId, name, rating, games}) to the Google Sheet
function postPlayerRatings(players, callback)
	if ratingsApiUrl == 'PLACEHOLDER_RATINGS_API_URL' then
		if callback then callback(false) end
		return
	end
	WebRequest.post(ratingsApiUrl, {payload = JSON.encode({players = players})}, function(request)
		if callback then callback(not request.is_error and request.response_code == 200) end
	end)
end

-- ELO update, now fetching the authoritative current ratings from the shared sheet first (rather than
-- trusting a local cache, which could be stale relative to games played from a different save/device),
-- then posting the recomputed ratings back
function updatePlayerRatings(playersWithScores)
	if #playersWithScores < 2 then return end
	
	fetchPlayerRatings(function(remoteList, errorMsg)
		if remoteList == nil then
			broadcastToAll('Could not update ratings (' .. tostring(errorMsg) .. '). Scores are unaffected.')
			return
		end
		local remoteById = {}
		for _, info in ipairs(remoteList) do remoteById[info.steamId] = info end
		
		local n = #playersWithScores
		local currentRatings = {}
		local gamesPlayed = {}
		for _, p in ipairs(playersWithScores) do
			local existing = remoteById[p.steamId]
			currentRatings[p.steamId] = existing and existing.rating or ratingStartingValue
			gamesPlayed[p.steamId] = existing and existing.games or 0
		end
		
		local totalDelta = {}
		for _, p in ipairs(playersWithScores) do totalDelta[p.steamId] = 0 end
		
		for i = 1, n do
			for j = 1, n do
				if i ~= j then
					local a, b = playersWithScores[i], playersWithScores[j]
					local ratingA, ratingB = currentRatings[a.steamId], currentRatings[b.steamId]
					local expected = 1 / (1 + 10 ^ ((ratingB - ratingA) / 400))
					local actual = 0.5
					if a.score > b.score then actual = 1
					elseif a.score < b.score then actual = 0
					end
					totalDelta[a.steamId] = totalDelta[a.steamId] + ratingKFactor * (actual - expected)
				end
			end
		end
		
		local updatedPlayers = {}
		local summaryLines = {}
		for _, p in ipairs(playersWithScores) do
			local avgDelta = totalDelta[p.steamId] / (n - 1)
			local newRating = math.floor(currentRatings[p.steamId] + avgDelta + 0.5)
			local newGames = gamesPlayed[p.steamId] + 1
			table.insert(updatedPlayers, {steamId = p.steamId, name = p.name, rating = newRating, games = newGames})
			local sign = avgDelta >= 0 and '+' or ''
			table.insert(summaryLines, p.name .. ': ' .. currentRatings[p.steamId] .. ' -> ' .. newRating .. ' (' .. sign .. math.floor(avgDelta + 0.5) .. ')')
		end
		
		postPlayerRatings(updatedPlayers, function(success)
			if success then
				broadcastToAll('Ratings updated: ' .. table.concat(summaryLines, '; '))
			else
				broadcastToAll('Ratings were computed but failed to save to the shared sheet.')
			end
		end)
	end)
end

-- shows every known player's current rating, sorted highest first, fetched fresh from the shared sheet
function showPlayerRatings(playerColor)
	fetchPlayerRatings(function(remoteList, errorMsg)
		if remoteList == nil then
			broadcastToColor('Could not load ratings (' .. tostring(errorMsg) .. ').', playerColor)
			return
		end
		table.sort(remoteList, function(a, b) return a.rating > b.rating end)
		
		local maxRows = 12
		for i = 1, maxRows do
			if remoteList[i] ~= nil then
				UI.setValue('ratingsRank' .. i, tostring(i))
				UI.setValue('ratingsName' .. i, remoteList[i].name)
				UI.setValue('ratingsValue' .. i, tostring(remoteList[i].rating))
				UI.setValue('ratingsGames' .. i, tostring(remoteList[i].games))
			else
				-- rows can't be individually hidden in this XML UI version, so unused ones are just left blank
				UI.setValue('ratingsRank' .. i, '')
				UI.setValue('ratingsName' .. i, '')
				UI.setValue('ratingsValue' .. i, '')
				UI.setValue('ratingsGames' .. i, '')
			end
		end
		
		UI.setAttribute('ratingsPanel', 'active', true)
	end)
end

function closeRatingsPanel(player, value, id)
	UI.setAttribute('ratingsPanel', 'active', false)
end

function onShowRatingsClick(buttonZone, clickColor, alt)
	showPlayerRatings(clickColor)
end

function menuScore(player, value, id)
	if not status.doneLoading or UI.getAttribute('score', 'color') == 'Grey' or not isSeated(player.color) and player.color ~= 'Black' then return end
	status.doneLoading = false
	printToAll(getPlayerName(player.color, true) .. ' calculated scores.')
	
	function menuScoreCoroutine()
		wait(0.4)
		function checkShuffling()
			for _, flag in pairs(status.shuffling) do
				if flag then return false end
			end
			return true
		end
		repeat coroutine.yield(0) until checkShuffling()
		
		local siteControlPoints, totalControlPoints = countSiteControlPointsPerPlayer()
		local topScore = 0
		local winners = {}
		local playersWithScores = {}
		for _, playerColor in ipairs(seatedPlayerColors) do
			local deckPoints = sumCardPoints(playerVars[playerColor].deckZoneGuid, 1)
			deckPoints = deckPoints + sumCardPoints(playerVars[playerColor].discardZoneGuid, 1)
			deckPoints = deckPoints + sumCardPoints(playerVars[playerColor].playZoneGuid, 1)
			for _, object in ipairs(Player[playerColor].getHandObjects()) do
				if object.type == 'Card' then
					deckPoints = deckPoints + tonumber(string.sub(object.getGMNotes(), 1, 2))
				end
			end
			UI.setValue('deck' .. playerColor, deckPoints)
			
			local innerCirclePoints = sumCardPoints(playerVars[playerColor].circleZoneGuid, 3)
			UI.setValue('circle' .. playerColor, innerCirclePoints)
			
			local trophyPoints = 0
			local vpPoints = 0
			for _, object in ipairs(getObjectFromGUID(playerVars[playerColor].trophyZoneGuid).getObjects()) do
				if object.hasTag('troop') then
					trophyPoints = trophyPoints + 1
				elseif object.getName() == 'VP Token' then
					vpPoints = vpPoints + tonumber(object.getDescription())
				end
			end
			UI.setValue('trophy' .. playerColor, trophyPoints)
			UI.setValue('vp' .. playerColor, vpPoints)
			UI.setValue('siteControl' .. playerColor, siteControlPoints[playerColor])
			UI.setValue('totalControl' .. playerColor, totalControlPoints[playerColor])
			
			local sum = deckPoints + innerCirclePoints + trophyPoints + vpPoints + siteControlPoints[playerColor] + totalControlPoints[playerColor]
			UI.setValue('sum' .. playerColor, sum)
			table.insert(playersWithScores, {steamId = tostring(Player[playerColor].steam_id), name = getPlayerName(playerColor), score = sum})
			if sum > topScore then
				topScore = sum
				winners = {playerColor}
			elseif sum == topScore then
				table.insert(winners, playerColor)
			end
		end
		
		if not status.ratingsAppliedThisGame then
			status.ratingsAppliedThisGame = true
			updatePlayerRatings(playersWithScores)
		end
		
		UI.setAttribute('scoreboard', 'active', true)
		for i, playerColor in ipairs(seatedPlayerColors) do
			UI.setAttribute('scoreboard' .. playerColor, 'active', true)
		end
		UI.setAttributes('score', {text = 'Recalculate Scores', textColor = 'white'})
		UI.setAttributes('toggleScoreboard', {textColor = 'white', color = 'rgb(0.42, 0.28, 0.60)'})
		if not status.displayed then
			UI.setAttributes('displayDecks', {textColor = 'white', color = 'rgb(0.42, 0.28, 0.60)'})
		end
		
		if #winners == 1 then
			broadcastToAll(getPlayerName(winners[1], true) .. ' wins!')
		elseif #winners > 1 then
			broadcastToAll(listText(winners, true) .. ' are tied!')
		end
		status.doneLoading = true
		return 1
	end
	startLuaCoroutine(Global, 'menuScoreCoroutine')
end

function countSiteControlPointsPerPlayer()
	local siteControlPoints = {Red = 0, Blue = 0, Purple = 0, Teal = 0}
	local totalControlPoints = {Red = 0, Blue = 0, Purple = 0, Teal = 0}
	if status.boardMode == 'modular' then
		for _, zoneGuid in ipairs(demonwebActiveSiteZoneGuids) do
			local winner, points, totalControl = demonwebSiteControlCheck(zoneGuid)
			if winner ~= nil then
				siteControlPoints[winner] = siteControlPoints[winner] + points
				if totalControl then
					totalControlPoints[winner] = totalControlPoints[winner] + 2
				end
			end
		end
		-- A2's regional bonus is intentionally NOT folded in here - it's delivered as physical VP tokens
		-- every turn instead (see demonwebDeliverTotalControlVpsCoroutine), so adding it here too would
		-- double-count it on the score display/final tally on top of the tokens already in the player's pool
		return siteControlPoints, totalControlPoints
	end
	if status.boardMode ~= 'standard' then return siteControlPoints, totalControlPoints end
	for _, section in ipairs(status.boardSectionsUsed) do
		for _, zoneGuid in ipairs(boardSections[section].siteZoneGuids) do
			local winner, points, totalControl = siteControlCheck(zoneGuid)
			if winner ~= nil then
				siteControlPoints[winner] = siteControlPoints[winner] + points
				if totalControl then
					totalControlPoints[winner] = totalControlPoints[winner] + 2
				end
			end
		end
	end
	return siteControlPoints, totalControlPoints
end

function siteControlCheck(zoneGuid)
	local zone = getObjectFromGUID(zoneGuid)
	if zone == nil then return nil, 0, false end	-- guards against a stale/destroyed zone guid crashing the
													-- whole counting loop instead of just skipping that one site
	local troopSpaces = tonumber(zone.getName())
	local points = tonumber(zone.getDescription())
	local troops = {Red = 0, Blue = 0, Purple = 0, Teal = 0, White = 0}
	local spies = {}
	for _, object in ipairs(zone.getObjects()) do
		if object.hasTag('troop') then
			troops[object.getDescription()] = troops[object.getDescription()] + 1
		elseif object.hasTag('spy') then
			table.insert(spies, object.getDescription())
		end
	end
	
	local winner = nil
	local winningCount = 0
	for playerColor, count in pairs(troops) do
		if count > 0 then
			if count == winningCount then
				winner = nil
			elseif count > winningCount then
				winner = playerColor
				winningCount = count
			end
		end
	end
	
	local totalControl = false
	if winner == 'White' then winner = nil end
	if winner ~= nil then
		if winningCount == troopSpaces then
			totalControl = true
			for _, spyColor in ipairs(spies) do
				if spyColor ~= winner then totalControl = false break end
			end
		end
	end
	return winner, points, totalControl
end

function sumCardPoints(zoneGuid, i)
	local score = 0
	for _, object in ipairs(getObjectFromGUID(zoneGuid).getObjects()) do
		if object.type == 'Card' then
			score = score + tonumber(string.sub(object.getGMNotes(), i, i+1))
		elseif object.type == 'Deck' then
			for _, card in ipairs(object.getObjects()) do
				score = score + tonumber(string.sub(card.gm_notes, i, i+1))
			end
		end
	end
	return score
end

---------------------- EVENTS

function onObjectEnterScriptingZone(zone, enteringObject)
	if not status.doneLoading or status.setupInProgress or status.gameState < 1 then return end
	if options.promoteCounters and zone.getName() == 'Inner Circle' and (enteringObject.type == 'Card' or enteringObject.type == 'Deck') then
		local playerColor = zone.getDescription()
		updatePromoteCounter(playerColor)
	elseif options.trophyCounters and zone.getName() == 'Trophy Hall' and (enteringObject.hasTag('troop') or enteringObject.getName() == 'VP Token') then
		local playerColor = zone.getDescription()
		if status.countingTrophies[zone.getDescription()] then return end
		status.countingTrophies[playerColor] = true
		
		function enterZoneCoroutine()
			wait(0.1)
			updateTrophyCounter(playerColor)
			status.countingTrophies[playerColor] = false
			return 1
		end
		startLuaCoroutine(Global, 'enterZoneCoroutine')
	end
end

function onObjectLeaveScriptingZone(zone, leavingObject)
	if not status.doneLoading or status.setupInProgress or status.gameState < 1 then return end
	if options.promoteCounters and zone.getName() == 'Inner Circle' and (leavingObject.type == 'Card' or leavingObject.type == 'Deck') then
		local playerColor = zone.getDescription()
		updatePromoteCounter(playerColor)
	elseif options.trophyCounters and zone.getName() == 'Trophy Hall' and (leavingObject.hasTag('troop') or leavingObject.getName() == 'VP Token') then
		local playerColor = zone.getDescription()
		if status.countingTrophies[zone.getDescription()] then return end
		status.countingTrophies[playerColor] = true
		
		function leaveZoneCoroutine()
			wait(0.1)
			updateTrophyCounter(playerColor)
			status.countingTrophies[playerColor] = false
			return 1
		end
		startLuaCoroutine(Global, 'leaveZoneCoroutine')
	elseif zone.getName() == 'Deck' and not status.checkingDeck and (leavingObject.type == 'Card' or leavingObject.type == 'Deck') then
		status.checkingDeck = true
		Wait.time(function()
			if updateMarketDeckCounter() == 0 then
				UI.setAttribute('calculateScoreMenu', 'active', true)
				status.gameState = 2
				requestTurnTimerStop()
			end
			status.checkingDeck = false
		end, 0.02)
	end
end

function updateMarketDeckCounter()
	local buttonZone = getObjectFromGUID(market.bottom[1])
	local deck = findDeck(buttonZone)
	local count = 0
	if deck ~= nil then
		count = deck.getQuantity()
		if count == -1 then count = 1 end
	end
	if buttonZone.getButtons() ~= nil and #buttonZone.getButtons() == 1 then
		buttonZone.editButton({index = 0, label = count})
	end
	return count
end

function onObjectEnterContainer(container, enteringObject)
	if container.getDescription() ~= 'Troop Bag' or not status.doneLoading or status.setupInProgress or status.gameState < 1 then return end
	local playerColor = container.getGMNotes()
	local buttonZone = getObjectFromGUID(playerVars[playerColor].troopCounterZoneGuid)
	buttonZone.editButton({index = 0, label = container.getQuantity()})
end

function onObjectLeaveContainer(container, leavingObject)
	addMenuItems(leavingObject)
	if status.gameState > 0 and container.getDescription() == 'Troop Bag' then
		local playerColor = container.getGMNotes()
		local buttonZone = getObjectFromGUID(playerVars[playerColor].troopCounterZoneGuid)
		buttonZone.editButton({index = 0, label = container.getQuantity()})
		
		if container.getQuantity() == 0 then
			UI.setAttribute('calculateScoreMenu', 'active', true)
			status.gameState = 2
			requestTurnTimerStop()
		end
	end
end

function filterObjectEnterContainer(container, object)
	if container.getDescription() == 'Troop Bag' then
		if not object.hasTag('troop') or object.getDescription() ~= container.getGMNotes() then return false end
	end
	return true
end

function onPlayerTurn(player, previousPlayer)
	-- tts bug: when rewinding time or saving a script, onPlayerTurn triggers with non-nil player that has '' color
	if not status.doneLoading or status.gameState < 1 or player == nil or player.color == '' then return end
	
	status.turn = player.color
	demonwebRevertStolenMarkersForPlayer(player.color)
	if status.timer.suppressNextTurnCleanup then
		-- passTurnDueToTimeout() already ran this player's end-of-turn cleanup manually (see there for why)
		status.timer.suppressNextTurnCleanup = false
	elseif previousPlayer ~= nil and isSeated(previousPlayer.color) then
		demonwebResolveEndOfTurnEffects(previousPlayer.color)
		if options.autoTotalControlVp then deliverTotalControlVps(previousPlayer.color) end
		if options.autoSendToDiscard then discardAndDraw(previousPlayer.color) end
		demonwebResetResourcePool(previousPlayer.color)
		demonwebResetFreeActions(previousPlayer.color)
	end
	for _, guid in ipairs(market.top) do
		refillMarketSpace(guid)
	end
	
	-- turn timer: every turn change resets the clock for whoever's turn it now is, as long as a timer session
	-- is running - unless an end-game trigger fired earlier this round and play has now come back around to
	-- the first player, in which case the round is complete and the timer stops instead
	if status.timer.active then
		if status.timer.pendingStop and player.color == status.firstPlayerColor then
			stopTurnTimer()
		else
			resetTurnTimer()
		end
	end
end

function discardAndDraw(playerColor)
	function discardAndDrawCoroutine()
		status.shuffling[playerColor] = true
		-- send to discard all including hand
		local sentToDiscardCount = sendToDiscard(playerColor, playerColor)
		if #Player[playerColor].getHandObjects() > 0 then
			local playZonePos = getObjectFromGUID(playerVars[playerColor].playZoneGuid).getPosition()
			local discardZonePos = getObjectFromGUID(playerVars[playerColor].discardZoneGuid).getPosition()
			local fromPosition = {discardZonePos[1], 3.5, playZonePos[3] - 6.6}
			local toPos = {discardZonePos[1], discardZonePos[2] + 0.5, discardZonePos[3]}
			for _, object in ipairs(Player[playerColor].getHandObjects()) do
				if object.type == 'Card' then 
					object.setPosition(fromPosition)
					object.setPositionSmooth(toPos, false, true)
					sentToDiscardCount = sentToDiscardCount + 1
				end
			end
		end
		
		-- draw
		if sentToDiscardCount > 0 then wait(0.72) end
		local handSize = 5
		local drawn = 0
		for _, object in ipairs(getObjectFromGUID(playerVars[playerColor].deckZoneGuid).getObjects()) do
			if drawn >= handSize then break end
			if object.type == 'Card' then
				object.deal(1, playerColor)
				drawn = drawn + 1
			elseif object.type == 'Deck' then
				local numberToDraw = handSize - drawn
				if object.getQuantity() >= numberToDraw then drawn = drawn + numberToDraw
				else drawn = drawn + object.getQuantity()
				end
				object.deal(numberToDraw, playerColor)
			end
		end
		
		-- refill deck and draw more
		if drawn < handSize then
			if drawn > 0 then wait(0.6) end
			refillDeck(playerColor, playerColor)
			wait(1.52)
			local deck = findDeck(getObjectFromGUID(playerVars[playerColor].deckZoneGuid))
			if deck ~= nil then deck.deal(handSize - drawn, playerColor) end
		end
		wait(0.6)
		status.shuffling[playerColor] = false
		return 1
	end
	startLuaCoroutine(Global, 'discardAndDrawCoroutine')
end

-- modular-board equivalent of deliverTotalControlVpsCoroutine below - there's no physical marker to flip
-- (sites are tracked purely by troop count via siteControlCheck), and every site's total-control bonus is a
-- flat 2 VP, matching the convention already used for the modular map in countSiteControlPointsPerPlayer.
function demonwebDeliverTotalControlVps(playerColor)
	function demonwebDeliverTotalControlVpsCoroutine()
		local vpToTake = 0
		local siteNames = {}
		local playersControlMarkers = {}
		for _, markerInfo in ipairs(demonwebActiveMarkers) do
			-- move (flip + collect into the winner's own area) the marker, same as the "Take" button does
			local winner, totalControl = demonwebMoveControlMarker(playerColor, markerInfo, playersControlMarkers)
			if winner == playerColor and totalControl and markerInfo.vp > 0 then
				vpToTake = vpToTake + markerInfo.vp
				local zone = getObjectFromGUID(markerInfo.siteZoneGuid)
				if zone ~= nil then table.insert(siteNames, zone.getGMNotes()) end
			end
		end

		-- A2's regional bonus (Fogtown/Gallenghast/Darkflame, no physical marker of their own - see
		-- demonwebCheckA2Bonus) pays out here too, on the same "every turn it still holds" cadence as the
		-- named sites above: +1 VP for controlling all 3, or +4 VP instead if all 3 are Total Controlled
		local a2Winner, a2TotalControl = demonwebCheckA2Bonus()
		if a2Winner == playerColor then
			vpToTake = vpToTake + (a2TotalControl and 4 or 1)
			table.insert(siteNames, a2TotalControl and 'Fogtown/Gallenghast/Darkflame (Total Control)' or 'Fogtown/Gallenghast/Darkflame')
		end

		if vpToTake > 0 then
			broadcastToAll(getPlayerName(playerColor, true) .. ' gets ' .. vpToTake .. ' VP for total control of ' .. listText(siteNames) .. '.')
			local fives = math.floor(vpToTake/5)
			local ones = vpToTake - 5 * fives
			if fives > 0 then
				for k = 1, fives do
					takeVp(vpBags.right[1], playerColor)
					wait(0.22)
				end
			end
			if ones > 0 then
				for k = 1, ones do
					takeVp(vpBags.left[1], playerColor)
					wait(0.22)
				end
			end
		end
		return 1
	end
	startLuaCoroutine(Global, 'demonwebDeliverTotalControlVpsCoroutine')
end

function deliverTotalControlVps(playerColor)
	if status.boardMode == 'modular' then demonwebDeliverTotalControlVps(playerColor) return end
	if status.boardMode ~= 'standard' then return end
	function deliverTotalControlVpsCoroutine()
		local vpToTake = 0
		local siteNames = {}
		local playersControlMarkers = {}
		for _, section in ipairs(status.boardSectionsUsed) do
			for _, controlMarkerInfo in ipairs(boardSections[section].controlMarkers) do
				-- move the control marker
				local winner, totalControl = moveControlMarker(playerColor, controlMarkerInfo, playersControlMarkers)
				if winner == playerColor and totalControl and not altMarkerVpDisabled[controlMarkerInfo.guid] then
					-- count vp tokens earned (skipped if this site's current alt-marker art shows no VP bonus)
					vpToTake = vpToTake + controlMarkerInfo.totalControlVp
					table.insert(siteNames, controlMarkerInfo.name)
				end
			end
		end
		
		-- give vp tokens to the player that passed the turn
		if vpToTake > 0 then
			broadcastToAll(getPlayerName(playerColor, true) .. ' gets ' .. vpToTake .. ' VP for total control of ' .. listText(siteNames) .. '.')
			local fives = math.floor(vpToTake/5)
			local ones = vpToTake - 5 * fives
			if fives > 0 then
				for k = 1, fives do
					takeVp(vpBags.right[1], playerColor)
					wait(0.22)
				end
			end
			if ones > 0 then
				for k = 1, ones do
					takeVp(vpBags.left[1], playerColor)
					wait(0.22)
				end
			end
		end
		return 1
	end
	startLuaCoroutine(Global, 'deliverTotalControlVpsCoroutine')
end

function onPlayerChangeColor(playerColor)
	if playerColor == 'Grey' then return end
	Wait.time(function()
		Player[playerColor].lookAt({position = {0,0,-6.5}, pitch = 72, yaw = 0, distance = 74})
	end, 0.01)
end

-- standalone versions of the 4 addHotkey actions (factored out so both the player-configurable hotkey
-- AND the fixed number keys below can call the exact same logic without duplicating it)
function hotkeyAssassinateDevour(playerColor, hoverObj)
	if hoverObj == nil then return end
	if hoverObj.hasTag('troop') then assassinate(playerColor, hoverObj)
	elseif hoverObj.type == 'Card' then devour(playerColor, hoverObj)
	end
end

function hotkeySupplantPromote(playerColor, hoverObj)
	if hoverObj == nil then return end
	if hoverObj.hasTag('troop') then supplant(playerColor, hoverObj)
	elseif hoverObj.type == 'Card' then promote(playerColor, hoverObj)
	end
end

function hotkeyReturnTake(playerColor, hoverObj)
	if hoverObj == nil then return end
	if hoverObj.hasTag('control') then contextMenuTakeControl(playerColor, hoverObj)
	else returnFigure(playerColor, hoverObj)
	end
end

-- Confirmed by testing: hovering a spy figure and typing any number never even reaches
-- onObjectNumberTyped (no event fires at all, on that object specifically) - yet the exact same figure's
-- own right-click "Return" context menu item works fine, so the object itself is perfectly interactive
-- and it's specifically TTS's number-typed-while-hovering event that won't fire for it. Separately, testing
-- also showed top-row 1/5 silently do nothing over most of a modular hex's own printed art (they only work
-- directly over an existing troop/circle) - onObjectNumberTyped requires hovering AN OBJECT to fire at
-- all, and the modular board's hex tiles apparently don't count as "hovered" everywhere across their own
-- surface. Neither of these can be fixed from inside onObjectNumberTyped, since in both cases the event
-- never reaches our code to begin with. onScriptingButtonDown (fires on Numpad keys by default,
-- independent of what's hovered - or even whether anything is) is the reliable substitute for both: Numpad
-- 5 returns the nearest spy if one's close to the pointer, otherwise places a new one; Numpad 1/6-9/0
-- deploy troops exactly like their top-row counterparts, just without depending on hover at all.
function onScriptingButtonDown(index, playerColor)
	if not status.doneLoading or status.setupInProgress or not isSeated(playerColor) then return end
	if index == 5 then
		local pos = Player[playerColor].getPointerPosition()
		local closest, closestDist2 = nil, nil
		for _, obj in ipairs(getAllObjects()) do
			if obj.hasTag('spy') then
				local p = obj.getPosition()
				local dx, dz = p[1] - pos[1], p[3] - pos[3]
				local d2 = dx*dx + dz*dz
				if closestDist2 == nil or d2 < closestDist2 then closest, closestDist2 = obj, d2 end
			end
		end
		if closest ~= nil and closestDist2 <= 4.0 then
			returnFigure(playerColor, closest)
		else
			hotkeyPlaceSpy(playerColor, nil)
		end
		return
	end
	-- only the troop-deploy numbers (1, 6-9, 0/index10) - 2/3/4 stay exclusively top-row (Assassinate/
	-- Devour, Supplant/Promote, Return/Take), not repurposed here
	if index == 1 or (index >= 6 and index <= 10) then
		demonwebDeployTroopsAtPointer(playerColor, index == 10 and 0 or index)
	end
end

function hotkeyPlaceSpy(playerColor, hoverObj)
	if not status.doneLoading or status.setupInProgress or not isSeated(playerColor) then return end
	local toPos = Player[playerColor].getPointerPosition()
	if status.boardMode == 'modular' then
		-- the modular board's own physical hex tiles are plain generic pieces - they carry none of the
		-- standard board's 'Board'/'troop'/'control'/'demonweb' identifying tags, so the tag-based gate
		-- used below for the standard board can't confirm "we're pointing at the board" here. Using it
		-- anyway meant this only ever passed when hovering an existing troop/spy/marker, which is
		-- exactly the reported bug (placement only worked on hexes that already had a neutral troop on
		-- them). The origin-radius check alone is a reliable substitute for that gate on this board.
		-- demonwebBoardRadius (defined near demonwebHexScale/R) covers the board's actual footprint with
		-- margin while stopping well short of the market/recruit area (measured at ~39-46 from the origin,
		-- fixed regardless of hex scale) - see its own comment for the formula. The old fixed 45 was way
		-- too generous and reached into the market, letting troops/spies spawn there.
		local dx, dz = toPos[1] - demonwebOrigin[1], toPos[3] - demonwebOrigin[3]
		if dx*dx + dz*dz > demonwebBoardRadius*demonwebBoardRadius then return end
	else
		-- hoverObj is nil when called from Numpad 5 (onScriptingButtonDown, no hover info available) - the
		-- tag gate only applies when we actually have a hovered object to check (top-row 5)
		if hoverObj ~= nil and hoverObj.getDescription() ~= 'Board' and not hoverObj.hasTag('troop') and not hoverObj.hasTag('control') and not hoverObj.hasTag('demonweb') then return end
		if toPos[1] < -25.8 or toPos[1] > 25.8 or toPos[3] < -14.6 or toPos[3] > 36.9 then return end
	end

	local found = false
	for _, guid in ipairs(playerVars[playerColor].spyZoneGuids) do
		local zone = getObjectFromGUID(guid)
		if #zone.getObjects() > 0 then
			for _, o in ipairs(zone.getObjects()) do
				if o.hasTag('spy') then
					o.setRotationSmooth(faceup, false, false)
					-- disable snapping while we move it, then re-enable shortly after: with Snap left on,
					-- the modular board's densely-packed 'spy'/'troop' snap points (much closer together
					-- than on the standard board) cause the object to immediately jump to whichever
					-- existing snap point is nearest instead of landing at the actual pointer position
					o.use_snap_points = false
					o.setPositionSmooth({toPos[1], 3.9, toPos[3]}, false, false)
					Wait.time(function() if o ~= nil then o.use_snap_points = true end end, 1)
					found = true
					break
				end
			end
			if found then break end
		end
	end
	if not found then broadcastToColor('No spies found on the snap points near your board.', playerColor) end
end

-- Plain top-row 5, dual-purpose like Return/Take on 4: if you're hovering an existing spy, return it home;
-- otherwise place a new one from your pool near the pointer. The "return" half is a best-effort attempt
-- only - confirmed by testing that TTS's onObjectNumberTyped simply never reports a spy figure as hovered
-- at all (true even for one that's never been touched/moved, so it's not about how it got there), for any
-- number key, while the same figure's own right-click "Return" menu item and position-based lookups work
-- fine - this looks like an engine-level quirk with this particular figure that Lua can't work around
-- through hover. Numpad 5 (onScriptingButtonDown above) is the reliable, confirmed-working way to return a
-- spy, since it doesn't depend on hover at all.
function hotkeyPlaceOrReturnSpy(playerColor, hoverObj)
	if hoverObj ~= nil and hoverObj.hasTag('spy') then
		-- returning your own spy is free (just retrieving your own figure); returning an enemy's spy is the
		-- paid "expend 3 Power" base action (rulebook p.13) when the resource pool is enabled
		if hoverObj.getDescription() ~= playerColor then
			if demonwebFreeActionsAvailable(playerColor, 'returnSpy') > 0 then
				demonwebUseFreeActions(playerColor, 'returnSpy', 1)
			elseif not demonwebSpendPower(playerColor, demonwebPowerCosts.returnSpy) then
				broadcastToColor('Not enough Power (' .. demonwebPowerCosts.returnSpy .. ' needed) to return an enemy spy.', playerColor)
				return
			end
		end
		returnFigure(playerColor, hoverObj)
	else
		hotkeyPlaceSpy(playerColor, hoverObj)
	end
end

function onObjectNumberTyped(object, playerColor, number)
	if not status.doneLoading or status.setupInProgress or not isSeated(playerColor) then return true end

	-- Plain top-row 1-5 no longer trigger anything from here - fully superseded by the 'Demonweb: ...'
	-- hotkeys (bound per player in Options -> Game Keys), which fire reliably everywhere with no TTS hover
	-- requirement at all, unlike this event. 6-10 still deploy troops via plain top-row keys below, since
	-- those were never the problem case (deploying more than 1 troop was comparatively rare to hit the
	-- hover issue in practice) - happy to move those to hotkeys-only too if you'd rather.
	if number >= 1 and number <= 5 then return true end

	demonwebDeployTroopsAtPointer(playerColor, number)
	return true
end

-- Shared deploy logic for both onObjectNumberTyped (top-row keys, hover-gated by TTS itself) and
-- onScriptingButtonDown (Numpad keys, no hover involved at all) - this doesn't take or need a hovered
-- object, only the pointer's world position. Confirmed (not just suspected) that TTS's onObjectNumberTyped
-- simply never fires over most of a modular hex's own surface - even an object built and positioned to
-- exactly mirror the standard board's own hoverable Board tile, verified via right-click to genuinely be
-- the thing under the cursor, still never gets reported to this event. Top-row keys only work there when
-- hovering something TTS does recognize (an existing troop/spy figure) - an engine-level limitation with
-- no Lua-side fix. Numpad routes through this same function without ever touching that hover check, so it
-- always works anywhere within the board's radius regardless.
function demonwebDeployTroopsAtPointer(playerColor, number)
	if not status.doneLoading or status.setupInProgress or not isSeated(playerColor) then return end
	local toPos = Player[playerColor].getPointerPosition()
	if status.boardMode == 'modular' then
		-- demonwebBoardRadius (see hotkeyPlaceSpy) clears the whole board with margin but stops short of
		-- the market/recruit area
		local dx, dz = toPos[1] - demonwebOrigin[1], toPos[3] - demonwebOrigin[3]
		if dx*dx + dz*dz > demonwebBoardRadius*demonwebBoardRadius then return end
	else
		if toPos[1] < -25.8 or toPos[1] > 25.8 or toPos[3] < -14.6 or toPos[3] > 36.9 then return end
	end

	if number == 0 then number = 10 end
	local rowLen = {3,3,3,2,3,3,4,3,3,4}
	local bag = getObjectFromGUID(playerVars[playerColor].troopBagGuid)
	-- Deploy costs 1 Power per troop (rulebook p.12) when the resource pool is enabled. Checked as a single
	-- lump sum up front (and only once the bag is confirmed to have enough troops) so a player is never
	-- charged for troops they don't actually receive. A card's own "Deploy N troops" instruction (free, per
	-- rulebook p.9) grants free-deploy credits instead of Power - those are used up first, in full-or-nothing
	-- lumps so a smaller free deploy is never partially spent on a bigger one.
	if bag.getQuantity() >= number then
		if demonwebFreeActionsAvailable(playerColor, 'deploy') >= number then
			demonwebUseFreeActions(playerColor, 'deploy', number)
		elseif not demonwebSpendPower(playerColor, demonwebPowerCosts.deploy * number) then
			broadcastToColor('Not enough Power (' .. (demonwebPowerCosts.deploy * number) .. ' needed) to deploy ' .. number .. ' troop(s).', playerColor)
			return
		end
	end
	for i=1, number do
		if bag.getQuantity() == 0 then broadcastToColor('You have no troops in your bag.', playerColor) return end
		local zOffset = math.ceil(i/rowLen[number]) - 1
		local xOffset = i - zOffset * rowLen[number] - 1
		-- same snap-suppression as Place Spy above: the modular board's tightly-packed 'troop' snap points
		-- otherwise pull the freshly-spawned troop onto the nearest existing neutral/troop point. Disabling
		-- use_snap_points AFTER takeObject returned was too late - TTS resolves the snap right as the
		-- object is spawned into place, before the next line of Lua ever runs, so the flag has to be set
		-- inside the spawn's own callback_function instead, which fires as part of that same spawn step.
		bag.takeObject({
			position = {toPos[1] + xOffset * 1.32, 3.5, toPos[3] - zOffset * 1.17},
			rotation = faceup,
			callback_function = function(troop)
				troop.use_snap_points = false
				Wait.time(function() if troop ~= nil then troop.use_snap_points = true end end, 1)
			end
		})
	end
	return true
end

---------------------- CONTEXT MENU

-- Per-card-name context-menu automation for the Mercenaries half-deck (see PROJECT_BRIEF for the full design
-- discussion). Each entry is a function(card) that adds one or more context-menu items to that specific card
-- object, calling into the primitives above. Board-positional instructions ("Deploy a troop", "Assassinate a
-- troop", "Place a spy", "Move a troop") can't be resolved from a menu click on the CARD itself (the menu has
-- no idea which board square/figure the player means) - those grant a free-action credit (consumed
-- automatically by the existing Deploy/Assassinate/Return-spy hotkeys and context-menu items) or, for
-- cost-free positional actions (Place a Spy, Move a troop/spy - free even in the base rules), just remind the
-- player to do it by hand. Conditions the mod has no way to verify on its own (e.g. "if that site is empty")
-- are trusted to the player, consistent with how the base rules already trust optional ability costs.
mercenariesCardMenus = {
	['Goblinoid ambushers'] = function(card)
		card.addContextMenuItem('Play: +1 Power', function(clickColor) demonwebGrantPower(clickColor, 1) end)
		demonwebAddOpponentMenuItems(card, 'Play: Steal 1 VP', function(clickColor, targetColor) demonwebStealVp(targetColor, clickColor, 1) end)
		demonwebAddBribeMenuItems(card, 'Play: Bribe -> +3 Power', function(clickColor) demonwebGrantPower(clickColor, 3) end)
	end,
	['Hobgoblin warlord'] = function(card)
		card.addContextMenuItem('Play: +3 Power', function(clickColor) demonwebGrantPower(clickColor, 3) end)
		demonwebAddBribeMenuItems(card, 'Play: Bribe -> cheap Assassinate rest of turn', function(clickColor)
			demonwebCheapAssassinateDiscount[clickColor] = true
			broadcastToColor('For the rest of your turn, Assassinate costs only 2 Power.', clickColor)
		end)
	end,
	['Dragonborn hireling'] = function(card)
		card.addContextMenuItem('Play: Assassinate a troop (free)', function(clickColor)
			demonwebGrantFreeAction(clickColor, 'assassinate', 1)
			broadcastToColor('Free Assassinate ready - right-click the troop to remove it (no Power cost).', clickColor)
		end)
		card.addContextMenuItem('Play: Gain 1 VP if 3+ troops in trophy hall', function(clickColor)
			if demonwebCountTrophyTroops(clickColor) >= 3 then demonwebGiveVpValue(clickColor, 1) end
		end)
	end,
	['Artemis Entreri'] = function(card)
		card.addContextMenuItem('Play: Assassinate 3 troops at a site (free)', function(clickColor)
			demonwebGrantFreeAction(clickColor, 'assassinate', 3)
			broadcastToColor('3 free Assassinates ready, all at the same site (no Power cost).', clickColor)
		end)
		card.addContextMenuItem('Claim: Gain 1 VP (site is now empty)', function(clickColor)
			demonwebGiveVpValue(clickColor, 1)
		end)
	end,
	['Goblin swarm'] = function(card)
		card.addContextMenuItem('Play: Deploy a troop (free)', function(clickColor)
			demonwebGrantFreeAction(clickColor, 'deploy', 1)
			broadcastToColor('Free Deploy ready for 1 troop (no Power cost).', clickColor)
		end)
		demonwebAddBribeMenuItems(card, 'Play: Bribe -> Deploy 2 troops (free)', function(clickColor)
			demonwebGrantFreeAction(clickColor, 'deploy', 2)
			broadcastToColor('Free Deploy ready for 2 troops (no Power cost).', clickColor)
		end)
	end,
	['Bugbear'] = function(card)
		card.addContextMenuItem('Play: Deploy + Assassinate white troop + Gain 1 VP', function(clickColor)
			demonwebGrantFreeAction(clickColor, 'deploy', 1)
			demonwebGrantFreeAction(clickColor, 'assassinate', 1)
			demonwebGiveVpValue(clickColor, 1)
			broadcastToColor('Free Deploy + free Assassinate ready (target a white troop) - no Power cost. +1 VP granted.', clickColor)
		end)
	end,
	['Security guard'] = function(card)
		card.addContextMenuItem('Play: Deploy 2 troops (free)', function(clickColor)
			demonwebGrantFreeAction(clickColor, 'deploy', 2)
			broadcastToColor('Free Deploy ready for 2 troops (no Power cost).', clickColor)
		end)
		demonwebAddOpponentMenuItems(card, 'Play: Steal 1 VP (had a troop adjacent)', function(clickColor, targetColor) demonwebStealVp(targetColor, clickColor, 1) end)
	end,
	['Goblin thief'] = function(card)
		card.addContextMenuItem('Play: Place a spy (use Place Spy hotkey, free)', function(clickColor)
			broadcastToColor('Use your Place Spy hotkey to place a spy at the target site (free, no Power cost).', clickColor)
		end)
		demonwebAddOpponentMenuItems(card, 'Play: Steal 1 VP (opponent troop at spy site)', function(clickColor, targetColor) demonwebStealVp(targetColor, clickColor, 1) end)
	end,
	['Bazaar trader'] = function(card)
		card.addContextMenuItem('Play: Discard a card -> Gain 1 VP + draw a card', function(clickColor)
			broadcastToColor('Discard a card from your hand.', clickColor)
			demonwebGiveVpValue(clickColor, 1)
			demonwebDrawCards(clickColor, 1)
		end)
		demonwebAddBribeMenuItems(card, 'Play: Bribe -> Place a spy + draw 2 cards', function(clickColor)
			demonwebDrawCards(clickColor, 2)
			broadcastToColor('Use your Place Spy hotkey to place a spy (free).', clickColor)
		end)
		card.addContextMenuItem('Play: Return a spy (then use Steal below)', function(clickColor)
			broadcastToColor('Return one of your spies (right-click it -> Return), then use "Confirm: Steal 3 VP" below.', clickColor)
		end)
		demonwebAddOpponentMenuItems(card, 'Confirm: Steal 3 VP (after returning spy)', function(clickColor, targetColor) demonwebStealVp(targetColor, clickColor, 3) end)
	end,
	['Xanathar smuggler'] = function(card)
		card.addContextMenuItem('Play: +1 Influence', function(clickColor) demonwebGrantInfluence(clickColor, 1) end)
		demonwebAddBribeMenuItems(card, 'Play: Bribe -> promote a card at end of turn', function(clickColor)
			demonwebPendingPromote[clickColor] = card.getGUID()
			broadcastToColor('At the end of your turn, another card you played this turn will be promoted.', clickColor)
		end)
	end,
	['Xanathar surveillance'] = function(card)
		card.addContextMenuItem('Play: Draw 3, then discard 2', function(clickColor)
			demonwebDrawCards(clickColor, 3)
			broadcastToColor('Draw 3 cards, then discard 2 of them by hand.', clickColor)
		end)
		demonwebAddBribeMenuItems(card, 'Play: Bribe (then use Promote on a discarded card)', function(clickColor)
			broadcastToColor('Bribe paid - right-click one of the cards you just discarded and choose Promote.', clickColor)
		end)
	end,
	['Ahmaergo'] = function(card)
		card.addContextMenuItem('Play: Move a troop + Gain 1 Influence (click up to twice)', function(clickColor)
			demonwebGrantInfluence(clickColor, 1)
			broadcastToColor('Move one of your troops by hand (free). This card lets you pick a choice like this up to twice total.', clickColor)
		end)
		demonwebAddBribeMenuItems(card, 'Play: Bribe -> swap 2 troops anywhere (click up to twice)', function(clickColor)
			broadcastToColor('Bribe paid - swap any 2 troops on the board by hand.', clickColor)
		end)
	end,
	['Xanathar Zushaxx'] = function(card)
		card.addContextMenuItem('Play: +4 Influence', function(clickColor) demonwebGrantInfluence(clickColor, 4) end)
		card.addContextMenuItem('Play: Activate - steal 1 VP per Recruit (rest of turn)', function(clickColor)
			demonwebStealOnRecruit[clickColor] = true
			broadcastToColor('For the rest of your turn, each Recruit steals 1 VP from an opponent.', clickColor)
		end)
	end,
	["Bregan D'aerthe agents"] = function(card)
		card.addContextMenuItem('Play: Take white troop from trophy hall + Deploy (free, up to 3x)', function(clickColor)
			local troop = demonwebFindTrophyWhiteTroop()
			if troop == nil then broadcastToColor('No white troops found in any trophy hall.', clickColor) return end
			local toPos = Player[clickColor].getPointerPosition()
			troop.use_hands = false
			troop.setRotationSmooth(faceup, false, true)
			troop.setPositionSmooth({toPos[1], 3.5, toPos[3]}, false, false)
			Wait.time(function() if troop ~= nil then troop.use_hands = true end end, 1.5)
		end)
		demonwebAddBribeMenuItems(card, "Play: Bribe -> Supplant a white troop (use Supplant on it, up to 3x)", function(clickColor)
			broadcastToColor('Bribe paid - right-click a white troop and choose Supplant.', clickColor)
		end)
	end,
	['Nihiloor'] = function(card)
		card.addContextMenuItem('Play: Deploy 3 troops (free)', function(clickColor)
			demonwebGrantFreeAction(clickColor, 'deploy', 3)
			broadcastToColor('Free Deploy ready for 3 troops (no Power cost).', clickColor)
		end)
		demonwebAddBribeMenuItems(card, 'Play: Bribe -> Move the deployed troops (do it by hand)', function(clickColor)
			broadcastToColor('Bribe paid - move the 3 deployed troops by hand.', clickColor)
		end)
		card.addContextMenuItem('Play: Assassinate white troop adjacent to each deployed troop (free, up to 3x)', function(clickColor)
			demonwebGrantFreeAction(clickColor, 'assassinate', 3)
			broadcastToColor('3 free Assassinates ready (one per deployed troop, target an adjacent white troop) - no Power cost.', clickColor)
		end)
	end,
	["Bregan D'aerthe spy"] = function(card)
		card.addContextMenuItem('Play: Place a spy (free)', function(clickColor)
			broadcastToColor('Use your Place Spy hotkey to place a spy (free, no Power cost).', clickColor)
		end)
		card.addContextMenuItem('Play: Steal a site control marker (see the marker itself)', function(clickColor)
			broadcastToColor("To steal a site's control marker, right-click the marker itself and choose \"Bregan D'aerthe Spy: Steal\" (it returns one of your placed spies as the cost).", clickColor)
		end)
	end,
	["Nar'l Xibrindas"] = function(card)
		card.addContextMenuItem('Play: Place a spy (free)', function(clickColor)
			broadcastToColor('Use your Place Spy hotkey to place a spy (free, no Power cost).', clickColor)
		end)
		card.addContextMenuItem('Play: Return a spy -> swap this card with one in an opponent discard', function(clickColor)
			local spy = demonwebFindPlacedSpy(clickColor)
			if spy == nil then broadcastToColor('You have no placed spy to return for this.', clickColor) return end
			returnFigure(clickColor, spy)
			broadcastToColor("Spy returned - manually swap this card with your chosen card in the target opponent's discard pile.", clickColor)
		end)
	end,
	-- Jarlaxle (Mercenaries): "Look at an opponent's hand and choose a card. They play it, but you decide
	-- how." Best-effort approximation - TTS has no way to make another player's client play a card or hand
	-- control of an on-screen choice to someone else. What IS achievable: genuinely look at the target's hand
	-- (privately messaged to the clicking player only) and remind the two players to physically move the
	-- chosen card into the target's play zone; since none of this mod's Mercenaries "Play: ..." menu items
	-- check who owns the card, the Jarlaxle player can then right-click that card themselves and choose its
	-- resolution - which is exactly "they play it, but you decide how".
	['Jarlaxle'] = function(card)
		demonwebAddOpponentMenuItems(card, 'Play: Look at hand & force a card (see chat)', function(clickColor, targetColor)
			local names = {}
			for _, o in ipairs(Player[targetColor].getHandObjects()) do
				if o.type == 'Card' then table.insert(names, o.getName()) end
			end
			if #names == 0 then broadcastToColor(getPlayerName(targetColor, true) .. ' has no cards in hand.', clickColor) return end
			broadcastToColor(getPlayerName(targetColor, true) .. "'s hand: " .. table.concat(names, ', '), clickColor)
			broadcastToColor('Have them play your chosen card (move it to their play zone) - then resolve its own "Play: ..." menu items yourself.', clickColor)
		end)
		demonwebAddBribeMenuItems(card, 'Play: Bribe -> also resolve the effect for yourself', function(clickColor)
			broadcastToColor('Bribe paid - also use the forced card\'s "Play: ..." menu items for your own benefit.', clickColor)
		end)
	end,
	['Shady merchant'] = function(card)
		card.addContextMenuItem('Play: Return an opponent troop (use Return on it) + move a spy by hand', function(clickColor)
			broadcastToColor('Right-click an opponent troop and choose Return; move any spy by hand (both free, no Power cost).', clickColor)
		end)
		demonwebAddOpponentMenuItems(card, 'Play: Bribe -> put a card played this turn atop opponent deck', function(clickColor, targetColor)
			if not demonwebBribeVp(clickColor, targetColor) then return end
			local playZone = getObjectFromGUID(playerVars[clickColor].playZoneGuid)
			local targetDeckZone = getObjectFromGUID(playerVars[targetColor].deckZoneGuid)
			if playZone == nil or targetDeckZone == nil then return end
			for _, object in ipairs(playZone.getObjects()) do
				if object.type == 'Card' and object.getGUID() ~= card.getGUID() then
					local toPos = targetDeckZone.getPosition()
					object.setRotation(facedown)
					object.setPositionSmooth({toPos[1], toPos[2] + 1, toPos[3]}, false, true)
					break
				end
			end
		end)
	end
}

function addMenuItems(object)
	if object.type == 'Card' then
		object.addContextMenuItem('Devour', function(playerColor) devour(playerColor, object) end)
		object.addContextMenuItem('Promote', function(playerColor) promote(playerColor, object) end)
		local mercenariesMenu = mercenariesCardMenus[object.getName()]
		if mercenariesMenu ~= nil then mercenariesMenu(object) end
	elseif object.hasTag('spy') then
		object.addContextMenuItem('Return', function(playerColor) returnFigure(playerColor, object) end)
	elseif object.hasTag('troop') then
		object.addContextMenuItem('Assassinate', function(playerColor) assassinate(playerColor, object) end)
		object.addContextMenuItem('Supplant', function(playerColor) supplant(playerColor, object) end)
		if object.getDescription() ~= 'White' then
			object.addContextMenuItem('Return', function(playerColor) returnFigure(playerColor, object) end)
		end
	elseif object.hasTag('control') then
		object.addContextMenuItem('Take', function(playerColor) contextMenuTakeControl(playerColor, object) end)
		object.addContextMenuItem("Bregan D'aerthe Spy: Steal", function(playerColor) demonwebBreganSpyStealMarker(playerColor, object) end)
	end
end

function promote(playerColor, card)
	if not isSeated(playerColor) then return end
	if card.getName() == 'Sylgar' then demonwebSylgarBounceBack(playerColor, card) return end
	local toZone = nil
	if card.getName() == 'Insane Outcast' then toZone = getObjectFromGUID(market.bottom[2])
	else toZone = getObjectFromGUID(playerVars[playerColor].circleZoneGuid)
	end
	local toPos = toZone.getPosition()
	
	card.use_hands = false
	card.setRotationSmooth(faceup, false, true)
	card.setPositionSmooth({toPos[1], toPos[2] + 0.7, toPos[3]}, false, true)
	
	-- tts bug: setPositionSmooth pulls other cards that are moved when setPositionSmooth ends, so end with setPosition which has smaller window for this bug to occur
	Wait.time(function()
		card.use_hands = true
		local deck = findDeck(toZone)
		if deck == nil or deck.getGUID() == card.getGUID() then card.setPosition(toPos)
		else deck.putObject(card)
		end
	end, 0.3)
end

function devour(playerColor, card)
	if not isSeated(playerColor) then return end
	if card.getName() == 'Sylgar' then demonwebSylgarBounceBack(playerColor, card) return end
	local toZone = nil
	if card.getName() == 'Insane Outcast' then toZone = getObjectFromGUID(market.bottom[2])
	else toZone = getObjectFromGUID(devourZoneGuid)
	end
	local toPos = toZone.getPosition()
	
	card.use_hands = false
	card.setRotationSmooth(faceup, false, true)
	card.setPositionSmooth({toPos[1], toPos[2] + 0.7, toPos[3]}, false, true)
	-- tts bug: setPositionSmooth pulls other cards that are moved when setPositionSmooth ends, so end with setPosition which has smaller window for this bug to occur
	Wait.time(function()
		card.use_hands = true
		local deck = findDeck(toZone)
		if deck == nil or deck.getGUID() == card.getGUID() then card.setPosition(toPos)
		else deck.putObject(card)
		end
	end, 0.3)
end

-- chargeCost defaults to true (the direct "expend 3 Power" base action, rulebook p.11, used by the
-- Assassinate context-menu item). Pass false for a card-granted Assassinate (e.g. inside supplant(), or a
-- future automated card effect) - those are free, not the paid resource-pool action.
function assassinate(playerColor, troop, chargeCost)
	if chargeCost == nil then chargeCost = true end
	if not isSeated(playerColor) then return end
	if troop.getDescription() == playerColor then broadcastToColor('Assassinate your own troop manually.', playerColor) return end
	if chargeCost then
		if demonwebFreeActionsAvailable(playerColor, 'assassinate') > 0 then
			demonwebUseFreeActions(playerColor, 'assassinate', 1)	-- granted directly by a card's own instruction - free
		else
			local cost = demonwebPowerCosts.assassinate
			if demonwebCheapAssassinateDiscount[playerColor] then cost = 2 end	-- Hobgoblin Warlord's Bribe discount
			if not demonwebSpendPower(playerColor, cost) then
				broadcastToColor('Not enough Power (' .. cost .. ' needed) to assassinate a troop.', playerColor)
				return
			end
		end
	end
	Player[playerColor].pingTable(troop.getPosition())
	local toPos = playerVars[playerColor].trophyTroopPosition
	troop.use_hands = false
	troop.setRotationSmooth(faceup, false, true)
	troop.setPositionSmooth({toPos[1] + math.random(0,7) * 1.2, toPos[2], toPos[3] - math.random(0,7) * 1.03}, false, false)
	Wait.time(function()
		troop.use_hands = true
	end, 3)
end

function supplant(playerColor, troop)
	if not isSeated(playerColor) or troop.getDescription() == playerColor then return end
	local bag = getObjectFromGUID(playerVars[playerColor].troopBagGuid)
	if bag.getQuantity() == 0 then broadcastToColor('You have no troops in your bag.', playerColor) return end
	local toPos = troop.getPosition()
	assassinate(playerColor, troop, false)	-- free: Supplant is a single card-granted compound ability, not the paid Assassinate action
	bag.takeObject({position = toPos, rotation = faceup})
end

function returnFigure(playerColor, object)
	if not isSeated(playerColor) then return end
	local ownerColor = object.getDescription()
	if object.hasTag('troop') then
		if ownerColor ~= 'White' and isSeated(ownerColor) then
			Player[playerColor].pingTable(object.getPosition())
			getObjectFromGUID(playerVars[ownerColor].troopBagGuid).putObject(object)
		end
	elseif object.hasTag('spy') then
		for _, guid in ipairs(playerVars[ownerColor].spyZoneGuids) do
			local zone = getObjectFromGUID(guid)
			if #zone.getObjects() == 0 then
				Player[playerColor].pingTable(object.getPosition())
				object.setRotationSmooth(faceup, false, true)
				object.setPositionSmooth(zone.getPosition(), false, true)
				break
			end
		end
	end
end

function contextMenuTakeControl(playerColor, controlMarker)
	if not isSeated(playerColor) then return end
	moveControlMarker(playerColor, getControlMarkerInfo(controlMarker), {}, true)
end

-- Switches one control-marker tile between its standard look (state 1, the object's original/default
-- appearance) and one of the alternate-art states (2/3/4, added as extra States on the same physical object -
-- same GUID throughout, so every existing lookup/button/context-menu keeps working unchanged). Guards against
-- calling setState for a state that doesn't exist (e.g. before alternate art has been added) the same way
-- setDeckState does for half-deck languages.
-- Applies either the standard look or one of the 3 alternate-art variants directly to a site control-marker
-- tile, using setCustomObject()+reload() rather than TTS "States" - the tile ends up with no alternate states
-- at all, so there's nothing for a player to cycle through with the number-key hotkey to see ahead of time.
-- variantIndex nil/0 = standard look. Updates altMarkerVpDisabled and the boardSections guid (reload() can
-- hand back a new object/guid) so everything downstream keeps working unchanged.
function setAltMarkerLook(guid, variantIndex)
	local marker = getObjectFromGUID(guid)
	local data = altMarkerData[guid]
	if marker == nil or data == nil then return end
	
	local face, back
	if variantIndex == nil or variantIndex == 0 then
		face, back = data.standardFace, data.standardBack
		altMarkerVpDisabled[guid] = nil
	else
		local variant = data.variants[variantIndex]
		face, back = variant.back, data.altFace	-- swapped: currently (unswapped) altFace shows "Control" and
													-- variant.back shows "Total Control", but the flip logic in
													-- moveControlMarker() shows the face when totalControl=true -
													-- so face needs to be the "Total Control" design and back the
													-- "Control" one
		if variant.vpOnTotalControl then altMarkerVpDisabled[guid] = nil
		else altMarkerVpDisabled[guid] = true
		end
	end
	
	local tags = marker.getTags()
	local notes = marker.getGMNotes()
	marker.setCustomObject({
		type = 2,
		image = face,
		image_secondary = back,
		thickness = 0.1,
		stackable = false
	})
	local reloaded = marker.reload()
	wait(0.1)		-- reload() respawns the object; give TTS a frame before touching the new reference
	reloaded.setGMNotes(notes)
	reloaded.setTags(tags)
	addMenuItems(reloaded)
	-- start alt-variant markers on the "Control" side (now the back, after the swap above) by default, since
	-- nothing controls the site yet at setup time
	if variantIndex ~= nil and variantIndex ~= 0 and not reloaded.is_face_down then reloaded.flip() end
	
	local info = getControlMarkerInfo(reloaded)
	if info ~= nil then info.guid = reloaded.getGUID() end
	if guid ~= reloaded.getGUID() then
		altMarkerData[reloaded.getGUID()] = data
		altMarkerData[guid] = nil
		if altMarkerVpDisabled[guid] ~= nil then
			altMarkerVpDisabled[reloaded.getGUID()] = altMarkerVpDisabled[guid]
			altMarkerVpDisabled[guid] = nil
		end
	end
end

function getControlMarkerInfo(controlMarker)
	local notes = controlMarker.getGMNotes()
	local index = tonumber(string.sub(notes, 1, 1))
	local section = string.sub(notes, 2, string.len(notes))
	return boardSections[section].controlMarkers[index]
end

---------------------- TURN TIMER

-- Called by the UI Start/Stop button. Turns the timer session on or off; the player decides when (if ever) to use it.
function toggleTurnTimer(player, value, id)
	if status.timer.active then stopTurnTimer()
	else startTurnTimer(player)
	end
end

function startTurnTimer(player)
	if status.timer.active or status.gameState < 1 then return end
	status.timer.active = true
	UI.setAttribute('timerToggleBtn', 'text', 'Stop')
	UI.setAttribute('timerToggleBtn', 'color', 'Red')
	if player ~= nil then broadcastToAll(getPlayerName(player.color, true) .. ' turned on the turn timer (' .. timerSettings.duration .. ' sec. per turn).')
	else broadcastToAll('Turn timer turned on (' .. timerSettings.duration .. ' sec. per turn).')
	end
	resetTurnTimer()
end

function stopTurnTimer()
	if not status.timer.active then return end
	status.timer.active = false
	status.timer.paused = false
	status.timer.pendingStop = false
	status.timer.epoch = status.timer.epoch + 1		-- invalidate any pending countdown tick
	UI.setAttribute('timerToggleBtn', 'text', 'Start')
	UI.setAttribute('timerToggleBtn', 'color', 'Green')
	UI.setAttribute('timerPauseBtn', 'text', 'Pause')
	UI.setAttribute('timerDisplay', 'text', '--:--')
	UI.setAttribute('timerDisplay', 'color', 'White')
end

-- Called when an end-game condition fires (market deck or a troop bag runs out). Rather than cutting the
-- timer off mid-round, let it keep running - every seated player still gets their turn this round - and only
-- stop it once play comes back around to whoever started the game (see onPlayerTurn()).
function requestTurnTimerStop()
	if not status.timer.active then return end
	status.timer.pendingStop = true
end

-- Called by the Pause/Resume button. Freezes or continues the countdown without ending the timer session
-- or changing whose turn it is; the remaining time is preserved exactly as it was when paused.
function togglePauseTimer(player, value, id)
	if not status.timer.active then return end
	if status.timer.paused then resumeTurnTimer() else pauseTurnTimer() end
end

function pauseTurnTimer()
	if not status.timer.active or status.timer.paused then return end
	status.timer.paused = true
	status.timer.epoch = status.timer.epoch + 1		-- invalidate the running tick chain; remaining is untouched
	UI.setAttribute('timerPauseBtn', 'text', 'Resume')
end

function resumeTurnTimer()
	if not status.timer.active or not status.timer.paused then return end
	status.timer.paused = false
	status.timer.epoch = status.timer.epoch + 1
	local myEpoch = status.timer.epoch
	UI.setAttribute('timerPauseBtn', 'text', 'Pause')
	turnTimerTick(myEpoch)
end

-- Called by the Hide/Show buttons. Only hides the settings/controls panel (bottom-right) - the countdown digits
-- under the End Turn button stay visible, and the countdown (and auto turn-pass on timeout) keeps running
-- in the background regardless.
function hideTimerPanel(player, value, id)
	UI.setAttribute('timerControlsPanel', 'active', false)
	UI.setAttribute('timerPanelCollapsed', 'active', true)
end

function showTimerPanel(player, value, id)
	UI.setAttribute('timerPanelCollapsed', 'active', false)
	UI.setAttribute('timerControlsPanel', 'active', true)
end

-- Resets the countdown to the configured duration for whoever's turn it currently is, and (re)starts ticking.
-- A fresh turn always starts unpaused, even if the previous player's countdown was paused when their turn ended.
function resetTurnTimer()
	status.timer.epoch = status.timer.epoch + 1
	local myEpoch = status.timer.epoch
	status.timer.remaining = timerSettings.duration
	status.timer.paused = false
	UI.setAttribute('timerPauseBtn', 'text', 'Pause')
	updateTimerDisplay()
	if status.timer.active then turnTimerTick(myEpoch) end
end

function turnTimerTick(myEpoch)
	Wait.time(function()
		-- if the timer was stopped, or another reset/turn-change already started a newer countdown, this stale chain dies here
		if not status.timer.active or myEpoch ~= status.timer.epoch then return end
		
		status.timer.remaining = status.timer.remaining - 1
		updateTimerDisplay()
		
		if status.timer.remaining <= 0 then
			local expiredColor = Turns.turn_color
			pcall(playTimeoutAlert, expiredColor)
			broadcastToAll(hexColors.Red .. 'Time is up!' .. '[-] ' .. getPlayerName(expiredColor, true) .. ' ran out of time — turn passes to the next player.')
			passTurnDueToTimeout(expiredColor)
		else
			turnTimerTick(myEpoch)
		end
	end, 1)
end

-- NOTE: Tabletop Simulator's scripting API has no way to play a sound without the accompanying visual ping
-- marker — pingTable() always shows both together, and there's no built-in "play a sound only" call for a
-- custom clip without hosting an audio file at a URL. Since the visual marker was unwanted, this alert is now
-- silent (the chat message below still announces the timeout to everyone). If you'd like an audible cue without
-- the visual, the only route is a custom sound file hosted at a URL played through Global's MusicPlayer — let
-- me know if you want to go that way and share a link to the clip.
function playTimeoutAlert(expiredColor)
end

-- Advances the turn to the next seated player (in seating order).
--
-- NOTE ON A TTS ENGINE QUIRK: simply assigning Turns.turn_color while Turns.enable is already true does NOT
-- reliably propagate to clients — this is a long-standing Tabletop Simulator limitation, not specific to this
-- script (well documented in TTS bug reports/forums). The one place this mod already changes the turn works
-- around it by accident: it sets Turns.turn_color BEFORE flipping Turns.enable to true for the very first time.
-- We recreate that same known-working transition here (disable -> set color -> re-enable) to force it through
-- mid-game. We also reset the clock directly instead of relying solely on onPlayerTurn firing from this change.
--
-- SIDE EFFECT OF THAT WORKAROUND: toggling Turns.enable off and back on makes TTS call onPlayerTurn with
-- previousPlayer = nil (the same as when turns first start), instead of the real previous player. Since the
-- game's own "discard played cards / draw back up to hand size" and "deliver total-control VPs" logic in
-- onPlayerTurn only runs when previousPlayer is known, that cleanup would silently get skipped for whoever's
-- time just ran out. So we run that same cleanup manually here for the expired player, and tell onPlayerTurn
-- (via suppressNextTurnCleanup) not to try to run it again for the nil previousPlayer it's about to see.
function passTurnDueToTimeout(currentColor)
	local nextColor = getNextSeatedColor(currentColor)
	if nextColor ~= nil and nextColor ~= currentColor then
		demonwebResolveEndOfTurnEffects(currentColor)
		if options.autoTotalControlVp then deliverTotalControlVps(currentColor) end
		if options.autoSendToDiscard then discardAndDraw(currentColor) end
		demonwebResetResourcePool(currentColor)
		demonwebResetFreeActions(currentColor)

		status.timer.suppressNextTurnCleanup = true
		Turns.enable = false
		Turns.turn_color = nextColor
		Turns.enable = true
		status.turn = nextColor
		-- onPlayerTurn() runs as a result of the turn_color change above and handles resetting (or, if an
		-- end-game trigger fired earlier this round and nextColor is the first player, stopping) the timer
	else
		-- only one seated player (or none found): just restart the clock, unless an end-game trigger is
		-- waiting for the round to end and this lone player is the one who started the game
		if status.timer.pendingStop and currentColor == status.firstPlayerColor then
			stopTurnTimer()
		else
			resetTurnTimer()
		end
	end
end

function getNextSeatedColor(currentColor)
	if #seatedPlayerColors == 0 then return nil end
	local currentIndex = nil
	for i, color in ipairs(seatedPlayerColors) do
		if color == currentColor then currentIndex = i break end
	end
	if currentIndex == nil then return seatedPlayerColors[1] end
	local nextIndex = currentIndex + 1
	if nextIndex > #seatedPlayerColors then nextIndex = 1 end
	return seatedPlayerColors[nextIndex]
end

function updateTimerDisplay()
	local remaining = status.timer.remaining
	if remaining < 0 then remaining = 0 end
	local minutes = math.floor(remaining / 60)
	local seconds = remaining % 60
	UI.setAttribute('timerDisplay', 'text', string.format('%d:%02d', minutes, seconds))
	
	local color = 'White'
	if remaining <= 10 then color = 'Red' end
	UI.setAttribute('timerDisplay', 'color', color)
end

-- Player edits the "seconds per turn" input field. Applies immediately; takes effect from the next reset onward.
function onTimerDurationInput(player, value, id)
	local seconds = tonumber(value)
	if seconds == nil then seconds = timerSettings.duration
	else seconds = math.floor(seconds) end
	if seconds < 5 then seconds = 5 end
	if seconds > 3600 then seconds = 3600 end
	timerSettings.duration = seconds
	UI.setAttribute('timerDurationInput', 'text', tostring(seconds))
	if not status.timer.active then
		status.timer.remaining = seconds
		updateTimerDisplay()
	end
end

-- Reflects current settings/state in the UI. Called on load (and whenever a fresh sync is needed).
function setupTimerUI()
	UI.setAttribute('timerDurationInput', 'text', tostring(timerSettings.duration))
	UI.setAttribute('timerPauseBtn', 'text', 'Pause')
	UI.setAttribute('timerPanelCollapsed', 'active', false)
	if status.timer.active then
		UI.setAttribute('timerToggleBtn', 'text', 'Stop')
		UI.setAttribute('timerToggleBtn', 'color', 'Red')
	else
		UI.setAttribute('timerToggleBtn', 'text', 'Start')
		UI.setAttribute('timerToggleBtn', 'color', 'Green')
		UI.setAttribute('timerDisplay', 'text', '--:--')
		UI.setAttribute('timerDisplay', 'color', 'White')
	end
	UI.setAttribute('timerNumbersToggleBtn', 'text', status.timer.numbersHidden and 'Show Numbers' or 'Hide Numbers')
end

-- Called by the Hide/Show Numbers button. Just hides the small countdown-digits panel; the timer itself
-- keeps running and resetting normally underneath, and the Start/Stop/Pause controls stay visible.
function toggleTimerNumbers(player, value, id)
	status.timer.numbersHidden = not status.timer.numbersHidden
	UI.setAttribute('timerNumbersToggleBtn', 'text', status.timer.numbersHidden and 'Show Numbers' or 'Hide Numbers')
	UI.setAttribute('timerPanel', 'active', not status.timer.numbersHidden)
end

---------------------- UTIL

function findDeck(zone)
	for _, obj in ipairs(zone.getObjects()) do
		if obj.type == 'Card' or obj.type == 'Deck' then return obj end
	end
	return nil
end

function getPlayerName(playerColor, includeHexColor)
	local name = Player[playerColor].steam_name
	if name == nil then name = playerColor end
	if includeHexColor and hexColors[playerColor] ~= nil then name = hexColors[playerColor] .. name .. '[-]' end
	return name
end

function isSeated(playerColor)
	for _, color in ipairs(seatedPlayerColors) do
		if color == playerColor then return true end
	end
	return false
end

function listText(list, getPlayerNames)
	if list == nil or #list == 0 then return nil end
	local text = ''
	for i, item in ipairs(list) do
		if i > 1 then
			if #list == 2 then
				text = text .. ' and '
			else		-- #list > 2
				if i == #list then text = text .. ', and '
				else text = text .. ', '
				end
			end
		end
		if getPlayerNames then text = text .. getPlayerName(item, true)
		else text = text .. item
		end
	end
	return text
end

function temp() end

function wait(t)
	local now = Time.time
	repeat coroutine.yield(0) until Time.time > now + t
end

---------------------- TEST

function testlog(a, b, c, d)
	log(tostring(a) .. ' ' .. tostring(b) .. ' ' .. tostring(c) .. ' ' .. tostring(d))
end

function test1(obj, clickColor, alt)
	UI.setAttributes('displayDecks', {text = buttonText.displayDecks, textColor = 'white', color = 'rgb(0.42, 0.28, 0.60)'})
	--Player[clickColor].lookAt({position = {0,0,-6.5}, pitch = 72, yaw = 0, distance = 74})
end

function test2(obj, clickColor, alt)
	Player[clickColor].lookAt({position = {0,0,-7}, pitch = 72, yaw = 0, distance = 74})
end

function test3(obj, clickColor, alt)
	--discardAndDraw('Blue')
	--deliverTotalControlVps('Purple')
	--Player[clickColor].lookAt({position = {0,0,-7}, pitch = 75, yaw = 0, distance = 72})
	--UI.setAttribute('calculateScoreMenu', 'active', true
	Player[clickColor].lookAt({position = {0,0,-7.5}, pitch = 72, yaw = 0, distance = 74})
end

function test4p(obj, clickColor, alt)
	generateDemonwebMap4Player(nil, nil, nil)
end

function menuTest4p(player, value, id)
	math.randomseed(os.time())
	status.boardMode = 'modular'
	demonwebDestroyStandardBoard()
	generateDemonwebMap4Player(nil, nil, nil)
	broadcastToAll('TEST: 4-player modular board generated.', {0.85, 0.55, 0.13})
end
