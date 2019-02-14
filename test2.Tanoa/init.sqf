/*
Notes:
 - Fix 'RH_IsAirborne' function (Changed it for debugging purposes)
*/

RH_REFUELING_SUPPORTED_VEHICLES = [
	"I_C_Plane_Civil_01_F",
	"B_Plane_CAS_01_dynamicLoadout_F"
];

RH_REFUELING_PLANES_TYPES = [
	"B_T_VTOL_01_armed_F"
];

MAX_MAP_DISTANCE = 7000;
REQUEST_DISTANCE = 1000;
DISTANCE_TO_CABLE = 50;

BASIC_MAX_CABLES = 2;
CABLE_WIND_SPEED = 25;
MAX_CABLE_LENGTH = 200;

BASIC_MAX_FUEL_CAPACITY = 5;

REFUELING_SPEED = 0.05;

Planes = [];

// Install player attributes
RH_InstallPlayerAttributes =
{
	player setVariable["RefuelRequested", false];
	player setVariable["Refueling", false];
	player setVariable["Installed", true];
};

// Uninstall player attributes
RH_UninstallPlayerAttributes =
{
	player setVariable["RefuelRequested", false];
	player setVariable["Refueling", false];
	player setVariable["Installed", false];
};

// Checks if the player requested refueling
// Input: none
// Output: true if there is a request, false otherwise
RH_IsPlayerRequestedRefuel =
{
	player getVariable["RefuelRequested", false]
};

// Checks if the player is currently refueling his plane
// Input: none
// Output: true if player's plane is getting refueled, false otherwise
RH_IsPlayerRefueling =
{
	player getVariable["Refueling", false]
};

// Checks if the player:
//  - there isn't a request already
//  - close to the refueling plane
//  - is not refueling currently
// Input: radius
// Output: true if player is able to request a refuel, false otherwise
RH_IsPlayerAbleToRequest =
{
	params["_radius"];

	_able = [] call RH_IsPlayerRequestedRefuel;
	if(_able) exitWith
	{
		false
	};
	_able = [_radius] call RH_IsRefuelingPlaneClose;
	if!(_able) exitWith
	{
		false
	};
	_able = [] call RH_IsPlayerRefueling;
	if(_able) exitWith
	{
		false
	};
	true
};

// Adds actions to the player in vanilla
RH_AddActionsToPlayer =
{
	player addAction["Report Location", {
		// Getting the closest refueling plane to the player
		_closest = [] call RH_GetClosestRefuelingPlane;
		if!(_closest isEqualTo objNull) then
		{
			[_closest] call RH_ReportLocation;
		};
	}, nil, 0, false, false, "", "call RH_IsRefuelingPlaneFar"];

	player addAction["Request Refuel", {
		[] call RH_RequestRefuel;
	}, nil, 0, false, true, "", "[REQUEST_DISTANCE] call RH_IsPlayerAbleToRequest"];

	player addAction["Cancel Request", {
		[] call RH_CancelRequest;
	}, nil, 0, false, true, "", "call RH_IsPlayerRequestedRefuel"];
};

// Reports the location of a given plane
// Input: plane
// Output: none
RH_ReportLocation =
{
	params["_plane"];
	hint mapGridPosition _plane;

	systemChat "REPORTING";
};

// Sets a request of refueling from the player
RH_RequestRefuel =
{
	player setVariable["RefuelRequested", true];
};

// Deletes a player request
RH_CancelRequest =
{
	player setVariable["RefuelRequested", false];
};

// Checks if the refueling plane is far from the player's plane
// Input: plane
// Output: true if it is far, false otherwise
RH_IsRefuelingPlaneFar =
{
	_isRPlaneClose = [REQUEST_DISTANCE] call RH_IsRefuelingPlaneClose;
	if(_isRPlaneClose) exitWith
	{
		false
	};
	true
};

// Gets the co-pilot of a given vehicle
// Input: vehicle
// Output: co-pilot unit on success, objNull on failure
RH_GetCoPilot =
{
	params["_veh"];

	_list = fullCrew [_veh, "turret"];
	_coPilot = objNull;
	if(count _list > 0) then
	{
		_coPilot = _list select 0 select 0;
	};
	_coPilot
};

// Checks if the unit is airborne
// Input: unit
// Output: true if it is airborne else returns false
/*
RH_IsAirborne =
{
	params ["_unit"];

	if(_unit isEqualTo objNull) exitWith
	{
		false
	};
	if(getPosATL _unit select 2 > 4) exitWith
	{
		true
	};
	false
};
*/
// Only for debugging
RH_IsAirborne =
{
	params ["_unit"];

	true
};


// Checks if player is close to the refueling plane
// Input: radius
// Output: true if player is close, false otherwise
RH_IsRefuelingPlaneClose =
{
	params["_radius"];

	_plane = [] call RH_GetClosestRefuelingPlane;
	
	if(_plane isEqualTo objNull) exitWith { false };
	if(_plane distance vehicle player <= _radius) exitWith
	{
		true
	};
	false
};

// Gets the closest refueling plane to the player
// Input: none
// Output: plane object on success, objNull on failure
RH_GetClosestRefuelingPlane =
{
	_distance = MAX_MAP_DISTANCE;
	_closest = objNull;
	{
		_isPlaneAirborne = [_x] call RH_IsAirborne;
		if(_isPlaneAirborne) then
		{
			_nDistance = vehicle player distance _x;
			if(_nDistance < _distance) then
			{
				_distance = _nDistance;
				_closest = _x;
			};
		};
	} forEach Planes;
	_closest
};

// Creates a basic refueling plane variables
//  _plane["ExternalFuel"] = Fuel
//  _plane["Cables"] = [[ropeObj, false, false], [ropeObj, false, false]]
// Input: plane
// Output: none
RH_CreateBasicRefuelingPlane =
{
	params["_plane"];

	// Setting up variables
	_cables = [];
	_isOut = false;
	_isTransferring = false;
	_fuel = BASIC_MAX_FUEL_CAPACITY;

	// Setting up cables
	for "_i" from 0 to BASIC_MAX_CABLES do
	{
		_cablesObj = [];
		_cablesObj pushBack ropeCreate[_plane, [0, 0, 0], 0];
		_cablesObj pushBack _isOut;
		_cablesObj pushBack _isTransferring;

		_cables pushBack _cablesObj;
	};

	// Storing variables inside the plane variable space
	_plane setVariable["ExternalFuel", BASIC_MAX_FUEL_CAPACITY];
	_plane setVariable["Cables", _cables];

	// Adding plane to the list
	Planes pushBack _plane;
};

// Releases a chosen cable from the refueling plane
// Input: plane, cable, cable index
// Output: none
RH_ReleaseCable =
{
	params["_plane", "_cable", "_cableIndex"];

	ropeUnwind [_cable, CABLE_WIND_SPEED, MAX_CABLE_LENGTH];

	sleep (MAX_CABLE_LENGTH / CABLE_WIND_SPEED);

	// Updating 'cables' variable
	_cables = _plane getVariable ["Cables", objNull];
	if!(_cables isEqualTo objNull) then
	{
		_singleCable = _cables select _cableIndex;
		_singleCable set [1, true];
		_cables set [_cableIndex, _singleCable];
		_plane setVariable["Cables", _cables];
	};
};

// Checks if the player's plane is close to the end of the cable
// Input: cable
// Output: true if close, false otherwise
RH_IsPlayerPlaneCloseToCable =
{
	params["_cable"];

	_pos = ropeEndPosition _cable select 0;
	_pos2 = getPosATL vehicle player;

	if(_pos distance _pos2 <= DISTANCE_TO_CABLE) exitWith
	{
		true
	};
	false
};

// Connects a cable from the refueling plane to the player's plane
// Input: plane, cable, cable index
// Output: none
RH_ConnectCable =
{
	params["_plane", "_cable", "_cableIndex"];

	[vehicle player, [0, 0, 0], [0, 0, -1]] ropeAttachTo _cable;
	vehicle player attachTo [_plane, [0, -100, 0]];

	// Updating 'cables'
	_cables = _plane getVariable["Cables", objNull];
	if!(_cables isEqualTo objNull) then
	{
		_singleCable = _cables select _cableIndex;
		_singleCable set [3, true];
		_cables set [_cableIndex, _singleCable];
		_plane setVariable["Cables", _cables];
	};
	
	// Updating player
	player setVariable["RefuelRequested", false];
	player setVariable["Refueling", true];

	// Add disconnect action to the player
	player addAction["Disconnect Cable", {
		player setVariable["Refueling", false];
	}, nil, 0, false, true, "", "call RH_IsPlayerRefueling"];
};

// Disconnects the cable attached from refueling plane to the player's plane
// Input: plane, cable, cable index
// Output: none
RH_DisconnectCable =
{
	params["_plane", "_cable", "_cableIndex"];

	vehicle player ropeDetach _cable;
	detach vehicle player;

	// Updating 'cables'
	_cables = _plane getVariable["Cables", objNull];
	if!(_cables isEqualTo objNull) then
	{
		_singleCable = _cables select _cableIndex;
		_singleCable set [3, false];
		_cables set [_cableIndex, _singleCable];
		_plane setVariable["Cables", _cables];
	};
	
	// Updating player
	player setVariable["Refueling", false];
};

// Refueling the player's plane
// Input: plane, cable, cable index
// Output: none
RH_RefuelPlayerPlane =
{
	params["_plane", "_cable", "_cableIndex"];

	[_plane, _cable, _cableIndex] call RH_ConnectCable;

	// Transfering fuel
	[_plane] call RH_TransferFuel;

	[_plane, _cable, _cableIndex] call RH_DisconnectCable;
};

// Transferring fuel from the refueling plane to the player
RH_TransferFuel =
{
	_isCompleted = false;
	while { !_isCompleted } do
	{
		// Checking if transference interrupted
		_isPlayerRefueling = [] call RH_IsPlayerRefueling;
		if!(_isPlayerRefueling) exitWith { false };
		// Checking if refueling plane has got external fuel to transfer
		_externalFuel = _plane getVariable["ExternalFuel", 0];
		if(_externalFuel <= 0) exitWith { false };
		// Checking if player's plane needs fuel
		_playerFuel = fuel vehicle player;
		if(_playerFuel >= 1) exitWith { false };
		// Checking if refueling plane has enough external fuel to transfer
		_transferIncrease = REFUELING_SPEED;
		if(_externalFuel < _transferIncrease) exitWith { false };
		_leftToTransfer = 1 - _playerFuel;
		// Checking if there is no need of transferring fuel
		if(_leftToTransfer <= 0) exitWith { false };

		// Transferring fuel
		_playerFuel = _playerFuel + _transferIncrease;
		_externalFuel = _externalFuel - _transferIncrease;
		_plane setVariable["ExternalFuel", _externalFuel];
		vehicle player setFuel _playerFuel;
		sleep 1;
	};
};

// Single Player
if(!isDedicated) then
{
	// Initiallizing all refueling planes
	{
		[_x] call RH_CreateBasicRefuelingPlane;
	} forEach nearestObjects [player, RH_REFUELING_PLANES_TYPES, MAX_MAP_DISTANCE];

	while { true } do
	{
		if(!isNull player && isPlayer player) then
		{
			// Check if there are refueling planes
			if(count Planes == 0) exitWith { false };
			// Check if player is in a vehicle
			_veh = vehicle player;
			_isInstalled = player getVariable["Installed", false];
			if(_veh != player) then
			{
				// Check if installed already
				// player is in supported vehicle
				// and player is driver or co-pilot
				_coPilot = [_veh] call RH_GetCoPilot;
				if(!_isInstalled && typeOf _veh in RH_REFUELING_SUPPORTED_VEHICLES && (driver _veh isEqualTo player || _coPilot isEqualTo player)) exitWith
				{
					// Installation
					[] call RH_InstallPlayerAttributes;
					[] spawn RH_AddActionsToPlayer;
					// debug
					//hint "Installed";
				};
				if(_isInstalled && typeOf _veh in RH_REFUELING_SUPPORTED_VEHICLES && (driver _veh isEqualTo player || _coPilot isEqualTo player)) exitWith
				{
					// Refueling player's plane
					// Checks if player:
					//  - is airborne
					//  - is inside of the radius of a refueling plane
					//  - requested refuel
					//  - not refueling currently
					_isPlayerAirborne = [_veh] call RH_IsAirborne;
					_isPlayerClose = [REQUEST_DISTANCE] call RH_IsRefuelingPlaneClose;
					_isPlayerRequestedRefuel = [] call RH_IsPlayerRequestedRefuel;
					_isPlayerRefueling = [] call RH_IsPlayerRefueling;

					if(!_isPlayerRefueling && _isPlayerAirborne && _isPlayerClose && _isPlayerRequestedRefuel) then
					{
						// Checks if refueling plane has any external fuel to give
						_refuelingPlane = [] call RH_GetClosestRefuelingPlane;
						if(_refuelingPlane isEqualTo objNull) exitWith { true };
						_rPlaneFuel = _refuelingPlane getVariable["ExternalFuel", 0];
						if(_rPlaneFuel > 0) then
						{
							// Checks if there are free cables
							_cables = _refuelingPlane getVariable["Cables", objNull];
							if(_cables isEqualTo objNull) exitWith { true };
							_numOfCables = count _cables - 1;
							for "_i" from 0 to _numOfCables do
							{
								_cable = _cables select _i select 0;
								_isOut = _cables select _i select 1;
								_isTransferring = _cables select _i select 2;
								
								if(!_isTransferring) exitWith
								{
									// Gets cable out
									if(!_isOut) then
									{
										[_refuelingPlane, _cable, _i] call RH_ReleaseCable;
										_isOut = true;
									};
									// Checks if player's plane is close to the end of the cable
									_isPlayerPlaneCloseToCable = [_cable] call RH_IsPlayerPlaneCloseToCable;
									if(_isPlayerPlaneCloseToCable) then
									{
										// Refuel player's plane
										[_refuelingPlane, _cable, _i] call RH_RefuelPlayerPlane;
									};
								};
							};
						};
					};
				};
			}
			else
			{
				if(_isInstalled) then
				{
					[] call RH_UninstallPlayerAttributes;
					// debug
					//hint "Uninstalled";
				};
			};
		};
		sleep 1;
	};
};