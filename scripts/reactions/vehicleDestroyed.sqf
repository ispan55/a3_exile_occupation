// SC_liveVehicles = count of vehicle
// SC_liveVehiclesArray = array of active vehicles

_vehicle = _this select 0;
_vehicle removeAllMPEventHandlers  "mphit";
_vehicle removeAllMPEventHandlers  "mpkilled";

if(_vehicle isKindOf "LandVehicle") then
{
    SC_liveVehicles = SC_liveVehicles - 1;
    SC_liveVehiclesArray = SC_liveVehiclesArray - [_vehicle];    
};

if(_vehicle isKindOf "Air") then
{
    SC_liveHelis = SC_liveHelis - 1;
    SC_liveHelisArray = SC_liveHelisArray - [_vehicle];    
};

if(_vehicle isKindOf "Ship") then
{
    SC_liveBoatss = SC_liveBoatss - 1;
    SC_liveBoatsArray = SC_liveBoatsArray - [_vehicle];    
};
