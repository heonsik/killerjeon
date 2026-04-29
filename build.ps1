python tools/expand_static_world.py
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$rojo = [string](Get-Command rojo.exe).Source
cmd /d /c "`"$rojo`" build --output KillerJeon.rbxlx default.project.json"
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

python tools/fix_workspace.py KillerJeon.rbxlx
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
