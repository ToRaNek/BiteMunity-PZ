-- BiteMunityClient.lua
-- Code côté client pour le mod BiteMunity - Corrigé pour Build 41

require "shared/BiteMunityConfig"
require "shared/BiteMunityCore"

BiteMunityClient = BiteMunityClient or {}

-- Variables locales
local lastInfectionCheck = 0
local CHECK_INTERVAL = 30 -- Vérifier toutes les 30 frames

-- Fonction de vérification périodique des infections
function BiteMunityClient.checkForInfections()

    local player = getPlayer()
    print("[DEBUG] getPlayer() result:", player)
    if not player then
        return
    end

    -- Vérification de sécurité pour getGameTime()
    local gameTime = getGameTime()
    if not gameTime then
        return
    end

    -- Alternative plus sûre pour calculer le temps
    local currentFrame = gameTime:getWorldAgeHours()
    if not currentFrame then
        -- Fallback vers un compteur simple si getWorldAgeHours() échoue
        currentFrame = lastInfectionCheck + 1
    else
        local timeOfDay = gameTime:getTimeOfDay() or 0
        currentFrame = currentFrame * 3600 + timeOfDay
    end

    if currentFrame - lastInfectionCheck < CHECK_INTERVAL then
        return
    end

    lastInfectionCheck = currentFrame
    print("[DEBUG] Updated lastInfectionCheck to:", lastInfectionCheck)

    -- Vérifier si le joueur a une nouvelle infection
    print("[DEBUG] Getting player body damage...")
    local bodyDamage = player:getBodyDamage()
    print("[DEBUG] getBodyDamage() result:", bodyDamage)
    if not bodyDamage then
        print("[DEBUG] No body damage found, exiting function")
        return
    end

    -- Parcourir toutes les parties du corps (Build 41 API)
    local bodyParts = bodyDamage:getBodyParts()
    print("[DEBUG] Body parts object:", bodyParts)
    local bodyPartsCount = bodyParts:size()
    print("[DEBUG] Total body parts count:", bodyPartsCount)

    for i = 0, bodyPartsCount - 1 do
        print("[DEBUG] Processing body part index:", i)
        local bodyPart = bodyParts:get(i)
        print("[DEBUG] Body part object:", bodyPart)

        if bodyPart then
            -- Build 41: Vérifier directement les attributs de blessure
            local hasInfectedBite = bodyPart:bitten() and bodyPart:isInfectedWound()
            local hasInfectedScratch = bodyPart:scratched() and bodyPart:isInfectedWound()
            local hasInfectedCut = bodyPart:isCut() and bodyPart:isInfectedWound()
            
            print("[DEBUG] Body part", i, "- Bitten:", bodyPart:bitten(), "Scratched:", bodyPart:scratched(), "Cut:", bodyPart:isCut())
            print("[DEBUG] Body part", i, "- IsInfectedWound:", bodyPart:isInfectedWound())

            -- Traiter chaque type de blessure infectée
            if hasInfectedBite then
                print("[DEBUG] Found infected bite! Processing immunity check...")
                BiteMunityClient.processInfectedWound(player, bodyPart, "Bite")
            end
            
            if hasInfectedScratch then
                print("[DEBUG] Found infected scratch! Processing immunity check...")
                BiteMunityClient.processInfectedWound(player, bodyPart, "Scratch")
            end
            
            if hasInfectedCut then
                print("[DEBUG] Found infected laceration! Processing immunity check...")
                BiteMunityClient.processInfectedWound(player, bodyPart, "Laceration")
            end
        else
            print("[DEBUG] Body part is nil at index:", i)
        end
    end

    print("[DEBUG] BiteMunityClient.checkForInfections() - Function completed")
end

-- Nouvelle fonction pour traiter une blessure infectée spécifique
function BiteMunityClient.processInfectedWound(player, bodyPart, woundType)
    print("[DEBUG] Processing infected wound type:", woundType)
    
    -- Tester l'immunité
    print("[DEBUG] Testing immunity for wound type:", woundType)
    local hasImmunity = BiteMunityCore.testImmunity(player, woundType)
    print("[DEBUG] BiteMunityCore.testImmunity() result:", hasImmunity)

    if hasImmunity then
        print("[DEBUG] Player has immunity! Cleaning infection...")

        -- Nettoyer l'infection sur cette partie du corps
        print("[DEBUG] Setting body part infection to false...")
        bodyPart:setInfectedWound(false)
        print("[DEBUG] Body part infection cleared")

        -- Si c'est une morsure et qu'on a l'immunité, enlever l'effet "mordu"
        if woundType == "Bite" and bodyPart:bitten() then
            print("[DEBUG] Removing bitten status...")
            bodyPart:setBitten(false, false) -- (bitten, bleeding)
        elseif woundType == "Scratch" and bodyPart:scratched() then
            print("[DEBUG] Removing scratched status...")
            bodyPart:setScratched(false, false)
        elseif woundType == "Laceration" and bodyPart:isCut() then
            print("[DEBUG] Removing cut status...")
            bodyPart:setCut(false, false)
        end

        print("[DEBUG] Calling BiteMunityCore.cleanInfection()...")
        BiteMunityCore.cleanInfection(player)
        print("[DEBUG] BiteMunityCore.cleanInfection() completed")

        print("[DEBUG] Calling BiteMunityCore.showImmunityMessage()...")
        BiteMunityCore.showImmunityMessage(player, woundType)
        print("[DEBUG] BiteMunityCore.showImmunityMessage() completed")

        -- Envoyer au serveur si en multijoueur
        local clientMode = isClient()
        print("[DEBUG] isClient() result:", clientMode)

        if clientMode then
            local playerID = player:getOnlineID()

            local commandData = {
                woundType = woundType,
                playerID = playerID
            }

            sendClientCommand(player, "BiteMunity", "ImmunityTriggered", commandData)
        end
    else
        print("[DEBUG] Player does not have immunity for", woundType)
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
        if args.playerID == player:getOnlineID() then
            BiteMunityCore.setPlayerPermanentImmunity(player, args.immune)
        end
    elseif command == "ShowImmunityMessage" then
        -- Afficher le message d'immunité
        if args.playerID == player:getOnlineID() then
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