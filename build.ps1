rojo build --output KillerJeon.rbxlx default.project.json
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

python tools/fix_workspace.py KillerJeon.rbxlx
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
