namespace HLOPFORGRAPPLE {

enum GrappleTarget
{
	GRAPPLE_NOT_A_TARGET	= 0,
	GRAPPLE_SMALL			= 1,
	GRAPPLE_MEDIUM			= 2,
	GRAPPLE_LARGE			= 3,
	GRAPPLE_FIXED			= 4,
};

GrappleTarget SizeForGrapple(CBaseEntity@ _Other) {
    if (_Other.IsBSPModel() || _Other.IsMachine())
        return GRAPPLE_NOT_A_TARGET;

    if (_Other.GetClassname().Find("tentacle") != String::INVALID_INDEX || _Other.GetClassname().Find("barnacle") != String::INVALID_INDEX) {
        return GRAPPLE_FIXED;
    }
    
    if (_Other.GetClassname().Find("spore") != String::INVALID_INDEX) {
        return GRAPPLE_MEDIUM;
    }
    
	Vector vecHuman = VEC_HUMAN_HULL_MAX - VEC_HUMAN_HULL_MIN;
	Vector vecTarget = _Other.pev.absmax - _Other.pev.absmin;
	
	float flEpsilon = 0.01f; // bounding boxes are sometimes off by a tiny fraction
	if (vecTarget.x - flEpsilon > vecHuman.x || vecTarget.y - flEpsilon > vecHuman.y || vecTarget.z - flEpsilon > vecHuman.z) {
        return GRAPPLE_LARGE;
    }
    
    Vector vecSmall = VEC_DUCK_HULL_MAX - VEC_DUCK_HULL_MIN;
    
    if (vecSmall.x - flEpsilon > vecTarget.x || vecSmall.y - flEpsilon > vecTarget.y || vecSmall.z - flEpsilon > vecTarget.z) {
        return GRAPPLE_SMALL;
    }
    
    return GRAPPLE_MEDIUM;
}

class CBarnacleGrappleTip : ScriptBaseEntity {
	int targetClass;
    
	void Precache()
    {
        BaseClass.Precache();
        g_Game.PrecacheModel( "models/shock_effect.mdl" );
    }
	
    void Spawn()
    {
        Precache();

        pev.movetype = MOVETYPE_FLY;
        pev.solid = SOLID_BBOX;

        g_EntityFuncs.SetModel( self, "models/shock_effect.mdl" );

        g_EntityFuncs.SetSize( pev, g_vecZero, g_vecZero );

        g_EntityFuncs.SetOrigin( self, pev.origin );

        SetThink( ThinkFunction( FlyThink ) );
        SetTouch( TouchFunction( TongueTouch ) );

        Vector vecAngles = pev.angles;

        vecAngles.x -= 30.0;

        pev.angles = vecAngles;

        g_EngineFuncs.MakeVectors( pev.angles );

        vecAngles.x = -( 30.0 + vecAngles.x );

        pev.velocity = g_vecZero;

        pev.gravity = 1.0;

        pev.nextthink = g_Engine.time + 0.02;

        m_bIsStuck = false;
        m_bMissed = false;
    }

	void FlyThink()
    {
        Math.MakeAimVectors( pev.angles );

        pev.angles = Math.VecToAngles( g_Engine.v_forward );

        const float flNewVel = ( ( pev.velocity.Length() * 0.8 ) + 400.0 );

        pev.velocity = pev.velocity * 0.2 + ( flNewVel * g_Engine.v_forward );

        /*if( !g_pGameRules.IsMultiplayer() )
        {
            //Note: the old grapple had a maximum velocity of 1600. - Solokiller
            if( pev.velocity.Length() > 750.0 )
            {
                pev.velocity = pev.velocity.Normalize() * 750.0;
            }
        }
        else
        {*/
            //TODO: should probably clamp at sv_maxvelocity to prevent the tip from going off course. - Solokiller
            if( pev.velocity.Length() > 2000.0 )
            {
                pev.velocity = pev.velocity.Normalize() * 2000.0;
            }
        //}

        pev.nextthink = g_Engine.time + 0.02;
    }
	void OffsetThink()
    {
        //Nothing
    }

	void TongueTouch( CBaseEntity@ pOther )
    {
        if( pOther is null )
        {
            targetClass = GRAPPLE_NOT_A_TARGET;
            m_bMissed = true;
        }
        else
        {
            if( pOther.IsPlayer() )
            {
                targetClass = GRAPPLE_MEDIUM;

                m_hGrappleTarget = pOther;

                m_bIsStuck = true;
            }
            else
            {
                targetClass = CheckTarget( pOther );

                if( targetClass != GRAPPLE_NOT_A_TARGET )
                {
                    m_bIsStuck = true;
                }
                else
                {
                    m_bMissed = true;
                }
            }
        }

        pev.velocity = g_vecZero;

        m_GrappleType = targetClass;

        SetThink( ThinkFunction( OffsetThink ) );
        pev.nextthink = g_Engine.time + 0.02;

        SetTouch( null );
    }

	int CheckTarget( CBaseEntity@ pTarget )
    {
        if( pTarget is null )
            return GRAPPLE_NOT_A_TARGET;

        if( pTarget.IsPlayer() )
        {
            m_hGrappleTarget = pTarget;

            return SizeForGrapple(pTarget);
        }

        Vector vecStart = pev.origin;
        Vector vecEnd = pev.origin + pev.velocity * 1024.0;

        TraceResult tr;

        g_Utility.TraceLine( vecStart, vecEnd, ignore_monsters, self.edict(), tr );

        CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );

    /*	if( !pHit )
            pHit = CWorld::GetInstance();*/

        string pTexture;

        if (pHit !is null)
            pTexture = g_Utility.TraceTexture(tr.pHit, vecStart, vecEnd);
        else
            pTexture = g_Utility.TraceTexture(g_EntityFuncs.Instance(0).edict(), vecStart, vecEnd);

        bool bIsFixed = false;

        if( !pTexture.IsEmpty() && pTexture.Find("xeno_grapple") == 0 )
        {
            bIsFixed = true;
        }
        else if (SizeForGrapple(pTarget) != GRAPPLE_NOT_A_TARGET)
        {
            if (SizeForGrapple(pTarget) == GRAPPLE_FIXED) {
                bIsFixed = true;
            } else {
                m_hGrappleTarget = pTarget;
                m_vecOriginOffset = pev.origin - pTarget.pev.origin;
                return SizeForGrapple(pTarget);
            }
        }

        if( bIsFixed )
        {
            m_hGrappleTarget = pTarget;
            m_vecOriginOffset = g_vecZero;

            return GRAPPLE_FIXED;
        }

        return GRAPPLE_NOT_A_TARGET;
    }

	void SetPosition( const Vector& in vecOrigin, const Vector& in vecAngles, CBaseEntity@ pOwner )
    {
        g_EntityFuncs.SetOrigin( self, vecOrigin );
        pev.angles = vecAngles;
        @pev.owner = pOwner.edict();
    }

	int GetGrappleType() const { return m_GrappleType; }

	bool IsStuck() const { return m_bIsStuck; }

	bool HasMissed() const { return m_bMissed; }
	EHandle GetGrappleTarget() { return m_hGrappleTarget; }
	void SetGrappleTarget( CBaseEntity@ pTarget )
	{
		m_hGrappleTarget = pTarget;
	}
    
	int m_GrappleType;
	bool m_bIsStuck;
	bool m_bMissed;
	EHandle m_hGrappleTarget;
	Vector m_vecOriginOffset;
};

enum bgrap_e {
	BGRAPPLE_BREATHE = 0,
	BGRAPPLE_LONGIDLE,
	BGRAPPLE_SHORTIDLE,
	BGRAPPLE_COUGH,
	BGRAPPLE_DOWN,
	BGRAPPLE_UP,
	BGRAPPLE_FIRE,
	BGRAPPLE_FIREWAITING,
	BGRAPPLE_FIREREACHED,
	BGRAPPLE_FIRETRAVEL,
	BGRAPPLE_FIRERELEASE
};

enum FireState
{
    OFF		= 0,
    CHARGE	= 1
};

class CBarnacleGrapple : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer
	{
		get const 	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set       	{ self.m_hPlayer = EHandle( @value ); }
	}
    
    const Cvar@ m_pDamage;
    bool m_bMode;

    float m_flLastBounceSoundTime;

	void Precache( void )
    {
        BaseClass.Precache();
        self.PrecacheCustomModels();
        
        g_Game.PrecacheGeneric( "sprites/scanarchy/weapon_hlopfor_grapple.txt" );
        
        g_Game.PrecacheModel( "models/scanarchy/v_bgrap.mdl" );
        g_Game.PrecacheModel( "models/scanarchy/w_bgrap.mdl" );
        g_Game.PrecacheModel( "models/scanarchy/p_bgrap.mdl" );

        g_SoundSystem.PrecacheSound( "weapons/bgrapple_release.wav" );
        g_SoundSystem.PrecacheSound( "weapons/bgrapple_impact.wav" );
        g_SoundSystem.PrecacheSound( "weapons/bgrapple_fire.wav" );
        g_SoundSystem.PrecacheSound( "weapons/bgrapple_cough.wav" );
        g_SoundSystem.PrecacheSound( "weapons/bgrapple_pull.wav" );
        g_SoundSystem.PrecacheSound( "weapons/bgrapple_wait.wav" );
        g_SoundSystem.PrecacheSound( "weapons/alienweap_draw.wav" );
        g_SoundSystem.PrecacheSound( "barnacle/bcl_chew1.wav" );
        g_SoundSystem.PrecacheSound( "barnacle/bcl_chew2.wav" );
        g_SoundSystem.PrecacheSound( "barnacle/bcl_chew3.wav" );
        g_SoundSystem.PrecacheSound( "debris/flesh5.wav" );

        g_Game.PrecacheModel( "sprites/tongue.spr" );

        g_Game.PrecacheOther( "sca_grapple_tip" );
    }

    void Spawn( void )
    {
        Precache();
        g_EntityFuncs.SetModel( self, "models/scanarchy/w_bgrap.mdl" );
        @m_pTip = null;
        m_bGrappling = false;
        self.m_iClip = -1;
        m_flLastBounceSoundTime = 0.f;
        @m_pDamage = g_EngineFuncs.CVarGetPointer("sk_plr_grapple");

        self.FallInit();
    }

	int iItemSlot(void) { return 1; }
	void EndAttack( void )
    {
        m_fireState = OFF;
        self.SendWeaponAnim( BGRAPPLE_FIRERELEASE );

        g_SoundSystem.EmitSound(self.edict(), CHAN_WEAPON, "weapons/bgrapple_release.wav", 1, ATTN_NORM);

        g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "weapons/bgrapple_pull.wav", 0.0, ATTN_NONE, SND_STOP, 100 );

        self.m_flTimeWeaponIdle = g_Engine.time + 0.9;

        self.m_flNextPrimaryAttack = g_Engine.time + 0.01;

        DestroyEffect();

        if( m_bGrappling && m_pPlayer.IsAlive() )
        {
            m_pPlayer.SetAnimation( PLAYER_IDLE );
        }

        m_pPlayer.pev.movetype = MOVETYPE_WALK;
        m_pPlayer.pev.flags &= ~(FL_IMMUNE_SLIME);
        m_pPlayer.m_afPhysicsFlags &= ~PFLAG_GRAPPLE;
    }
    
    bool PlayEmptySound()
    {
        if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;
		}
		
		return false;
    }
    
    void Touch(CBaseEntity@ _Other) {
        BaseClass.Touch(_Other);
        if (m_flLastBounceSoundTime + 0.2f < g_Engine.time && self.pev.velocity != g_vecZero) {
            g_SoundSystem.StopSound(self.edict(), CHAN_ITEM, "items/weapondrop1.wav");
            g_SoundSystem.PlaySound(self.edict(), CHAN_ITEM, "items/weapondrop1.wav", 0.01, ATTN_NORM, SND_STOP | SND_CHANGE_VOL | SND_CHANGE_PITCH, PITCH_NORM, 1, true, self.pev.origin);
            g_SoundSystem.PlaySound(self.edict(), CHAN_VOICE, "debris/flesh5.wav", 0.95, ATTN_NORM, 0, PITCH_HIGH, 1, true, self.pev.origin);
            m_flLastBounceSoundTime = g_Engine.time;
        }
    }
    
    bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1		= -1;
		info.iMaxAmmo2		= -1;
        info.iAmmo1Drop     = -1;
        info.iAmmo2Drop     = -1;
		info.iMaxClip		= WEAPON_NOCLIP;
		info.iSlot			= 0;
		info.iPosition		= 8;
		info.iWeight		= 0;
        info.iFlags         = ITEM_FLAG_ESSENTIAL;
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
	bool Deploy()
    {
        bool r = self.DefaultDeploy(self.GetV_Model("models/scanarchy/v_bgrap.mdl"), self.GetP_Model("models/scanarchy/p_bgrap.mdl"), BGRAPPLE_UP, "hive" );
        self.m_flTimeWeaponIdle = g_Engine.time + 1.1;
        return r;
    }
	void Holster( int skiplocal /* = 0 */ )
    {
        m_pPlayer.m_flNextAttack = g_Engine.time + 0.5;

        if( m_fireState != OFF )
            EndAttack();

        self.SendWeaponAnim( BGRAPPLE_DOWN );
    }
	void WeaponIdle( void )
    {
        self.ResetEmptySound();

        if( self.m_flTimeWeaponIdle > g_Engine.time )
            return;

        if( m_fireState != OFF )
        {
            EndAttack();
            return;
        }

        m_bMissed = false;

        const float flNextIdle = Math.RandomFloat( 0.0, 1.0 );

        int iAnim;

        if( flNextIdle <= 0.5 )
        {
            iAnim = BGRAPPLE_LONGIDLE;
            self.m_flTimeWeaponIdle = g_Engine.time + 10.0;
        }
        else if( flNextIdle > 0.95 )
        {
            g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_STATIC, "weapons/bgrapple_cough.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM );

            iAnim = BGRAPPLE_COUGH;
            self.m_flTimeWeaponIdle = g_Engine.time + 4.6;
        }
        else
        {
            iAnim = BGRAPPLE_BREATHE;
            self.m_flTimeWeaponIdle = g_Engine.time + 2.566;
        }

        self.SendWeaponAnim( iAnim );
    }
    void SecondaryAttack( void )
    {
        m_bMode = !m_bMode;
        if (m_bMode) {
            g_PlayerFuncs.ClientPrint(m_pPlayer, HUD_PRINTCENTER, "Rappelling Mode");
        } else {
            g_PlayerFuncs.ClientPrint(m_pPlayer, HUD_PRINTCENTER, "Pull Mode");
        }
        self.m_flNextSecondaryAttack = g_Engine.time + 0.5f;
    }
    void PrimaryAttack( void )
    {
        if( m_bMissed )
        {
            self.m_flTimeWeaponIdle = g_Engine.time + 0.1;
            return;
        }

        g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );
        if( m_pTip !is null)
        {
            if( m_pTip.IsStuck() )
            {
                CBaseEntity@ pTarget = m_pTip.GetGrappleTarget().GetEntity();

                if( pTarget is null || (!pTarget.IsBSPModel() && !pTarget.IsAlive()) )
                {
                    EndAttack();
                    return;
                }

                if( m_pTip.GetGrappleType() > GRAPPLE_SMALL )
                {
                    //m_pPlayer.pev.movetype = MOVETYPE_FLY;
                    m_pPlayer.pev.flags |= FL_IMMUNE_SLIME;
                    //Tells the physics code that the player is not on a ladder - Solokiller
                }

                if( m_bMomentaryStuck )
                {
                    self.SendWeaponAnim( BGRAPPLE_FIRETRAVEL );

                    g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_STATIC, "weapons/bgrapple_impact.wav", 0.98, ATTN_NORM, 0, 125 );

                    if( pTarget.IsPlayer() )
                    {
                        g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_STATIC,"weapons/bgrapple_impact.wav", 0.98, ATTN_NORM, 0, 125 );
                    }

                    m_bMomentaryStuck = false;
                }

                switch( m_pTip.GetGrappleType() )
                {
                case GRAPPLE_NOT_A_TARGET: break;

                case GRAPPLE_SMALL:
                    //pTarget.BarnacleVictimGrabbed( this );
                    m_pTip.pev.origin = pTarget.Center();

                    pTarget.pev.velocity = pTarget.pev.velocity + ( m_pPlayer.pev.origin - pTarget.pev.origin );

                    if( pTarget.pev.velocity.Length() > 450.0 )
                    {
                        pTarget.pev.velocity = pTarget.pev.velocity.Normalize() * 450.0;
                    }

                    break;

                case GRAPPLE_MEDIUM:
                case GRAPPLE_LARGE:
                case GRAPPLE_FIXED:
                    //pTarget.BarnacleVictimGrabbed( this );

                    if( m_pTip.GetGrappleType() != GRAPPLE_FIXED )
                        g_EntityFuncs.SetOrigin( m_pTip.self, pTarget.Center() );

                    if (!m_bMode)
                        m_pPlayer.pev.velocity = m_pPlayer.pev.velocity + ( m_pTip.pev.origin - m_pPlayer.pev.origin );

                    if( m_pPlayer.pev.velocity.Length() > 450.0 )
                    {
                        m_pPlayer.pev.velocity = m_pPlayer.pev.velocity.Normalize() * 450.0;

                        Vector vecPitch = Math.VecToAngles( m_pPlayer.pev.velocity );

                        if( (vecPitch.x > 55.0 && vecPitch.x < 205.0) || vecPitch.x < -55.0 )
                        {
                            m_bGrappling = false;
                            m_pPlayer.SetAnimation( PLAYER_IDLE );
                        }
                        else
                        {
                            if (!m_bGrappling)
                                g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "weapons/bgrapple_pull.wav", 0.98, ATTN_NORM, 0, 125 );
                            m_bGrappling = true;
                            m_pPlayer.m_afPhysicsFlags |= PFLAG_GRAPPLE;
                        }
                    }
                    else
                    {
                        m_bGrappling = false;
                        m_pPlayer.SetAnimation( PLAYER_IDLE );
                    }

                    break;
                }
            }

            if( m_pTip.HasMissed() )
            {
                g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "weapons/bgrapple_release.wav", 0.98, ATTN_NORM, 0, 125 );

                EndAttack();
                return;
            }
        }
        if( m_fireState != OFF )
        {
            m_pPlayer.m_iWeaponVolume = 450;

            if( m_flShootTime != 0.0 && g_Engine.time > m_flShootTime )
            {
                self.SendWeaponAnim( BGRAPPLE_FIREWAITING );

                Vector vecPunchAngle = m_pPlayer.pev.punchangle;

                vecPunchAngle.x += 2.0;

                m_pPlayer.pev.punchangle = vecPunchAngle;

                Fire( m_pPlayer.GetGunPosition(), g_Engine.v_forward );
                g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "weapons/bgrapple_pull.wav", 0.98, ATTN_NORM, 0, 125 );
                m_flShootTime = 0;
            }
        }
        else
        {
            m_bMomentaryStuck = true;

            self.SendWeaponAnim( BGRAPPLE_FIRE );

            m_pPlayer.m_iWeaponVolume = 450;

            self.m_flTimeWeaponIdle = g_Engine.time + 0.1;
            /*if( g_pGameRules.IsMultiplayer() )
            {
                m_flShootTime = g_Engine.time;
            }
            else
            {*/
                m_flShootTime = g_Engine.time + 0.35;
            //}
            g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "weapons/bgrapple_fire.wav", 0.98, ATTN_NORM, 0, 125 );
            m_fireState = CHARGE;
        }

        if( m_pTip is null )
        {
            self.m_flNextPrimaryAttack = g_Engine.time + 0.1;
            return;
        }

        if( m_pTip.GetGrappleType() != GRAPPLE_FIXED && m_pTip.IsStuck() )
        {
            g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle );

            Vector vecSrc = m_pPlayer.GetGunPosition();

            Vector vecEnd = vecSrc + g_Engine.v_forward * 16.0;

            TraceResult tr;

            g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

            if( tr.flFraction >= 1.0 )
            {
                g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
                if( tr.flFraction < 1.0 )
                {
                    CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
    /*
                    if( !pHit )
                        pHit = CWorld::GetInstance();

                    if( !pHit )
                    {
                        FindHullIntersection( vecSrc, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer );
                    }
    */
                }
            }

            if( tr.flFraction < 1.0 )
            {
                CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
    /*
                if( !pHit )
                    pHit = CWorld::GetInstance();
    */
                m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

                if( pHit !is null )
                {
                    if( m_pTip !is null )
                    {
                        bool bValidTarget = false;
                        if( pHit.IsPlayer() )
                        {
                            m_pTip.SetGrappleTarget( @pHit );
                            bValidTarget = true;
                        }
                        else if( m_pTip.CheckTarget( @pHit ) != GRAPPLE_NOT_A_TARGET )
                        {
                            bValidTarget = true;
                        }
                        if( bValidTarget )
                        {
                            if( m_flDamageTime + 0.5 < g_Engine.time )
                            {
                                g_WeaponFuncs.ClearMultiDamage();

                                float flDamage = m_pDamage.value;//gSkillData.plrDmgGrapple;

                                //if( g_pGameRules.IsMultiplayer() )
                                //{
                                    flDamage *= 2;
                                //}

                                pHit.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_CLUB );

                                g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

                                m_flDamageTime = g_Engine.time;

                                string pszSample;

                                switch( Math.RandomLong( 0, 2 ) )
                                {
                                case 0: pszSample = "barnacle/bcl_chew1.wav"; break;
                                case 1: pszSample = "barnacle/bcl_chew2.wav"; break;
                                case 2: pszSample = "barnacle/bcl_chew3.wav"; break;
                                }
                                g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_VOICE, pszSample, VOL_NORM, ATTN_NORM, 0, 125 );
                            }
                        }
                    }
                }
            }
        }

        //TODO: CTF support - Solokiller
        /*
        if( g_pGameRules.IsMultiplayer() && g_pGameRules.IsCTF() )
        {
            m_flNextPrimaryAttack = g_Engine.time;
        }
        else
        */
        {
            self.m_flNextPrimaryAttack = g_Engine.time + 0.01;
        }
    }

	void Fire( const Vector& in vecOrigin, const Vector& in vecDir )
    {
        Vector vecSrc = vecOrigin;

        Vector vecEnd = vecSrc + vecDir * 2048.0;

        TraceResult tr;

        g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

        if( tr.fAllSolid == 0 )
        {
            CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
    /*
            if( !pHit )
                pHit = CWorld::GetInstance();
    */
            if( pHit !is null )
            {
                UpdateEffect();

                m_flDamageTime = g_Engine.time;
            }
        }
    }

	void CreateEffect( void )
    {
        DestroyEffect();

        //m_pTip = GetClassPtr((CBarnacleGrappleTip *)NULL);
        CBaseEntity@ pEntity = g_EntityFuncs.Create("sca_grapple_tip", g_vecZero, g_vecZero, true, null);
        @m_pTip = cast<CBarnacleGrappleTip@>(CastToScriptClass(pEntity));
        m_pTip.Spawn();

        g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle );

        Vector vecOrigin =
            m_pPlayer.GetGunPosition() +
            g_Engine.v_forward * 16.0 +
            g_Engine.v_right * 8.0 +
            g_Engine.v_up * -8.0;

        Vector vecAngles = m_pPlayer.pev.v_angle;

        vecAngles.x = -vecAngles.x;

        m_pTip.SetPosition( vecOrigin, vecAngles, m_pPlayer );

        if( m_pBeam is null )
        {
            @m_pBeam = g_EntityFuncs.CreateBeam( "sprites/tongue.spr", 16 );

            m_pBeam.EntsInit( m_pTip.self.entindex(), m_pPlayer.entindex() );

            m_pBeam.SetFlags( BEAM_FSOLID );

            m_pBeam.SetBrightness( 100.0 );

            m_pBeam.SetEndAttachment( 1 );

            m_pBeam.pev.spawnflags |= SF_BEAM_TEMPORARY;
        }
    }
	void UpdateEffect( void )
    {
        if( m_pBeam is null || m_pTip is null )
            CreateEffect();
    }
	void DestroyEffect( void )
    {
        if( m_pBeam !is null)
        {
            g_EntityFuncs.Remove( m_pBeam );
            @m_pBeam = null;
        }
        if( m_pTip !is null)
        {
            m_pTip.self.Killed( null, GIB_NEVER );
            @m_pTip = null;
        }
    }

	bool UseDecrement(void)
	{
		return false;
	}

    FireState m_fireState;
	CBarnacleGrappleTip@ m_pTip;

	CBeam@ m_pBeam;

	float m_flShootTime;
	float m_flDamageTime;

	bool m_bGrappling;
	bool m_bMissed;
	bool m_bMomentaryStuck;
};

void Register() {
    g_CustomEntityFuncs.RegisterCustomEntity("HLOPFORGRAPPLE::CBarnacleGrappleTip", "sca_grapple_tip");
    g_CustomEntityFuncs.RegisterCustomEntity("HLOPFORGRAPPLE::CBarnacleGrapple", "weapon_hlopfor_grapple");
    g_ItemRegistry.RegisterWeapon("weapon_hlopfor_grapple", "scanarchy", "", "", "", "");
}

}