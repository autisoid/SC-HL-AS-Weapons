namespace HLOPFORWRENCH {
const uint MELEE_WALLHIT_VOLUME = 512;
const uint MELEE_BODYHIT_VOLUME = 128;

const uint PIPEWRENCH_ATTACK2_MIN_DAMAGE = 45;
const uint PIPEWRENCH_ATTACK2_MAX_DAMAGE = 200;

enum pwrench_e {
	PIPEWRENCH_IDLE1 = 0,
	PIPEWRENCH_IDLE2,
	PIPEWRENCH_IDLE3,
	PIPEWRENCH_DRAW,
	PIPEWRENCH_HOLSTER,
	PIPEWRENCH_ATTACK1HIT,
	PIPEWRENCH_ATTACK1MISS,
	PIPEWRENCH_ATTACK2HIT,
	PIPEWRENCH_ATTACK2MISS,
	PIPEWRENCH_ATTACK3HIT,
	PIPEWRENCH_ATTACK3MISS,
	PIPEWRENCH_ATTACKBIGWIND,
	PIPEWRENCH_ATTACKBIGHIT,
	PIPEWRENCH_ATTACKBIGMISS,
	PIPEWRENCH_ATTACKBIGLOOP,
};

const Cvar@ g_pDamagePtr;

array<CScheduledFunction@> g_rgpfnLoops(33);

void DoWrenchHoldLoop(EHandle _Player, float _LastFrame, EHandle _Weapon) {
    if (!_Player.IsValid()) {
        return;
    }
    if (!_Weapon.IsValid()) {
        return;
    }
    CBasePlayerWeapon@ pBaseWeapon = cast<CBasePlayerWeapon@>(_Weapon.GetEntity());
    CHLCPipeWrench@ pWeapon = cast<CHLCPipeWrench@>(CastToScriptClass(pBaseWeapon));
    if (pWeapon is null or pWeapon.m_pPlayer is null) {
        return;
    }
    if (pWeapon.m_nStage > 2)
        return;
    if (pWeapon.m_nStage == 2 && pWeapon.m_flBigSwingEnd + 1.1f < g_Engine.time) {
        pWeapon.m_nStage = 3;
        return;
    }
    
    CBasePlayer@ lpPlayer = cast<CBasePlayer@>(_Player.GetEntity());
    if (lpPlayer is null or !lpPlayer.IsConnected()) {
        return;
    }
    
    CBaseMonster@ lpTarget = cast<CBaseMonster@>(_Player.GetEntity());
    if (lpTarget is null) {
        return;
    }
    
    if (!lpPlayer.IsAlive()) {
        return;
    }
    
    //lpTarget.pev.gaitsequence = 0;
    
    bool bIsSequencePlaying = (pWeapon.m_nStage == 0 ? lpTarget.pev.sequence == 25 : pWeapon.m_nStage == 1 ? lpTarget.pev.sequence == 26 : lpTarget.pev.sequence == 27);
    
    if (!bIsSequencePlaying) {
        if (lpTarget.pev.framerate >= 0.f && _LastFrame <= 0.f) {
            _LastFrame = 0.f;
        }
        
        _LastFrame = 0.f;
                
        if (lpTarget.pev.framerate >= 0.f && _LastFrame >= 255.f) {
            _LastFrame = 255.f;
        } else if (lpTarget.pev.framerate < 0.f && _LastFrame <= 255.f + 0.1f) {
            _LastFrame = 255.f;
        }
        
        lpTarget.m_Activity = ACT_RELOAD;
        lpTarget.m_GaitActivity = ACT_RELOAD;
        lpTarget.m_IdealActivity = ACT_RELOAD;
        lpTarget.m_movementActivity = ACT_RELOAD;
        lpTarget.pev.sequence = (pWeapon.m_nStage == 0 ? 25 : pWeapon.m_nStage == 1 ? 26 : 27);
        lpTarget.pev.frame = _LastFrame;
        lpTarget.ResetSequenceInfo();
        lpTarget.ResetGaitSequenceInfo();
        lpTarget.pev.framerate = 1.f;
    } else {
        bool bLoopFinished = lpTarget.pev.framerate > 0.f ? (lpTarget.pev.frame - 255.f > 0.01f) : (255.f - lpTarget.pev.frame > 0.01f);
            
        if (!bLoopFinished) {
            _LastFrame = lpTarget.pev.frame;
            
            if (lpTarget.pev.framerate >= 0.f && _LastFrame >= 255.f) {
                _LastFrame = lpTarget.pev.frame = 0.f;
            } else if (lpTarget.pev.framerate < 0.f && _LastFrame <= 255.f + 0.1f) {
                _LastFrame = lpTarget.pev.frame = 0.f;
            }
            
            lpTarget.m_flLastEventCheck = g_Engine.time + 1.0f;
            lpTarget.m_flLastGaitEventCheck = g_Engine.time + 1.0f;
            
            if (_LastFrame <= 0.f)
                _LastFrame = 0.00001f;
            if (_LastFrame >= 255.f)
                _LastFrame = 254.9999f;
        } else {
            if (pWeapon.m_nStage == 2) {
                pWeapon.m_nStage = 3;
                return;
            }
        }
    }
        
    @g_rgpfnLoops[lpPlayer.entindex()] = g_Scheduler.SetTimeout("DoWrenchHoldLoop", 0, EHandle(lpPlayer), _LastFrame, EHandle(pBaseWeapon));
}

class CHLCPipeWrench : ScriptBasePlayerWeaponEntity {
	int m_iSwing;
	TraceResult m_trHit;
	int m_iSwingMode;
	float m_flBigSwingStart;
    int m_nStage;
    float m_flBigSwingEnd;

	CBasePlayer@ m_pPlayer
	{
		get const 	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set       	{ self.m_hPlayer = EHandle( @value ); }
	}

    void Precache() {
        BaseClass.Precache();
        self.PrecacheCustomModels();
        
		g_Game.PrecacheGeneric( "sprites/scanarchy/weapon_hlopfor_pipewrench.txt" );

        g_Game.PrecacheModel("models/scanarchy/v_pipe_wrench.mdl");
        g_Game.PrecacheModel("models/scanarchy/w_pipe_wrench.mdl");
        g_Game.PrecacheModel("models/scanarchy/p_pipe_wrench.mdl");

        g_SoundSystem.PrecacheSound("weapons/pwrench_hit1.wav");
        g_SoundSystem.PrecacheSound("weapons/pwrench_hit2.wav");
        g_SoundSystem.PrecacheSound("weapons/pwrench_hitbod1.wav");
        g_SoundSystem.PrecacheSound("weapons/pwrench_hitbod2.wav");
        g_SoundSystem.PrecacheSound("weapons/pwrench_hitbod3.wav");
        g_SoundSystem.PrecacheSound("weapons/pwrench_miss1.wav");
        g_SoundSystem.PrecacheSound("weapons/pwrench_miss2.wav");

        g_SoundSystem.PrecacheSound("weapons/pwrench_big_hitbod1.wav");
        g_SoundSystem.PrecacheSound("weapons/pwrench_big_hitbod2.wav");
        g_SoundSystem.PrecacheSound("weapons/pwrench_big_miss.wav");
    }
    
    void Spawn()
    {
        Precache();
        g_EntityFuncs.SetModel(self, "models/scanarchy/w_pipe_wrench.mdl");
        m_iSwingMode = 0;
        self.m_iClip = -1;
        
        @g_pDamagePtr = g_EngineFuncs.CVarGetPointer("sk_plr_wrench");

        self.FallInit();// get ready to fall down.
    }
    
    bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1		= -1;
		info.iMaxAmmo2		= -1;
        info.iAmmo1Drop     = -1;
        info.iAmmo2Drop     = -1;
		info.iMaxClip		= WEAPON_NOCLIP;
		info.iSlot			= 0;
		info.iPosition		= 6;
		info.iWeight		= 10;
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
        m_iSwingMode = 0;
        return self.DefaultDeploy(self.GetV_Model("models/scanarchy/v_pipe_wrench.mdl"), self.GetP_Model("models/scanarchy/p_pipe_wrench.mdl"), PIPEWRENCH_DRAW, "crowbar");
    }
    
    void Holster(int skiplocal = 0)
    {
        m_iSwingMode = 0;
        m_pPlayer.m_flNextAttack = g_Engine.time + 0.5;
        self.SendWeaponAnim(PIPEWRENCH_HOLSTER);
    }
    
    void PrimaryAttack()
    {
        if (m_iSwingMode == 0 && !Swing(true))
        {
            SetThink(ThinkFunction(SwingAgain));
            self.pev.nextthink = g_Engine.time + 0.1;
        }
    }

    void SecondaryAttack(void)
    {
        if (m_iSwingMode != 1)
        {
            self.SendWeaponAnim(PIPEWRENCH_ATTACKBIGWIND);
            m_flBigSwingStart = g_Engine.time;
            m_nStage = 0;
            @g_rgpfnLoops[m_pPlayer.entindex()] = g_Scheduler.SetTimeout("DoWrenchHoldLoop", 0, EHandle(m_pPlayer), 0.f, EHandle(self));
        } else if (m_flBigSwingStart + 0.8f < g_Engine.time) {
            m_nStage = 1;
        }
        m_iSwingMode = 1;
        self.m_flTimeWeaponIdle = g_Engine.time + 0.3;
        self.m_flNextSecondaryAttack = g_Engine.time + 0.1;
    }
    
    void WeaponIdle(void)
    {
        if ( m_iSwingMode == 1 )
        {
            if ( g_Engine.time > m_flBigSwingStart + 1.0 )
            {
                m_iSwingMode = 2;
            }
        }
        else if (m_iSwingMode == 2)
        {
            self.m_flNextSecondaryAttack = self.m_flNextPrimaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 1.1;
            BigSwing();
            m_iSwingMode = 0;
            return;
        }
        else
        {
            m_iSwingMode = 0;
            if ( self.m_flTimeWeaponIdle > g_Engine.time )
                return;
            int iAnim;
            float flRand = g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 0.0, 1.0 );

            if ( flRand <= 0.3 )
            {
                iAnim = PIPEWRENCH_IDLE1;
                self.m_flTimeWeaponIdle = g_Engine.time + 2.0;
            }
            else if ( flRand <= 0.6 )
            {
                iAnim = PIPEWRENCH_IDLE2;
                self.m_flTimeWeaponIdle = g_Engine.time + 3.0;
            }
            else
            {
                iAnim = PIPEWRENCH_IDLE3;
                self.m_flTimeWeaponIdle = g_Engine.time + 3.0;
            }
            self.SendWeaponAnim( iAnim );
        }
    }

    void SwingAgain(void)
    {
        Swing(false);
    }

    void Smack()
    {
        g_WeaponFuncs.DecalGunshot(m_trHit, BULLET_PLAYER_CROWBAR);
    }
    
    bool Swing(bool fFirst)
    {
        bool fDidHit = false;

        TraceResult tr;

        g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle );
        Vector vecSrc	= m_pPlayer.GetGunPosition( );
        Vector vecEnd	= vecSrc + g_Engine.v_forward * 32;

        g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

        if ( tr.flFraction >= 1.0 )
        {
            g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
            if ( tr.flFraction < 1.0 )
            {
                // Calculate the point of intersection of the line (or hull) and the object we hit
                // This is and approximation of the "best" intersection
                CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
                if ( pHit is null || pHit.IsBSPModel() )
                    g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );
                vecEnd = tr.vecEndPos;	// This is the point on the actual surface (the hull could have hit space)
            }
        }
        
        if (fFirst)
        {
            switch( ((m_iSwing++) % 2) + 1 )
            {
            case 0:
                self.SendWeaponAnim( PIPEWRENCH_ATTACK1MISS );
                break;
            case 1:
                self.SendWeaponAnim( PIPEWRENCH_ATTACK2MISS );
                break;
            case 2:
                self.SendWeaponAnim( PIPEWRENCH_ATTACK3MISS );
                break;
            }
            if (Math.RandomLong(0, 1) == 0) {
                g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_ITEM, "weapons/pwrench_miss1.wav", 1, ATTN_NORM);
            } else {
                g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_ITEM, "weapons/pwrench_miss2.wav", 1, ATTN_NORM);
            }
        }

        if ( tr.flFraction >= 1.0 )
        {
            // miss
            if ( fFirst ) {
                self.m_flNextPrimaryAttack = g_Engine.time + 0.7;
                self.m_flNextSecondaryAttack = g_Engine.time + 0.7;
                self.m_flTimeWeaponIdle = g_Engine.time + 5.0;
                // player "shoot" animation
                m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
            }
        }
        else
        {
            switch( ((m_iSwing++) % 2) + 1 )
            {
            case 0:
                self.SendWeaponAnim( PIPEWRENCH_ATTACK1HIT );
                break;
            case 1:
                self.SendWeaponAnim( PIPEWRENCH_ATTACK2HIT );
                break;
            case 2:
                self.SendWeaponAnim( PIPEWRENCH_ATTACK3HIT );
                break;
            }

            // player "shoot" animation
            m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

            // hit
            fDidHit = true;
            CBaseEntity@ pEntity = g_EntityFuncs.Instance(tr.pHit);

            // play thwack, smack, or dong sound
            float flVol = 1.0;
            bool fHitWorld = true;

            if( pEntity !is null)
            {
                g_WeaponFuncs.ClearMultiDamage();
                float flDamage = g_pDamagePtr.value;
                
                // Send trace attack to player.
                pEntity.TraceAttack(m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_CLUB);

                g_WeaponFuncs.ApplyMultiDamage(m_pPlayer.pev, m_pPlayer.pev);

                if ( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE )
                {
                    // play thwack or smack sound
                    switch( Math.RandomLong(0,2) )
                    {
                    case 0:
                        g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_ITEM, "weapons/pwrench_hitbod1.wav", 1, ATTN_NORM); break;
                    case 1:
                        g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_ITEM, "weapons/pwrench_hitbod2.wav", 1, ATTN_NORM); break;
                    case 2:
                        g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_ITEM, "weapons/pwrench_hitbod3.wav", 1, ATTN_NORM); break;
                    }
                    m_pPlayer.m_iWeaponVolume = MELEE_BODYHIT_VOLUME;
                    if ( !pEntity.IsAlive() )
                    {
                        self.m_flNextPrimaryAttack = g_Engine.time + 0.5;
                        return true;
                    }
                    else
                          flVol = 0.1;

                    fHitWorld = false;
                }
            }

            // play texture hit sound
            // UNDONE: Calculate the correct point of intersection when we hit with the hull instead of the line

            if( fHitWorld )
            {
                // also play pipe wrench strike
                switch( Math.RandomLong(0,1) )
                {
                case 0:
                    g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, "weapons/pwrench_hit1.wav", 1, ATTN_NORM, 0, 98 + Math.RandomLong(0,3));
                    break;
                case 1:
                    g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, "weapons/pwrench_hit2.wav", 1, ATTN_NORM, 0, 98 + Math.RandomLong(0,3));
                    break;
                }

                // delay the decal a bit
                m_trHit = tr;
            }

            m_pPlayer.m_iWeaponVolume = int( flVol * MELEE_WALLHIT_VOLUME );

            SetThink( ThinkFunction(Smack) );
            self.pev.nextthink = g_Engine.time + 0.2;
            self.m_flNextPrimaryAttack = g_Engine.time + 0.5;
            self.m_flNextSecondaryAttack = g_Engine.time + 0.5;
        }
        self.m_flTimeWeaponIdle = g_Engine.time + 5.0;
        return fDidHit;
    }
    
    void BigSwing(void)
    {
        TraceResult tr;

        g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle );
        Vector vecSrc	= m_pPlayer.GetGunPosition( );
        Vector vecEnd	= vecSrc + g_Engine.v_forward * 32;

        g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

        if ( tr.flFraction >= 1.0 )
        {
            g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
            if ( tr.flFraction < 1.0 )
            {
                // Calculate the point of intersection of the line (or hull) and the object we hit
                // This is and approximation of the "best" intersection
                CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
                if ( pHit is null || pHit.IsBSPModel() )
                    g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );
                vecEnd = tr.vecEndPos;	// This is the point on the actual surface (the hull could have hit space)
            }
        }
        
        /*PLAYBACK_EVENT_FULL( FEV_NOTHOST, m_pPlayer->edict(), m_usPWrench,
            0.0,
            (float*)&g_vecZero,
            (float*)&g_vecZero,
            0, 0, 0, 0, 0, 0 );*/
        self.SendWeaponAnim( PIPEWRENCH_ATTACKBIGHIT );

        g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "weapons/pwrench_big_miss.wav", 0.8, ATTN_NORM);

        //m_pPlayer.pev.punchangle.x -= 2;
        if ( tr.flFraction >= 1.0 )
        {
            // player "shoot" animation
            m_nStage = 2;
            m_flBigSwingEnd = g_Engine.time;
            //m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
        }
        else
        {
            self.SendWeaponAnim( PIPEWRENCH_ATTACKBIGHIT );

            // player "shoot" animation
            m_nStage = 2;
            m_flBigSwingEnd = g_Engine.time;
            //m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

            // hit
            CBaseEntity@ pEntity = g_EntityFuncs.Instance(tr.pHit);

            if( pEntity !is null)
            {
                g_WeaponFuncs.ClearMultiDamage();
                float flDamage = (g_Engine.time - m_flBigSwingStart) * g_pDamagePtr.value + 25.0f;
                if (flDamage > PIPEWRENCH_ATTACK2_MAX_DAMAGE) {
                    flDamage = PIPEWRENCH_ATTACK2_MAX_DAMAGE;
                }
                pEntity.TraceAttack(m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_CLUB);

                g_WeaponFuncs.ApplyMultiDamage(m_pPlayer.pev, m_pPlayer.pev);
            }

            // play thwack, smack, or dong sound
            float flVol = 1.0;
            bool fHitWorld = true;

            if (pEntity !is null)
            {
                if (pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE)
                {
                    // play thwack or smack sound
                    switch( Math.RandomLong(0,1) )
                    {
                    case 0:
                        g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_ITEM, "weapons/pwrench_big_hitbod1.wav", 1, ATTN_NORM);
                        break;
                    case 1:
                        g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_ITEM, "weapons/pwrench_big_hitbod2.wav", 1, ATTN_NORM);
                        break;
                    }
                    m_pPlayer.m_iWeaponVolume = MELEE_BODYHIT_VOLUME;
                    if ( !pEntity.IsAlive() )
                          return;
                    else
                          flVol = 0.1;

                    fHitWorld = false;
                }
            }

            // play texture hit sound
            if( fHitWorld )
            {

                switch( Math.RandomLong(0,1) )
                {
                case 0:
                    g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, "weapons/pwrench_hit1.wav", 1, ATTN_NORM, 0, 98 + Math.RandomLong(0,3));
                    break;
                case 1:
                    g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, "weapons/pwrench_hit2.wav", 1, ATTN_NORM, 0, 98 + Math.RandomLong(0,3));
                    break;
                }

                // delay the decal a bit
                m_trHit = tr;
            }

            m_pPlayer.m_iWeaponVolume = int( flVol * MELEE_WALLHIT_VOLUME );
        }
    }
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "HLOPFORWRENCH::CHLCPipeWrench", "weapon_hlopfor_pipewrench" );
	g_ItemRegistry.RegisterWeapon( "weapon_hlopfor_pipewrench", "scanarchy" );
}

} // End of namespace