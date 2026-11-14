static const float AdditiveCoverage = 6.0;
static const float ExcludedCoverage = 7.0;
static const float TranslucentSurface = -3.0;
static const float TranslucentTrailSource = -4.0;

bool IsOrdinaryTranslucent(float coverage)
{
    return MB_TRANSLUCENT_MOTION && coverage < 0.0;
}

bool IsAdditive(float coverage)
{
    return MB_TRANSLUCENT_MOTION && coverage == AdditiveCoverage;
}

bool IsProtectedSurface(float coverage)
{
    return coverage == ExcludedCoverage || IsAdditive(coverage) || (coverage > 2.5 && coverage < 3.5);
}

bool HasGeometryCoverage(float coverage)
{
    return coverage > 0.0 || IsOrdinaryTranslucent(coverage);
}
