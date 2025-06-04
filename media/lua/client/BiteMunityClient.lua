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
    local player = getPlayer()
    if not player then return end
    
    -- Vérification de sécurité pour getGameTime()
    local gameTime = getGameTime()
    if not gameTime then return end
    
    -- Alternative plus sûre pour calculer le temps
    local currentFrame = gameTime:getWorldAgeHours()
    if not currentFrame then
        -- Fallback vers un compteur simple si getWorldAgeHours() échoue
        currentFrame = lastInfectionCheck + 1
    else
        currentFrame = currentFrame * 3600 + (gameTime:getTimeOfDay() or 0)
    end
    
    if currentFrame - lastInfectionCheck < CHECK_INTERVAL then
        return
    end
    
    lastInfectionCheck = currentFrame
    
    -- Vérifier si le joueur a une nouvelle infection
    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then return end
    
    -- Parcourir toutes les parties du corps
    for i = 0, bodyDamage:getBodyParts():size() - 1 do
        local bodyPart = bodyDamage:getBodyParts():get(i)
        if bodyPart then
            -- Parcourir toutes les blessures
            for j = 0, bodyPart:getWounds():size() - 1 do
                local wound = bodyPart:getWounds():get(j)
                if wound and wound:isInfected() then
                    -- Déterminer le type de blessure
                    local woundType = "Bite" -- Par défaut
                    
                    if wound:getType() then
                        local type = tostring(wound:getType())
                        if type:find("Scratch") then
                            woundType = "Scratch"
                        elseif type:find("Laceration") then
                            woundType = "Laceration"
                        elseif type:find("Bite") then
                            woundType = "Bite"
                        end
                    end
                    
                    -- Tester l'immunité
                    if BiteMunityCore.testImmunity(player, woundType) then
                        -- Nettoyer l'infection
                        wound:setInfected(false)
                        BiteMunityCore.cleanInfection(player)
                        BiteMunityCore.showImmunityMessage(player, woundType)
                        
                        -- Envoyer au serveur si en multijoueur
                        if isClient() then
                            sendClientCommand(player, "BiteMunity", "ImmunityTriggered", {
                                woundType = woundType,
                                playerID = player:getOnlineID()
                            })
                        end
                    end
                end
            end
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