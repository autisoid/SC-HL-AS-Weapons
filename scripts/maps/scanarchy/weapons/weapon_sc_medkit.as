namespace SCMEDKIT
{

enum medkit_e
{
	MEDKIT_IDLE = 0,
    MEDKIT_LONGIDLE,
    MEDKIT_LONGUSE,
    MEDKIT_SHORTUSE,
    MEDKIT_HOLSTER,
    MEDKIT_DRAW
};

string g_VeeMdl = "models/hlclassic/v_medkit.mdl";
string g_WeeMdl = "models/hlclassic/w_pmedkit.mdl";
string g_PeeMdl = "models/hlclassic/p_medkit.mdl";

enum eModelsMode {
    kDefaultClassic = 0,
    kBlueShift,
    kOpposingForce
}

int g_eModelsMode = kDefaultClassic;

uint g_Slot = 0;
uint g_Position = 7;

const string g_WeaponName		= "weapon_sc_medkit";

float fabsf(float _Value) {
    return _Value < 0.f ? (_Value * -1.f) : _Value;
}

float fclampf(float _Value, float _Min, float _Max) {
    return _Value < _Min ? _Min : _Value > _Max ? _Max : _Value;
}

enum eReviveState {
    kBegin = 0,
    kMiddle,
    kEnd
};

class weapon_sc_medkit : ScriptBasePlayerWeaponEntity {
    float m_flRechargeTime;
    eReviveState m_eReviveState;
    float m_flReviveStartTime;
    float m_flLastReviveTime;
    const Cvar@ m_pDamage;
    float m_flTotalHealedHealthSum;

	private CBasePlayer@ m_pPlayer {
		get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
		set { self.m_hPlayer = EHandle(@value); }
	}
    
	void Spawn() {
		self.Precache();
		g_EntityFuncs.SetModel(self, self.GetW_Model(g_WeeMdl));
		self.m_iClip = -1;

        self.m_iDefaultAmmo = 50;
        self.m_dropType = DROP_PLAYER_CMD;
        
        SetThink(ThinkFunction(IdleThink));
        self.pev.nextthink = g_Engine.time + 2.5;

		self.FallInit();// get ready to fall down.
        
        @m_pDamage = g_EngineFuncs.CVarGetPointer("sk_plr_HpMedic");
        m_flTotalHealedHealthSum = 0.f;
	}
    
    void Pickup(CBaseEntity@ pOther) {
        if (!pOther.IsPlayer() || !pOther.IsAlive())
			return;
        if ((self.pev.flags & FL_ONGROUND) == 0) return;
        
        CBasePlayer@ pPlayer = cast<CBasePlayer@>(pOther);
        g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "Pickup entry\n");
        SetTouch(null);
        SetThink(ThinkFunction(IdleThink));
        
        if (pPlayer.HasNamedPlayerItem("weapon_sc_medkit") !is null) {
			if (pPlayer.GiveAmmo(50, "weapon_sc_medkit", 100) != -1) {
				self.CheckRespawn();
				//g_SoundSystem.EmitSound(self.edict(), CHAN_ITEM, CoFCOMMON::ITEM_SOUND_PICK, 1, ATTN_NORM);
				self.AttachToPlayer(pPlayer);
				g_EntityFuncs.Remove(self);
			}
		} else if (pPlayer.AddPlayerItem(self) != APIR_NotAdded) {
			self.AttachToPlayer(pPlayer);
			//g_SoundSystem.EmitSound(self.edict(), CHAN_ITEM, CoFCOMMON::WEAPON_SOUND_GET, 1, ATTN_NORM);
		}
    }
    
    bool CanHaveDuplicates() {
        return true;
    }

	void Precache() {
        BaseClass.Precache();
		self.PrecacheCustomModels();
        
		g_Game.PrecacheGeneric("sprites/scanarchy/weapon_sc_medkit.txt");

		g_Game.PrecacheModel(g_VeeMdl);
		g_Game.PrecacheModel(g_WeeMdl);
		g_Game.PrecacheModel(g_PeeMdl);
        
        g_SoundSystem.PrecacheSound("items/medshot5.wav");
        g_SoundSystem.PrecacheSound("items/medshotno1.wav");
        g_SoundSystem.PrecacheSound("items/suitchargeok1.wav");
        g_SoundSystem.PrecacheSound("items/suitchargeno1.wav");
        g_SoundSystem.PrecacheSound("hlclassic/weapons/electro4.wav");
	}

	bool GetItemInfo(ItemInfo& out info) {
		info.iMaxAmmo1		= 100;
		info.iMaxAmmo2		= -1;
        info.iAmmo1Drop     = 10;
        info.iAmmo2Drop     = -1;
		info.iMaxClip		= WEAPON_NOCLIP;
		info.iSlot			= g_Slot;
		info.iPosition		= g_Position;
		info.iWeight		= 0;
        info.iFlags         = ITEM_FLAG_LIMITINWORLD | ITEM_FLAG_EXHAUSTIBLE | ITEM_FLAG_ESSENTIAL;
        info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);
        
		return true;
	}
	
	bool AddToPlayer(CBasePlayer@ pPlayer) {
		if (!BaseClass.AddToPlayer(pPlayer))
			return false;
		
		@m_pPlayer = pPlayer;
		
		NetworkMessage message(MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict());
			message.WriteLong(g_ItemRegistry.GetIdForName(self.pev.classname));
		message.End();
		
		return true;
	}

	bool Deploy() {
		return self.DefaultDeploy(self.GetV_Model(g_VeeMdl), self.GetP_Model(g_PeeMdl), MEDKIT_DRAW, "trip");
	}

	void Holster(int skiplocal = 0) {
		BaseClass.Holster(skiplocal);
	}
	
	void PrimaryAttack() {
        Vector vecDest = m_pPlayer.GetGunPosition() + g_Engine.v_forward * 200.f;
        TraceResult tr;
        g_Utility.TraceHull(m_pPlayer.GetGunPosition(), vecDest, dont_ignore_monsters, large_hull, m_pPlayer.edict(), tr);
        if (tr.pHit is null) return;
        g_Utility.FindHullIntersection(m_pPlayer.GetGunPosition(), tr, tr, VEC_HUMAN_HULL_MIN, VEC_HUMAN_HULL_MAX, m_pPlayer.edict());
        if (tr.pHit is null) return;
        CBaseEntity@ pEntity = g_EntityFuncs.Instance(tr.pHit);
        if (pEntity is null) return;
        if (pEntity is m_pPlayer) return;
        if ((!pEntity.IsPlayerAlly() && !pEntity.IsPlayer()) || pEntity.IsMachine()) return;
        if (pEntity.pev.health >= pEntity.pev.max_health) return;
        //g_WeaponFuncs.ClearMultiDamage();
        int nAmmo = m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType);
        if (nAmmo <= m_pDamage.value) {
            UseAmmo(nAmmo);
            pEntity.pev.health = fclampf(pEntity.pev.health + float(nAmmo), 0.f, pEntity.pev.max_health);
            //pEntity.TraceAttack(m_pPlayer.pev, float(nAmmo) * -1.f, g_Engine.v_forward, tr, DMG_MEDKITHEAL);  
        } else {
            if (pEntity.pev.health + m_pDamage.value >= pEntity.pev.max_health) {
                int nUsage = int(ceil(pEntity.pev.max_health - pEntity.pev.health));
                UseAmmo(nUsage);
                pEntity.pev.health = fclampf(pEntity.pev.health + float(nUsage), 0.f, pEntity.pev.max_health);
                //pEntity.TraceAttack(m_pPlayer.pev, float(nUsage) * -1.f, g_Engine.v_forward, tr, DMG_MEDKITHEAL);  
            } else {
                UseAmmo(int(m_pDamage.value));
                pEntity.pev.health = fclampf(pEntity.pev.health + 10.f, 0.f, pEntity.pev.max_health);
                //pEntity.TraceAttack(m_pPlayer.pev, m_pDamage.value * -1.f, g_Engine.v_forward, tr, DMG_MEDKITHEAL);  
            }
        }
        //_WeaponFuncs.ApplyMultiDamage(m_pPlayer.pev, m_pPlayer.pev);
        m_pPlayer.AddPoints(1, false);
        if (pEntity.IsMonster()) {
            CBaseMonster@ pMonster = pEntity.MyMonsterPointer();
            pMonster.m_hEnemy = null;
            for (uint i = 1; i <= 4; i++)
                pMonster.PopEnemy();

            pMonster.Forget(bits_MEMORY_PROVOKED | bits_MEMORY_SUSPICIOUS);
            pMonster.ClearSchedule();
        }
        g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "items/medshot5.wav", 0.98f, ATTN_NORM, 0, 100);
        self.SendWeaponAnim(MEDKIT_SHORTUSE);
		m_pPlayer.SetAnimation(PLAYER_ATTACK1);
        self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flTimeWeaponIdle  = g_Engine.time + 0.5f;
        self.m_flTimeWeaponIdle = g_Engine.time + 4.f;
	}
    
    void SecondaryAttack() {
        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) < 50) {
            g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "items/suitchargeno1.wav", 0.98f, ATTN_NORM, 0, 110);
            self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 1.0f;
            return;
        }
        if (m_flLastReviveTime + 0.5f > g_Engine.time) {
            return;
        }
    
        array<CBaseEntity@> pMonsters(g_EngineFuncs.NumberOfEntities());
        Vector vecMins = m_pPlayer.pev.origin - Vector(128.f, 128.f, 128.f);
        Vector vecMaxs = m_pPlayer.pev.origin + Vector(128.f, 128.f, 128.f);
        int nMonstersInSphere = g_EntityFuncs.EntitiesInBox(@pMonsters, vecMins, vecMaxs, 0);
        CBaseEntity@ pValidMonster = null;
        for (int idx = 0; idx < nMonstersInSphere; idx++) {
            CBaseEntity@ pMonster = pMonsters[idx];
            if (pMonster is null || pMonster.IsBSPModel() || pMonster.IsMachine()) continue;
            if ((!pMonster.IsPlayerAlly() && !pMonster.IsPlayer()) && (pMonster.GetClassname() != "deadplayer")) continue;
            if (!pMonster.IsRevivable()) continue;
            if (pMonster is m_pPlayer) continue;
            //if (pMonster.Classify() != m_pPlayer.Classify()) continue;
            /*
            if (!pMonster.IsMonster()) continue;
            if (pMonster.IsAlive()) continue;
            if (pMonster.IsPlayer()) {
                CBasePlayer@ pPlayer = cast<CBasePlayer@>(pMonster);
                Observer@ pObserver = pPlayer.GetObserver();
                if (!pObserver.HasCorpse()) continue;
            }*/

            @pValidMonster = pMonster;
            break;
        }
        
        if (pValidMonster is null) {
            if (m_eReviveState != kMiddle) {
                g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "items/medshotno1.wav", 0.98f, ATTN_NORM, 0, 110);
            } else {
                if (m_flReviveStartTime + 2.0f < g_Engine.time)
                    m_pPlayer.SetAnimation(PLAYER_ATTACK1);
            }
            self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 0.6f;
            return;
        }
        if (m_eReviveState != kMiddle) {
            g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "items/suitchargeok1.wav", 0.98f, ATTN_NORM, 0, 110);
            self.SendWeaponAnim(MEDKIT_LONGUSE);
            pValidMonster.BeginRevive(2.0f);
            m_eReviveState = kBegin;
        }
        if (m_eReviveState == kBegin) {
            m_flReviveStartTime = g_Engine.time;
            self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 0.1f;
            m_eReviveState = kMiddle;
        }
        if (m_eReviveState == kMiddle) {
            if (m_flReviveStartTime + 2.0f < g_Engine.time) {
                self.SendWeaponAnim(MEDKIT_SHORTUSE);
                m_pPlayer.SetAnimation(PLAYER_ATTACK1);
                pValidMonster.EndRevive(0.f);
                UseAmmo(50);
                m_pPlayer.AddPoints(1, false);
                m_eReviveState = kEnd;
                g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/electro4.wav", 0.98f, ATTN_NORM, 0, 110);
                SetThink(ThinkFunction(EndReviveThink));
                self.pev.nextthink = g_Engine.time + 0.1f;
                m_flReviveStartTime = 0.f;
                self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flTimeWeaponIdle = m_flLastReviveTime = g_Engine.time + 1.5f;
            }
        }
    }
    
    void EndReviveThink() {
        g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_AUTO, "items/medshot5.wav", 0.98f, ATTN_NORM, 0, 100);
        SetThink(ThinkFunction(IdleThink));
        self.pev.nextthink = g_Engine.time + 2.5f;
    }
    
    void UseAmmo(int _Count) {
		if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) >= _Count)
			m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - _Count);
		else
			m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, 0);
            
        m_flTotalHealedHealthSum = m_flTotalHealedHealthSum + float(_Count);
            
        if (m_flTotalHealedHealthSum >= 10.f) {
            if (m_pPlayer.pev.max_health >= m_pPlayer.pev.health)
                m_pPlayer.pev.health = fclampf(m_pPlayer.pev.health + m_flTotalHealedHealthSum / 10.f, 0.f, m_pPlayer.pev.max_health);
            
            while (m_flTotalHealedHealthSum >= 10.f) {
                m_flTotalHealedHealthSum = m_flTotalHealedHealthSum - 10.f;
            }
            
            m_flTotalHealedHealthSum = fabsf(m_flTotalHealedHealthSum);
        }
	}
    
    void IdleThink() {
        if (!self.m_hPlayer.IsValid()) {
            self.pev.nextthink = g_Engine.time + 2.5f;
            return;
        }
        
        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 1)
            m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, 5);
        else if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) < 100)
            m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, Math.min(m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) + 5, 100));
        
        self.pev.nextthink = g_Engine.time + 2.5f;
    }
    
    void WeaponIdle() {
        self.ResetEmptySound();
        if (m_eReviveState != kBegin) {
            m_eReviveState = kBegin;
            m_flReviveStartTime = 0.f;
            self.m_flNextSecondaryAttack = g_Engine.time + 1.5f;
            self.m_flTimeWeaponIdle = g_Engine.time + 4.5f;
        }
        
        if (m_flReviveStartTime != 0.f) {
            self.m_flTimeWeaponIdle = g_Engine.time + 4.5f;
        }
        
        if (self.m_flTimeWeaponIdle > g_Engine.time)
            return;

        if (Math.RandomLong(0, 1) == 0) {
            self.SendWeaponAnim(MEDKIT_IDLE);
        } else {
            self.SendWeaponAnim(MEDKIT_LONGIDLE);
        }
        self.m_flTimeWeaponIdle = g_Engine.time + 4.5f;
    }
}

void Register()
{
    if (g_eModelsMode == kOpposingForce) {
        g_VeeMdl = "models/scanarchy/opfor/v_medkit.mdl";
    } else if (g_eModelsMode == kBlueShift) {
        g_VeeMdl = "models/scanarchy/bshift/v_medkit.mdl";
    }

	g_CustomEntityFuncs.RegisterCustomEntity( "SCMEDKIT::weapon_sc_medkit", g_WeaponName );
	g_ItemRegistry.RegisterWeapon( g_WeaponName, "scanarchy", "health", "", "ammo_medkit", "" );
}

} // End of namespace