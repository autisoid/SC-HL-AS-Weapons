namespace HLDMSHOTGUN
{

// special deathmatch shotgun spreads
Vector VECTOR_CONE_DM_SHOTGUN = Vector( 0.08716, 0.04362, 0.00  ); // 10 degrees by 5 degrees
Vector VECTOR_CONE_DM_DOUBLESHOTGUN = Vector( 0.17365, 0.04362, 0.00 ); // 20 degrees by 5 degrees

enum shotgun_e {
	SHOTGUN_IDLE = 0,
	SHOTGUN_FIRE,
	SHOTGUN_FIRE2,
	SHOTGUN_RELOAD,
	SHOTGUN_PUMP,
	SHOTGUN_START_RELOAD,
	SHOTGUN_DRAW,
	SHOTGUN_HOLSTER,
	SHOTGUN_IDLE4,
	SHOTGUN_IDLE_DEEP
};

// Weapon info
const string g_WeaponName           = "weapon_hldm_shotgun";

enum eModelsMode {
    kDefaultClassic = 0,
    kBlueShift,
    kOpposingForce
}

string g_VeeMdl = "models/hlclassic/v_shotgun.mdl";

int g_eModelsMode = kDefaultClassic;

class weapon_hldm_shotgun : ScriptBasePlayerWeaponEntity {
    int m_fInReload;
	float m_flNextReload;
    int m_iShell;
	float m_flPumpTime;
    int m_nInSpecialReload;

    const Cvar@ m_pDamage;

    private CBasePlayer@ m_pPlayer {
        get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
        set { self.m_hPlayer = EHandle( @value ); }
    }

    void Spawn() {
        Precache();
        g_EntityFuncs.SetModel(self, self.GetW_Model("models/hlclassic/w_shotgun.mdl"));
        self.m_iDefaultAmmo = 12;
        self.FallInit(); // get ready to fall down.
        
        @m_pDamage = g_EngineFuncs.CVarGetPointer( "sk_plr_buckshot" );
    }

    void Precache() {
        BaseClass.Precache();
        self.PrecacheCustomModels();
        
		g_Game.PrecacheGeneric( "sprites/scanarchy/weapon_hldm_shotgun.txt" );
        
        g_Game.PrecacheModel("models/hlclassic/p_shotgun.mdl");
        g_Game.PrecacheModel(g_VeeMdl);
        g_Game.PrecacheModel("models/hlclassic/w_shotgun.mdl");
        m_iShell = g_Game.PrecacheModel ("models/shotgunshell.mdl");// shotgun shell

        g_SoundSystem.PrecacheSound("hlclassic/items/9mmclip1.wav");              

        g_SoundSystem.PrecacheSound ("hlclassic/weapons/dbarrel1.wav");//shotgun
        g_SoundSystem.PrecacheSound ("hlclassic/weapons/sbarrel1.wav");//shotgun

        g_SoundSystem.PrecacheSound ("hlclassic/weapons/reload1.wav");	// shotgun reload
        g_SoundSystem.PrecacheSound ("hlclassic/weapons/reload3.wav");	// shotgun reload

    	g_SoundSystem.PrecacheSound ("hlclassic/weapons/sshell1.wav");	// shotgun reload - played on client
    	g_SoundSystem.PrecacheSound ("hlclassic/weapons/sshell3.wav");	// shotgun reload - played on client
        
        g_SoundSystem.PrecacheSound ("hlclassic/weapons/357_cock1.wav"); // gun empty sound
        g_SoundSystem.PrecacheSound ("hlclassic/weapons/scock1.wav");	// cock gun
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
        info.iMaxAmmo1  = 125;
        info.iMaxAmmo2  = -1;
        info.iMaxClip   = 8;
        info.iSlot      = 2;
        info.iPosition  = 5;
        info.iId        = g_ItemRegistry.GetIdForName( self.pev.classname );
        info.iWeight    = 15;
        info.iAmmo1Drop = 8;
        
        return true;
    }

    bool Deploy() {
        return self.DefaultDeploy(self.GetV_Model(g_VeeMdl), self.GetP_Model("models/hlclassic/p_shotgun.mdl"), SHOTGUN_DRAW, "shotgun");
    }

    void Holster( int skipLocal = 0 )
    {
        BaseClass.Holster( skipLocal );
    }
    
    void CreatePelletDecals( const Vector& in vecSrc, const Vector& in vecAiming, const Vector& in vecSpread, const uint uiPelletCount )
	{
		TraceResult tr;
	
		float x, y;
	
		for( uint uiPellet = 0; uiPellet < uiPelletCount; ++uiPellet )
		{
			g_Utility.GetCircularGaussianSpread( x, y );

			Vector vecDir = vecAiming + x * vecSpread.x * g_Engine.v_right + y * vecSpread.y * g_Engine.v_up;

			Vector vecEnd	= vecSrc + vecDir * 2048;

			g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

			if( tr.flFraction < 1.0f )
			{
				if( tr.pHit !is null )
				{
					CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );

					if( pHit is null || pHit.IsBSPModel() )
					{
						// Decal
						g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_BUCKSHOT );
					}
				}
			}
		}
	}
    
    void PrimaryAttack() {
        // don't fire underwater
        if (m_pPlayer.pev.waterlevel == 3) {
            self.PlayEmptySound();
            self.m_flNextPrimaryAttack = g_Engine.time + 0.15f;
            return;
        }

        if (self.m_iClip <= 0) {
            self.Reload();
            if (self.m_iClip == 0)
                self.PlayEmptySound();
            return;
        }
        
		self.SendWeaponAnim( SHOTGUN_FIRE, 0, 0 );
        
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/sbarrel1.wav", Math.RandomFloat( 0.98f, 1.0f ), ATTN_NORM, 0, 85 + Math.RandomLong( 0, 0x1f ) );

        m_pPlayer.m_iWeaponVolume = 1000;
        m_pPlayer.m_iWeaponFlash = 256;

        self.m_iClip--;

        m_pPlayer.pev.effects |= EF_MUZZLEFLASH;

        Vector vecSrc	 = m_pPlayer.GetGunPosition( );
        Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

        m_pPlayer.FireBullets( 4, vecSrc, vecAiming, VECTOR_CONE_DM_SHOTGUN, 2048, BULLET_PLAYER_BUCKSHOT, 0 );

        if (self.m_iClip == 0 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
            // HEV suit - indicate out of ammo condition
            m_pPlayer.SetSuitUpdate("!HEV_AMO0", false, 0);

        m_flPumpTime = g_Engine.time + 0.5f;

        self.m_flNextPrimaryAttack = g_Engine.time + 0.75f;
        self.m_flNextSecondaryAttack = g_Engine.time + 0.75f;
        if (self.m_iClip != 0)
            self.m_flTimeWeaponIdle = g_Engine.time + 5.f;
        else
            self.m_flTimeWeaponIdle = g_Engine.time + 0.75f;
        m_nInSpecialReload = 0;
        
		m_pPlayer.pev.punchangle.x = -5.0f;
        
		CreatePelletDecals( vecSrc, vecAiming, VECTOR_CONE_DM_SHOTGUN, 4 );
    }

    void SecondaryAttack( )
    {
        // don't fire underwater
        if (m_pPlayer.pev.waterlevel == 3)
        {
            self.PlayEmptySound( );
            self.m_flNextPrimaryAttack = g_Engine.time + (0.15f);
            return;
        }

        if (self.m_iClip <= 1)
        {
            self.Reload( );
            self.PlayEmptySound( );
            return;
        }
        
		self.SendWeaponAnim( SHOTGUN_FIRE2, 0, 0 );

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/dbarrel1.wav", Math.RandomFloat( 0.98f, 1.0f ), ATTN_NORM, 0, 85 + Math.RandomLong( 0, 0x1f ) );

        m_pPlayer.m_iWeaponVolume = 1000;
        m_pPlayer.m_iWeaponFlash = 256;

        self.m_iClip -= 2;

        m_pPlayer.pev.effects |= EF_MUZZLEFLASH;

        // player "shoot" animation
        m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

        Vector vecSrc	 = m_pPlayer.GetGunPosition( );
        Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

        m_pPlayer.FireBullets( 8, vecSrc, vecAiming, VECTOR_CONE_DM_DOUBLESHOTGUN, 2048, BULLET_PLAYER_BUCKSHOT, 0, int(m_pDamage.value) );

        if (self.m_iClip == 0 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
            m_pPlayer.SetSuitUpdate("!HEV_AMO0", false, 0);

        m_flPumpTime = g_Engine.time + 0.95f;

        self.m_flNextPrimaryAttack = g_Engine.time + (1.5);
        self.m_flNextSecondaryAttack = g_Engine.time + 1.5f;
        if (self.m_iClip != 0)
            self.m_flTimeWeaponIdle = g_Engine.time + 6.f;
        else
            self.m_flTimeWeaponIdle = 1.5f;

        m_nInSpecialReload = 0;
        
		m_pPlayer.pev.punchangle.x = -10.0f;
        
		CreatePelletDecals( vecSrc, vecAiming, VECTOR_CONE_DM_SHOTGUN, 8 );
    }

    void Reload( )
    {
        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0 || self.m_iClip == 8)
            return;
            
		if( m_flNextReload > g_Engine.time ) {
			return;
        }

        // don't reload until recoil is done
        if (self.m_flNextPrimaryAttack > g_Engine.time && m_nInSpecialReload == 0) {
            return;
        }

        // check to see if we're ready to reload
        if (m_nInSpecialReload == 0) {
            self.SendWeaponAnim( SHOTGUN_START_RELOAD, 0, 0 );
            m_nInSpecialReload = 1;
            m_pPlayer.m_flNextAttack = 0.6f;
            self.m_flTimeWeaponIdle = g_Engine.time + 0.6f;
            self.m_flNextPrimaryAttack = g_Engine.time + (1.f);
            self.m_flNextSecondaryAttack = g_Engine.time + 1.f;
            return;
        }
        else if (m_nInSpecialReload == 1)
        {
            if (self.m_flTimeWeaponIdle > g_Engine.time) {
                return;
            }
            // was waiting for gun to move to side
            m_nInSpecialReload = 2;

            if (Math.RandomLong(0,1) != 0)
                g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_ITEM, "hlclassic/weapons/reload1.wav", 1, ATTN_NORM, 0, 85 + Math.RandomLong(0,0x1f));
            else
                g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_ITEM, "hlclassic/weapons/reload3.wav", 1, ATTN_NORM, 0, 85 + Math.RandomLong(0,0x1f));

            self.SendWeaponAnim( SHOTGUN_RELOAD );

            m_flNextReload = g_Engine.time + 0.5f;
            self.m_flTimeWeaponIdle = g_Engine.time + 0.5f;
        }
        else
        {
            // Add them to the clip
            self.m_iClip += 1;
            m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 1);
            m_nInSpecialReload = 1;
        }
        
        BaseClass.Reload();
    }
    
    void WeaponIdle( )
    {
        self.ResetEmptySound( );

        m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

        if (self.m_flTimeWeaponIdle <  g_Engine.time )
        {
            if (self.m_iClip == 0 && m_nInSpecialReload == 0 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) != 0)
            {
                self.Reload( );
            }
            else if (m_nInSpecialReload != 0)
            {
                if (self.m_iClip != 8 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) != 0)
                {
                    self.Reload( );
                }
                else
                {
                    // reload debounce has timed out
                    self.SendWeaponAnim( SHOTGUN_PUMP );
                    
                    // play cocking sound
                    g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_ITEM, "hlclassic/weapons/scock1.wav", 1, ATTN_NORM, 0, 95 + Math.RandomLong(0,0x1f));
                    m_nInSpecialReload = 0;
                    self.m_flTimeWeaponIdle = g_Engine.time + 1.5;
                }
            }
            else
            {
                int iAnim;
                float flRand = g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 0.f, 1.f );
                if (flRand <= 0.8f)
                {
                    iAnim = SHOTGUN_IDLE_DEEP;
                    self.m_flTimeWeaponIdle = g_Engine.time + (60.f/12.f);// * RANDOM_LONG(2, 5);
                }
                else if (flRand <= 0.95f)
                {
                    iAnim = SHOTGUN_IDLE;
                    self.m_flTimeWeaponIdle = g_Engine.time + (20.f/9.f);
                }
                else
                {
                    iAnim = SHOTGUN_IDLE4;
                    self.m_flTimeWeaponIdle = g_Engine.time + (20.f/9.f);
                }
                self.SendWeaponAnim( iAnim );
            }
        }
    }
    
    void ItemPostFrame( )
    {
        if ( m_flPumpTime != 0.f && m_flPumpTime < g_Engine.time )
        {
            // play pumping sound
            g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_ITEM, "hlclassic/weapons/scock1.wav", 1, ATTN_NORM, 0, 95 + Math.RandomLong(0,0x1f));
            m_flPumpTime = 0.f;
        }

        BaseClass.ItemPostFrame();
    }
}

void Register() {
    if (g_eModelsMode == kOpposingForce) {
        g_VeeMdl = "models/scanarchy/opfor/v_shotgun.mdl";
    } else if (g_eModelsMode == kBlueShift) {
        g_VeeMdl = "models/scanarchy/bshift/v_shotgun.mdl";
    }
    
    g_CustomEntityFuncs.RegisterCustomEntity("HLDMSHOTGUN::weapon_hldm_shotgun", g_WeaponName);
    g_ItemRegistry.RegisterWeapon(g_WeaponName, "scanarchy", "buckshot", "", "ammo_buckshot", "");
}

} // End of namespace