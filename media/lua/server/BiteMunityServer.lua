-- media/lua/server/BiteMunityServer.lua
-- Code côté serveur pour le mod BiteMunity - MORSURES UNIQUEMENT

BiteMunityServer = BiteMunityServer or {}

-- Fonction pour gérer les commandes des clients
function BiteMunityServer.onClientCommand(module, command, player, args)
    if module ~= "BiteMunity" then 
        return 
    end
    
    if command == "ImmunityTriggered" then
        -- Un client a déclenché l'immunité aux morsures
        local settings = BiteMunityConfig.getSandboxSettings()
        
        if settings.permanentImmunity then
            BiteMunityCore.setPlayerPermanentImmunity(player, true)
            
            -- Informer tous les clients de l'état d'immunité du joueur
            sendServerCommand("BiteMunity", "SyncImmunity", {
                playerID = player:getOnlineID(),
                immune = true
            })
        end
        
        -- Diffuser le message d'immunité si activé
        if settings.showMessage then
            sendServerCommand(player, "BiteMunity", "ShowImmunityMessage", {
                playerID = player:getOnlineID(),
                woundType = "Bite"
            })
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
    if not isServer() then 
        return 
    end
    
    -- Ne traiter que les morsures
    if damageType ~= "BITE" and damageType ~= "Bite" then
        return
    end
    
    BiteMunityCore.onPlayerGetDamage(player, damageType, damage)
end

function BiteMunityServer.onCreatePlayer(playerIndex, player)
    if not isServer() then 
        return 
    end
    
    BiteMunityCore.onPlayerCreate(playerIndex, player)
    
    -- Envoyer le statut d'immunité au client
    local immune = BiteMunityCore.isPlayerPermanentlyImmune(player)
    sendServerCommand(player, "BiteMunity", "SyncImmunity", {
        playerID = player:getOnlineID(),
        immune = immune
    })
end

function BiteMunityServer.onPlayerConnect(player)
    if not isServer() then 
        return 
    end
    
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
    if not isServer() then 
        return 
    end
    
    -- Sauvegarder les données d'immunité
    local modData = player:getModData()
    modData.BiteMunityImmune = BiteMunityCore.isPlayerPermanentlyImmune(player)
    
    local playerID = tostring(player:getOnlineID())
    if BiteMunityCore.naturallyImmunePlayers[playerID] then
        modData.BiteMunityNaturallyImmune = BiteMunityCore.naturallyImmunePlayers[playerID]
    end
end

-- Vérification périodique côté serveur
function BiteMunityServer.onEveryTenMinutes()
    if not isServer() then 
        return 
    end
    
    -- Vérifier tous les joueurs connectés pour les infections de morsure
    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            -- Utiliser la fonction de vérification de BiteMunityCore
            BiteMunityCore.checkForBiteInfections(player)
        end
    end
end

-- Fonction d'initialisation côté serveur
function BiteMunityServer.init()
    if not isServer() then 
        return 
    end
    
    -- Enregistrer les événements serveur
    Events.OnClientCommand.Add(BiteMunityServer.onClientCommand)
    Events.OnPlayerGetDamage.Add(BiteMunityServer.onPlayerGetDamage)
    Events.OnCreatePlayer.Add(BiteMunityServer.onCreatePlayer)
    Events.OnPlayerConnect.Add(BiteMunityServer.onPlayerConnect)
    Events.OnPlayerDisconnect.Add(BiteMunityServer.onPlayerDisconnect)
    Events.EveryTenMinutes.Add(BiteMunityServer.onEveryTenMinutes)
    
    print("[BiteMunity] Server initialized - Protection contre les morsures de zombies uniquement")
end

-- Initialiser le serveur
Events.OnGameStart.Add(BiteMunityServer.init)