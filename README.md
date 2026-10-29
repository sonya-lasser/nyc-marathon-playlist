# NYC Marathon Playlist Planning with R

A personal project to build a course-aware soundtrack for the 2026 NYC Marathon.

This project combines Spotify playlist metadata, Soundcharts audio features, and GPX course data to explore how music can support different parts of the race—from a reflective opening to a high-energy bridge crossing and a celebratory final 5K.

The goal is not to create a scientifically “optimal” playlist. It is to combine quantitative information with personal preferences, meaningful songs, crowd-listening breaks, and practical race-day flexibility.

## Project overview

The workflow has four stages:

1. Download song metadata from a Spotify playlist.
2. Retrieve available audio features and genres from Soundcharts.
3. Process a local GPX file into course and quarter-mile data.
4. Arrange songs into course sections and visualize the planned soundtrack.

The playlist uses manual anchors at important locations. Earlier pauses or skipped songs do not need to remain perfectly synchronized because playback can be reset at those anchors.

## Repository structure

```text
.
├── NYC-Marathon-Spotify.Rproj
├── loading-data.R
├── marathon-route.R
├── playlist-creation.R
├── playlist-analysis.R
├── unusedcode.R
├── .gitignore
└── data/
    ├── songs_with_soundcharts.csv
    ├── course.csv
    ├── quarter_mile_course.csv
    ├── course_waypoints.csv
    ├── song_timeline.csv
    ├── nyc-marathon-2026-blue-route-mile-markers.gpx
    └── archive/
```

Some generated data or archived files may be excluded from version control.

### R scripts

| File | Purpose |
|---|---|
| `loading-data.R` | Authorizes Spotify, downloads playlist entries, retrieves Soundcharts features for unique track IDs, and saves the combined song data. |
| `marathon-route.R` | Reads the GPX route, calculates cumulative distance, processes elevation, and exports course tables. |
| `playlist-creation.R` | Assigns songs to sections, defines playback order and manual anchors, applies manual feature overrides, and exports the song timeline. |
| `playlist-analysis.R` | Loads the saved tables and creates plots, maps, and playlist summaries. |
| `unusedcode.R` | Earlier experiments and reference code; not required for the current workflow. |
| `NYC-Marathon-Spotify.Rproj` | Opens the project in RStudio with the repository as the working directory. |

## Requirements

- R and, optionally, RStudio
- A Spotify developer application with suitable Web API access
- Soundcharts API credentials and access to the endpoint used by the script
- A local GPX route file
- An internet connection for API requests and online map tiles

Install the packages used across the project:

```r
install.packages(c(
  "httr",
  "tidyverse",
  "sf",
  "patchwork",
  "leaflet",
  "htmlwidgets",
  "htmltools",
  "viridisLite"
))
```

Package requirements may vary if optional visualizations are removed.

## Credentials

Credentials are loaded from environment variables rather than written into scripts.

Create or edit your user-level `.Renviron` file:

```r
install.packages("usethis") # If needed
usethis::edit_r_environ()
```

Add:

```text
SPOTIFY_CLIENT_ID=your_client_id
SPOTIFY_CLIENT_SECRET=your_client_secret
SPOTIFY_REDIRECT_URI=http://127.0.0.1:1410/
SOUNDCHARTS_APP_ID=your_soundcharts_app_id
SOUNDCHARTS_API_KEY=your_soundcharts_api_key
```

Save the file and restart R.

The Spotify developer app must have the exact redirect URI registered:

```text
http://127.0.0.1:1410/
```

Check that credentials are loaded without printing them:

```r
nzchar(Sys.getenv("SPOTIFY_CLIENT_ID"))
nzchar(Sys.getenv("SOUNDCHARTS_API_KEY"))
```

Never commit `.Renviron`, API keys, OAuth tokens, or console history containing credentials. If a credential is exposed, rotate it; deleting it from the latest file does not remove it from Git history.

## How to run

Open `NYC-Marathon-Spotify.Rproj` and run scripts from the project root.

### 1. Download playlist data

In `loading-data.R`, set:

```r
playlist_id <- "YOUR_SPOTIFY_PLAYLIST_ID"
output_file <- "data/songs_with_soundcharts.csv"
```

The playlist ID is the code after `/playlist/` in a Spotify URL, excluding any query parameters.

Run:

```r
source("loading-data.R")
```

Complete the browser authorization when prompted.

The script:

- Retrieves all pages of playlist entries.
- Preserves playlist positions and repeated songs.
- Requests Soundcharts data once per unique available track ID.
- Joins the features back to the playlist.
- Writes one combined CSV.

Each run makes fresh API requests and may count toward API allowances. The script does not download song audio.

### 2. Process the course

In `marathon-route.R`, set the GPX path and planning pace:

```r
gpx_path <- "data/nyc-marathon-2026-blue-route-mile-markers.gpx"
pace_min_per_mile <- 12.5
```

Run:

```r
source("marathon-route.R")
```

The current processing assumes one continuous track segment and valid elevation values.

### 3. Create the playlist timeline

Run:

```r
source("playlist-creation.R")
```

This reads the song and course CSVs, assigns every source playlist position to a section, and creates:

```text
data/song_timeline.csv
```

Validation checks stop the script if source positions are missing, duplicated, or unassigned.

### 4. Run the analysis

Run:

```r
source("playlist-analysis.R")
```

This uses saved CSVs. API requests are not needed for plotting.

The scripts do not automatically create or reorder Spotify playlists; the planned order is represented in the exported data.

## Playlist structure

| Section | Purpose | Planned placement |
|---|---|---|
| `01 Opening` | Reflective, spacious music for taking in the start | Start of race |
| `02 Team` | A continuous block of baseball walk-up songs | Immediately after the opening |
| `03 Steady Middle` | Upbeat variety and steady musical momentum | After Team, until the bridge anchor |
| `04 Queensboro Bridge` | Focus, energy, and determination | Approximately mile 14.92 |
| `05 First Avenue` | Optional background music while enjoying the crowds | Approximately miles 16–18 |
| `06 The Wall` | Dance-oriented energy followed by determination | Manual start at mile 18 |
| `07 Almost There` | Continued late-race hype | After The Wall block |
| `08 Final 5K` | Personally selected closing soundtrack | Manual start near mile 23.11 |

Section names must match exactly wherever they are referenced in the code.

“The Wall” is a playlist chapter name, not a prediction that a particular physiological event will happen at that mile.

### Manual anchors and reserves

The plan assumes:

- A constant planning pace of 12:30 per mile.
- No crossfade.
- Songs play in their assigned order.
- The runner manually switches or skips to the next anchored section.
- Crowd breaks and skipped songs are expected.

Songs extending beyond a section’s cutoff remain available as reserves. They do not push the next anchored section later in the model.

This is a planning scenario, not a real-time playback tracker.

## Important source-order assumption

Song assignments currently use the source playlist’s `playlist_position`.

The current plan expects 92 entries, including:

- Position 91: `I Will Survive`
- Position 92: `I'm Still Standing`

Reordering or inserting tracks in the source Spotify playlist changes position-based assignments.

Keep the source order stable, or update the assignment vectors after refreshing the data. Track-ID-based assignments would be a useful future improvement.

## Data files and key variables

### `songs_with_soundcharts.csv`

One row per source playlist entry, including repeated songs.

| Variable | Description |
|---|---|
| `playlist_position` | Original position in the source Spotify playlist |
| `track_id` | Spotify track identifier |
| `track_name` | Track title |
| `artists` | Combined artist credit |
| `album` | Album name |
| `duration_minutes` | Spotify track duration, converted to minutes |
| `sc_status` | Soundcharts lookup status |
| `sc_energy` | Musical energy/intensity score |
| `sc_danceability` | Danceability score |
| `sc_valence` | Estimated musical positivity |
| `sc_tempo` | Estimated tempo in beats per minute |
| `sc_acousticness` | Acousticness score |
| `sc_instrumentalness` | Instrumentalness score |
| `sc_speechiness` | Speechiness score |
| `sc_liveness` | Liveness score |
| `sc_loudness` | Loudness value returned by the API |
| `sc_key`, `sc_mode` | Key and mode values returned by the API |
| `sc_time_signature` | Time signature returned by the API |
| `sc_duration` | Duration returned by Soundcharts, retained without conversion |
| `sc_isrc` | ISRC returned by Soundcharts |
| `sc_genres` | Semicolon-separated genre labels |

Consult Soundcharts documentation for current field definitions and units. The `sc_` prefix identifies the Soundcharts feature columns, except where a documented manual override has been applied.

Typical lookup statuses include:

- `found`: a song object with a nonempty audio object was returned; individual fields may still be missing.
- `found_no_audio`: metadata was found without audio features.
- `missing_object`: the expected song object was absent.
- `http_404` or other `http_*` values: an unsuccessful HTTP response.

Missing features are `NA`, not zero.

### `course.csv`

One row per GPX track point.

| Variable | Description |
|---|---|
| `point_order` | Point sequence along the course |
| `longitude`, `latitude` | Geographic coordinates in EPSG:4326 |
| `easting`, `northing` | Projected coordinates in EPSG:32618, in meters |
| `elevation_meters`, `elevation_feet` | GPX elevation in the stated units |
| `step_meters` | Planar distance from the previous point |
| `distance_meters`, `distance_miles` | Cumulative calculated route distance |
| `pace_min_per_mile` | Planning pace used during processing |
| `elapsed_minutes` | Estimated time at that distance under the constant-pace assumption |

CSV files do not retain spatial coordinate-system metadata. Specify the correct CRS when converting coordinates back into spatial objects.

### `quarter_mile_course.csv`

One row per quarter-mile boundary, plus the GPX endpoint.

| Variable | Description |
|---|---|
| `distance_miles` | Segment endpoint |
| `elevation_feet` | Elevation interpolated at that boundary |
| `elapsed_minutes` | Estimated time at the boundary |
| `segment_start_miles` | Previous boundary |
| `segment_distance_miles` | Segment length; the final segment may be shorter |
| `elevation_change_feet` | Endpoint elevation minus starting elevation |
| `grade_percent` | Net vertical change divided by horizontal segment distance × 100 |

Each row describes the segment ending at `distance_miles`. The first row has no preceding segment, so change and grade are `NA`.

**Net elevation change is not total climbing.** A segment can climb and descend substantially while having little net change.

### `course_waypoints.csv`

Waypoint labels and coordinates from the GPX, including available mile-marker information. Waypoints are preserved for reference; they are not currently used to recalibrate cumulative GPX distance.

### `song_timeline.csv`

The main analysis-ready output. It retains song metadata and features, and adds:

| Variable | Description |
|---|---|
| `original_position` | Source playlist position used for classification |
| `playlist_section` | Assigned course/music chapter |
| `section_order` | Playback order within the section |
| `play_order` | Overall section-based order, including reserves |
| `feature_source` | Feature provenance label, including manual overrides |
| `anchor_mile` | Planned section start |
| `cutoff_mile` | Next manual switch or course endpoint |
| `start_minutes`, `end_minutes` | Song times relative to the section’s start |
| `start_mile`, `end_mile` | Estimated song locations at the planning pace |
| `plotted_end_mile` | Song endpoint clipped to the section cutoff |
| `playback_status` | Whether the song fits, crosses a cutoff, or is a reserve |

Filter to:

```r
start_mile < plotted_end_mile
```

when plotting scheduled music rather than unused reserves.

## Manual feature override

Soundcharts did not provide audio features for Olivia Rodrigo’s `my way` when the data was collected.

The analysis applies these user-supplied values:

| Feature | Value |
|---|---:|
| Energy | 0.86 |
| Danceability | 0.58 |
| Valence | 0.70 |
| Tempo | 144 BPM |

These values are not Soundcharts measurements and have not been independently validated in this project. They are labeled `Manually supplied` in `feature_source`.

## Visualizations and summaries

The analysis includes or supports:

- Quarter-mile grade aligned with planned song energy.
- A geographic course map colored by song energy.
- An interactive Leaflet map with song information.
- Energy, danceability, and valence scatterplots by distance.
- LOESS curves showing the broad musical arc.
- Genre composition by playlist section.
- Time-weighted feature summaries.
- Scheduled music, reserve time, and uncovered-time summaries.
- Artist-credit listening-time summaries.

### Interpretation choices

- Scatterplot dots represent the midpoint of each song’s scheduled course portion.
- LOESS trends give each plotted song equal influence; they are not duration-weighted.
- Section averages can be weighted by scheduled listening time.
- Genre summaries divide a song’s scheduled minutes equally among its genre tags to avoid double-counting listening time.
- Combined artist credits are treated as separate credits in the simple artist summary.
- The route-color overlay approximates song boundaries using the available GPX points.

## Mapping

Interactive maps use Leaflet with OpenStreetMap tiles. The working `addTiles()` setup does not require an API key.

The background may be visually subdued with CSS so the route remains prominent.

An internet connection is required to load online background tiles, including when viewing a saved HTML widget. Keep map attribution visible and follow the tile provider’s usage policy; do not bulk-download public tiles for offline use.

## Limitations

### Course accuracy

The route was obtained from a community-shared GPX source. It should not be treated as independently verified official 2026 race guidance.

The processed GPX measures approximately 26.45 miles, while the official marathon distance is 42.195 km, or approximately 26.22 miles. The model retains the GPX distance axis rather than automatically rescaling it.

Course-file geometry, sampling, and measurement differences can affect calculated distances and anchor placement. Use official race information and on-course markers for race-day decisions.

### Elevation accuracy

Elevation is taken from the GPX and has not been independently validated. Bridges, sparse sampling, and elevation noise can affect grade estimates.

### Music features

Soundcharts features are not assumed to be identical to Spotify’s historical audio-feature values. Automated estimates can be missing or imperfect.

BPM is musical tempo, not running cadence. Half-time and double-time interpretations are common.

Valence estimates musical positivity; it does not measure how a particular listener feels about a song.

### Timing and performance

The timeline assumes constant pace and does not simulate congestion, aid-station stops, changing effort, pauses, or spontaneous skips.

Audio-feature scores are planning aids, not evidence that a song will improve pace or prevent fatigue. Music does not replace appropriate training, pacing, fueling, or race-day safety decisions.

## Sources and acknowledgments

### Walk-up-song inspiration and API workflow

[Eric P. Green’s walkup project](https://github.com/ericpgreen/walkup/tree/main)

Referenced as inspiration for the walk-up-song component and the Soundcharts lookup workflow adapted for this project.

### Course GPX source

[RunNYC community post: 2026 course updated GPX files](https://www.reddit.com/r/RunNYC/comments/1xg14i3/2026_course_updated_gpx_files/)

Source referenced for the locally used course GPX and mile-marker data.

### Data and mapping services

- **Spotify Web API:** playlist entries, track identifiers, metadata, and durations.
- **Soundcharts API:** available audio features, identifiers, and genre labels.
- **OpenStreetMap contributors:** interactive map background data.

### AI assistance

**OpenAI’s ChatGPT** assisted with:

- Drafting and refactoring R code.
- Troubleshooting API, data-processing, plotting, and Git issues.
- Developing playlist-section ideas and timing calculations.
- Explaining methods and drafting documentation.

Personal song choices, race-day preferences, and playlist decisions are mine. AI-assisted suggestions and code require human review and testing.

## Data use and licensing

This repository combines original analysis code with information obtained from third-party services and a community-shared route file.

Acknowledgment does not replace permission or license compliance. Consult the original sources and applicable API terms before redistributing data, route files, or adapted code. This project does not claim ownership of third-party music metadata, audio-feature data, map data, or course files.

## Possible future improvements

- Replace position-based assignments with stable track-ID-based assignments.
- Model different pace scenarios while preserving manual anchors.
- Add personal ratings and familiarity to the analysis.
- Annotate official landmarks and verified mile markers.
- Export ordered song lists for easier Spotify playlist assembly.
- Compare the planned soundtrack with actual race-day playback and pacing.