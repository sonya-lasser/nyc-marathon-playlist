# NYC Marathon Playlist Planning

An R project for creating a personalized soundtrack for the 2026 NYC Marathon using Spotify metadata, Soundcharts audio features, and GPX course data.

The playlist combines personal song preferences with course sections, elevation, and planned crowd-listening breaks. Musical features support the planning—they do not predict running performance.

## Files

| File | Purpose |
|---|---|
| `loading-data.R` | Downloads Spotify playlist metadata and Soundcharts features. |
| `marathon-route.R` | Processes the GPX into course points, elevation, and quarter-mile summaries. |
| `playlist-creation.R` | Assigns song sections, playback order, and manual course anchors. |
| `playlist-analysis.R` | Creates maps, plots, and summaries. |
| `unusedcode.R` | Earlier experiments; not required. |
| `data/songs_with_soundcharts.csv` | Song metadata and available audio features. |
| `data/course.csv` | Route coordinates, elevation, distance, and estimated timing. |
| `data/quarter_mile_course.csv` | Quarter-mile net elevation changes and grades. |
| `data/course_waypoints.csv` | GPX waypoint labels and coordinates. |
| `data/song_timeline.csv` | Ordered songs, sections, features, and planned course locations. |
| `data/*.gpx` | Original route source. |

## Setup

Open the `.Rproj` file in RStudio and install:

```r
install.packages(c(
  "httr", "tidyverse", "sf", "patchwork",
  "leaflet", "htmlwidgets", "htmltools", "viridisLite"
))
```

Store credentials in `.Renviron`, then restart R:

```text
SPOTIFY_CLIENT_ID=your_client_id
SPOTIFY_CLIENT_SECRET=your_client_secret
SPOTIFY_REDIRECT_URI=http://127.0.0.1:1410/
SOUNDCHARTS_APP_ID=your_app_id
SOUNDCHARTS_API_KEY=your_api_key
```

Register the same redirect URI in your Spotify developer app. Keep credentials, tokens, and console history out of Git.

## Workflow

1. Set the Spotify playlist ID and output path in `loading-data.R`.
2. Run `loading-data.R` and complete browser authorization.
3. Set the GPX path and planning pace in `marathon-route.R`, then run it.
4. Run `playlist-creation.R`.
5. Run `playlist-analysis.R`.

The loading script makes fresh API requests each run. Analysis uses saved CSVs and does not require additional API calls.

## Playlist structure

1. **Opening:** reflective, spacious music.
2. **Team:** songs connected to the baseball team I work with.
3. **Steady Middle:** upbeat variety and sustained momentum.
4. **Queensboro Bridge:** a focused energy peak.
5. **First Avenue:** optional background music while enjoying crowds.
6. **The Wall:** dance energy building into determination.
7. **Almost There:** continued late-race hype.
8. **Final 5K:** a separate closing soundtrack.

The model assumes **12:30 per mile, no crossfade, and manual switches at key locations**. Overflow songs remain available as reserves.

**Song assignments depend on the source playlist’s positions.** Reordering that playlist requires updating the assignments.

## Key variables

| Variable | Meaning |
|---|---|
| `playlist_position` / `original_position` | Position in the source Spotify playlist |
| `playlist_section`, `section_order` | Assigned section and playback order |
| `duration_minutes` | Full Spotify track duration |
| `sc_energy`, `sc_danceability`, `sc_valence` | Audio-feature scores, generally on a 0–1 scale |
| `sc_tempo` | Musical tempo in BPM—not running cadence |
| `sc_genres` | Semicolon-separated genre labels |
| `sc_status` | Soundcharts lookup result; missing features remain `NA` |
| `distance_miles` | Cumulative distance along the GPX |
| `elevation_change_feet`, `grade_percent` | Quarter-mile net elevation change and average grade |
| `anchor_mile`, `cutoff_mile` | Planned section boundaries |
| `start_mile`, `end_mile` | Estimated song locations |
| `plotted_end_mile` | Song endpoint clipped at the next anchor |
| `playback_status` | Fits, interrupted at a switch, or reserve |

Route coordinates include longitude/latitude in **EPSG:4326** and projected coordinates in **EPSG:32618**.

## Visualizations

- Course grade aligned with song energy.
- Interactive NYC route colored by energy.
- Energy, danceability, and valence trends by distance.
- Genre mix, artist variety, listening-time summaries, and reserves.

Section summaries use scheduled listening time where appropriate. Genre minutes are divided equally among each song’s tags to avoid double-counting.

## Assumptions and limitations

- The community-sourced GPX is not independently verified official race guidance.
- Its calculated length is approximately **26.45 miles**; the official marathon distance remains **42.195 km / 26.22 miles**.
- GPX elevation can be imperfect, especially around bridges. Net elevation change is not total climbing.
- Pauses, skips, and pace changes affect actual song locations.
- Audio features describe music, not personal emotional responses or expected performance.
- Olivia Rodrigo’s **“my way”** uses manually supplied values: energy **0.86**, danceability **0.58**, valence **0.70**, and tempo **144 BPM**. These are labeled separately from Soundcharts data.
- Online map backgrounds require internet access. Keep map attribution visible.

## Sources and acknowledgments

- [Eric P. Green’s walkup project](https://github.com/ericpgreen/walkup/tree/main): walk-up-song inspiration and the Soundcharts workflow adapted for this project.
- [RunNYC: 2026 course updated GPX files](https://www.reddit.com/r/RunNYC/comments/1xg14i3/2026_course_updated_gpx_files/): referenced course GPX source.
- **Spotify Web API:** playlist metadata and track durations.
- **Soundcharts API:** audio features and genre information.
- **OpenStreetMap contributors:** map background.
- **OpenAI’s ChatGPT:** assistance with R code, troubleshooting, playlist planning, and documentation. Final preferences and decisions are mine.

Third-party data and adapted material remain subject to their original licenses and service terms. Check those terms before redistributing files.