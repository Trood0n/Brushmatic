-- Définir le dossier pour les schémas et les fichiers de coordonnées
local schem_dir = minetest.get_worldpath() .. "/brushmatic"
local coords_file = minetest.get_worldpath() .. "/brushmatic/relative_coordinates.txt"
local temps_schems_path = schem_dir .. "/temp_schematics"
local wea_c = worldeditadditions_core
local max_radius = 50

-- Création des répertoires si besoin
minetest.mkdir(schem_dir)
minetest.mkdir(temps_schems_path)
-------------------
--- Enregistrement de données + fonctions usefull ---
-------------------

-- Fonction pour charger les coordonnées relatives depuis le fichier
local function load_relative_coordinates()
    local relative_coordinates = {}
    local file = io.open(coords_file, "r")
    if file then
        local data = file:read("*all")
        local deserialized_data = minetest.deserialize(data)
        if type(deserialized_data) == "table" then
            relative_coordinates = deserialized_data
        else
            minetest.log("error", "The relative coordinates file is corrupted.")
        end
        file:close()
    end
    return relative_coordinates
end

-- Fonction pour sauvegarder les coordonnées relatives dans le fichier.txt pour pouvoir le partager facilement
local function save_relative_coordinates(relative_coordinates)
    local file = io.open(coords_file, "w")
    if file then
        file:write(minetest.serialize(relative_coordinates))
        file:close()
    else
        minetest.log("error", "Cannot save relative coordinates.")
    end
end

-- Fonction pour enregistrer un schem et ses coordonnées relatives
local function save_relative_pos_to_file(schematic_name, relative_pos)
    local relative_coordinates = load_relative_coordinates()
    relative_coordinates[schematic_name] = relative_pos
    save_relative_coordinates(relative_coordinates)
end

-- Fonction pour calculer la pos de p3 par rapport au coin inférieur gauche 
local function calculate_relative_pos(p1, p2, p3)
    local min_pos = {
        x = math.min(p1.x, p2.x),
        y = math.min(p1.y, p2.y),
        z = math.min(p1.z, p2.z),
    }

    return {
        x = p3.x - min_pos.x,
        y = p3.y - min_pos.y,
        z = p3.z - min_pos.z,
    }
end
-- Fonction pour obtenir les 3 points nécessaires via WorldEdit Addition
local function get_we_points(name)
    local p1 = worldedit.pos1[name]
    local p2 = worldedit.pos2[name]
    local p3 = wea_c.pos.get(name, 3)
    return p1, p2, p3
end
-- La classique table_contains
local function table_contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-------------------
--- Récupération & placement des schems ---
-------------------

-- Fonction pour lister l'ensemble des schems avec leur caté ex  : arbre/arbre1
local function get_schematics(schem_dir)
    local schematics = {}

    -- Fonction récursive pour explorer les sous-dossiers
    local function scan_dir(dir)
        for _, subdir in ipairs(minetest.get_dir_list(dir, true)) do
            local subdir_path = dir .. "/" .. subdir
            scan_dir(subdir_path)
        end
        for _, filename in ipairs(minetest.get_dir_list(dir, false)) do
            local filepath = dir .. "/" .. filename
            if filename:match(".mts$") then
                table.insert(schematics, filepath:sub(#schem_dir + 2, -5)) 
            end
        end
    end

    scan_dir(schem_dir)

    return schematics
end

-- Fonction pour lister les catégorie disponible dans le folder brushmatic 
local function get_cate(schem_dir)
    local cates = {}

    for _, cate in ipairs(minetest.get_dir_list(schem_dir, true)) do
        if cate ~= "temp_schematics" then 
            table.insert(cates, cate)
        end
    end
    return cates
end

-- Fonction pour obtenir les vrais noms des schems ex : arbre1 et non arbre/arbre1
local function get_schematic_names(schem_dir)
    local schematic_names = {}
    local schematics = get_schematics(schem_dir)  -- récup la liste complète
    
    -- Recup le vrai nom des schems
    for _, schematic in ipairs(schematics) do
        local name = schematic:match("([^/]+)$")
        if name then
            table.insert(schematic_names, name)
        end
    end
    
    return schematic_names
end

-- Permet de savoir le schem possède des coos relatives
local function scheme_get_relatives_cos(scheme_name)
    local relative_coordinates = load_relative_coordinates()
    local relative_pos = relative_coordinates[scheme_name]
    if relative_pos then 
        return relative_pos
    else
        return nil
    end
end

local function rotate_node_coords(x, y, z, angle)
    if angle == "90" then
        return z, y, -x
    elseif angle == "180" then
        return -x, y, -z
    elseif angle == "270" then
        return -z, y, -x
    else
        return x, y, z -- Pas de rotation
    end
end

local function place_custom_schematic(pos, schematic_path, flags)
    -- Charger le schéma
    local schematic = minetest.serialize_schematic(schematic_path, "lua", {})
    if not schematic then
        return false, "Failed to load schematic"
    end
    
    schematic = schematic .. " return schematic"

    local schematic_func, err = loadstring(schematic)
    if not schematic_func then
        return false, "Error loading schematic: " .. tostring(err)
    end

    local schematic = schematic_func()   

    -- Calculer le décalage pour le centrage
    local offset = {x = pos.x, y = pos.y, z = pos.z}
    if flags then
        if flags.place_center_x then
            offset.x = pos.x - math.floor(schematic.size.x / 2)
        end
        if flags.place_center_y then
            offset.y = pos.y - math.floor(schematic.size.y / 2)
        end
        if flags.place_center_z then
            offset.z = pos.z - math.floor(schematic.size.z / 2)
        end
    end

    -- Préparer le VoxelManip
    local vmanip = minetest.get_voxel_manip()
    
    -- Recalcul des limites dynamiques
    local pos1 = offset
    local pos2 = {
        x = pos.x + schematic.size.x,
        y = pos.y + schematic.size.y,
        z = pos.z + schematic.size.z,
    }

    -- Lire les données de la carte dans le VoxelManip
    local emin, emax = vmanip:read_from_map(pos1, pos2)
    local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
    local data = vmanip:get_data()

    -- Placer les nœuds
    for z = 0, schematic.size.z - 1 do
        for y = 0, schematic.size.y - 1 do
            for x = 0, schematic.size.x - 1 do
                local index = (z * schematic.size.y + y) * schematic.size.x + x + 1
                local node = schematic.data[index]
                if node.name ~= "air" and node.name ~= "ignore" then
                    local abs_pos = {
                        x = offset.x + x,
                        y = offset.y + y,
                        z = offset.z + z,
                    }
                    local vi = area:index(abs_pos.x, abs_pos.y, abs_pos.z)
                    data[vi] = minetest.get_content_id(node.name)
                end
            end
        end
    end

    -- Appliquer les changements
    vmanip:set_data(data)
    vmanip:write_to_map()
    vmanip:update_map()

    return true, "Schematic placed successfully with flags"
end



-- Fonction pour placer un schematic en fonction du bloc recherché dans une zone précise (quasi la même que la fonction dans l'init.lua avec qlqs modifs)
local function place_schematic_on_blocks_in_zone(schematic_name, pos, radius, bloc, force_placement, rotation, centralization, relative_coos, mod, cate, replacements)
    -- Vérification que le rayon est valide
    if radius <= 0 or radius > max_radius then
        return false, "Invalid radius."
    end

    -- Vérification que le bloc soit valide
    if not minetest.registered_nodes[bloc] then
        return false, "Invalid block type."
    end
 
    local schematic_path = schem_dir .."/" .. schematic_name .. ".mts"
    local area_min = vector.subtract(pos, {x = radius, y = radius, z = radius})
    local area_max = vector.add(pos, {x = radius, y = radius, z = radius})

    -- Recherche des blocs dans la zone
    local target_positions = minetest.find_nodes_in_area(area_min, area_max, bloc)
    if #target_positions == 0 then
        return false, "No target nodes found in the area."
    end
    -- Changement du message
    local message_ok = "Schematics have been successfully placed "..#target_positions.." times"
    if replacements == "true" then 
        message_ok = message_ok .. " without air."
    end

    for i = 1, #target_positions do
        local schematic_pos = {
            x = target_positions[i].x,
            y = target_positions[i].y,
            z = target_positions[i].z
        }
        -- Cheack si le brush est en Random Brush
        if mod == "true" and cate and cate ~= "" then
            local cate_path = schem_dir .. "/" .. cate
            local category_schems = get_schematics(cate_path)
            if #category_schems > 0 then
                schematic_name = category_schems[math.random(#category_schems)]
                schematic_path = cate_path .. "/" .. schematic_name .. ".mts"
            else
                return false, "No schematics found in category: " .. cate
            end 
        end
        -- Si l'option placement avec des relatives coos est activée 
        local use_relative_coos = false
        if relative_coos == "true" then
            local relative_pos = scheme_get_relatives_cos(schematic_name:match("([^/]+)$"))
            if relative_pos then
                schematic_pos = {
                    x = schematic_pos.x - relative_pos.x,
                    y = schematic_pos.y - relative_pos.y,
                    z = schematic_pos.z - relative_pos.z,
                }
                rotation = "0"
                centralization = nil
            end
        end
        if replacements == "true" then 
            local success, message = place_custom_schematic(schematic_pos, schematic_path, centralization, rotation)
            if not success then
                return false, "Error in place_custom_schematic : " .. message
            end
        else
            replacements = nil
            minetest.place_schematic(schematic_pos, schematic_path, rotation, replacements, force_placement, centralization)
        end 
    end

    return true, message_ok
end

-------------------
--- Commandes Register ---
-------------------

-- Commande pour créer un schem
minetest.register_chatcommand("create_scheme", {
    params = "<filename> <category>",
    description = "Create a schematic using 3 WorldEdit Addition points and manage him with a categorie",
    privs = {server = true},
    func = function(name, param)
        if param == "" then
            return false, "Usage: /create_scheme <filename> <category>"
        end
        local args = param:split(" ")
        local scheme_name = args[1]
        local cate = args[2]
        local p1, p2, p3, err = get_we_points(name)
        -- Création du dossier de la caté si besoin 
        local schematic_names = get_schematic_names(schem_dir)  -- Liste des vrais noms des schémas existants
        if table_contains(schematic_names, scheme_name) then
            return false, "A schematic with the name '" .. scheme_name .. "' already exists."
        end
        local schematic_path = schem_dir .. scheme_name .. ".mts"
        if cate and cate ~= "" then 
            local path_brushmatic = minetest.get_worldpath() .. "/brushmatic"
            local path_cate = path_brushmatic .. "/"..cate
            minetest.mkdir(path_cate)
            schematic_path = path_cate .."/".. scheme_name .. ".mts"
        else
            return false, "Please enter a category for your schematic"
        end
        -- Cheack si la pos3 est utiliser = coos relative sinon scheme normal
        if p3 then
            -- Calcul la pos relative du schem
            local relative_pos = calculate_relative_pos(p1, p2, p3)
            save_relative_pos_to_file(scheme_name, relative_pos)
            minetest.create_schematic(p1, p2, nil, schematic_path)
            return true, "Schematic '" .. scheme_name .. "' created and saved with relative coordinates in the category : " ..cate
        else
            minetest.create_schematic(p1, p2, nil, schematic_path)
            return true, "Schematic '" .. scheme_name .. "' created and saved in the category : "..cate
        end
    end,
})

-- Commande pour supprimer un schem
minetest.register_chatcommand("delete_scheme", {
    params = "<schematic_name>",
    description = "Delete relative coordinates of a schematic from the file",
    privs = {server = true},
    func = function(name, param)
        if param == "" then
            return false, "Usage: /delete_scheme <schematic_name>"
        end

        local relative_coordinates = load_relative_coordinates()
        if relative_coordinates[param] then
            relative_coordinates[param] = nil
            save_relative_coordinates(relative_coordinates)
            return true, "Schematic '" .. param .. "' deleted."
        else
            return false, "Schematic '" .. param .. "' not found."
        end
    end,
})

-------------------
--- Partie Fs ---
-------------------

local function schems_fs(user, itemstack)
    local schematics = get_schematics(schem_dir)
    local category = get_cate(schem_dir)
    
    if #schematics == 0 and #category == 0 then
        minetest.chat_send_player(user:get_player_name(), "No schematic or category found in /brushmatic/")
        return
    end

    -- Récupération des métadonnées actuelles de l'outil
    local meta = itemstack:get_meta()
    local current_schematic = meta:get_string("schematic_name") or ""
    local current_cate = meta:get_string("cate") or ""
    local current_rotation = meta:get_string("rotation")
    local force_placement = meta:get_string("force_placement") == "true" and "true" or "false"
    local relative_coos = meta:get_string("relative_coos") == "true" and "true" or "false"
    local flags = {
        place_center_x = meta:get_string("place_center_x") == "true" and "true" or "false",
        place_center_y = meta:get_string("place_center_y") == "true" and "true" or "false",
        place_center_z = meta:get_string("place_center_z") == "true" and "true" or "false",
    }
  
    local relative_coordinates = load_relative_coordinates()
    local relative_pos = relative_coordinates[current_schematic:match("([^/]+)$")]
    local replace_radius = meta:get_string("replace_radius") == "true" and "true" or "false"
    local radius = tonumber(meta:get_string("radius")) or "5"
    local bloc = meta:get_string("bloc") or ""
    local mod = meta:get_string("mod") == "true" and "true" or "false"
    local replacements = meta:get_string("replacements") == "true" and "true" or "false"
    -- Construction de la formspec
    local formspec = "size[8,9]"
    -- Recup le mod du brush 
    if mod == "false" then
        if #schematics >= 1 then 
            formspec = formspec .. "textlist[0.5,1;7,3;schematic_list;"
            for _, schematic in ipairs(schematics) do
                formspec = formspec .. schematic .. (schematic == current_schematic and " (selected)" or "") .. ","
            end
            formspec = formspec:sub(1, -2) .. "]"
        else 
            formspec = formspec .. "label[0.5,1.5;There is no schematic]"
        end
        formspec = formspec .. "label[0.5,0.5;Select a schematic :]"
        if relative_pos then
            formspec = formspec .. "checkbox[3,5;relative_coos;Use Relative Coordinates;" .. relative_coos .. "]"
        end
    elseif mod == "true" then
        if #category >= 1 then 
            formspec = formspec .. "textlist[0.5,1;7,3;cate_list;"
            for _, cate in ipairs(category) do
                formspec = formspec .. cate .. (cate == current_cate and " (selected)" or "") .. ","
            end
            formspec = formspec:sub(1, -2) .. "]"
            local cate_path = schem_dir .. "/" .. current_cate
            local schems_cate = get_schematics(cate_path)
            if #schems_cate > 0 then 
                local found_relative_pos = false
                for i = 1, #schems_cate do
                    local schematic_name = schems_cate[i]:match("([^/]+)$")
                    local relative_pos = relative_coordinates[schematic_name]
                    if relative_pos then
                        found_relative_pos = true
                        break -- Stop la boucle si un schem possède des pos relatives
                    end
                end
                if found_relative_pos then
                    formspec = formspec .. "checkbox[3,5;relative_coos;Use Relative Coordinates;" .. relative_coos .. "]"
                end
            else
                minetest.chat_send_player(user:get_player_name(), "No schematic found in "..cate.." category")
            end
        else 
            formspec = formspec .. "label[0.5,1.5;There is no category]"
        end
        formspec = formspec .. "label[0.5,0.5;Select a category :]"
    end

    -- Permet de changer de mod 
    formspec = formspec .. "checkbox[3,0.4;mod;Select category;" .. mod .. "]"
    -- Options supplémentaires
    formspec = formspec .. "label[0.5,4.5;Rotation: "..current_rotation.."]"
    formspec = formspec .. "dropdown[0.5,5;2;rotation;0,90,180,270,random;" .. current_rotation .. "]"
    formspec = formspec .. "checkbox[3,4;replacements;Force Placement;" .. replacements .. "]"
    formspec = formspec .. "checkbox[3,4.5;force_placement;Place Air;" .. force_placement .. "]"
    formspec = formspec .. "checkbox[3,5.5;replace_radius;Enable Radius Placement;" .. replace_radius .. "]"
    if replace_radius == "true" then
        formspec = formspec .. "field[3.3,7;1.5,1;radius;Radius:;" .. radius .. "]"
        formspec = formspec .. "field[5.3,7;2.5,1;bloc;Block:;" .. bloc .. "]"
    end

    if (not relative_pos or relative_coos == "false") or mod == "true" then
        formspec = formspec .. "label[0.5,6;Flags:]"
        formspec = formspec .. "checkbox[0.5,6.5;place_center_x;Center X;" .. flags.place_center_x .. "]"
        formspec = formspec .. "checkbox[0.5,7;place_center_y;Center Y;" .. flags.place_center_y .. "]"
        formspec = formspec .. "checkbox[0.5,7.5;place_center_z;Center Z;" .. flags.place_center_z .. "]"
    end
    formspec = formspec .. "button_exit[3,8;2,1;save;Save]"

    minetest.show_formspec(user:get_player_name(), "brushmatic:select_schematic", formspec)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "brushmatic:select_schematic" then
        local itemstack = player:get_wielded_item()
        local meta = itemstack:get_meta()

        if fields.schematic_list then
            local schematics = get_schematics(schem_dir)
            local num = tonumber(fields.schematic_list:match(":(%d+)$"))
            if num and schematics[num] then
                meta:set_string("schematic_name", schematics[num])
                minetest.chat_send_player(player:get_player_name(), "Selected schematic: " .. schematics[num])
                schems_fs(player, itemstack)
            end
        end

        if fields.cate_list then
            local cate = get_cate(schem_dir)
            local num = tonumber(fields.cate_list:match(":(%d+)$"))
            if num and cate[num] then
                meta:set_string("cate", cate[num])
                minetest.chat_send_player(player:get_player_name(), "Selected category : " .. cate[num])
                schems_fs(player, itemstack)
            end
        end

        if fields.mod then
            meta:set_string("mod", fields.mod == "true" and "true" or "false")
            schems_fs(player, itemstack)
        end

        if fields.replacements then
            meta:set_string("replacements", fields.replacements == "true" and "true" or "false")
            schems_fs(player, itemstack)
        end
    
        if fields.save then
            meta:set_string("rotation", fields.rotation)
        end

        local flags = {"place_center_x", "place_center_y", "place_center_z"}

        -- Relative coos
        if fields.relative_coos then 
            meta:set_string("relative_coos", fields.relative_coos == "true" and "true" or "false")  
            schems_fs(player, itemstack)
        end 
        
        if fields.force_placement then
            meta:set_string("force_placement", fields.force_placement == "true" and "true" or "false")
            schems_fs(player, itemstack)
        end
        -- Center
        for _, flag in ipairs(flags) do
            if fields[flag] then
                meta:set_string(flag, fields[flag] == "true" and "true" or "false")
                meta:set_string("relative_coos", "false")
                schems_fs(player, itemstack)
            end
        end
        -- Transforme le brush en Radius Brush
        if fields.replace_radius then
            meta:set_string("replace_radius", fields.replace_radius == "true" and "true" or "false")
            schems_fs(player, itemstack)
        end
        -- Radius du Brush
        if fields.radius then
            meta:set_string("radius", tonumber(fields.radius))
            schems_fs(player, itemstack)
        end

        if fields.bloc then
            meta:set_string("bloc", fields.bloc)
            schems_fs(player, itemstack)
        end
        

        local schematic_name = meta:get_string("schematic_name") or "None"
        local relative_coos = meta:get_string("relative_coos")
        local Force_placement = meta:get_string("force_placement") or "False"
        local description = "Schematic Brush\n" ..
                            "Rotation : " .. meta:get_string("rotation") .. "\n" ..
                            "Force_placement : " .. meta:get_string("force_placement")
        
        if relative_coos == "true" then 
            description = description .. " \nRelative Coordinates : ".. relative_coos
        end
        local mod = meta:get_string("mod") or "false"
        if mod == "true" then
            local cate_name = meta:get_string("cate") or "None"
            description = description .. " \nMode : Category\nName : "..cate_name
        else
            local schematic_name = meta:get_string("schematic_name") or "None"
            description = description .. " \nMode : Schematic\nName : "..schematic_name
        end
        meta:set_string("description", description)
        -- Sauvegarde l'item mis à jour
        
        player:set_wielded_item(itemstack)
        minetest.chat_send_player(player:get_player_name(), "Brush updated!")
    end
end)

-------------------
--- Le Brush ---
-------------------

minetest.register_tool("brushmatic:brush", {
    description = "Schematic Brush",
    inventory_image = "brushmatic_brush.png",
    range = 128,
    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing.type == "node" then
            local pos = pointed_thing.above
            local meta = itemstack:get_meta()
            local schematic_name = meta:get_string("schematic_name")
            local rotation = meta:get_string("rotation") or "0"
            local relative_coos = meta:get_string("relative_coos")
            local force_placement = meta:get_string("force_placement") == "true"
            local flags = {
                place_center_x = meta:get_string("place_center_x") == "true",
                place_center_y = meta:get_string("place_center_y") == "true",
                place_center_z = meta:get_string("place_center_z") == "true",
            }
            local replace_radius = meta:get_string("replace_radius")
            local radius = tonumber(meta:get_string("radius") or "5") 
            local bloc = meta:get_string("bloc")
            local mod = meta:get_string("mod")
            local cate = meta:get_string("cate") or "None"
            local replacements = meta:get_string("replacements") or "true"

            if schematic_name == "" and mod ~= "true" then
                minetest.chat_send_player(user:get_player_name(), "No schematic selected.")
                return itemstack
            end

            local relative_coordinates = load_relative_coordinates()
            local relative_pos = relative_coordinates[schematic_name:match("([^/]+)$")]
            local schematic_path = schem_dir .."/" .. schematic_name .. ".mts"
            local message_ok = "Schematic '" .. schematic_name .. "' placed."

            if replace_radius and replace_radius == "true" then
                local success, message = place_schematic_on_blocks_in_zone(schematic_name, pos, radius, bloc, force_placement, rotation, flags, relative_coos, mod, cate, replacements)
                if not success then
                    minetest.chat_send_player(user:get_player_name(), "Error: " .. message)
                else
                    minetest.chat_send_player(user:get_player_name(), message)
                end
                return
            end

            if mod == "true" then 
                local cate_path = schem_dir .. "/" .. cate
                local category_schems = get_schematics(cate_path)
                if #category_schems > 0 then
                    schematic_name = category_schems[math.random(#category_schems)]
                    schematic_path = cate_path .. "/" .. schematic_name .. ".mts"
                    relative_pos = relative_coordinates[schematic_name]
                    minetest.chat_send_player(user:get_player_name(), "schem with relative cos "..schematic_name)
                else
                    minetest.chat_send_player(user:get_player_name(), "No schematics found in category: " .. cate)
                    return itemstack
                end
            end

            if relative_pos and relative_coos == "true" then
                local placement_pos = {
                    x = pos.x - relative_pos.x,
                    y = pos.y - relative_pos.y,
                    z = pos.z - relative_pos.z,
                }
                pos = placement_pos
                rotation = "0"
                flags = "false"
                message_ok = message_ok .. " With relatives coordinates."
            end

            if replacements == "true" then 
                local success, message = place_custom_schematic(pos, schematic_path, flags, rotation)
                if not success then
                    minetest.chat_send_player(user:get_player_name(), "Error: " .. message)
                else
                    minetest.chat_send_player(user:get_player_name(), message)
                end
                return
            else
                replacements = nil
            end
            minetest.place_schematic(pos, schematic_path, rotation, nil, force_placement, flags, replacements)
            minetest.chat_send_player(user:get_player_name(), message_ok)
        end
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        schems_fs(user, itemstack)
    end
})

-- Fonction pour suprimer les schematics temporaires
minetest.register_on_shutdown(function()
    local files = minetest.get_dir_list(temps_schems_path, false)
    for _, file in ipairs(files) do
        os.remove(temps_schems_path .. "/" .. file)
    end
    minetest.log("action", "Tous les schémas temporaires ont été supprimés.")
end)