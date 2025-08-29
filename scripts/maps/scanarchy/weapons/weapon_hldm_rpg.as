#include "sca_rpg_rocket"

namespace HLDMRPG {

enum rpg_e {
	RPG_IDLE = 0,
	RPG_FIDGET,
	RPG_RELOAD,		// to reload
	RPG_FIRE2,		// to empty
	RPG_HOLSTER1,	// loaded
	RPG_DRAW1,		// loaded
	RPG_HOLSTER2,	// unloaded
	RPG_DRAW_UL,	// unloaded
	RPG_IDLE_UL,	// unloaded idle
	RPG_FIDGET_UL,	// unloaded fidget
};

string g_VeeMdl = "models/hlclassic/v_rpg.mdl";

enum eModelsMode {
    kDefaultClassic = 0,
    kBlueShift,
    kOpposingForce
}

int g_eModelsMode = kDefaultClassic;

class CLaserSpot : ScriptBaseEntity
{
	void Spawn( void )
    {
        Precache( );
        pev.movetype = MOVETYPE_NONE;
        pev.solid = SOLID_NOT;

        pev.rendermode = kRenderGlow;
        pev.renderfx = kRenderFxNoDissipation;
        pev.renderamt = 255;
        SetThink( ThinkFunction( DisappearThink ) );
        self.pev.nextthink = g_Engine.time + 0.1f;

        g_EntityFuncs.SetModel(self, "sprites/laserdot.spr");
        g_EntityFuncs.SetOrigin( self, pev.origin );
    };
    
	void Precache( void )
    {
        g_Game.PrecacheModel("sprites/laserdot.spr");
    };
    
    void DisappearThink() {
        if (self.pev.owner is null) {
            g_EntityFuncs.Remove(self);
            return;
        }
        
        CBaseEntity@ pOwner = g_EntityFuncs.Instance(self.pev.owner);
        CRpg@ pRpg = cast<CRpg@>(CastToScriptClass(pOwner));
        if (pRpg is null) {
            g_EntityFuncs.Remove(self);
            return;
        }
        CBasePlayer@ pPlayer = pRpg.m_pPlayer;
        EHandle hActiveItem = pPlayer.m_hActiveItem;
        if (!hActiveItem.IsValid()) {
            @pRpg.m_pSpot = null;
            g_EntityFuncs.Remove(self);
            return;
        }
        CBasePlayerItem@ pItem = cast<CBasePlayerItem@>(hActiveItem.GetEntity());
        CBasePlayerWeapon@ pWeapon = pItem.GetWeaponPtr();
        if (pWeapon is null) {
            @pRpg.m_pSpot = null;
            g_EntityFuncs.Remove(self);
            return;
        }
        if (pWeapon.entindex() != pOwner.entindex()) {
            @pRpg.m_pSpot = null;
            g_EntityFuncs.Remove(self);
            return;
        }
        
        self.pev.nextthink = g_Engine.time + 0.5f;
    }

	int	ObjectCaps( void ) { return FCAP_DONT_SAVE; }
    
	void Suspend( float flSuspendTime )
    {
        pev.effects |= EF_NODRAW;
        
        SetThink( ThinkFunction( Revive ) );
        pev.nextthink = g_Engine.time + flSuspendTime;
    }
	void Revive( void )
    {
        pev.effects &= ~EF_NODRAW;

        SetThink( ThinkFunction( DisappearThink ) );
        self.pev.nextthink = g_Engine.time + 0.5f;
    }
};

CLaserSpot@ UTIL_CreateSpot( edict_t@ _Owner )
{
    CBaseEntity@ pEntity = g_EntityFuncs.Create("sca_rpg_laser_spot", g_vecZero, g_vecZero, false, _Owner);
	//CLaserSpot *pSpot = GetClassPtr( (CLaserSpot *)NULL );

    CLaserSpot@ pSpot = cast<CLaserSpot@>(CastToScriptClass(pEntity));
	//pSpot.Spawn();

	//pSpot.pev.classname = MAKE_STRING("laser_spot");

	return pSpot;
}

class CRpg : ScriptBasePlayerWeaponEntity
{
    CBasePlayer@ m_pPlayer {
		get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
		set { self.m_hPlayer = EHandle(@value); }
	}
    
	bool AddToPlayer(CBasePlayer@ pPlayer) {
		if( !BaseClass.AddToPlayer( pPlayer ) )
			return false;
		
		@m_pPlayer = pPlayer;
		
		NetworkMessage message( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			message.WriteLong( g_ItemRegistry.GetIdForName(self.pev.classname) );
		message.End();
		
		return true;
    }

	void Spawn( void )
    {
        Precache( );

        g_EntityFuncs.SetModel(self, self.GetW_Model("models/hlclassic/w_rpg.mdl"));
        m_fSpotActive = true;

        self.m_iDefaultAmmo = 2;

        self.FallInit();// get ready to fall down.
    }
	void Precache( void )
    {
        BaseClass.Precache();
        self.PrecacheCustomModels();
        
		g_Game.PrecacheGeneric( "sprites/scanarchy/weapon_hldm_rpg.txt" );
        
        g_Game.PrecacheModel("models/hlclassic/w_rpg.mdl");
        g_Game.PrecacheModel(g_VeeMdl);
        g_Game.PrecacheModel("models/hlclassic/p_rpg.mdl");

        //g_SoundSystem.PrecacheSound("items/9mmclip1.wav");

        g_Game.PrecacheOther( "sca_rpg_laser_spot" );
        g_Game.PrecacheOther( "sca_rpg_rocket" );

        g_SoundSystem.PrecacheSound("hlclassic/weapons/rocketfire1.wav");
        g_SoundSystem.PrecacheSound("hlclassic/weapons/glauncher.wav"); // alternative fire sound
        
        g_SoundSystem.PrecacheSound ("hlclassic/weapons/357_cock1.wav"); // gun empty sound
    }
	void Reload( void )
    {
        bool iResult;

        if ( self.m_iClip == 1 )
        {
            // don't bother with any of this if don't need to reload.
            return;
        }

        // because the RPG waits to autoreload when no missiles are active while  the LTD is on, the
        // weapons code is constantly calling into this function, but is often denied because 
        // a) missiles are in flight, but the LTD is on
        // or
        // b) player is totally out of ammo and has nothing to switch to, and should be allowed to
        //    shine the designator around
        //
        // Set the next attack time into the future so that WeaponIdle will get called more often
        // than reload, allowing the RPG LTD to be updated
        
        self.m_flNextPrimaryAttack = g_Engine.time + 0.5;

        if ( pev.iuser4 != 0 && m_fSpotActive )
        {
            // no reloading when there are active missiles tracking the designator.
            // ward off future autoreload attempts by setting next attack time into the future for a bit. 
            return;
        }

        if (m_pSpot !is null && m_fSpotActive)
        {
            m_pSpot.Suspend( 2.1 );
            self.m_flNextSecondaryAttack = g_Engine.time + 2.1;
        }

        if (self.m_iClip == 0)
        {
            iResult = self.DefaultReload( 1, RPG_RELOAD, 2 );
        }

        if (iResult)
        {
            self.m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat ( 10, 15 );
        }
    }
	int iItemSlot( void ) { return 4; }
	bool GetItemInfo(ItemInfo& out _Info)
    {
        _Info.iMaxAmmo1 = 5;
        _Info.iMaxAmmo2 = -1;
        _Info.iAmmo1Drop = 1;
        _Info.iMaxClip = 1;
        _Info.iSlot = 3;
        _Info.iPosition = 4;
        _Info.iFlags = 0;
        _Info.iWeight = 20;
        _Info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);

        return true;
    }

	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;
			
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/357_cock1.wav", 0.8, ATTN_NORM, 0, PITCH_NORM );
		}
		
		return false;
	}

	bool Deploy( )
    {
        if ( self.m_iClip == 0 )
        {
            return self.DefaultDeploy( self.GetV_Model(g_VeeMdl), self.GetP_Model("models/hlclassic/p_rpg.mdl"), RPG_DRAW_UL, "rpg" );
        }

        return self.DefaultDeploy( self.GetV_Model(g_VeeMdl), self.GetP_Model("models/hlclassic/p_rpg.mdl"), RPG_DRAW1, "rpg" );
    }
	bool CanHolster( void )
    {
        if ( m_fSpotActive && pev.iuser4 != 0 )
        {
            // can't put away while guiding a missile.
            return false;
        }

        return true;
    }
	void Holster( int skiplocal = 0 )
    {
        self.m_fInReload = false;// cancel any reload in progress.

        m_pPlayer.m_flNextAttack = g_Engine.time + 0.5;
        // m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat ( 10, 15 );
        self.SendWeaponAnim( RPG_HOLSTER1 );
        if (m_pSpot !is null)
        {
            m_pSpot.self.Killed( null, GIB_NEVER );
            g_EntityFuncs.Remove(m_pSpot.self);
            @m_pSpot = null;
        }
        
        BaseClass.Holster(skiplocal);
    }

	void PrimaryAttack( void )
    {
        if (self.m_iClip != 0)
        {
            m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
            m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;

            self.SendWeaponAnim( RPG_FIRE2 );

            // player "shoot" animation
            m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

            g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle );
            Vector vecSrc = m_pPlayer.GetGunPosition( ) + g_Engine.v_forward * 16 + g_Engine.v_right * 8 + g_Engine.v_up * -8;
            
            SCARPGROCKET::CRpgRocket@ pRocket = SCARPGROCKET::UTIL_CreateRpgRocket( vecSrc, m_pPlayer.pev.v_angle, m_pPlayer, self );

            g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle );// RpgRocket::Create stomps on globals, so remake.
            pRocket.self.pev.velocity = pRocket.self.pev.velocity + g_Engine.v_forward * DotProduct( m_pPlayer.pev.velocity, g_Engine.v_forward );

            // firing RPG no longer turns on the designator. ALT fire is a toggle switch for the LTD.
            // Ken signed up for this as a global change (sjb)

            
            g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/rocketfire1.wav", 0.9, ATTN_NORM );
            g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_ITEM, "hlclassic/weapons/glauncher.wav", 0.7, ATTN_NORM );

            self.m_iClip--;
            //m_pPlayer.m_rgAmmo[m_iPrimaryAmmoType]--;
            
            self.m_flNextPrimaryAttack = g_Engine.time + 1.5;
            self.m_flTimeWeaponIdle = g_Engine.time + 1.5;
            m_pPlayer.pev.punchangle.x -= 5;
        }
        else
        {
            self.PlayEmptySound( );
            self.m_flNextPrimaryAttack = g_Engine.time + 1.5;
        }
        UpdateSpot( );
    }
	void SecondaryAttack( void )
    {
        m_fSpotActive = ! m_fSpotActive;

        if (!m_fSpotActive && m_pSpot !is null)
        {
            m_pSpot.self.Killed( null, GIB_NORMAL );
            g_EntityFuncs.Remove(m_pSpot.self);
            @m_pSpot = null;
        }

        self.m_flNextSecondaryAttack = g_Engine.time + 0.2;
    }
	void WeaponIdle( void )
    {
        UpdateSpot( );

        self.ResetEmptySound( );

        if (self.m_flTimeWeaponIdle > g_Engine.time)
            return;

        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) != 0)
        {
            int iAnim;
            float flRand = Math.RandomFloat(0, 1);
            if (flRand <= 0.75 || m_fSpotActive)
            {
                if ( self.m_iClip == 0 )
                    iAnim = RPG_IDLE_UL;
                else
                    iAnim = RPG_IDLE;

                self.m_flTimeWeaponIdle = g_Engine.time + 90.0 / 15.0;
            }
            else
            {
                if ( self.m_iClip == 0 )
                    iAnim = RPG_FIDGET_UL;
                else
                    iAnim = RPG_FIDGET;

                self.m_flTimeWeaponIdle = g_Engine.time + 3.0;
            }

            self.SendWeaponAnim( iAnim );
        }
        else
        {
            self.m_flTimeWeaponIdle = g_Engine.time + 1;
        }
    }

	void UpdateSpot( void )
    {
        if (m_fSpotActive)
        {
            if (m_pSpot is null)
            {
                @m_pSpot = UTIL_CreateSpot(self.edict());
            }

            g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle );
            Vector vecSrc = m_pPlayer.GetGunPosition( );;
            Vector vecAiming = g_Engine.v_forward;

            TraceResult tr;
            g_Utility.TraceLine ( vecSrc, vecSrc + vecAiming * 8192, dont_ignore_monsters, m_pPlayer.edict(), tr );
            
            // ALERT( "%f %f\n", g_Engine.v_forward.y, vecAiming.y );

            /*
            float a = g_Engine.v_forward.y * vecAiming.y + g_Engine.v_forward.x * vecAiming.x;
            m_pPlayer.pev.punchangle.y = acos( a ) * (180 / M_PI);
            
            ALERT( at_console, "%f\n", a );
            */

            g_EntityFuncs.SetOrigin( m_pSpot.self, tr.vecEndPos );
        }
    }
	bool ShouldWeaponIdle( void ) { return true; };

	CLaserSpot@ m_pSpot;
	bool m_fSpotActive;
	//int m_cActiveRockets;// how many missiles in flight from this launcher right now?

};

void Register() {
    if (g_eModelsMode == kOpposingForce) {
        g_VeeMdl = "models/scanarchy/opfor/v_rpg.mdl";
    } else if (g_eModelsMode == kBlueShift) {
        g_VeeMdl = "models/scanarchy/bshift/v_rpg.mdl";
    }
    
	g_CustomEntityFuncs.RegisterCustomEntity( "SCARPGROCKET::CRpgRocket", "sca_rpg_rocket" );
	g_CustomEntityFuncs.RegisterCustomEntity( "HLDMRPG::CLaserSpot", "sca_rpg_laser_spot" );
	g_CustomEntityFuncs.RegisterCustomEntity( "HLDMRPG::CRpg", "weapon_hldm_rpg" );
	g_ItemRegistry.RegisterWeapon( "weapon_hldm_rpg", "scanarchy", "rockets", "", "ammo_rpgclip", "" );
}

}