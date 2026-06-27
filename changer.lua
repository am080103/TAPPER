-- ============================================================
-- changer.lua – Skin & Model Changer (FULL WORKING)
-- ============================================================

local ffi = ffi
local band, rshift, bxor, lshift = bit.band, bit.rshift, bit.bxor, bit.lshift
local floor = math.floor

local off = {}

local DUMPER = "https://raw.githubusercontent.com/a2x/cs2-dumper/main/output/"

local FIELDS = {
    m_pWeaponServices      = "m_pWeaponServices",
    m_hMyWeapons           = "m_hMyWeapons",
    m_hActiveWeapon        = "m_hActiveWeapon",
    m_AttributeManager     = { "m_AttributeManager", "C_EconEntity" },
    m_Item                 = "m_Item",
    m_pGameSceneNode       = "m_pGameSceneNode",
    m_modelState           = { "m_modelState", "CSkeletonInstance" },
    m_hModel               = { "m_hModel", "CModelState" },
    m_nSubclassID          = "m_nSubclassID",
    m_iTeamNum             = "m_iTeamNum",
    m_iHealth              = "m_iHealth",
    m_lifeState            = "m_lifeState",
    m_hOwnerEntity         = "m_hOwnerEntity",
    m_hPlayerPawn          = "m_hPlayerPawn",
    m_steamID              = "m_steamID",
    m_iItemDefinitionIndex = "m_iItemDefinitionIndex",
    m_bRestoreCustomMat    = "m_bRestoreCustomMaterialAfterPrecache",
    m_iEntityQuality       = "m_iEntityQuality",
    m_iItemIDLow           = "m_iItemIDLow",
    m_iItemIDHigh          = "m_iItemIDHigh",
    m_iAccountID           = "m_iAccountID",
    m_OriginalOwnerXuidLow = { "m_OriginalOwnerXuidLow", "C_EconEntity" },
    m_bInitialized         = "m_bInitialized",
    m_bDisallowSOC         = "m_bDisallowSOC",
    m_AttributeList        = "m_AttributeList",
    m_Attributes           = "m_Attributes",
    m_nFallbackPaintKit    = { "m_nFallbackPaintKit", "C_EconEntity" },
    m_nFallbackSeed        = { "m_nFallbackSeed", "C_EconEntity" },
    m_flFallbackWear       = { "m_flFallbackWear", "C_EconEntity" },
    m_nFallbackStatTrak    = { "m_nFallbackStatTrak", "C_EconEntity" },
    m_EconGloves           = { "m_EconGloves", "C_CSPlayerPawn" },
    m_bNeedToReApplyGloves = { "m_bNeedToReApplyGloves", "C_CSPlayerPawn" },
}
local function pull_offset(j, name, after)
    local init = 1
    if after then local p = j:find('"' .. after .. '"%s*:%s*{'); if p then init = p end end
    local v = j:match('"' .. name .. '"%s*:%s*(%d+)', init)
    return v and tonumber(v) or nil
end
pcall(function()
    local j = http.Get(DUMPER .. "client_dll.json")
    if type(j) ~= "string" then return end
    for key, spec in pairs(FIELDS) do
        local name, after = spec, nil
        if type(spec) == "table" then name, after = spec[1], spec[2] end
        local v = pull_offset(j, name, after)
        if v then off[key] = v end
    end
end)
off.m_szWorldModel = 48
off.m_modelState = off.m_modelState or 336
off.m_hModel     = off.m_hModel     or 160

local function r_u8 (a) return ffi.cast("uint8_t*",  a)[0] end
local function r_u16(a) return ffi.cast("uint16_t*", a)[0] end
local function r_i32(a) return ffi.cast("int32_t*",  a)[0] end
local function r_u32(a) return ffi.cast("uint32_t*", a)[0] end
local function r_u64(a) return ffi.cast("uint64_t*", a)[0] end
local function r_ptr(a) return tonumber(ffi.cast("uint64_t*", a)[0]) end
local function w_u8 (a,v) ffi.cast("uint8_t*",  a)[0]=v end
local function w_u16(a,v) ffi.cast("uint16_t*", a)[0]=v end
local function w_i32(a,v) ffi.cast("int32_t*",  a)[0]=v end
local function w_u32(a,v) ffi.cast("uint32_t*", a)[0]=v end
local function w_u64(a,v) ffi.cast("uint64_t*", a)[0]=v end
local function w_f32(a,v) ffi.cast("float*",    a)[0]=v end
local function valid(p) return p ~= nil and p > 0x10000 and p < 0x7FFFFFFFFFFF end
local function read_cstr(a, max)
    if not valid(a) then return "" end
    local t = {}
    for i = 0, (max or 160) - 1 do
        local c = r_u8(a + i); if c == 0 then break end
        t[#t+1] = string.char(c)
    end
    return table.concat(t)
end

local function sig_rva(modBase, mod, pattern, instrLen)
    if not modBase then return nil end
    local a = mem.FindPattern(mod, pattern); if not a or a == 0 then return nil end
    a = tonumber(a)
    return (a + instrLen + r_i32(a + 3)) - modBase
end
local function sig_disp(mod, pattern)
    local a = mem.FindPattern(mod, pattern); if not a or a == 0 then return nil end
    return r_i32(tonumber(a) + 3)
end
do
    local cb = mem.GetModuleBase("client.dll")
    local eb = mem.GetModuleBase("engine2.dll")
    off.dwEntityList            = sig_rva(cb, "client.dll",  "48 89 0D ?? ?? ?? ?? E9 ?? ?? ?? ?? CC", 7)
    off.dwLocalPlayerController = sig_rva(cb, "client.dll",  "48 8B 05 ?? ?? ?? ?? 41 89 BE", 7)
    off.dwNetworkGameClient     = sig_rva(eb, "engine2.dll", "48 89 3D ?? ?? ?? ?? FF 87", 7)
    off.dwNetworkGameClient_signOnState = sig_disp("engine2.dll", "44 8B 81 ?? ?? ?? ?? 48 8D 0D")
    if not off.dwLocalPlayerController or not off.dwEntityList or not off.m_hMyWeapons then
        print("[changer] WARNING: signatures/netvars not resolved -- changer inactive")
    else
        print(string.format("[changer] sigs ok: entlist=%X ctrl=%X ngc=%s",
            off.dwEntityList, off.dwLocalPlayerController,
            off.dwNetworkGameClient and string.format("%X", off.dwNetworkGameClient) or "nil"))
    end
end

local function tou32(x) x = x % 0x100000000; if x < 0 then x = x + 0x100000000 end; return x end
local function mul32(a, b)
    a = a % 0x100000000; b = b % 0x100000000
    local ah, al = floor(a/0x10000), a%0x10000
    local bh = floor(b/0x10000)
    return (al*(b%0x10000) + ((al*bh + ah*(b%0x10000)) % 0x10000)*0x10000) % 0x100000000
end
local MM = 0x5bd1e995
local function murmur2(str, seed)
    local len = #str
    local h = tou32(bxor(seed, len))
    local i, rem = 1, len
    while rem >= 4 do
        local b0,b1,b2,b3 = str:byte(i, i+3)
        local k = b0 + b1*256 + b2*65536 + b3*16777216
        k = mul32(k, MM); k = tou32(bxor(k, rshift(k, 24))); k = mul32(k, MM)
        h = mul32(h, MM); h = tou32(bxor(h, k))
        i = i + 4; rem = rem - 4
    end
    if rem >= 3 then h = tou32(bxor(h, lshift(str:byte(i+2), 16))) end
    if rem >= 2 then h = tou32(bxor(h, lshift(str:byte(i+1), 8))) end
    if rem >= 1 then h = tou32(bxor(h, str:byte(i))); h = mul32(h, MM) end
    h = tou32(bxor(h, rshift(h, 13))); h = mul32(h, MM); h = tou32(bxor(h, rshift(h, 15)))
    return h
end
local function subclass_hash(def) return murmur2(tostring(def):lower(), 0x31415926) end

local DLL = "client.dll"
local sig = {
    set_model      = "40 53 48 83 EC ?? 48 8B D9 4C 8B C2 48 8B 0D ?? ?? ?? ?? 48 8D 54 24 40",
    update_subclass= "4C 8B DC 53 48 81 EC ?? ?? ?? ?? 48 8B 41",
    set_mesh_mask  = "48 89 5C 24 ?? 48 89 74 24 ?? 57 48 83 EC ?? 48 8D 99 ?? ?? ?? ?? 48 8B 71",
    regen_skins    = "48 83 EC ?? E8 ?? ?? ?? ?? 48 85 C0 0F 84 ?? ?? ?? ?? 48 8B 10",
}
local SBG_SIG = "E8 ?? ?? ?? ?? EB 0C 48 8B CF"
local fn, fnptr = {}, {}
local function resolve()
    for name, pattern in pairs(sig) do
        if not fn[name] then local a = mem.FindPattern(DLL, pattern); if a and a ~= 0 then fn[name] = a end end
    end
    if not fn.set_body_group then
        local a = mem.FindPattern(DLL, SBG_SIG)
        if a and a ~= 0 then fn.set_body_group = a + 5 + r_i32(a + 1) end
    end
    if fn.set_model       and not fnptr.set_model       then fnptr.set_model       = ffi.cast("void(*)(void*, const char*)", fn.set_model) end
    if fn.update_subclass and not fnptr.update_subclass then fnptr.update_subclass = ffi.cast("void(*)(void*)",              fn.update_subclass) end
    if fn.set_mesh_mask   and not fnptr.set_mesh_mask   then fnptr.set_mesh_mask   = ffi.cast("void(*)(void*, uint64_t)",    fn.set_mesh_mask) end
    if fn.regen_skins     and not fnptr.regen_skins     then fnptr.regen_skins     = ffi.cast("void(*)(void)",               fn.regen_skins) end
    if fn.set_body_group  and not fnptr.set_body_group  then fnptr.set_body_group  = ffi.cast("void(*)(void*, const char*, unsigned int)", fn.set_body_group) end
end
local function vfunc(this, index)
    if not valid(this) then return nil end
    local vt = r_ptr(this); if not valid(vt) then return nil end
    local f = r_ptr(vt + index*8); if not valid(f) then return nil end
    return f
end
local function vcall_void(this, index)
    local f = vfunc(this, index); if not f then return end
    ffi.cast("void(*)(void*)", f)(ffi.cast("void*", this))
end
local function vcall_void_bool(this, index, b)
    local f = vfunc(this, index); if not f then return end
    ffi.cast("void(*)(void*, int)", f)(ffi.cast("void*", this), b and 1 or 0)
end

local KNIVES = {
    { name = "Default (no swap)", def = nil },
    { name = "Bayonet",        def = 500 }, { name = "Classic Knife",  def = 503 },
    { name = "Flip Knife",     def = 505 }, { name = "Gut Knife",      def = 506 },
    { name = "Karambit",       def = 507 }, { name = "M9 Bayonet",     def = 508 },
    { name = "Huntsman",       def = 509 }, { name = "Falchion",       def = 512 },
    { name = "Bowie Knife",    def = 514 }, { name = "Butterfly",      def = 515 },
    { name = "Shadow Daggers", def = 516 }, { name = "Paracord Knife", def = 517 },
    { name = "Survival Knife", def = 518 }, { name = "Ursus Knife",    def = 519 },
    { name = "Navaja Knife",   def = 520 }, { name = "Nomad Knife",    def = 521 },
    { name = "Stiletto",       def = 522 }, { name = "Talon Knife",    def = 523 },
    { name = "Skeleton Knife", def = 525 }, { name = "Kukri Knife",    def = 526 },
}
local WEAPONS = {
    { name = "AK-47",        def = 7  }, { name = "M4A4",         def = 16 },
    { name = "M4A1-S",       def = 60 }, { name = "AWP",          def = 9  },
    { name = "SSG 08",       def = 40 }, { name = "SCAR-20",      def = 38 },
    { name = "G3SG1",        def = 11 }, { name = "SG 553",       def = 39 },
    { name = "AUG",          def = 8  }, { name = "FAMAS",        def = 10 },
    { name = "Galil AR",     def = 13 }, { name = "Desert Eagle", def = 1  },
    { name = "R8 Revolver",  def = 64 }, { name = "Dual Berettas",def = 2  },
    { name = "Five-SeveN",   def = 3  }, { name = "Glock-18",     def = 4  },
    { name = "Tec-9",        def = 30 }, { name = "P2000",        def = 32 },
    { name = "P250",         def = 36 }, { name = "USP-S",        def = 61 },
    { name = "CZ75-Auto",    def = 63 }, { name = "MAC-10",       def = 17 },
    { name = "P90",          def = 19 }, { name = "PP-Bizon",     def = 26 },
    { name = "MP5-SD",       def = 23 }, { name = "MP7",          def = 33 },
    { name = "MP9",          def = 34 }, { name = "UMP-45",       def = 24 },
    { name = "M249",         def = 14 }, { name = "Negev",        def = 28 },
    { name = "XM1014",       def = 25 }, { name = "MAG-7",        def = 27 },
    { name = "Nova",         def = 35 }, { name = "Sawed-Off",    def = 29 },
}
local GLOVES = {
    { name = "Default (off)",      def = 0    },
    { name = "Bloodhound Gloves",  def = 5027 }, { name = "Sport Gloves",      def = 5030 },
    { name = "Driver Gloves",      def = 5031 }, { name = "Hand Wraps",        def = 5032 },
    { name = "Moto Gloves",        def = 5033 }, { name = "Specialist Gloves", def = 5034 },
    { name = "Hydra Gloves",       def = 5035 }, { name = "Broken Fang Gloves",def = 4725 },
}
local function is_knife(def) return def == 42 or def == 59 or (def >= 500 and def <= 526) end

-- ============================================================
-- SKINS TABLE – LOADED FROM GLOBAL (set by skins_data.lua)
-- ============================================================
local SKINS = _G.FEMBOYTAP_SKINS or {}
if next(SKINS) == nil then
    print("[changer] WARNING: SKINS table not loaded – skin changer will be limited")
end

-- ============================================================
-- SKIN LIST HELPER
-- ============================================================
local function skin_list_for(def)
    local names  = { "[ None ]" }
    local paints = { 0 }
    local src = def and SKINS[def]
    if src then
        for i = 1, #src do
            names[i+1]  = src[i][1]
            paints[i+1] = src[i][2]
        end
    end
    return names, paints
end

-- ============================================================
-- ITEMS DEFINITION
-- ============================================================
local ITEMS = {}
local function add_item(name, def, kind) ITEMS[#ITEMS+1] = { name = name, def = def, kind = kind } end

for i = 1, #KNIVES do
    local k = KNIVES[i]
    if k.def then add_item("[Knife] " .. k.name, k.def, "knife") end
end
for i = 1, #WEAPONS do
    add_item(WEAPONS[i].name, WEAPONS[i].def, "weapon")
end
for i = 1, #GLOVES do
    local g = GLOVES[i]
    add_item(g.def == 0 and "[Glove] Default (off)" or "[Glove] " .. g.name, g.def, "glove")
end

local itemNames = {}; for i = 1, #ITEMS do itemNames[i] = ITEMS[i].name end

local DEF_TO_ITEM = {}
for i = 1, #ITEMS do
    if ITEMS[i].kind ~= "glove" then DEF_TO_ITEM[ITEMS[i].def] = i end
end

-- ============================================================
-- STATE
-- ============================================================
local state = {
    cfg          = {},
    opts         = {},
    knifeDef     = nil,
    gloveDef     = nil,
    applied      = {},
    pendingReset = {},
    resetKnife   = false,
    resetGlove   = false,
    localModel       = nil,
    appliedLocalModel= nil,
    origModelPawn    = nil,
    origModelName    = nil,
    overrideActive   = false,
}

local Config = {}
local g_activeDef = nil

local function item_ptr(wpn) return wpn + off.m_AttributeManager + off.m_Item end
local function safe_wear(wear)
    if not wear or wear <= 0 then return 0.0001 end
    return wear
end

local function write_fallback(wpn, paint, wear, seed, stat, statval)
    w_i32(wpn + off.m_nFallbackPaintKit, paint)
    w_f32(wpn + off.m_flFallbackWear, safe_wear(wear))
    w_i32(wpn + off.m_nFallbackSeed, seed)
    w_i32(wpn + off.m_nFallbackStatTrak, stat and (statval or 0) or -1)
end

local function mark_item_custom(item)
    w_u32(item + off.m_iItemIDHigh, 0xFFFFFFFF)
    w_u8 (item + off.m_bInitialized, 1)
    w_u8 (item + off.m_bDisallowSOC, 0)
    w_u8 (item + off.m_bRestoreCustomMat, 1)
end

local function refresh_econ(wpn)
    vcall_void_bool(wpn, 10, true)
    vcall_void_bool(wpn, 110, true)
end

local function apply_knife_model(wpn)
    if fnptr.set_model then
        local vdata = r_ptr(wpn + off.m_nSubclassID + 8)
        if valid(vdata) then
            local s = read_cstr(vdata + off.m_szWorldModel, 160)
            if s:find("models/") and s:find("%.vmdl") then fnptr.set_model(ffi.cast("void*", wpn), s) end
        end
    end
    if fnptr.set_mesh_mask then
        local node = r_ptr(wpn + off.m_pGameSceneNode)
        if valid(node) then fnptr.set_mesh_mask(ffi.cast("void*", node), 2) end
    end
end

local function set_knife_subclass(wpn, def_target, quality)
    local item = item_ptr(wpn)
    w_u16(item + off.m_iItemDefinitionIndex, def_target)
    w_i32(item + off.m_iEntityQuality, quality)
    w_u32(wpn + off.m_nSubclassID, subclass_hash(def_target))
    if fnptr.update_subclass then fnptr.update_subclass(ffi.cast("void*", wpn)) end
    apply_knife_model(wpn)
    return item
end

local function process_knife(wpn, def_target, paint, wear, seed, stat, statval)
    local item = set_knife_subclass(wpn, def_target, 3)
    mark_item_custom(item)
    write_fallback(wpn, paint, wear, seed, stat, statval)
    refresh_econ(wpn)
    vcall_void(wpn, 195)
end

-- ============================================================
-- FIX: Added vcall_void(wpn, 195) to force skin update
-- ============================================================
local function process_weapon(wpn, paint, wear, seed, stat, statval)
    mark_item_custom(item_ptr(wpn))
    write_fallback(wpn, paint, wear, seed, stat, statval)
    refresh_econ(wpn)
    vcall_void(wpn, 195)  -- Force weapon to re-apply its skin
end

local function restore_weapon(wpn)
    write_fallback(wpn, 0, 0.0001, 0, false)
    refresh_econ(wpn)
    vcall_void(wpn, 195)
end

local function restore_knife(wpn, pawn)
    local def_target = (r_u8(pawn + off.m_iTeamNum) == 2) and 59 or 42
    set_knife_subclass(wpn, def_target, 0)
    write_fallback(wpn, 0, 0.0001, 0, false)
    refresh_econ(wpn)
    vcall_void(wpn, 195)
end

local ATTR_STRUCT = 72

local game_alloc, game_free
local function resolve_mem()
    if game_alloc then return true end
    pcall(function() ffi.cdef[[ void* GetModuleHandleA(const char*); ]] end)
    pcall(function() ffi.cdef[[ void* GetProcAddress(void*, const char*); ]] end)
    local tier0
    pcall(function() tier0 = ffi.C.GetModuleHandleA("tier0.dll") end)
    if not tier0 then return false end
    local pa, pf
    pcall(function() pa = ffi.C.GetProcAddress(tier0, "MemAlloc_AllocFunc") end)
    pcall(function() pf = ffi.C.GetProcAddress(tier0, "MemAlloc_FreeFunc") end)
    if not pa or not pf then return false end
    pcall(function()
        game_alloc = ffi.cast("void*(*)(size_t)", pa)
        game_free  = ffi.cast("void(*)(void*)", pf)
    end)
    return game_alloc ~= nil and game_free ~= nil
end

local function glove_attr_remove(item)
    local addr = item + off.m_AttributeList + off.m_Attributes
    local size = r_ptr(addr)
    local ptr  = r_ptr(addr + 8)
    w_u64(addr, 0); w_u64(addr + 8, 0)
    if game_free and size ~= 0 and valid(ptr) then
        pcall(function() game_free(ffi.cast("void*", ptr)) end)
    end
end

local function glove_attr_set(item, paint, seed, wear)
    glove_attr_remove(item)
    if paint <= 0 then return end
    if not resolve_mem() then return end
    wear = safe_wear(wear)
    local raw  = game_alloc(ATTR_STRUCT * 3)
    local bptr = tonumber(ffi.cast("uintptr_t", raw))
    if not bptr or bptr == 0 then return end
    for i = 0, (ATTR_STRUCT * 3) / 8 - 1 do w_u64(bptr + i * 8, 0) end
    local function mk(i, def, val)
        local b = bptr + i * ATTR_STRUCT
        w_u16(b + 0x30, def); w_f32(b + 0x34, val); w_f32(b + 0x38, val)
    end
    mk(0, 6, paint)
    mk(1, 7, seed)
    mk(2, 8, wear)
    local addr = item + off.m_AttributeList + off.m_Attributes
    w_u64(addr, 3)
    w_u64(addr + 8, bptr)
end

local function local_account_id(base)
    local ctrl = r_ptr(base + off.dwLocalPlayerController)
    if not valid(ctrl) then return 0 end
    local sid = r_u64(ctrl + off.m_steamID)
    return tonumber(sid % 0x100000000)
end

local glove_key, glove_apply = nil, 0
local function apply_gloves(base, pawn, gdef, paint, wear, seed)
    local g    = pawn + off.m_EconGloves
    local cur  = r_u16(g + off.m_iItemDefinitionIndex)
    local init = r_u8 (g + off.m_bInitialized)
    local key  = gdef.."|"..paint.."|"..floor(wear*100000).."|"..seed

    if key ~= glove_key then glove_key = key; glove_apply = 6 end
    local engine_reset = (cur ~= gdef) or (init == 0)
    if engine_reset and glove_apply <= 0 then glove_apply = 2 end

    if glove_apply > 0 then
        local acc = local_account_id(base)
        w_u8 (g + off.m_bInitialized, 0)
        w_u16(g + off.m_iItemDefinitionIndex, gdef)
        w_i32(g + off.m_iEntityQuality, 3)
        w_u32(g + off.m_iItemIDHigh, 0xFFFFFFFF)
        w_u32(g + off.m_iItemIDLow,  0xFFFFFFFF)
        w_u32(g + off.m_iAccountID, acc)
        w_u32(g + off.m_OriginalOwnerXuidLow, acc)
        glove_attr_set(g, paint, seed, wear)
        w_u8 (g + off.m_bDisallowSOC, 0)
        w_u8 (g + off.m_bRestoreCustomMat, 1)
        w_u8 (g + off.m_bInitialized, 1)
        w_u8 (pawn + off.m_bNeedToReApplyGloves, 1)
        if fnptr.set_body_group then
            pcall(function() fnptr.set_body_group(ffi.cast("void*", pawn), "first_or_third_person", 1) end)
        end
        glove_apply = glove_apply - 1
    end
end

local function reset_gloves(pawn)
    local g = pawn + off.m_EconGloves
    w_u8 (g + off.m_bInitialized, 0)
    w_u16(g + off.m_iItemDefinitionIndex, 0)
    glove_attr_remove(g)
    w_u8 (pawn + off.m_bNeedToReApplyGloves, 1)
    glove_key, glove_apply = nil, 0
    if fnptr.set_body_group then
        pcall(function() fnptr.set_body_group(ffi.cast("void*", pawn), "first_or_third_person", 1) end)
    end
end

local function handle_to_entity(elist, hnd)
    if not valid(elist) or hnd == 0 or hnd == 0xFFFFFFFF then return nil end
    local idx   = band(hnd, 0x7FFF)
    local chunk = r_ptr(elist + 8 * rshift(idx, 9) + 16); if not valid(chunk) then return nil end
    local e     = r_ptr(chunk + 112 * band(idx, 0x1FF))
    if valid(e) and valid(r_ptr(e)) then return e end
    return nil
end

local function pawn_alive(pawn)
    local ls = r_u8 (pawn + off.m_lifeState)
    local hp = r_i32(pawn + off.m_iHealth)
    return ls == 0 and hp > 0 and hp < 100000
end

local function in_game()
    local cl, so = off.dwNetworkGameClient, off.dwNetworkGameClient_signOnState
    if not cl or not so then return true end
    local eng = mem.GetModuleBase("engine2.dll"); if not eng then return true end
    local client = r_ptr(eng + cl); if not valid(client) then return false end
    return r_i32(client + so) == 6
end

local function get_live_local()
    local ok, lp = pcall(entities.GetLocalPlayer)
    if not ok or not lp then return nil end
    local alive = false
    pcall(function() alive = lp:IsAlive() end)
    return alive and lp or nil
end

local model_ffi_done = false
local function model_ffi()
    if model_ffi_done then return end
    model_ffi_done = true
    pcall(function() ffi.cdef[[
        typedef struct {
            uint32_t dwFileAttributes;
            uint32_t ftCreationLo, ftCreationHi;
            uint32_t ftAccessLo,   ftAccessHi;
            uint32_t ftWriteLo,    ftWriteHi;
            uint32_t nFileSizeHigh, nFileSizeLow;
            uint32_t dwReserved0,  dwReserved1;
            char     cFileName[260];
            char     cAlternateFileName[14];
        } AW_FIND_DATA;
        void*    FindFirstFileA(const char*, AW_FIND_DATA*);
        int      FindNextFileA(void*, AW_FIND_DATA*);
        int      FindClose(void*);
        uint32_t GetCurrentDirectoryA(uint32_t, char*);
        typedef struct {
            int32_t  m_nLength;
            uint32_t m_nAllocatedSize;
            union { char* p; char s[8]; } u;
        } AW_CBufStr;
    ]] end)
    pcall(function() ffi.cdef[[ void* GetModuleHandleA(const char*); ]] end)
    pcall(function() ffi.cdef[[ void* GetProcAddress(void*, const char*); ]] end)
end

local function find_invalid() return ffi.cast("void*", ffi.cast("intptr_t", -1)) end

local function models_root()
    model_ffi()
    local buf = ffi.new("char[?]", 1024)
    local n = ffi.C.GetCurrentDirectoryA(1024, buf)
    local cwd = ffi.string(buf, n)
    local root, count = cwd:gsub("[\\/]bin[\\/]win64.*$", "\\csgo")
    if count == 0 then return nil end
    return root
end

local SCAN_DIRS = { "characters", "agents", "models" }

local function scan_into(dir, names, paths)
    local fd = ffi.new("AW_FIND_DATA")
    local h = ffi.C.FindFirstFileA(dir .. "\\*", fd)
    if h == find_invalid() then return end
    repeat
        local nm = ffi.string(fd.cFileName)
        if nm ~= "." and nm ~= ".." then
            local full = dir .. "\\" .. nm
            if band(fd.dwFileAttributes, 0x10) ~= 0 then
                scan_into(full, names, paths)
            elseif nm:sub(-7) == ".vmdl_c" then
                local stem = nm:sub(1, #nm - 7)
                if not stem:lower():match("_arms?$") then
                    local p = full:lower():find("\\csgo\\", 1, true)
                    if p then
                        local rel = full:sub(p + 6):gsub("\\", "/")
                        rel = rel:sub(1, #rel - 2)
                        names[#names + 1] = stem
                        paths[#paths + 1] = rel
                    end
                end
            end
        end
    until ffi.C.FindNextFileA(h, fd) == 0
    ffi.C.FindClose(h)
end

-- ============================================================
-- scan_models with fallback
-- ============================================================
local g_modelNames, g_modelPaths

local function scan_models()
    if g_modelNames then return g_modelNames, g_modelPaths end
    local names, paths = { "[ OFF ]" }, { "" }
    pcall(function()
        local root = models_root()
        if root then
            for _, sub in ipairs(SCAN_DIRS) do scan_into(root .. "\\" .. sub, names, paths) end
        end
    end)
    if #names == 1 then
        local fallback = {
            "models/player/ct_urban.vmdl",
            "models/player/ct_sas.vmdl",
            "models/player/t_leet.vmdl",
            "models/player/t_phoenix.vmdl",
        }
        for _, model in ipairs(fallback) do
            names[#names + 1] = model:match("([^/]+)%.vmdl$") or model
            paths[#paths + 1] = model
        end
        print("[changer] No models found – using fallback vanilla models")
    end
    g_modelNames, g_modelPaths = names, paths
    return names, paths
end

local function rescan_models()
    g_modelNames, g_modelPaths = nil, nil
    return scan_models()
end

local g_IRS = nil
local PRECACHE_SIG = "40 53 55 57 48 81 EC 80 00 00 00 48 8B 01 49 8B E8 48 8B FA"
local function resolve_model_fns()
    if fnptr.precache and g_IRS and fnptr.cbuf_insert then return true end
    model_ffi()
    if not fn.precache then
        local a = mem.FindPattern("resourcesystem.dll", PRECACHE_SIG)
        if a and a ~= 0 then fn.precache = a end
    end
    if fn.precache and not fnptr.precache then
        fnptr.precache = ffi.cast("void*(*)(void*, void*, const char*)", fn.precache)
    end
    if not g_IRS then
        pcall(function()
            local rs = ffi.C.GetModuleHandleA("resourcesystem.dll")
            local ci = rs and ffi.C.GetProcAddress(rs, "CreateInterface")
            if ci then
                local CI = ffi.cast("void*(*)(const char*, int*)", ci)
                local irs = CI("ResourceSystem013", nil)
                if irs ~= nil then g_IRS = irs end
            end
        end)
    end
    if not fnptr.cbuf_insert then
        pcall(function()
            local t0 = ffi.C.GetModuleHandleA("tier0.dll")
            local ins = t0 and ffi.C.GetProcAddress(t0, "?Insert@CBufferString@@QEAAPEBDHPEBDH_N@Z")
            if ins then fnptr.cbuf_insert = ffi.cast("const char*(*)(void*, int, const char*, int, int)", ins) end
        end)
    end
    return fnptr.precache ~= nil and g_IRS ~= nil and fnptr.cbuf_insert ~= nil
end

local function precache_model(path)
    if path == nil or path == "" then return end
    if not resolve_model_fns() then return end
    local cb = ffi.new("AW_CBufStr")
    cb.m_nLength = 0
    cb.m_nAllocatedSize = 0xC0000008
    cb.u.p = nil
    pcall(function() fnptr.cbuf_insert(cb, 0, path, -1, 0) end)
    pcall(function() fnptr.precache(g_IRS, cb, "") end)
end

-- ============================================================
-- apply_local_model
-- ============================================================
local function apply_local_model(pawn, lp)
    if not fnptr.set_model then return end

    if state.origModelPawn ~= pawn then
        state.origModelPawn     = pawn
        state.appliedLocalModel = nil
        state.overrideActive    = false
        state.origModelName     = nil
        if lp then pcall(function()
            local nm = lp:GetModelName()
            if type(nm) == "string" and nm:find("%.vmdl") then state.origModelName = nm end
        end) end
    end
    local path = state.localModel
    if path and path ~= "" then
        if state.appliedLocalModel == path then return end
        precache_model(path)
        pcall(function() fnptr.set_model(ffi.cast("void*", pawn), path) end)
        state.appliedLocalModel = path
        state.overrideActive    = true
    else
        if state.appliedLocalModel == "OFF" then return end
        if state.origModelName then
            precache_model(state.origModelName)
            pcall(function() fnptr.set_model(ffi.cast("void*", pawn), state.origModelName) end)
            state.overrideActive = false
        else
            local default = "models/player/ct_urban.vmdl"
            precache_model(default)
            pcall(function() fnptr.set_model(ffi.cast("void*", pawn), default) end)
            state.overrideActive = false
        end
        state.appliedLocalModel = "OFF"
    end
end

-- ============================================================
-- RUN
-- ============================================================
local function run()
    local lp = get_live_local()
    if not lp or not in_game() then
        if next(state.applied) then state.applied = {} end
        return
    end

    local base = mem.GetModuleBase(DLL); if not base then return end
    local ctrl = r_ptr(base + off.dwLocalPlayerController); if not valid(ctrl) then return end
    local myHandle = r_u32(ctrl + off.m_hPlayerPawn)
    if myHandle == 0 or myHandle == 0xFFFFFFFF then return end

    local elist = r_ptr(base + off.dwEntityList); if not valid(elist) then return end
    local pawn = handle_to_entity(elist, myHandle); if not valid(pawn) then return end
    if not valid(r_ptr(pawn + off.m_pGameSceneNode)) then return end

    if not pawn_alive(pawn) then
        if next(state.applied) then state.applied = {} end
        return
    end

    local applied = state.applied

    apply_local_model(pawn, lp)

    if state.resetGlove then
        reset_gloves(pawn); state.resetGlove = false
    elseif state.gloveDef then
        local c = state.cfg[state.gloveDef]
        if c then apply_gloves(base, pawn, state.gloveDef, c.paint, c.wear, c.seed) end
    end

    local ws   = r_ptr(pawn + off.m_pWeaponServices); if not valid(ws) then return end
    local count= r_i32(ws + off.m_hMyWeapons)
    local arr  = r_ptr(ws + off.m_hMyWeapons + 8)
    if count<=0 or count>64 or not valid(arr) then return end

    local kdef = state.knifeDef
    local kc   = kdef and state.cfg[kdef]

    local did = false
    for i = 0, count - 1 do
        local wpn = handle_to_entity(elist, r_u32(arr + i*4))
        if wpn then
            if r_u32(wpn + off.m_hOwnerEntity) == myHandle then
                do
                    local def = r_u16(item_ptr(wpn) + off.m_iItemDefinitionIndex)
                    if is_knife(def) then
                        if state.resetKnife and not (kdef and kc) then
                            restore_knife(wpn, pawn); applied[wpn] = nil; state.resetKnife = false; did = true
                        elseif kdef and kc then
                            local s = "k|"..kdef.."|"..kc.paint.."|"..kc.wear.."|"..kc.seed.."|"..tostring(kc.stat).."|"..tostring(kc.statval or 0)
                            if applied[wpn] ~= s then
                                process_knife(wpn, kdef, kc.paint, kc.wear, kc.seed, kc.stat, kc.statval); applied[wpn]=s; did=true
                            end
                        end
                    else
                        if state.pendingReset[def] then
                            restore_weapon(wpn); applied[wpn] = nil; state.pendingReset[def] = nil; did = true
                        else
                            local c = state.cfg[def]
                            if c then
                                if c.paint > 0 then
                                    local s = "w|"..c.paint.."|"..c.wear.."|"..c.seed.."|"..tostring(c.stat).."|"..tostring(c.statval or 0)
                                    if applied[wpn] ~= s then
                                        process_weapon(wpn, c.paint, c.wear, c.seed, c.stat, c.statval); applied[wpn]=s; did=true
                                    end
                                else
                                    local s = "w|none"
                                    if applied[wpn] ~= s then
                                        restore_weapon(wpn); applied[wpn]=s; did=true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if did and fnptr.regen_skins then fnptr.regen_skins() end
end

local function active_weapon_def()
    if not get_live_local() then return nil end
    local base = mem.GetModuleBase(DLL); if not base then return nil end
    local ctrl = r_ptr(base + off.dwLocalPlayerController); if not valid(ctrl) then return nil end
    local elist = r_ptr(base + off.dwEntityList)
    local pawn = handle_to_entity(elist, r_u32(ctrl + off.m_hPlayerPawn)); if not valid(pawn) then return nil end
    local ws   = r_ptr(pawn + off.m_pWeaponServices); if not valid(ws) then return nil end
    local wpn  = handle_to_entity(elist, r_u32(ws + off.m_hActiveWeapon)); if not wpn then return nil end
    return r_u16(item_ptr(wpn) + off.m_iItemDefinitionIndex)
end

local CFG_FILE = "awchanger.txt"

local function file_write(path, data)
    local ok = false
    pcall(function()
        local f = file.Open(path, "w")
        if f then f:Write(data); f:Close(); ok = true end
    end)
    return ok
end

local function file_read(path)
    local data
    pcall(function()
        local f = file.Open(path, "r")
        if f then data = f:Read(); f:Close() end
    end)
    return data
end

function Config.serialize()
    local lines = { "AWCFG1",
                    "K " .. tostring(state.knifeDef or 0),
                    "G " .. tostring(state.gloveDef or 0) }
    for def, c in pairs(state.cfg) do
        lines[#lines + 1] = string.format("E %d %d %.6f %d %d %s %d",
            def, c.paint or 0, c.wear or 0.0001, c.seed or 0, c.stat and 1 or 0, c.kind or "weapon", c.statval or 0)
    end
    for k, v in pairs(state.opts) do
        local tv = type(v)
        local tag = (tv == "boolean") and "b" or (tv == "number") and "n" or "s"
        local sv  = (tv == "boolean") and (v and "1" or "0") or tostring(v)
        lines[#lines + 1] = string.format("O %s %s %s", k, tag, sv)
    end
    if state.localModel and state.localModel ~= "" then
        lines[#lines + 1] = "L " .. state.localModel
    end
    return table.concat(lines, "\n")
end

function Config.parse(str)
    if type(str) ~= "string" or not str:find("AWCFG1", 1, true) then return nil end
    local newCfg, kdef, gdef, opts, lmodel = {}, nil, nil, {}, nil
    for line in str:gmatch("[^\r\n]+") do
        local t = line:sub(1, 1)
        if t == "K" then
            local v = tonumber(line:match("^K%s+(%-?%d+)")); if v and v ~= 0 then kdef = v end
        elseif t == "G" then
            local v = tonumber(line:match("^G%s+(%-?%d+)")); if v and v ~= 0 then gdef = v end
        elseif t == "E" then
            local d, p, w, s, st, kind, sv =
                line:match("^E%s+(%-?%d+)%s+(%-?%d+)%s+([%d%.eE%+%-]+)%s+(%-?%d+)%s+(%d)%s+(%a+)%s*(%d*)")
            d, p, w, s = tonumber(d), tonumber(p), tonumber(w), tonumber(s)
            if d then
                newCfg[d] = { paint = p or 0, wear = w or 0.0001, seed = s or 0,
                              stat = (st == "1"), kind = kind or "weapon", statval = tonumber(sv) or 0 }
            end
        elseif t == "O" then
            local k, tag, v = line:match("^O%s+(%S+)%s+(%a)%s+(.*)$")
            if k then
                if     tag == "b" then opts[k] = (v == "1")
                elseif tag == "n" then opts[k] = tonumber(v) or 0
                else                   opts[k] = v end
            end
        elseif t == "L" then
            local v = line:match("^L%s+(.+)$")
            if v and v ~= "" then lmodel = v end
        end
    end
    return newCfg, kdef, gdef, opts, lmodel
end

function Config.applyTable(newCfg, kdef, gdef, opts, lmodel)
    for def, c in pairs(state.cfg) do
        if c.kind == "weapon" and not newCfg[def] then state.pendingReset[def] = true end
    end
    if state.knifeDef and state.knifeDef ~= kdef then state.resetKnife = true end
    if state.gloveDef and state.gloveDef ~= gdef then state.resetGlove = true end
    state.cfg      = newCfg
    state.knifeDef = kdef
    state.gloveDef = gdef
    state.opts     = opts or {}
    state.localModel = lmodel
    state.appliedLocalModel = nil
    state.applied  = {}
end

function Config.save() return file_write(CFG_FILE, Config.serialize()) end

function Config.load()
    local newCfg, kdef, gdef, opts, lmodel = Config.parse(file_read(CFG_FILE))
    if not newCfg then return false end
    Config.applyTable(newCfg, kdef, gdef, opts, lmodel)
    return true
end

local function commit()
    state.applied = {}
    Config.save()
end

local C = {}
C.items     = ITEMS
C.names     = itemNames
C.defToItem = DEF_TO_ITEM
C.offsets   = off

function C.skinList(def) return skin_list_for(def) end
function C.isKnife(def)  return is_knife(def) end
function C.activeDef()   return g_activeDef end
function C.knifeDef()    return state.knifeDef end
function C.getCfg(def)   return state.cfg[def] end

function C.apply(item, paint, wear, seed, stat, statval)
    if not item then return "nothing selected" end
    if item.kind == "glove" and item.def == 0 then
        state.cfg[0]     = nil
        state.gloveDef   = nil
        state.resetGlove = true
        commit()
        return "gloves: default"
    end
    state.cfg[item.def] = { paint = paint, wear = wear, seed = seed, stat = stat, statval = statval, kind = item.kind }
    if     item.kind == "knife" then state.knifeDef = item.def
    elseif item.kind == "glove" then state.gloveDef = item.def end
    commit()
    return string.format("applied: %s (paint %d)", item.name, paint)
end

function C.remove(item)
    if not item then return "nothing selected" end
    state.cfg[item.def] = nil
    if item.kind == "knife" then
        if state.knifeDef == item.def then state.knifeDef = nil end
        state.resetKnife = true
    elseif item.kind == "glove" then
        if state.gloveDef == item.def then state.gloveDef = nil end
        state.resetGlove = true
    else
        state.pendingReset[item.def] = true
    end
    commit()
    return "removed: " .. item.name
end

function C.resetAll()
    for def, c in pairs(state.cfg) do
        if c.kind == "weapon" then state.pendingReset[def] = true end
    end
    state.cfg        = {}
    state.knifeDef   = nil
    state.gloveDef   = nil
    state.resetKnife = true
    state.resetGlove = true
    commit()
    return "reset all"
end

function C.clearConfig()
    C.resetAll()
    pcall(function() file.Delete(CFG_FILE) end)
    return "config cleared"
end

function C.loadConfig() return Config.load() end
function C.getOpt(k)     return state.opts[k] end
function C.setOpt(k, v)  state.opts[k] = v; Config.save() end

function C.modelList()     return scan_models() end
function C.refreshModels() return rescan_models() end
function C.getLocalModel() return state.localModel end
function C.setLocalModel(path)
    if path == nil or path == "" then state.localModel = nil
    else state.localModel = path end
    state.appliedLocalModel = nil
    Config.save()
    return state.localModel
end

callbacks.Register("CreateMove", function()
    local okd, d = pcall(active_weapon_def); g_activeDef = okd and d or nil
    local ok, err = pcall(run)
    if not ok then print("[changer] error: " .. tostring(err)) end
end)

resolve()
pcall(resolve_model_fns)
local n = 0; for _ in pairs(SKINS) do n = n + 1 end
print(string.format("[changer] ready: %d weapons, set_model=%s", n, fn.set_model and "ok" or "NIL"))
local ok_root, root_str = pcall(models_root)
print(string.format("[changer] precache: fn=%s irs=%s cbuf=%s root=%s",
    fnptr.precache and "ok" or "NIL", g_IRS and "ok" or "NIL",
    fnptr.cbuf_insert and "ok" or "NIL", tostring(ok_root and root_str or "ERR")))

return C
