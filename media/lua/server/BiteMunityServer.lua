-- BiteMunityServer.lua
-- Code côté serveur pour le mod BiteMunity

require "shared/BiteMunityConfig"
require "shared/BiteMunityCore"

BiteMunityServer = BiteMunityServer or {}

-- Fonction pour gérer les commandes des clients
function BiteMunityServer.onClientCommand(module, command, player, args)
    if module ~= "BiteMunity" then return end
    
    if command == "ImmunityTriggered" then
        -- Un client a déclenché l'immunité, synchroniser avec les autres joueurs
        local settings = BiteMunityConfig.getSandboxSettings()
        
        if settings.permanentImmunity then
            BiteMunityCore.setPlayerPermanentImmunity(player, true)
            
            -- Informer tous les clients de l'état d'immunité du joueur
            sendServerCommand("BiteMunity", "SyncImmunity", {
                playerID = player:getOnlineID(),
                immune = true
            })
        end
        
        -- Diffuser le message d'immunité à tous les joueurs proches
        if settings.showMessage then
            local nearbyPlayers = {}
            local square = player:getSquare()
            if square then
                for x = -10, 10 do
                    for y = -10, 10 do
                        local checkSquare = square:getCell():getGridSquare(square:getX() + x, square:getY() + y, square:getZ())
                        if checkSquare then
                            local objects = checkSquare:getObjects()
                            for i = 0, objects:size() - 1 do
                                local obj = objects:get(i)
                                if instanceof(obj, "IsoPlayer") then
                                    local nearbyPlayer = obj
                                    sendServerCommand(nearbyPlayer, "BiteMunity", "ShowImmunityMessage", {
                                        playerID = player:getOnlineID(),
                                        woundType = args.woundType or "Bite"
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    elseif command == "RequestImmunityStatus" then
        -- Un client demande le statut d'immunité
        local immune = BiteMunityCore.isPlayerPermanentlyImmune(player)
        sendServerCommand(player, "BiteMunity", "SyncImmunity", {
            playerID = player:getOnlineID(),
            immune = immune
        })
    end
end

-- Event handlers côté serveur
function BiteMunityServer.onPlayerGetDamage(player, damageType, damage)
    if not isServer() then return end
    BiteMunityCore.onPlayerGetDamage(player, damageType, damage)
end

function BiteMunityServer.onZombieAttack(zombie, player, bodyPart, weapon)
    if not isServer() then return end
    BiteMunityCore.onZombieAttack(zombie, player, bodyPart, weapon)
end

function BiteMunityServer.onCreatePlayer(playerIndex, player)
    if not isServer() then return end
    BiteMunityCore.onPlayerCreate(playerIndex, player)
    
    -- Envoyer le statut d'immunité au client
    local immune = BiteMunityCore.isPlayerPermanentlyImmune(player)
    sendServerCommand(player, "BiteMunity", "SyncImmunity", {
        playerID = player:getOnlineID(),
        immune = immune
    })
end

function BiteMunityServer.onPlayerConnect(player)
    if not isServer() then return end
    
    -- Charger les données d'immunité du joueur
    BiteMunityCore.loadPlayerImmunity(player)
    
    -- Synchroniser avec le client
    local immune = BiteMunityCore.isPlayerPermanentlyImmune(player)
    sendServerCommand(player, "BiteMunity", "SyncImmunity", {
        playerID = player:getOnlineID(),
        immune = immune
    })
end

function BiteMunityServer.onPlayerDisconnect(player)
    if not isServer() then return end
    
    -- Sauvegarder les données d'immunité
    local settings = BiteMunityConfig.getSandboxSettings()
    if settings.permanentImmunity then
        local modData = player:getModData()
        modData.BiteMunityImmune = BiteMunityCore.isPlayerPermanentlyImmune(player)
    end
end

-- Fonction de vérification périodique côté serveur
function BiteMunityServer.onEveryTenMinutes()
    if not isServer() then return end
    
    -- Vérifier tous les joueurs connectés pour les infections
    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            local bodyDamage = player:getBodyDamage()
            if bodyDamage and bodyDamage:isInfected() then
                -- Vérifier si le joueur devrait être immunisé
                local settings = BiteMunityConfig.getSandboxSettings()
                if settings.permanentImmunity and BiteMunityCore.isPlayerPermanentlyImmune(player) then
                    -- Nettoyer l'infection
                    BiteMunityCore.cleanInfection(player)
                    
                    -- Informer le client
                    sendServerCommand(player, "BiteMunity", "ShowImmunityMessage", {
                        playerID = player:getOnlineID(),
                        woundType = "Bite"
                    })
                end
            end
        end
    end
end

-- Fonction d'initialisation côté serveur
function BiteMunityServer.init()
    if not isServer() then return end
    
    -- Enregistrer les événements serveur
    Events.OnClientCommand.Add(BiteMunityServer.onClientCommand)
    Events.OnPlayerGetDamage.Add(BiteMunityServer.onPlayerGetDamage)
    Events.OnCreatePlayer.Add(BiteMunityServer.onCreatePlayer)
    Events.OnPlayerConnect.Add(BiteMunityServer.onPlayerConnect)
    Events.OnPlayerDisconnect.Add(BiteMunityServer.onPlayerDisconnect)
    Events.EveryTenMinutes.Add(BiteMunityServer.onEveryTenMinutes)
    
    print("[BiteMunity] Server initialized")
end

-- Initialiser le serveur
Events.OnGameStart.Add(BiteMunityServer.init)