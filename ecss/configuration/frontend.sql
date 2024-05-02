/* ###########################################################################
    C6ECSS : Enhanced City-States Selection for Civilization VI
    Copyright (c) 2024 zzragnar0kzz
    All rights reserved.
########################################################################### */

/* ###########################################################################
    begin C6ECSS configuration
########################################################################### */

-- hide YnAMP's CS selection mode parameter if it is present
UPDATE Parameters SET Visible = 0 WHERE ConfigurationID = 'SelectCityStates';

-- 
REPLACE INTO Parameters (ParameterId, Name, Description, Domain, DefaultValue, ConfigurationGroup, ConfigurationId, GroupId, SortIndex) 
VALUES 
    ('UncapCityStates', 'LOC_UNCAP_CITY_STATES_NAME', 'LOC_UNCAP_CITY_STATES_DESC', 'bool', 0, 'Game', 'UNCAP_CITY_STATES', 'GameOptions', 80);

-- city-states priority list - this parameter should be hidden
-- INSERT INTO Parameters (Key1, Key2, ParameterId, Name, Description, Domain, Hash, Array, ConfigurationGroup, ConfigurationId, GroupId, Visible, SortIndex)
-- VALUES
--     ('Ruleset', 'RULESET_STANDARD', 'CityStatesPriority', 'LOC_CITY_STATES_PRIORITY_NAME', 'LOC_CITY_STATES_PRIORITY_DESC', 'StandardCityStatesPriority', 0, 1, 'Game', 'PRIORITY_CITY_STATES', 'MapOptions', 0, 200),
-- 	('Ruleset', 'RULESET_EXPANSION_1', 'CityStatesPriority', 'LOC_CITY_STATES_PRIORITY_NAME', 'LOC_CITY_STATES_PRIORITY_DESC', 'Expansion1CityStatesPriority', 0, 1, 'Game', 'PRIORITY_CITY_STATES', 'MapOptions', 0, 200),
-- 	('Ruleset', 'RULESET_EXPANSION_2', 'CityStatesPriority', 'LOC_CITY_STATES_PRIORITY_NAME', 'LOC_CITY_STATES_PRIORITY_DESC', 'Expansion2CityStatesPriority', 0, 1, 'Game', 'PRIORITY_CITY_STATES', 'MapOptions', 0, 200);

/* ###########################################################################
define value queries to set the lower and upper boundaries of the Natural Wonders slider(s)
lower boundary : the value defined in MapSizes.MinNaturalWonders for the selected map size
upper boundary : the lesser of:
    (1) the number of Natural Wonders available with the selected ruleset and any enabled additional content; or
    (2) the value defined in MapSizes.MaxNaturalWonders for the selected map size
########################################################################### */
-- INSERT INTO Queries (QueryId, SQL)
-- VALUES
--     ('StandardNaturalWonderCountRange', 'SELECT ''StandardNaturalWonderCountRange'' AS Domain, ?1 AS MinimumValue, (SELECT CASE WHEN (SELECT Count(*) FROM NaturalWonders WHERE Domain = ''StandardNaturalWonders'') < ?2 THEN (SELECT Count(*) FROM NaturalWonders WHERE Domain = ''StandardNaturalWonders'') ELSE ?2 END) AS MaximumValue LIMIT 1'),
-- 	('Expansion1NaturalWonderCountRange', 'SELECT ''Expansion1NaturalWonderCountRange'' AS Domain, ?1 AS MinimumValue, (SELECT CASE WHEN (SELECT Count(*) FROM NaturalWonders WHERE Domain = ''Expansion1NaturalWonders'') < ?2 THEN (SELECT Count(*) FROM NaturalWonders WHERE Domain = ''Expansion1NaturalWonders'') ELSE ?2 END) AS MaximumValue LIMIT 1'),
-- 	('Expansion2NaturalWonderCountRange', 'SELECT ''Expansion2NaturalWonderCountRange'' AS Domain, ?1 AS MinimumValue, (SELECT CASE WHEN (SELECT Count(*) FROM NaturalWonders WHERE Domain = ''Expansion2NaturalWonders'') < ?2 THEN (SELECT Count(*) FROM NaturalWonders WHERE Domain = ''Expansion2NaturalWonders'') ELSE ?2 END) AS MaximumValue LIMIT 1');

-- 
-- UPDATE MapSizes 
-- SET MaxPlayers = 4, MaxCityStates = 6, DefaultCityStates = 3
-- WHERE MapSizeType = 'MAPSIZE_DUEL' AND Domain = 'StandardMapSizes';

-- UPDATE MapSizes 
-- SET MaxPlayers = 6, MaxCityStates = 9, DefaultCityStates = 6
-- WHERE MapSizeType = 'MAPSIZE_TINY' AND Domain = 'StandardMapSizes';

-- UPDATE MapSizes 
-- SET MaxPlayers = 10, MaxCityStates = 15, DefaultCityStates = 9
-- WHERE MapSizeType = 'MAPSIZE_SMALL' AND Domain = 'StandardMapSizes';

-- UPDATE MapSizes 
-- SET MaxPlayers = 14, MaxCityStates = 21, DefaultCityStates = 12
-- WHERE MapSizeType = 'MAPSIZE_STANDARD' AND Domain = 'StandardMapSizes';

-- UPDATE MapSizes 
-- SET MaxPlayers = 16, MaxCityStates = 24, DefaultCityStates = 15
-- WHERE MapSizeType = 'MAPSIZE_LARGE' AND Domain = 'StandardMapSizes';

-- UPDATE MapSizes 
-- SET MaxPlayers = 20, MaxCityStates = 30, DefaultCityStates = 18
-- WHERE MapSizeType = 'MAPSIZE_HUGE' AND Domain = 'StandardMapSizes';

-- 
UPDATE MapSizes 
SET MaxPlayers = 63, MaxCityStates = 61 
WHERE Domain = 'StandardMapSizes';

/* ###########################################################################
    end C6ECSS configuration
########################################################################### */
