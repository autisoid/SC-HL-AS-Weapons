#include "weapon_hldm_gauss"
#include "weapon_hldm_egon"
#include "weapon_hldm_hornetgun"
#include "weapon_hldm_shotgun"
#include "weapon_hldm_crowbar"
#include "weapon_hldm_9mmAR"
#include "weapon_hldm_glock"
#include "weapon_hldm_357"
#include "weapon_sc_grenade"
#include "weapon_sc_medkit"
#include "weapon_hlopfor_pipewrench"
#include "weapon_hldm_xbow"
#include "weapon_hlopfor_deagle"
#include "weapon_hlopfor_sniperrifle"
#include "weapon_hlopfor_m249"
#include "weapon_hlopfor_sporelauncher"
#include "weapon_hldm_squeakgrenade"
#include "weapon_hlopfor_grapple"
#include "weapon_hlopfor_displacer"
#include "weapon_hlopfor_knife"
#include "weapon_hldm_satchelcharge"
#include "weapon_hldm_tripmine"
#include "weapon_hldm_rpg"
#include "weapon_hlopfor_penguingrenade"

enum eModelsMode {
    kDefaultClassic = 0,
    kBlueShift,
    kOpposingForce
}

int g_eModelsMode = kDefaultClassic;

void PrecacheHLDMWeaponsSprites() {
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hlopfor_displacer.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hldm_egon.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hldm_hornetgun.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hldm_9mmAR.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hldm_357.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hldm_crowbar.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hldm_gauss.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hldm_glock.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hldm_handgrenade.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_sc_medkit.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hlopfor_pipewrench.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hldm_xbow.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hlopfor_deagle.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hlopfor_sniperrifle.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hlopfor_m249.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hlopfor_sporelauncher.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hldm_squeakgrenade.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hlopfor_grapple.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hlopfor_knife.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hldm_satchelcharge.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hldm_tripmine.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hldm_rpg.txt");
    g_Game.PrecacheGeneric("sprites/scanarchy/weapon_hlopfor_penguingrenade.txt");
}

void PrecacheTheWeapons() {
    g_Game.PrecacheOther("weapon_hlopfor_displacer");
    g_Game.PrecacheOther("weapon_hldm_egon");
    g_Game.PrecacheOther("weapon_hldm_hornetgun");
    g_Game.PrecacheOther("weapon_hldm_9mmAR");
    g_Game.PrecacheOther("weapon_hldm_357");
    g_Game.PrecacheOther("weapon_hldm_crowbar");
    g_Game.PrecacheOther("weapon_hldm_gauss");
    g_Game.PrecacheOther("weapon_hldm_glock");
    g_Game.PrecacheOther("weapon_hldm_handgrenade");
    g_Game.PrecacheOther("weapon_sc_medkit");
    g_Game.PrecacheOther("weapon_hlopfor_pipewrench");
    g_Game.PrecacheOther("weapon_hldm_xbow");
    g_Game.PrecacheOther("weapon_hlopfor_deagle");
    g_Game.PrecacheOther("weapon_hlopfor_sniperrifle");
    g_Game.PrecacheOther("weapon_hlopfor_m249");
    g_Game.PrecacheOther("weapon_hlopfor_sporelauncher");
    g_Game.PrecacheOther("weapon_hldm_squeakgrenade");
    g_Game.PrecacheOther("weapon_hlopfor_grapple");
    g_Game.PrecacheOther("weapon_hlopfor_knife");
    g_Game.PrecacheOther("weapon_hldm_satchelcharge");
    g_Game.PrecacheOther("weapon_hldm_tripmine");
    g_Game.PrecacheOther("weapon_hldm_rpg");
    g_Game.PrecacheOther("weapon_hlopfor_penguingrenade");
    
    //special precache for the penguins
    g_Game.PrecacheModel("models/scanarchy/opfor/w_penguinnest.mdl");
    g_Game.PrecacheModel("models/scanarchy/opfor/w_penguin.mdl");
    g_Game.PrecacheModel("models/scanarchy/opfor/v_penguin.mdl");
    g_Game.PrecacheModel("models/scanarchy/opfor/p_penguin.mdl");
}

void RegisterHLDMWeapons() {
    PrecacheHLDMWeaponsSprites();

    HLPYTHON::g_eModelsMode = g_eModelsMode;
    HLPYTHON::Register();
    
    HLDMGAUSS::g_eModelsMode = g_eModelsMode;
    HLDMGAUSS::Register();
    
    HLDMSHOTGUN::g_eModelsMode = g_eModelsMode;
    HLDMSHOTGUN::Register();
    
    CLCROWBAR::g_eModelsMode = g_eModelsMode;
    CLCROWBAR::Register();
    
    HLDMMP5::g_eModelsMode = g_eModelsMode;
    HLDMMP5::Register();
    
    HLDMGLOCK::g_eModelsMode = g_eModelsMode;
    HLDMGLOCK::Register();
    
    SCGRENADE::g_eModelsMode = g_eModelsMode;
    SCGRENADE::Register();
    
    SCMEDKIT::g_eModelsMode = g_eModelsMode;
    SCMEDKIT::Register();
    
    HLOPFORWRENCH::Register();
    
    HLDMXBOW::g_eModelsMode = g_eModelsMode;
    HLDMXBOW::Register();
    
    HLDMSQUEAK::g_eModelsMode = g_eModelsMode;
    HLDMSQUEAK::Register();
    
    HLOPFORGRAPPLE::Register();
    
    HLCEgon::g_eModelsMode = g_eModelsMode;
    HLCEgon::Register();
    
    HLCHornetGun::Register();
    
    HLOPFORDISPLACER::Register();
    
    HLDMSATCHELCHARGE::g_eModelsMode = g_eModelsMode;
    HLDMSATCHELCHARGE::Register();
    
    HLDMTRIPMINE::g_eModelsMode = g_eModelsMode;
    HLDMTRIPMINE::Register();
    
    HLDMRPG::g_eModelsMode = g_eModelsMode;
    HLDMRPG::Register();
    
    COFEagle::Register();
    COFKnife::Register();
    COFM249::Register();
    //COFPenguin::Register();
    //COFShockRifle::Register();
    COFSniperRifle::Register();
    COFSporeLauncher::Register();
    
    HLOPFORPENGUIN::g_eModelsMode = g_eModelsMode;
    HLOPFORPENGUIN::Register();
    
    PrecacheTheWeapons();
}