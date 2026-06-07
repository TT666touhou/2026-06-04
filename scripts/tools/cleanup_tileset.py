import os

def main():
    tres_path = r'assets/tilesets/mrmotext/mrmotext_world_tileset.tres'
    if not os.path.exists(tres_path):
        print(f"Error: {tres_path} not found.")
        return

    with open(tres_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    new_lines = []
    
    # 1. Keep the gd_resource header (line 0)
    new_lines.append(lines[0])
    new_lines.append('\n')

    # 2. Find and keep only the original MRMOTEXT_EX.png ext_resource (usually id "1_61lvi")
    found_ext = False
    for line in lines:
        if '[ext_resource' in line and 'id="1_61lvi"' in line:
            new_lines.append(line)
            found_ext = True
            break
    if not found_ext:
        # fallback search
        for line in lines:
            if '[ext_resource' in line and 'MRMOTEXT_EX.png' in line:
                new_lines.append(line)
                break
    new_lines.append('\n')

    # 3. Find and keep the sub_resource for source 0 (starts at line 38, ends before the next sub_resource at 2088)
    # Let's locate the line numbers dynamically in case they shifted
    start_idx = -1
    end_idx = -1
    for i, line in enumerate(lines):
        if '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_c36ag"]' in line:
            start_idx = i
        elif start_idx != -1 and '[sub_resource' in line and i > start_idx:
            end_idx = i
            break

    if start_idx == -1:
        print("Error: Could not locate source 0 sub_resource.")
        return
        
    if end_idx == -1:
        # If there are no other sub_resources, it goes until the [resource] section
        for i, line in enumerate(lines):
            if i > start_idx and '[resource]' in line:
                end_idx = i
                break

    print(f"Keeping source 0 sub_resource from line {start_idx} to {end_idx}")
    for idx in range(start_idx, end_idx):
        new_lines.append(lines[idx])
    new_lines.append('\n')

    # 4. Add the clean [resource] section at the end
    new_lines.append('[resource]\n')
    new_lines.append('tile_size = Vector2i(8, 8)\n')
    new_lines.append('sources/0 = SubResource("TileSetAtlasSource_c36ag")\n')

    with open(tres_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    print("Successfully cleaned up tileset resource file.")

if __name__ == '__main__':
    main()
