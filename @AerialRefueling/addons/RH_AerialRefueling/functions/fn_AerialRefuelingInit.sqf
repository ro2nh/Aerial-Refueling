/*
Disabled for testing purposes

_MAX_FUEL = 100;
_MAX_CABLE_LENGTH = 20;

// Refueling plane attritubes
_fuel = 0;
_isInUse = false;
_isAI = false;
_isAirborne = false;
_isDeployed = false;
_isConnected = false;
_isRefueling = false;

RH_PILOT_STATES = [
	"BEFORE_REQUEST",
	"REQUESTED",
	"CONNECTED",
	"REFUELING"
];

RH_REFUELING_SUPPORTED_VEHICLES = [
	"type1",
	"type2",
	"type3"
];

_players = [];

// Player actions
RH_AddPlayerRefuelingActions = 
{
};

RH_ClearPlayerRefuelingActions = 
{
};

// Radio transmittion
RH_RadioTransmit =
{
};

// Starting point
if(!isDedicated) then
{
	// Not a server
	[] spawn
	{
		while { true } do
		{
			if(!isNull player && isPlayer player) then
			{
				// Installation
				if!(player getVariable["VarsAquired", false]) then
				{
					_players pushBack [player, RH_PILOT_STATES select 0];
					player setVariable["VarsAquired", true];
				};
				
				if(vehicle player != player) then
				{
					// Player is in vehicle
					if!(player getVariable["Refueling_Actions_Loaded", false]) then
					{
						//hint typeOf vehicle player;
						if(typeOf vehicle player in RH_REFUELING_SUPPORTED_VEHICLES)
						{
							// Player in supported vehicle
							if(_players select 0 select 1 == RH_PILOT_STATES select 0) then
							{
								//RH_AddPlayerRefuelingActions
							};
							
						};
					};
				}
				else
				{
					// Player is not in any vehicle
					if(player getVariable["Refueling_Actions_Loaded", false]) then
					{
						//
						player setVariable["Refueling_Actions_Loaded", false];
					};
				};
			};
			sleep 1;
		};
	};
};

if(isServer) then
{
	// A Server
};

*/