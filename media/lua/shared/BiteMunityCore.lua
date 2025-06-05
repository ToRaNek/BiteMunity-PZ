-- BiteMunityCore.lua
-- Fonctions principales du système d'immunité - Corrigé pour Build 41

BiteMunityCore = BiteMunityCore or {}

-- Table pour stocker les joueurs immunisés de façon permanente
BiteMunityCore.immunePlayers = {}

-- Fonction pour vérifier si un joueur est immunisé de façon permanente
function BiteMunityCore.isPlayerPermanentlyImmune(player)
    if not player then return false end
    local playerID = tostring(player:getOnlineID())
    return BiteMunityCore.immunePlayers[playerID] == true
end

-- Fonction pour marquer un joueur comme immunisé de façon permanente
function BiteMunityCore.setPlayerPermanentImmunity(player, immune)
    if not player then return end
    local playerID = tostring(player:getOnlineID())
    BiteMunityCore.immunePlayers[playerID] = immune
    
    -- Sauvegarder les données du joueur
    if isServer() then
        player:getModData().BiteMunityImmune = immune
    end
end

-- Fonction pour charger l'immunité permanente depuis les données du joueur
function BiteMunityCore.loadPlayerImmunity(player)
    if not player then return end
    local playerID = tostring(player:getOnlineID())
    local modData = player:getModData()
    
    if modData.BiteMunityImmune then
        BiteMunityCore.immunePlayers[playerID] = modData.BiteMunityImmune
    end
end

-- Fonction principale pour tester l'immunité
function BiteMunityCore.testImmunity(player, woundType)
    if not player then return false end
    
    local settings = BiteMunityConfig.getSandboxSettings()
    
    -- Si le joueur est déjà immunisé de façon permanente
    if settings.permanentImmunity and BiteMunityCore.isPlayerPermanentlyImmune(player) then
        return true
    end
    
    -- Test de chance d'immunité
    local roll = ZombRand(100) + 1 -- 1-100
    local isImmune = roll <= settings.immunityChance
    
    -- Si immunisé et immunité permanente activée, marquer le joueur
    if isImmune and settings.permanentImmunity then
        BiteMunityCore.setPlayerPermanentImmunity(player, true)
    end
    
    return isImmune
end

-- Fonction pour nettoyer une infection existante (Build 41)
function BiteMunityCore.cleanInfection(player)
    if not player then return end
    
    -- Retirer l'état d'infection global
    local bodyDamage = player:getBodyDamage()
    if bodyDamage then
        bodyDamage:setInfected(false)
        bodyDamage:setInfectionLevel(0)
        bodyDamage:setInfectionTime(0)
        bodyDamage:setInfectionGrowthRate(0)
        
        -- Build 41: Nettoyer les infections sur chaque partie du corps
        local bodyParts = bodyDamage:getBodyParts()
        for i = 0, bodyParts:size() - 1 do
            local bodyPart = bodyParts:get(i)
            if bodyPart and bodyPart:isInfectedWound() then
                bodyPart:setInfectedWound(false)
            end
        end
    end
end

-- Fonction pour nettoyer complètement une blessure (infection + blessure)
function BiteMunityCore.cleanWoundCompletely(bodyPart, woundType)
    if not bodyPart then return end
    
    -- Nettoyer l'infection
    bodyPart:setInfectedWound(false)
    
    -- Enlever la blessure elle-même selon le type
    if woundType == "Bite" and bodyPart:bitten() then
        bodyPart:setBitten(false, false) -- (bitten, bleeding)
    end
end

-- Fonction pour afficher le message d'immunité
function BiteMunityCore.showImmunityMessage(player, woundType)
    if not player then return end
    
    local settings = BiteMunityConfig.getSandboxSettings()
    if not settings.showMessage then return end
    
    local message = BiteMunityConfig.IMMUNITY_MESSAGES[woundType] or "Votre système immunitaire a résisté à l'infection !"
    
    if isClient() or not isServer() then
        player:Say(message)
        -- Ajouter aussi dans le chat système si possible
        if addLineInChat then
            addLineInChat(message, 0, 1, 0) -- Vert
        end
    end
end

-- Event handlers
function BiteMunityCore.onPlayerGetDamage(player, damageType, damage)
    if not player or not damageType then return end
    
    -- Vérifier si c'est un dégât de zombie (morsure, griffure, lacération)
    local woundType = nil
    
    if damageType == "BITE" or damageType == "Bite" then
        woundType = "Bite"
    end
    
    if woundType then
        -- Tester l'immunité
        if BiteMunityCore.testImmunity(player, woundType) then
            -- Le joueur est immunisé, programme la vérification après un délai
            BiteMunityCore.scheduleImmunityCheck(player, woundType)
        end
    end
end

-- Nouvelle fonction pour programmer une vérification d'immunité avec délai
function BiteMunityCore.scheduleImmunityCheck(player, woundType)
    local checkFunction = function()
        if not player then return end
        
        local bodyDamage = player:getBodyDamage()
        if not bodyDamage then return end
        
        local bodyParts = bodyDamage:getBodyParts()
        for i = 0, bodyParts:size() - 1 do
            local bodyPart = bodyParts:get(i)
            if bodyPart then
                local shouldClean = false
                
                -- Vérifier selon le type de blessure
                if woundType == "Bite" and bodyPart:bitten() then
                    shouldClean = true
                end
                
                if shouldClean then
                    -- Nettoyer complètement la blessure
                    BiteMunityCore.cleanWoundCompletely(bodyPart, woundType)
                    BiteMunityCore.cleanInfection(player)
                    BiteMunityCore.showImmunityMessage(player, woundType)
                    return -- Traiter une blessure à la fois
                end
            end
        end
    end
    
    -- Programmer l'exécution avec un petit délai
    local delayFrames = 5
    local frameCount = 0
    local timerFunction
    timerFunction = function()
        frameCount = frameCount + 1
        if frameCount >= delayFrames then
            checkFunction()
            Events.OnTick.Remove(timerFunction)
        end
    end
    
    Events.OnTick.Add(timerFunction)
end

-- Event pour quand un joueur prend des dégâts d'un zombie (Build 41)
function BiteMunityCore.onZombieAttack(zombie, player, bodyPart, weapon)
    if not player or not zombie then return end
    
    -- Fonction de vérification avec protection pour Build 41
    local checkFunction = function()
        if not player then return end
        
        local bodyDamage = player:getBodyDamage()
        if not bodyDamage then return end
        
        local bodyParts = bodyDamage:getBodyParts()
        for i = 0, bodyParts:size() - 1 do
            local bp = bodyParts:get(i)
            if bp then
                -- Vérifier chaque type de blessure infectée
                if bp:bitten() and bp:isInfectedWound() then
                    if BiteMunityCore.testImmunity(player, "Bite") then
                        BiteMunityCore.cleanWoundCompletely(bp, "Bite")
                        BiteMunityCore.cleanInfection(player)
                        BiteMunityCore.showImmunityMessage(player, "Bite")
                        return
                    end
                end
            end
        end
    end
    
    -- Programmer avec un délai sécurisé
    local delayFrames = 10
    local frameCount = 0
    local timerFunction
    timerFunction = function()
        frameCount = frameCount + 1
        if frameCount >= delayFrames then
            checkFunction()
            Events.OnTick.Remove(timerFunction)
        end
    end
    
    Events.OnTick.Add(timerFunction)
end

function BiteMunityCore.onPlayerCreate(playerIndex, player)
    -- Charger l'immunité permanente du joueur
    BiteMunityCore.loadPlayerImmunity(player)
end