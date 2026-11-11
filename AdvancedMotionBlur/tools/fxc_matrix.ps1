# Compile the three effects with FXC (fx_2_0) across the Settings.fxh switch
# combinations. Every case starts from src/Settings.fxh with MB_DEBUG forced to
# 0, so a debug view left on locally does not hide the full shader.
#
#   pwsh tools/fxc_matrix.ps1 [-Src src] [-Work <temp dir>]
#
# FXC uses D3DCompiler_47. MME compiles with d3dx9_43, which is slower and
# stricter; check load time with tools/d3dx_compile_time.py on <Work>/default.
# MME's `_INDEX` vertex semantic is unknown to FXC, so the copies use TEXCOORD7.
param(
    [string]$Src = (Join-Path $PSScriptRoot '..\src'),
    [string]$Work = (Join-Path ([IO.Path]::GetTempPath()) 'amb-fxc-matrix')
)
$fxc = 'C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\fxc.exe'
$settings = Get-Content (Join-Path $Src 'Settings.fxh') -Raw
$settings = [regex]::Replace($settings, '(?m)^#define MB_DEBUG\s+\S+', '#define MB_DEBUG 0')
$cases = @(
    @{ Name = 'default'; Set = @{} },
    @{ Name = 'q0'; Set = @{ MB_QUALITY = '0' } },
    @{ Name = 'q2'; Set = @{ MB_QUALITY = '2' } },
    @{ Name = 'q3'; Set = @{ MB_QUALITY = '3' } },
    @{ Name = 'q3p0'; Set = @{ MB_QUALITY = '3'; MB_EXTEND_FOREGROUND = '0' } },
    @{ Name = 'edge0'; Set = @{ MB_EDGE_BACKGROUND = '0' } },
    @{ Name = 'edge0q3'; Set = @{ MB_EDGE_BACKGROUND = '0'; MB_QUALITY = '3' } },
    @{ Name = 'edgep0'; Set = @{ MB_EXTEND_FOREGROUND = '0' } },
    @{ Name = 'spread0'; Set = @{ MB_TRAIL_SPREAD = '0.0' } },
    @{ Name = 'linear0'; Set = @{ MB_LINEAR_COLOR = '0' } },
    @{ Name = 'search1'; Set = @{ MB_OUTLINE_SEARCH = '1' } },
    @{ Name = 'search5'; Set = @{ MB_OUTLINE_SEARCH = '5' } },
    @{ Name = 'fringe0'; Set = @{ MB_OUTLINE_FRINGE = '0' } },
    @{ Name = 'linear0p0'; Set = @{ MB_LINEAR_COLOR = '0'; MB_EXTEND_FOREGROUND = '0' } },
    @{ Name = 'dbg1'; Set = @{ MB_DEBUG = '1' } },
    @{ Name = 'dbg2'; Set = @{ MB_DEBUG = '2' } },
    @{ Name = 'dbg3'; Set = @{ MB_DEBUG = '3' } },
    @{ Name = 'dbg4'; Set = @{ MB_DEBUG = '4' } },
    @{ Name = 'dbg5'; Set = @{ MB_DEBUG = '5' } },
    @{ Name = 'p0'; Set = @{ MB_EXTEND_FOREGROUND = '0' } },
    @{ Name = 'nooutline'; Set = @{ MB_OUTLINE_MOTION = '0' } },
    @{ Name = 'noauto'; Set = @{ MB_AUTO_MODEL_MOTION = '0' } },
    @{ Name = 'nocutprobe'; Set = @{ MB_CUT_SCREEN_HEIGHT = '0.0' } },
    @{ Name = 'layered'; Set = @{ MB_LAYERED_TRAIL = '1' } },
    @{ Name = 'worldhistory'; Set = @{ MB_KEEP_OBJECT_MOTION_ON_CUT = '1' } },
    @{ Name = 'worldp0'; Set = @{ MB_KEEP_OBJECT_MOTION_ON_CUT = '1'; MB_EXTEND_FOREGROUND = '0' } },
    @{ Name = 'worlddbg2'; Set = @{ MB_KEEP_OBJECT_MOTION_ON_CUT = '1'; MB_DEBUG = '2' } },
    @{ Name = 'worldlayered'; Set = @{ MB_KEEP_OBJECT_MOTION_ON_CUT = '1'; MB_LAYERED_TRAIL = '1' } },
    @{ Name = 'worldnoteleport'; Set = @{ MB_KEEP_OBJECT_MOTION_ON_CUT = '1'; MB_TELEPORT_DISTANCE = '0.0' } },
    @{ Name = 'thresh8'; Set = @{ MB_SPEED_THRESHOLD = '8.0' } },
    @{ Name = 'thresh8p0'; Set = @{ MB_SPEED_THRESHOLD = '8.0'; MB_EXTEND_FOREGROUND = '0' } },
    @{ Name = 'legacy020'; Set = @{ MB_SHUTTER_ANGLE = '180.0'; MB_MOTION_SCALE = '1.0'; MB_MAX_STREAK = '48.0'; MB_SPEED_THRESHOLD = '0.0' } }
)
$fail = 0
foreach ($case in $cases) {
    $dir = Join-Path $Work $case.Name
    New-Item -ItemType Directory -Force $dir | Out-Null
    Copy-Item (Join-Path $Src '*') $dir -Force
    $text = $settings
    foreach ($k in $case.Set.Keys) {
        $text = [regex]::Replace($text, "(?m)^#define $k\s+\S+", "#define $k $($case.Set[$k])")
    }
    Set-Content (Join-Path $dir 'Settings.fxh') $text -NoNewline
    $geo = Join-Path $dir 'Geometry.fxh'
    (Get-Content $geo -Raw).Replace(': _INDEX', ': TEXCOORD7') | Set-Content $geo -NoNewline
    foreach ($fx in 'AdvancedMotionBlur.fx', 'DepthVelocity.fx', 'MotionGeometry.fx') {
        $out = & $fxc /nologo /T fx_2_0 /Fo (Join-Path $dir ($fx + '.fxo')) (Join-Path $dir $fx) 2>&1
        $ok = $LASTEXITCODE -eq 0
        if (-not $ok) { $fail++ }
        $issues = ($out | Select-String -Pattern 'warning|error' | Where-Object { $_.Line -notmatch 'X4717' } | ForEach-Object { $_.Line }) -join ' | '
        '{0,-10} {1,-22} {2} {3}' -f $case.Name, $fx, ($(if ($ok) { 'OK' } else { 'FAIL' })), $issues
    }
}
"cases: $($cases.Count), builds: $($cases.Count * 3), failures: $fail"
exit $fail
