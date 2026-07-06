# Paths to ffmpeg and ffprobe
$ffmpeg = "C:\ffmpeg\ffmpeg.exe"
$ffprobe = "C:\ffmpeg\ffprobe.exe"

# Root folder containing multiple subfolders
$root = "D:\Audiobooks\BookCollection"

# Process each subfolder
Get-ChildItem -Path $root -Directory | ForEach-Object {
    $folder = $_.FullName
    $output = "$folder\$($_.Name).m4b"
    $concatList = "$folder\concat.txt"
    $chapterFile = "$folder\chapters.txt"

    # Reset temp files
    Remove-Item $concatList, $chapterFile -ErrorAction SilentlyContinue

    # Collect m4a files (sorted by name)
    $files = Get-ChildItem -Path $folder -Filter *.m4a | Sort-Object Name

    if ($files.Count -eq 0) {
        Write-Host "No m4a files in $folder, skipping..."
        return
    }

    # Build concat list
    $files | ForEach-Object {
        "file '$($_.FullName)'" | Out-File -FilePath $concatList -Append -Encoding ASCII
    }

    # Build chapter metadata header
    ";FFMETADATA1" | Out-File -FilePath $chapterFile -Encoding ASCII

    $start = 0
    $chapterNo = 1

    foreach ($f in $files) {
        # Get duration in seconds
        $duration = & $ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$($f.FullName)"
        $durationMs = [math]::Round([double]$duration * 1000)

        $end = $start + $durationMs-1

        # Chapter title in format: Chapter No - FileName
        $chapterTitle = "Chapter $chapterNo - $($f.BaseName)"

@"
[CHAPTER]
TIMEBASE=1/1000
START=$start
END=$end
title=$chapterTitle
"@ | Out-File -FilePath $chapterFile -Append -Encoding ASCII

        $start = $end
        $chapterNo++
    }

    # Run ffmpeg to combine with chapters
    & $ffmpeg -report -f concat -safe 0 -i $concatList -i $chapterFile -map_metadata 1 -map 0:a -c:a copy -threads 4 $output

    Write-Host "Created audiobook: $output"
}
