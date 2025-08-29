namespace HLDMSATCHELCHARGE {

enum satchel_e {
	SATCHEL_IDLE1 = 0,
	SATCHEL_FIDGET1,
	SATCHEL_DRAW,
	SATCHEL_DROP
};

enum satchel_radio_e {
	SATCHEL_RADIO_IDLE1 = 0,
	SATCHEL_RADIO_FIDGET1,
	SATCHEL_RADIO_DRAW,
	SATCHEL_RADIO_FIRE,
	SATCHEL_RADIO_HOLSTER
};

string g_VeeRadioMdl = "models/hlclassic/v_satchel_radio.mdl";
string g_VeeMdl = "models/hlclassic/v_satchel.mdl";

enum eModelsMode {
    kDefaultClassic = 0,
    kBlueShift,
    kOpposingForce
}

int g_eModelsMode = kDefaultClassic;

class CSatchel : ScriptBasePlayerWeaponEntity
{
	CBasePlayer@ m_pPlayer
	{
		get const 	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set       	{ self.m_hPlayer = EHandle( @value ); }
	}
    
    float m_flLastBounceSoundTime;
    
    void Spawn( )
    {
        Precache( );
        g_EntityFuncs.SetModel(self, self.GetW_Model("models/hlclassic/w_satchel.mdl"));

        self.m_iDefaultAmmo = 1;
        
        m_flLastBounceSoundTime = 0.f;
            
        self.FallInit();// get ready to fall down.
    }
	void Precache( void )
    {
        BaseClass.Precache();
        self.PrecacheCustomModels();
        
		g_Game.PrecacheGeneric( "sprites/scanarchy/weapon_hldm_satchelcharge.txt" );
        
        g_Game.PrecacheModel(g_VeeMdl);
        g_Game.PrecacheModel(g_VeeRadioMdl);
        g_Game.PrecacheModel("models/hlclassic/w_satchel.mdl");
        g_Game.PrecacheModel("models/hlclassic/p_satchel.mdl");
        g_Game.PrecacheModel("models/hlclassic/p_satchel_radio.mdl");
        g_SoundSystem.PrecacheSound("weapons/g_bounce1.wav");

        g_Game.PrecacheOther( "monster_satchel" );
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
                if (flDistance < 1.f) {
                    g_SoundSystem.PlaySound(self.edict(), CHAN_AUTO, "weapons/g_bounce1.wav", 0.95, ATTN_NORM, 0, PITCH_NORM, 1, true, self.pev.origin);
                    m_flLastBounceSoundTime = g_Engine.time;
                }
            }
        }
    }
    
	int iItemSlot( void ) { return 5; }
    bool GetItemInfo(ItemInfo& out _Info)
    {
        _Info.iMaxAmmo1 = 5;
        _Info.iMaxAmmo2 = -1;
        _Info.iMaxClip = WEAPON_NOCLIP;
        _Info.iSlot = 4;
        _Info.iPosition = 5;
        _Info.iFlags = ITEM_FLAG_SELECTONEMPTY | ITEM_FLAG_LIMITINWORLD | ITEM_FLAG_EXHAUSTIBLE;
        _Info.iWeight = -10;
        _Info.iAmmo1Drop = 1;
        _Info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);

        return true;
    }
	bool AddToPlayer( CBasePlayer@ pPlayer )
    {
        bool bResult = BaseClass.AddToPlayer( pPlayer );

        //pPlayer.pev.weapons |= (1<<self.m_iId);
        @m_pPlayer = pPlayer;
		
		NetworkMessage message( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			message.WriteLong( g_ItemRegistry.GetIdForName(self.pev.classname) );
		message.End();
        m_chargeReady = 0;// this satchel charge weapon now forgets that any satchels are deployed by it.

        if (bResult)
        {
            return self.AddWeapon( );
        }
        return false;
    }
	void PrimaryAttack()
    {
        switch (m_chargeReady)
        {
        case 0:
            {
            Throw( );
            }
            break;
        case 1:
            {
            self.SendWeaponAnim( SATCHEL_RADIO_FIRE );

            edict_t@ pPlayer = m_pPlayer.edict( );

            CBaseEntity@ pSatchel = null;

            while ((@pSatchel = g_EntityFuncs.FindEntityInSphere( pSatchel, m_pPlayer.pev.origin, 4096, "monster_satchel", "classname" )) !is null)
            {
                if (pSatchel.pev.owner is pPlayer)
                {
                    pSatchel.Use( m_pPlayer, m_pPlayer, USE_ON, 0 );
                    m_chargeReady = 2;
                }
            }

            if (m_chargeReady == 1)
            {
                // play buzzer sound
            }
            else
            {
                // play click sound
            }

            m_chargeReady = 2;
            self.m_flNextPrimaryAttack = g_Engine.time + 0.5;
            self.m_flNextSecondaryAttack = g_Engine.time + 0.5;
            self.m_flTimeWeaponIdle = g_Engine.time + 0.5;
            break;
            }

        case 2:
            // we're reloading, don't allow fire
            {
            }
            break;
        }
    }
	void SecondaryAttack( void )
    {
        if (m_chargeReady != 2)
        {
            Throw( );
        }
    }

    bool CanHaveDuplicates() {
        return true;
    }

	bool AddDuplicate( CBasePlayerItem@ pOriginal )
    {
        CSatchel@ pSatchel = cast<CSatchel@>(CastToScriptClass(pOriginal));

        if ( pSatchel.m_chargeReady != 0 )
        {
            return false;
        }

        return BaseClass.AddDuplicate ( pOriginal );
    }
    bool CanDeploy( void )
    {
        if ( m_pPlayer.m_rgAmmo(self.PrimaryAmmoIndex()) > 0 ) 
        {
            // player is carrying some satchels
            return true;
        }

        if (m_chargeReady != 0 )
        {
            // player isn't carrying any satchels, but has some out
            return true;
        }

        return false;
    }
    bool Deploy( )
    {
        bool bResult = false;
        if (m_chargeReady != 0)
        {
            bResult = self.DefaultDeploy(self.GetV_Model(g_VeeRadioMdl), self.GetP_Model("models/hlclassic/p_satchel_radio.mdl"), SATCHEL_RADIO_DRAW, "hive");
        }
        else
        {
            if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0) {
                m_pPlayer.RemovePlayerItem(self);
                return false;
            }
        
            bResult = self.DefaultDeploy(self.GetV_Model(g_VeeMdl), self.GetP_Model("models/hlclassic/p_satchel.mdl"), SATCHEL_DRAW, "trip");
        }

        //m_pPlayer.m_flNextAttack = g_Engine.time + 1.0;
        self.m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat ( 10, 15 );
        return bResult;
    }
	bool IsUseable( void )
    {
        if ( m_pPlayer.m_rgAmmo(self.PrimaryAmmoIndex()) > 0 ) 
        {
            // player is carrying some satchels
            return true;
        }

        if (m_chargeReady != 0)
        {
            // player isn't carrying any satchels, but has some out
            return true;
        }

        return false;
    }
    
    void _DestroyItem() {
        self.DestroyItem();
    }
	
	void Holster( )
    {
        m_pPlayer.m_flNextAttack = g_Engine.time + 0.5;
        
        if (m_chargeReady != 0)
        {
            self.SendWeaponAnim( SATCHEL_RADIO_HOLSTER );
        }
        else
        {
            self.SendWeaponAnim( SATCHEL_DROP );
        }
        g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_WEAPON, "common/null.wav", 1.0, ATTN_NORM);

        if ( m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0 && m_chargeReady == 0 )
        {
            //m_pPlayer.pev.weapons &= ~(1<<self.m_iId);
            SetThink( ThinkFunction( this._DestroyItem ) );
            pev.nextthink = g_Engine.time + 0.1;
        }
    }
	
    void WeaponIdle( void )
    {
        if (self.m_flTimeWeaponIdle > g_Engine.time)
            return;

        switch( m_chargeReady )
        {
        case 0:
            self.SendWeaponAnim( SATCHEL_FIDGET1 );
            // use tripmine animations
            m_pPlayer.m_szAnimExtension = "trip";
            break;
        case 1:
            self.SendWeaponAnim( SATCHEL_RADIO_FIDGET1 );
            // use hivehand animations
            m_pPlayer.m_szAnimExtension = "hive";
            break;
        case 2:
            if ( m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0 )
            {
                m_chargeReady = 0;
                self.RetireWeapon();
                return;
            }

            m_pPlayer.pev.viewmodel = self.GetV_Model(g_VeeMdl);
            m_pPlayer.pev.weaponmodel = self.GetP_Model("models/hlclassic/p_satchel.mdl");
            self.SendWeaponAnim( SATCHEL_DRAW );

            // use tripmine animations
            m_pPlayer.m_szAnimExtension = "trip";

            self.m_flNextPrimaryAttack = g_Engine.time + 0.5;
            self.m_flNextSecondaryAttack = g_Engine.time + 0.5;
            m_chargeReady = 0;
            break;
        }
        self.m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat ( 10, 15 );// how long till we do this again.
    }

	void Throw( void )
    {
        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) != 0)
        {
            Vector vecSrc = m_pPlayer.pev.origin;

            Vector vecThrow = g_Engine.v_forward * 274 + m_pPlayer.pev.velocity;

            CBaseEntity@ pSatchel = g_EntityFuncs.Create( "monster_satchel", vecSrc, g_vecZero, false, m_pPlayer.edict() );
            pSatchel.pev.velocity = vecThrow;
            pSatchel.pev.avelocity.y = 400;

            m_pPlayer.pev.viewmodel = self.GetV_Model(g_VeeRadioMdl);
            m_pPlayer.pev.weaponmodel = self.GetP_Model("models/hlclassic/p_satchel_radio.mdl");
            self.SendWeaponAnim( SATCHEL_RADIO_DRAW );

            // player "shoot" animation
            m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

            m_chargeReady = 1;
            
            m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 1);

            self.m_flNextPrimaryAttack = g_Engine.time + 1.0;
            self.m_flNextSecondaryAttack = g_Engine.time + 0.5;
        }
    }

	int m_chargeReady;
};

void Register() {
    if (g_eModelsMode == kOpposingForce) {
        g_VeeMdl = "models/scanarchy/opfor/v_satchel.mdl";
        g_VeeRadioMdl = "models/scanarchy/opfor/v_satchel_radio.mdl";
    } else if (g_eModelsMode == kBlueShift) {
        g_VeeMdl = "models/scanarchy/bshift/v_satchel.mdl";
        g_VeeRadioMdl = "models/scanarchy/bshift/v_satchel_radio.mdl";
    }
    
	g_CustomEntityFuncs.RegisterCustomEntity( "HLDMSATCHELCHARGE::CSatchel", "weapon_hldm_satchelcharge" );
	g_ItemRegistry.RegisterWeapon( "weapon_hldm_satchelcharge", "scanarchy", "Satchel Charge", "", "weapon_hldm_satchelcharge", "" );
    
	g_Hooks.RegisterHook(Hooks::Player::PlayerUse, @HOOKED_PlayerUse);
}

void PostPlayerUse(EHandle _Player) {
    if (!_Player.IsValid())
        return;
        
    CBasePlayer@ pPlayer = cast<CBasePlayer@>(_Player.GetEntity());
    
    CBaseEntity@ pEntity = null;
    while ((@pEntity = g_EntityFuncs.FindEntityInSphere(pEntity, pPlayer.pev.origin, 8.f, "weapon_hldm_satchelcharge", "classname")) !is null) {
        CSatchel@ pSatchel = cast<CSatchel@>(CastToScriptClass(pEntity));
        if (pSatchel is null) {
            g_EntityFuncs.Remove(pEntity);
            continue;
        }
        if (pSatchel.m_pPlayer is null && (pEntity.pev.flags & FL_ONGROUND) == 0) {
            g_EntityFuncs.Remove(pEntity);
            continue;
        }
    }
    bool bReplaceModels = true;
    while ((@pEntity = g_EntityFuncs.FindEntityInSphere(pEntity, pPlayer.pev.origin, 4096.f, "monster_satchel", "classname")) !is null) {
        if (pEntity.pev.owner is pPlayer.edict()) {
            bReplaceModels = false;
            break;
        }
    }
    if (bReplaceModels) {
        CBasePlayerWeapon@ pActiveItem = cast<CBasePlayerWeapon@>(pPlayer.m_hActiveItem.GetEntity());
        if (pActiveItem !is null) {
            if (pActiveItem.GetClassname() == "weapon_hldm_satchelcharge") {
                CSatchel@ pPlayerSatchel = cast<CSatchel@>(CastToScriptClass(pActiveItem));
                pPlayerSatchel.m_chargeReady = 0;
                pPlayerSatchel.Deploy();
            }
        }
    }
    
    /*CBasePlayerItem@ pItem = null;
    if ((@pItem = pPlayer.HasNamedPlayerItem("weapon_satchel")) !is null) {
        CBasePlayerWeapon@ pWeapon = pItem.GetWeaponPtr();
        CBasePlayerItem@ pCustomSatchel = null;
        
        if ((@pCustomSatchel = pPlayer.HasNamedPlayerItem("weapon_hldm_satchelcharge")) !is null) {
            if (pPlayer.GiveAmmo(1, "weapon_hldm_satchelcharge", 5, false) != -1) {
                pPlayer.m_rgAmmo(pWeapon.m_iPrimaryAmmoType, pPlayer.m_rgAmmo(pWeapon.m_iPrimaryAmmoType) - 1);
                pPlayer.RemovePlayerItem(pItem);
                g_EntityFuncs.Remove(pItem);
                CBaseEntity@ pSatchel = null;
                bool bReplaceModels = true;
                while ((@pSatchel = g_EntityFuncs.FindEntityInSphere(pSatchel, pPlayer.pev.origin, 4096, "monster_satchel", "classname")) !is null) {
                    if (pSatchel.pev.owner is pPlayer.edict()) {
                        bReplaceModels = false;
                        break;
                    }
                }
                if (bReplaceModels) {
                    CBasePlayerWeapon@ pActiveItem = cast<CBasePlayerWeapon@>(pPlayer.m_hActiveItem.GetEntity());
                    if (pActiveItem !is null) {
                        if (pActiveItem.GetClassname() == "weapon_hldm_satchelcharge") {
                            CSatchel@ pPlayerSatchel = cast<CSatchel@>(CastToScriptClass(pActiveItem));
                            pPlayerSatchel.m_chargeReady = 0;
                            pPlayerSatchel.Deploy();
                        }
                    }
                }
            }
        } else {
            pPlayer.GiveNamedItem("weapon_hldm_satchelcharge", 0, 0);
            pPlayer.RemovePlayerItem(pItem);
            g_EntityFuncs.Remove(pItem);
            CBaseEntity@ pSatchel = null;
            bool bReplaceModels = true;
            while ((@pSatchel = g_EntityFuncs.FindEntityInSphere(pSatchel, pPlayer.pev.origin, 4096, "monster_satchel", "classname")) !is null) {
                if (pSatchel.pev.owner is pPlayer.edict()) {
                    bReplaceModels = false;
                    break;
                }
            }
            if (bReplaceModels) {
                CBasePlayerWeapon@ pActiveItem = cast<CBasePlayerWeapon@>(pPlayer.m_hActiveItem.GetEntity());
                if (pActiveItem !is null) {
                    if (pActiveItem.GetClassname() == "weapon_hldm_satchelcharge") {
                        CSatchel@ pPlayerSatchel = cast<CSatchel@>(CastToScriptClass(pActiveItem));
                        pPlayerSatchel.m_chargeReady = 0;
                        pPlayerSatchel.Deploy();
                    }
                }
            }
        }
    }*/
}

HookReturnCode HOOKED_PlayerUse(CBasePlayer@ _Player, uint& out _Flags) {
    if ((_Player.m_afButtonPressed & IN_USE) == 0) {
        return HOOK_CONTINUE;
    }
    
    g_Scheduler.SetTimeout("PostPlayerUse", 0.f, EHandle(_Player));
 
    return HOOK_CONTINUE;
}

}