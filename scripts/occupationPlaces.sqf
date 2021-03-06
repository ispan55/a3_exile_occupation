if (!isServer) exitWith {};

private["_wp","_wp2","_wp3"];

_logDetail = format ["[OCCUPATION]:: Starting Occupation Monitor @ %1",time];
[_logDetail] call SC_fnc_log;

_middle 		    = worldSize/2;			
_spawnCenter 	    = [_middle,_middle,0];		// Centre point for the map
_maxDistance 	    = _middle;			        // Max radius for the map

_maxAIcount 		= SC_maxAIcount;
_minFPS 			= SC_minFPS;
_useLaunchers 	    = DMS_ai_use_launchers;
_scaleAI			= SC_scaleAI;
_side               = "bandit"; 

if(SC_occupyPlacesSurvivors) then 
{ 
    if(!isNil "DMS_Enable_RankChange") then { DMS_Enable_RankChange = true;  };
};


// more than _scaleAI players on the server and the max AI count drops per additional player
_currentPlayerCount = count playableUnits;
if(_currentPlayerCount > _scaleAI) then 
{
	_maxAIcount = _maxAIcount - (_currentPlayerCount - _scaleAI) ;
};

// Don't spawn additional AI if the server fps is below _minFPS
if(diag_fps < _minFPS) exitWith 
{ 
    if(SC_extendedLogging) then 
    { 
        _logDetail = format ["[OCCUPATION:Places]:: Held off spawning more AI as the server FPS is only %1",diag_fps]; 
        [_logDetail] call SC_fnc_log; 
    };
};

_aiActive = {alive _x && (side _x == SC_BanditSide OR side _x == SC_SurvivorSide)} count allUnits;
if(_aiActive > _maxAIcount) exitWith 
{ 
    if(SC_extendedLogging) then 
    { 
        _logDetail = format ["[OCCUPATION:Places]:: %1 active AI, so not spawning AI this time",_aiActive]; 
        [_logDetail] call SC_fnc_log;
    };
};

_locations = (nearestLocations [_spawnCenter, ["NameVillage","NameCity", "NameCityCapital"], _maxDistance]);
{
	_okToSpawn = true;
	_temppos = position _x;
	_locationName = text _x;
	_locationType = type _x;
	_pos = [_temppos select 0, _temppos select 1, 0];
	
	if(SC_extendedLogging) then 
    { 
        _logDetail = format ["[OCCUPATION:Places]:: Testing location name: %1 position: %2",_locationName,_pos]; 
        [_logDetail] call SC_fnc_log; 
    };
	
	while{_okToSpawn} do
	{			
		// Percentage chance to spawn (roll 80 or more to spawn AI)
		_spawnChance = round (random 100);
		if(_spawnChance < 80) exitWith 
        {
            _okToSpawn = false; 
            if(SC_extendedLogging) then 
            { 
                _logDetail = format ["[OCCUPATION:Places]:: Rolled %1 so not spawning AI this time",_spawnChance,_locationName];
                [_logDetail] call SC_fnc_log;
            };
        };
			
		// Don't spawn if too near a player base
		_nearBase = (nearestObjects [_pos,["Exile_Construction_Flag_Static"],500]) select 0;
		if (!isNil "_nearBase") exitwith 
        { 
            _okToSpawn = false; 
            if(SC_extendedLogging) then 
            { 
                _logDetail = format ["[OCCUPATION:Places]:: %1 is too close to player base",_locationName];
                [_logDetail] call SC_fnc_log;
            };
        };
		
		// Don't spawn AI near traders and spawn zones
		_nearestMarker = [allMapMarkers, _pos] call BIS_fnc_nearestPosition; // Nearest Marker to the Location		
		_posNearestMarker = getMarkerPos _nearestMarker;
		if(_pos distance _posNearestMarker < 500) exitwith 
        { 
            _okToSpawn = false; 
            if(SC_extendedLogging) then 
            { 
                _logDetail = format ["[OCCUPATION:Places]:: %1 is too close to a %2",_locationName,_nearestMarker];
                [_logDetail] call SC_fnc_log;
            }; 
        };
	
		// Don't spawn additional AI if there are players in range
		if([_pos, 250] call ExileClient_util_world_isAlivePlayerInRange) exitwith 
        { 
            _okToSpawn = false; 
            if(SC_extendedLogging) then 
            { 
                _logDetail = format ["[OCCUPATION:Places]:: %1 has players too close",_locationName];
                [_logDetail] call SC_fnc_log;
            }; 
        };
    
		// Don't spawn additional AI if there are already AI in range
        _nearBanditAI = { side _x == SC_BanditSide AND _x distance _pos < 500 } count allUnits;
        _nearSurvivorAI = { side _x == SC_SurvivorSide AND _x distance _pos < 500 } count allUnits;

        if(_nearBanditAI > 0 AND _nearSurvivorAI > 0) then 
        { 
            _okToSpawn = false; 
            if(SC_extendedLogging) then 
            { 
                _logDetail = format ["[OCCUPATION:Places]:: %1 already has active AI patrolling",_locationName];
                [_logDetail] call SC_fnc_log;
            }; 
        }
        else
        {
            if(_nearBanditAI == 0 AND _nearSurvivorAI == 0) then 
            { 
                _sideToSpawn = random 100; 
                if(_sideToSpawn <= SC_SurvivorsChance) then  
                { 
                    _side = "survivor";   
                }
                else
                { 
                    _side = "bandit";           
                };
            }
            else
            {
                if(_nearSurvivorAI == 0) then 
                { 
                    _side = "survivor";
                }
                else 
                { 
                    _side = "bandit"; 
                };
            };            
        };

		if(_okToSpawn) then
		{
			if(!SC_occupyPlacesSurvivors) then { _side = "bandit"; };
            //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Get AI to patrol the town
			//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			_aiCount = 1;
			_groupRadius = 100;
			if(_locationType isEqualTo "NameCityCapital") then  { _aiCount = 5; _groupRadius = 300; };
			if(_locationType isEqualTo "NameCity") then         { _aiCount = 2 + (round (random 3)); _groupRadius = 200; };
			if(_locationType isEqualTo "NameVillage") then      { _aiCount = 1 + (round (random 2)); _groupRadius = 100; };
				
			if(_aiCount < 1) then { _aiCount = 1; };
			_difficulty = "random";
			
			_spawnPos = [_pos,10,100,5,0,20,0] call BIS_fnc_findSafePos;		
			_spawnPosition = [_spawnPos select 0, _spawnPos select 1,0];
			
			DMS_ai_use_launchers = false;
			_initialGroup = [_spawnPosition, _aiCount, "randomEasy", "assault", _side] call DMS_fnc_SpawnAIGroup;
			DMS_ai_use_launchers = _useLaunchers;
            
            _group = createGroup SC_BanditSide;
            if(_side == "survivor") then 
            { 
                deleteGroup _group;
                _group = createGroup SC_SurvivorSide;              
            };
            
            _group setVariable ["DMS_LockLocality",nil];
            _group setVariable ["DMS_SpawnedGroup",true];
            _group setVariable ["DMS_Group_Side", _side];
            
            {	
                _unit = _x;           
                [_unit] joinSilent grpNull;
                [_unit] joinSilent _group;
                if(_side == "survivor") then
                {
                    _unit addMPEventHandler ["mphit", "_this call SC_fnc_unitMPHit;"];
                    removeUniform _unit;
                    _unit forceAddUniform "Exile_Uniform_BambiOverall";     
                    if(SC_debug) then
                    {
                        _tag = createVehicle ["Sign_Arrow_Green_F", position _unit, [], 0, "CAN_COLLIDE"];
                        _tag attachTo [_unit,[0,0,0.6],"Head"];  
                    };          
                }
                else
                {
                    if(SC_debug) then
                    {
                        _tag = createVehicle ["Sign_Arrow_F", position _unit, [], 0, "CAN_COLLIDE"];
                        _tag attachTo [_unit,[0,0,0.6],"Head"];  
                    };                      
                };
            }foreach units _initialGroup;
						
			// Get the AI to shut the fuck up :)
			enableSentences false;
			enableRadio false;
			
			if(!SC_useWaypoints) then
			{
				[_group, _pos, _groupRadius] call bis_fnc_taskPatrol;
				_group setBehaviour "COMBAT";
				_group setCombatMode "RED";
			}
			else
			{
				[ _group,_pos,_difficulty,"COMBAT" ] call DMS_fnc_SetGroupBehavior;
				
				_buildings = _pos nearObjects ["building", _groupRadius];
				{
					_isEnterable = [_x] call BIS_fnc_isBuildingEnterable;
             
					if(_isEnterable) then
					{
                        _buildingPositions = [_x, 10] call BIS_fnc_buildingPositions;
                        _y = _x;
                        
						// Find Highest Point
						_highest = [0,0,0];
						{
							if(_x select 2 > _highest select 2) then
							{
								_highest = _x;
							};

						} foreach _buildingPositions;		
						_wpPosition = _highest;
						
						_i = _buildingPositions find _wpPosition;
						_wp = _group addWaypoint [_wpPosition, 0] ;
						_wp setWaypointBehaviour "COMBAT";
						_wp setWaypointCombatMode "RED";
						_wp setWaypointCompletionRadius 1;
						_wp waypointAttachObject _y;
						_wp setwaypointHousePosition _i;
						_wp setWaypointType "SAD";

					};
				} foreach _buildings;
				if(count _buildings > 0 && !isNil "_wp") then
				{
					_wp setWaypointType "CYCLE";
				};			
			};

			if(_locationType isEqualTo "NameCityCapital") then
			{
				DMS_ai_use_launchers = false;
				_initialGroup2 = [_spawnPosition, 5, _difficulty, "random", _side] call DMS_fnc_SpawnAIGroup;
				DMS_ai_use_launchers = _useLaunchers;

                _group2 = createGroup SC_BanditSide;
                if(_side == "survivor") then 
                {                   
                    deleteGroup _group2;
                    _group2 = createGroup SC_SurvivorSide;
                };
                         
                _group2 setVariable ["DMS_LockLocality",nil];
                _group2 setVariable ["DMS_SpawnedGroup",true];
                _group2 setVariable ["DMS_Group_Side", _side];                         
                            
				// Get the AI to shut the fuck up :)
				enableSentences false;
				enableRadio false;
     
                {	
                    _unit = _x;
                    [_unit] joinSilent grpNull;
                    [_unit] joinSilent _group2;
                    if(_side == "survivor") then
                    {
                        _unit addMPEventHandler ["mphit", "_this call SC_fnc_unitMPHit;"];
                        removeUniform _unit;
                        _unit forceAddUniform "Exile_Uniform_BambiOverall";     
                        if(SC_debug) then
                        {
                            _tag = createVehicle ["Sign_Arrow_Green_F", position _unit, [], 0, "CAN_COLLIDE"];
                            _tag attachTo [_unit,[0,0,0.6],"Head"];  
                        };
                    }
                    else
                    {
                        if(SC_debug) then
                        {
                            _tag = createVehicle ["Sign_Arrow_F", position _unit, [], 0, "CAN_COLLIDE"];
                            _tag attachTo [_unit,[0,0,0.6],"Head"];  
                        };                                                       
                    };
                }foreach units _initialGroup2;
                
				[_group2, _pos, _groupRadius] call bis_fnc_taskPatrol;
				_group2 setBehaviour "AWARE";
				_group2 setCombatMode "RED";
			};
			//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			
			if(SC_mapMarkers) then 
			{
				_marker = createMarker [format ["%1", _spawnPosition],_pos];
				_marker setMarkerShape "Icon";
				_marker setMarkerSize [3,3];
				_marker setMarkerType "mil_dot";
				_marker setMarkerBrush "Solid";
				_marker setMarkerAlpha 0.5;
				_marker setMarkerColor "ColorOrange";
				_marker setMarkerText "Occupied Area";	
			};			
			
			if(_side == "survivor") then 
            {
                _logDetail = format ["[OCCUPATION:Places]:: Spawning %2 survivor AI in at %3 to patrol %1",_locationName,_aiCount,_spawnPosition];                  
            }
            else
            {
                _logDetail = format ["[OCCUPATION:Places]:: Spawning %2 bandit AI in at %3 to patrol %1",_locationName,_aiCount,_spawnPosition];    
            };
            [_logDetail] call SC_fnc_log;
			_okToSpawn = false;		
		};
	
	};
	sleep 0.2;
} forEach _locations;