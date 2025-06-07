-- media/lua/shared/BiteMunityConfig.lua
-- Configuration pour le mod BiteMunity - MORSURES UNIQUEMENT

BiteMunityConfig = BiteMunityConfig or {}

-- Valeurs par défaut
BiteMunityConfig.DEFAULT_IMMUNITY_CHANCE = 25
BiteMunityConfig.DEFAULT_SHOW_MESSAGE = true
BiteMunityConfig.DEFAULT_PERMANENT_IMMUNITY = true
BiteMunityConfig.DEFAULT_NATURAL_IMMUNITY_CHANCE = 5 -- Chance d'être naturellement immunisé à la création

-- Types de blessures infectieuses - SEULEMENT LES MORSURES
BiteMunityConfig.INFECTIOUS_WOUNDS = {
    "Bite",
}

-- Messages d'immunité
BiteMunityConfig.IMMUNITY_MESSAGES = {
    ["Bite"] = "Votre systeme immunitaire a resiste a l'infection de la morsure !",
    ["Natural"] = "Vous etes naturellement immunise contre les morsures de zombies !",
}

-- Fonction pour obtenir les paramètres sandbox
function BiteMunityConfig.getSandboxSettings()
    local settings = {}
    
    if SandboxVars and SandboxVars.BiteMunity then
        settings.immunityChance = SandboxVars.BiteMunity.ImmunityChance or BiteMunityConfig.DEFAULT_IMMUNITY_CHANCE
        settings.showMessage = SandboxVars.BiteMunity.ShowImmunityMessage
        if settings.showMessage == nil then
            settings.showMessage = BiteMunityConfig.DEFAULT_SHOW_MESSAGE
        end
        settings.permanentImmunity = SandboxVars.BiteMunity.PermanentImmunity
        if settings.permanentImmunity == nil then
            settings.permanentImmunity = BiteMunityConfig.DEFAULT_PERMANENT_IMMUNITY
        end
        settings.naturalImmunityChance = SandboxVars.BiteMunity.NaturalImmunityChance or BiteMunityConfig.DEFAULT_NATURAL_IMMUNITY_CHANCE
    else
        -- Valeurs par défaut si sandbox vars pas disponible
        settings.immunityChance = BiteMunityConfig.DEFAULT_IMMUNITY_CHANCE
        settings.showMessage = BiteMunityConfig.DEFAULT_SHOW_MESSAGE
        settings.permanentImmunity = BiteMunityConfig.DEFAULT_PERMANENT_IMMUNITY
        settings.naturalImmunityChance = BiteMunityConfig.DEFAULT_NATURAL_IMMUNITY_CHANCE
    end
    return settings
end