from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / "src" / "Workspace" / "Map.rbxmx"
SPAWNS_PATH = ROOT / "src" / "Workspace" / "Spawns.rbxmx"
ITEMS_PATH = ROOT / "src" / "Workspace" / "Items.rbxmx"

BEGIN_MARK = "<!-- BEGIN_EXPANDED_STATIC_WORLD -->"
END_MARK = "<!-- END_EXPANDED_STATIC_WORLD -->"


def find_matching_item_end(text: str, start: int) -> int:
    depth = 0
    position = start

    while position < len(text):
        next_open = text.find("<Item ", position)
        next_close = text.find("</Item>", position)
        if next_close == -1:
            raise RuntimeError("Could not find matching </Item>")

        if next_open != -1 and next_open < next_close:
            depth += 1
            position = next_open + len("<Item ")
        else:
            depth -= 1
            position = next_close + len("</Item>")
            if depth == 0:
                return position

    raise RuntimeError("Could not find matching item end")


def get_named_part_block(text: str, name: str) -> tuple[int, int, str]:
    name_marker = f'<string name="Name">{name}</string>'
    name_at = text.find(name_marker)
    if name_at == -1:
        raise RuntimeError(f"Part not found: {name}")

    start = text.rfind('<Item class="Part"', 0, name_at)
    if start == -1:
        raise RuntimeError(f"Part start not found: {name}")

    end = find_matching_item_end(text, start)
    return start, end, text[start:end]


def replace_tag_value(block: str, parent_tag: str, child_tag: str, value: float) -> str:
    pattern = rf'(<{parent_tag}[^>]*>.*?<{child_tag}>)(.*?)(</{child_tag}>.*?</{parent_tag}>)'
    replacement = rf'\g<1>{value:g}\g<3>'
    return re.sub(pattern, replacement, block, count=1, flags=re.S)


def set_part_transform(text: str, name: str, position=None, size=None) -> str:
    start, end, block = get_named_part_block(text, name)
    if position is not None:
        x, y, z = position
        block = replace_tag_value(block, "CoordinateFrame", "X", x)
        block = replace_tag_value(block, "CoordinateFrame", "Y", y)
        block = replace_tag_value(block, "CoordinateFrame", "Z", z)
    if size is not None:
        x, y, z = size
        block = replace_tag_value(block, "Vector3", "X", x)
        block = replace_tag_value(block, "Vector3", "Y", y)
        block = replace_tag_value(block, "Vector3", "Z", z)
    return text[:start] + block + text[end:]


def strip_generated(text: str) -> str:
    start = text.find(BEGIN_MARK)
    end = text.find(END_MARK)
    if start == -1 or end == -1:
        return text
    end += len(END_MARK)
    return text[:start] + text[end:]


def color_xml(color: tuple[float, float, float]) -> str:
    r, g, b = color
    return f"<Color3 name=\"Color\"><R>{r}</R><G>{g}</G><B>{b}</B></Color3>"


def part_xml(ref_id: int, name: str, position, size, color, collide=True, transparency=0.0) -> str:
    px, py, pz = position
    sx, sy, sz = size
    return f"""    <Item class="Part" referent="{ref_id}">
      <Properties>
        <bool name="Anchored">true</bool>
        <bool name="CanCollide">{str(collide).lower()}</bool>
        <float name="Transparency">{transparency}</float>
        {color_xml(color)}
        <CoordinateFrame name="CFrame"><X>{px}</X><Y>{py}</Y><Z>{pz}</Z><R00>1.0</R00><R01>0.0</R01><R02>0.0</R02><R10>0</R10><R11>1.0</R11><R12>-0.0</R12><R20>-0.0</R20><R21>0.0</R21><R22>1.0</R22></CoordinateFrame>
        <string name="Name">{name}</string>
        <Vector3 name="Size"><X>{sx}</X><Y>{sy}</Y><Z>{sz}</Z></Vector3>
      </Properties>
    </Item>"""


def insert_before_folder_close(text: str, generated: str) -> str:
    text = strip_generated(text)
    insert_at = text.rfind("  </Item>")
    if insert_at == -1:
        raise RuntimeError("Could not find folder close")
    return text[:insert_at] + f"  {BEGIN_MARK}\n{generated}\n  {END_MARK}\n" + text[insert_at:]


def expand_map() -> None:
    text = MAP_PATH.read_text(encoding="utf-8")
    text = set_part_transform(text, "RoomFloor", size=(1700, 2, 1700))
    text = set_part_transform(text, "NorthWall", position=(0, 21, -850), size=(1704, 42, 4))
    text = set_part_transform(text, "SouthWall", position=(0, 21, 850), size=(1704, 42, 4))
    text = set_part_transform(text, "WestWall", position=(-850, 21, 0), size=(4, 42, 1704))
    text = set_part_transform(text, "EastWall", position=(850, 21, 0), size=(4, 42, 1704))
    text = set_part_transform(text, "CenterRunwayX", size=(1640, 0.25, 4))
    text = set_part_transform(text, "CenterRunwayZ", size=(4, 0.25, 1640))

    parts = []
    ref_id = 900000
    districts = [
        ("NW", -560, -560, (1.0, 0.368627, 0.431373)),
        ("NE", 560, -560, (0.270588, 0.788235, 1.0)),
        ("SW", -560, 560, (0.372549, 0.929412, 0.545098)),
        ("SE", 560, 560, (1.0, 0.843137, 0.290196)),
        ("N", 0, -705, (0.698039, 0.490196, 1.0)),
        ("S", 0, 705, (1.0, 0.529412, 0.329412)),
        ("W", -705, 0, (0.360784, 1.0, 0.729412)),
        ("E", 705, 0, (1.0, 0.345098, 0.462745)),
    ]

    for index, (key, cx, cz, accent) in enumerate(districts, start=1):
        for name, pos, size, color, collide, transparency in [
            (f"OuterRunwayX{key}", (cx, 1.3, cz), (260, 0.35, 5), accent, False, 0.05),
            (f"OuterRunwayZ{key}", (cx, 1.34, cz), (5, 0.35, 260), accent, False, 0.05),
            (f"OuterTower{key}", (cx, 35, cz), (34, 70, 34), (0.164706, 0.188235, 0.25098), True, 0),
            (f"OuterTowerGlow{key}", (cx, 72, cz), (38, 4, 38), accent, False, 0.03),
            (f"OuterCoverA{key}", (cx - 110, 9, cz - 70), (100, 18, 24), (0.411765, 0.298039, 0.203922), True, 0),
            (f"OuterCoverB{key}", (cx + 110, 9, cz + 70), (24, 18, 100), (0.411765, 0.298039, 0.203922), True, 0),
            (f"OuterCoverC{key}", (cx + 92, 7, cz - 118), (86, 14, 24), (0.282353, 0.431373, 0.772549), True, 0),
            (f"OuterCoverD{key}", (cx - 92, 7, cz + 118), (24, 14, 86), (0.921569, 0.454902, 0.341176), True, 0),
        ]:
            parts.append(part_xml(ref_id, name, pos, size, color, collide, transparency))
            ref_id += 1

        crate_offsets = [(-120, -20), (-72, 112), (22, -126), (118, 38), (-18, 76), (82, -82)]
        for crate, (ox, oz) in enumerate(crate_offsets, start=1):
            parts.append(part_xml(ref_id, f"OuterCrate{key}{crate}", (cx + ox, 5, cz + oz), (18, 10, 18), (0.623529, 0.443137, 0.290196), True, 0))
            ref_id += 1

    for x in (-420, 420):
        parts.append(part_xml(ref_id, f"LongBridgeX{x}", (x, 18, 0), (260, 5, 18), (0.321569, 0.345098, 0.411765), True, 0))
        ref_id += 1
        parts.append(part_xml(ref_id, f"LongBridgeGlowX{x}", (x, 21, 0), (260, 1, 3), (1.0, 0.843137, 0.290196), False, 0.05))
        ref_id += 1

    for z in (-420, 420):
        parts.append(part_xml(ref_id, f"LongBridgeZ{z}", (0, 18, z), (18, 5, 260), (0.321569, 0.345098, 0.411765), True, 0))
        ref_id += 1
        parts.append(part_xml(ref_id, f"LongBridgeGlowZ{z}", (0, 21, z), (3, 1, 260), (0.270588, 0.788235, 1.0), False, 0.05))
        ref_id += 1

    dense_zones = [
        ("ArcadeNorth", 0, -610, (0.698039, 0.490196, 1.0), (0.270588, 0.788235, 1.0), False),
        ("ToyTownSouth", 0, 610, (1.0, 0.843137, 0.290196), (1.0, 0.368627, 0.431373), True),
        ("LibraryWest", -610, 0, (0.509804, 0.360784, 0.227451), (0.360784, 1.0, 0.729412), False),
        ("FactoryEast", 610, 0, (0.321569, 0.345098, 0.411765), (1.0, 0.345098, 0.462745), True),
    ]

    for zone_index, (name, cx, cz, primary, accent, rotate) in enumerate(dense_zones, start=1):
        for row in range(-2, 3):
            for column in range(-2, 3):
                if abs(row) != 2 or abs(column) != 2:
                    x_offset = row * 48 if rotate else column * 48
                    z_offset = column * 48 if rotate else row * 48
                    height = 18 + ((row + column + zone_index) % 3) * 8
                    parts.append(part_xml(ref_id, f"{name}Block{row}_{column}", (cx + x_offset, height / 2, cz + z_offset), (30, height, 30), primary, True, 0))
                    ref_id += 1
                    parts.append(part_xml(ref_id, f"{name}BlockGlow{row}_{column}", (cx + x_offset, height + 1.2, cz + z_offset), (32, 1, 4), accent, False, 0.04))
                    ref_id += 1

        for i in range(1, 8):
            offset = -180 + (i - 1) * 60
            if rotate:
                parts.append(part_xml(ref_id, f"{name}LongCoverA{i}", (cx + offset, 9, cz - 165), (22, 18, 72), (0.180392, 0.211765, 0.27451), True, 0))
                ref_id += 1
                parts.append(part_xml(ref_id, f"{name}LongCoverB{i}", (cx + offset, 9, cz + 165), (22, 18, 72), (0.180392, 0.211765, 0.27451), True, 0))
                ref_id += 1
                parts.append(part_xml(ref_id, f"{name}FloorStripe{i}", (cx + offset, 1.45, cz), (8, 0.4, 310), accent, False, 0.07))
                ref_id += 1
            else:
                parts.append(part_xml(ref_id, f"{name}LongCoverA{i}", (cx - 165, 9, cz + offset), (72, 18, 22), (0.180392, 0.211765, 0.27451), True, 0))
                ref_id += 1
                parts.append(part_xml(ref_id, f"{name}LongCoverB{i}", (cx + 165, 9, cz + offset), (72, 18, 22), (0.180392, 0.211765, 0.27451), True, 0))
                ref_id += 1
                parts.append(part_xml(ref_id, f"{name}FloorStripe{i}", (cx, 1.45, cz + offset), (310, 0.4, 8), accent, False, 0.07))
                ref_id += 1

        pillar_points = [
            (225, 0), (191, 117), (83, 256), (-83, 256), (-191, 117),
            (-225, 0), (-191, -117), (-83, -256), (83, -256), (191, -117),
        ]
        for i, (ox, oz) in enumerate(pillar_points, start=1):
            height = 42 if i % 3 == 0 else 28
            parts.append(part_xml(ref_id, f"{name}Pillar{i}", (cx + ox, height / 2, cz + oz), (16, height, 16), (0.12549, 0.14902, 0.203922), True, 0))
            ref_id += 1
            parts.append(part_xml(ref_id, f"{name}PillarCap{i}", (cx + ox, height + 1.5, cz + oz), (20, 3, 20), accent, False, 0.03))
            ref_id += 1

    for i, x in enumerate((-720, -480, -240, 240, 480, 720), start=1):
        parts.append(part_xml(ref_id, f"NorthSouthConnectorWallA{i}", (x, 13, -285), (34, 26, 110), (0.219608, 0.25098, 0.321569), True, 0))
        ref_id += 1
        parts.append(part_xml(ref_id, f"NorthSouthConnectorWallB{i}", (x, 13, 285), (34, 26, 110), (0.219608, 0.25098, 0.321569), True, 0))
        ref_id += 1
        parts.append(part_xml(ref_id, f"ConnectorBeaconNS{i}", (x, 29, -285), (20, 4, 20), (1.0, 0.843137, 0.290196), False, 0.03))
        ref_id += 1

    for i, z in enumerate((-720, -480, -240, 240, 480, 720), start=1):
        parts.append(part_xml(ref_id, f"EastWestConnectorWallA{i}", (-285, 13, z), (110, 26, 34), (0.219608, 0.25098, 0.321569), True, 0))
        ref_id += 1
        parts.append(part_xml(ref_id, f"EastWestConnectorWallB{i}", (285, 13, z), (110, 26, 34), (0.219608, 0.25098, 0.321569), True, 0))
        ref_id += 1
        parts.append(part_xml(ref_id, f"ConnectorBeaconEW{i}", (-285, 29, z), (20, 4, 20), (0.270588, 0.788235, 1.0), False, 0.03))
        ref_id += 1

    MAP_PATH.write_text(insert_before_folder_close(text, "\n".join(parts)), encoding="utf-8")


def expand_spawns() -> None:
    text = SPAWNS_PATH.read_text(encoding="utf-8")
    text = set_part_transform(text, "GameSpawn", position=(-780, 5, -780))
    text = set_part_transform(text, "ChaserSpawn", position=(780, 5, 780))
    SPAWNS_PATH.write_text(text, encoding="utf-8")


def expand_items() -> None:
    text = ITEMS_PATH.read_text(encoding="utf-8")
    parts = []
    ref_id = 910000
    item_specs = [
        ("SpeedPotion7", (-620, 5, -520), (4, 4, 4), (0.14902, 0.854902, 1.0)),
        ("SpeedPotion8", (620, 5, 520), (4, 4, 4), (0.14902, 0.854902, 1.0)),
        ("SpeedPotion9", (0, 5, -705), (4, 4, 4), (0.14902, 0.854902, 1.0)),
        ("SpeedPotion10", (0, 5, 705), (4, 4, 4), (0.14902, 0.854902, 1.0)),
        ("ShieldOrb3", (-705, 5, 0), (4.5, 4.5, 4.5), (0.360784, 1.0, 0.729412)),
        ("ShieldOrb4", (705, 5, 0), (4.5, 4.5, 4.5), (0.360784, 1.0, 0.729412)),
        ("DecoyBeacon3", (-560, 5, 560), (4.5, 4.5, 4.5), (0.698039, 0.490196, 1.0)),
        ("DecoyBeacon4", (560, 5, -560), (4.5, 4.5, 4.5), (0.698039, 0.490196, 1.0)),
        ("ShockOrb3", (-520, 5, -620), (4.5, 4.5, 4.5), (1.0, 0.878431, 0.360784)),
        ("ShockOrb4", (520, 5, 620), (4.5, 4.5, 4.5), (1.0, 0.878431, 0.360784)),
        ("EnergyCore1", (-560, 75, -560), (5.5, 5.5, 5.5), (1.0, 0.345098, 0.462745)),
        ("EnergyCore3", (560, 75, 560), (5.5, 5.5, 5.5), (1.0, 0.345098, 0.462745)),
        ("EnergyCore4", (0, 75, -705), (5.5, 5.5, 5.5), (1.0, 0.345098, 0.462745)),
        ("EnergyCore5", (0, 75, 705), (5.5, 5.5, 5.5), (1.0, 0.345098, 0.462745)),
    ]

    text = strip_generated(text)
    text = set_part_transform(text, "EnergyCore1", position=(-560, 75, -560))
    text = set_part_transform(text, "EnergyCore3", position=(560, 75, 560))

    for name, position, size, color in item_specs:
        if f'<string name="Name">{name}</string>' in text:
            continue
        parts.append(part_xml(ref_id, name, position, size, color, False, 0))
        ref_id += 1

    ITEMS_PATH.write_text(insert_before_folder_close(text, "\n".join(parts)), encoding="utf-8")


def main() -> int:
    expand_map()
    expand_spawns()
    expand_items()
    print("EXPANDED_STATIC_WORLD_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
