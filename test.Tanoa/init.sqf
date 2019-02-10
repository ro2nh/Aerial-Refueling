// For getting vehicles type: hint typeOf vehicle player
RH_REFUELING_SUPPORTED_VEHICLES = [
	"I_C_Plane_Civil_01_F"
];

RH_REFUELING_PLANES_TYPES = [
	"B_T_VTOL_01_armed_F"
];

MAX_MAP_DISTANCE = 7000;
DISTANCE_TO_REQUEST = 1000;
DISTANCE_TO_CABLE = 10;

MAX_CABLE_LENGTH = 30;
CABLE_WIND_SPEED = 5;

REFUELING_SPEED = 0.1; // percent per second
MAX_FUEL_CAPACITY = 5;

Planes = [];
//debug
Planes pushBack ("B_T_VTOL_01_armed_F" createVehicle [12194.7,13068.8,5.84077]);

RH_PlayerAddActions = 
{
	player addAction ["Report Location", {
		[] call RH_ReportPlaneLocation;
	}, nil, 0, false, false, "", "call RH_IsRefuelingPlaneFarAway"];

	player addAction ["Request Refuel", {
		[] call RH_RequestRefuel;
	}, nil, 0, false, true, "", "call RH_IsRefuelingPlaneCloseAndNotRequested"];

	player addAction ["Cancel Request", {
		[] call RH_CancelRequest;
	}, nil, 0, false, true, "", "call RH_IsThereRequest"];

	player addAction ["Disconnect Cable", {
		[] call RH_DisconnectCable;
	}, nil, 0, false, true, "", "call RH_IsRefueling"];
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

RH_DisconnectCable =
{};

// Plane functions
RH_GetCableOut = 
{
	params["_plane, ,_cable, _cableIndex"];

	ropeUnwind [_cable, CABLE_WIND_SPEED, MAX_CABLE_LENGTH];

	// Update 'cables' variable
	_cables = _plane getVariable["Cables"];
	_cable = _cables select _cableIndex;
	_cable set [2, true];
	_cables set [_cableIndex, _cable];
	_plane setVariable["Cables", _cables];
};

RH_TransferFuel =
{
	params ["_plane", "_cable", "_i"];

	[vehicle player, [0, 0, 0], [0, 0, -1]] ropeAttachTo _cable;

	// Update 'cables' variable
	_cables = _plane getVariable["Cables"];
	_cable = _cables select _cableIndex;
	_cable set [3, true];
	_cables set [_cableIndex, _cable];
	_plane setVariable["Cables", _cables];
	
	player setVariable["Refueling", true];

	// Refueling requested vehicle
	//debug
	hint "Refueling";
	while { !_isComplete } do
	{
		//
		//
		//
		sleep 1;
	};
	//
	//
	//
	//
};
//plane1 "Cables" = [[ropeObj, _isDamaged, _isOut, _isTransferring], 

// Validations
RH_IsCableVeryClose = 
{
	params [_cable];
	if(ropeEndPosition _cable distance vehicle player <= DISTANCE_TO_CABLE) exitWith
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

RH_IsRefuelingPlaneCloseAndNotRequested = 
{
	_val = [] call RH_IsRefuelingPlaneClose;
	if(_val) exitWith
	{
		_val = [] call RH_IsThereRequest;
		if(_val) exitWith
		{
			false
		};
		true
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

	//cable1 = ropeCreate [master, [0, 0, 0], 0];
	//ropeUnwind [cable1, 5, MAX_CABLE_LENGTH];
	//[vehicle player, [0, 0, 0], [0, 0, -1]] ropeAttachTo cable1;
	//vehicle player ropeDetach cable1;
	///////
};

// Entry point
[] spawn
{
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
						_fuel = _plane getVariable["Fuel"];
						if(_fuel > 0) then
						{
							// Check if at least one cable is available
							_cables = _plane getVariable["Cables"];
							
							for "_i" from 0 to 1 do
							{
								_cable = _cables select _i select 0;
								_isDamaged = _cables select _i select 1;
								_isOut = _cables select _i select 2;
								_isTransferring = _cables select _i select 3;

								if(!_isDamaged && !_isTransferring) then
								{
									if(!_isOut) then
									{
										// Get cable out
										[_plane,_cable, _i] call RH_GetCableOut;
										_isOut = true;
									};
									_isCableClose = [_cable] call RH_IsCableVeryClose;
									if(_isCableClose) then
									{
										[_plane,_cable, _i] call RH_TransferFuel;
									};
									//exitWith { true };
								};
							};
							
							//plane1 "Cables" = [[ropeObj, _isDamaged, _isOut, _isTransferring], 
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