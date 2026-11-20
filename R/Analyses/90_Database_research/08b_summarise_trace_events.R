#----------------------------------------------------------#
#
#
#                       VegVault
#
#         Summarise the events of the traced v1 functions
#         - sourced by 08_profile_v1_gridpoints.R and
#           09_profile_v1_global_batches.R
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Expects `path_event_log` and `data_trace_steps` (from
#   08a_trace_v1_functions.R) in the calling environment. Creates:
#   - `data_events`: every event, with its call and the seconds to the next
#     event of the same call (the duration of the step, including the
#     functions it calls)
#   - `table_steps`: per function and step, the number of calls and the
#     total, median, and maximum seconds
#   - `table_calls`: per call, its seconds and the row counts at its exit

data_events <-
  readr::read_csv(
    file = path_event_log,
    col_names = c("fn_name", "kind", "epoch", "extras"),
    col_types = "ccdc"
  ) |>
  dplyr::mutate(event_order = dplyr::row_number()) |>
  # Calls of one function never nest, so each exit closes a call
  dplyr::mutate(
    call_id = 1L + base::cumsum(dplyr::lag(kind == "exit", default = FALSE)),
    .by = fn_name
  ) |>
  dplyr::mutate(
    step_order = base::cumsum(kind == "step"),
    seconds = dplyr::lead(epoch) - epoch,
    .by = c(fn_name, call_id)
  ) |>
  dplyr::arrange(event_order)

table_steps <-
  data_events |>
  dplyr::filter(kind == "step") |>
  dplyr::summarise(
    n_calls = dplyr::n(),
    seconds_total = base::sum(seconds),
    seconds_median = stats::median(seconds),
    seconds_max = base::max(seconds),
    .by = c(fn_name, step_order)
  ) |>
  dplyr::left_join(
    data_trace_steps,
    by = dplyr::join_by(fn_name, step_order),
    relationship = "one-to-one"
  )

table_calls <-
  data_events |>
  dplyr::summarise(
    epoch_start = base::min(epoch),
    seconds = base::max(epoch) - base::min(epoch),
    extras_exit = dplyr::last(extras),
    .by = c(fn_name, call_id)
  ) |>
  dplyr::arrange(epoch_start)
