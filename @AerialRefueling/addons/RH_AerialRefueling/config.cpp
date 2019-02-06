class CfgPatches
{
    class RH_AerialRefueling
    {
        name = "Aerial Refueling";
        author = "Ron.H";

        requiredVersion = 1.0;
        requiredAddons[] = {"A3_Modules_F"};

        units[] = {};
    };
};

class CfgFunctions
{
    class RH
    {
        class AerialRefueling
        {
            file = "\RH_AerialRefueling\functions";
            class AerialRefuelingInit
            {
                postInit = 1;
            };
        };
    };
};