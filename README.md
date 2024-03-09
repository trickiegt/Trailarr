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