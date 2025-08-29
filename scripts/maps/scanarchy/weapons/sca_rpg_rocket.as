namespace SCARPGROCKET {

CRpgRocket@ UTIL_CreateRpgRocket( Vector vecOrigin, Vector vecAngles, CBaseEntity@ pOwner, CBasePlayerWeapon@ pLauncher )
{
	//CRpgRocket *pRocket = GetClassPtr( (CRpgRocket *)NULL );
    CBaseEntity@ pEntity = g_EntityFuncs.Create("sca_rpg_rocket", g_vecZero, g_vecZero, true, null);
    CRpgRocket@ pRocket = cast<CRpgRocket@>(CastToScriptClass(pEntity));

	g_EntityFuncs.SetOrigin( pEntity, vecOrigin );
	pEntity.pev.angles = vecAngles;
	pRocket.Spawn();
	pRocket.SetTouch( TouchFunction( pRocket.RocketTouch ) );
	pRocket.m_pLauncher = EHandle(pLauncher);// remember what RPG fired me. 
	pLauncher.pev.iuser4++;// register this missile as active for the launcher
	@pEntity.pev.owner = pOwner.edict();

	return pRocket;
}

class CRpgRocket : ScriptBaseMonsterEntity
{
	void Spawn( void )
    {
        Precache( );
        // motor
        pev.movetype = MOVETYPE_BOUNCE;
        pev.solid = SOLID_BBOX;

        g_EntityFuncs.SetModel(self, "models/hlclassic/rpgrocket.mdl");
        g_EntityFuncs.SetSize(pev, g_vecZero, g_vecZero);
        g_EntityFuncs.SetOrigin( self, pev.origin );

        //pev.classname = MAKE_STRING("rpg_rocket");

        SetThink( ThinkFunction( IgniteThink ) );
        SetTouch( TouchFunction( ExplodeTouch ) );

        pev.angles.x -= 30;
        g_EngineFuncs.MakeVectors( pev.angles );
        pev.angles.x = -(pev.angles.x + 30);

        pev.velocity = g_Engine.v_forward * 250;
        pev.gravity = 0.5;

        pev.nextthink = g_Engine.time + 0.4;

        pev.dmg = g_EngineFuncs.CVarGetFloat("sk_plr_rpg"); //gSkillData.plrDmgRPG;
    }
	void Precache( void )
    {
        g_Game.PrecacheModel("models/hlclassic/rpgrocket.mdl");
        m_iTrail = g_Game.PrecacheModel("sprites/smoke.spr");
        g_SoundSystem.PrecacheSound("hlclassic/weapons/rocket1.wav");
		g_SoundSystem.PrecacheSound("hlclassic/weapons/debris1.wav");
		g_SoundSystem.PrecacheSound("hlclassic/weapons/debris2.wav");
		g_SoundSystem.PrecacheSound("hlclassic/weapons/debris3.wav");
    }
	void FollowThink( void )
    {
        CBaseEntity@ pOther = null;
        Vector vecTarget;
        Vector vecDir;
        float flDist, flMax, flDot;
        TraceResult tr;

        Math.MakeAimVectors( pev.angles );

        vecTarget = g_Engine.v_forward;
        flMax = 4096;
        
        // Examine all entities within a reasonable radius
        while ((@pOther = g_EntityFuncs.FindEntityByClassname( pOther, "sca_rpg_laser_spot" )) !is null)
        {
            g_Utility.TraceLine ( pev.origin, pOther.pev.origin, dont_ignore_monsters, self.edict(), tr );
            // ALERT( at_console, "%f\n", tr.flFraction );
            if (tr.flFraction >= 0.90)
            {
                vecDir = pOther.pev.origin - pev.origin;
                flDist = vecDir.Length( );
                vecDir = vecDir.Normalize( );
                flDot = DotProduct( g_Engine.v_forward, vecDir );
                if ((flDot > 0) && (flDist * (1 - flDot) < flMax))
                {
                    flMax = flDist * (1 - flDot);
                    vecTarget = vecDir;
                }
            }
        }

        pev.angles = Math.VecToAngles( vecTarget );

        // this acceleration and turning math is totally wrong, but it seems to respond well so don't change it.
        float flSpeed = pev.velocity.Length();
        if (g_Engine.time - m_flIgniteTime < 1.0)
        {
            pev.velocity = pev.velocity * 0.2 + vecTarget * (flSpeed * 0.8 + 400);
            if (pev.waterlevel == 3)
            {
                // go slow underwater
                if (pev.velocity.Length() > 300)
                {
                    pev.velocity = pev.velocity.Normalize() * 300;
                }
                g_Utility.BubbleTrail( pev.origin - pev.velocity * 0.1, pev.origin, 4 );
            } 
            else 
            {
                if (pev.velocity.Length() > 2000)
                {
                    pev.velocity = pev.velocity.Normalize() * 2000;
                }
            }
        }
        else
        {
            if ((pev.effects & EF_LIGHT) != 0)
            {
                pev.effects = 0;
                g_SoundSystem.StopSound( self.edict(), CHAN_VOICE, "hlclassic/weapons/rocket1.wav" );
            }
            pev.velocity = pev.velocity * 0.2 + vecTarget * flSpeed * 0.798;
            if (pev.waterlevel == 0 && pev.velocity.Length() < 1500)
            {
                Detonate( );
            }
        }
        // ALERT( at_console, "%.0f\n", flSpeed );

        pev.nextthink = g_Engine.time + 0.1;
    }
    void ExplodeTouch( CBaseEntity@ pOther )
    {
        TraceResult tr;
        Vector		vecSpot;// trace starts here!

        @pev.enemy = pOther.edict();

        vecSpot = pev.origin - pev.velocity.Normalize() * 32;
        g_Utility.TraceLine( vecSpot, vecSpot + pev.velocity.Normalize() * 64, ignore_monsters, self.edict(), tr );

        Explode( tr, DMG_BLAST );
    }
    void Explode( TraceResult& in pTrace, int bitsDamageType )
    {
        float		flRndSound;// sound randomizer

        pev.model = String::EMPTY_STRING;//invisible
        pev.solid = SOLID_NOT;// intangible

        pev.takedamage = DAMAGE_NO;

        // Pull out of the wall a bit
        if ( pTrace.flFraction != 1.0 )
        {
            pev.origin = pTrace.vecEndPos + (pTrace.vecPlaneNormal * (pev.dmg - 24) * 0.6);
        }

        int iContents = g_EngineFuncs.PointContents ( pev.origin );
        
        NetworkMessage explosion( MSG_PAS, NetworkMessages::SVC_TEMPENTITY, pev.origin );
            explosion.WriteByte( TE_EXPLOSION );		// This makes a dynamic light and the explosion sprites/sound
            explosion.WriteCoord( pev.origin.x );	// Send to PAS because of the sound
            explosion.WriteCoord( pev.origin.y );
            explosion.WriteCoord( pev.origin.z );
            if (iContents != CONTENTS_WATER)
            {
                explosion.WriteShort( g_EngineFuncs.ModelIndex("sprites/zerogxplode.spr") );
            }
            else
            {
                explosion.WriteShort( g_EngineFuncs.ModelIndex("sprites/WXplo1.spr") );
            }
            explosion.WriteByte( uint8((pev.dmg - 50.f) * 0.6f)  ); // scale * 10
            explosion.WriteByte( 15  ); // framerate
            explosion.WriteByte( TE_EXPLFLAG_NONE );
        explosion.End();

        CSoundEnt@ pSoundEnt = GetSoundEntInstance();
        pSoundEnt.InsertSound ( bits_SOUND_COMBAT, pev.origin, NORMAL_EXPLOSION_VOLUME, 3.0, self );
        entvars_t@ pevOwner;
        if ( pev.owner !is null )
            @pevOwner = @pev.owner.vars;
        else
            @pevOwner = null;

        @pev.owner = null; // can't traceline attack owner if this is set

        g_WeaponFuncs.RadiusDamage ( self.pev.origin, pev, pevOwner, pev.dmg, pev.dmg * 2.5f, CLASS_NONE, bitsDamageType );

        if ( Math.RandomFloat( 0 , 1 ) < 0.5 )
        {
            g_Utility.DecalTrace( pTrace, DECAL_SCORCH1 );
        }
        else
        {
            g_Utility.DecalTrace( pTrace, DECAL_SCORCH2 );
        }

        flRndSound = Math.RandomFloat( 0 , 1 );

        switch ( Math.RandomLong( 0, 2 ) )
        {
            case 0: g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "hlclassic/weapons/debris1.wav", 0.55, ATTN_NORM);	break;
            case 1: g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "hlclassic/weapons/debris2.wav", 0.55, ATTN_NORM);	break;
            case 2: g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "hlclassic/weapons/debris3.wav", 0.55, ATTN_NORM);	break;
        }

        pev.effects |= EF_NODRAW;
        SetThink( ThinkFunction( Smoke ) );
        pev.velocity = g_vecZero;
        pev.nextthink = g_Engine.time + 0.3;

        if (iContents != CONTENTS_WATER)
        {
            int sparkCount = Math.RandomLong(0,3);
            for ( int i = 0; i < sparkCount; i++ )
                g_EntityFuncs.Create( "spark_shower", pev.origin, pTrace.vecPlaneNormal, false, null );
        }
    }
    void Smoke( void )
    {
        if (g_EngineFuncs.PointContents ( pev.origin ) == CONTENTS_WATER)
        {
            g_Utility.Bubbles( pev.origin - Vector( 64, 64, 64 ), pev.origin + Vector( 64, 64, 64 ), 100 );
        }
        else
        {
            NetworkMessage smoke( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, pev.origin );
                smoke.WriteByte( TE_SMOKE );
                smoke.WriteCoord( pev.origin.x );
                smoke.WriteCoord( pev.origin.y );
                smoke.WriteCoord( pev.origin.z );
                smoke.WriteShort( g_EngineFuncs.ModelIndex("sprites/steam1.spr") );
                smoke.WriteByte( uint8((pev.dmg - 50.f) * 0.8f) ); // scale * 10
                smoke.WriteByte( 12  ); // framerate
            smoke.End();
        }
        g_EntityFuncs.Remove( self );
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
	void IgniteThink( void )
    {
        // pev.movetype = MOVETYPE_TOSS;

        pev.movetype = MOVETYPE_FLY;
        pev.effects |= EF_LIGHT;

        // make rocket sound
        g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "hlclassic/weapons/rocket1.wav", 1, 0.5 );

        // rocket trail
        NetworkMessage beam(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY);
            beam.WriteByte( TE_BEAMFOLLOW );
            beam.WriteShort(self.entindex());	// entity
            beam.WriteShort(m_iTrail );	// model
            beam.WriteByte( 40 ); // life
            beam.WriteByte( 5 );  // width
            beam.WriteByte( 224 );   // r, g, b
            beam.WriteByte( 224 );   // r, g, b
            beam.WriteByte( 255 );   // r, g, b
            beam.WriteByte( 255 );	// brightness

        beam.End();  // move PHS/PVS data sending into here (SEND_ALL, SEND_PVS, SEND_PHS)



    /*
        beam.WriteByte( MSG_BROADCAST, SVC_TEMPENTITY );
        beam.WriteByte( MSG_BROADCAST, TE_BEAMFOLLOW);
            WRITE_SHORT(entindex());	// entity
        WRITE_SHORT(MSG_BROADCAST, m_iTrail );	// model
        beam.WriteByte( MSG_BROADCAST, 40 ); // life
        beam.WriteByte( MSG_BROADCAST, 5 );  // width
        beam.WriteByte( MSG_BROADCAST, 224 );   // r, g, b
        beam.WriteByte( MSG_BROADCAST, 224 );   // r, g, b
        beam.WriteByte( MSG_BROADCAST, 255 );   // r, g, b
        beam.WriteByte( MSG_BROADCAST, 255 );	// brightness
    */
        m_flIgniteTime = g_Engine.time;

        // set to follow laser spot
        SetThink( ThinkFunction( FollowThink ) );
        pev.nextthink = g_Engine.time + 0.1;
    }
	void RocketTouch( CBaseEntity@ pOther )
    {
        if ( m_pLauncher.IsValid())
        {
            CBaseEntity@ pLauncher = m_pLauncher.GetEntity();
            // my launcher is still around, tell it I'm dead.
            pLauncher.pev.iuser4--;
        }
        

        g_SoundSystem.StopSound( self.edict(), CHAN_VOICE, "hlclassic/weapons/rocket1.wav" );
        ExplodeTouch( pOther );
    }

	int m_iTrail;
	float m_flIgniteTime;
	/*CRpg@*/ EHandle m_pLauncher;// pointer back to the launcher that fired me. 
};

}