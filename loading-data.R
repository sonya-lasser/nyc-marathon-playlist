library(httr)
library(dplyr)
library(tibble)

## SETTINGS ----
playlist_id <- "7dsI1jukmEVGqKzpkvdqeB" #IMPORTANT -- CHANGE HERE FOR DIFFERENT FILE
output_file <- "data/songs_with_soundcharts.csv"

required <- c(
  "SPOTIFY_CLIENT_ID", "SPOTIFY_CLIENT_SECRET",
  "SOUNDCHARTS_APP_ID", "SOUNDCHARTS_API_KEY"
)

if (any(!nzchar(Sys.getenv(required)))) {
  stop("Missing credentials. Check .Renviron and restart R.")
}

`%||%` <- function(x, fallback) {
  if (is.null(x) || length(x) == 0L) fallback else x
}


## AUTHORIZE SPOTIFY ----
spotify_oauth <- oauth2.0_token(
  endpoint = oauth_endpoint(
    authorize = "https://accounts.spotify.com/authorize",
    access = "https://accounts.spotify.com/api/token"
  ),
  app = oauth_app(
    appname = "R Analysis",
    key = Sys.getenv("SPOTIFY_CLIENT_ID"),
    secret = Sys.getenv("SPOTIFY_CLIENT_SECRET"),
    redirect_uri = Sys.getenv(
      "SPOTIFY_REDIRECT_URI",
      unset = "http://127.0.0.1:1410/"
    )
  ),
  scope = c(
    "playlist-read-private",
    "playlist-read-collaborative"
  ),
  cache = FALSE
)


## GET PLAYLIST ----
entries <- list()
offset <- 0L

repeat {
  response <- GET(
    paste0(
      "https://api.spotify.com/v1/playlists/",
      playlist_id,
      "/items"
    ),
    config(token = spotify_oauth),
    query = list(limit = 50, offset = offset),
    timeout(30)
  )
  
  stop_for_status(response)
  batch <- content(response, as = "parsed", encoding = "UTF-8")
  
  entries <- c(entries, batch$items)
  
  if (is.null(batch[["next"]]) || !length(batch$items)) break
  
  offset <- offset + length(batch$items)
}

if (!length(entries)) {
  stop("No playlist entries returned.")
}

songs <- bind_rows(lapply(seq_along(entries), function(i) {
  entry <- entries[[i]]
  track <- entry$item %||% entry$track
  
  tibble(
    playlist_position = i,
    track_id = track$id %||% NA_character_,
    track_name = track$name %||% NA_character_,
    artists = if (length(track$artists)) {
      paste(
        vapply(track$artists, function(a) a$name, character(1)),
        collapse = ", "
      )
    } else {
      NA_character_
    },
    album = track$album$name %||% NA_character_,
    duration_minutes = (track$duration_ms %||% NA_real_) / 60000
  )
}))


## GET SOUNDCHARTS FEATURES ----
fetch_soundcharts <- function(id) {
  response <- RETRY(
    "GET",
    paste0(
      "https://customer.api.soundcharts.com",
      "/api/v2.25/song/by-platform/spotify/",
      id
    ),
    add_headers(
      `x-app-id` = Sys.getenv("SOUNDCHARTS_APP_ID"),
      `x-api-key` = Sys.getenv("SOUNDCHARTS_API_KEY")
    ),
    timeout(30),
    times = 3,
    terminate_on = c(400, 401, 403, 404),
    quiet = TRUE
  )
  
  status <- status_code(response)
  
  if (status %in% c(401L, 403L)) {
    stop("Soundcharts authentication/access failed: HTTP ", status)
  }
  
  if (status != 200L) {
    return(tibble(
      track_id = id,
      sc_status = paste0("http_", status)
    ))
  }
  
  obj <- content(
    response,
    as = "parsed",
    encoding = "UTF-8"
  )$object
  
  audio <- obj$audio
  
  numeric_fields <- c(
    "danceability", "energy", "valence", "acousticness",
    "instrumentalness", "speechiness", "liveness",
    "loudness", "tempo"
  )
  
  features <- as_tibble(setNames(
    lapply(numeric_fields, function(field) {
      as.numeric(audio[[field]] %||% NA_real_)
    }),
    paste0("sc_", numeric_fields)
  ))
  
  genres <- vapply(
    obj$genres,
    function(g) g$root %||% NA_character_,
    character(1)
  )
  
  genres <- unique(genres[!is.na(genres) & nzchar(genres)])
  
  bind_cols(
    tibble(
      track_id = id,
      sc_status = if (is.null(obj)) {
        "missing_object"
      } else if (!length(audio)) {
        "found_no_audio"
      } else {
        "found"
      }
    ),
    features,
    tibble(
      sc_key = as.character(audio$key %||% NA_character_),
      sc_mode = as.character(audio$mode %||% NA_character_),
      sc_time_signature = as.numeric(
        audio$timeSignature %||% NA_real_
      ),
      sc_duration = as.numeric(obj$duration %||% NA_real_),
      sc_isrc = obj$isrc$value %||% NA_character_,
      sc_genres = if (length(genres)) {
        paste(genres, collapse = "; ")
      } else {
        NA_character_
      }
    )
  )
}

# Look up each unique track once, preserving playlist repeats later.
track_ids <- unique(songs$track_id)
track_ids <- track_ids[!is.na(track_ids) & nzchar(track_ids)]

if (!length(track_ids)) {
  stop("No track IDs were available for Soundcharts lookup.")
}

features <- bind_rows(lapply(seq_along(track_ids), function(i) {
  message("Soundcharts: ", i, "/", length(track_ids))
  
  result <- fetch_soundcharts(track_ids[i])
  Sys.sleep(0.3)
  
  result
}))


## JOIN AND SAVE ----
songs_data <- songs |>
  left_join(
    features,
    by = "track_id",
    relationship = "many-to-one"
  )

write.csv(songs_data, output_file, row.names = FALSE)

message("Saved ", nrow(songs_data), " playlist entries to ", output_file)