#!/bin/bash
#On Radarr Import -> Run radarrImport.bash -> Run Trailers.ps1
# (connect feature in Radarr won't directly run pwsh)
if [ $radarr_movie_id == $null ]; then
  #For running CustomScript Test in Radarr
  #This way the powershell script will not present an interactive menu
  radarr_movie_id="0"
fi
/opt/microsoft/powershell/7/pwsh /home/gitrepos/VSCode/ArrRelated/Trailers.ps1 $radarr_movie_id