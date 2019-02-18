/*
Notes:
- Simplfy script
- Replace rope with cable model:
 - Black thick cable with an connection object
- Fix disconnect cable function
- Add refueling on the ground using ace mod to the external fuel
- Add fuel gui on the refueling plane
- Add radio transmissions to actions
*/

// For getting vehicles type: hint typeOf vehicle player
RH_REFUELING_SUPPORTED_VEHICLES = [
	"I_C_Plane_Civil_01_F",
	"B_Plane_CAS_01_dynamicLoadout_F",
	"B_Plane_Fighter_01_F"
];

RH_REFUELING_PLANES_TYPES = [
	"B_T_VTOL_01_armed_F"
];

MAX_MAP_DISTANCE = 7000;
DISTANCE_TO_REQUEST = 1000;
DISTANCE_TO_CABLE = 5;

MAX_CABLE_LENGTH = 200;
CABLE_WIND_SPEED = 25;

REFUELING_SPEED = 0.02; // percent per second
MAX_FUEL_CAPACITY = 5;

Planes = [];
//debug
//Planes pushBack ("B_T_VTOL_01_armed_F" createVehicle [12194.7,13068.8,5.84077]);

RH_PlayerAddActions = 
{
	player addAction ["Report Location", {
		[] call RH_ReportPlaneLocation;
	}, nil, 0, false, false, "", "call RH_IsRefuelingPlaneFarAway"];

	player addAction ["Request Refuel", {
		[] call RH_RequestRefuel;
	}, nil, 0, false, true, "", "call RH_IsRefuelingPlaneCloseAndNotRequestedAndNotRefueling"];

	player addAction ["Cancel Request", {
		[] call RH_CancelRequest;
	}, nil, 0, false, true, "", "call RH_IsThereRequest"];

	/*
	player addAction ["Disconnect Cable", {
		//_connectionInfo = player getVariable["ConnectionInfo", objNull];
		[] call RH_DisconnectCable;
	}, nil, 0, false, true, "", "call RH_IsRefueling"];
	*/
};

RH_GetClosestRefuelingPlane = 
{
	_distance = MAX_MAP_DISTANCE;
	_closest = Planes select 0;
	{
		_isAirborne = [_x] call RH_IsAirborne;
		if(_isAirborne) then
		{
			_nDistance = player distance _x;
			if(_nDistance <= _distance) then
			{
				_distance = _nDistance;
				_closest = _x;
			}
		};
	} forEach Planes;
	_isAirborne = [_closest] call RH_IsAirborne;
	if(_isAirborne) exitWith { _closest };
	objNull
};

// Get the location of the closest refueling plane
RH_ReportPlaneLocation = 
{
	// add radio report
	_plane = [] call RH_GetClosestRefuelingPlane;
	hint mapGridPosition _plane;
};

RH_RequestRefuel =
{
	// add radio report
	player setVariable["RefuelRequested", true];
};

RH_CancelRequest =
{
	// add radio report
	player setVariable["RefuelRequested", false];
};

// Plane functions
RH_GetCableOut = 
{
	params["_plane", "_cable", "_cableIndex"];

	ropeUnwind [_cable, CABLE_WIND_SPEED, MAX_CABLE_LENGTH];

	sleep (MAX_CABLE_LENGTH / CABLE_WIND_SPEED);

	// Update 'cables' variable
	_cables = _plane getVariable ["Cables", objNull];
	_cable = _cables select _cableIndex;
	_cable set [2, true];
	_cables set [_cableIndex, _cable];
	_plane setVariable["Cables", _cables];
};

RH_ConnectCable = 
{
	params ["_plane", "_cable", "_cableIndex"];

	[vehicle player, [0, 0, 0], [0, 0, -1]] ropeAttachTo _cable;
	vehicle player attachTo [_plane, [0, -100, 0]];

	// Update 'cables' variable
	_cables = _plane getVariable["Cables", objNull];
	_cableArray = _cables select _cableIndex;
	_cableArray set [3, true];
	_cables set [_cableIndex, _cableArray];
	_plane setVariable["Cables", _cables];

	// Update player variables
	player setVariable["RefuelRequested", false];
	player setVariable["Refueling", true];
	
	_disconnectAction = player addAction ["Disconnect Cable", {
		[_plane, _cable, _cableIndex] call RH_DisconnectCable;
	}, nil, 0, false, true, "", "call RH_IsRefueling"];
	player setVariable["DisconnectAction", _disconnectAction];
};

RH_DisconnectCable =
{
	params ["_plane", "_cable", "_cableIndex"];

	vehicle player ropeDetach _cable;
	detach vehicle player;

	// Update 'cables' variable
	_cables = _plane getVariable["Cables", objNull];
	_cableArray = _cables select _cableIndex;
	_cableArray set [3, false];
	_cables set [_cableIndex, _cableArray];
	_plane setVariable["Cables", _cables];

	// Update player variables
	player setVariable ["Refueling", false];

	_disconnectAction = player getVariable ["DisconnectAction", 0];
	player removeAction _disconnectAction;
};

RH_TransferFuel =
{
	params ["_plane", "_cable", "_cableIndex"];
	
	[_plane, _cable, _cableIndex] call RH_ConnectCable;

	// Refueling requested vehicle
	_planeFuel = _plane getVariable["Fuel", 0];
	_fuel = fuel vehicle player;
	_isComplete = false;
	while { !_isComplete } do
	{
		_refueling = player getVariable ["Refueling", false];
		if(!_refueling) exitWith { _isComplete = true; };
		if(_planeFuel == 0) exitWith { _isComplete = true; };
		if(_fuel == 1) exitWith { _isComplete = true; };
		_leftToFuel = 1 - _fuel;
		if(_planeFuel < _leftToFuel) exitWith { _isComplete = true; };
		if(_leftToFuel <= 0) exitWith { _isComplete = true; };
		_fuel = _fuel + REFUELING_SPEED;
		_planeFuel = _planeFuel - REFUELING_SPEED;
		_plane setVariable["Fuel", _planeFuel];
		vehicle player setFuel _fuel;
		sleep 1;
	};

	[_plane, _cable, _cableIndex] call RH_DisconnectCable;
};

// Validations
RH_IsCableVeryClose = 
{
	params ["_cable"];

	_pos = ropeEndPosition _cable select 0;
	_pos2 = getPosATL vehicle player;

	if(_pos distance _pos2 <= DISTANCE_TO_CABLE) exitWith
	{
		true
	};
	false
};

RH_IsRefuelingPlaneFarAway = 
{
	_plane = [] call RH_GetClosestRefuelingPlane;
	if(_plane == objNull) exitWith { true };
	if(_plane distance vehicle player >= DISTANCE_TO_REQUEST) exitWith
	{
		true
	};
	false
};

RH_IsRefuelingPlaneClose = 
{
	_val = [] call RH_IsRefuelingPlaneFarAway;
	if(_val) exitWith
	{
		false
	};
	true
};

RH_IsRefuelingPlaneCloseAndNotRequestedAndNotRefueling = 
{
	_val = [] call RH_IsRefuelingPlaneClose;
	if(_val) exitWith
	{
		_val = [] call RH_IsThereRequest;
		if(!_val) exitWith
		{
			_val = [] call RH_IsRefueling;
			if(_val) exitWith
			{
				false
			};
			true
		};
		false
	};
	false
};

RH_IsThereRequest =
{
	player getVariable "RefuelRequested"
};

RH_IsRefueling =
{
	player getVariable "Refueling"
};

RH_IsAirborne = 
{
	params["_obj"];

	if(getPosATL _obj select 2 > 15) exitWith
	{
		true
	};
	false
};

RH_CreateRefuelingPlane = 
{
	/*
	Planes var example:
	Planes = [plane1, plane2, ...];
	plane1 "Fuel" = MAX_FUEL_CAPACITY;
	plane1 "Cables" = [[ropeObj, _isDamaged, _isOut, _isTransferring], [ropeObj, _isDamaged, _isOut, _isTransferring]];
	*/
	{
		// Add 2 cables that comes out from 2 defined points
		// Set variables to each cable
		_cables = [];
		_isDamaged = false;
		_isOut = false;
		_isTransferring = false;
		_fuel = MAX_FUEL_CAPACITY;

		// Setting up 2 cables
		for "_i" from 0 to 1 do
		{
			_cablesObj = [];
			_cablesObj pushBack ropeCreate [_x, [0, 0, 0], 0];
			_cablesObj pushBack _isDamaged;
			_cablesObj pushBack _isOut;
			_cablesObj pushBack _isTransferring;

			_cables pushBack _cablesObj;
		};

		_x setVariable["Fuel", _fuel];
		_x setVariable["Cables", _cables];
	} forEach Planes;
};

// Entry point
[] spawn
{
	// Getting all refueling planes
	{
		Planes pushBack _x;
	} forEach nearestObjects [player, ["B_T_VTOL_01_armed_F"], MAX_MAP_DISTANCE];
	[] call RH_CreateRefuelingPlane;

	while { true } do
	{
		// Installation
		if(!isNull player && isPlayer player) then
		{
			// Check if there are refueling planes
			if(count Planes == 0) exitWith {};
			if(vehicle player != player) then
			{
				// Player is in a vehicle
				// Installation
				//debug
				vehicle player setFuel 0.4;
				if!(player getVariable["Installed", false]) then
				{
					if(typeOf vehicle player in RH_REFUELING_SUPPORTED_VEHICLES) then
					{
						// Player is in supported vehicle
						_list = fullCrew [vehicle player, "turret"];
						_coPilot = objNull;
						if(count _list > 0) then
						{
							_coPilot = _list select 0 select 0;
						};

						if(driver (vehicle player) isEqualTo player || _coPilot == player) then
						{
							[] spawn RH_PlayerAddActions;

							player setVariable["RefuelRequested", false];
							player setVariable["Refueling", false];
							player setVariable["Installed", true];
							// debug
							//hint "Installed";
						};
					};
				}
				else
				{
					// Check if player is airborne and close to refueling plane
					_isPlayerAirborne = [vehicle player] call RH_IsAirborne;
					_isClose = [] call RH_IsRefuelingPlaneClose;
					_isThereRequest = [] call RH_IsThereRequest;
					_isPlayerRefueling = [] call RH_IsRefueling;
					if(_isPlayerAirborne && _isClose && _isThereRequest && !_isPlayerRefueling) then
					{
						_plane = [] call RH_GetClosestRefuelingPlane;

						// Check if plane has fuel
						_fuel = _plane getVariable["Fuel", 0];
						
						if(_fuel > 0) then
						{
							// Check if at least one cable is available
							_cables = _plane getVariable["Cables", objNull];
							
							for "_i" from 0 to 1 do
							{
								_cable = _cables select _i select 0;
								_isDamaged = _cables select _i select 1;
								_isOut = _cables select _i select 2;
								_isTransferring = _cables select _i select 3;

								if(!_isDamaged && !_isTransferring) exitWith
								{
									if(!_isOut) then
									{
										// Get cable out
										[_plane, _cable, _i] call RH_GetCableOut;
										_isOut = true;
									};
									_isThereRequest = [] call RH_IsThereRequest;
									if(!_isThereRequest) exitWith { true };
									_isCableClose = [_cable] call RH_IsCableVeryClose;
									if(_isCableClose) then
									{
										[_plane, _cable, _i] call RH_TransferFuel;
									};
								};
							};
						};
					};
				};
			}
			else
			{
				// Player is not in any vehicle
				if(player getVariable["Installed", false]) then
				{
					removeAllActions player;
					player setVariable["RefuelRequested", nil];
					player setVariable["Refueling", nil];
					player setVariable["Installed", false];
					// debug
					//hint "Uninstalled";
				};
			};
		};
		sleep 1;
	};
};