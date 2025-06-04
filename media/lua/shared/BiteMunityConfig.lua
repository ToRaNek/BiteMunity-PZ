-- BiteMunityConfig.lua
-- Configuration et constantes pour le mod BiteMunity

BiteMunityConfig = BiteMunityConfig or {}

-- Valeurs par défaut
BiteMunityConfig.DEFAULT_IMMUNITY_CHANCE = 25
BiteMunityConfig.DEFAULT_SHOW_MESSAGE = true
BiteMunityConfig.DEFAULT_PERMANENT_IMMUNITY = false
BiteMunityConfig.DEFAULT_APPLIES_TO = 1 -- 1=Tout, 2=Morsures seulement, 3=Griffures seulement, 4=Lacérations seulement

-- Types de blessures infectieuses
BiteMunityConfig.INFECTIOUS_WOUNDS = {
    "Bite",
    "Scratch", 
    "Laceration"
}

-- Messages d'immunité
BiteMunityConfig.IMMUNITY_MESSAGES = {
    ["Bite"] = "Votre système immunitaire a résisté à l'infection de la morsure !",
    ["Scratch"] = "Votre système immunitaire a résisté à l'infection de la griffure !",
    ["Laceration"] = "Votre système immunitaire a résisté à l'infection de la lacération !"
}

-- Fonction pour obtenir les paramètres sandbox
function BiteMunityConfig.getSandboxSettings()
    local settings = {}
    
    if SandboxVars and SandboxVars.BiteMunity then
        settings.immunityChance = SandboxVars.BiteMunity.ImmunityChance or BiteMunityConfig.DEFAULT_IMMUNITY_CHANCE
        settings.appliesTo = SandboxVars.BiteMunity.ImmunityAppliesTo or BiteMunityConfig.DEFAULT_APPLIES_TO
        settings.showMessage = SandboxVars.BiteMunity.ShowImmunityMessage
        if settings.showMessage == nil then
            settings.showMessage = BiteMunityConfig.DEFAULT_SHOW_MESSAGE
        end
        settings.permanentImmunity = SandboxVars.BiteMunity.PermanentImmunity
        if settings.permanentImmunity == nil then
            settings.permanentImmunity = BiteMunityConfig.DEFAULT_PERMANENT_IMMUNITY
        end
    else
        -- Valeurs par défaut si sandbox vars pas disponible
        settings.immunityChance = BiteMunityConfig.DEFAULT_IMMUNITY_CHANCE
        settings.appliesTo = BiteMunityConfig.DEFAULT_APPLIES_TO
        settings.showMessage = BiteMunityConfig.DEFAULT_SHOW_MESSAGE
        settings.permanentImmunity = BiteMunityConfig.DEFAULT_PERMANENT_IMMUNITY
    end
    
    return settings
end

-- Fonction pour vérifier si un type de blessure est concerné par l'immunité
function BiteMunityConfig.shouldApplyImmunity(woundType, appliesTo)
    if appliesTo == 1 then -- Tout
        return true
    elseif appliesTo == 2 then -- Morsures seulement
        return woundType == "Bite"
    elseif appliesTo == 3 then -- Griffures seulement
        return woundType == "Scratch"
    elseif appliesTo == 4 then -- Lacérations seulement
        return woundType == "Laceration"
    end
    return false
end