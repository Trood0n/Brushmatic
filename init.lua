
local modpath = minetest.get_modpath("brushmatic")
dofile(modpath .. "/brush.lua")

--[[
local function place_schematic_on_blocks(schematic_path, positions, force_placement, rotation, centralization, replacements)
    for _, pos in ipairs(positions) do
        local schematic_pos = {
            x = pos.x,
            y = pos.y,
            z = pos.z
        }
        minetest.place_schematic(schematic_pos, schematic_path, rotation, replacements, force_placement, centralization)
    end
end

-- Command for test 
minetest.register_chatcommand("pschemecenter", {
    params = "<schematic_path> <target_node> <force_placement> <rotation> <centralization>",
    description = "Place schematics on specified target nodes. This command is deprecated",
    privs = {server = true},
    func = function(name, param)
        local args = param:split(" ")
        if #args > 5 then
            return false, "Usage: /pschemecenter <schematic_path> <target_node> <force_placement> <rotation> <centralization>"
        end
        -- Area of the selection
        local area_start = worldedit.pos1[name]
        local area_end = worldedit.pos2[name]
        --Path to the schematic
        local schematic_path = minetest.get_worldpath() .. "/schems/" .. args[1]
        -- Target Node
        if area_start ~= nil and area_end ~= nil then
            if args[2] == nil then
                 minetest.place_schematic(area_start, schematic_path, "0", nil, false, "place_center_x,place_center_z")
                return true, "The schematic "..args[1].." has been placed correctly"
            end
            local target_node = args[2]
            local target_positions = minetest.find_nodes_in_area(area_start, area_end, target_node)
            if #target_positions == 0 then
                return false, "No target nodes found in the area."
            end
            -- If replace all blocs 
            local force_placement = false
            if args[3] ~= nil then
                if args[3] == "y" then
                    force_placement = true
                elseif args[3] ~= "n" then 
                    return false, "Force_placement can equal y or n"
                end 
            end
            -- Rotation of the schem
            local rotation = "0"
            if args[4] ~= nil then 
                if args[4] ~= "0" and args[4] ~= "90" and args[4] ~= "180" and args[4] ~= "270" and args[4] ~= "random" then 
                    return false, "Rotation can equal \"0\" or \"90\" or \"180\" or \"270\" or \"random\""
                end
                rotation = args[4] 
            end
            -- Centralisation 
            local centralization = "place_center_x,place_center_z"
            if args[5] ~= nil then
                local valid_centralization = {
                    x = "place_center_x",
                    y = "place_center_y",
                    z = "place_center_z",
                }
                local selected_axes = {}
                -- Find "xyz" characters
                for axis in args[5]:gmatch(".") do
                    if valid_centralization[axis] then
                        table.insert(selected_axes, valid_centralization[axis])
                    end
                end
                -- Make a table 
                if #selected_axes > 0 then
                    centralization = table.concat(selected_axes, ",")
                end
            end 
            -- Place schematic
            place_schematic_on_blocks(schematic_path, target_positions, force_placement, rotation, centralization)
            -- Message 
            return true, "The schematic has been placed "..tostring(#target_positions).." times"
        else
            return false, "No area selected"
        end
    end,
})
]]--