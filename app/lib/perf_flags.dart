/// Perf experiment flags (debug-time only).
///
/// Keep defaults OFF so production behavior is unchanged.
const bool kPerfLowRasterMode = bool.fromEnvironment(
  "MJC_PERF_LOW_RASTER",
  defaultValue: false,
);

