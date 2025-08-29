/*
* This script implements HLSP survival mode
*/

#include "point_checkpoint"
#include "hlsp/trigger_suitcheck"
#include "HLSPClassicMode"
#include "cubemath/trigger_once_mp"

void MapInit()
{
	RegisterPointCheckPointEntity();
	RegisterTriggerSuitcheckEntity();
	RegisterTriggerOnceMpEntity();
	
	g_EngineFuncs.CVarSetFloat( "mp_hevsuit_voice", 1 );
	
	ClassicModeMapInit();
}

void MapStart() {
    ClassicModeMapStart();
}
