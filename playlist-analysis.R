library(tidyverse)
library(patchwork)

# shoutout https://github.com/ericpgreen/walkup/tree/main

## LOAD AND PREPARE ----
course_df <- read.csv("data/course.csv")
quarter_mile_df <- read.csv("data/quarter_mile_course.csv")
song_timeline <- read.csv("data/song_timeline.csv")
pace <- 12.5
course_finish <- max(course_df$distance_miles)

scheduled_songs <- song_timeline |>
  filter(start_mile < plotted_end_mile) |>
  mutate(
    midpoint_mile = (start_mile + plotted_end_mile) / 2
  )

distance_scale <- scale_x_continuous(
  limits = c(0, course_finish),
  breaks = seq(0, ceiling(course_finish), by = 1),
  expand = expansion(mult = 0)
)

plot_theme <- theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())


## 1. COURSE GRADE + SONG ENERGY ----
grade_plot <- quarter_mile_df |>
  filter(!is.na(grade_percent)) |>
  ggplot() +
  geom_rect(
    aes(
      xmin = segment_start_miles,
      xmax = distance_miles,
      ymin = pmin(0, grade_percent),
      ymax = pmax(0, grade_percent),
      fill = grade_percent >= 0
    )
  ) +
  geom_hline(yintercept = 0, color = "grey40") +
  scale_fill_manual(
    values = c("TRUE" = "#D95F02", "FALSE" = "#247BA0"),
    guide = "none"
  ) +
  labs(
    title = "Course demands and your anchored playlist",
    x = NULL,
    y = "Grade (%)"
  )

energy_plot <- ggplot(scheduled_songs) +
  geom_segment(
    aes(
      x = start_mile,
      xend = plotted_end_mile,
      y = sc_energy,
      yend = sc_energy,
      color = playlist_section
    ),
    linewidth = 3,
    na.rm = TRUE
  ) +
  labs(
    x = "Distance along GPX (miles)",
    y = "Song energy",
    color = "Section"
  )

combined_plot <- (
  (grade_plot + distance_scale) /
    (energy_plot + distance_scale)
) & plot_theme

print(combined_plot)


## 2. ENERGY-COLORED COURSE MAP ----
course_music <- course_df |>
  left_join(
    scheduled_songs |>
      select(
        track_name, playlist_section, sc_energy, sc_tempo,
        start_mile, plotted_end_mile
      ),
    by = join_by(
      distance_miles >= start_mile,
      distance_miles < plotted_end_mile
    ),
    relationship = "many-to-one"
  ) |>
  arrange(point_order) |>
  mutate(
    next_easting = lead(easting),
    next_northing = lead(northing)
  )

energy_map <- ggplot(course_music) +
  geom_segment(
    aes(
      x = easting,
      y = northing,
      xend = next_easting,
      yend = next_northing,
      color = sc_energy
    ),
    linewidth = 1.5,
    lineend = "round",
    na.rm = TRUE
  ) +
  scale_color_viridis_c(
    option = "C",
    limits = c(0, 1),
    na.value = "grey75",
    name = "Song energy"
  ) +
  coord_equal() +
  theme_void() +
  labs(
    title = "My NYC Marathon soundtrack",
    subtitle = "Planned song energy along the course",
    caption = paste(
      "Assumes 12:30/mile and manual anchors.",
      "Gray = missing energy or no scheduled song."
    )
  )

print(energy_map)




## 3. AUDIO FEATURES + SMOOTH TRENDS ----
scatter_data <- scheduled_songs |>
  pivot_longer(
    cols = c(sc_energy, sc_danceability, sc_valence),
    names_to = "metric",
    values_to = "score"
  ) |>
  mutate(
    metric = factor(
      metric,
      levels = c("sc_energy", "sc_danceability", "sc_valence"),
      labels = c("Energy", "Danceability", "Valence / positivity")
    )
  )

playlist_scatter <- ggplot(
  scatter_data,
  aes(midpoint_mile, score, color = playlist_section)
) +
  geom_point(size = 2.5, alpha = 0.85, na.rm = TRUE) +
  geom_smooth(
    aes(group = 1),
    method = "loess",
    formula = y ~ x,
    span = 0.4,
    se = FALSE,
    color = "black",
    linewidth = 1,
    na.rm = TRUE
  ) +
  facet_wrap(~ metric, ncol = 1) +
  distance_scale +
  scale_y_continuous(breaks = seq(0, 1, by = 0.25)) +
  coord_cartesian(ylim = c(0, 1)) +
  plot_theme +
  theme(legend.position = "bottom") +
  guides(color = guide_legend(ncol = 2)) +
  labs(
    title = "My marathon soundtrack",
    subtitle = "Dots mark song-segment midpoints; curves show song-level trends",
    x = "Distance along GPX (miles)",
    y = "Audio-feature score",
    color = "Section"
  )

print(playlist_scatter)


## CHECK RESERVES AND INTERRUPTED SONGS ----
song_timeline |>
  filter(playback_status != "Fits") |>
  select(
    playlist_section, track_name,
    start_mile, end_mile, playback_status
  ) |>
  as_tibble() |>
  print(n = Inf)


## GENRE PLOTS ----

# Use only the portion scheduled before each manual switch.
scheduled <- song_timeline |>
  filter(start_mile < plotted_end_mile) |>
  mutate(
    scheduled_minutes = (plotted_end_mile - start_mile) * pace,
    sc_genres = if_else(
      is.na(sc_genres) | str_trim(sc_genres) == "",
      "Unknown",
      sc_genres
    ),
    genre_list = str_split(sc_genres, ";\\s*"),
    genre_minutes = scheduled_minutes / lengths(genre_list)
  )

genre_summary <- scheduled |>
  select(playlist_section, genre_list, genre_minutes) |>
  unnest_longer(genre_list, values_to = "genre") |>
  group_by(playlist_section, genre) |>
  summarise(
    minutes = sum(genre_minutes),
    .groups = "drop"
  ) |>
  group_by(playlist_section) |>
  mutate(share = minutes / sum(minutes)) |>
  ungroup()

genre_plot <- ggplot(
  genre_summary,
  aes(
    x = playlist_section,
    y = share,
    fill = genre
  )
) +
  geom_col(width = 0.8) +
  coord_flip() +
  scale_x_discrete(limits = rev(sort(unique(
    genre_summary$playlist_section
  )))) +
  scale_y_continuous(labels = scales::label_percent()) +
  labs(
    title = "How the soundtrack changes across the race",
    subtitle = "Scheduled listening time divided equally among each song’s genre tags",
    x = NULL,
    y = "Share of section’s scheduled music",
    fill = "Soundcharts genre"
  ) +
  theme_minimal(base_size = 12)

print(genre_plot)


## ARTIST VARIABILITY ----

artist_summary <- scheduled |>
  group_by(artists) |>
  summarise(
    playlist_entries = n(),
    scheduled_minutes = sum(scheduled_minutes),
    .groups = "drop"
  ) |>
  arrange(desc(scheduled_minutes))

artist_summary |>
  slice_head(n = 15) |>
  ggplot(aes(
    x = reorder(artists, scheduled_minutes),
    y = scheduled_minutes
  )) +
  geom_col(fill = "#247BA0") +
  coord_flip() +
  labs(
    title = "Who accompanies the most miles?",
    subtitle = "Artist collaborations are treated as separate credits",
    x = NULL,
    y = "Scheduled listening time (minutes)"
  ) +
  theme_minimal(base_size = 12)

## COVERAGE/RESERVES/INTENSITY ----

section_summary <- song_timeline |>
  mutate(
    listening_minutes = pmax(
      0,
      plotted_end_mile - start_mile
    ) * pace
  ) |>
  group_by(playlist_section) |>
  summarise(
    songs = n(),
    
    available_minutes = sum(duration_minutes),
    
    window_minutes =
      (first(cutoff_mile) - first(anchor_mile)) * pace,
    
    scheduled_minutes = sum(listening_minutes),
    
    reserve_minutes = sum(
      duration_minutes - listening_minutes
    ),
    
    average_energy = weighted.mean(
      sc_energy,
      w = listening_minutes,
      na.rm = TRUE
    ),
    
    average_danceability = weighted.mean(
      sc_danceability,
      w = listening_minutes,
      na.rm = TRUE
    ),
    
    .groups = "drop"
  ) |>
  mutate(
    uncovered_minutes = pmax(
      0,
      window_minutes - scheduled_minutes
    )
  )

View(section_summary)
## NYC MUSIC MAP ----


# Keep route segments with valid endpoints.
map_data <- course_music |>
  filter(
    is.finite(easting),
    is.finite(northing),
    is.finite(next_easting),
    is.finite(next_northing)
  )

# Create a spatial line for each short course segment.
segment_geometry <- lapply(seq_len(nrow(map_data)), function(i) {
  st_linestring(
    matrix(
      c(
        map_data$easting[i],
        map_data$northing[i],
        map_data$next_easting[i],
        map_data$next_northing[i]
      ),
      ncol = 2,
      byrow = TRUE
    )
  )
})

# Your projected coordinates use EPSG:32618.
# Leaflet needs longitude/latitude, so transform to EPSG:4326.
route_segments <- st_sf(
  map_data,
  geometry = st_sfc(segment_geometry, crs = 32618)
) |>
  st_transform(4326)

# Fixed energy scale, matching your other plots.
energy_colors <- colorNumeric(
  palette = viridisLite::inferno(256),
  domain = c(0, 1),
  na.color = "#AAAAAA"
)

nyc_music_map <- leaflet(route_segments) |>
  addTiles(
    options = tileOptions(className = "quiet-basemap")
  ) |>
  addPolylines(
    color = ~energy_colors(sc_energy),
    weight = 5,
    opacity = 0.95,
    popup = ~paste0(
      "<b>", coalesce(track_name, "No scheduled song"), "</b>",
      "<br>Section: ", coalesce(playlist_section, "—"),
      "<br>GPX mile: ", round(distance_miles, 2),
      "<br>Energy: ",
      coalesce(as.character(round(sc_energy, 2)), "Unavailable"),
      "<br>BPM: ",
      coalesce(as.character(round(sc_tempo)), "Unavailable")
    )
  ) |>
  addLegend(
    position = "bottomright",
    pal = energy_colors,
    values = c(0, 1),
    title = "Song energy"
  ) |>
  addScaleBar(position = "bottomleft")

nyc_music_map

nyc_music_map