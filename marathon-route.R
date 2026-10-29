library(sf)
library(dplyr)
library(tibble)

#shoutout https://www.reddit.com/r/RunNYC/comments/1xg14i3/2026_course_updated_gpx_files/


## SETTINGS ----
gpx_path <- "data/nyc-marathon-2026-blue-route-mile-markers.gpx"
output_dir <- "data"
pace_min_per_mile <- 12.5

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(gpx_path)) {
  stop("GPX file not found: ", gpx_path)
}


## READ COURSE ----
course_points <- st_read(
  gpx_path,
  layer = "track_points",
  quiet = TRUE
) |>
  arrange(track_fid, track_seg_id, track_seg_point_id)

# Require one continuous track segment.
stopifnot(
  nrow(course_points) > 1,
  nrow(distinct(
    st_drop_geometry(course_points),
    track_fid,
    track_seg_id
  )) == 1
)

if (!"ele" %in% names(course_points)) {
  stop("The GPX does not contain an elevation field.")
}

if (any(!is.finite(course_points$ele))) {
  stop("Some elevation values are missing or invalid.")
}


## BUILD COURSE TABLE ----

# Geographic coordinates for maps.
lon_lat <- course_points |>
  st_transform(4326) |>
  st_coordinates()

# Projected coordinates in meters for local distance calculations.
xy <- course_points |>
  st_transform(32618) |>
  st_coordinates()

step_meters <- c(
  0,
  sqrt(diff(xy[, "X"])^2 + diff(xy[, "Y"])^2)
)

course_df <- tibble(
  point_order = seq_len(nrow(course_points)),
  longitude = lon_lat[, "X"],
  latitude = lon_lat[, "Y"],
  easting = xy[, "X"],
  northing = xy[, "Y"],
  elevation_meters = as.numeric(course_points$ele),
  step_meters = step_meters
) |>
  mutate(
    distance_meters = cumsum(step_meters),
    distance_miles = distance_meters / 1609.344,
    elevation_feet = elevation_meters * 3.28084,
    pace_min_per_mile = pace_min_per_mile,
    elapsed_minutes = distance_miles * pace_min_per_mile
  )

route_length <- max(course_df$distance_miles)


## BUILD QUARTER-MILE TABLE ----
quarter_mile_distances <- sort(unique(c(
  seq(0, route_length, by = 0.25),
  route_length
)))

quarter_mile_df <- tibble(
  distance_miles = quarter_mile_distances,
  elevation_feet = approx(
    x = course_df$distance_miles,
    y = course_df$elevation_feet,
    xout = quarter_mile_distances,
    ties = mean
  )$y
) |>
  mutate(
    elapsed_minutes = distance_miles * pace_min_per_mile,
    segment_start_miles = lag(distance_miles),
    segment_distance_miles = distance_miles - segment_start_miles,
    elevation_change_feet = elevation_feet - lag(elevation_feet),
    grade_percent =
      100 * elevation_change_feet / (segment_distance_miles * 5280)
  )


## READ WAYPOINTS ----
waypoints <- st_read(
  gpx_path,
  layer = "waypoints",
  quiet = TRUE
) |>
  st_transform(4326)

if (nrow(waypoints) > 0) {
  waypoint_xy <- st_coordinates(waypoints)
  
  waypoint_df <- waypoints |>
    st_drop_geometry() |>
    select(any_of(c("name", "desc", "ele"))) |>
    mutate(
      longitude = waypoint_xy[, "X"],
      latitude = waypoint_xy[, "Y"]
    )
} else {
  waypoint_df <- tibble(
    name = character(),
    longitude = double(),
    latitude = double()
  )
}


## SAVE OUTPUTS ----
write.csv(
  course_df,
  file.path(output_dir, "course.csv"),
  row.names = FALSE
)

write.csv(
  quarter_mile_df,
  file.path(output_dir, "quarter_mile_course.csv"),
  row.names = FALSE
)

write.csv(
  waypoint_df,
  file.path(output_dir, "course_waypoints.csv"),
  row.names = FALSE
)

message(
  "Saved ", nrow(course_df), " course points, ",
  nrow(quarter_mile_df), " quarter-mile boundaries, and ",
  nrow(waypoint_df), " waypoints. Route length: ",
  round(route_length, 2), " miles."
)