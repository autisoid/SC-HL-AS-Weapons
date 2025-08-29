namespace HLOPFORPENGUIN {

enum w_squeak_e {
	WSQUEAK_IDLE1 = 0,
	WSQUEAK_FIDGET,
	WSQUEAK_JUMP,
	WSQUEAK_RUN,
};

enum squeak_e {
	SQUEAK_IDLE1 = 0,
	SQUEAK_FIDGETFIT,
	SQUEAK_FIDGETNIP,
	SQUEAK_DOWN,
	SQUEAK_UP,
	SQUEAK_THROW
};

const float SQUEEK_DETONATE_DELAY = 15.0;

string g_PeeMdl		= "models/scanarchy/opfor/p_penguin.mdl";
string g_VeeMdl		= "models/scanarchy/v_penguin.mdl";
string g_WeeMdl		= "models/scanarchy/opfor/w_penguin.mdl";

enum eModelsMode {
    kDefaultClassic = 0,
    kBlueShift,
    kOpposingForce
}

int g_eModelsMode = kDefaultClassic;

class CPenguinGrenade : ScriptBaseMonsterEntity
{
    CPenguinGrenade()
    {
        m_flNextBounceSoundTime = 0;
        m_bReentry = false;
    }
    
    const Cvar@ m_pHealth;
    const Cvar@ m_pDmgPop;
    const Cvar@ m_pDmgBite;
    
    bool m_bReentry;

	void Spawn( void )
    {
        Precache( );
        // motor
        pev.movetype = MOVETYPE_BOUNCE;
        pev.solid = SOLID_BBOX;

        g_EntityFuncs.SetModel(self, g_WeeMdl);
        g_EntityFuncs.SetSize(pev, Vector( -4, -4, 0), Vector(4, 4, 8));
        g_EntityFuncs.SetOrigin( self, pev.origin );

        SetTouch( TouchFunction( SuperBounceTouch ) );
        SetThink( ThinkFunction( HuntThink ) );
        pev.nextthink = g_Engine.time + 0.1;
        m_flNextHunt = g_Engine.time + 1E6;

        pev.flags |= FL_MONSTER;
        pev.takedamage		= DAMAGE_AIM;
        @m_pHealth = g_EngineFuncs.CVarGetPointer("sk_snark_health");
        @m_pDmgPop = g_EngineFuncs.CVarGetPointer("sk_plr_hand_grenade");
        @m_pDmgBite = g_EngineFuncs.CVarGetPointer("sk_snark_dmg_bite"); 
        pev.health			= m_pHealth.value;
        pev.gravity		= 0.5;
        pev.friction		= 0.5;

        pev.dmg = m_pDmgPop.value;

        m_flDie = g_Engine.time + SQUEEK_DETONATE_DELAY;
        
        self.m_bloodColor = BLOOD_COLOR_YELLOW;

        self.m_flFieldOfView = 0; // 180 degrees

        if ( pev.owner !is null )
            m_hOwner = g_EntityFuncs.Instance( pev.owner );

        m_flNextBounceSoundTime = g_Engine.time;// reset each time a snark is spawned.

        pev.sequence = WSQUEAK_RUN;
        self.ResetSequenceInfo( );
    }
	void Precache( void )
    {
        BaseClass.Precache();
        g_Game.PrecacheModel(g_WeeMdl);
        g_SoundSystem.PrecacheSound("squeek/sqk_blast1.wav");
        g_SoundSystem.PrecacheSound("common/bodysplat.wav");
        g_SoundSystem.PrecacheSound("squeek/sqk_die1.wav");
        g_SoundSystem.PrecacheSound("squeek/sqk_hunt1.wav");
        g_SoundSystem.PrecacheSound("squeek/sqk_hunt2.wav");
        g_SoundSystem.PrecacheSound("squeek/sqk_hunt3.wav");
        g_SoundSystem.PrecacheSound("squeek/sqk_deploy1.wav");
    }
	int Classify ( void )
    {
        return CLASS_PLAYER_BIOWEAPON;
    }
	void SuperBounceTouch( CBaseEntity@ pOther )
    {
        float	flpitch;

        TraceResult tr = g_Utility.GetGlobalTrace( );

        // don't hit the guy that launched this grenade
        if ( pev.owner !is null && pOther.edict() is pev.owner )
            return;

        // at least until we've bounced once
        @pev.owner = null;

        pev.angles.x = 0;
        pev.angles.z = 0;

        // avoid bouncing too much
        if (m_flNextHit > g_Engine.time)
            return;

        // higher pitch as squeeker gets closer to detonation time
        flpitch = 155.0 - 60.0 * ((m_flDie - g_Engine.time) / SQUEEK_DETONATE_DELAY);

        if ( pOther.pev.takedamage > DAMAGE_NO && m_hOwner.IsValid() && pOther.edict() !is m_hOwner.GetEntity().edict() && self.m_flNextAttack < g_Engine.time)
        {
            // attack!

            // make sure it's me who has touched them
            if (tr.pHit is pOther.edict())
            {
                // and it's not another squeakgrenade
                if (tr.pHit.vars.modelindex != pev.modelindex)
                {
                    // ALERT( at_console, "hit enemy\n");
                    g_WeaponFuncs.ClearMultiDamage( );
                    pOther.TraceAttack(pev, m_pDmgBite.value, g_Engine.v_forward, tr, DMG_SLASH ); 
                    if (m_hOwner.IsValid())
                        g_WeaponFuncs.ApplyMultiDamage( pev, m_hOwner.GetEntity().pev );
                    else
                        g_WeaponFuncs.ApplyMultiDamage( pev, pev );

                    // XWHT: don't add more explosion damage because it can explode the whole map if the penguin gets stuck
                    //pev.dmg += m_pDmgPop.value; // add more explosion damage
                    // m_flDie += 2.0; // add more life

                    // make bite sound
                    g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_WEAPON, "squeek/sqk_deploy1.wav", 1.0, ATTN_NORM, 0, int(flpitch));
                    self.m_flNextAttack = g_Engine.time + 0.5;
                }
            }
            else
            {
                // ALERT( at_console, "been hit\n");
            }
        }

        m_flNextHit = g_Engine.time + 0.1;
        m_flNextHunt = g_Engine.time;

        // in multiplayer, we limit how often snarks can make their bounce sounds to prevent overflows.
        if ( g_Engine.time < m_flNextBounceSoundTime )
        {
            // too soon!
            return;
        }
        
        CSoundEnt@ pSoundEnt = GetSoundEntInstance();
        if ((pev.flags & FL_ONGROUND) == 0)
        {
            // play bounce sound
            float flRndSound = Math.RandomFloat ( 0 , 1 );

            if ( flRndSound <= 0.33 )
                g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "squeek/sqk_hunt1.wav", 1, ATTN_NORM, 0, int(flpitch));		
            else if (flRndSound <= 0.66)
                g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "squeek/sqk_hunt2.wav", 1, ATTN_NORM, 0, int(flpitch));
            else 
                g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "squeek/sqk_hunt3.wav", 1, ATTN_NORM, 0, int(flpitch));
            pSoundEnt.InsertSound ( bits_SOUND_COMBAT, pev.origin, 256, 0.25, self );
        }
        else
        {
            // skittering sound
            pSoundEnt.InsertSound ( bits_SOUND_COMBAT, pev.origin, 100, 0.1, self );
        }

        m_flNextBounceSoundTime = g_Engine.time + 0.5;// half second.
    }
	
    void HuntThink( void )
    {
        // ALERT( at_console, "think\n" );

        if (!self.IsInWorld())
        {
            SetTouch( null );
            g_EntityFuncs.Remove( self );
            return;
        }
        
        self.StudioFrameAdvance( );
        pev.nextthink = g_Engine.time + 0.1;

        // explode when ready
        if (g_Engine.time >= m_flDie)
        {
            //g_vecAttackDir = pev.velocity.Normalize( );
            pev.health = -1;
            self.Killed( pev, 0 );
            return;
        }

        // float
        if (pev.waterlevel != 0)
        {
            if (pev.movetype == MOVETYPE_BOUNCE)
            {
                pev.movetype = MOVETYPE_FLY;
            }
            pev.velocity = pev.velocity * 0.9;
            pev.velocity.z += 8.0;
        }
        else if (pev.movetype == MOVETYPE_FLY)
        {
            pev.movetype = MOVETYPE_BOUNCE;
        }

        // return if not time to hunt
        if (m_flNextHunt > g_Engine.time)
            return;

        m_flNextHunt = g_Engine.time + 2.0;
        
        CBaseEntity@ pOther = null;
        Vector vecDir;
        TraceResult tr;

        Vector vecFlat = pev.velocity;
        vecFlat.z = 0;
        vecFlat = vecFlat.Normalize( );

        g_EngineFuncs.MakeVectors( pev.angles );

        if (!self.m_hEnemy.IsValid() || !self.m_hEnemy.GetEntity().IsAlive())
        {
            // find target, bounce a bit towards it.
            self.Look( 512 );
            self.m_hEnemy = self.BestVisibleEnemy( );
        }

        // squeek if it's about time blow up
        if ((m_flDie - g_Engine.time <= 0.5) && (m_flDie - g_Engine.time >= 0.3))
        {
            g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "squeek/sqk_die1.wav", 1, ATTN_NORM, 0, 100 + Math.RandomLong(0,0x3F));
            CSoundEnt@ pSoundEnt = GetSoundEntInstance();
            pSoundEnt.InsertSound ( bits_SOUND_COMBAT, pev.origin, 256, 0.25, self );
        }

        // higher pitch as squeeker gets closer to detonation time
        float flpitch = 155.0 - 60.0 * ((m_flDie - g_Engine.time) / SQUEEK_DETONATE_DELAY);
        if (flpitch < 80)
            flpitch = 80;

        if (self.m_hEnemy.IsValid())
        {
            if (self.FVisible( self.m_hEnemy.GetEntity().pev.origin ))
            {
                vecDir = self.m_hEnemy.GetEntity().EyePosition() - pev.origin;
                m_vecTarget = vecDir.Normalize( );
            }

            float flVel = pev.velocity.Length();
            float flAdj = 50.0 / (flVel + 10.0);

            if (flAdj > 1.2)
                flAdj = 1.2;
            
            // ALERT( at_console, "think : enemy\n");

            // ALERT( at_console, "%.0f %.2f %.2f %.2f\n", flVel, m_vecTarget.x, m_vecTarget.y, m_vecTarget.z );

            pev.velocity = pev.velocity * flAdj + m_vecTarget * 300;
        }

        if ((pev.flags & FL_ONGROUND) != 0)
        {
            pev.avelocity = g_vecZero;
        }
        else
        {
            if (pev.avelocity == g_vecZero)
            {
                pev.avelocity.x = Math.RandomFloat( -100, 100 );
                pev.avelocity.z = Math.RandomFloat( -100, 100 );
            }
        }

        if ((pev.origin - m_posPrev).Length() < 1.0)
        {
            pev.velocity.x = Math.RandomFloat( -100, 100 );
            pev.velocity.y = Math.RandomFloat( -100, 100 );
        }
        m_posPrev = pev.origin;

        g_EngineFuncs.VecToAngles( pev.velocity, pev.angles );
        pev.angles.z = 0;
        pev.angles.x = 0;
    }
	int  BloodColor( void ) { return BLOOD_COLOR_RED; }
    void _SUB_Remove() {
        self.SUB_Remove();
    }
    void Detonate() {
		TraceResult tr;
		Vector vecSpot;
		
		vecSpot = self.pev.origin + Vector (0, 0, 8);
		g_Utility.TraceLine(vecSpot, vecSpot + Vector (0, 0, -40), ignore_monsters, self.edict(), tr);
		
        edict_t@ pedOwner = null;
        entvars_t@ pevOwner = null;
        if (m_hOwner.IsValid()) {
            CBaseEntity@ pentOwner = m_hOwner.GetEntity();
            @pevOwner = pentOwner.pev;
            @pedOwner = pentOwner.edict();
        } else {
            @pedOwner = self.edict();
            @pevOwner = self.pev;
        }
        
		g_EntityFuncs.CreateExplosion(tr.vecEndPos, Vector(0, 0, -90), pedOwner, int(self.pev.dmg), false);
		g_WeaponFuncs.RadiusDamage(tr.vecEndPos, self.pev, pevOwner, self.pev.dmg, (self.pev.dmg * 3.0), CLASS_NONE, DMG_BLAST);
	}
	void Killed( entvars_t@ pevAttacker, int iGib )
    {
        if (m_bReentry) {
            return;
        }
        
        m_bReentry = true;
        
        pev.model = String::EMPTY_STRING;// make invisible
        SetThink( ThinkFunction( this._SUB_Remove ) );
        SetTouch( null );
        pev.nextthink = g_Engine.time + 0.1;
    
        Detonate();
        
        // since squeak grenades never leave a body behind, clear out their takedamage now.
        // Squeaks do a bit of radius damage when they pop, and that radius damage will
        // continue to call this function unless we acknowledge the Squeak's death now. (sjb)
        pev.takedamage = DAMAGE_NO;
        
        g_Utility.BloodDrips( pev.origin, g_vecZero, BloodColor(), 80 );

        // reset owner so death message happens
        if (m_hOwner.IsValid())
            @pev.owner = m_hOwner.GetEntity().edict();

        BaseClass.Killed( pevAttacker, GIB_ALWAYS );
    }
	void GibMonster( void )
    {
        g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "common/bodysplat.wav", 0.75, ATTN_NORM, 0, 200);		
    }

	float m_flNextBounceSoundTime;

	// CBaseEntity *m_pTarget;
	float m_flDie;
	Vector m_vecTarget;
	float m_flNextHunt;
	float m_flNextHit;
	Vector m_posPrev;
	EHandle m_hOwner;
	int  m_iMyClass;
};

class CPenguin : ScriptBasePlayerWeaponEntity
{
    private CBasePlayer@ m_pPlayer {
		get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
		set { self.m_hPlayer = EHandle(@value); }
	}
    
    float m_flLastBounceSoundTime;
    
    void Spawn( )
    {
        Precache( );
        g_EntityFuncs.SetModel(self, self.GetW_Model("models/scanarchy/opfor/w_penguinnest.mdl"));

        self.FallInit();//get ready to fall down.

        self.m_iDefaultAmmo = 5;
        m_flLastBounceSoundTime = 0.f;
            
        pev.sequence = 1;
        pev.animtime = g_Engine.time;
        pev.framerate = 1.0;
    }
    void Precache( void )
    {
        BaseClass.Precache();
        self.PrecacheCustomModels();
        
        g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hlopfor_penguingrenade.txt");
        
        g_Game.PrecacheModel("models/scanarchy/opfor/w_penguinnest.mdl");
        
        g_Game.PrecacheModel(g_VeeMdl);
        g_Game.PrecacheModel(g_PeeMdl);
        g_SoundSystem.PrecacheSound("squeek/sqk_hunt2.wav");
        g_SoundSystem.PrecacheSound("squeek/sqk_hunt3.wav");
        g_SoundSystem.PrecacheSound("debris/flesh5.wav");
        g_Game.PrecacheOther("monster_sca_snark");
    }
    
    void Touch(CBaseEntity@ _Other) {
        BaseClass.Touch(_Other);
        if (m_flLastBounceSoundTime + 0.2f < g_Engine.time && self.pev.velocity != g_vecZero) {
            g_SoundSystem.StopSound(self.edict(), CHAN_ITEM, "items/weapondrop1.wav");
            g_SoundSystem.PlaySound(self.edict(), CHAN_ITEM, "items/weapondrop1.wav", 0.01, ATTN_NORM, SND_STOP | SND_CHANGE_VOL | SND_CHANGE_PITCH, PITCH_NORM, 1, true, self.pev.origin);
            g_SoundSystem.PlaySound(self.edict(), CHAN_VOICE, "debris/flesh5.wav", 0.95, ATTN_NORM, 0, PITCH_NORM, 1, true, self.pev.origin);
            m_flLastBounceSoundTime = g_Engine.time;
        }
    }
    
    bool CanHaveDuplicates() {
        return true;
    }
    
	int iItemSlot( void ) { return 5; }
	
    bool GetItemInfo(ItemInfo& out _Info)
    {
        _Info.iMaxAmmo1 = 10000;
        _Info.iMaxAmmo2 = -1;
        _Info.iMaxClip = WEAPON_NOCLIP;
        _Info.iSlot = 4;
        _Info.iPosition = 15;
        _Info.iWeight = 5;
        _Info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);
        _Info.iFlags = ITEM_FLAG_LIMITINWORLD | ITEM_FLAG_EXHAUSTIBLE;
        _Info.iAmmo1Drop = 1;

        return true;
    }

    void PrimaryAttack()
    {
        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) != 0)
        {
            g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle );
            TraceResult tr;

            // find place to toss monster
            g_Utility.TraceLine( m_pPlayer.pev.origin + g_Engine.v_forward * 16, m_pPlayer.pev.origin + g_Engine.v_forward * 64, dont_ignore_monsters, null, tr );

            if (tr.fAllSolid == 0 && tr.fStartSolid == 0 && tr.flFraction > 0.25)
            {
                self.SendWeaponAnim( SQUEAK_THROW );

                // player "shoot" animation
                m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

                CBaseEntity@ pSqueak = g_EntityFuncs.Create( "monster_sca_penguingrenade", tr.vecEndPos, m_pPlayer.pev.v_angle, false, m_pPlayer.edict() );

                pSqueak.pev.velocity = g_Engine.v_forward * 200 + m_pPlayer.pev.velocity;

                // play hunt sound
                float flRndSound = Math.RandomFloat ( 0 , 1 );

                if ( flRndSound <= 0.5 )
                    g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "squeek/sqk_hunt2.wav", 1, ATTN_NORM, 0, 105);
                else 
                    g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "squeek/sqk_hunt3.wav", 1, ATTN_NORM, 0, 105);

                m_pPlayer.m_iWeaponVolume = QUIET_GUN_VOLUME;

                m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 1);

                m_fJustThrown = true;

                self.m_flNextPrimaryAttack = g_Engine.time + 0.3;
                self.m_flTimeWeaponIdle = g_Engine.time + 1.0;
            }
        }
    }

    void SecondaryAttack( void )
    {

    }
	bool Deploy( )
    {
        // play hunt sound
        float flRndSound = Math.RandomFloat ( 0 , 1 );

        if ( flRndSound <= 0.5 )
            g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_VOICE, "squeek/sqk_hunt2.wav", 1, ATTN_NORM, 0, 100);
        else 
            g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_VOICE, "squeek/sqk_hunt3.wav", 1, ATTN_NORM, 0, 100);

        m_pPlayer.m_iWeaponVolume = QUIET_GUN_VOLUME;

        return self.DefaultDeploy( self.GetV_Model(g_VeeMdl), self.GetP_Model(g_PeeMdl), SQUEAK_UP, "squeak" );
    }
    void Holster( )
    {
        m_pPlayer.m_flNextAttack = g_Engine.time + 0.5;
        
        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0)
        {
            m_pPlayer.pev.weapons &= ~(1<<WEAPON_SNARK);
            SetThink( ThinkFunction( self.DestroyItem ) );
            pev.nextthink = g_Engine.time + 0.1;
            return;
        }
        
        self.SendWeaponAnim( SQUEAK_DOWN );
        g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_WEAPON, "common/null.wav", 1.0, ATTN_NORM);
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
	
    void WeaponIdle( void )
    {
        if (self.m_flTimeWeaponIdle > g_Engine.time)
            return;

        if (m_fJustThrown)
        {
            m_fJustThrown = false;

            if ( m_pPlayer.m_rgAmmo(self.PrimaryAmmoIndex()) == 0 )
            {
                self.RetireWeapon();
                return;
            }

            self.SendWeaponAnim( SQUEAK_UP );
            self.m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat ( 10, 15 );
            return;
        }

        int iAnim;
        float flRand = Math.RandomFloat(0, 1);
        if (flRand <= 0.75)
        {
            iAnim = SQUEAK_IDLE1;
            self.m_flTimeWeaponIdle = g_Engine.time + 30.0 / 16 * (2);
        }
        else if (flRand <= 0.875)
        {
            iAnim = SQUEAK_FIDGETFIT;
            self.m_flTimeWeaponIdle = g_Engine.time + 70.0 / 16.0;
        }
        else
        {
            iAnim = SQUEAK_FIDGETNIP;
            self.m_flTimeWeaponIdle = g_Engine.time + 80.0 / 16.0;
        }
        self.SendWeaponAnim( iAnim );
    }
    
	bool m_fJustThrown;
};

void Register()
{
    if (g_eModelsMode == kOpposingForce) {
        g_VeeMdl = "models/scanarchy/opfor/v_penguin.mdl";
    }

    g_CustomEntityFuncs.RegisterCustomEntity("HLOPFORPENGUIN::CPenguinGrenade", "monster_sca_penguingrenade");
    g_CustomEntityFuncs.RegisterCustomEntity("HLOPFORPENGUIN::CPenguin", "weapon_hlopfor_penguingrenade");
    g_ItemRegistry.RegisterWeapon("weapon_hlopfor_penguingrenade", "scanarchy", "Penguins", "", "weapon_hlopfor_penguingrenade", "");
}

}