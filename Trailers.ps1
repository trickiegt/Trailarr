<# This Is Configured for Linux ONLY && Relies on yt-dlp
# Script can run headless by passing a Radarr movie ID as an argument
# -- allowing it to run as a custom Radarr Connect (with the help of a bash script -- Radarr does not support Powershell Scripts)
# Manually running this script provides a few options.
# 1) List all movies from Radarr and their trailer status
#    - Tags movie with traileraquired if one is found or downloaded
#    - Offers and attempts to download movie trailer if missing
# 2) Rename All Trailers
#    - Scans Radarr root folders for *-trailer.mkv
#    - If trailer found, rename to folder name-trailer.mkv
#    - Example: /Movies/Some Movie Name(2020)/offical-trailer.mkv becomes /Movies/Some Movie Name(2020)/Some Movie Name(2020)-trailer.mkv
# 3) Remove tag from all movies and then remove the tag from Radarr
#    - Used for testing but might be desired by someone else
#>

$logName = "Trailarr."+(Get-Date -Format 'yMdms')+".log" #Year Month Day Minute Second 24373529
$logPath = $PSScriptRoot+"/"+$logName
$tmdbAPIkey = "3b7343443443434343426" #Not really required but needed when asking tmdb for a trailer url (Radarr provides a url most times)
$url = "http://radarr.local:7878" #Replace with your server address
$headers = @{
  'X-Api-Key' = 'a9f83434343343443434e76' #Replace with your API Key
  'accept' = 'text/json'
  'Content-Type' = 'text/json'
}
$videoformat="bestvideo[vcodec*=avc1]+bestaudio"
$process = "/usr/local/bin/yt-dlp" #Change if yt-dlp is in a different location for you

function acquireTrailer() { #Attempt to download trailer from youtube
    param(
        [Parameter(Mandatory=$True)]
        [Object[]]$movie
    )
    #Check for existance of trailer in movie folder
    $trailer = check4Existing $movie
    if ($trailer) { 
        Write-Host "Trailer Exists in Folder - Renaming if Required - Inserting Radarr Movie Tag"
        renameTrailer $trailer
        Invoke-WebRequest -Uri "$($url)/api/v3/movie/editor" -Headers $headers -Method Put -ContentType "application/json" -Body "{`"movieIds`":[$($movie.id) ],`"tags`":[$($trailerTag.id)],`"applyTags`":`"add`"}" -ErrorAction 'SilentlyContinue' | out-null
    }
    else {
        $youtubeurl = "https://www.youtube.com/watch?v="
        #Try to Get Trailer from Radarr or Ask for manual URL
        if ($movie.youTubeTrailerId) {
            $youtubeurl += $movie.youTubeTrailerId
            Write-Host "Radarr Provided $($movie.title) Trailer URL: $($movie.youTubeTrailerId)"
        } elseif ($tmdbAPIkey) { #check TMDB for trailer link
            $tmdbTrailers = Invoke-WebRequest -Uri "https://api.themoviedb.org/3/movie/$($movie.tmdbId)/videos?api_key=$($tmdbAPIkey)&language=en" | ConvertFrom-Json
            $trailerList = $tmdbTrailers.results | Where-Object {$_.site -eq 'YouTube'} | Where-Object {$_.type -eq 'Trailer'}
            if ($trailerList) {
                $youtubeurl += $($trailerList[0].key)
                Write-Host "TMDB Provided $($movie.title) Trailer URL: $($trailerList[0].key)"
            }
        } 
        if ($youtubeurl.Length -lt 35){
            if (!$Args) { #Ask user if running manually
                Write-Host "Unable to automatically find a trailer. Enter a URL manually or skip"
                $youtubeurl = Read-Host "Paste Youtube URL or Press Enter to Skip"
            }
        }
        if ($youtubeurl.Length -gt 35){
            #Prepare to download
            $filePath = $($movie.path)
            $filename = $($movie.title)
            $procArgs = "$youtubeurl -o $PSScriptRoot/-trailer --format $videoformat --write-sub --sub-lang en --embed-subs --merge-output-format mkv"
            #Start Download
            Start-Process $process -ArgumentList $procArgs -NoNewWindow -PassThru -Wait
            Move-Item $PSScriptRoot/-trailer.mkv $filePath/$filename-trailer.mkv
            #$trailer = Get-ChildItem -Path $movie.folderName -Filter '*-trailer.mkv' -ErrorAction 'SilentlyContinue'
            $trailer = check4Existing $movie
            if ($trailer) { 
                renameTrailer $trailer
                #Add Tag to Radarr (TrailerAcquired)
                Invoke-WebRequest -Uri "$($url)/api/v3/movie/editor" -Headers $headers -Method Put -ContentType "application/json" -Body "{`"movieIds`":[$($movie.id) ],`"tags`":[$($trailerTag.id)],`"applyTags`":`"add`"}" -ErrorAction 'SilentlyContinue' | out-null
            }
       }
       else { Write-Host "Failed to find a trailer for $($movie.title)" }
    }
    return
}

function listMovies(){ #Show all entities | Status | Offer Trailer Acquisition if missing
    param(
        [Parameter(Mandatory=$True)]
        [Object[]]$movieList
    )
    for ($movie=0; $movie -lt $movieList.Length; $movie++) {
        if ($movieList[$movie].hasFile) { #Make Sure There is a Movie Present
            Write-Host "Array ID: $movie | " -NoNewline
            Write-Host "$($movieList[$movie].title)" -ForegroundColor Yellow
            Write-Host "Radarr ID: $($movieList[$movie].id) | Trailer Status: " -NoNewline
            if ($movieList[$movie].tags -icontains $($trailerTag.id)) { Write-Host "Acquired`n" -ForegroundColor Green }
            else { 
                Write-Host "Missing`n" -ForegroundColor Red 
                if ($choice -ine 'a'){
                    $choice = Read-Host "Would you like to try downloading this trailer? (Y)es / (N)o / (A)lways"
                }
                if (($choice -ieq 'y') -or ($choice -ieq 'a')) { acquireTrailer $movieList[$movie] }
            }
        }
    }
    return
}

function renameAllTrailers(){ #Scan all entities and renames trailer to match foldername
    $rootPaths = Invoke-WebRequest -Uri "$($url)/api/v3/rootfolder/" -Headers $headers | ConvertFrom-Json
    [int]$named =0
    foreach ($rootPath in $rootPaths) {
        $trailers = Get-ChildItem -Path $($rootPath.path) -Filter '*-trailer.mkv' -Depth 1
        foreach ($trailer in $trailers) { 
            $desiredFileName = $trailer.Directory.Name + "-trailer.mkv"
            if ($desiredFileName -eq $trailer.Name) { <#Write-Host "Skipping $trailer - Same Name" -ForegroundColor Gray #> }
            else { #rename trailer
                renameTrailer $trailer
                $named++
            }
        }
    }
    Write-Host "Finished! Renamed a Total of $named Trailers." -foregroundcolor cyan
    return
}

function renameTrailer(){ #Call with trailer object -- Renames trailer to match foldername
    param(
        [Parameter(Mandatory=$True)]
        [Object[]]$trailer
    )
    
    $desiredName = $trailer.Directory.Name + "-trailer.mkv"
    if ($desiredName -eq $trailer.Name) { <#Write-Host "Skipping $trailer - Same Name" -ForegroundColor Gray#> }
    else {
        Write-host "$($trailer.name) -|- New Name: $desiredName" -ForegroundColor Yellow
        Rename-Item $($trailer.FullName) $desiredName
    }
    return
}

function check4Existing() { #Call with movie object - Return Trailer Object or False
    param(
        [Parameter(Mandatory=$True)]
        [Object[]]$movie
    )
    #Check for existance of movie trailer in movie folder
    $trailer = Get-ChildItem -Path $movie.folderName -Filter '*-trailer.mkv' -ErrorAction 'SilentlyContinue'
    Write-Host "Get-ChildItem -Path $($movie.folderName) -Filter '*-trailer.mkv' -ErrorAction 'SilentlyContinue'"
    if ($trailer) { return $trailer }
    else { return $false }
}

function showMenu() {
    Write-Host "#####################" -ForegroundColor Cyan
    Write-Host "#  Trailer Manager  #" -ForegroundColor Cyan
    Write-Host "#####################" -ForegroundColor Cyan
    Write-Host "1 - List All Movies and their IDs and Current Status - Offer Trailer Download and/or Rename if Needed"
    Write-Host "2 - Rename All Improperly Named Trailers - Set to match containing folder name"
    Write-Host "3 - Remove Tag 'traileracquired' From All Movies"
    $choice = Read-Host "Please Select Option 1, 2, 3 -- any other entry will exit"
    return $choice
}

Start-Transcript -Path $logPath

$tagList = Invoke-WebRequest -Uri "$($url)/api/v3/tag/" -Headers $headers | ConvertFrom-Json
$trailerTag = $tagList | Where-Object {$_.label -match 'traileracquired'}
if(!$trailerTag) { #Create new tag for acquired trailers if needed
    $body = "{`"label`": `"traileracquired`"}"
    $trailerTag = Invoke-WebRequest -Uri "$($url)/api/v3/tag/" -Headers $headers -Body $body -Method Post | ConvertFrom-Json
    Write-Host "Our tag was not found.. Created tag# $trailerTag"
}
if ($Args) { #Run Script Headless with Arguments
    Write-Host "Received Radarr ID: $($Args[0])"
    $movies = Invoke-WebRequest -Uri "$($url)/api/v3/movie/" -Headers $headers | ConvertFrom-Json
    for ($movie=0; $movie -lt $movies.Length; $movie++) {
        if ($($movies[$movie].id) -ieq $($Args[0])) {
            Write-Host "Found Movie $($movies[$movie].title) - Array ID: $movie"
            Write-Host "Attempting to acquire trailer automatically."
            acquireTrailer $($movies[$movie])
            $movie += $movies.Length
        }
    }
            
}
else { #Present Menu
    $choice = showMenu
    if (($choice -gt 0) -and ($choice -lt 3)) { #Don't request movie list unless were going to work with it
        $movies = Invoke-WebRequest -Uri "$($url)/api/v3/movie/" -Headers $headers | ConvertFrom-Json
    } else { exit }
    if ($choice -eq 1) { <# List Movies / IDs / Status #>
        listMovies $movies
    }
    elseif ($choice -eq 2) { <# Scan and Rename Trailers #>
        renameAllTrailers $movies
    }
    elseif ($choice -eq 3) { <# Remove traileracquired tag from all movies #>
        foreach ($movie in $movies) {
            Invoke-WebRequest -Uri "$($url)/api/v3/movie/editor" -Headers $headers -Method Put -ContentType "application/json" -Body "{`"movieIds`":[$($movie.id) ],`"tags`":[$($trailerTag.id)],`"applyTags`":`"remove`"}" -ErrorAction 'SilentlyContinue' | out-null
        }
        Invoke-WebRequest -Uri "$($url)/api/v3/tag/4" -Headers $headers -Method Delete | ConvertFrom-Json
    }
}
Stop-Transcript
