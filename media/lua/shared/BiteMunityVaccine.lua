-- media/lua/shared/BiteMunityVaccine.lua
-- Système de vaccin complexe pour BiteMunity

BiteMunityVaccine = BiteMunityVaccine or {}

-- Configuration du système de vaccin
BiteMunityVaccine.Config = {
    -- Compétences requises
    REQUIRED_DOCTOR_LEVEL = 8,
    REQUIRED_FIRSTAID_LEVEL = 6,
    
    -- Taux de réussite
    BASE_SUCCESS_RATE = 20,
    SKILL_BONUS_PER_LEVEL = 5,
    MAX_SUCCESS_RATE = 85,
    
    -- Cooldowns (en heures de jeu)
    DONOR_COOLDOWN = 72,     -- 3 jours
    RECEIVER_COOLDOWN = 168, -- 7 jours
    
    -- Effets secondaires (durée en heures)
    SIDE_EFFECTS_DURATION = 24,
    
    -- Quantité de sang prélevé
    BLOOD_SAMPLE_AMOUNT = 250,
    MIN_HEALTH_FOR_DONATION = 50,
    HEALTH_LOSS_ON_DONATION = 15,
}

-- Table pour suivre les cooldowns des joueurs
BiteMunityVaccine.PlayerCooldowns = {
    donors = {},    -- Dernier don de sang
    receivers = {}, -- Dernière injection
}

-- Table pour suivre les effets secondaires actifs
BiteMunityVaccine.ActiveSideEffects = {}

-- Fonction pour vérifier si un joueur peut donner son sang
function BiteMunityVaccine.canDonateBlood(player)
    if not player then return false, "Joueur invalide" end
    
    -- Vérifier l'immunité permanente
    if not BiteMunityCore.isPlayerPermanentlyImmune(player) then
        return false, "Le donneur doit être immunisé de façon permanente"
    end
    
    -- Vérifier la santé minimale
    local health = player:getHealth()
    if health < BiteMunityVaccine.Config.MIN_HEALTH_FOR_DONATION then
        return false, "Santé insuffisante pour donner du sang (minimum " .. BiteMunityVaccine.Config.MIN_HEALTH_FOR_DONATION .. "%)"
    end
    
    -- Vérifier le cooldown
    local playerID = tostring(player:getOnlineID())
    local lastDonation = BiteMunityVaccine.PlayerCooldowns.donors[playerID]
    if lastDonation then
        local gameTime = getGameTime()
        local currentTime = gameTime:getWorldAgeHours()
        local timeSinceDonation = currentTime - lastDonation
        
        if timeSinceDonation < BiteMunityVaccine.Config.DONOR_COOLDOWN then
            local remaining = BiteMunityVaccine.Config.DONOR_COOLDOWN - timeSinceDonation
            return false, string.format("Cooldown actif: %.1f heures restantes", remaining)
        end
    end
    
    return true, "OK"
end

-- Fonction pour prélever du sang d'un joueur immunisé
function BiteMunityVaccine.donateBlood(donor, medic)
    if not donor or not medic then return false, "Paramètres invalides" end
    
    -- Vérifications préliminaires
    local canDonate, reason = BiteMunityVaccine.canDonateBlood(donor)
    if not canDonate then
        return false, reason
    end
    
    -- Vérifier les compétences du médecin
    local medicSkill = medic:getPerkLevel(Perks.Doctor)
    local firstAidSkill = medic:getPerkLevel(Perks.FirstAid)
    
    if medicSkill < BiteMunityVaccine.Config.REQUIRED_DOCTOR_LEVEL then
        return false, "Compétence Médecine insuffisante (niveau " .. BiteMunityVaccine.Config.REQUIRED_DOCTOR_LEVEL .. " requis)"
    end
    
    if firstAidSkill < BiteMunityVaccine.Config.REQUIRED_FIRSTAID_LEVEL then
        return false, "Compétence Premiers Secours insuffisante (niveau " .. BiteMunityVaccine.Config.REQUIRED_FIRSTAID_LEVEL .. " requis)"
    end
    
    -- Vérifier l'équipement nécessaire
    local inventory = medic:getInventory()
    local syringe = inventory:getFirstTypeEval("BloodSyringe", function(item) 
        return item:getType() == "BloodSyringe" and not item:hasTag("Used")
    end)
    
    if not syringe then
        return false, "Seringue stérilisée requise"
    end
    
    -- Effectuer le prélèvement
    local donorID = tostring(donor:getOnlineID())
    local gameTime = getGameTime()
    local currentTime = gameTime:getWorldAgeHours()
    
    -- Enregistrer le cooldown
    BiteMunityVaccine.PlayerCooldowns.donors[donorID] = currentTime
    
    -- Réduire la santé du donneur
    local stats = donor:getStats()
    stats:setEndurance(stats:getEndurance() - 0.3)
    donor:setHealth(donor:getHealth() - BiteMunityVaccine.Config.HEALTH_LOSS_ON_DONATION)
    
    -- Créer l'échantillon de sang immunisé
    local bloodSample = inventory:AddItem("BiteMunity.ImmuneBloodSample")
    if bloodSample then
        bloodSample:setName("Echantillon Sang Immunise - " .. donor:getDisplayName())
        bloodSample:getModData().donorID = donorID
        bloodSample:getModData().collectionTime = currentTime
        bloodSample:getModData().donorSkills = {
            doctor = medicSkill,
            firstAid = firstAidSkill
        }
    end
    
    -- Consommer la seringue
    inventory:Remove(syringe)
    
    -- Messages
    medic:Say("Prelevement de sang effectue avec succes.")
    donor:Say("Je me sens un peu faible mais ca va aller.")
    
    return true, "Prélèvement réussi"
end

-- Fonction pour créer le vaccin à partir du sang
function BiteMunityVaccine.createVaccine(medic, bloodSample, microscope, centrifuge, labEquipment)
    if not medic or not bloodSample then return false, "Paramètres invalides" end
    
    -- Vérifier les compétences
    local medicSkill = medic:getPerkLevel(Perks.Doctor)
    if medicSkill < BiteMunityVaccine.Config.REQUIRED_DOCTOR_LEVEL then
        return false, "Compétence Médecine insuffisante"
    end
    
    -- Vérifier l'équipement
    if not microscope or not centrifuge or not labEquipment then
        return false, "Équipement médical complet requis (microscope, centrifugeuse, laboratoire)"
    end
    
    -- Vérifier l'âge de l'échantillon (ne doit pas être trop vieux)
    local sampleData = bloodSample:getModData()
    local gameTime = getGameTime()
    local currentTime = gameTime:getWorldAgeHours()
    local sampleAge = currentTime - (sampleData.collectionTime or 0)
    
    if sampleAge > 48 then -- 2 jours maximum
        return false, "L'échantillon de sang est trop ancien"
    end
    
    -- Calculer le taux de réussite
    local baseRate = BiteMunityVaccine.Config.BASE_SUCCESS_RATE
    local skillBonus = (medicSkill - BiteMunityVaccine.Config.REQUIRED_DOCTOR_LEVEL) * BiteMunityVaccine.Config.SKILL_BONUS_PER_LEVEL
    local successRate = math.min(baseRate + skillBonus, BiteMunityVaccine.Config.MAX_SUCCESS_RATE)
    
    -- Ajouter XP
    medic:getXp():AddXP(Perks.Doctor, 50)
    
    -- Tenter la création
    local roll = ZombRand(100) + 1
    local success = roll <= successRate
    
    -- Consommer les ressources
    local inventory = medic:getInventory()
    inventory:Remove(bloodSample)
    
    -- Consommer produits chimiques
    local chemicals = inventory:getFirstType("ChemicalBottle")
    if chemicals then
        inventory:Remove(chemicals)
    end
    
    if success then
        -- Créer le vaccin
        local vaccine = inventory:AddItem("BiteMunity.ImmunityVaccine")
        if vaccine then
            vaccine:setName("Vaccin d'Immunite - Lot " .. tostring(ZombRand(1000, 9999)))
            vaccine:getModData().creationTime = currentTime
            vaccine:getModData().creatorSkill = medicSkill
            vaccine:getModData().quality = math.min(100, 50 + skillBonus)
        end
        
        medic:Say("Vaccin cree avec succes !")
        return true, "Vaccin créé"
    else
        medic:Say("La creation du vaccin a echoue. Echantillon perdu.")
        return false, "Échec de la création"
    end
end

-- Fonction pour administrer le vaccin
function BiteMunityVaccine.administerVaccine(medic, patient, vaccine)
    if not medic or not patient or not vaccine then return false, "Paramètres invalides" end
    
    -- Vérifications
    local canReceive, reason = BiteMunityVaccine.canReceiveVaccine(patient)
    if not canReceive then
        return false, reason
    end
    
    -- Vérifier les compétences du médecin
    local medicSkill = medic:getPerkLevel(Perks.Doctor)
    if medicSkill < BiteMunityVaccine.Config.REQUIRED_DOCTOR_LEVEL then
        return false, "Compétence Médecine insuffisante pour administrer le vaccin"
    end
    
    -- Vérifier l'âge du vaccin
    local vaccineData = vaccine:getModData()
    local gameTime = getGameTime()
    local currentTime = gameTime:getWorldAgeHours()
    local vaccineAge = currentTime - (vaccineData.creationTime or 0)
    
    if vaccineAge > 168 then -- 7 jours maximum
        return false, "Le vaccin est trop ancien et n'est plus efficace"
    end
    
    -- Calculer les chances de succès basées sur la qualité du vaccin et les compétences
    local baseRate = vaccineData.quality or 50
    local skillBonus = (medicSkill - BiteMunityVaccine.Config.REQUIRED_DOCTOR_LEVEL) * 3
    local successRate = math.min(baseRate + skillBonus, 95)
    
    -- Enregistrer le cooldown
    local patientID = tostring(patient:getOnlineID())
    BiteMunityVaccine.PlayerCooldowns.receivers[patientID] = currentTime
    
    -- Consommer le vaccin
    local inventory = medic:getInventory()
    inventory:Remove(vaccine)
    
    -- Ajouter XP
    medic:getXp():AddXP(Perks.Doctor, 75)
    
    -- Tenter l'injection
    local roll = ZombRand(100) + 1
    local success = roll <= successRate
    
    if success then
        -- Succès: accorder l'immunité permanente
        BiteMunityCore.setPlayerPermanentImmunity(patient, true)
        BiteMunityCore.showImmunityMessage(patient, "Vaccine")
        
        patient:Say("Je me sens... different. Plus fort.")
        medic:Say("Injection reussie ! Le patient est maintenant immunise.")
        
        -- Synchroniser en multijoueur
        if isServer() then
            sendServerCommand("BiteMunity", "SyncImmunity", {
                playerID = patient:getOnlineID(),
                immune = true
            })
        end
        
        return true, "Vaccination réussie"
    else
        -- Échec: effets secondaires
        BiteMunityVaccine.applySideEffects(patient)
        
        patient:Say("Je ne me sens pas bien du tout...")
        medic:Say("Le patient reagit mal au vaccin. Effets secondaires en cours.")
        
        return false, "Vaccination échouée - effets secondaires"
    end
end

-- Fonction pour appliquer les effets secondaires
function BiteMunityVaccine.applySideEffects(player)
    if not player then return end
    
    local playerID = tostring(player:getOnlineID())
    local gameTime = getGameTime()
    local currentTime = gameTime:getWorldAgeHours()
    
    -- Enregistrer les effets secondaires
    BiteMunityVaccine.ActiveSideEffects[playerID] = {
        startTime = currentTime,
        endTime = currentTime + BiteMunityVaccine.Config.SIDE_EFFECTS_DURATION,
        severity = ZombRand(1, 4) -- 1=léger, 2=modéré, 3=sévère
    }
    
    -- Appliquer immédiatement les premiers effets
    local stats = player:getStats()
    local bodyDamage = player:getBodyDamage()
    
    -- Nausée et vomissements
    stats:setNausea(0.8)
    stats:setStress(0.6)
    
    -- Fièvre (température corporelle)
    bodyDamage:setTemperature(39.5)
    
    -- Fatigue
    stats:setFatigue(0.9)
    
    -- Réduction des capacités
    stats:setEndurance(stats:getEndurance() * 0.6)
    
    player:Say("Ugh... Je me sens vraiment mal...")
end

-- Fonction pour gérer les effets secondaires actifs (appelée périodiquement)
function BiteMunityVaccine.processSideEffects()
    local gameTime = getGameTime()
    if not gameTime then return end
    
    local currentTime = gameTime:getWorldAgeHours()
    
    for playerID, effects in pairs(BiteMunityVaccine.ActiveSideEffects) do
        if currentTime >= effects.endTime then
            -- Effets terminés
            BiteMunityVaccine.ActiveSideEffects[playerID] = nil
            
            -- Récupérer le joueur et restaurer ses capacités
            local player = getPlayerByOnlineID(tonumber(playerID))
            if player then
                local stats = player:getStats()
                stats:setNausea(0)
                stats:setStress(0.2)
                stats:setFatigue(0.3)
                
                player:Say("Je commence a me sentir mieux...")
            end
        else
            -- Continuer les effets
            local player = getPlayerByOnlineID(tonumber(playerID))
            if player then
                local stats = player:getStats()
                local timeLeft = effects.endTime - currentTime
                local intensity = math.min(timeLeft / BiteMunityVaccine.Config.SIDE_EFFECTS_DURATION, 1)
                
                -- Maintenir les effets en fonction de l'intensité
                if intensity > 0.5 then
                    stats:setNausea(0.7 + (intensity * 0.3))
                    stats:setStress(0.5 + (intensity * 0.4))
                    
                    -- Chance d'évanouissement si sévère
                    if effects.severity >= 3 and ZombRand(1000) < 5 then
                        player:setAsleep(true)
                        player:Say("Je... je vais m'evanouir...")
                    end
                end
            end
        end
    end
end

-- Fonction pour sauvegarder les données du système de vaccin
function BiteMunityVaccine.saveData(player)
    if not player then return end
    
    local modData = player:getModData()
    local playerID = tostring(player:getOnlineID())
    
    -- Sauvegarder les cooldowns
    modData.BiteMunityVaccine_LastDonation = BiteMunityVaccine.PlayerCooldowns.donors[playerID]
    modData.BiteMunityVaccine_LastInjection = BiteMunityVaccine.PlayerCooldowns.receivers[playerID]
    
    -- Sauvegarder les effets secondaires actifs
    modData.BiteMunityVaccine_SideEffects = BiteMunityVaccine.ActiveSideEffects[playerID]
end

-- Fonction pour charger les données du système de vaccin
function BiteMunityVaccine.loadData(player)
    if not player then return end
    
    local modData = player:getModData()
    local playerID = tostring(player:getOnlineID())
    
    -- Charger les cooldowns
    if modData.BiteMunityVaccine_LastDonation then
        BiteMunityVaccine.PlayerCooldowns.donors[playerID] = modData.BiteMunityVaccine_LastDonation
    end
    
    if modData.BiteMunityVaccine_LastInjection then
        BiteMunityVaccine.PlayerCooldowns.receivers[playerID] = modData.BiteMunityVaccine_LastInjection
    end
    
    -- Charger les effets secondaires
    if modData.BiteMunityVaccine_SideEffects then
        BiteMunityVaccine.ActiveSideEffects[playerID] = modData.BiteMunityVaccine_SideEffects
    end
end

-- Fonction pour vérifier si un joueur peut recevoir le vaccin
function BiteMunityVaccine.canReceiveVaccine(player)
    if not player then return false, "Joueur invalide" end
    
    -- Vérifier si déjà immunisé
    if BiteMunityCore.isPlayerPermanentlyImmune(player) then
        return false, "Ce joueur est déjà immunisé"
    end
    
    -- Vérifier le cooldown
    local playerID = tostring(player:getOnlineID())
    local lastInjection = BiteMunityVaccine.PlayerCooldowns.receivers[playerID]
    if lastInjection then
        local gameTime = getGameTime()
        local currentTime = gameTime:getWorldAgeHours()
        local timeSinceInjection = currentTime - lastInjection
        
        if timeSinceInjection < BiteMunityVaccine.Config.RECEIVER_COOLDOWN then
            local remaining = BiteMunityVaccine.Config.RECEIVER_COOLDOWN - timeSinceInjection
            return false, string.format("Cooldown actif: %.1f heures restantes", remaining)
        end
    end
    
    return true, "OK"
