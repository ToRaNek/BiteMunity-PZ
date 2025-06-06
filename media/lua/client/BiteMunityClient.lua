-- BiteMunityClient.lua
-- Code côté client pour le mod BiteMunity - Corrigé pour Build 41

-- Import des modules partagés (sans require car ils sont chargés directement)
-- BiteMunityConfig et BiteMunityCore sont chargés automatiquement

BiteMunityClient = BiteMunityClient or {}

-- Variables locales
local lastInfectionCheck = 0
local CHECK_INTERVAL = 1800 -- Vérifier toutes les minutes

-- Fonction de vérification périodique des infections
function BiteMunityClient.checkForInfections()
    local player = getPlayer()
    if not player then
        return
    end

    local gameTime = getGameTime()
    if not gameTime then
        return
    end

    -- Alternative plus sûre pour calculer le temps
    local currentFrame = gameTime:getWorldAgeHours()
    if not currentFrame then
        currentFrame = lastInfectionCheck + 1
    else
        local timeOfDay = gameTime:getTimeOfDay() or 0
        currentFrame = currentFrame * 3600 + timeOfDay
    end

    if currentFrame - lastInfectionCheck < CHECK_INTERVAL then
        return
    end

    lastInfectionCheck = currentFrame

    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then
        return
    end

    -- Parcourir toutes les parties du corps (Build 41 API)
    local bodyParts = bodyDamage:getBodyParts()
    local bodyPartsCount = bodyParts:size()

    for i = 0, bodyPartsCount - 1 do
        local bodyPart = bodyParts:get(i)

        if bodyPart then
            -- Build 41: Vérifier directement les attributs de blessure
            local isBitten = bodyPart:bitten()
            local isInfected = bodyPart:isInfectedWound()

            -- Traiter chaque type de blessure infectée
            if isBitten and isInfected then
                print("[BiteMunity] Found infected bite - testing immunity")
                BiteMunityClient.processInfectedWound(player, bodyPart, "Bite")
            end
        end
    end
end

-- Nouvelle fonction pour traiter une blessure infectée spécifique - CORRIGÉE
function BiteMunityClient.processInfectedWound(player, bodyPart, woundType)
    -- Tester l'immunité
    local hasImmunity = BiteMunityCore.testImmunity(player, woundType)

    if hasImmunity then
        print("[BiteMunity] Player has immunity for " .. woundType .. " - cleaning infection")

        -- Nettoyer l'infection sur cette partie du corps
        bodyPart:setInfectedWound(false)

        -- Correction: Utiliser les bonnes méthodes pour enlever les blessures
        if woundType == "Bite" and bodyPart:bitten() then
            -- Utiliser la fonction sécurisée
            local success, error = pcall(function()
                bodyPart:setBitten(false, false)
            end)
            
            if not success then
                print("[BiteMunity] Error cleaning bite wound:", error)
            end
        end

        BiteMunityCore.cleanInfection(player)
        BiteMunityCore.showImmunityMessage(player, woundType)

        -- Envoyer au serveur si en multijoueur
        if isClient() then
            local playerID = player:getOnlineID()
            local commandData = {
                woundType = woundType,
                playerID = playerID
            }
            sendClientCommand(player, "BiteMunity", "ImmunityTriggered", commandData)
        end
    end
end

-- Version alternative avec une approche plus sûre pour Build 41
function BiteMunityClient.processInfectedWoundSafe(player, bodyPart, woundType)
    local hasImmunity = BiteMunityCore.testImmunity(player, woundType)

    if hasImmunity then
        -- Approche plus sûre: utiliser pcall pour éviter les crashs
        local success, error = pcall(function()
            bodyPart:setInfectedWound(false)
            
            -- Nettoyer les blessures en fonction du type
            if woundType == "Bite" then
                if bodyPart.setBitten then
                    bodyPart:setBitten(false, false)
                end
            end
        end)
        
        if not success then
            print("[BiteMunity] Error cleaning wound:", error)
            -- Fallback: au moins nettoyer l'infection
            if bodyPart.setInfectedWound then
                bodyPart:setInfectedWound(false)
            end
        else
            print("[BiteMunity] Successfully cleaned " .. woundType .. " infection")
        end

        BiteMunityCore.cleanInfection(player)
        BiteMunityCore.showImmunityMessage(player, woundType)

        -- Envoyer au serveur si en multijoueur
        if isClient() then
            local playerID = player:getOnlineID()
            local commandData = {
                woundType = woundType,
                playerID = playerID
            }
            sendClientCommand(player, "BiteMunity", "ImmunityTriggered", commandData)
        end
    end
end

-- Event handlers côté client
function BiteMunityClient.onPlayerGetDamage(player, damageType, damage)
    if player ~= getPlayer() then return end
    BiteMunityCore.onPlayerGetDamage(player, damageType, damage)
end

function BiteMunityClient.onTick()
    -- Vérification de sécurité avant d'appeler checkForInfections
    local player = getPlayer()
    local gameTime = getGameTime()
    
    -- S'assurer que le jeu est correctement initialisé
    if player and gameTime then
        BiteMunityClient.checkForInfections()
    end
end

function BiteMunityClient.onCreatePlayer(playerIndex, player)
    if player == getPlayer() then
        BiteMunityCore.onPlayerCreate(playerIndex, player)
    end
end

-- Fonction pour gérer les commandes du serveur
function BiteMunityClient.onServerCommand(module, command, args)
    if module ~= "BiteMunity" then return end
    
    local player = getPlayer()
    if not player then return end
    
    if command == "SyncImmunity" then
        -- Synchroniser l'état d'immunité permanente
        if args and args.playerID == player:getOnlineID() then
            BiteMunityCore.setPlayerPermanentImmunity(player, args.immune)
        end
    elseif command == "ShowImmunityMessage" then
        -- Afficher le message d'immunité
        if args and args.playerID == player:getOnlineID() then
            BiteMunityCore.showImmunityMessage(player, args.woundType)
        end
    end
end

-- Fonction d'initialisation côté client
function BiteMunityClient.init()
    -- Enregistrer les événements
    Events.OnPlayerGetDamage.Add(BiteMunityClient.onPlayerGetDamage)
    Events.OnTick.Add(BiteMunityClient.onTick)
    Events.OnCreatePlayer.Add(BiteMunityClient.onCreatePlayer)
    Events.OnServerCommand.Add(BiteMunityClient.onServerCommand)
    
    print("[BiteMunity] Client initialized")
end

-- Initialiser le client
Events.OnGameStart.Add(BiteMunityClient.init)