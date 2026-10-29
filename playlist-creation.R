library(tidyverse)

## LOAD DATA ----
songs_data <- read.csv("data/songs_with_soundcharts.csv")
quarter_mile_df <- read.csv("data/quarter_mile_course.csv")

pace <- 12.5
final_start <- 23.11
course_finish <- max(quarter_mile_df$distance_miles)


## SECTION ORDER ----
# Positions refer to the original Spotify playlist.
# Each vector defines the playback order within that section.

sections <- list(
  "01 Opening" = c(51, 38, 39, 61, 31, 80),
  
  "02 Team" = c(15, 14, 16, 18, 17, 20, 19),
  
  "03 Steady Middle" = c(
    26, 45, 34, 62, 6, 7, 86,
    11, 79, 30, 71, 22, 55, 63, 48, 52, 54, 76, 68, 58, 43,
    32, 70, 81, 27, 5, 72, 74, 37, 73,
    40, 49, 66, 77, 88, 82, 41, 89
  ),
  
  "04 Queensboro Bridge" = c(4, 60, 29),
  
  "05 First Avenue" = c(3, 53, 21, 23, 90, 65, 56, 2, 69),
  
  "06 The Wall" = c(
    57, 67, 44, 59, 83, 47, 64, 8, 10, 24, 25, 78
  ),
  
  "07 Almost There" = c(46, 33, 42, 75, 85, 36, 87),
  
  "08 Final 5K" = c(1, 9, 13, 28, 12, 84, 35, 50, 91, 92)
)

section_lookup <- imap_dfr(
  sections,
  function(positions, section) {
    tibble(
      original_position = positions,
      playlist_section = section,
      section_order = seq_along(positions)
    )
  }
)

# Every source position must be assigned exactly once.
stopifnot(
  !anyNA(songs_data$playlist_position),
  !anyDuplicated(songs_data$playlist_position),
  !anyDuplicated(section_lookup$original_position),
  setequal(
    songs_data$playlist_position,
    section_lookup$original_position
  )
)


## CLASSIFY ALL SONGS ----
categorized_songs <- songs_data |>
  mutate(original_position = playlist_position) |>
  left_join(
    section_lookup,
    by = "original_position",
    relationship = "one-to-one"
  ) |>
  arrange(playlist_section, section_order)


## MANUAL FEATURE OVERRIDE ----
manual_track <- "4Ilw2lD6z4WBqh65vUUZUf"

categorized_songs <- categorized_songs |>
  mutate(
    sc_energy = if_else(
      track_id == manual_track, 0.86, sc_energy
    ),
    sc_danceability = if_else(
      track_id == manual_track, 0.58, sc_danceability
    ),
    sc_valence = if_else(
      track_id == manual_track, 0.70, sc_valence
    ),
    sc_tempo = if_else(
      track_id == manual_track, 144, sc_tempo
    ),
    feature_source = if_else(
      track_id == manual_track,
      "Manually supplied",
      "Soundcharts"
    )
  )

# Stop rather than silently build an invalid timeline.
stopifnot(
  all(is.finite(categorized_songs$duration_minutes)),
  all(categorized_songs$duration_minutes > 0)
)


## SECTION DURATIONS ----
section_lengths <- categorized_songs |>
  group_by(playlist_section) |>
  summarise(
    songs = n(),
    minutes = sum(duration_minutes),
    .groups = "drop"
  )

section_minutes <- function(section) {
  section_lengths$minutes[
    match(section, section_lengths$playlist_section)
  ]
}

opening_end <- section_minutes("01 Opening") / pace
team_end <- opening_end + section_minutes("02 Team") / pace

late_end <- 18 +
  section_minutes("06 The Wall") / pace


## MANUAL COURSE ANCHORS ----
anchors <- tibble(
  playlist_section = names(sections),
  
  anchor_mile = c(
    0, opening_end, team_end, 14.92,
    16, 18, late_end, final_start
  ),
  
  cutoff_mile = c(
    opening_end, team_end, 14.92, 16,
    18, late_end, final_start, course_finish
  )
)

stopifnot(all(anchors$anchor_mile < anchors$cutoff_mile))


## BUILD TIMELINE — NO CROSSFADE ----
song_timeline <- categorized_songs |>
  left_join(
    anchors,
    by = "playlist_section",
    relationship = "many-to-one"
  ) |>
  arrange(playlist_section, section_order) |>
  group_by(playlist_section) |>
  mutate(
    end_minutes = cumsum(duration_minutes),
    start_minutes = lag(end_minutes, default = 0),
    
    start_mile = anchor_mile + start_minutes / pace,
    end_mile = anchor_mile + end_minutes / pace,
    
    plotted_end_mile = pmin(end_mile, cutoff_mile),
    
    playback_status = case_when(
      start_mile >= cutoff_mile ~ "Reserve",
      end_mile > cutoff_mile + (1 / 60) / pace ~
        "Plays until manual switch / finish",
      TRUE ~ "Fits"
    )
  ) |>
  ungroup() |>
  mutate(play_order = row_number(), .before = 1)


## SAVE ----
write.csv(
  song_timeline,
  "data/song_timeline.csv",
  row.names = FALSE
)

print(section_lengths)