namespace HLDMMP5
{

enum mp5_e
{
	MP5_LONGIDLE = 0,
	MP5_IDLE1,
	MP5_LAUNCH,
	MP5_RELOAD,
	MP5_DEPLOY,
	MP5_FIRE1,
	MP5_FIRE2,
	MP5_FIRE3,
};

// Weapon info
const string g_WeaponName           = "weapon_hldm_9mmAR";

enum eModelsMode {
    kDefaultClassic = 0,
    kBlueShift,
    kOpposingForce
}

int g_eModelsMode = kDefaultClassic;

string g_VeeMdl = "models/hlclassic/v_9mmAR.mdl";
string g_PeeMdl = "models/hlclassic/p_9mmAR.mdl";
string g_WeeMdl = "models/hlclassic/w_9mmAR.mdl";

class weapon_hldm_MP5 : ScriptBasePlayerWeaponEntity {
    int m_iShell;

    private CBasePlayer@ m_pPlayer {
        get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
        set { self.m_hPlayer = EHandle( @value ); }
    }

    void Spawn() {
        Precache();
        g_EntityFuncs.SetModel(self, self.GetW_Model("models/hlclassic/w_9mmAR.mdl"));
        self.m_iDefaultAmmo = 30;
        self.FallInit(); // get ready to fall down.
    }

    void Precache() {
        BaseClass.Precache();
        self.PrecacheCustomModels();
        
		g_Game.PrecacheGeneric( "sprites/scanarchy/weapon_hldm_9mmAR.txt" );
        
        g_Game.PrecacheModel(g_VeeMdl);
        g_Game.PrecacheModel(g_WeeMdl);
        g_Game.PrecacheModel(g_PeeMdl);

        m_iShell = g_Game.PrecacheModel ("models/hlclassic/shell.mdl");// brass shellTE_MODEL

        g_Game.PrecacheModel("models/grenade.mdl");	// grenade

        g_Game.PrecacheModel("models/w_9mmARclip.mdl");
        g_SoundSystem.PrecacheSound("hlclassic/items/9mmclip1.wav");              

        g_SoundSystem.PrecacheSound("hlclassic/items/clipinsert1.wav");
        g_SoundSystem.PrecacheSound("hlclassic/items/cliprelease1.wav");

        g_SoundSystem.PrecacheSound ("hlclassic/weapons/hks1.wav");// H to the K
        g_SoundSystem.PrecacheSound ("hlclassic/weapons/hks2.wav");// H to the K
        g_SoundSystem.PrecacheSound ("hlclassic/weapons/hks3.wav");// H to the K

        g_SoundSystem.PrecacheSound ( "hlclassic/weapons/glauncher.wav" );
        g_SoundSystem.PrecacheSound ( "hlclassic/weapons/glauncher2.wav" );
        
        g_SoundSystem.PrecacheSound ("hlclassic/weapons/357_cock1.wav"); // gun empty sound
    }

    bool AddToPlayer(CBasePlayer@ pPlayer) {
        if (BaseClass.AddToPlayer(pPlayer)) {
            @m_pPlayer = pPlayer;
            
            NetworkMessage weap(MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict());
                weap.WriteLong(g_ItemRegistry.GetIdForName(self.pev.classname));
            weap.End();
            
            return true;
        }
        
        return false;
    }

    bool GetItemInfo(ItemInfo& out info) {
        info.iMaxAmmo1  = 250;
        info.iMaxAmmo2  = 10;
        info.iMaxClip   = 50;
        info.iSlot      = 2;
        info.iPosition  = 4;
        info.iId        = g_ItemRegistry.GetIdForName( self.pev.classname );
        info.iWeight    = 15;
        info.iAmmo1Drop = 8;
        
        return true;
    }

    bool Deploy() {
        return self.DefaultDeploy(self.GetV_Model(g_VeeMdl), self.GetP_Model(g_PeeMdl), MP5_DEPLOY, "mp5");
    }

    void Holster( int skipLocal = 0 )
    {
        BaseClass.Holster( skipLocal );
    }
    
    void PrimaryAttack()
    {
        // don't fire underwater
        if (m_pPlayer.pev.waterlevel == 3)
        {
            self.PlayEmptySound( );
            self.m_flNextPrimaryAttack = g_Engine.time + 0.15;
            return;
        }

        if (self.m_iClip <= 0)
        {
            self.PlayEmptySound();
            self.m_flNextPrimaryAttack = g_Engine.time + 0.15;
            return;
        }

        m_pPlayer.m_iWeaponVolume = 600;
        m_pPlayer.m_iWeaponFlash = 256;

        self.m_iClip--;
        
		self.SendWeaponAnim( MP5_FIRE1 + Math.RandomLong(0,2));

        m_pPlayer.pev.effects |= EF_MUZZLEFLASH;

        // player "shoot" animation
        m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
        
        switch( Math.RandomLong(0,2) )
            {
            case 0: g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/hks1.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong(0,0xf)); break;
            case 1: g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/hks2.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong(0,0xf)); break;
        	case 2: g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/hks3.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong(0,0xf)); break;
            }
            
        g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );

        Vector	vecShellVelocity = m_pPlayer.pev.velocity 
                                 + g_Engine.v_right * Math.RandomFloat(50,70) 
                                 + g_Engine.v_up * Math.RandomFloat(100,150) 
                                 + g_Engine.v_forward * 25;
        g_EntityFuncs.EjectBrass ( self.pev.origin + m_pPlayer.pev.view_ofs
                        + g_Engine.v_up * -12 
                        + g_Engine.v_forward * 20 
                        + g_Engine.v_right * 4, vecShellVelocity, self.pev.angles.y, m_iShell, TE_BOUNCE_SHELL); 
        

        Vector vecSrc	 = m_pPlayer.GetGunPosition( );
        Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );
        
        m_pPlayer.FireBullets( 1, vecSrc, vecAiming, VECTOR_CONE_6DEGREES, 8192, BULLET_PLAYER_MP5, 2 );
       
        TraceResult tr;
        
		float x, y;
		g_Utility.GetCircularGaussianSpread( x, y );
		Vector vecDir = vecAiming + x * VECTOR_CONE_6DEGREES.x * g_Engine.v_right + y * VECTOR_CONE_6DEGREES.y * g_Engine.v_up;
		Vector vecEnd	= vecSrc + vecDir * 4096;

        g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

        if( tr.flFraction < 1.0f )
        {
            if( tr.pHit !is null )
            {
                CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );

                if( pHit is null || pHit.IsBSPModel() )
                {
                    // Decal
                    g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_MP5 );
                }
            }
        }

        if (self.m_iClip == 0 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
            // HEV suit - indicate out of ammo condition
            m_pPlayer.SetSuitUpdate("!HEV_AMO0", false, 0);

        self.m_flNextPrimaryAttack = g_Engine.time + 0.1;
        if (self.m_flNextPrimaryAttack < g_Engine.time)
            self.m_flNextPrimaryAttack = g_Engine.time + 0.1;

        self.m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat ( 10, 15 );

        m_pPlayer.pev.punchangle.x = Math.RandomFloat( -2, 2 );
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
    
    void SecondaryAttack( void )
    {
        // don't fire underwater
        if (m_pPlayer.pev.waterlevel == 3)
        {
            self.PlayEmptySound( );
            self.m_flNextPrimaryAttack = g_Engine.time + 0.15;
            return;
        }

        if (m_pPlayer.m_rgAmmo(self.m_iSecondaryAmmoType) == 0)
        {
            self.PlayEmptySound( );
            return;
        }

        m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
        m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;

        m_pPlayer.m_iExtraSoundTypes = bits_SOUND_DANGER;
        m_pPlayer.m_flStopExtraSoundTime = g_Engine.time + 0.2;
                
        m_pPlayer.m_rgAmmo(self.m_iSecondaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iSecondaryAmmoType) - 1);
        
        self.SendWeaponAnim( MP5_LAUNCH );

        // player "shoot" animation
        m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

        if ( Math.RandomLong(0,1) != 0)
        {
            // play this sound through BODY channel so we can hear it if player didn't stop firing MP3
            g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/glauncher.wav", 0.8, ATTN_NORM);
        }
        else
        {
            // play this sound through BODY channel so we can hear it if player didn't stop firing MP3
            g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/glauncher2.wav", 0.8, ATTN_NORM);
        }

        g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );

        // we don't add in player velocity anymore.
        g_EntityFuncs.ShootContact( m_pPlayer.pev, 
                                m_pPlayer.pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_forward * 16, 
                                g_Engine.v_forward * 800 );
        
        self.m_flNextPrimaryAttack = g_Engine.time + (1);
        self.m_flNextSecondaryAttack = g_Engine.time + 1;
        self.m_flTimeWeaponIdle = g_Engine.time + 5;// idle pretty soon after shooting.

        if (m_pPlayer.m_rgAmmo(self.m_iSecondaryAmmoType) == 0)
            // HEV suit - indicate out of ammo condition
            m_pPlayer.SetSuitUpdate("!HEV_AMO0", false, 0);

        m_pPlayer.pev.punchangle.x -= 10;
    }

    void Reload( )
    {
        if ( m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0 )
            return;

        self.DefaultReload( 50, MP5_RELOAD, 1.5 );
    }


    void WeaponIdle( )
    {
        self.ResetEmptySound( );

        m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

        if ( self.m_flTimeWeaponIdle > g_Engine.time )
            return;

        int iAnim;
        switch ( Math.RandomLong( 0, 1 ) )
        {
        case 0:	
            iAnim = MP5_LONGIDLE;	
            break;
        
        case 1:
            iAnim = MP5_IDLE1;
            break;
            
        default:
            iAnim = MP5_IDLE1;
            break;
        }

        self.SendWeaponAnim( iAnim );

        self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 10, 15); // how long till we do this again.
    }
}

void Register() {
    if (g_eModelsMode == kOpposingForce) {
        g_VeeMdl = "models/scanarchy/opfor/v_9mmAR.mdl";
    } else if (g_eModelsMode == kBlueShift) {
        g_VeeMdl = "models/scanarchy/bshift/v_9mmAR.mdl";
    }

    g_CustomEntityFuncs.RegisterCustomEntity("HLDMMP5::weapon_hldm_MP5", g_WeaponName);
    g_ItemRegistry.RegisterWeapon(g_WeaponName, "scanarchy", "9mm", "ARgrenades", "ammo_9mmAR", "ammo_ARgrenades");
}

} // End of namespace