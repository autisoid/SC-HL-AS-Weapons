namespace HLDMTRIPMINE {

enum tripmine_e {
	TRIPMINE_IDLE1 = 0,
	TRIPMINE_IDLE2,
	TRIPMINE_ARM1,
	TRIPMINE_ARM2,
	TRIPMINE_FIDGET,
	TRIPMINE_HOLSTER,
	TRIPMINE_DRAW,
	TRIPMINE_WORLD,
	TRIPMINE_GROUND,
};

string g_VeeMdl = "models/hlclassic/v_tripmine.mdl";

enum eModelsMode {
    kDefaultClassic = 0,
    kBlueShift,
    kOpposingForce
}

int g_eModelsMode = kDefaultClassic;

class CTripmine : ScriptBasePlayerWeaponEntity
{
    private CBasePlayer@ m_pPlayer {
		get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
		set { self.m_hPlayer = EHandle(@value); }
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
    
    bool CanHaveDuplicates() {
        return true;
    }
    
	void Spawn( void )
    {
        Precache( );
        g_EntityFuncs.SetModel(self, self.GetW_Model("models/hlclassic/w_tripmine.mdl"));
        pev.frame = 0;
        pev.body = 3;
        pev.sequence = TRIPMINE_GROUND;
        // self.ResetSequenceInfo( );
        pev.framerate = 0;

        self.FallInit();// get ready to fall down
            
        //SetThink(ThinkFunction(DroppedThink));

        self.m_iDefaultAmmo = 1;

        //if ( !g_pGameRules.IsDeathmatch() )
        //{
            //g_EntityFuncs.SetSize(pev, Vector(-16, -16, 0), Vector(16, 16, 28) ); 
        //}
    }
	void Precache( void )
    {
        BaseClass.Precache();
        self.PrecacheCustomModels();
        
        g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hldm_tripmine.txt");
    
        g_Game.PrecacheModel (g_VeeMdl);
        g_Game.PrecacheModel ("models/hlclassic/w_tripmine.mdl");
        g_Game.PrecacheModel ("models/hlclassic/p_tripmine.mdl");
        g_Game.PrecacheOther( "monster_tripmine" );
    }
	int iItemSlot( void ) { return 5; }
	bool GetItemInfo(ItemInfo& out _Info)
    {
        _Info.iMaxAmmo1 = 5;
        _Info.iMaxAmmo2 = -1;
        _Info.iAmmo1Drop = 1;
        _Info.iMaxClip = WEAPON_NOCLIP;
        _Info.iSlot = 4;
        _Info.iPosition = 6;
        _Info.iWeight = -10;
        _Info.iFlags = ITEM_FLAG_LIMITINWORLD | ITEM_FLAG_EXHAUSTIBLE;
        _Info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);

        return true;
    }
	void SetObjectCollisionBox( void )
	{
		//!!!BUGBUG - fix the model!
		pev.absmin = pev.origin + Vector(-16, -16, -5);
		pev.absmax = pev.origin + Vector(16, 16, 28); 
	}
    
    /*void DroppedThink() {
        if (m_pPlayer is null) {
            self.pev.body = 3;
            self.pev.skin = 1;
            self.pev.sequence = 8;
        }
        self.pev.nextthink = g_Engine.time + 0.1f;
    }*/

    void _DestroyItem() {
        self.DestroyItem();
    }

	void PrimaryAttack( void )
    {
        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
            return;

        g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );
        Vector vecSrc	 = m_pPlayer.GetGunPosition( );
        Vector vecAiming = g_Engine.v_forward;

        TraceResult tr;

        g_Utility.TraceLine( vecSrc, vecSrc + vecAiming * 128, dont_ignore_monsters, m_pPlayer.edict(), tr );

        if (tr.flFraction < 1.0)
        {
            // ALERT( at_console, "hit %f\n", tr.flFraction );

            CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );
            if (pEntity !is null && (pEntity.pev.flags & FL_CONVEYOR) == 0)
            {
                Vector angles = Math.VecToAngles( tr.vecPlaneNormal );

                CBaseEntity@ pEnt = g_EntityFuncs.Create( "monster_tripmine", tr.vecEndPos + tr.vecPlaneNormal * 8, angles, false, m_pPlayer.edict() );

                m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 1);

                // player "shoot" animation
                m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

                if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0)
                {
                    self.SendWeaponAnim( TRIPMINE_DRAW );
                }
                else
                {
                    // no more mines! 
                    self.RetireWeapon();
                    return;
                }
            }
            else
            {
                // ALERT( at_console, "no deploy\n" );
            }
        }
        else
        {

        }

        self.m_flNextPrimaryAttack = g_Engine.time + 0.3;
        self.m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat ( 10, 15 );
    }
	bool Deploy( void )
    {
        pev.body = 0;
        return self.DefaultDeploy( self.GetV_Model(g_VeeMdl), self.GetP_Model("models/hlclassic/p_tripmine.mdl"), TRIPMINE_DRAW, "trip" );
    }
	void Holster( void )
    {
        m_pPlayer.m_flNextAttack = g_Engine.time + 0.5;

        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0)
        {
            // out of mines
            //m_pPlayer.pev.weapons &= ~(1<<WEAPON_TRIPMINE);
            SetThink( ThinkFunction( this._DestroyItem) );
            pev.nextthink = g_Engine.time + 0.1;
        }

        self.SendWeaponAnim( TRIPMINE_HOLSTER );
        g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_WEAPON, "common/null.wav", 1.0, ATTN_NORM);
    }
	void WeaponIdle( void )
    {
        if (self.m_flTimeWeaponIdle > g_Engine.time)
            return;

        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0)
        {
            self.SendWeaponAnim( TRIPMINE_DRAW );
        }
        else
        {
            self.RetireWeapon(); 
            return;
        }

        int iAnim;
        float flRand = Math.RandomFloat(0, 1);
        if (flRand <= 0.25)
        {
            iAnim = TRIPMINE_IDLE1;
            self.m_flTimeWeaponIdle = g_Engine.time + 90.0 / 30.0;
        }
        else if (flRand <= 0.75)
        {
            iAnim = TRIPMINE_IDLE2;
            self.m_flTimeWeaponIdle = g_Engine.time + 60.0 / 30.0;
        }
        else
        {
            iAnim = TRIPMINE_FIDGET;
            self.m_flTimeWeaponIdle = g_Engine.time + 100.0 / 30.0;
        }

        self.SendWeaponAnim( iAnim );
    }
};

void Register() {
    if (g_eModelsMode == kOpposingForce) {
        g_VeeMdl = "models/scanarchy/opfor/v_tripmine.mdl";
    } else if (g_eModelsMode == kBlueShift) {
        g_VeeMdl = "models/scanarchy/bshift/v_tripmine.mdl";
    }

    g_CustomEntityFuncs.RegisterCustomEntity("HLDMTRIPMINE::CTripmine", "weapon_hldm_tripmine");
    g_ItemRegistry.RegisterWeapon("weapon_hldm_tripmine", "scanarchy", "Trip Mine", "", "weapon_hldm_tripmine", "");
}

}