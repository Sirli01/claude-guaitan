param(
    [string]$InputFolder = "",
    [string]$OutputFolder = "",
    [string]$Filter = "*.png",
	[int]$Columns = 4,
	[int]$Rows = 4,
	[int]$CanvasWidth = 512,
	[int]$CanvasHeight = 512,
	[int]$BaselineY = 440,
	[int]$BackgroundThreshold = 244,
	[int]$IdleFrameIndex = 0,
	[switch]$KeepChineseFolderName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($InputFolder)) {
    $InputFolder = Join-Path ([Environment]::GetFolderPath("Desktop")) "character_walk_sources"
}
if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
    $OutputFolder = Join-Path ([Environment]::GetFolderPath("Desktop")) "character_walk_exports"
}

Add-Type -AssemblyName System.Drawing

if (-not ("CharacterSheetToolsV2" -as [type])) {
Add-Type -ReferencedAssemblies @("System.Drawing") -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public sealed class CharacterFrameComponent {
    public int Left { get; set; }
    public int Top { get; set; }
    public int Width { get; set; }
    public int Height { get; set; }
    public int Area { get; set; }
    public int CenterX { get { return Left + Width / 2; } }
    public int CenterY { get { return Top + Height / 2; } }
}

public static class CharacterSheetToolsV2 {
    public static Bitmap ExtractCell(Bitmap source, Rectangle sourceRect) {
        Bitmap cell = new Bitmap(sourceRect.Width, sourceRect.Height, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(cell)) {
            g.Clear(Color.Transparent);
            g.DrawImage(source, new Rectangle(0, 0, sourceRect.Width, sourceRect.Height), sourceRect, GraphicsUnit.Pixel);
        }
        return cell;
    }

    public static Bitmap RemoveBackgroundConnectedToEdges(Bitmap source, int threshold) {
        Bitmap bmp = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp)) {
            g.Clear(Color.Transparent);
            g.DrawImage(source, 0, 0, source.Width, source.Height);
        }

        Rectangle rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        BitmapData data = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        int stride = data.Stride;
        int width = bmp.Width;
        int height = bmp.Height;
        int bytes = Math.Abs(stride) * height;
        byte[] buffer = new byte[bytes];
        Marshal.Copy(data.Scan0, buffer, 0, bytes);

        bool[] visited = new bool[width * height];
        Queue<int> queue = new Queue<int>();

        Action<int, int> enqueueIfBackground = (x, y) => {
            if (x < 0 || y < 0 || x >= width || y >= height) {
                return;
            }
            int index = y * width + x;
            if (visited[index]) {
                return;
            }
            if (!IsBackground(buffer, stride, x, y, threshold)) {
                return;
            }
            visited[index] = true;
            queue.Enqueue(index);
        };

        for (int x = 0; x < width; x++) {
            enqueueIfBackground(x, 0);
            enqueueIfBackground(x, height - 1);
        }
        for (int y = 0; y < height; y++) {
            enqueueIfBackground(0, y);
            enqueueIfBackground(width - 1, y);
        }

        int[] offsets = new int[] { -1, 0, 1, 0, 0, -1, 0, 1 };
        while (queue.Count > 0) {
            int index = queue.Dequeue();
            int x = index % width;
            int y = index / width;
            int pixelOffset = y * stride + x * 4;
            buffer[pixelOffset + 3] = 0;

            for (int i = 0; i < offsets.Length; i += 2) {
                enqueueIfBackground(x + offsets[i], y + offsets[i + 1]);
            }
        }

        Marshal.Copy(buffer, 0, data.Scan0, bytes);
        bmp.UnlockBits(data);
        return bmp;
    }

    public static Rectangle FindOpaqueBounds(Bitmap bmp) {
        int minX = bmp.Width;
        int minY = bmp.Height;
        int maxX = -1;
        int maxY = -1;

        Rectangle rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        BitmapData data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int stride = data.Stride;
        int bytes = Math.Abs(stride) * bmp.Height;
        byte[] buffer = new byte[bytes];
        Marshal.Copy(data.Scan0, buffer, 0, bytes);
        bmp.UnlockBits(data);

        for (int y = 0; y < bmp.Height; y++) {
            for (int x = 0; x < bmp.Width; x++) {
                int offset = y * stride + x * 4;
                byte alpha = buffer[offset + 3];
                if (alpha <= 12) {
                    continue;
                }
                if (x < minX) minX = x;
                if (y < minY) minY = y;
                if (x > maxX) maxX = x;
                if (y > maxY) maxY = y;
            }
        }

        if (maxX < minX || maxY < minY) {
            return Rectangle.Empty;
        }
        return Rectangle.FromLTRB(minX, minY, maxX + 1, maxY + 1);
    }

    public static Bitmap Crop(Bitmap source, Rectangle cropRect) {
        if (cropRect == Rectangle.Empty) {
            return new Bitmap(1, 1, PixelFormat.Format32bppArgb);
        }
        Bitmap cropped = new Bitmap(cropRect.Width, cropRect.Height, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(cropped)) {
            g.Clear(Color.Transparent);
            g.DrawImage(source, new Rectangle(0, 0, cropRect.Width, cropRect.Height), cropRect, GraphicsUnit.Pixel);
        }
        return cropped;
    }

    public static Bitmap ComposeToCanvas(Bitmap source, int canvasWidth, int canvasHeight, int baselineY) {
        Bitmap output = new Bitmap(canvasWidth, canvasHeight, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(output)) {
            g.Clear(Color.Transparent);

            float scale = Math.Min(1.0f, Math.Min((float)canvasWidth / Math.Max(source.Width, 1), (float)baselineY / Math.Max(source.Height, 1)));
            int drawWidth = Math.Max(1, (int)Math.Round(source.Width * scale));
            int drawHeight = Math.Max(1, (int)Math.Round(source.Height * scale));
            int drawX = Math.Max(0, (canvasWidth - drawWidth) / 2);
            int drawY = Math.Max(0, baselineY - drawHeight);
            g.DrawImage(source, new Rectangle(drawX, drawY, drawWidth, drawHeight), new Rectangle(0, 0, source.Width, source.Height), GraphicsUnit.Pixel);
        }
        return output;
    }

    public static CharacterFrameComponent[] FindOpaqueComponents(Bitmap bmp, int alphaThreshold, int minArea, int minWidth, int minHeight) {
        Rectangle rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        BitmapData data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int stride = data.Stride;
        int width = bmp.Width;
        int height = bmp.Height;
        int bytes = Math.Abs(stride) * height;
        byte[] buffer = new byte[bytes];
        Marshal.Copy(data.Scan0, buffer, 0, bytes);
        bmp.UnlockBits(data);

        bool[] visited = new bool[width * height];
        Queue<int> queue = new Queue<int>();
        List<CharacterFrameComponent> result = new List<CharacterFrameComponent>();
        int[] offsets = new int[] { -1, 0, 1, 0, 0, -1, 0, 1 };

        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int startIndex = y * width + x;
                if (visited[startIndex] || !IsOpaque(buffer, stride, x, y, alphaThreshold)) {
                    continue;
                }

                visited[startIndex] = true;
                queue.Enqueue(startIndex);
                int minX = x;
                int minY = y;
                int maxX = x;
                int maxY = y;
                int area = 0;

                while (queue.Count > 0) {
                    int index = queue.Dequeue();
                    int px = index % width;
                    int py = index / width;
                    area++;
                    if (px < minX) minX = px;
                    if (py < minY) minY = py;
                    if (px > maxX) maxX = px;
                    if (py > maxY) maxY = py;

                    for (int i = 0; i < offsets.Length; i += 2) {
                        int nx = px + offsets[i];
                        int ny = py + offsets[i + 1];
                        if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
                            continue;
                        }
                        int neighborIndex = ny * width + nx;
                        if (visited[neighborIndex] || !IsOpaque(buffer, stride, nx, ny, alphaThreshold)) {
                            continue;
                        }
                        visited[neighborIndex] = true;
                        queue.Enqueue(neighborIndex);
                    }
                }

                int componentWidth = maxX - minX + 1;
                int componentHeight = maxY - minY + 1;
                if (area >= minArea && componentWidth >= minWidth && componentHeight >= minHeight) {
                    result.Add(new CharacterFrameComponent {
                        Left = minX,
                        Top = minY,
                        Width = componentWidth,
                        Height = componentHeight,
                        Area = area
                    });
                }
            }
        }

        return result.ToArray();
    }

    private static bool IsBackground(byte[] buffer, int stride, int x, int y, int threshold) {
        int offset = y * stride + x * 4;
        byte b = buffer[offset];
        byte g = buffer[offset + 1];
        byte r = buffer[offset + 2];
        byte a = buffer[offset + 3];
        if (a == 0) {
            return true;
        }
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        return r >= threshold && g >= threshold && b >= threshold && (max - min) <= 18;
    }

    private static bool IsOpaque(byte[] buffer, int stride, int x, int y, int alphaThreshold) {
        int offset = y * stride + x * 4;
        return buffer[offset + 3] > alphaThreshold;
    }
}
"@
}

$rowOrder = @("down", "up", "left", "right")
if ($Rows -ne $rowOrder.Count) {
    throw "Rows must match the built-in row order: down/up/left/right."
}

function New-UString {
    param([int[]]$Codes)
    return (-join ($Codes | ForEach-Object { [char]$_ }))
}

$walkSuffix = New-UString @(0x8D70, 0x8DEF)

$nameMap = @{
    (New-UString @(0x590F, 0x6850)) = "sister"
    (New-UString @(0x6797, 0x4F73, 0x8BED)) = "cool_npc"
    (New-UString @(0x9E7F, 0x53EF)) = "cheerful_npc"
    (New-UString @(0x5468, 0x9510)) = "male_npc"
    (New-UString @(0x6C88, 0x8587)) = "female_npc"
    (New-UString @(0x4F59, 0x51E1)) = "timid_male"
}

function Get-CharacterNames {
	param([string]$BaseName)
    $displayName = $BaseName -replace [regex]::Escape($walkSuffix), "" -replace "_walk", "" -replace "walk", ""
	$displayName = $displayName.Trim("_", "-", " ")
	if ([string]::IsNullOrWhiteSpace($displayName)) {
		$displayName = $BaseName
	}
	$characterId = if ($nameMap.ContainsKey($displayName)) { $nameMap[$displayName] } else { $displayName }
	[pscustomobject]@{
		DisplayName = $displayName
		CharacterId = $characterId
	}
}

function Save-Png {
	param(
		[System.Drawing.Bitmap]$Bitmap,
		[string]$Path
	)
	$dir = Split-Path -Parent $Path
	if (-not (Test-Path $dir)) {
		New-Item -ItemType Directory -Path $dir -Force | Out-Null
	}
	$Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function Get-OrderedComponents {
    param(
        [CharacterFrameComponent[]]$Components,
        [int]$ExpectedRows,
        [int]$ExpectedColumns
    )

    $expectedCount = $ExpectedRows * $ExpectedColumns
    if ($Components.Count -ne $expectedCount) {
        throw "Detected $($Components.Count) character silhouettes, expected $expectedCount."
    }

    $sortedByTop = @($Components | Sort-Object Top, Left)
    $orderedComponents = New-Object System.Collections.Generic.List[object]
    for ($rowIndex = 0; $rowIndex -lt $ExpectedRows; $rowIndex++) {
        $rowComponents = @($sortedByTop | Select-Object -Skip ($rowIndex * $ExpectedColumns) -First $ExpectedColumns | Sort-Object Left)
        if ($rowComponents.Count -ne $ExpectedColumns) {
            throw "Detected a non-standard row layout. Row count was $($rowComponents.Count), expected $ExpectedColumns."
        }
        foreach ($component in $rowComponents) {
            [void]$orderedComponents.Add($component)
        }
    }

    return [pscustomobject]@{
        Ordered = $orderedComponents.ToArray()
    }
}

if (-not (Test-Path $InputFolder)) {
    throw "Input folder does not exist: $InputFolder"
}

if (-not (Test-Path $OutputFolder)) {
	New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}


$sourceFiles = @(Get-ChildItem -Path $InputFolder -Filter $Filter -File | Where-Object {
	$_.BaseName -notmatch "^Gemini_Generated_"
} | Sort-Object Name)

if ($sourceFiles.Count -eq 0) {
    throw "No source files matched filter: $Filter"
}

$summary = @()
$issues = @()

foreach ($file in $sourceFiles) {
	$names = Get-CharacterNames -BaseName $file.BaseName
	$folderName = if ($KeepChineseFolderName) { $names.DisplayName } else { $names.CharacterId }
	$characterOutput = Join-Path $OutputFolder $folderName
	$walkDir = Join-Path $characterOutput "walk"
	$idleDir = Join-Path $characterOutput "idle"

    $source = $null
	try {
        New-Item -ItemType Directory -Path $walkDir -Force | Out-Null
        New-Item -ItemType Directory -Path $idleDir -Force | Out-Null

        $source = [System.Drawing.Bitmap]::FromFile($file.FullName)
        $transparentSource = [CharacterSheetToolsV2]::RemoveBackgroundConnectedToEdges($source, $BackgroundThreshold)
        $components = [CharacterSheetToolsV2]::FindOpaqueComponents($transparentSource, 12, 3500, 60, 140)
        $grid = Get-OrderedComponents -Components $components -ExpectedRows $Rows -ExpectedColumns $Columns
        $orderedComponents = $grid.Ordered
        $sheet = New-Object System.Drawing.Bitmap -ArgumentList @([int]($CanvasWidth * $Columns), [int]($CanvasHeight * $Rows), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
		$sheetGraphics = [System.Drawing.Graphics]::FromImage($sheet)
		$sheetGraphics.Clear([System.Drawing.Color]::Transparent)

		try {
			for ($row = 0; $row -lt $Rows; $row++) {
				$direction = $rowOrder[$row]
				for ($col = 0; $col -lt $Columns; $col++) {
                    $component = $orderedComponents[($row * $Columns) + $col]
                    if ($component -is [System.Array]) {
                        throw "Component resolution returned an array instead of a single silhouette."
                    }
                    $padding = 2
                    $left = [math]::Max(0, $component.Left - $padding)
                    $top = [math]::Max(0, $component.Top - $padding)
                    $right = [math]::Min($transparentSource.Width, $component.Left + $component.Width + $padding)
                    $bottom = [math]::Min($transparentSource.Height, $component.Top + $component.Height + $padding)
                    $srcRect = New-Object System.Drawing.Rectangle -ArgumentList @([int]$left, [int]$top, [int]($right - $left), [int]($bottom - $top))
                    $cropped = [CharacterSheetToolsV2]::Crop($transparentSource, $srcRect)
                    $final = [CharacterSheetToolsV2]::ComposeToCanvas($cropped, $CanvasWidth, $CanvasHeight, $BaselineY)

					try {
						$frameName = "{0}_{1}.png" -f $direction, $col
						$framePath = Join-Path $walkDir $frameName
						Save-Png -Bitmap $final -Path $framePath
						$sheetGraphics.DrawImage($final, $col * $CanvasWidth, $row * $CanvasHeight)

						if ($col -eq $IdleFrameIndex) {
							$idlePath = Join-Path $idleDir ("idle_{0}.png" -f $direction)
							Save-Png -Bitmap $final -Path $idlePath
						}
					}
					finally {
						$cropped.Dispose()
						$final.Dispose()
					}
				}
			}

			$sheetPath = Join-Path $characterOutput ("{0}_walk_sheet.png" -f $folderName)
			Save-Png -Bitmap $sheet -Path $sheetPath

			$manifest = [ordered]@{
				source_file = $file.FullName
				display_name = $names.DisplayName
				character_id = $names.CharacterId
				row_order = $rowOrder
				frame_count_per_direction = $Columns
				canvas_width = $CanvasWidth
				canvas_height = $CanvasHeight
				baseline_y = $BaselineY
				idle_frame_index = $IdleFrameIndex
			}
			$manifest | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $characterOutput "manifest.json") -Encoding UTF8

			$summary += [pscustomobject]@{
                DisplayName = $names.DisplayName
                CharacterId = $names.CharacterId
                OutputFolder = $characterOutput
                FrameSize = "${CanvasWidth}x${CanvasHeight}"
			}
		}
		finally {
            $transparentSource.Dispose()
			$sheetGraphics.Dispose()
			$sheet.Dispose()
		}
	}
    catch {
        $issues += [pscustomobject]@{
            SourceFile = $file.Name
            Reason = "{0} | {1}" -f $_.Exception.Message, $_.ScriptStackTrace
        }
        continue
    }
	finally {
        if ($source) {
            $source.Dispose()
        }
	}
}

$summary | Format-Table -AutoSize | Out-String | Write-Host
if ($issues.Count -gt 0) {
    Write-Host "Skipped non-standard sources:"
    $issues | Format-Table -AutoSize | Out-String | Write-Host
    $issues | Export-Csv -Path (Join-Path $OutputFolder "skipped_sources.csv") -NoTypeInformation -Encoding UTF8
}
Write-Host "Export finished. Open each *_walk_sheet.png first and verify foot alignment."
