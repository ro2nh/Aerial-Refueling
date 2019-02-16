class CfgPatches
{
    class RH_AerialRefueling
    {
        name = "Aerial Refueling";
        author = "Ron.H";

        requiredVersion = 1.0;
        requiredAddons[] = {"A3_Modules_F", "A3_Data_F"};

        units[] = {};
    };
};

class CfgVehicles
{
    class All;
    
    class Rope: All
    {
        model = "\RH_AerialRefueling\proxies\Rope\rope.p3d";
    };
};

class CfgNonAIVehicles
{
    class RopeSegment
    {
        model = "\RH_AerialRefueling\proxies\Rope\rope.p3d";
    };

    class RopeEnd: RopeSegment
    {
        model = "\A3\Data_f\Hook\Hook_F.p3d";
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