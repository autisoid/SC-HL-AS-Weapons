namespace HLOPFORDISPLACER {

enum DisplacerAnim {
    DISPLACER_IDLE1 = 0,
    DISPLACER_IDLE2,
    DISPLACER_SPINUP,
    DISPLACER_SPIN,
    DISPLACER_FIRE,
    DISPLACER_DRAW,
    DISPLACER_HOLSTER1
};

enum EDisplacerMode {
    kStarted = 0,
    kSpinningUp,
    kSpinning,
    kFired
};

enum EDisplacerSecondaryAttackMode {
    kDefault = 0,
    kMultipleDestinations
};

Vector g_vecInvalidTeleportDestination(16777215.f, 16777215.f, 16777215.f);
array<Vector> g_rgvecTeleportDestination;
array<Vector> g_rgvecTeleportDestinationAngles;

void InitialiseTeleportDestinations() {
    g_rgvecTeleportDestination.resize(0);
    g_rgvecTeleportDestination.resize(33);
    g_rgvecTeleportDestinationAngles.resize(0);
    g_rgvecTeleportDestinationAngles.resize(33);

    for (uint idx = 0; idx < g_rgvecTeleportDestination.length(); idx++) {
        g_rgvecTeleportDestination[idx] = g_vecInvalidTeleportDestination;
    } 
    for (uint idx = 0; idx < g_rgvecTeleportDestinationAngles.length(); idx++) {
        g_rgvecTeleportDestinationAngles[idx] = g_vecZero;
    }
}

void Register() {
    InitialiseTeleportDestinations();
    g_CustomEntityFuncs.RegisterCustomEntity("HLOPFORDISPLACER::CHLCDisplacer", "weapon_hlopfor_displacer");
    g_CustomEntityFuncs.RegisterCustomEntity("HLOPFORDISPLACER::CTriggerDisplacerDestinationPointSpecification", "trigger_displacer_destination_point_spec");
    g_ItemRegistry.RegisterWeapon("weapon_hlopfor_displacer", "scanarchy", "uranium", "", "ammo_gaussclip", "");
}

CBaseEntity@ UTIL_CreateDisplacerBall(const Vector& in _Origin, const Vector& in _Angles, CBaseEntity@ _Owner) {
    CBaseEntity@ pBall = g_EntityFuncs.Create("displacer_portal", g_vecZero, g_vecZero, true, _Owner.edict());

    g_EntityFuncs.SetOrigin(pBall, _Origin);

    Vector vecNewAngles = _Angles;

    vecNewAngles.x = vecNewAngles.x * -1.f;

    pBall.pev.angles = vecNewAngles;

    Math.MakeVectors(_Angles);

    pBall.pev.velocity = g_Engine.v_forward * 500.f;
    pBall.pev.dmg = 250.f;
    pBall.pev.fuser1 = 300.f; //radius
    pBall.pev.vuser1 = pBall.pev.velocity;

    g_EntityFuncs.DispatchSpawn(pBall.edict());

    return pBall;
}

class CHLCDisplacer : ScriptBasePlayerWeaponEntity {
    private CBasePlayer@ m_pPlayer {
        get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
        set { self.m_hPlayer = EHandle(@value); }
    }
    
    EDisplacerSecondaryAttackMode m_eSecondaryAttackMode = kDefault;

    void Precache() {
        BaseClass.Precache();
        self.PrecacheCustomModels();
        
		g_Game.PrecacheGeneric( "sprites/scanarchy/weapon_hlopfor_displacer.txt" );
        
        g_Game.PrecacheModel("models/scanarchy/v_displacer.mdl");
        g_Game.PrecacheModel("models/scanarchy/w_displacer.mdl");
        g_Game.PrecacheModel("models/scanarchy/p_displacer.mdl");

        g_SoundSystem.PrecacheSound("weapons/displacer_fire.wav");
        g_SoundSystem.PrecacheSound("weapons/displacer_self.wav");
        g_SoundSystem.PrecacheSound("weapons/displacer_spin.wav");
        g_SoundSystem.PrecacheSound("weapons/displacer_spin2.wav");

        g_SoundSystem.PrecacheSound("buttons/button11.wav");

        g_Game.PrecacheOther("displacer_portal");
    }

    void Spawn() {
        BaseClass.Spawn();
        Precache();

        g_EntityFuncs.SetModel(self, self.GetW_Model("models/scanarchy/w_displacer.mdl"));

        self.m_iDefaultAmmo = 40;

        self.FallInit();
    }

    bool Deploy() {
        return self.DefaultDeploy(self.GetV_Model("models/scanarchy/v_displacer.mdl"), self.GetP_Model("models/scanarchy/p_displacer.mdl"), DISPLACER_DRAW, "egon");
    } 

    void Holster(int skiplocal = 0) {
        self.m_fInReload = false;

        g_SoundSystem.StopSound(m_pPlayer.edict(), CHAN_WEAPON, "weapons/displacer_spin.wav");

        m_pPlayer.m_flNextAttack = g_Engine.time + 1.f;

        self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 0.f, 5.f);

        self.SendWeaponAnim(DISPLACER_HOLSTER1);
        SetThink(null);
        
        BaseClass.Holster(skiplocal);
    }

    void WeaponIdle() {
        self.ResetEmptySound();

        m_pPlayer.GetAutoaimVector(AUTOAIM_10DEGREES);

        if (m_flSoundDelay != 0.f && g_Engine.time >= m_flSoundDelay)
            m_flSoundDelay = 0.f;

        if (self.m_flTimeWeaponIdle <= g_Engine.time) {
            float flNextIdle = Math.RandomFloat(0.f, 1.f);

            int iAnim;

            if (flNextIdle <= 0.5) {
                iAnim = DISPLACER_IDLE1;
                self.m_flTimeWeaponIdle = g_Engine.time + 3.f;
            } else {
                iAnim = DISPLACER_IDLE2;
                self.m_flTimeWeaponIdle = g_Engine.time + 3.f;
            }

            self.SendWeaponAnim(iAnim);
        }
    }

    void PrimaryAttack() {
        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) >= 20) {
            SetThink(ThinkFunction(SpinupThink));

            self.pev.nextthink = g_Engine.time;

            m_eMode = kStarted;

            g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_WEAPON, "weapons/displacer_spin.wav", Math.RandomFloat(0.8f, 0.9f), ATTN_NORM);

            self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 2.5f;
        } else {
            g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_WEAPON, "buttons/button11.wav", Math.RandomFloat(0.8f, 0.9f), ATTN_NORM);

            self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.5f;
        }
    }
    
    CBasePlayerItem@ DropItem() {
        SetThink(null);
        return self;
    }

    void SecondaryAttack() {
        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) >= 60) {
            SetThink(ThinkFunction(AltSpinupThink));

            self.pev.nextthink = g_Engine.time;

            m_eMode = kStarted;

            g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_WEAPON, "weapons/displacer_spin2.wav", Math.RandomFloat(0.8f, 0.9f), ATTN_NORM);

            self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 1.5f;
        } else {
            g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_WEAPON, "buttons/button11.wav", Math.RandomFloat(0.8f, 0.9f), ATTN_NORM);

            self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.5f;
        }
    }

    void Reload() {
        //Do nothing.
    }

    void SpinupThink() {
        if (m_pPlayer is null) return;
    
        if (m_eMode == kStarted) {
            self.SendWeaponAnim(DISPLACER_SPINUP);

            m_eMode = kSpinningUp;

            m_flStartTime = g_Engine.time;
            m_iSoundState = 0;
        }

        if (m_eMode <= kSpinningUp) {
            if (g_Engine.time > m_flStartTime + 0.9) {
                m_eMode = kSpinning;

                SetThink(ThinkFunction(FireThink));

                self.pev.nextthink = g_Engine.time + 0.1f;
            }

            m_iImplodeCounter = int((g_Engine.time - m_flStartTime) * 100.f + 50.f);
        }

        if (m_iImplodeCounter > 250)
            m_iImplodeCounter = 250;

        m_iSoundState = 128;

        self.pev.nextthink = g_Engine.time + 0.1f;
    }

    void AltSpinupThink() {
        if (m_pPlayer is null) return;
        
        if (m_eMode == kStarted) {
            self.SendWeaponAnim(DISPLACER_SPINUP);

            m_eMode = kSpinningUp;

            m_flStartTime = g_Engine.time;
            m_iSoundState = 0;
        }

        if (m_eMode <= kSpinningUp) {
            if (g_Engine.time > m_flStartTime + 0.9f) {
                m_eMode = kSpinning;

                SetThink(ThinkFunction(AltFireThink));

                self.pev.nextthink = g_Engine.time + 0.1f;
            }

            m_iImplodeCounter = int((g_Engine.time - m_flStartTime) * 100.f + 50.f);
        }

        if (m_iImplodeCounter > 250)
            m_iImplodeCounter = 250;

        m_iSoundState = 128;

        self.pev.nextthink = g_Engine.time + 0.1f;
    }

    void FireThink() {
        if (m_pPlayer is null) return;
        
        m_pPlayer.m_iWeaponVolume = 1000; //LOUD_GUN_VOLUME
        m_pPlayer.m_iWeaponFlash = 512; //BRIGHT_GUN_FLASH;

        self.SendWeaponAnim(DISPLACER_FIRE);

        m_pPlayer.SetAnimation(PLAYER_ATTACK1);

        m_pPlayer.pev.effects |= EF_MUZZLEFLASH;

        g_SoundSystem.EmitSound(self.edict(), CHAN_WEAPON, "weapons/displacer_fire.wav", Math.RandomFloat(0.8f, 0.9f), ATTN_NORM);

        const Vector vecAnglesAim = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;

        Math.MakeVectors(vecAnglesAim);

        Vector vecSrc = m_pPlayer.GetGunPosition();

        //Update auto-aim
        //m_pPlayer.GetAutoaimVectorFromPoint(vecSrc, AUTOAIM_10DEGREES);

        UTIL_CreateDisplacerBall(vecSrc, vecAnglesAim, m_pPlayer);
        
        m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 20);

        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0) {
            m_pPlayer.SetSuitUpdate("!HEV_AMO0", false, 0); //false == SUIT_SENTENCE, 0 == SUIT_REPEAT_OK
        }

        SetThink(null);
    }

    void AltFireThink() {
        if (m_pPlayer is null) return;
        
        g_SoundSystem.StopSound(m_pPlayer.edict(), CHAN_WEAPON, "weapons/displacer_spin.wav");

        if (m_eSecondaryAttackMode == kMultipleDestinations) {
            Vector vecOriginalLocation = m_pPlayer.pev.origin;

            Vector vecDestination = g_rgvecTeleportDestination[m_pPlayer.entindex()];
            Vector vecAngles = g_rgvecTeleportDestinationAngles[m_pPlayer.entindex()];

            if (vecDestination != g_vecInvalidTeleportDestination) {
                m_pPlayer.pev.flags &= ~FL_SKIPLOCALHOST;

                //Vector vecNewOrigin = vecDestination;
                //vecNewOrigin.z += 37.f; //?????? ~ xWhitey

                g_EntityFuncs.SetOrigin(m_pPlayer, vecDestination);

                m_pPlayer.pev.angles = vecAngles;

                m_pPlayer.pev.v_angle = vecAngles;

                m_pPlayer.pev.fixangle = 1;

                m_pPlayer.pev.basevelocity = g_vecZero;
                m_pPlayer.pev.velocity = g_vecZero;

                self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 2.f;

                SetThink(null);

                m_pPlayer.m_iWeaponVolume = 1000; //LOUD_GUN_VOLUME
                m_pPlayer.m_iWeaponFlash = 512; //BRIGHT_GUN_FLASH

                m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 60);

                UTIL_CreateDisplacerBall(vecOriginalLocation, Vector(90, 0, 0), m_pPlayer);

                if (self.m_iClip == 0) {
                    if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0) {
                        m_pPlayer.SetSuitUpdate("!HEV_AMO0", false, 0); //false == SUIT_SENTENCE, 0 == SUIT_REPEAT_OK
                    }
                }

                self.m_flTimeWeaponIdle = g_Engine.time;
            } else {
                g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_WEAPON, "buttons/button11.wav", Math.RandomFloat(0.8f, 0.9f), ATTN_NORM);
                self.m_flNextSecondaryAttack = g_Engine.time + 3.0;
                self.m_flTimeWeaponIdle = g_Engine.time;
            }
        } else if (m_eSecondaryAttackMode == kDefault) {
            dictionary@ pUserData = m_pPlayer.GetUserData();
            CBaseEntity@ pTarget = null;
            if (pUserData.exists("m_fIsInXen")) {
                pUserData.delete("m_fIsInXen");
                
                //@pTarget = g_EntityFuncs.FindEntityByClassname(null, "info_teleport_destination");
                @pTarget = g_EntityFuncs.FindEntityByTargetname(null, "displacer_global_target");
                //@pTarget = g_EntityFuncs.FindEntityByClassname(null, "info_displacer_earth_target");
            } else {
                pUserData["m_fIsInXen"] = "1";
                
                //@pTarget = g_EntityFuncs.FindEntityByClassname(null, "info_teleport_destination");
                @pTarget = g_EntityFuncs.FindEntityByTargetname(null, "displacer_global_target");
                //@pTarget = g_EntityFuncs.FindEntityByClassname(null, "info_displacer_xen_target");
            }
            
            if (pTarget !is null) {
                Vector vecOriginalLocation = m_pPlayer.pev.origin;
                Vector vecAngles = pTarget.pev.angles;
                m_pPlayer.pev.flags &= ~FL_SKIPLOCALHOST;

                //Vector vecNewOrigin = vecDestination;
                //vecNewOrigin.z += 37.f; //?????? ~ xWhitey

                g_EntityFuncs.SetOrigin(m_pPlayer, pTarget.pev.origin);

                m_pPlayer.pev.angles = vecAngles;

                m_pPlayer.pev.v_angle = vecAngles;

                m_pPlayer.pev.fixangle = 1;

                m_pPlayer.pev.basevelocity = g_vecZero;
                m_pPlayer.pev.velocity = g_vecZero;

                self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 2.f;

                SetThink(null);

                m_pPlayer.m_iWeaponVolume = 1000; //LOUD_GUN_VOLUME
                m_pPlayer.m_iWeaponFlash = 512; //BRIGHT_GUN_FLASH

                m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 60);

                UTIL_CreateDisplacerBall(vecOriginalLocation, Vector(90, 0, 0), m_pPlayer);

                if (self.m_iClip == 0) {
                    if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0) {
                        m_pPlayer.SetSuitUpdate("!HEV_AMO0", false, 0); //false == SUIT_SENTENCE, 0 == SUIT_REPEAT_OK
                    }
                }

                self.m_flTimeWeaponIdle = g_Engine.time;
            } else {
                g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_WEAPON, "buttons/button11.wav", Math.RandomFloat(0.8f, 0.9f), ATTN_NORM);
                self.m_flNextSecondaryAttack = g_Engine.time + 3.0;
                self.m_flTimeWeaponIdle = g_Engine.time;
            }
        }
    }

    int iItemSlot() {
        return 15;
    }

    bool GetItemInfo(ItemInfo& out _Info) {
        _Info.iMaxAmmo1 = 100;
        _Info.iMaxAmmo2 = -1;
        _Info.iMaxClip = WEAPON_NOCLIP;
        _Info.iSlot = 5;
        _Info.iPosition = 15;
        _Info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);
        _Info.iWeight = 20;
        _Info.iAmmo1Drop = 20;
        
        return true;
    }
    
	bool AddToPlayer(CBasePlayer@ _Player) {
		if (!BaseClass.AddToPlayer(_Player))
			return false;
		
		@m_pPlayer = _Player;
		
		NetworkMessage message(MSG_ONE, NetworkMessages::WeapPickup, _Player.edict());
			message.WriteLong(g_ItemRegistry.GetIdForName(self.pev.classname));
		message.End();
		
		return true;
	}

    bool UseDecrement() {
        return false;
    }

    float m_flStartTime;
    float m_flSoundDelay;

    EDisplacerMode m_eMode;

    int m_iImplodeCounter;
    int m_iSoundState;
};

class CTriggerDisplacerDestinationPointSpecification : ScriptBaseEntity {
    void Precache() {
        BaseClass.Precache();
    }
    
    void Spawn() {
        BaseClass.Spawn();
        
        self.pev.solid = SOLID_TRIGGER;
        self.pev.movetype = MOVETYPE_NONE;
        g_EntityFuncs.SetModel(self, self.pev.model);    // set size and link into world
        g_EntityFuncs.SetOrigin(self, self.pev.origin);
    }
    
    bool KeyValue(const string& in _Key, const string& in _Value) {
        if (_Key == "vuser1") { //destination
        
            g_Utility.StringToVector(self.pev.vuser1, _Value);

            return true;
        } else if (_Key == "vuser2") { //vecAngles
        
            g_Utility.StringToVector(self.pev.vuser2, _Value);

            return true;
        }

        return BaseClass.KeyValue(_Key, _Value);
    }
    
    void Touch(CBaseEntity@ _Other) {
        if (!_Other.IsPlayer()) return;
        
        g_rgvecTeleportDestination[_Other.entindex()] = self.pev.vuser1;
        g_rgvecTeleportDestinationAngles[_Other.entindex()] = self.pev.vuser2;
    }
};

}