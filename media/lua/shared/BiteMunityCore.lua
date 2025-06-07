-- media/lua/shared/BiteMunityCore.lua
-- Système d'immunité aux MORSURES DE ZOMBIES uniquement

BiteMunityCore = BiteMunityCore or {}

-- Table pour stocker les joueurs immunisés de façon permanente
BiteMunityCore.immunePlayers = {}

-- Table pour stocker les joueurs naturellement immunisés (dès la création)
BiteMunityCore.naturallyImmunePlayers = {}

-- Fonction principale : vérifier si un joueur est immunisé aux morsures de zombies
function BiteMunityCore.isPlayerPermanentlyImmune(player)
    if not player then return false end
    local playerID = tostring(player:getOnlineID())
    
    -- Vérifier l'immunité permanente (acquise après survie à une morsure)
    if BiteMunityCore.immunePlayers[playerID] == true then
        return true
    end
    
    -- Vérifier l'immunité naturelle (dès la création du personnage)
    if BiteMunityCore.naturallyImmunePlayers[playerID] == true then
        return true
    end
    
    return false
end

-- Marquer un joueur comme immunisé de façon permanente (après survie à une morsure)
function BiteMunityCore.setPlayerPermanentImmunity(player, immune)
    if not player then return end
    local playerID = tostring(player:getOnlineID())
    BiteMunityCore.immunePlayers[playerID] = immune
    
    -- Sauvegarder
    if isServer() then
        player:getModData().BiteMunityImmune = immune
    end
    
    print("[BiteMunity] Joueur " .. playerID .. " immunité permanente: " .. tostring(immune))
end

-- Marquer un joueur comme naturellement immunisé (à la création)
function BiteMunityCore.setPlayerNaturalImmunity(player, immune)
    if not player then return end
    local playerID = tostring(player:getOnlineID())
    BiteMunityCore.naturallyImmunePlayers[playerID] = immune
    
    -- Sauvegarder
    if isServer() then
        player:getModData().BiteMunityNaturallyImmune = immune
    end
    
    print("[BiteMunity] Joueur " .. playerID .. " immunité naturelle: " .. tostring(immune))
end

-- Tester l'immunité naturelle à la création du joueur
function BiteMunityCore.rollNaturalImmunity(player)
    if not player then return false end
    
    local settings = BiteMunityConfig.getSandboxSettings()
    if settings.naturalImmunityChance <= 0 then
        return false
    end
    
    local roll = ZombRand(100) + 1 -- 1-100
    local isNaturallyImmune = roll <= settings.naturalImmunityChance
    
    if isNaturallyImmune then
        BiteMunityCore.setPlayerNaturalImmunity(player, true)
        if settings.showMessage then
            BiteMunityCore.showImmunityMessage(player, "Natural")
        end
        print("[BiteMunity] Joueur " .. tostring(player:getOnlineID()) .. " est naturellement immunisé aux morsures !")
    end
    
    return isNaturallyImmune
end

-- Forcer l'immunité manuellement (pour debug/vaccination)
function BiteMunityCore.forceImmunity(player, immunityType)
    if not player then return false end
    
    immunityType = immunityType or "natural"
    
    if immunityType == "natural" then
        BiteMunityCore.setPlayerNaturalImmunity(player, true)
    else
        BiteMunityCore.setPlayerPermanentImmunity(player, true)
    end
    
    local settings = BiteMunityConfig.getSandboxSettings()
    if settings.showMessage then
        BiteMunityCore.showImmunityMessage(player, "Natural")
    end
    
    return true
end

-- Charger l'immunité depuis les données sauvegardées
function BiteMunityCore.loadPlayerImmunity(player)
    if not player then return end
    local playerID = tostring(player:getOnlineID())
    local modData = player:getModData()
    
    -- Charger l'immunité permanente
    if modData.BiteMunityImmune then
        BiteMunityCore.immunePlayers[playerID] = modData.BiteMunityImmune
        print("[BiteMunity] Immunité permanente chargée pour " .. playerID)
    end
    
    -- Charger l'immunité naturelle
    if modData.BiteMunityNaturallyImmune then
        BiteMunityCore.naturallyImmunePlayers[playerID] = modData.BiteMunityNaturallyImmune
        print("[BiteMunity] Immunité naturelle chargée pour " .. playerID)
    end
end

-- Tester l'immunité lors d'une nouvelle morsure
function BiteMunityCore.testImmunity(player, woundType)
    if not player then return false end
    
    -- Ne traiter QUE les morsures
    if woundType ~= "Bite" then
        return false
    end
    
    local settings = BiteMunityConfig.getSandboxSettings()
    
    -- Si le joueur est déjà immunisé, il reste immunisé
    if BiteMunityCore.isPlayerPermanentlyImmune(player) then
        return true
    end
    
    -- Test de chance d'immunité pour nouvelle morsure
    local roll = ZombRand(100) + 1 -- 1-100
    local isImmune = roll <= settings.immunityChance
    
    -- Si immunisé et immunité permanente activée, marquer le joueur
    if isImmune and settings.permanentImmunity then
        BiteMunityCore.setPlayerPermanentImmunity(player, true)
    end
    
    return isImmune
end

-- Nettoyer l'infection de morsure
function BiteMunityCore.cleanInfection(player)
    if not player then return end
    
    local bodyDamage = player:getBodyDamage()
    if bodyDamage then
        bodyDamage:setInfected(false)
        bodyDamage:setInfectionLevel(0)
        bodyDamage:setInfectionTime(0)
        bodyDamage:setInfectionGrowthRate(0)
        
        -- Nettoyer les infections sur chaque partie du corps
        local bodyParts = bodyDamage:getBodyParts()
        for i = 0, bodyParts:size() - 1 do
            local bodyPart = bodyParts:get(i)
            if bodyPart and bodyPart:isInfectedWound() then
                bodyPart:setInfectedWound(false)
            end
        end
    end
end

-- Nettoyer complètement une morsure (infection + blessure)
function BiteMunityCore.cleanBiteWound(bodyPart)
    if not bodyPart then return end
    
    -- Nettoyer l'infection
    bodyPart:setInfectedWound(false)
    
    -- Enlever la morsure si elle existe
    if bodyPart:bitten() then
        local success, error = pcall(function()
            bodyPart:setBitten(false, false) -- (bitten, bleeding)
        end)
        
        if not success then
            print("[BiteMunity] Erreur lors du nettoyage de la morsure: " .. tostring(error))
        end
    end
end

-- Afficher le message d'immunité
function BiteMunityCore.showImmunityMessage(player, woundType)
    if not player then return end
    
    local settings = BiteMunityConfig.getSandboxSettings()
    if not settings.showMessage then return end
    
    local message = BiteMunityConfig.IMMUNITY_MESSAGES[woundType] or "Votre système immunitaire a résisté à la morsure de zombie !"
    
    if isClient() or not isServer() then
        player:Say(message)
        if addLineInChat then
            addLineInChat(message, 0, 1, 0) -- Vert
        end
    end
end

-- Vérification périodique des infections de morsure
function BiteMunityCore.checkForBiteInfections(player)
    if not player then return end
    
    -- Si le joueur est immunisé, nettoyer automatiquement toute infection de morsure
    if BiteMunityCore.isPlayerPermanentlyImmune(player) then
        local bodyDamage = player:getBodyDamage()
        if bodyDamage then
            local bodyParts = bodyDamage:getBodyParts()
            for i = 0, bodyParts:size() - 1 do
                local bodyPart = bodyParts:get(i)
                if bodyPart and bodyPart:bitten() and bodyPart:isInfectedWound() then
                    -- Joueur immunisé mais infecté par morsure = nettoyer
                    BiteMunityCore.cleanBiteWound(bodyPart)
                    BiteMunityCore.cleanInfection(player)
                    BiteMunityCore.showImmunityMessage(player, "Bite")
                    print("[BiteMunity] Infection de morsure nettoyée pour joueur immunisé")
                    return -- Une seule morsure à la fois
                end
            end
        end
    end
end

-- Event handlers simplifiés
function BiteMunityCore.onPlayerGetDamage(player, damageType, damage)
    if not player or not damageType then return end
    
    -- Ne traiter QUE les morsures
    if damageType ~= "BITE" and damageType ~= "Bite" then
        return
    end
    
    -- Tester l'immunité
    if BiteMunityCore.testImmunity(player, "Bite") then
        -- Le joueur est immunisé, programmer la vérification après un délai
        BiteMunityCore.scheduleImmunityCheck(player)
    end
end

-- Programmer une vérification d'immunité avec délai
function BiteMunityCore.scheduleImmunityCheck(player)
    local checkFunction = function()
        if not player then return end
        
        local bodyDamage = player:getBodyDamage()
        if not bodyDamage then return end
        
        local bodyParts = bodyDamage:getBodyParts()
        for i = 0, bodyParts:size() - 1 do
            local bodyPart = bodyParts:get(i)
            if bodyPart and bodyPart:bitten() then
                -- Nettoyer la morsure
                BiteMunityCore.cleanBiteWound(bodyPart)
                BiteMunityCore.cleanInfection(player)
                BiteMunityCore.showImmunityMessage(player, "Bite")
                return -- Traiter une morsure à la fois
            end
        end
    end
    
    -- Programmer avec un petit délai
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

-- Vérification périodique des infections de morsure (utilisée par le serveur)
function BiteMunityCore.checkForBiteInfections(player)
    if not player then return end
    
    -- Si le joueur est immunisé, nettoyer automatiquement toute infection de morsure
    if BiteMunityCore.isPlayerPermanentlyImmune(player) then
        local bodyDamage = player:getBodyDamage()
        if bodyDamage then
            local bodyParts = bodyDamage:getBodyParts()
            for i = 0, bodyParts:size() - 1 do
                local bodyPart = bodyParts:get(i)
                if bodyPart and bodyPart:bitten() and bodyPart:isInfectedWound() then
                    -- Joueur immunisé mais infecté par morsure = nettoyer
                    BiteMunityCore.cleanBiteWound(bodyPart)
                    BiteMunityCore.cleanInfection(player)
                    BiteMunityCore.showImmunityMessage(player, "Bite")
                    print("[BiteMunity] Infection de morsure nettoyée pour joueur immunisé")
                    return -- Une seule morsure à la fois
                end
            end
        end
    end
end

function BiteMunityCore.onPlayerCreate(playerIndex, player)
    -- Charger l'immunité existante
    BiteMunityCore.loadPlayerImmunity(player)
    
    -- Tester l'immunité naturelle si pas déjà immunisé
    if not BiteMunityCore.isPlayerPermanentlyImmune(player) then
        BiteMunityCore.rollNaturalImmunity(player)
    end
end