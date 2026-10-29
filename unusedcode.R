
## FINAL FIVE K ----

rated_songs <- read.csv("marathon_song_ratings.csv")

# Missing audio values receive a neutral score.
relative_score <- function(x) {
  result <- rep(0.5, length(x))
  valid <- is.finite(x)
  
  if (sum(valid) > 1L) {
    result[valid] <- (
      rank(x[valid], ties.method = "average") - 1
    ) / (sum(valid) - 1)
  }
  
  result
}

scored_songs <- rated_songs |>
  filter(
    final_eligible %in% TRUE,
    !is.na(personal_rating),
    !is.na(finish_boost),
    !is.na(familiarity)
  ) |>
  mutate(
    energy_score = relative_score(sc_energy),
    positivity_score = relative_score(sc_valence),
    
    finish_score =
      0.35 * ((finish_boost - 1) / 4) +
      0.25 * ((personal_rating - 1) / 4) +
      0.15 * ((familiarity - 1) / 4) +
      0.15 * energy_score +
      0.10 * positivity_score
  ) |>
  arrange(desc(finish_score))

