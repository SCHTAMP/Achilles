/*
	Adds (or removes) a set of objects to all of the curator modules that are active.
	
	Parameters:
		0 - Array - The set of objects to add or remove from curator control.
		1 - Boolean - True to add the objects to curator control, false to remove them from curator control. Default is True.
		2 - Boolean - True to also consider simple objects. Default is True.
*/

private _unitsToModify = param [0, [], [[]]];
private _addToCurator = param [1, true, [true]];
private _includeSimpleObjects = param [2, false, [false]];

if (isNil "Ares_addUnitsToCurator_server") then
{
	Ares_addUnitsToCurator_server =
	{
		if (_this select 1) then
		{
			{ _x addCuratorEditableObjects [(_this select 0), true]; } foreach allCurators;
		}
		else
		{
			{ _x removeCuratorEditableObjects [(_this select 0), true]; } foreach allCurators;
		};
	};
	publicVariableServer "Ares_addUnitsToCurator_server";
};

private _simpleObjects = _unitsToModify select {isSimpleObject _x};
_unitsToModify = _unitsToModify - _simpleObjects;

[_unitsToModify, _addToCurator] remoteExec ["Ares_addUnitsToCurator_server", 2];

// handle simple objects
if (_includeSimpleObjects and {count _simpleObjects > 0}) then
{
	private ["_object", "_logic","_logic_list","_logic_group","_pos", "_displayName","_str_content"];
	
	if (_addToCurator) then
	{
		_simpleObjects = _simpleObjects select {isNull (_x getVariable ["master", objNull])};
		if (count _simpleObjects == 0) exitWith {};
		
		_logic_list = [];
		_logic_group = createGroup sideLogic;
		_logic_group deleteGroupWhenEmpty true;
		
		{
			_object = _x;
			_pos = position _object;
			_pos = if (surfaceIsWater _pos) then {getPosASL _object} else {getPosATL _object};
			
			_logic = _logic_group createUnit ["module_f", _pos, [], 0, "CAN_COLLIDE"];
			_logic setVectorDirAndUp [vectorDir _object, vectorUp _object];
			waitUntil {direction _logic - direction _object < 0.01 or {isNull _logic}};
			_object attachTo [_logic];
			
			_logic_list pushBack _logic;
		} forEach _simpleObjects;
		
		// critical delay for proper name setting of game logics
		waitUntil {{name _x != "" and {not isNull _x}} count _logic_list == 0};
		private _allocation_error_cases = 0;
		for "_i" from 0 to (count _simpleObjects - 1) do
		{
			_object = _simpleObjects select _i;
			_logic = _logic_list select _i;
			
			if (not isNull _logic) then
			{
				_str_content = (str _object) splitString " ";
				_displayName = _str_content select (count _str_content - 1);
				[_logic, _displayName] remoteExecCall ["setName", 0, _logic];
			} else
			{
				_allocation_error_cases = _allocation_error_cases + 1;
			};
		};
		if (_allocation_error_cases > 0) then {hint format ["Allocation error: Could not create reference logic for simple object! (occured in %1/%2 cases)", _allocation_error_cases, count _logic_list]};
		
		[_logic_list, true] remoteExec ["Ares_addUnitsToCurator_server", 2];
	} else
	{
		{
			_object = _x;
			_logic = attachedTo _object;
			if (not isNull _logic) then
			{
				detach _object;
				deleteVehicle _logic;
			};
		} forEach _simpleObjects;
	};
};


true