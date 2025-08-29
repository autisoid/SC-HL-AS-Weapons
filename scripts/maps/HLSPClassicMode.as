/*
* This script implements HLSP specific Classic Mode features
*/

#include "scanarchy/weapons/weapons"
#include "scanarchy/Footsteps"
#include "scanarchy/BaseDeadPlayer"

array<ItemMapping@> g_ItemMappings = { ItemMapping("weapon_rpg", "weapon_hldm_rpg"), ItemMapping("weapon_tripmine", "weapon_hldm_tripmine"), ItemMapping("weapon_satchel", "weapon_hldm_satchelcharge"), ItemMapping("weapon_displacer", "weapon_hlopfor_displacer"), ItemMapping("weapon_grapple", "weapon_hlopfor_grapple"), ItemMapping("weapon_snark", "weapon_hldm_squeakgrenade"), ItemMapping("weapon_sporelauncher", "weapon_hlopfor_sporelauncher"),ItemMapping("weapon_m249", "weapon_hlopfor_m249"), ItemMapping("weapon_eagle", "weapon_hlopfor_deagle"), ItemMapping("weapon_sniperrifle", "weapon_hlopfor_sniperrifle"), ItemMapping("weapon_crossbow", "weapon_hldm_xbow"), ItemMapping("weapon_pipewrench", "weapon_hlopfor_pipewrench"), ItemMapping("weapon_medkit", "weapon_sc_medkit"), ItemMapping("weapon_handgrenade", "weapon_hldm_handgrenade"), ItemMapping("weapon_357", "weapon_hldm_357"), ItemMapping( "weapon_m16", "weapon_hldm_9mmAR" ), ItemMapping("weapon_9mmhandgun", "weapon_hldm_glock"), ItemMapping("weapon_glock", "weapon_hldm_glock"), ItemMapping( "weapon_9mmAR", "weapon_hldm_9mmAR" ), ItemMapping( "weapon_mp5", "weapon_hldm_9mmAR" ), ItemMapping("weapon_gauss", "weapon_hldm_gauss"), ItemMapping("weapon_egon", "weapon_hldm_egon"), ItemMapping("weapon_hornetgun", "weapon_hldm_hornetgun"), ItemMapping("weapon_shotgun", "weapon_hldm_shotgun"), ItemMapping("weapon_crowbar", "weapon_hldm_crowbar") };

array<ItemMapping@> g_ItemMappingsOpFor = { ItemMapping("weapon_rpg", "weapon_hldm_rpg"), ItemMapping("weapon_tripmine", "weapon_hldm_tripmine"), ItemMapping("weapon_satchel", "weapon_hldm_satchelcharge"), ItemMapping("weapon_displacer", "weapon_hlopfor_displacer"), ItemMapping("weapon_grapple", "weapon_hlopfor_grapple"), ItemMapping("weapon_snark", "weapon_hldm_squeakgrenade"), ItemMapping("weapon_sporelauncher", "weapon_hlopfor_sporelauncher"),ItemMapping("weapon_m249", "weapon_hlopfor_m249"), ItemMapping("weapon_eagle", "weapon_hlopfor_deagle"), ItemMapping("weapon_sniperrifle", "weapon_hlopfor_sniperrifle"), ItemMapping("weapon_crossbow", "weapon_hldm_xbow"), ItemMapping("weapon_pipewrench", "weapon_hlopfor_pipewrench"), ItemMapping("weapon_medkit", "weapon_sc_medkit"), ItemMapping("weapon_handgrenade", "weapon_hldm_handgrenade"), ItemMapping("weapon_357", "weapon_hldm_357"), ItemMapping( "weapon_m16", "weapon_hldm_9mmAR" ), ItemMapping("weapon_9mmhandgun", "weapon_hldm_glock"), ItemMapping("weapon_glock", "weapon_hldm_glock"), ItemMapping( "weapon_9mmAR", "weapon_hldm_9mmAR" ), ItemMapping( "weapon_mp5", "weapon_hldm_9mmAR" ), ItemMapping("weapon_gauss", "weapon_hldm_gauss"), ItemMapping("weapon_egon", "weapon_hldm_egon"), ItemMapping("weapon_hornetgun", "weapon_hldm_hornetgun"), ItemMapping("weapon_shotgun", "weapon_hldm_shotgun"), ItemMapping("weapon_crowbar", "weapon_hlopfor_knife") };


bool ShouldRestartIfClassicModeChangesOn( const string& in szMapName )
{
	return szMapName != "-sp_campaign_portal" && szMapName != "hl_c00";
}

HookReturnCode HOOKED_Collected(CBaseEntity@ _Item, CBaseEntity@ _Player) {
    if (_Item is null || !_Player.IsPlayer()) 
        return HOOK_CONTINUE;
        
    for( uint w = 0; w < g_ItemMappings.length(); w++ ) {
        if( _Item.GetClassname() != g_ItemMappings[w].get_From() || g_ItemMappings[w].get_To() == "" )
            continue;

        CBaseEntity@ pNewItem = g_EntityFuncs.Create( g_ItemMappings[w].get_To(), _Item.pev.origin, _Item.pev.angles, true );

        if( pNewItem is null ) 
            continue;

        pNewItem.pev.spawnflags = _Item.pev.spawnflags;
        pNewItem.pev.movetype = _Item.pev.movetype;
        pNewItem.pev.rendermode = pNewItem.m_iOriginalRenderMode = _Item.m_iOriginalRenderMode;
        pNewItem.pev.renderfx = pNewItem.m_iOriginalRenderFX = _Item.m_iOriginalRenderFX;
        pNewItem.pev.renderamt = pNewItem.m_flOriginalRenderAmount = _Item.m_flOriginalRenderAmount;
        pNewItem.pev.rendercolor = pNewItem.m_vecOriginalRenderColor = _Item.m_vecOriginalRenderColor;

        if( _Item.GetTargetname() != "" )
            pNewItem.pev.targetname = _Item.GetTargetname();

        if( _Item.pev.target != "" )
            pNewItem.pev.target = _Item.pev.target;

        if( _Item.pev.netname != "" )
            pNewItem.pev.netname = _Item.pev.netname;

        CBasePlayerWeapon@
            pOldWeapon = cast<CBasePlayerWeapon@>( _Item ), 
            pNewWeapon = cast<CBasePlayerWeapon@>( pNewItem );

        if( pOldWeapon !is null && pNewWeapon !is null )
        {
            pNewWeapon.m_flDelay = pOldWeapon.m_flDelay;
            pNewWeapon.m_bExclusiveHold = pOldWeapon.m_bExclusiveHold;

            if( pOldWeapon.m_iszKillTarget != "" )
                pNewWeapon.m_iszKillTarget = pOldWeapon.m_iszKillTarget;
        }

        if( g_EntityFuncs.DispatchSpawn( pNewItem.edict() ) < 0 )
            continue;
            
        CBasePlayer@ pPlayer = cast<CBasePlayer@>(_Player);
            
        //pPlayer.m_rgAmmo(pNewWeapon.PrimaryAmmoIndex(), pPlayer.m_rgAmmo(pNewWeapon.PrimaryAmmoIndex()) + pPlayer.m_rgAmmo(pOldWeapon.PrimaryAmmoIndex()));
        //pPlayer.m_rgAmmo(pNewWeapon.SecondaryAmmoIndex(), pPlayer.m_rgAmmo(pNewWeapon.SecondaryAmmoIndex()) + pPlayer.m_rgAmmo(pOldWeapon.SecondaryAmmoIndex()));
        //pPlayer.RemoveExcessAmmo(pNewWeapon.PrimaryAmmoIndex());
        //pPlayer.RemoveExcessAmmo(pNewWeapon.SecondaryAmmoIndex());

        g_EntityFuncs.Remove( _Item );
    }

    return HOOK_CONTINUE;
}

HookReturnCode SwapItem(CBaseEntity@ pOldItem) {
    if( pOldItem is null ) 
        return HOOK_CONTINUE;
        
    //g_Log.PrintF("Attempting to swap " + pOldItem.GetClassname() + "\n");

    for( uint w = 0; w < g_ItemMappings.length(); w++ ) {
        if( pOldItem.GetClassname() != g_ItemMappings[w].get_From() || g_ItemMappings[w].get_To() == "" )
            continue;

        CBaseEntity@ pNewItem = g_EntityFuncs.Create( g_ItemMappings[w].get_To(), pOldItem.pev.origin, pOldItem.pev.angles, true );

        if( pNewItem is null ) 
            continue;

        pNewItem.pev.spawnflags = pOldItem.pev.spawnflags;
        pNewItem.pev.movetype = pOldItem.pev.movetype;
        pNewItem.pev.rendermode = pNewItem.m_iOriginalRenderMode = pOldItem.m_iOriginalRenderMode;
        pNewItem.pev.renderfx = pNewItem.m_iOriginalRenderFX = pOldItem.m_iOriginalRenderFX;
        pNewItem.pev.renderamt = pNewItem.m_flOriginalRenderAmount = pOldItem.m_flOriginalRenderAmount;
        pNewItem.pev.rendercolor = pNewItem.m_vecOriginalRenderColor = pOldItem.m_vecOriginalRenderColor;

        if( pOldItem.GetTargetname() != "" )
            pNewItem.pev.targetname = pOldItem.GetTargetname();

        if( pOldItem.pev.target != "" )
            pNewItem.pev.target = pOldItem.pev.target;

        if( pOldItem.pev.netname != "" )
            pNewItem.pev.netname = pOldItem.pev.netname;

        CBasePlayerWeapon@
            pOldWeapon = cast<CBasePlayerWeapon@>( pOldItem ), 
            pNewWeapon = cast<CBasePlayerWeapon@>( pNewItem );

        if( pOldWeapon !is null && pNewWeapon !is null )
        {
            pNewWeapon.m_flDelay = pOldWeapon.m_flDelay;
            pNewWeapon.m_bExclusiveHold = pOldWeapon.m_bExclusiveHold;

            if( pOldWeapon.m_iszKillTarget != "" )
                pNewWeapon.m_iszKillTarget = pOldWeapon.m_iszKillTarget;
        }

        if( g_EntityFuncs.DispatchSpawn( pNewItem.edict() ) < 0 )
            continue;

        g_EntityFuncs.Remove( pOldItem );
    }
        
    return HOOK_CONTINUE;
}

void ClassicModeMapInit()
{
    string szMapName = string(g_Engine.mapname);
    if (szMapName.Find("of") == 0) {
        g_eModelsMode = kOpposingForce;
    } else if (szMapName.Find("ba") == 0) {
        g_eModelsMode = kBlueShift;
    } else {
        g_eModelsMode = kDefaultClassic;
    }
    RegisterHLDMWeapons();
    if (szMapName.Find("of") == 0) {
        g_ClassicMode.SetItemMappings( @g_ItemMappingsOpFor );
    } else {
        g_ClassicMode.SetItemMappings( @g_ItemMappings );
    }
    g_ClassicMode.ForceItemRemap( g_Hooks.RegisterHook( Hooks::PickupObject::Materialize, SwapItem ) && g_Hooks.RegisterHook( Hooks::PickupObject::Collected, HOOKED_Collected ) );
    InitialiseFootsteps();
    SCADEADPLAYER::Register();

	//We want classic mode voting to be enabled here
	g_ClassicMode.EnableMapSupport();
	
	if( !ShouldRestartIfClassicModeChangesOn( g_Engine.mapname ) )
		g_ClassicMode.SetShouldRestartOnChange( false );
}

void ClassicModeMapStart()
{
}

/*
* This is the function to use with trigger_script: triggering it will start classic mode. If the map is not hl_c00, the map is restarted
*/
void StartClassicModeVote( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
{
	//Don't force the vote; only start if needed
	StartClassicModeVote( false );
}

void StartClassicModeVote( const bool bForce )
{
	if( !bForce && g_ClassicMode.IsStateDefined() )
		return;
		
	float flVoteTime = g_EngineFuncs.CVarGetFloat( "mp_votetimecheck" );
	
	if( flVoteTime <= 0 )
		flVoteTime = 16;
		
	float flPercentage = g_EngineFuncs.CVarGetFloat( "mp_voteclassicmoderequired" );
	
	if( flPercentage <= 0 )
		flPercentage = 51;
		
	Vote vote( "HLSP Classic Mode vote", ( g_ClassicMode.IsEnabled() ? "Disable" : "Enable" ) + " Classic Mode?", flVoteTime, flPercentage );
	
	vote.SetVoteBlockedCallback( @ClassicModeVoteBlocked );
	vote.SetVoteEndCallback( @ClassicModeVoteEnd );
	
	vote.Start();
}

void ClassicModeVoteBlocked( Vote@ pVote, float flTime )
{
	// Voting is blocked at the moment (another vote in progress...).
	// Try again later.
	
	// The 3rd argument will be passed to the scheduled function.
	g_Scheduler.SetTimeout( "StartClassicModeVote", flTime, false );
}

void ClassicModeVoteEnd( Vote@ pVote, bool bResult, int iVoters )
{
	if( !bResult )
	{
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTNOTIFY, "Vote for Classic Mode failed" );
		return;
	}
	
	g_PlayerFuncs.ClientPrintAll( HUD_PRINTNOTIFY, "Vote to " + ( !g_ClassicMode.IsEnabled() ? "Enable" : "Disable" ) + " Classic mode passed\n" );
	
	g_ClassicMode.Toggle();
}

//Leave this out of release builds!
CConCommand g_ClassicModeVote( "debug_classicmodevote", "Debug only: starts the Classic Mode vote", @ClassicModeVoteCallback );

void ClassicModeVoteCallback( const CCommand@ pArgs )
{
	StartClassicModeVote( false );
}
