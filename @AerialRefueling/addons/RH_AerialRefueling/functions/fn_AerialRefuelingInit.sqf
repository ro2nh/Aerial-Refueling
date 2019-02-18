/*
Notes:
 - Replace rope with cable model:
  - Black thick cable with an connection object
 - Add radio transmissions to actions
 - Attach fuel objects to plane:
  - A hole that the cable comes out of
  - A receiver to the requested plane that the cable connects to
 - Ver.2.0:
  - Refueling controlled by a player
  - Fuel gui on the refueling plane
  - Add refueling on the ground using ace mod to the external fuel

  Create a new mod of Cockpit-Control using mouse
*/

// Debugging the code
// Usage: if(DebugCode) then { systemChat "debug message"; };
DebugCode = true;

RH_REFUELING_SUPPORTED_VEHICLES = [
	"B_Plane_CAS_01_dynamicLoadout_F",
	"B_Plane_Fighter_01_F"
];

RH_REFUELING_PLANES_TYPES = [
	"B_T_VTOL_01_armed_F"
];

MAX_MAP_DISTANCE = 7000;	// meters
REQUEST_DISTANCE = 1000;	// meters
DISTANCE_TO_CABLE = 50;		// meters

BASIC_MAX_CABLES = 2;
CABLE_WIND_SPEED = 25;		// meters per seconds
MAX_CABLE_LENGTH = 100;		// meters

BASIC_MAX_FUEL_CAPACITY = 5; // 5 full tanks

REFUELING_SPEED = 0.05; 	// meters per second

IDLE_TIME = 4 * 60; 		// 4 minutes

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
	}, nil, 0, false, false, "", ""];

	player addAction["Request Refuel", {
		[] call RH_RequestRefuel;
	}, nil, 0, false, true, "", "[REQUEST_DISTANCE] call RH_IsPlayerAbleToRequest"];

	player addAction["Cancel Request", {
		[] call RH_CancelRequest;
	}, nil, 0, false, true, "", "call RH_IsPlayerRequestedRefuel"];

	if(DebugCode) then { systemChat "Actions were added to the player"; };
};

// Reports the location of a given plane
// Input: plane
// Output: none
RH_ReportLocation =
{
	params["_plane"];
	_planeSpeed = speed _plane;
	_planeHeight = getPosATL _plane select 2;
	hint format["%1\n%2 km/h\nHeight: %3", mapGridPosition _plane, _planeSpeed, _planeHeight];

	if(DebugCode) then { systemChat "Location was reported"; };
};

// Sets a request of refueling from the player
RH_RequestRefuel =
{
	player setVariable["RefuelRequested", true];

	if(DebugCode) then { systemChat "Requested refuel"; };
};

// Deletes a player request
RH_CancelRequest =
{
	player setVariable["RefuelRequested", false];

	if(DebugCode) then { systemChat "Request was canceled"; };
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
	for "_i" from 0 to (BASIC_MAX_CABLES - 1) do
	{
		// Getting the cable position
		_cablePos = [0, 0, 0];
		if(_i == 0) then
		{
			_cablePos = [10, 0, 0];
		}
		else
		{
			_cablePos = [-10, 0, 0];
		};

		_cable = ropeCreate[_plane, _cablePos, 0];
		//Not working yet
		_cable setObjectTexture [0, "\RH_AerialRefueling\data\cable.paa"];
		_cable setObjectTexture [1, ""];

		_cablesObj = [];
		_cablesObj pushBack _cable;
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

	// Updating all clients
	[_plane, _cables] remoteExecCall ["RH_UpdatePlanes"];

	if(DebugCode) then { systemChat "Cable was released"; };
};

// Pulling a chosen cable up to the refueling plane
// Input: plane, cable, cable index
// Output: none
RH_PullCableUp =
{
	params["_plane", "_cable", "_cableIndex"];

	ropeUnwind [_cable, CABLE_WIND_SPEED, -MAX_CABLE_LENGTH, true];

	sleep (MAX_CABLE_LENGTH / CABLE_WIND_SPEED);

	// Updating 'cables' variable
	_cables = _plane getVariable ["Cables", objNull];
	if!(_cables isEqualTo objNull) then
	{
		_singleCable = _cables select _cableIndex;
		_singleCable set [1, false];
		_cables set [_cableIndex, _singleCable];
		_plane setVariable["Cables", _cables];
	};

	// Updating all clients
	[_plane, _cables] remoteExecCall ["RH_UpdatePlanes"];

	if(DebugCode) then { systemChat "Cable was pull up"; };
};

// Checks if the player's plane is close to the end of the cable
// Input: cable
// Output: true if close, false otherwise
RH_IsPlayerPlaneCloseToCable =
{
	params["_cable"];

	// Checking if cable exists
	if(_cable isEqualTo objNull) exitWith
	{
		false
	};

	_pos = ropeEndPosition _cable select 1;
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

	// Attaching the cable to the player's plane
	_veh = vehicle player;
	[_veh, [0, 5, 0], [0, 0, -1]] ropeAttachTo _cable;
	_attachPos = 	[abs ((getPos _cable select 0) - (getPos _plane select 0)),
					 abs ((getPos _cable select 1) - (getPos _plane select 1)),
					 abs ((getPos _cable select 2) - (getPos _plane select 2))];

	if(_cableIndex == 0) then
	{
		_attachPos set[0, ((_attachPos select 0) + 50)];
	}
	else
	{
		_attachPos set[0, ((_attachPos select 0) - 50)];
	};
	_attachPos set[1, ((_attachPos select 1) - 100)];
	_veh attachTo [_plane, _attachPos];

	// Updating 'cables'
	_cables = _plane getVariable["Cables", objNull];
	if!(_cables isEqualTo objNull) then
	{
		_singleCable = _cables select _cableIndex;
		_singleCable set [3, true];
		_cables set [_cableIndex, _singleCable];
		_plane setVariable["Cables", _cables];
	};

	// Updating all clients
	[_plane, _cables] remoteExecCall ["RH_UpdatePlanes"];
	
	// Updating player
	player setVariable["RefuelRequested", false];
	player setVariable["Refueling", true];
	player setVariable["Velocity", (velocity _veh)];

	// Add disconnect action to the player
	player addAction["Disconnect Cable", {
		player setVariable["Refueling", false];
	}, nil, 0, false, true, "", "call RH_IsPlayerRefueling"];

	if(DebugCode) then { systemChat "Cable is connected"; };
};

// Disconnects the cable attached from refueling plane to the player's plane
// Input: plane, cable, cable index
// Output: none
RH_DisconnectCable =
{
	params["_plane", "_cable", "_cableIndex"];

	_veh = vehicle player;
	_veh ropeDetach _cable;
	detach _veh;

	// Turning engine on
	_veh engineOn true;
	_playerVelocity = player getVariable["Velocity", [0, 0, 0]];
	_veh setVelocity _playerVelocity;

	// Updating 'cables'
	_cables = _plane getVariable["Cables", objNull];
	if!(_cables isEqualTo objNull) then
	{
		_singleCable = _cables select _cableIndex;
		_singleCable set [3, false];
		_cables set [_cableIndex, _singleCable];
		_plane setVariable["Cables", _cables];
	};

	// Updating all clients
	[_plane, _cables] remoteExecCall ["RH_UpdatePlanes"];
	
	// Updating player
	player setVariable["Refueling", false];

	if(DebugCode) then { systemChat "Cable disconnected"; };
};

// Refuels the player's plane
// Input: plane, cable, cable index
// Output: none
RH_RefuelPlayerPlane =
{
	params["_plane", "_cable", "_cableIndex"];

	[_plane, _cable, _cableIndex] call RH_ConnectCable;

	// Transfering fuel
	if(DebugCode) then { systemChat "Refueling"; };
	[_plane] call RH_TransferFuel;

	[_plane, _cable, _cableIndex] call RH_DisconnectCable;
};

// Transfers fuel from the refueling plane to the player
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


// Updates 'Planes' global variable
// Input: plane, cables
// Output: none
RH_UpdatePlanes =
{
	params["_plane", "_cables"];

	{
		if(_x isEqualTo _plane) exitWith
		{
			if!(_cables isEqualTo objNull) then
			{
				_x setVariable["Cables", _cables];
			}
		};
	} forEach Planes;

	if(DebugCode) then { systemChat "Plane updated"; };
};

// Checks if this is a real player
if(hasInterface) then
{
	// Initiallizing all refueling planes
	{
		[_x] call RH_CreateBasicRefuelingPlane;
	} forEach nearestObjects [player, RH_REFUELING_PLANES_TYPES, MAX_MAP_DISTANCE];

	while { true } do
	{
		{
			// Check if refueling plane is idle for some time
			_cables = _x getVariable["Cables", objNull];
			if(_cables isEqualTo objNull) exitWith { true };
			_numOfCables = count _cables - 1;
			for "_i" from 0 to _numOfCables do
			{
				_cable = _cables select _i select 0;
				_isOut = _cables select _i select 1;
				_isTransferring = _cables select _i select 2;
				// Check if the transferring from this cable and cable is out
				if(!(_isTransferring) && _isOut) then
				{
					_timer = _cable getVariable["IdleTimer", -1];
					if(_timer == -1) then
					{
						_cable setVariable["IdleTimer", IDLE_TIME];
						_timer = IDLE_TIME;
					};
					if(_timer == 0) then
					{
						// Times up
						// Resetting timer and pulling cable up
						_cable setVariable["IdleTimer", IDLE_TIME];
						[_x, _cable, _i] call RH_PullCableUp;
					};
					_timer = _timer - 1;
					_cable setVariable["IdleTimer", _timer];
				};
			};
		} forEach Planes;
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
					
					if(DebugCode) then { systemChat "Installed"; };
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
					
					if(DebugCode) then { systemChat "Uninstalled"; };
				};
			};
		};
		sleep 1;
	};
};