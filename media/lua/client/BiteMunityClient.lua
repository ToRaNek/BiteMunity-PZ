-- BiteMunityClient.lua
-- Code côté client pour le mod BiteMunity

require "shared/BiteMunityConfig"
require "shared/BiteMunityCore"

BiteMunityClient = BiteMunityClient or {}

-- Variables locales
local lastInfectionCheck = 0
local CHECK_INTERVAL = 30 -- Vérifier toutes les 30 frames

-- Fonction de vérification périodique des infections
function BiteMunityClient.checkForInfections()
    print("[DEBUG] BiteMunityClient.checkForInfections() - Function started")

    local player = getPlayer()
    print("[DEBUG] getPlayer() result:", player)
    if not player then
        print("[DEBUG] No player found, exiting function")
        return
    end

    -- Vérification de sécurité pour getGameTime()
    print("[DEBUG] Attempting to get game time...")
    local gameTime = getGameTime()
    print("[DEBUG] getGameTime() result:", gameTime)
    if not gameTime then
        print("[DEBUG] No game time found, exiting function")
        return
    end

    -- Alternative plus sûre pour calculer le temps
    print("[DEBUG] Calculating current frame...")
    local currentFrame = gameTime:getWorldAgeHours()
    print("[DEBUG] getWorldAgeHours() result:", currentFrame)
    if not currentFrame then
        print("[DEBUG] getWorldAgeHours() failed, using fallback calculation")
        -- Fallback vers un compteur simple si getWorldAgeHours() échoue
        currentFrame = lastInfectionCheck + 1
        print("[DEBUG] Fallback currentFrame:", currentFrame)
    else
        local timeOfDay = gameTime:getTimeOfDay() or 0
        print("[DEBUG] getTimeOfDay() result:", timeOfDay)
        currentFrame = currentFrame * 3600 + timeOfDay
        print("[DEBUG] Calculated currentFrame:", currentFrame)
    end

    print("[DEBUG] lastInfectionCheck:", lastInfectionCheck)
    print("[DEBUG] CHECK_INTERVAL:", CHECK_INTERVAL)
    print("[DEBUG] Time difference:", currentFrame - lastInfectionCheck)

    if currentFrame - lastInfectionCheck < CHECK_INTERVAL then
        print("[DEBUG] Not enough time passed since last check, exiting")
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

    -- Parcourir toutes les parties du corps
    local bodyParts = bodyDamage:getBodyParts()
    print("[DEBUG] Body parts object:", bodyParts)
    local bodyPartsCount = bodyParts:size()
    print("[DEBUG] Total body parts count:", bodyPartsCount)

    for i = 0, bodyPartsCount - 1 do
        print("[DEBUG] Processing body part index:", i)
        local bodyPart = bodyParts:get(i)
        print("[DEBUG] Body part object:", bodyPart)

        if bodyPart then
            local wounds = bodyPart:getWounds()
            print("[DEBUG] Wounds object for body part", i, ":", wounds)
            local woundsCount = wounds:size()
            print("[DEBUG] Wounds count for body part", i, ":", woundsCount)

            -- Parcourir toutes les blessures
            for j = 0, woundsCount - 1 do
                print("[DEBUG] Processing wound index:", j, "for body part:", i)
                local wound = wounds:get(j)
                print("[DEBUG] Wound object:", wound)

                if wound then
                    local isInfected = wound:isInfected()
                    print("[DEBUG] Wound", j, "isInfected():", isInfected)

                    if isInfected then
                        print("[DEBUG] Found infected wound! Processing immunity check...")

                        -- Déterminer le type de blessure
                        local woundType = "Bite" -- Par défaut
                        print("[DEBUG] Default wound type set to:", woundType)

                        local woundTypeObject = wound:getType()
                        print("[DEBUG] wound:getType() result:", woundTypeObject)

                        if woundTypeObject then
                            local type = tostring(woundTypeObject)
                            print("[DEBUG] Wound type string:", type)

                            if type:find("Scratch") then
                                woundType = "Scratch"
                                print("[DEBUG] Detected Scratch wound")
                            elseif type:find("Laceration") then
                                woundType = "Laceration"
                                print("[DEBUG] Detected Laceration wound")
                            elseif type:find("Bite") then
                                woundType = "Bite"
                                print("[DEBUG] Detected Bite wound")
                            end
                        else
                            print("[DEBUG] No wound type found, using default:", woundType)
                        end

                        -- Tester l'immunité
                        print("[DEBUG] Testing immunity for wound type:", woundType)
                        local hasImmunity = BiteMunityCore.testImmunity(player, woundType)
                        print("[DEBUG] BiteMunityCore.testImmunity() result:", hasImmunity)

                        if hasImmunity then
                            print("[DEBUG] Player has immunity! Cleaning infection...")

                            -- Nettoyer l'infection
                            print("[DEBUG] Setting wound infection to false...")
                            wound:setInfected(false)
                            print("[DEBUG] Wound infection cleared")

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
                                print("[DEBUG] Sending client command to server...")
                                local playerID = player:getOnlineID()
                                print("[DEBUG] Player online ID:", playerID)

                                local commandData = {
                                    woundType = woundType,
                                    playerID = playerID
                                }
                                print("[DEBUG] Command data:", commandData)

                                sendClientCommand(player, "BiteMunity", "ImmunityTriggered", commandData)
                                print("[DEBUG] Client command sent successfully")
                            else
                                print("[DEBUG] Not in client mode, skipping server communication")
                            end
                        else
                            print("[DEBUG] Player does not have immunity for", woundType)
                        end
                    else
                        print("[DEBUG] Wound", j, "is not infected, skipping")
                    end
                else
                    print("[DEBUG] Wound object is nil at index:", j)
                end
            end
        else
            print("[DEBUG] Body part is nil at index:", i)
        end
    end

    print("[DEBUG] BiteMunityClient.checkForInfections() - Function completed")
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