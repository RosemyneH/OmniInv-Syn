param(
    [Parameter(Mandatory = $true)][string]$BaselinePath,
    [Parameter(Mandatory = $true)][string]$CandidatePath,
    [double]$AvgRegressionPct = 8.0,
    [double]$P95RegressionPct = 12.0,
    [double]$MaxRegressionPct = 15.0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Json {
    param([string]$Path)
    if (-not (Test-Path -Path $Path)) {
        throw "Missing file: $Path"
    }
    return Get-Content -Raw -Path $Path | ConvertFrom-Json
}

function Test-Regression {
    param(
        [double]$BaselineValue,
        [double]$CandidateValue,
        [double]$ThresholdPct
    )

    if ($BaselineValue -le 0) {
        return $false
    }

    $allowed = $BaselineValue * (1 + ($ThresholdPct / 100.0))
    return $CandidateValue -gt $allowed
}

$baseline = Get-Json -Path $BaselinePath
$candidate = Get-Json -Path $CandidatePath

if (-not $baseline.metrics) { throw "Baseline missing metrics object" }
if (-not $candidate.metrics) { throw "Candidate missing metrics object" }

$failures = @()

foreach ($metricName in $baseline.metrics.PSObject.Properties.Name) {
    $baseMetric = $baseline.metrics.$metricName
    $candMetric = $candidate.metrics.$metricName
    if (-not $candMetric) {
        $failures += "Missing candidate metric: $metricName"
        continue
    }

    if (Test-Regression -BaselineValue ([double]$baseMetric.avgMs) -CandidateValue ([double]$candMetric.avgMs) -ThresholdPct $AvgRegressionPct) {
        $failures += "$metricName avgMs regressed: baseline=$($baseMetric.avgMs) candidate=$($candMetric.avgMs)"
    }
    if (Test-Regression -BaselineValue ([double]$baseMetric.p95Ms) -CandidateValue ([double]$candMetric.p95Ms) -ThresholdPct $P95RegressionPct) {
        $failures += "$metricName p95Ms regressed: baseline=$($baseMetric.p95Ms) candidate=$($candMetric.p95Ms)"
    }
    if (Test-Regression -BaselineValue ([double]$baseMetric.maxMs) -CandidateValue ([double]$candMetric.maxMs) -ThresholdPct $MaxRegressionPct) {
        $failures += "$metricName maxMs regressed: baseline=$($baseMetric.maxMs) candidate=$($candMetric.maxMs)"
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Perf regression check FAILED"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Perf regression check PASSED"
exit 0
