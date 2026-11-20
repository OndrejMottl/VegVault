#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Trace v1 functions for the profiling scripts
#         - sourced by 08_profile_v1_gridpoints.R and
#           09_profile_v1_global_batches.R
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Expects in the calling environment:
#   - `vec_functions_traced`: names of v1 functions in the global
#     environment
#   - `path_event_log`: the CSV file the events are appended to
# Creates `data_trace_steps` (the label of every traced step) and traces
#   each function with base `trace()`: a timestamp before every top-level
#   step and at exit, with the row counts of the data frames in the frame.
#   The functions themselves are not changed. The caller untraces them
#   with `base::untrace()` when done.

# One row per traced top-level step, to label the logged events
data_trace_steps <-
  tibble::tibble(fn_name = vec_functions_traced) |>
  dplyr::mutate(
    steps = purrr::map(
      .x = fn_name,
      .f = ~ base::as.list(
        base::body(base::get(.x, envir = base::globalenv()))
      )[-1L]
    )
  ) |>
  tidyr::unnest_longer(col = steps, indices_include = FALSE) |>
  dplyr::mutate(
    step_order = dplyr::row_number(),
    step_label = purrr::map_chr(
      .x = steps,
      .f = ~ base::deparse(.x, width.cutoff = 500L) |>
        purrr::chuck(1L) |>
        stringr::str_squish() |>
        stringr::str_trunc(width = 70L)
    ),
    .by = fn_name
  ) |>
  dplyr::select(fn_name, step_order, step_label)

# Each tracer appends one line: function, kind of event, time, and the
#   row counts of the data frames (and the single strings) in the frame.
#   It runs inside `local()`, so it adds nothing to the traced frame.
purrr::walk(
  .x = vec_functions_traced,
  .f = ~ {
    name_fn <- .x

    list_tracers <-
      purrr::map(
        .x = c(step = "step", exit = "exit"),
        .f = ~ base::bquote(
          base::local({
            env_traced <-
              base::parent.env(base::environment())

            list_locals <-
              base::mget(
                x = base::ls(envir = env_traced),
                envir = env_traced
              )

            vec_rows <-
              purrr::map_int(
                .x = purrr::keep(.x = list_locals, .p = base::is.data.frame),
                .f = base::nrow
              )

            vec_strings <-
              purrr::keep(.x = list_locals, .p = rlang::is_string) |>
              base::unlist()

            base::cat(
              stringr::str_c(
                .(name_fn),
                .(.x),
                base::sprintf("%.6f", base::as.numeric(base::Sys.time())),
                stringr::str_c(
                  c(
                    stringr::str_c(base::names(vec_rows), "=", vec_rows),
                    stringr::str_c(
                      base::names(vec_strings),
                      "=",
                      stringr::str_replace_all(
                        string = vec_strings,
                        pattern = "[,;=\"\\s]+",
                        replacement = " "
                      ) |>
                        stringr::str_trunc(width = 60L)
                    )
                  ),
                  collapse = ";"
                ),
                sep = ","
              ),
              "\n",
              sep = "",
              file = .(path_event_log),
              append = TRUE
            )
          })
        )
      )

    base::trace(
      what = name_fn,
      tracer = purrr::chuck(list_tracers, "step"),
      exit = purrr::chuck(list_tracers, "exit"),
      at = base::seq.int(
        from = 2L,
        to = base::length(base::body(base::get(name_fn)))
      ),
      print = FALSE,
      where = base::globalenv()
    )
  }
)
