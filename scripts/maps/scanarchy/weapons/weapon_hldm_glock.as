/*  
* The original Half-Life version of the Glock
* Modified for the Crack-Life Sven Co-op conversion
*
* Original Crack-Life mod by: Siemka321
* Sven Co-op Re-conversion: Rafael "R4to0" Alves
*/

namespace HLDMGLOCK
{

enum glock_e
{
	GLOCK_IDLE1 = 0,
	GLOCK_IDLE2,
	GLOCK_IDLE3,
	GLOCK_SHOOT,
	GLOCK_SHOOT_EMPTY,
	GLOCK_RELOAD,
	GLOCK_RELOAD_NOT_EMPTY,
	GLOCK_DRAW,
	GLOCK_HOLSTER,
	GLOCK_ADD_SILENCER
};

// Models
string g_PeeMdl		= "models/hlclassic/p_9mmhandgun.mdl";
string g_VeeMdl		= "models/hlclassic/v_9mmhandgun.mdl";
string g_WeeMdl		= "models/hlclassic/w_9mmhandgun.mdl";

// Sounds
const string g_FireSnd		= "hlclassic/weapons/pl_gun3.wav";
const string g_EmptySnd		= "hlclassic/weapons/357_cock1.wav";

// Weapon Info
const uint g_MaxAmmoPri		= 250;
const uint g_MaxClip		= 17;
const uint g_Weight			= 10;
const string g_PriAmmoType	= "9mm"; //Default: 9mm
const string g_WeaponName	= "weapon_hldm_glock";

enum eModelsMode {
    kDefaultClassic = 0,
    kBlueShift,
    kOpposingForce
}

int g_eModelsMode = kDefaultClassic;

class weapon_hldm_glock : ScriptBasePlayerWeaponEntity
{
    int m_iShell;

	private CBasePlayer@ m_pPlayer
	{
		get const 	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set       	{ self.m_hPlayer = EHandle( @value ); }
	}

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, self.GetW_Model(g_WeeMdl) );
		self.m_iDefaultAmmo = g_MaxClip;
		self.FallInit();
	}

	void Precache()
	{
        BaseClass.Precache();
        self.PrecacheCustomModels();
        
		g_Game.PrecacheGeneric( "sprites/scanarchy/weapon_hldm_glock.txt" );

		g_Game.PrecacheModel( g_PeeMdl );
		g_Game.PrecacheModel( g_VeeMdl );
		g_Game.PrecacheModel( g_WeeMdl );
        
        m_iShell = g_Game.PrecacheModel ("models/hlclassic/shell.mdl");// brass shell

		g_SoundSystem.PrecacheSound( g_FireSnd );
		g_SoundSystem.PrecacheSound( g_EmptySnd );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= g_MaxAmmoPri;
		info.iMaxAmmo2	= -1;
		info.iMaxClip 	= g_MaxClip;
		info.iSlot 		= 1;
		info.iPosition 	= 4;
		info.iId		= g_ItemRegistry.GetIdForName( self.pev.classname );
		info.iWeight 	= g_Weight;

		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( BaseClass.AddToPlayer( pPlayer ) == true )
		{
			@m_pPlayer = pPlayer;
			NetworkMessage clglock( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			clglock.WriteLong( g_ItemRegistry.GetIdForName( self.pev.classname ) );
			clglock.End();
			return true;
		}

		return false;
	}

	bool Deploy()
	{
		return self.DefaultDeploy( self.GetV_Model(g_VeeMdl), self.GetP_Model(g_PeeMdl), GLOCK_DRAW, "onehanded" );
	}

	void Holster( int skipLocal = 0 )
	{
		self.m_fInReload = false; // cancel any reload in progress.
		SetThink( null );
		BaseClass.Holster( skipLocal );
		self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed,  10, 15 );
	}

	void SecondaryAttack()
	{
		GlockFire( 0.1f, 0.2f );
		self.m_flNextSecondaryAttack = self.m_flNextPrimaryAttack = g_Engine.time + 0.2f;
	}

	void PrimaryAttack()
	{
		GlockFire( 0.01f, 0.3f );
		self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.3f;
	}

	void GlockFire( float flSpread , float flCycleTime)
	{
		if( self.m_iClip <= 0 )
		{
			//self.PlayEmptySound();
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, g_EmptySnd, Math.RandomFloat( 0.92f, 1.0f ), ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
			self.m_flNextPrimaryAttack = g_Engine.time + 0.2f;

			return;
		}

		--self.m_iClip;
        
        m_pPlayer.pev.effects |= EF_MUZZLEFLASH;

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

        if (self.m_iClip != 0)
            self.SendWeaponAnim( GLOCK_SHOOT );
        else
            self.SendWeaponAnim( GLOCK_SHOOT_EMPTY );
        
        g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );
            
        Vector	vecShellVelocity = m_pPlayer.pev.velocity 
                                 + g_Engine.v_right * Math.RandomFloat(50,70) 
                                 + g_Engine.v_up * Math.RandomFloat(100,150) 
                                 + g_Engine.v_forward * 25;
        g_EntityFuncs.EjectBrass ( self.pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_up * -12 + g_Engine.v_forward * 32 + g_Engine.v_right * 6 , vecShellVelocity, self.pev.angles.y, m_iShell, TE_BOUNCE_SHELL ); 

		// Fire sound
		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, g_FireSnd, Math.RandomFloat( 0.92f, 1.0f ), ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );

		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = g_Engine.v_forward;

		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, Vector( flSpread, flSpread, flSpread ), 8192, BULLET_PLAYER_9MM, 0 );

		if( self.m_iClip == 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			// HEV suit - indicate out of ammo condition
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );
	
		self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed,  10, 15 );

		// Decal shit
		TraceResult tr;
		float x, y;
		g_Utility.GetCircularGaussianSpread( x, y );
		Vector vecDir = vecAiming + x * flSpread * g_Engine.v_right + y * flSpread  * g_Engine.v_up;
		Vector vecEnd = vecSrc + vecDir * 4096;
		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction < 1.0f )
		{
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
                
				if( pHit is null || pHit.IsBSPModel() )
					g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_9MM );
			}
		}
        
        m_pPlayer.pev.punchangle.x -= 2;
	}

	void Reload()
	{
        if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 || self.m_iClip == g_MaxClip )
			return;

		self.DefaultReload( g_MaxClip, GLOCK_RELOAD, 2.75f, 0 );
		BaseClass.Reload();
		self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 10, 15 );
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();

		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

        // only idle if the slid isn't back
        if (self.m_iClip != 0)
        {
            int iAnim;
            float flRand = Math.RandomFloat(0, 1);
            if (flRand <= 0.3 + 0 * 0.75)
            {
                iAnim = GLOCK_IDLE3;
                self.m_flTimeWeaponIdle = g_Engine.time + 49.0 / 16;
            }
            else if (flRand <= 0.6 + 0 * 0.875)
            {
                iAnim = GLOCK_IDLE1;
                self.m_flTimeWeaponIdle = g_Engine.time + 60.0 / 16.0;
            }
            else
            {
                iAnim = GLOCK_IDLE2;
                self.m_flTimeWeaponIdle = g_Engine.time + 40.0 / 16.0;
            }
            self.SendWeaponAnim( iAnim );
        }
	}
}

void Register()
{
    if (g_eModelsMode == kOpposingForce) {
        g_VeeMdl = "models/scanarchy/opfor/v_9mmhandgun.mdl";
    } else if (g_eModelsMode == kBlueShift) {
        g_VeeMdl = "models/scanarchy/bshift/v_9mmhandgun.mdl";
    }
    
	g_CustomEntityFuncs.RegisterCustomEntity( "HLDMGLOCK::weapon_hldm_glock", g_WeaponName );
	g_ItemRegistry.RegisterWeapon( g_WeaponName, "scanarchy", g_PriAmmoType, "", "ammo_9mmclip", "" );
}

} // End of namespace