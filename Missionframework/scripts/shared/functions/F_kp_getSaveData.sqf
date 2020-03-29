/*
    File: F_kp_getSaveData.sqf
    Author: KP Liberation Dev Team - https://github.com/KillahPotatoes
    Date: 2020-03-29
    Last Update: 2020-03-29
    License: MIT License - http://www.opensource.org/licenses/MIT

    Description:
        Gather current session data for saving.

    Parameter(s):
        NONE

    Returns:
        Save data [ARRAY]
*/

private _objectsToSave = [];
private _resourceStorages = [];
private _aiGroups = [];

private _allObjects = [];
private _allStorages = [];
private _allMines = [];

// Get all blufor groups
private _allBlueGroups = allGroups select {
    (side _x == GRLIB_side_friendly) &&                 // Only blufor groups
    {isNull objectParent (leader _x)} &&                // Make sure it's an infantry group
    {!(((units _x) select {alive _x}) isEqualTo [])}    // At least one unit has to be alive
};

// Fetch all objects and AI groups near each FOB
{
    private _fobPos = _x;
    private _fobObjects = (_fobPos nearobjects (GRLIB_fob_range * 2)) select {
        ((typeof _x) in _classnamesToSave) &&                       // Exclude classnames which are not in the presets
        {alive _x} &&                                               // Exclude dead or broken objects
        {getObjectType _x >= 8} &&                                  // Exclude preplaced terrain objects
        {speed _x < 5} &&                                           // Exclude moving objects (like civilians driving through)
        {isNull attachedTo _x} &&                                   // Exclude attachTo'd objects
        {((getpos _x) select 2) < 10} &&                            // Exclude hovering helicopters and the like
        {!(_x getVariable ["KP_liberation_edenObject", false])} &&  // Exclude all objects placed via editor in mission.sqm
        {!(_x getVariable ["KP_liberation_preplaced", false])} &&   // Exclude preplaced (e.g. little birds from carrier)
        {!((typeOf _x) in KP_liberation_crates)}                    // Exclude storage crates (those are handled separately)
    };

    _allObjects = _allObjects + (_fobObjects select {!((typeOf _x) in KP_liberation_storage_buildings)});
    _allStorages = _allStorages + (_fobObjects select {(_x getVariable ["KP_liberation_storage_type",-1]) == 0});

    // Process all groups near this FOB
    {
        // Get only living AI units of the group
        private _grpUnits = (units _x) select {!(isPlayer _x) && (alive _x)};
        // Add to save array
        _aiGroups pushBack [getPosATL (leader _x), (_grpUnits apply {typeOf _x})];
    } forEach (_allBlueGroups select {(_fobPos distance2D (leader _x)) < (GRLIB_fob_range * 2)});

    // Save all mines around FOB
    private _fobMines = allMines inAreaArray [_fobPos, GRLIB_fob_range * 2, GRLIB_fob_range * 2];
    _allMines append (_fobMines apply {[
        getPosWorld _x,
        [vectorDirVisual _x, vectorUpVisual _x],
        typeOf _x,
        _x mineDetectedBy GRLIB_side_friendly
    ]});
} forEach GRLIB_all_fobs;

// Save all fetched objects
{
    // Position data
    private _savedpos = getPosWorld _x;
    private _savedvecdir = vectorDirVisual _x;
    private _savedvecup = vectorUpVisual _x;
    private _class = typeOf _x;
    private _hascrew = false;

    // Determine if vehicle is crewed
    if (_class in _bluforClassnames) then {
        if (({!isPlayer _x} count (crew _x) ) > 0) then {
            _hascrew = true;
        };
    };

    // Add to saving when not a civilian vehicle or listed in the seized civilian vehicles array
    if (!(_class in civilian_vehicles) || {_x in KP_liberation_cr_vehicles}) then {
        _objectsToSave pushBack [_class,_savedpos,_savedvecdir,_savedvecup,_hascrew];
    };
} forEach _allObjects;

// Save all storages and resources
{
    // Position data
    private _savedpos = getPosWorld _x;
    private _savedvecdir = vectorDirVisual _x;
    private _savedvecup = vectorUpVisual _x;
    private _class = typeof _x;

    // Resource variables
    private _supplyValue = 0;
    private _ammoValue = 0;
    private _fuelValue = 0;

    // Sum all stored resources of current storage
    {
        switch ((typeOf _x)) do {
            case KP_liberation_supply_crate: {_supplyValue = _supplyValue + (_x getVariable ["KP_liberation_crate_value",0]);};
            case KP_liberation_ammo_crate: {_ammoValue = _ammoValue + (_x getVariable ["KP_liberation_crate_value",0]);};
            case KP_liberation_fuel_crate: {_fuelValue = _fuelValue + (_x getVariable ["KP_liberation_crate_value",0]);};
            default {diag_log format ["[KP LIBERATION] [ERROR] Invalid object (%1) at storage area", (typeOf _x)];};
        };
    } forEach (attachedObjects _x);

    // Add to saving with corresponding resource values
    _resourceStorages pushBack [_class,_savedpos,_savedvecdir,_savedvecup,_supplyValue,_ammoValue,_fuelValue];
} forEach _allStorages;

// Pack all stats in one array
private _stats = [
    stats_ammo_produced,
    stats_ammo_spent,
    stats_blufor_soldiers_killed,
    stats_blufor_soldiers_recruited,
    stats_blufor_teamkills,
    stats_blufor_vehicles_built,
    stats_blufor_vehicles_killed,
    stats_civilian_buildings_destroyed,
    stats_civilian_vehicles_killed,
    stats_civilian_vehicles_killed_by_players,
    stats_civilian_vehicles_seized,
    stats_civilians_healed,
    stats_civilians_killed,
    stats_civilians_killed_by_players,
    stats_fobs_built,
    stats_fobs_lost,
    stats_fuel_produced,
    stats_fuel_spent,
    stats_hostile_battlegroups,
    stats_ieds_detonated,
    stats_opfor_killed_by_players,
    stats_opfor_soldiers_killed,
    stats_opfor_vehicles_killed,
    stats_opfor_vehicles_killed_by_players,
    stats_player_deaths,
    stats_playtime,
    stats_prisoners_captured,
    stats_readiness_earned,
    stats_reinforcements_called,
    stats_resistance_killed,
    stats_resistance_teamkills,
    stats_resistance_teamkills_by_players,
    stats_secondary_objectives,
    stats_sectors_liberated,
    stats_sectors_lost,
    stats_spartan_respawns,
    stats_supplies_produced,
    stats_supplies_spent,
    stats_vehicles_recycled
];

// Pack the weights in one array
private _weights = [
    infantry_weight,
    armor_weight,
    air_weight
];

// Pack the save data in the save array
[
    kp_liberation_version,
    date,
    _objectsToSave,
    _resourceStorages,
    _stats,
    _weights,
    _aiGroups,
    blufor_sectors,
    combat_readiness,
    GRLIB_all_fobs,
    GRLIB_permissions,
    GRLIB_vehicle_to_military_base_links,
    KP_liberation_civ_rep,
    KP_liberation_clearances,
    KP_liberation_guerilla_strength,
    KP_liberation_logistics,
    KP_liberation_production,
    KP_liberation_production_markers,
    resources_intel,
    _allMines
] // return
