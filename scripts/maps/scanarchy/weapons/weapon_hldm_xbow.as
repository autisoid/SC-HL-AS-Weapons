namespace HLDMXBOW {

const uint BOLT_AIR_VELOCITY = 2000;
const uint BOLT_WATER_VELOCITY = 1000;

string g_VeeMdl = "models/hlclassic/v_crossbow.mdl";

enum eModelsMode {
    kDefaultClassic = 0,
    kBlueShift,
    kOpposingForce
}

int g_eModelsMode = kDefaultClassic;

// UNDONE: Save/restore this?  Don't forget to set classname and LINK_ENTITY_TO_CLASS()
// 
// OVERLOADS SOME ENTVARS:
//
// speed - the ideal magnitude of my velocity
class CHLDMCrossbowBolt : ScriptBaseEntity
{

    void Spawn( )
    {
        Precache( );
        self.pev.movetype = MOVETYPE_FLY;
        self.pev.solid = SOLID_BBOX;

        self.pev.gravity = 0.5;

        g_EntityFuncs.SetModel(self, "models/crossbow_bolt.mdl");

        g_EntityFuncs.SetOrigin(self, self.pev.origin );
        g_EntityFuncs.SetSize(self.pev, g_vecZero, g_vecZero);
        
        @m_pDamage = g_EngineFuncs.CVarGetPointer("sk_plr_xbow_bolt_monster");

        SetTouch( TouchFunction( BoltTouch ) );
        SetThink( ThinkFunction( BubbleThink ) );
        self.pev.nextthink = g_Engine.time + 0.2;
    }


    void Precache( )
    {
        BaseClass.Precache();
        //self.PrecacheCustomModels();
            
        g_Game.PrecacheModel ("models/crossbow_bolt.mdl");
        g_SoundSystem.PrecacheSound("hlclassic/weapons/xbow_hitbod1.wav");
        g_SoundSystem.PrecacheSound("hlclassic/weapons/xbow_hitbod2.wav");
        g_SoundSystem.PrecacheSound("hlclassic/weapons/xbow_fly1.wav");
        g_SoundSystem.PrecacheSound("hlclassic/weapons/xbow_hit1.wav");
        g_SoundSystem.PrecacheSound("fvox/beep.wav");
        m_iTrail = g_Game.PrecacheModel("sprites/streak.spr");
    }


    int	Classify ( void )
    {
        return	CLASS_NONE;
    }

    void BoltTouch( CBaseEntity@ pOther )
    {
        SetTouch( null );
        SetThink( null );
        
        if (self.pev.owner is null) return;

        if (pOther.pev.takedamage != DAMAGE_NO)
        {
            TraceResult tr = g_Utility.GetGlobalTrace( );
            entvars_t@ pevOwner = @self.pev.owner.vars;

            // UNDONE: this needs to call TraceAttack instead
            g_WeaponFuncs.ClearMultiDamage( );

            //if ( pOther.IsPlayer() )
            //{
                pOther.TraceAttack(pevOwner, m_pDamage.value, self.pev.velocity.Normalize(), tr, DMG_NEVERGIB | DMG_POISON ); 
            //}
            //else
            //{
            //	pOther.TraceAttack(pevOwner, gSkillData.plrDmgCrossbowMonster, pev.velocity.Normalize(), tr, DMG_BULLET | DMG_NEVERGIB ); 
            //}

            g_WeaponFuncs.ApplyMultiDamage( self.pev, pevOwner );

            self.pev.velocity = g_vecZero;
            // play body "thwack" sound
            switch( Math.RandomLong(0,1) )
            {
            case 0:
                g_SoundSystem.EmitSound(self.edict(), CHAN_WEAPON, "hlclassic/weapons/xbow_hitbod1.wav", 1, ATTN_NORM); break;
            case 1:
                g_SoundSystem.EmitSound(self.edict(), CHAN_WEAPON, "hlclassic/weapons/xbow_hitbod2.wav", 1, ATTN_NORM); break;
            }

            //self.Killed( self.pev, GIB_NEVER );
            SetThink( ThinkFunction( ExplodeThink ) );
            self.pev.nextthink = g_Engine.time + 0.1;
            return;
        }
        else
        {
            g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_WEAPON, "hlclassic/weapons/xbow_hit1.wav", Math.RandomFloat(0.95, 1.0), ATTN_NORM, 0, 98 + Math.RandomLong(0,7));

            SetThink( ThinkFunction( this._SUB_Remove ) );
            self.pev.nextthink = g_Engine.time;// this will get changed below if the bolt is allowed to stick in what it hit.

            if ( pOther.GetClassname() == "worldspawn" )
            {
                // if what we hit is static architecture, can stay around for a while.
                Vector vecDir = pev.velocity.Normalize( );
                g_EntityFuncs.SetOrigin( self, self.pev.origin - vecDir * 12 );
                g_EngineFuncs.VecToAngles( vecDir, self.pev.angles );
                self.pev.solid = SOLID_NOT;
                self.pev.movetype = MOVETYPE_FLY;
                self.pev.velocity = g_vecZero;
                self.pev.avelocity.z = 0;
                self.pev.angles.z = Math.RandomLong(0,360);
                self.pev.nextthink = g_Engine.time + 10.0;
            }

            if (g_EngineFuncs.PointContents(pev.origin) != CONTENTS_WATER)
            {
                g_Utility.Sparks( self.pev.origin );
            }
        }


        SetThink( ThinkFunction( ExplodeThink ) );
        self.pev.nextthink = g_Engine.time + 0.1;
    }
    
    void _SUB_Remove() {
        self.SUB_Remove();
    }

    void BubbleThink( void )
    {
        self.pev.nextthink = g_Engine.time + 0.1;

        if (self.pev.waterlevel == 0)
            return;

        g_Utility.BubbleTrail( self.pev.origin - self.pev.velocity * 0.1, self.pev.origin, 1 );
    }

    void ExplodeThink( void )
    {
        int iContents = g_EngineFuncs.PointContents ( self.pev.origin );
        int iScale;
        
        self.pev.dmg = 40;
        iScale = 10;

        NetworkMessage explo( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin );
            explo.WriteByte( TE_EXPLOSION);		
            explo.WriteCoord( pev.origin.x );
            explo.WriteCoord( pev.origin.y );
            explo.WriteCoord( pev.origin.z );
            if (iContents != CONTENTS_WATER)
            {
                explo.WriteShort( g_EngineFuncs.ModelIndex("sprites/zerogxplode.spr") );
            }
            else
            {
                explo.WriteShort( g_EngineFuncs.ModelIndex("sprites/WXplo1.spr") );
            }
            explo.WriteByte( iScale  ); // scale * 10
            explo.WriteByte( 15  ); // framerate
            explo.WriteByte( TE_EXPLFLAG_NONE );
        explo.End();

        entvars_t@ pevOwner;

        if ( self.pev.owner !is null)
            @pevOwner = @self.pev.owner.vars;
        else
            @pevOwner = null;

        @self.pev.owner = null; // can't traceline attack owner if this is set

        g_WeaponFuncs.RadiusDamage( self.pev.origin, self.pev, pevOwner, self.pev.dmg, 128, CLASS_NONE, DMG_BLAST | DMG_ALWAYSGIB );

        g_EntityFuncs.Remove(self);
    }

	int m_iTrail;
    const Cvar@ m_pDamage = null;
};

CHLDMCrossbowBolt@ UTIL_BoltCreate() {
    CBaseEntity@ pTheBolt = g_EntityFuncs.CreateEntity("hldm_crossbow_bolt", null, false);
	CHLDMCrossbowBolt@ pBolt = cast<CHLDMCrossbowBolt@>(CastToScriptClass(pTheBolt));
    pBolt.Spawn();
    
    return pBolt;
}

enum crossbow_e {
	CROSSBOW_IDLE1 = 0,	// full
	CROSSBOW_IDLE2,		// empty
	CROSSBOW_FIDGET1,	// full
	CROSSBOW_FIDGET2,	// empty
	CROSSBOW_FIRE1,		// full
	CROSSBOW_FIRE2,		// reload
	CROSSBOW_FIRE3,		// empty
	CROSSBOW_RELOAD,	// from empty
	CROSSBOW_DRAW1,		// full
	CROSSBOW_DRAW2,		// empty
	CROSSBOW_HOLSTER1,	// full
	CROSSBOW_HOLSTER2,	// empty
};


class CHLDMCrossbow : ScriptBasePlayerWeaponEntity {
	bool m_fInZoom; // don't save this

	private CBasePlayer@ m_pPlayer
	{
		get const 	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set       	{ self.m_hPlayer = EHandle( @value ); }
	}

    void Spawn( )
    {
        Precache( );
        g_EntityFuncs.SetModel(self, self.GetW_Model("models/hlclassic/w_crossbow.mdl"));

        self.m_iDefaultAmmo = 5;//CROSSBOW_DEFAULT_GIVE;

        self.FallInit();// get ready to fall down.
    }
    
    bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1		= 50;
		info.iMaxAmmo2		= -1;
        info.iAmmo2Drop     = -1;
		info.iMaxClip		= 5;
		info.iSlot			= 2;
		info.iPosition		= 6;
		info.iWeight		= 10;
        info.iAmmo1Drop    = 5;
        info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);
        
		return true;
	}
    
	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer( pPlayer ) )
			return false;
		
		@m_pPlayer = pPlayer;
		
		NetworkMessage message( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			message.WriteLong( g_ItemRegistry.GetIdForName(self.pev.classname) );
		message.End();
		
		return true;
	}
    
    void Precache( void )
    {
        BaseClass.Precache();
        self.PrecacheCustomModels();
        
        g_Game.PrecacheGeneric( "sprites/scanarchy/weapon_hldm_xbow.txt" );
        
        g_Game.PrecacheModel("models/hlclassic/w_crossbow.mdl");
        g_Game.PrecacheModel(g_VeeMdl);
        g_Game.PrecacheModel("models/hlclassic/p_crossbow.mdl");

        g_SoundSystem.PrecacheSound("hlclassic/weapons/xbow_fire1.wav");
        g_SoundSystem.PrecacheSound("hlclassic/weapons/xbow_reload1.wav");
        g_SoundSystem.PrecacheSound("hlclassic/weapons/xbow_hitbod1.wav");
        g_SoundSystem.PrecacheSound("hlclassic/weapons/xbow_hitbod2.wav");
        g_SoundSystem.PrecacheSound("hlclassic/weapons/xbow_fly1.wav");
        g_SoundSystem.PrecacheSound("hlclassic/weapons/357_cock1.wav");

        g_Game.PrecacheOther( "hldm_crossbow_bolt" );
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
        if (self.m_iClip != 0)
            return self.DefaultDeploy( self.GetV_Model(g_VeeMdl), self.GetP_Model("models/hlclassic/p_crossbow.mdl"), CROSSBOW_DRAW1, "bow" );
        return self.DefaultDeploy( self.GetV_Model(g_VeeMdl), self.GetP_Model("models/hlclassic/p_crossbow.mdl"), CROSSBOW_DRAW2, "bow" );
    }

    void Holster( int iSkipLocal = 0 )
    {
        self.m_fInReload = false;// cancel any reload in progress.

        if ( m_fInZoom )
        {
            SecondaryAttack( );
        }

        m_pPlayer.m_flNextAttack = g_Engine.time + 0.5;
        if (self.m_iClip != 0)
            self.SendWeaponAnim( CROSSBOW_HOLSTER1 );
        else
            self.SendWeaponAnim( CROSSBOW_HOLSTER2 );
    }

    void PrimaryAttack( void )
    {
        if ( m_fInZoom ) //multiplayer only
        {
            FireSniperBolt();
            return;
        }

        FireBolt();
    }

    // this function only gets called in multiplayer
    void FireSniperBolt()
    {
        self.m_flNextPrimaryAttack = g_Engine.time + 0.75;

        if (self.m_iClip == 0)
        {
            self.PlayEmptySound( );
            return;
        }

        TraceResult tr;

        m_pPlayer.m_iWeaponVolume = QUIET_GUN_VOLUME;
        self.m_iClip--;

        // make twang sound
        g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/xbow_fire1.wav", Math.RandomFloat(0.95, 1.0), ATTN_NORM, 0, 93 + Math.RandomLong(0,0xF));

        if (self.m_iClip != 0)
        {
            g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_ITEM, "hlclassic/weapons/xbow_reload1.wav", Math.RandomFloat(0.95, 1.0), ATTN_NORM, 0, 93 + Math.RandomLong(0,0xF));
            self.SendWeaponAnim( CROSSBOW_FIRE1 );
        }
        else if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0)
        {
            self.SendWeaponAnim( CROSSBOW_FIRE3 );
        }

        // player "shoot" animation
        m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
        
        Vector anglesAim = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;
        g_EngineFuncs.MakeVectors( anglesAim );
        Vector vecSrc = m_pPlayer.GetGunPosition( ) - g_Engine.v_up * 2;
        Vector vecDir = g_Engine.v_forward;

        g_Utility.TraceLine(vecSrc, vecSrc + vecDir * 8192, dont_ignore_monsters, m_pPlayer.edict(), tr);
        
        if ( tr.pHit is null ) return;
        
        CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );

        if ( pHit.pev.takedamage != DAMAGE_NO )
        {
            switch( Math.RandomLong(0,1) )
            {
            case 0:
                g_SoundSystem.EmitSound( pHit.edict(), CHAN_BODY, "hlclassic/weapons/xbow_hitbod1.wav", 1, ATTN_NORM); break;
            case 1:
                g_SoundSystem.EmitSound( pHit.edict(), CHAN_BODY, "hlclassic/weapons/xbow_hitbod2.wav", 1, ATTN_NORM); break;
            }

            g_WeaponFuncs.ClearMultiDamage( );
            pHit.TraceAttack(m_pPlayer.pev, 120, vecDir, tr, DMG_BULLET | DMG_NEVERGIB | DMG_POISON ); 
            g_WeaponFuncs.ApplyMultiDamage( self.pev, m_pPlayer.pev );
        }
        else
        {
            // create a bolt
            CHLDMCrossbowBolt@ pBolt = UTIL_BoltCreate();
            pBolt.pev.origin = tr.vecEndPos - vecDir * 10;
            g_EngineFuncs.VecToAngles( vecDir, pBolt.pev.angles );
            pBolt.pev.solid = SOLID_NOT;
            pBolt.SetTouch( null );
            pBolt.SetThink( ThinkFunction( pBolt._SUB_Remove ) );

            g_SoundSystem.EmitSound( pBolt.self.edict(), CHAN_WEAPON, "hlclassic/weapons/xbow_hit1.wav", Math.RandomFloat(0.95, 1.0), ATTN_NORM );

            if (g_EngineFuncs.PointContents(tr.vecEndPos) != CONTENTS_WATER)
            {
                g_Utility.Sparks( tr.vecEndPos );
            }

            if ( pHit.GetClassname() == "worldspawn" )
            {
                // let the bolt sit around for a while if it hit static architecture
                pBolt.pev.nextthink = g_Engine.time + 5.0;
            }
            else
            {
                pBolt.pev.nextthink = g_Engine.time;
            }
        }
    }

    void FireBolt()
    {
        TraceResult tr;

        if (self.m_iClip == 0)
        {
            self.PlayEmptySound( );
            return;
        }

        m_pPlayer.m_iWeaponVolume = QUIET_GUN_VOLUME;

        self.m_iClip--;

        // make twang sound
        g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/xbow_fire1.wav", Math.RandomFloat(0.95, 1.0), ATTN_NORM, 0, 93 + Math.RandomLong(0,0xF));

        if (self.m_iClip != 0)
        {
            g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_ITEM, "hlclassic/weapons/xbow_reload1.wav", Math.RandomFloat(0.95, 1.0), ATTN_NORM, 0, 93 + Math.RandomLong(0,0xF));
            self.SendWeaponAnim( CROSSBOW_FIRE1 );
        }
        else if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0)
        {
            self.SendWeaponAnim( CROSSBOW_FIRE3 );
        }

        // player "shoot" animation
        m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

        Vector anglesAim = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;
        g_EngineFuncs.MakeVectors( anglesAim );

        // Vector vecSrc	 = pev.origin + g_Engine.v_up * 16 + g_Engine.v_forward * 20 + g_Engine.v_right * 4;
        anglesAim.x		= -anglesAim.x;
        Vector vecSrc	 = m_pPlayer.GetGunPosition( ) - g_Engine.v_up * 2;
        Vector vecDir	 = g_Engine.v_forward;

        //CBaseEntity *pBolt = CBaseEntity::Create( "crossbow_bolt", vecSrc, anglesAim, m_pPlayer.edict() );
        CHLDMCrossbowBolt@ pBolt = UTIL_BoltCreate();
        pBolt.pev.origin = vecSrc;
        pBolt.pev.angles = anglesAim;
        @pBolt.pev.owner = m_pPlayer.edict();

        if (m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD)
        {
            pBolt.pev.velocity = vecDir * BOLT_WATER_VELOCITY;
            pBolt.pev.speed = BOLT_WATER_VELOCITY;
        }
        else
        {
            pBolt.pev.velocity = vecDir * BOLT_AIR_VELOCITY;
            pBolt.pev.speed = BOLT_AIR_VELOCITY;
        }
        pBolt.pev.avelocity.z = 10;

        if (self.m_iClip == 0 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
            // HEV suit - indicate out of ammo condition
            m_pPlayer.SetSuitUpdate("!HEV_AMO0", false, 0);

        self.m_flNextPrimaryAttack = g_Engine.time + 0.75;

        self.m_flNextSecondaryAttack = g_Engine.time + 0.75;
        if (self.m_iClip != 0)
            self.m_flTimeWeaponIdle = g_Engine.time + 5.0;
        else
            self.m_flTimeWeaponIdle = 0.75;

        m_pPlayer.pev.punchangle.x -= 2;
    }


    void SecondaryAttack()
    {
        if (m_fInZoom)
        {
            m_pPlayer.m_iFOV = 0; // 0 means reset to default fov
            m_fInZoom = false;
        }
        else
        {
            m_pPlayer.m_iFOV = 20;
            m_fInZoom = true;
        }
        
        self.pev.nextthink = g_Engine.time + 0.1;
        self.m_flNextSecondaryAttack = g_Engine.time + 1.0;
    }


    void Reload( void )
    {
        if ( m_fInZoom )
        {
            SecondaryAttack();
        }

        if (self.DefaultReload( 5, CROSSBOW_RELOAD, 4.5 ))
        {
            g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_ITEM, "hlclassic/weapons/xbow_reload1.wav", Math.RandomFloat(0.95, 1.0), ATTN_NORM, 0, 93 + Math.RandomLong(0,0xF));
        }
    }


    void WeaponIdle( void )
    {
        m_pPlayer.GetAutoaimVector( AUTOAIM_2DEGREES );  // get the autoaim vector but ignore it;  used for autoaim crosshair in DM

        self.ResetEmptySound( );
        
        if (self.m_flTimeWeaponIdle < g_Engine.time)
        {
            float flRand = Math.RandomFloat(0, 1);
            if (flRand <= 0.75)
            {
                if (self.m_iClip != 0)
                {
                    self.SendWeaponAnim( CROSSBOW_IDLE1 );
                }
                else
                {
                    self.SendWeaponAnim( CROSSBOW_IDLE2 );
                }
                self.m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat ( 10, 15 );
            }
            else
            {
                if (self.m_iClip != 0)
                {
                    self.SendWeaponAnim( CROSSBOW_FIDGET1 );
                    self.m_flTimeWeaponIdle = g_Engine.time + 90.0 / 30.0;
                }
                else
                {
                    self.SendWeaponAnim( CROSSBOW_FIDGET2 );
                    self.m_flTimeWeaponIdle = g_Engine.time + 80.0 / 30.0;
                }
            }
        }
    }
};

void Register()
{
    if (g_eModelsMode == kOpposingForce) {
        g_VeeMdl = "models/scanarchy/opfor/v_crossbow.mdl";
    } else if (g_eModelsMode == kBlueShift) {
        g_VeeMdl = "models/scanarchy/bshift/v_crossbow.mdl";
    }
    
    g_CustomEntityFuncs.RegisterCustomEntity( "HLDMXBOW::CHLDMCrossbow", "weapon_hldm_xbow" );
    g_CustomEntityFuncs.RegisterCustomEntity( "HLDMXBOW::CHLDMCrossbowBolt", "hldm_crossbow_bolt" );
    g_ItemRegistry.RegisterWeapon( "weapon_hldm_xbow", "scanarchy", "bolts", "", "ammo_crossbow", "");
}

}