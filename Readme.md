# SchematicBrush

A powerful tool for easily placing, editing, and manipulating schematics in Minetest.

## Features
- Place schematics in your world with precision.
- Edit and manipulate existing structures.
- Simple and intuitive commands.

## Installation
1. Download the mod.
2. Place the folder in your Minetest `mods` directory.
3. Enable the mod in your world.

## Commands
| Command                                       | Description                                                                             |
|-----------------------------------------------|-----------------------------------------------------------------------------------------|
| `/create_scheme <schematic_name> <category>`  | Create a schematic in .mts format with or without relatives coors.                      |
| `/delete_scheme <schematic_name>`             | Deletes the relative coordinates of the schematic in the relative_coordinates.txt file. |


## Forms
### Options Description

This interface allows you to configure the behavior of the **Brush** to manipulate and place schematics in Minetest.

| **Option**                     | **Description**                                                                                                                                                   |
|--------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Textlist**                   | Allows you to choose from different schematics or categories if the "Select Category" option is enabled.                                                          |
| **Select Category (Checkbox)** | If enabled, selects an entire category: when using the brush, a random schematic from the selected category will be placed.                                        |
| **Rotation**                   | Sets the schematic's rotation from the following options: `0`, `90`, `180`, `270`, or `Random` (random rotation).                                                |
| **Flags (Center X / Y / Z)**   | Centers the schematic along the X, Y, or Z axes for precise placement.                                                                                           |
| **Force Placement**            | Places all blocks of the schematic, even if they replace non-air blocks (except for air blocks if "Place Air" is not enabled).                                    |
| **Place Air**                  | Includes air blocks when placing the schematic. **Note**: There is no need to enable both "Force Placement" and "Place Air"; enabling "Force Placement" alone has the same effect. |
| **Use Relative Coordinates**   | Places the third WordEdit point saved on the selected block. This option takes priority over flags. When selecting a category, schematics with relative coordinates will use them, while others will rely on flags. |
| **Enable Radius Placement**    | Allows the schematic (or schematics in the case of a category) to be placed on all positions defined by the specified radius.                                     |
| **Radius**                     | Sets the placement radius (max 50, adjustable in `brush.lua`).                                                                                                    |
| **Block**                      | Specifies the block on which schematics will be placed. Only one block can be selected at a time.                                                                |

---

### Example Usage

#### **Place a schematic with random rotation:**
1. Select a schematic from the list.
2. Set the rotation to "Random."
3. Enable or disable the flags as needed (e.g., "Center X").
4. Click "Save" and use the brush to place the schematic.

#### **Place a category with a radius:**
1. Check the "Select Category" option.
2. Choose a category from the list.
3. Enable "Enable Radius Placement" and set a radius (e.g., `10`).
4. Select a target block and click "Save."

---

### Visual Preview

For a detailed demonstration, watch the test video available on [YouTube](https://youtu.be/g81tZ-pUc6I).

---

## Thanks 
Thanks to [Atlante](https://github.com/Atlante1952) for the brush texture 

---