namespace SCGRENADE {

enum eModelsMode {
    kDefaultClassic = 0,
    kBlueShift,
    kOpposingForce
}

int g_eModelsMode = kDefaultClassic;

string g_VeeMdl			= "models/hlclassic/v_grenade.mdl";

string g_lpszCustomGrenadeClassName = "monster_hlc_grenade";

class CCustomGrenade : ScriptBaseMonsterEntity {
    bool m_bRegisteredSound = false;
    bool m_bHasDelayedTheExplosion = false;
	
	void Spawn() {
		Precache();
		
		self.pev.movetype = MOVETYPE_BOUNCE;
		self.pev.solid = SOLID_BBOX;
        
        g_EntityFuncs.SetModel(self, "models/hlclassic/grenade.mdl");
		g_EntityFuncs.SetSize(self.pev, g_vecZero, g_vecZero);
		
		self.pev.dmg = 100;
		m_bRegisteredSound = false;
        m_bHasDelayedTheExplosion = false;
	}
    
    bool IsRevivable() {
        return false;
    }
	
	void Precache() {
		g_Game.PrecacheModel("models/hlclassic/w_grenade.mdl");
		g_Game.PrecacheModel("models/hlclassic/grenade.mdl");
		g_Game.PrecacheModel("models/cretegibs.mdl");
		
		g_SoundSystem.PrecacheSound("hlclassic/weapons/grenade_hit1.wav");
		g_SoundSystem.PrecacheSound("hlclassic/weapons/grenade_hit2.wav");
		g_SoundSystem.PrecacheSound("hlclassic/weapons/grenade_hit3.wav");
	}
	
	void BounceTouch(CBaseEntity@ pOther) {
		if (pOther.edict() is self.pev.owner)
			return;
            
		entvars_t@ pevOwner = self.pev.owner.vars;
		if (pevOwner !is null) {
			TraceResult tr = g_Utility.GetGlobalTrace();
			g_WeaponFuncs.ClearMultiDamage();
			pOther.TraceAttack(pevOwner, 1, g_Engine.v_forward, tr, DMG_GENERIC); //DMG_BLAST); //DMG_BLAST gives the victim velocity on touch, no!
			g_WeaponFuncs.ApplyMultiDamage(self.pev, pevOwner);
		}
		
		Vector vecTestVelocity;
		
		vecTestVelocity = self.pev.velocity; 
		vecTestVelocity.z *= 0.45;
		
		if (!m_bRegisteredSound && vecTestVelocity.Length() <= 60) {
			CBaseEntity@ pOwner = g_EntityFuncs.Instance(self.pev.owner);
			CSoundEnt@ soundEnt = GetSoundEntInstance();
			soundEnt.InsertSound(bits_SOUND_DANGER, self.pev.origin, int(self.pev.dmg / 0.4), 0.3, pOwner);
			m_bRegisteredSound = true;
		}
		
		if ((self.pev.flags & FL_ONGROUND) == 0) {
			// play bounce sound
			BounceSound();
		}
		
		self.pev.framerate = self.pev.velocity.Length() / 200.0;
		if (self.pev.framerate > 1.0)
			self.pev.framerate = 1;
		else if (self.pev.framerate < 0.5)
			self.pev.framerate = 0;
	}
    
	void TumbleThink() {
		if (!self.IsInWorld()) {
			g_EntityFuncs.Remove(self);
			return;
		}
		
		self.StudioFrameAdvance();
		self.pev.nextthink = g_Engine.time + 0.1;
        
        if ((self.pev.flags & FL_ONGROUND) != 0) {
            self.pev.velocity.x *= 0.9f;
            self.pev.velocity.y *= 0.9f;
        
			self.pev.sequence = 1;
        }
		
		if (self.pev.dmgtime - 1 < g_Engine.time) {
			CBaseEntity@ pOwner = g_EntityFuncs.Instance(self.pev.owner);
			CSoundEnt@ soundEnt = GetSoundEntInstance();
			soundEnt.InsertSound(bits_SOUND_DANGER, self.pev.origin + self.pev.velocity * (self.pev.dmgtime - g_Engine.time), 400, 0.1, pOwner);
            
            if (!m_bHasDelayedTheExplosion && (self.pev.flags & FL_ONGROUND) != 0) {
                array<CBaseEntity@> pMonsters(g_EngineFuncs.NumberOfEntities());
                Vector vecMins = self.pev.origin - Vector(64.f, 64.f, 64.f);
                Vector vecMaxs = self.pev.origin + Vector(64.f, 64.f, 64.f);
                int nMonstersInSphere = g_EntityFuncs.EntitiesInBox(@pMonsters, vecMins, vecMaxs, 0);
                CBaseEntity@ pValidMonster = null;
                for (int idx = 0; idx < nMonstersInSphere; idx++) {
                    CBaseEntity@ pMonster = pMonsters[idx];
                    if (!pMonster.IsPlayer()) continue;
                    self.pev.dmgtime += 2.f;
                    m_bHasDelayedTheExplosion = true;
                    break;
                }
            }
		}
		
		if (self.pev.dmgtime <= g_Engine.time) {
			SetThink(ThinkFunction(Detonate));
		}
		if (self.pev.waterlevel != 0) {
			self.pev.velocity = self.pev.velocity * 0.5;
			self.pev.framerate = 0.2;
		}
	}
	
	void Detonate() {
		TraceResult tr;
		Vector vecSpot;
		
		vecSpot = self.pev.origin + Vector (0, 0, 8);
		g_Utility.TraceLine(vecSpot, vecSpot + Vector (0, 0, -40), ignore_monsters, self.edict(), tr);
		
		g_EntityFuncs.CreateExplosion(tr.vecEndPos, Vector(0, 0, -90), self.pev.owner, int(self.pev.dmg), false);
		g_WeaponFuncs.RadiusDamage(tr.vecEndPos, self.pev, self.pev.owner.vars, self.pev.dmg, (self.pev.dmg * 3.0), CLASS_NONE, DMG_BLAST);
		
		g_EntityFuncs.Remove(self);
	}
	
	void BounceSound() {
		switch (Math.RandomLong(0, 2)) {
			case 0:	g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "hlclassic/weapons/grenade_hit1.wav", 0.25, ATTN_NORM); break;
			case 1:	g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "hlclassic/weapons/grenade_hit2.wav", 0.25, ATTN_NORM); break;
			case 2:	g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "hlclassic/weapons/grenade_hit3.wav", 0.25, ATTN_NORM); break;
		}
	}
	
	void cSetTouch() {
		SetTouch(TouchFunction(BounceTouch));
	}
	
	void cSetThink() {
		SetThink(ThinkFunction(TumbleThink));
	}
}

CBaseEntity@ UTIL_ShootGrenade(edict_t@ _Owner, Vector _Origin, Vector _Velo, float _PinTime) {
    CBaseEntity@ pTheNade = g_EntityFuncs.Create(g_lpszCustomGrenadeClassName, _Origin, _Owner.vars.angles, false, _Owner);
	CCustomGrenade@ pGrenade = cast<CCustomGrenade@>(CastToScriptClass(pTheNade));
    @pTheNade.pev.owner = @_Owner;
    //pTheNade.Spawn();
    g_EntityFuncs.DispatchSpawn(pTheNade.edict());
	pGrenade.pev.origin = _Origin;
	pGrenade.pev.velocity = _Velo;
	g_EngineFuncs.VecToAngles(pGrenade.pev.velocity, pGrenade.pev.angles);
	
	pGrenade.cSetTouch(); // Bounce if touched
	
	pGrenade.pev.dmgtime = g_Engine.time + _PinTime;
	pGrenade.cSetThink();
	pGrenade.pev.nextthink = g_Engine.time + 0.1f;
	if (_PinTime < 0.1f) {
		pGrenade.pev.nextthink = g_Engine.time;
		pGrenade.pev.velocity = g_vecZero;
	}
	
	pGrenade.pev.sequence = Math.RandomLong(3, 6);
	pGrenade.pev.framerate = 1.0f;
	
	pGrenade.pev.gravity = 0.6f;
	pGrenade.pev.friction = 0.8f;
	
	pGrenade.pev.model = string_t("models/hlclassic/w_grenade.mdl");
    g_EntityFuncs.SetModel(pGrenade.self, "models/hlclassic/w_grenade.mdl");
	pGrenade.pev.dmg = 100;
    
    return pTheNade;
}

const uint HANDGRENADE_PRIMARY_VOLUME = 450;

enum handgrenade_e {
	HANDGRENADE_IDLE = 0,
	HANDGRENADE_FIDGET,
	HANDGRENADE_PINPULL,
	HANDGRENADE_THROW1,	// toss
	HANDGRENADE_THROW2,	// medium
	HANDGRENADE_THROW3,	// hard
	HANDGRENADE_HOLSTER,
	HANDGRENADE_DRAW
};

class CHLCHandGrenade : ScriptBasePlayerWeaponEntity {
    private CBasePlayer@ m_pPlayer
    {
        get const   { return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
        set         { self.m_hPlayer = EHandle( @value ); }
    }
    
    float m_flLastBounceSoundTime;
    
	void Spawn( )
    {
        Precache( );
        g_EntityFuncs.SetModel(self, "models/hlclassic/w_grenade.mdl");
        
		g_Game.PrecacheGeneric( "sprites/scanarchy/weapon_hldm_handgrenade.txt" );

        self.pev.dmg = g_EngineFuncs.CVarGetFloat("sk_plr_hand_grenade");

        m_flLastBounceSoundTime = 0.f;

        self.m_iDefaultAmmo = 5;

        self.FallInit();// get ready to fall down.
    }
    
	void Precache( void ) {
        BaseClass.Precache();
        self.PrecacheCustomModels();
    
        g_Game.PrecacheModel("models/hlclassic/w_grenade.mdl");
        g_Game.PrecacheModel(g_VeeMdl);
        g_Game.PrecacheModel("models/hlclassic/p_grenade.mdl");
        g_Game.PrecacheOther("monster_hlc_grenade");
    }
    
	int iItemSlot( void ) { return 5; }
    
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
    
	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= 10;
		info.iAmmo1Drop = 1;
		info.iMaxAmmo2	= -1;
		info.iAmmo2Drop	= -1;
		info.iMaxClip 	= WEAPON_NOCLIP;
		info.iSlot 		= 4;
		info.iPosition 	= 4;
		info.iWeight 	= 5;
        info.iFlags     = ITEM_FLAG_LIMITINWORLD | ITEM_FLAG_EXHAUSTIBLE;
        info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);

		return true;
	}
    
    bool CanHaveDuplicates()
	{
		return true;
	}
    
    bool Deploy( )
    {
        m_flReleaseThrow = -1;
        return self.DefaultDeploy( self.GetV_Model(g_VeeMdl), self.GetP_Model("models/hlclassic/p_grenade.mdl"), HANDGRENADE_DRAW, "crowbar" );
    }

    bool CanHolster( void )
    {
        // can only holster hand grenades when not primed!
        return ( m_flStartThrow == 0 );
    }
    
    void Holster( )
    {
        m_pPlayer.m_flNextAttack = g_Engine.time + 0.5;
        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0)
        {
            self.SendWeaponAnim( HANDGRENADE_HOLSTER );
        }
        else
        {
            // no more grenades!
            m_pPlayer.pev.weapons &= ~(1<<WEAPON_HANDGRENADE);
            SetThink( ThinkFunction(self.DestroyItem) );
            self.pev.nextthink = g_Engine.time + 0.1;
        }

        g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_WEAPON, "common/null.wav", 1.0, ATTN_NORM);
    }

	void PrimaryAttack()
    {
        if (m_flStartThrow == 0 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0)
        {
            m_flStartThrow = g_Engine.time;
            m_flReleaseThrow = 0;

            self.SendWeaponAnim( HANDGRENADE_PINPULL );
            self.m_flTimeWeaponIdle = g_Engine.time + 0.5;
        }
    }
    
    void Touch(CBaseEntity@ _Other) {
        BaseClass.Touch(_Other);
        if (m_flLastBounceSoundTime + 0.2f < g_Engine.time) {
            if (self.pev.velocity != g_vecZero) {
                g_SoundSystem.StopSound(self.edict(), CHAN_ITEM, "items/weapondrop1.wav");
                g_SoundSystem.PlaySound(self.edict(), CHAN_ITEM, "items/weapondrop1.wav", 0.01, ATTN_NORM, SND_STOP | SND_CHANGE_VOL | SND_CHANGE_PITCH, PITCH_NORM, 1, true, self.pev.origin);
                TraceResult tr;
                g_Utility.TraceLine(self.pev.origin, self.pev.origin - Vector(0, 0, 8192), dont_ignore_monsters, self.edict(), tr);
                float flDistance = (self.pev.origin - tr.vecEndPos).Length();
                if (flDistance < 10.f) {
                    g_SoundSystem.PlaySound(self.edict(), CHAN_VOICE, "hlclassic/weapons/grenade_hit3.wav", 1.0, ATTN_NORM, 0, PITCH_HIGH, 1, true, self.pev.origin);
                    m_flLastBounceSoundTime = g_Engine.time;
                }
            }
        }
    }
    
    string GetBounceSound() {
        return "weapons/grenade_hit3.wav";
    }

    void WeaponIdle( void )
    {
        if (m_flReleaseThrow == 0)
            m_flReleaseThrow = g_Engine.time;

        if (self.m_flTimeWeaponIdle > g_Engine.time)
            return;

        if (m_flStartThrow != 0)
        {
            Vector angThrow = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;

            if (angThrow.x < 0)
                angThrow.x = -10 + angThrow.x * ((90 - 10) / 90.0);
            else
                angThrow.x = -10 + angThrow.x * ((90 + 10) / 90.0);

            float flVel = (90 - angThrow.x) * 4;
            if (flVel > 500)
                flVel = 500;

            g_EngineFuncs.MakeVectors( angThrow );

            Vector vecSrc = m_pPlayer.pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_forward * 16;

            Vector vecThrow = g_Engine.v_forward * flVel + m_pPlayer.pev.velocity;

            // alway explode 3 seconds after the pin was pulled
            float time = m_flStartThrow - g_Engine.time + 3.0;
            if (time < 0)
                time = 0;
                
            UTIL_ShootGrenade(m_pPlayer.edict(), vecSrc, vecThrow, time);

            //CGrenade::ShootTimed( m_pPlayer.pev, vecSrc, vecThrow, time );

            if (flVel < 500)
            {
                self.SendWeaponAnim( HANDGRENADE_THROW1 );
            }
            else if (flVel < 1000)
            {
                self.SendWeaponAnim( HANDGRENADE_THROW2 );
            }
            else
            {
                self.SendWeaponAnim( HANDGRENADE_THROW3 );
            }

            // player "shoot" animation
            m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

            m_flStartThrow = 0;
            self.m_flNextPrimaryAttack = g_Engine.time + 0.5;
            self.m_flTimeWeaponIdle = g_Engine.time + 0.5;

            m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 1);

            if ( m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0 )
            {
                // just threw last grenade
                // set attack times in the future, and weapon idle in the future so we can see the whole throw
                // animation, weapon idle will automatically retire the weapon for us.
                self.m_flTimeWeaponIdle = self.m_flNextSecondaryAttack = self.m_flNextPrimaryAttack = g_Engine.time + 0.5;// ensure that the animation can finish playing
            }
            return;
        }
        else if (m_flReleaseThrow > 0)
        {
            // we've finished the throw, restart.
            m_flStartThrow = 0;

            if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) != 0)
            {
                self.SendWeaponAnim( HANDGRENADE_DRAW );
            }
            else
            {
                self.RetireWeapon();
                return;
            }

            self.m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat( 10, 15 );
            m_flReleaseThrow = -1;
            return;
        }

        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) != 0)
        {
            int iAnim;
            float flRand = Math.RandomFloat(0, 1);
            if (flRand <= 0.75)
            {
                iAnim = HANDGRENADE_IDLE;
                self.m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat ( 10, 15 );// how long till we do this again.
            }
            else 
            {
                iAnim = HANDGRENADE_FIDGET;
                self.m_flTimeWeaponIdle = g_Engine.time + 75.0 / 30.0;
            }

            self.SendWeaponAnim( iAnim );
        }
    }
    
	float m_flStartThrow;
	float m_flReleaseThrow;
}

void Register()
{
    if (g_eModelsMode == kOpposingForce) {
        g_VeeMdl = "models/scanarchy/opfor/v_grenade.mdl";
    } else if (g_eModelsMode == kBlueShift) {
        g_VeeMdl = "models/scanarchy/bshift/v_grenade.mdl";
    }
    
	g_CustomEntityFuncs.RegisterCustomEntity( "SCGRENADE::CCustomGrenade", g_lpszCustomGrenadeClassName );
	g_CustomEntityFuncs.RegisterCustomEntity( "SCGRENADE::CHLCHandGrenade", "weapon_hldm_handgrenade" );
	g_ItemRegistry.RegisterWeapon( "weapon_hldm_handgrenade", "scanarchy", "Hand Grenade", "", "weapon_hldm_handgrenade", "" );
}

}