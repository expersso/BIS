if(getRversion() >= "2.15.1") utils::globalVariables(c("obs_value", "time_period"))
if(getRversion() >= "2.15.1") utils::globalVariables(c("obs_value", "time_period"))

complete_url <- function(x) paste0("https://www.bis.org", x)

download_bis <- function(url, ...) {
  tmp_dir <- tempdir()
  tmp_file <- tempfile(fileext = ".zip")

  utils::download.file(url, tmp_file, mode = "wb", ...)

  filename <- utils::unzip(tmp_file, list = TRUE)
  utils::unzip(tmp_file, exdir = tmp_dir)

  file.path(tmp_dir, filename$Name)
}

gather_bis <- function(df) {
  df <- tidyr::gather(df, date, obs_value, dplyr::matches("\\d"))
  df <- dplyr::select(df, -time_period)
  dplyr::mutate(df, obs_value = as.numeric(obs_value))
}

clean_names <- function(x) {
  tolower(gsub("'", "", gsub("[[:space:]]", "_", x)))
}

nskips <- function(path) {
  data <- readLines(path, 15)
  ncols <- lengths(strsplit(data, ","))
  sum(ncols < 5)
}

read_bis_wide <- function(path, skip, na.drop = TRUE) {
  df <- t(readr::read_csv(path, skip = skip, col_names = FALSE))

  nms <- df[1, ]
  df <- df[-1, ]
  df <- dplyr::as_data_frame(df)
  names(df) <- clean_names(nms)
  df <- gather_bis(df)

  if(na.drop) tidyr::drop_na(df) else df
}

read_bis_long <- function(path, skip, na.drop = TRUE) {
  df <- readr::read_csv(path, skip = skip)
  names(df) <- clean_names(names(df))
  df <- gather_bis(df)

  if(na.drop) tidyr::drop_na(df) else df
}

read_bis <- function(path) {
  skip <- nskips(path)
  try(return(read_bis_wide(path, skip)), TRUE)
  try(return(read_bis_long(path, skip)), TRUE)
}

#' Download data frame of available BIS data sets
#'
#' @return A data frame
#' @export
#'
#' @examples
#' datasets <- get_datasets()
get_datasets <- function() {
  url <- complete_url("/statistics/full_data_sets.htm")
  page <- xml2::read_html(url)
  nodes <- rvest::html_nodes(page, xpath = "//a[contains(@href, 'zip')]")

  dplyr::tibble(name = rvest::html_text(nodes),
                url  = complete_url(rvest::html_attr(nodes, "href")))
}

#' Download, parse, and read into memory a BIS data set
#'
#' @param url The url to the data set to be read (usually acquired through get_dataset())
#' @param ... Arguments passed to download.file (e.g. quiet = TRUE)
#'
#' @return A data frame
#' @export
#'
#' @examples
#' datasets <- get_datasets()
#' df <- get_bis(datasets$url[6])
get_bis <- function(url, ...) {
  path <- download_bis(url, ...)
  read_bis(path)
}
