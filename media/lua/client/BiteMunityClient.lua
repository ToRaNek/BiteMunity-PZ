-- media/lua/client/BiteMunityClient.lua
-- Code côté client pour le mod BiteMunity - MORSURES UNIQUEMENT - VERSION CORRIGÉE

BiteMunityClient = BiteMunityClient or {}

-- Variables locales
local lastInfectionCheck = 0
local CHECK_INTERVAL = 1800 -- Vérifier toutes les minutes

-- Fonction de vérification périodique des infections de morsure
function BiteMunityClient.checkForBiteInfections()
    local player = getPlayer()
    if not player then
        return
    end

    local gameTime = getGameTime()
    if not gameTime then
        return
    end

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

    -- Vérifier SEULEMENT les morsures infectées
    local bodyParts = bodyDamage:getBodyParts()
    local bodyPartsCount = bodyParts:size()

    for i = 0, bodyPartsCount - 1 do
        local bodyPart = bodyParts:get(i)

        if bodyPart then
            -- Vérifier uniquement les morsures infectées
            local isBitten = bodyPart:bitten()
            local isInfected = bodyPart:isInfectedWound()

            if isBitten and isInfected then
                print("[BiteMunity] Morsure infectée trouvée - test d'immunité")
                BiteMunityClient.processInfectedBite(player, bodyPart)
                return -- Traiter une seule morsure à la fois
            end
        end
    end
end

-- Traiter une morsure infectée spécifique
function BiteMunityClient.processInfectedBite(player, bodyPart)
    -- Tester l'immunité aux morsures
    local hasImmunity = BiteMunityCore.testImmunity(player, "Bite")

    if hasImmunity then
        print("[BiteMunity] Joueur immunisé aux morsures - nettoyage de l'infection")

        -- Nettoyer l'infection sur cette partie du corps
        bodyPart:setInfectedWound(false)

        -- Enlever la morsure si possible
        local success, error = pcall(function()
            bodyPart:SetBitten(false)
        end)
        
        if not success then
            print("[BiteMunity] Erreur lors du nettoyage de la morsure:", error)
            -- Au moins nettoyer l'infection
            bodyPart:setInfectedWound(false)
        end

        BiteMunityCore.cleanInfection(player)
        BiteMunityCore.showImmunityMessage(player, "Bite")

        -- Envoyer au serveur si en multijoueur
        if isClient() then
            local playerID = player:getOnlineID()
            local commandData = {
                woundType = "Bite",
                playerID = playerID
            }
            sendClientCommand(player, "BiteMunity", "ImmunityTriggered", commandData)
        end
    end
end

-- Event handlers côté client
function BiteMunityClient.onPlayerGetDamage(player, damageType, damage)
    if player ~= getPlayer() then 
        return 
    end
    
    -- Ne traiter QUE les morsures
    if damageType ~= "BITE" and damageType ~= "Bite" then
        return
    end
    
    BiteMunityCore.onPlayerGetDamage(player, damageType, damage)
end

function BiteMunityClient.onTick()
    local player = getPlayer()
    local gameTime = getGameTime()
    
    -- S'assurer que le jeu est correctement initialisé
    if player and gameTime then
        BiteMunityClient.checkForBiteInfections()
    end
end

function BiteMunityClient.onCreatePlayer(playerIndex, player)
    if player == getPlayer() then
        BiteMunityCore.onPlayerCreate(playerIndex, player)
    end
end

-- Fonction pour gérer les commandes du serveur
function BiteMunityClient.onServerCommand(module, command, args)
    if module ~= "BiteMunity" then 
        return 
    end
    
    local player = getPlayer()
    if not player then 
        return 
    end
    
    if command == "SyncImmunity" then
        -- Synchroniser l'état d'immunité permanente
        if args and args.playerID == player:getOnlineID() then
            BiteMunityCore.setPlayerPermanentImmunity(player, args.immune)
        end
    elseif command == "ShowImmunityMessage" then
        -- Afficher le message d'immunité
        if args and args.playerID == player:getOnlineID() then
            BiteMunityCore.showImmunityMessage(player, "Bite")
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
    
    print("[BiteMunity] Client initialized - Protection contre les morsures de zombies uniquement")
end

-- Initialiser le client
Events.OnGameStart.Add(BiteMunityClient.init)