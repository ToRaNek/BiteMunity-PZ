-- BiteMunityCore.lua
-- Fonctions principales du système d'immunité

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
    
    -- Vérifier si ce type de blessure est concerné par l'immunité
    if not BiteMunityConfig.shouldApplyImmunity(woundType, settings.appliesTo) then
        return false
    end
    
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

-- Fonction pour nettoyer une infection existante
function BiteMunityCore.cleanInfection(player)
    if not player then return end
    
    -- Retirer l'état d'infection
    local bodyDamage = player:getBodyDamage()
    if bodyDamage then
        bodyDamage:setInfected(false)
        bodyDamage:setInfectionLevel(0)
        bodyDamage:setInfectionTime(0)
        bodyDamage:setInfectionGrowthRate(0)
        
        -- Nettoyer les blessures infectées
        for i = 0, bodyDamage:getBodyParts():size() - 1 do
            local bodyPart = bodyDamage:getBodyParts():get(i)
            if bodyPart then
                for j = 0, bodyPart:getWounds():size() - 1 do
                    local wound = bodyPart:getWounds():get(j)
                    if wound and wound:isInfected() then
                        wound:setInfected(false)
                    end
                end
            end
        end
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
    elseif damageType == "SCRATCH" or damageType == "Scratch" then  
        woundType = "Scratch"
    elseif damageType == "LACERATION" or damageType == "Laceration" then
        woundType = "Laceration"
    end
    
    if woundType then
        -- Tester l'immunité
        if BiteMunityCore.testImmunity(player, woundType) then
            -- Le joueur est immunisé, nettoyer l'infection
            BiteMunityCore.cleanInfection(player)
            
            -- Afficher le message d'immunité
            BiteMunityCore.showImmunityMessage(player, woundType)
        end
    end
end

-- Event pour quand un joueur prend des dégâts d'un zombie
function BiteMunityCore.onZombieAttack(zombie, player, bodyPart, weapon)
    if not player or not zombie then return end
    
    -- Fonction de vérification avec protection
    local checkFunction = function()
        -- Vérifier que le joueur est toujours valide
        if not player then return end
        
        -- Vérifier les nouvelles blessures infectées
        local bodyDamage = player:getBodyDamage()
        if bodyDamage then
            for i = 0, bodyDamage:getBodyParts():size() - 1 do
                local bp = bodyDamage:getBodyParts():get(i)
                if bp then
                    for j = 0, bp:getWounds():size() - 1 do
                        local wound = bp:getWounds():get(j)
                        if wound and wound:isInfected() then
                            local woundType = "Bite" -- Par défaut, considérer comme morsure
                            
                            -- Tenter de déterminer le type de blessure
                            if wound:getType() then
                                woundType = tostring(wound:getType())
                            end
                            
                            -- Tester l'immunité
                            if BiteMunityCore.testImmunity(player, woundType) then
                                wound:setInfected(false)
                                BiteMunityCore.cleanInfection(player)
                                BiteMunityCore.showImmunityMessage(player, woundType)
                                return -- Sortir après avoir traité une blessure
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Utiliser un délai avec protection contre les erreurs
    local timer = 0.1
    local timerFunction
    timerFunction = function()
        local gameTime = getGameTime()
        if not gameTime then 
            -- Si le temps de jeu n'est pas disponible, essayer à nouveau
            return
        end
        
        timer = timer - gameTime:getMultiplier() / 1000
        if timer <= 0 then
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