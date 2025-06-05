-- BiteMunityConfig.lua
-- Configuration et constantes pour le mod BiteMunity

BiteMunityConfig = BiteMunityConfig or {}

-- Valeurs par défaut
BiteMunityConfig.DEFAULT_IMMUNITY_CHANCE = 25
BiteMunityConfig.DEFAULT_SHOW_MESSAGE = true
BiteMunityConfig.DEFAULT_PERMANENT_IMMUNITY = false

-- Types de blessures infectieuses
BiteMunityConfig.INFECTIOUS_WOUNDS = {
    "Bite",
}

-- Messages d'immunité (sans accents pour éviter les problèmes d'encodage)
BiteMunityConfig.IMMUNITY_MESSAGES = {
    ["Bite"] = "Votre systeme immunitaire a resiste a l'infection de la morsure !",
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
    else
        -- Valeurs par défaut si sandbox vars pas disponible
        settings.immunityChance = BiteMunityConfig.DEFAULT_IMMUNITY_CHANCE
        settings.showMessage = BiteMunityConfig.DEFAULT_SHOW_MESSAGE
        settings.permanentImmunity = BiteMunityConfig.DEFAULT_PERMANENT_IMMUNITY
    end
    return settings
end