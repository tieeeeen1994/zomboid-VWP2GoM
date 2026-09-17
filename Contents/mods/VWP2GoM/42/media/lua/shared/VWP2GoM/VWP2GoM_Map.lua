local Map = {}

Map.VERSION = 1

Map.Weapons = {
    ["Base.Pistol"]                     = "MarzGuns.M92FS",
    ["Base.PistolGlock"]                = "MarzGuns.M92FS",
    ["Base.Pistolm93r"]                 = "MarzGuns.M93R",
    ["Base.Pistol2"]                    = "MarzGuns.M1911",
    ["Base.Pistol3"]                    = "MarzGuns.SW629",
    ["Base.AssaultRifle"]               = "MarzGuns.M16A2",
    ["Base.AssaultRifleA3"]             = "MarzGuns.M16A3",
    ["Base.AssaultRifleM4"]             = "MarzGuns.M4A1",
    ["Base.AssaultRifleAK47"]           = "MarzGuns.AK47",
    ["Base.AssaultRifle2"]              = "MarzGuns.M14",
    ["Base.SR25_Rifle"]                 = "MarzGuns.PSG1",
    ["Base.Shotgun"]                    = "MarzGuns.MOSSBERG_590",
    ["Base.ShotgunSawnoff"]             = "MarzGuns.REMINGTON_870",
    ["Base.JS3T_Shotgun"]               = "MarzGuns.SPAS12",
    ["Base.VarmintRifle"]               = "MarzGuns.MODEL_70",
    ["Base.HuntingRifle"]               = "MarzGuns.REMINGTON_700",
    ["Base.MSR7T_Rifle"]                = "MarzGuns.M24",
    ["Base.JS14_Rifle"]                 = "MarzGuns.MINI_14",
    ["Base.AC556"]                      = "MarzGuns.M16A3",
    ["Base.L92_Carbine"]                = "MarzGuns.W1873",
    ["Base.L94_Rifle"]                  = "MarzGuns.W1894",
    ["Base.TrapperCarbine"]             = "MarzGuns.CAMP_CARBINE",
    ["Base.JS5_smg"]                    = "MarzGuns.MP5",
    ["Base.MP5_SMG"]                    = "MarzGuns.MP5",
    ["Base.MP5SD_SMG"]                  = "MarzGuns.MP5SD",
    ["Base.DoubleBarrelShotgun"]        = "MarzGuns.DOUBLEBARREL",
    ["Base.DoubleBarrelShotgunSawnoff"] = "MarzGuns.DOUBLEBARREL",
    ["Base.Side_By_Side"]               = "MarzGuns.DOUBLEBARREL",
}

Map.RerollWeapons = {
    ["Base.Revolver"]       = true,
    ["Base.Revolver_Long"]  = true,
    ["Base.Revolver_Short"] = true,
}

Map.RerollCandidates = {
    "MarzGuns.M92FS", "MarzGuns.M93R", "MarzGuns.HIPOWER", "MarzGuns.P226", "MarzGuns.VP70M",
    "MarzGuns.TEC9", "MarzGuns.MP5K", "MarzGuns.M1911", "MarzGuns.USP", "MarzGuns.MAC10",
    "MarzGuns.DEAGLE", "MarzGuns.COLT_SINGLE", "MarzGuns.PYTHON", "MarzGuns.RHINO",
    "MarzGuns.SW629", "MarzGuns.MP412", "MarzGuns.DETECTIVE_38",
}

Map.RequiredPartSwaps = {
    ["Base.JS3T_Shotgun"] = {
        ["MarzGuns.SPAS12_Selector_Semi"] = "MarzGuns.SPAS12_Selector_Pump",
    },
    ["Base.DoubleBarrelShotgunSawnoff"] = {
        ["MarzGuns.DOUBLEBARREL_Barrel_Close"] = "MarzGuns.DOUBLEBARREL_Barrel_Sawnoff_Close",
    },
}

Map.Magazines = {
    ["Base.9mmClip"]      = "MarzGuns.9x19Magazine15_M92FS",
    ["Base.44Clip"]       = "MarzGuns.50Magazine8_DEAGLE",
    ["Base.45Clip"]       = "MarzGuns.45Magazine7_M1911",
    ["Base.M14Clip"]      = "MarzGuns.762x51Magazine20_M14",
    ["Base.JS14_Clip"]    = "MarzGuns.223Magazine20_Mini14",
    ["Base.JS14_Clip_30"] = "MarzGuns.223Magazine30_Mini14",
    ["Base.JS5_Clip"]     = "MarzGuns.9x19Magazine30_MP5",
    ["Base.556Clip_20"]   = "MarzGuns.556x45Magazine20_STANAG",
    ["Base.556Clip"]      = "MarzGuns.556x45Magazine30_STANAG",
    ["Base.556Clip_75"]   = "MarzGuns.556x45Magazine75_STANAG",
    ["Base.308Clip_10"]   = "MarzGuns.762x51Magazine20_M14",
    ["Base.308Clip_20"]   = "MarzGuns.762x51Magazine20_M14",
    ["Base.762Clip_30"]   = "MarzGuns.762x39Magazine30",
    ["Base.762Clip_75"]   = "MarzGuns.762x39Magazine75",
    ["Base.9mmClip_25"]   = "MarzGuns.9x19Magazine25_MP5",
    ["Base.9mmClip_30"]   = "MarzGuns.9x19Magazine30_MP5",
    ["Base.9mmClip_40"]   = "MarzGuns.9x19Magazine60_MP5",
    ["Base.9mmClip_100"]  = "MarzGuns.9x19Magazine100_MP5",
}

Map.Rounds = {
    ["Base.762Bullets"]   = "SWMG.762x39_Bullet",
    ["Base.Bullets9mm"]   = "SWMG.9x19_Bullet",
    ["Base.Bullets45"]    = "SWMG.45_Bullet",
    ["Base.Bullets38"]    = "SWMG.38_Bullet",
    ["Base.Bullets357"]   = "SWMG.357_Bullet",
    ["Base.Bullets44"]    = "SWMG.44_Bullet",
    ["Base.308Bullets"]   = "SWMG.762x51_Bullet",
    ["Base.556Bullets"]   = "SWMG.556x45_Bullet",
    ["Base.3030Bullets"]  = "SWMG.3030_Bullet",
    ["Base.ShotgunShells"] = "SWMG.12Gauge_Shell_Buckshot",
}

Map.AmmoPacks = {
    ["Base.762Box"]              = "MarzGuns.762x39_Box",
    ["Base.762Carton"]           = "MarzGuns.762x39_Carton",
    ["Base.Bullets9mmBox"]       = "MarzGuns.9x19_Box",
    ["Base.Bullets9mmCarton"]    = "MarzGuns.9x19_Carton",
    ["Base.Bullets45Box"]        = "MarzGuns.45_Box",
    ["Base.Bullets45Carton"]     = "MarzGuns.45_Carton",
    ["Base.Bullets38Box"]        = "MarzGuns.38_Box",
    ["Base.Bullets38Carton"]     = "MarzGuns.38_Carton",
    ["Base.Bullets357Box"]       = "MarzGuns.357_Box",
    ["Base.Bullets357Carton"]    = "MarzGuns.357_Carton",
    ["Base.308Box"]              = "MarzGuns.762x51_Box",
    ["Base.308Carton"]           = "MarzGuns.762x51_Carton",
    ["Base.556Box"]              = "MarzGuns.556x45_Box",
    ["Base.556Carton"]           = "MarzGuns.556x45_Carton",
    ["Base.3030Box"]             = "MarzGuns.3030_Box",
    ["Base.3030Carton"]          = "MarzGuns.3030_Carton",
    ["Base.ShotgunShellsBox"]    = "MarzGuns.12Gauge_Box_Buckshot",
    ["Base.ShotgunShellsCarton"] = "MarzGuns.12Gauge_Carton_Buckshot",
}

Map.AmmoRepacks = {
    ["Base.Bullets44Box"]    = { rounds = 20,  bullet = "SWMG.44_Bullet", box = "MarzGuns.44_Box", boxRounds = 25 },
    ["Base.Bullets44Carton"] = { rounds = 240, bullet = "SWMG.44_Bullet", box = "MarzGuns.44_Box", boxRounds = 25 },
}

Map.PartPriority = {
    "Base.AmmoStraps",
    "Base.M9_Bayonet_Attachment",
    "Base.AR_Silencer",
    "Base.Pistol_Silencer",
    "Base.Heavy_Pistol_Silencer",
    "Base.556Muzzle",
    "Base.762Muzzle",
    "Base.x8Scope",
    "Base.x4Scope",
    "Base.x2Scope",
    "Base.RedDot",
    "Base.TritiumSights",
    "Base.Laser",
    "Base.GunLight",
    "Base.RecoilPad",
    "Base.ChokeTubeFull",
    "Base.ChokeTubeImproved",
}

Map.Parts = {
    ["Base.x2Scope"] = {
        mount = { "MarzGuns.LR4X_Scope", "MarzGuns.Aimpoint_Sight", "MarzGuns.EXPS1_Sight" },
        loose = "MarzGuns.LR4X_Scope",
    },
    ["Base.x4Scope"] = {
        mount = { "MarzGuns.PSO1_Scope", "MarzGuns.LR10X_Scope", "MarzGuns.TA28_Scope", "MarzGuns.EXPS3_Sight" },
        loose = "MarzGuns.PSO1_Scope",
    },
    ["Base.x8Scope"] = {
        mount = { "MarzGuns.LRX12X_Scope", "MarzGuns.LR10X_Scope", "MarzGuns.TR06X_Scope" },
        loose = "MarzGuns.LRX12X_Scope",
    },
    ["Base.RedDot"] = {
        mount = { "MarzGuns.ReflexS2_Sight", "MarzGuns.Kobra_Sight", "MarzGuns.OKP3_Sight", "MarzGuns.PS1_Sight" },
        loose = "MarzGuns.ReflexS2_Sight",
    },
    ["Base.TritiumSights"] = {
        mount = { "MarzGuns.PL4_Sight", "MarzGuns.PS1_Sight" },
        loose = "MarzGuns.PL4_Sight",
    },
    ["Base.Laser"] = {
        mount = { "MarzGuns.PX1_Laser", "MarzGuns.LRX-7_Laser", "MarzGuns.AimRight_Laser" },
        loose = "MarzGuns.PX1_Laser",
        looseLongGun = "MarzGuns.LRX-7_Laser",
    },
    ["Base.GunLight"] = {
        mount = { "MarzGuns.TL_Light", "MarzGuns.LP_Light", "MarzGuns.SR7_Light", "MarzGuns.BrightPoint-5_Light" },
        loose = "MarzGuns.TL_Light",
        looseLongGun = "MarzGuns.SR7_Light",
    },
    ["Base.Pistol_Silencer"] = {
        mount = { "MarzGuns.Shh9_Suppressor", "MarzGuns.P45_Suppressor" },
        loose = "MarzGuns.Shh9_Suppressor",
    },
    ["Base.Heavy_Pistol_Silencer"] = {
        mount = { "MarzGuns.P45_Suppressor" },
        loose = "MarzGuns.P45_Suppressor",
    },
    ["Base.AR_Silencer"] = {
        mount = { "MarzGuns.MKI_Suppressor", "MarzGuns.NDR_Suppressor", "MarzGuns.PBS-1_Suppressor" },
        loose = "MarzGuns.MKI_Suppressor",
    },
    ["Base.556Muzzle"] = {
        mount = { "MarzGuns.LX_Flashhider" },
        loose = "MarzGuns.LX_Flashhider",
    },
    ["Base.762Muzzle"] = {
        mount = { "MarzGuns.AK_Muzzle_Mount_Device" },
        loose = "MarzGuns.LX_Flashhider",
    },
    ["Base.ChokeTubeFull"] = {
        mount = { "MarzGuns.LR2_Compensator" },
        loose = "MarzGuns.LR2_Compensator",
    },
    ["Base.ChokeTubeImproved"] = {
        mount = { "MarzGuns.LX_Flashhider" },
        loose = "MarzGuns.LX_Flashhider",
    },
    ["Base.RecoilPad"] = {
        mount = { "MarzGuns.Shellholder", "MarzGuns.Stub_Foregrip" },
        loose = "MarzGuns.Shellholder",
    },
    ["Base.AmmoStraps"] = {
        mount = { "MarzGuns.Shellholder", "MarzGuns.Rem700_Sling", "MarzGuns.Model_70_Sling" },
        loose = "MarzGuns.Shellholder",
        looseLongGun = "MarzGuns.Rem700_Sling",
    },
    ["Base.M9_Bayonet_Attachment"] = {
        mount = { "MarzGuns.M9_Bayonet_Attachment" },
        loose = "MarzGuns.M9_BAYONET",
        bayonet = true,
    },
}

Map.InternalPartTypes = {
    Clip = true,
    MovingBolt = true,
    StockIntegrated = true,
    Barrel = true,
}

Map.Barrels = {
    ["Base.Side_By_Side_Barrel_Close"]         = "MarzGuns.DOUBLEBARREL_Barrel_Close",
    ["Base.Side_By_Side_Barrel_Open"]          = "MarzGuns.DOUBLEBARREL_Barrel_Close",
    ["Base.Side_By_Side_Barrel_Sawnoff_Close"] = "MarzGuns.DOUBLEBARREL_Barrel_Sawnoff_Close",
    ["Base.Side_By_Side_Barrel_Sawnoff_Open"]  = "MarzGuns.DOUBLEBARREL_Barrel_Sawnoff_Close",
}

Map.LooseOther = {
    ["Base.M9_Bayonet"]                        = "MarzGuns.M9_BAYONET",
    ["Base.Attack_Bayonet"]                    = "MarzGuns.Attack_Bayonet",
    ["Base.GenericFakeItem"]                   = "MarzGuns.FakeItem",
    ["Base.OpenBolt"]                          = "MarzGuns.Bolt_Lock",
    ["Base.CloseBolt"]                         = "MarzGuns.Bolt_Lock",
    ["Base.JS5_Stock_Folded"]                  = "MarzGuns.MP5_Integrated_Stock_Folded",
    ["Base.JS5_Stock_Deployed"]                = "MarzGuns.MP5_Integrated_Stock_Deployed",
    ["Base.Side_By_Side_Barrel_Close"]         = "MarzGuns.DOUBLEBARREL_Barrel_Close",
    ["Base.Side_By_Side_Barrel_Open"]          = "MarzGuns.DOUBLEBARREL_Barrel_Open",
    ["Base.Side_By_Side_Barrel_Sawnoff_Close"] = "MarzGuns.DOUBLEBARREL_Barrel_Sawnoff_Close",
    ["Base.Side_By_Side_Barrel_Sawnoff_Open"]  = "MarzGuns.DOUBLEBARREL_Barrel_Sawnoff_Open",
}

Map.TransientModData = {
    AmmoList = true,
    SpentAmmoList = true,
    MagazineType = true,
    MagazineTypeLastIndex = true,
    ActiveAmmoProfile = true,
    GW_CachedBayonetSpear = true,
    GW_BayonetOriginalWeapon = true,
    GW_BayonetDeployed = true,
    GWG_FiringExplosiveAmmo = true,
    shortRackAfterInsert = true,
    Gunworks_SpawnerItemType = true,
    StockFolded = true,
    VWP2GoM = true,
}

function Map.IsSource(fullType)
    return Map.Weapons[fullType] ~= nil
        or Map.RerollWeapons[fullType] ~= nil
        or Map.Magazines[fullType] ~= nil
        or Map.Rounds[fullType] ~= nil
        or Map.AmmoPacks[fullType] ~= nil
        or Map.AmmoRepacks[fullType] ~= nil
        or Map.Parts[fullType] ~= nil
        or Map.LooseOther[fullType] ~= nil
end

return Map
