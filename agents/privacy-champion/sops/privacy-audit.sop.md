# Privacy Audit — Standard Operating Procedure

> Referenced by: `taskrails/privacy-audit.taskrail.json`
> Owner: Privacy Champion agent
> Version: 0.1.0

## Purpose

This SOP defines the execution methodology for the privacy audit taskrail.
While the taskrail provides the WHAT (constraints and validation gates),
this SOP provides the HOW (techniques, error handling, edge cases).

## Pre-Audit Checklist

Before starting the audit taskrail:

- [ ] Confirm write access to the workspace directory for logs and backups
- [ ] Verify required tools: bash, curl or wget, jq, python3 (preferred) or python
- [ ] Check if running as admin/root — note which surfaces will be unreachable if not
- [ ] Confirm the surface catalog file exists and is readable
- [ ] Warn if any detected browser is not in the catalog

## Step Execution Guidance

### Step 1: Fingerprint

Run `scripts/fingerprint.sh`. Parse the JSON output. Do not summarize — the
exact OS version string matters because surface catalogs are version-gated.

If fingerprint returns unknown for any field, flag it explicitly. An unknown OS
means the surface catalog won't match — the audit can still run against
browser surfaces (which are platform-agnostic).

### Step 2: Enumerate

Load `data/surface-catalog.json`. Match against OS family and version. For
each detected browser, include all browser surfaces. Include platform-agnostic
browser surfaces even if the OS catalog is sparse.

If the OS family is `unknown`, enumerate only browser and network surfaces.
Skip OS surfaces entirely rather than guessing.

### Step 3: Probe

For each surface, execute the `probe_method`. Parse the result. Classify:
- `enabled` — surface is active and transmitting
- `disabled` — surface is confirmed off
- `partially_enabled` — some aspect is on (e.g., basic telemetry vs full)
- `unknown` — probe failed, permission denied, path not found, version mismatch

For `unknown`, record the specific error. Common causes:
- Registry key doesn't exist (not applicable to this version)
- Config file path differs (version-specific path)
- Permission denied (need elevated privileges)
- Tool not available (e.g., `reg` not on Linux)

### Step 4: Classify

Rate each enabled or partially-enabled surface:

**Severity:**
- HIGH: Identity-exfiltrating, PII leakage, keystroke data, location tracking
- MEDIUM: Usage profiling, behavioral tracking, feature usage
- LOW: Crash diagnostics only, minimal data, de-identified

**Tier assignment:**
- TIER_1: HIGH severity + REVERSIBLE + NONE/MINOR impact → APPLY automatically if user approves tier
- TIER_2: MEDIUM severity + REVERSIBLE + NONE/MINOR impact → RECOMMEND
- TIER_3: Any severity + PARTIALLY_REVERSIBLE or MODERATE impact → REVIEW individually
- TIER_4: Any severity + IRREVERSIBLE or MAJOR impact → SKIP by default, user must explicitly opt in

### Step 5: Approval Gate

This is a HARD STOP. Do not proceed until the user responds.

Present findings in this order:
1. Summary: X surfaces found, Y enabled, Z recommended for closure
2. Tier 1 (green): "These have clear privacy benefit and no noticeable impact"
3. Tier 2 (yellow): "These improve privacy with minor tradeoffs"
4. Tier 3 (orange): "These have meaningful tradeoffs — review individually"
5. Tier 4 (red): "These have major impact — not recommended without specific need"

Ask: "Approve Tier 1 only, Tiers 1+2, Tiers 1+2+3, or select individual surfaces?"

### Step 6: Apply

Apply closures in dependency order: services first, then config files, then
registry/preferences. If a service is disabled, the config it reads won't matter.

For each closure:
1. Record before-state (from probe)
2. Execute closure method
3. Record after-state (immediate check)
4. Log: surface_id, method, before, after, timestamp

If a closure fails:
- Log the failure with the exact error
- Continue with remaining surfaces
- Do NOT retry automatically (some failures are persistent)

### Step 7: Verify

Re-probe every surface modified in step 6. Use the same probe method.

For each:
- Confirmed: new state matches expected DISABLED
- Failed: state reverted or probe still shows enabled
- Investigate failures for common causes: update reverted the change, method insufficient, dependency blocked the closure

Flag all failures in the verification report.

### Step 8: Report

Structure the final report:

```
# Privacy Audit Report
{timestamp}

## System
{fingerprint summary}

## Results Summary
- Surfaces audited: {N}
- Closed: {N}
- Failed to close: {N}
- Declined by user: {N}
- Could not address (gaps): {N}

## Changes Applied
| Surface | Method | Before | After | Reversible |
|---------|--------|--------|-------|------------|

## Closures That Failed
| Surface | Attempted Method | Error | Suggested Action |
|---------|-----------------|-------|-----------------|

## Surfaces Declined
| Surface | Tier | User's Reason (if given) |
|---------|------|-------------------------|

## Remaining Gaps
{Surfaces that could not be addressed with rationale}

## Rollback Instructions
{For each change, the exact command to reverse it}

## Next Steps
- Browser extensions recommended
- VPN/DNS-over-HTTPS consideration
- Future audits: after OS update, after browser update, quarterly

## Re-audit Recommendation
{When to run this again}
```

## Error Recovery

| Scenario | Action |
|----------|--------|
| Fingerprint fails completely | Report what could be detected, proceed with browser-only audit |
| Surface catalog missing | Report the gap, suggest adding the platform to the catalog |
| Probe returns unknown for many surfaces | Flag as high-risk — audit quality is degraded |
| Closure method fails mid-execution | Log, continue, flag in final report |
| Verification shows many failures | Flag as high-risk — something is reverting changes |
| Script execution error | Fall back to documented manual method if available |