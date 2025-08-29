namespace HLCEgon
{

const string g_WeaponName           = "weapon_hldm_egon";

// Weapon info
const uint g_MaxCarry               = 100;
const uint g_Weight                 = 20;
const uint g_DefaultGive            = 20;
const string g_PriAmmoType          = "uranium";

uint g_Slot = 3;
uint g_Position = 6;

enum EGON_FIRESTATE { FIRE_OFF, FIRE_CHARGE };
enum EGON_FIREMODE { FIRE_NARROW, FIRE_WIDE};

enum egon_e {
	EGON_IDLE1 = 0,
	EGON_FIDGET1,
	EGON_ALTFIREON,
	EGON_ALTFIRECYCLE,
	EGON_ALTFIREOFF,
	EGON_FIRE1,
	EGON_FIRE2,
	EGON_FIRE3,
	EGON_FIRE4,
	EGON_DRAW,
	EGON_HOLSTER
};

string g_VeeMdl		= "models/hlclassic/v_egon.mdl";

enum eModelsMode {
    kDefaultClassic = 0,
    kBlueShift,
    kOpposingForce
}

int g_eModelsMode = kDefaultClassic;

array<int> g_aiFireAnims1 = { EGON_FIRE1, EGON_FIRE2, EGON_FIRE3, EGON_FIRE4 };
array<int> g_aiFireAnims2 = { EGON_ALTFIRECYCLE };

float fabsf(float _Value) {
    return _Value < 0.f ? _Value * -1.f : _Value;
}

class CHLCHLDMEgon : ScriptBasePlayerWeaponEntity {
    private CBasePlayer@ m_pPlayer {
		get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
		set { self.m_hPlayer = EHandle(@value); }
	}

	void Spawn() {
        BaseClass.Spawn();
        Precache();
        g_EntityFuncs.SetModel(self, self.GetW_Model("models/hlclassic/w_egon.mdl"));

        self.m_iDefaultAmmo = g_DefaultGive;

        self.FallInit();// get ready to fall down.
    }
    
	void Precache() {
        BaseClass.Precache();
        self.PrecacheCustomModels();
        
		g_Game.PrecacheGeneric( "sprites/scanarchy/weapon_hldm_egon.txt" );
        
        g_Game.PrecacheModel("models/hlclassic/w_egon.mdl");
        g_Game.PrecacheModel(g_VeeMdl);
        g_Game.PrecacheModel("models/hlclassic/p_egon.mdl");

        g_Game.PrecacheModel("models/w_9mmclip.mdl");
        g_SoundSystem.PrecacheSound("hlclassic/items/9mmclip1.wav");

        g_SoundSystem.PrecacheSound("hlclassic/weapons/egon_off1.wav");
        g_SoundSystem.PrecacheSound("hlclassic/weapons/egon_run3.wav");
        g_SoundSystem.PrecacheSound("hlclassic/weapons/egon_windup2.wav");

        g_Game.PrecacheModel("sprites/xbeam1.spr");
        g_Game.PrecacheModel("sprites/XSpark1.spr");

        g_SoundSystem.PrecacheSound("hlclassic/weapons/357_cock1.wav");
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
    
	int iItemSlot() { return 4; }
    
    bool GetItemInfo(ItemInfo& out _Info) {
        _Info.iMaxAmmo1 = g_MaxCarry;
        _Info.iMaxAmmo2 = -1;
        _Info.iMaxClip = WEAPON_NOCLIP;
        _Info.iSlot = g_Slot;
        _Info.iPosition  = g_Position;
        _Info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);
        _Info.iWeight = g_Weight;
        _Info.iAmmo1Drop = 20;
        
        return true;
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

	bool Deploy() {
        m_bDeployed = false;
        return self.DefaultDeploy(self.GetV_Model(g_VeeMdl), self.GetP_Model("models/hlclassic/p_egon.mdl"), EGON_DRAW, "egon");
    }
    
	void Holster(int iSkipLocal = 0) {
        m_pPlayer.m_flNextAttack = g_Engine.time + 0.5f;
        // m_flTimeWeaponIdle = gpGlobals->time + UTIL_RandomFloat ( 10, 15 );
        self.SendWeaponAnim(EGON_HOLSTER);
        
        if (m_eFireState != FIRE_OFF)
            EndAttack();
    }
    
    bool CanHolster() {
        return m_eFireState == FIRE_OFF;
    }

	void DestroyEffect() {
     	if (m_pBeam !is null) {
            g_EntityFuncs.Remove(m_pBeam);
            @m_pBeam = null;
        }
        if (m_pNoise !is null) {
            g_EntityFuncs.Remove( m_pNoise );
            @m_pNoise = null;
        }
        if (m_pSprite !is null) {
            if (m_eFireMode == FIRE_WIDE)
                m_pSprite.Expand(10.f, 500.f);
            else
                g_EntityFuncs.Remove(m_pSprite);
            @m_pSprite = null;
        }   
    }
    
	void UpdateEffect(const Vector& in _StartPoint, const Vector& in _EndPoint, float _TimeBlend) {
        if (m_pBeam is null) {
            CreateEffect();
        }

        m_pBeam.SetStartPos(_EndPoint);
        m_pBeam.SetBrightness(int(255.f - (_TimeBlend * 180.f)));
        m_pBeam.SetWidth(int(40.f - (_TimeBlend * 20.f)));

        if (m_eFireMode == FIRE_WIDE)
            m_pBeam.SetColor(int(30.f + (25.f * _TimeBlend)), int(30.f + (30.f * _TimeBlend)), int(64.f + 80.f * fabsf(sin(g_Engine.time * 10.f))));
        else
            m_pBeam.SetColor(int(60.f + (25.f * _TimeBlend)), int(120.f + (30.f * _TimeBlend)), int(64.f + 80.f * fabsf(sin(g_Engine.time * 10.f))));


        g_EntityFuncs.SetOrigin(m_pSprite, _EndPoint);
        m_pSprite.pev.frame += 8.f * g_Engine.frametime;
        if (m_pSprite.pev.frame > m_pSprite.Frames())
            m_pSprite.pev.frame = 0.f;

        m_pNoise.SetStartPos(_EndPoint);
    }
    
	void CreateEffect() {
        DestroyEffect();

        @m_pBeam = g_EntityFuncs.CreateBeam("sprites/xbeam1.spr", 40.f);
        m_pBeam.PointEntInit(self.pev.origin, m_pPlayer.entindex());
        m_pBeam.SetFlags(BEAM_FSINE);
        m_pBeam.SetEndAttachment(1);
        m_pBeam.pev.spawnflags |= SF_BEAM_TEMPORARY; // Flag these to be destroyed on save/restore or level transition

        @m_pNoise = g_EntityFuncs.CreateBeam("sprites/xbeam1.spr", 55.f);
        m_pNoise.PointEntInit(self.pev.origin, m_pPlayer.entindex());
        m_pNoise.SetScrollRate(25);
        m_pNoise.SetBrightness(100);
        m_pNoise.SetEndAttachment(1);
        m_pNoise.pev.spawnflags |= SF_BEAM_TEMPORARY;

        @m_pSprite = g_EntityFuncs.CreateSprite("sprites/XSpark1.spr", self.pev.origin, false);
        m_pSprite.pev.scale = 1.f;
        m_pSprite.SetTransparency(kRenderGlow, 255, 255, 255, 255, kRenderFxNoDissipation);
        m_pSprite.pev.spawnflags |= 0x8000; //SF_SPRITE_TEMPORARY;

        if (m_eFireMode == FIRE_WIDE) {
            m_pBeam.SetScrollRate(50);
            m_pBeam.SetNoise(20);
            m_pNoise.SetColor(50, 50, 255);
            m_pNoise.SetNoise(8);
        } else {
            m_pBeam.SetScrollRate(110);
            m_pBeam.SetNoise(5);
            m_pNoise.SetColor(80, 120, 255);
            m_pNoise.SetNoise(2);
        }
    }

	void EndAttack() {
        g_SoundSystem.StopSound(m_pPlayer.edict(), CHAN_STATIC, "hlclassic/weapons/egon_run3.wav");
        g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/egon_off1.wav", 0.98f, ATTN_NORM, 0, 100); 
        m_eFireState = FIRE_OFF;
        self.m_flTimeWeaponIdle = g_Engine.time + 2.f;
        self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.5f;
        DestroyEffect();
    }
    
    /*
    void SecondaryAttack() {
        self.SendWeaponAnim(EGON_FIDGET1);
        m_eFireMode = (m_eFireMode == FIRE_NARROW ? FIRE_WIDE : FIRE_NARROW);
        self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 2.0f;
    }
    */
    
	void Attack() {
        // don't fire underwater
        if (m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD)  {
            if (m_pBeam !is null) {
                EndAttack();
            } else {
                self.PlayEmptySound();
            }
            return;
        }

        Math.MakeVectors(m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle);
        Vector vecAiming = g_Engine.v_forward;
        Vector vecSrc = m_pPlayer.GetGunPosition();

        switch (m_eFireState) {
            case FIRE_OFF: {
                if (!HasAmmo()) {
                    self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.25f;
                    self.PlayEmptySound();
                    return;
                }

                m_flAmmoUseTime = g_Engine.time;// start using ammo ASAP.

                self.SendWeaponAnim(g_aiFireAnims1[Math.RandomLong(0, g_aiFireAnims1.length() - 1)]);
                m_flShakeTime = 0.f;

                m_pPlayer.m_iWeaponVolume = 450;
                self.m_flTimeWeaponIdle = g_Engine.time + 0.1f;
                m_flShootTime = g_Engine.time + 2.f;

                if (m_eFireMode == FIRE_WIDE) {
                    g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/egon_windup2.wav", 0.98f, ATTN_NORM, 0, 125);
                } else  {
                    g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/egon_windup2.wav", 0.9f, ATTN_NORM, 0, 100);
                }

                self.pev.dmgtime = g_Engine.time + GetPulseInterval();
                m_eFireState = FIRE_CHARGE;
            }
            break;

            case FIRE_CHARGE: {
                Fire(vecSrc, vecAiming);
                m_pPlayer.m_iWeaponVolume = 450;

                if (m_flShootTime != 0.f && g_Engine.time > m_flShootTime) {
                    if (m_eFireMode == FIRE_WIDE) {
                        g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_STATIC, "hlclassic/weapons/egon_run3.wav", 0.98f, ATTN_NORM, 0, 125 );
                    } else {
                        g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_STATIC, "hlclassic/weapons/egon_run3.wav", 0.9f, ATTN_NORM, 0, 100 );
                    }

                    m_flShootTime = 0.f;
                }
                if (!HasAmmo()) {
                    EndAttack();
                    m_eFireState = FIRE_OFF;
                    self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 1.f;
                }

            }
            break;
        }
    }
    
	void PrimaryAttack() {
        m_eFireMode = FIRE_WIDE;
        Attack();
    }
    
	void WeaponIdle() {
        self.ResetEmptySound();

        if (self.m_flTimeWeaponIdle > g_Engine.time)
            return;

        if (m_eFireState != FIRE_OFF)
            EndAttack();

        int iAnim;

        float flRand = Math.RandomFloat(0.f, 1.f);

        if (flRand <= 0.5) {
            iAnim = EGON_IDLE1;
            self.m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat(10.f, 15.f);
        } else {
            iAnim = EGON_FIDGET1;
            self.m_flTimeWeaponIdle = g_Engine.time + 3.f;
        }

        self.SendWeaponAnim(iAnim);
        m_bDeployed = true;
    }

	float m_flAmmoUseTime;// since we use < 1 point of ammo per update, we subtract ammo on a timer.

	float GetPulseInterval() {
        return 0.1f;
    }
    
	float GetDischargeInterval() {
        return 0.1f;
    }

	void Fire(const Vector& in _OrigSrc, const Vector& in _Dir) {
        Vector vecDest = _OrigSrc + _Dir * 2048.f;
        TraceResult tr;

        Vector tmpSrc = _OrigSrc + g_Engine.v_up * -8.f + g_Engine.v_right * 3.f;

        g_Utility.TraceLine(_OrigSrc, vecDest, dont_ignore_monsters, m_pPlayer.edict(), tr);

        if (tr.fAllSolid != 0)
            return;

        CBaseEntity@ pEntity = g_EntityFuncs.Instance(tr.pHit);

        if (pEntity is null)
            return;

        if (m_pSprite !is null && (pEntity.pev.takedamage > DAMAGE_NO)) {
            m_pSprite.pev.effects &= ~EF_NODRAW;
        } else if (m_pSprite !is null) {
            m_pSprite.pev.effects |= EF_NODRAW;
        }

        float flTimeDist;

        switch (m_eFireMode) {
            case FIRE_NARROW: {
                if (self.pev.dmgtime < g_Engine.time) {
                    // Narrow mode only does damage to the entity it hits
                    g_WeaponFuncs.ClearMultiDamage();
                    if (pEntity.pev.takedamage > DAMAGE_NO) {
                        pEntity.TraceAttack(m_pPlayer.pev, 6.f, _Dir, tr, DMG_ENERGYBEAM);
                    }
                    g_WeaponFuncs.ApplyMultiDamage(m_pPlayer.pev, m_pPlayer.pev);

                    // multiplayer uses 1 ammo every 1/10th second
                    if (g_Engine.time >= m_flAmmoUseTime) {
                        UseAmmo(1);
                        m_flAmmoUseTime = g_Engine.time + 0.1f;
                    }

                    self.pev.dmgtime = g_Engine.time + GetPulseInterval();
                }
                flTimeDist = (self.pev.dmgtime - g_Engine.time) / GetPulseInterval();
            }
                break;
            case FIRE_WIDE: {
                if (self.pev.dmgtime < g_Engine.time) {
                    // wide mode does damage to the ent, and radius damage
                    g_WeaponFuncs.ClearMultiDamage();
                    if (pEntity.pev.takedamage > DAMAGE_NO) {
                        pEntity.TraceAttack(m_pPlayer.pev, 14.f, _Dir, tr, DMG_ENERGYBEAM | DMG_ALWAYSGIB);
                    }
                    g_WeaponFuncs.ApplyMultiDamage(m_pPlayer.pev, m_pPlayer.pev);

                    // radius damage a little more potent in multiplayer.
                    g_WeaponFuncs.RadiusDamage(tr.vecEndPos, self.pev, m_pPlayer.pev, (14.f / 4.f), 128, CLASS_NONE, DMG_ENERGYBEAM | DMG_BLAST | DMG_ALWAYSGIB);
                    
                    if (!m_pPlayer.IsAlive())
                        return;

                    //multiplayer uses 5 ammo/second
                    if (g_Engine.time >= m_flAmmoUseTime) {
                        UseAmmo(1);
                        m_flAmmoUseTime = g_Engine.time + 0.2f;
                    }

                    self.pev.dmgtime = g_Engine.time + GetDischargeInterval();
                    if (m_flShakeTime < g_Engine.time) {
                        g_PlayerFuncs.ScreenShake(tr.vecEndPos, 5.0, 150.0, 0.75, 250.0);
                        m_flShakeTime = g_Engine.time + 1.5f;
                    }
                }
                flTimeDist = (self.pev.dmgtime - g_Engine.time) / GetDischargeInterval();
            }
                break;
        }

        if (flTimeDist < 0.f)
            flTimeDist = 0.f;
        else if (flTimeDist > 1.f)
            flTimeDist = 1.f;
        flTimeDist = 1.f - flTimeDist;

        UpdateEffect(tmpSrc, tr.vecEndPos, flTimeDist);
    }

	bool HasAmmo() {
		if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
			return false;
		return true;
	}

	void UseAmmo(int _Count) {
		if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) >= _Count)
			m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - _Count);
		else
			m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, 0);
	}

	float m_flShootTime;
	CBeam@ m_pBeam;
	CBeam@ m_pNoise;
	CSprite@ m_pSprite;
	EGON_FIRESTATE m_eFireState;
	EGON_FIREMODE m_eFireMode;
	float m_flShakeTime;
	bool m_bDeployed;
};

void Register()
{
    if (g_eModelsMode == kOpposingForce) {
        g_VeeMdl = "models/scanarchy/opfor/v_egon.mdl";
    } else if (g_eModelsMode == kBlueShift) {
        g_VeeMdl = "models/scanarchy/bshift/v_egon.mdl";
    }
    
    g_CustomEntityFuncs.RegisterCustomEntity("HLCEgon::CHLCHLDMEgon", HLCEgon::g_WeaponName);
    g_ItemRegistry.RegisterWeapon(HLCEgon::g_WeaponName, "scanarchy", HLCEgon::g_PriAmmoType, "", "ammo_gaussclip", "");
}

}