from pathlib import Path
import re
import sys
import math


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


def split_workspace_block(block: str) -> tuple[str, str]:
    properties_end = block.find("</Properties>")
    if properties_end == -1:
        raise RuntimeError("Workspace block has no Properties")

    properties_end += len("</Properties>")
    children_start = properties_end
    children_end = block.rfind("</Item>")
    if children_end == -1:
        raise RuntimeError("Workspace block has no closing Item")

    return block[:children_start], block[children_start:children_end]


def cframe_xml(name: str, position: tuple[float, float, float], target: tuple[float, float, float]) -> str:
    px, py, pz = position
    tx, ty, tz = target

    back = (px - tx, py - ty, pz - tz)
    back_len = math.sqrt(sum(component * component for component in back))
    back = tuple(component / back_len for component in back)

    world_up = (0.0, 1.0, 0.0)
    right = (
        world_up[1] * back[2] - world_up[2] * back[1],
        world_up[2] * back[0] - world_up[0] * back[2],
        world_up[0] * back[1] - world_up[1] * back[0],
    )
    right_len = math.sqrt(sum(component * component for component in right))
    right = tuple(component / right_len for component in right)

    up = (
        back[1] * right[2] - back[2] * right[1],
        back[2] * right[0] - back[0] * right[2],
        back[0] * right[1] - back[1] * right[0],
    )

    return f"""
			<CoordinateFrame name="{name}">
				<X>{px}</X><Y>{py}</Y><Z>{pz}</Z>
				<R00>{right[0]}</R00><R01>{up[0]}</R01><R02>{back[0]}</R02>
				<R10>{right[1]}</R10><R11>{up[1]}</R11><R12>{back[1]}</R12>
				<R20>{right[2]}</R20><R21>{up[2]}</R21><R22>{back[2]}</R22>
			</CoordinateFrame>"""


def editor_camera_xml() -> tuple[str, str]:
    camera_ref = "KILLERJEON_EDITOR_CAMERA"
    cframe = cframe_xml("CFrame", (1250, 850, 1250), (0, 0, 0))
    focus = cframe_xml("Focus", (0, 0, 0), (0, 0, -1))
    camera = f"""
		<Item class="Camera" referent="{camera_ref}">
			<Properties>
{cframe}
				<Ref name="CameraSubject">null</Ref>
				<token name="CameraType">0</token>
				<float name="FieldOfView">70</float>
				<token name="FieldOfViewMode">0</token>
{focus}
				<bool name="HeadLocked">true</bool>
				<float name="HeadScale">1</float>
				<bool name="VRTiltAndRollEnabled">false</bool>
				<string name="Name">Camera</string>
			</Properties>
		</Item>"""
    return camera_ref, camera


def ensure_editor_camera(workspace_block: str) -> str:
    if '<Item class="Camera"' in workspace_block:
        return workspace_block

    camera_ref, camera = editor_camera_xml()
    properties_end = workspace_block.find("</Properties>")
    if properties_end == -1:
        return workspace_block

    if '<Ref name="CurrentCamera">' not in workspace_block[:properties_end]:
        workspace_block = (
            workspace_block[:properties_end]
            + f'\n      <Ref name="CurrentCamera">{camera_ref}</Ref>\n    '
            + workspace_block[properties_end:]
        )

    insert_at = workspace_block.find("</Properties>") + len("</Properties>")
    return workspace_block[:insert_at] + camera + workspace_block[insert_at:]


def move_workspace_near_top(text: str) -> str:
    workspace_start = text.find('<Item class="Workspace"')
    if workspace_start == -1:
        return text

    workspace_end = find_matching_item_end(text, workspace_start)
    workspace_block = text[workspace_start:workspace_end]

    # Put Workspace near the top so Roblox Studio opens into the editable world
    # instead of starting from other services and the default sky view.
    external_marker = "<External>nil</External>"
    insert_at = text.find(external_marker)
    if insert_at != -1:
        insert_at += len(external_marker)
    else:
        roblox_header_end = text.find(">")
        if roblox_header_end == -1:
            return text
        insert_at = roblox_header_end + 1

    without_workspace = text[:workspace_start] + text[workspace_end:]
    if workspace_start < insert_at:
        insert_at -= workspace_end - workspace_start

    return without_workspace[:insert_at] + "\n\t" + workspace_block + without_workspace[insert_at:]


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: fix_workspace.py <place.rbxlx>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    text = path.read_text(encoding="utf-8")

    starts = [match.start() for match in re.finditer(r'<Item class="Workspace"', text)]
    if len(starts) >= 2:
        first_start = starts[0]
        first_end = find_matching_item_end(text, first_start)
        second_start = starts[1]
        second_end = find_matching_item_end(text, second_start)

        first_block = text[first_start:first_end]
        second_block = text[second_start:second_end]

        first_head, first_children = split_workspace_block(first_block)
        _, second_children = split_workspace_block(second_block)

        merged_first = first_head + first_children + second_children + "\n\t</Item>"
        text = text[:first_start] + merged_first + text[first_end:second_start] + text[second_end:]

    workspace_start = text.find('<Item class="Workspace"')
    if workspace_start != -1:
        workspace_end = find_matching_item_end(text, workspace_start)
        workspace_block = ensure_editor_camera(text[workspace_start:workspace_end])
        text = text[:workspace_start] + workspace_block + text[workspace_end:]

    text = move_workspace_near_top(text)
    path.write_text(text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
