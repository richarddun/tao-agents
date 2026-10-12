# Approval-gate prompt

Reusable presentation prompt for step 5 of the audit taskrail. This is a
**hard stop**: present the plan and wait for an explicit decision. Do not
apply anything, and do not infer approval from earlier runs or context.

---

Present the findings in this order, using the exact headings below.

**1. Summary**

> Audited {N} surfaces. {E} are enabled. I recommend closing {R} of them.
> {U} could not be probed (reported as UNKNOWN). {G} are gaps not covered by
> the catalog.

**2. Tier 1 — clear privacy win, no noticeable impact (green)**

> These are safe to close and you will not notice a difference.

**3. Tier 2 — privacy win, minor impact (yellow)**

> These improve privacy with a small trade-off, e.g. a preference resets.

**4. Tier 3 — meaningful trade-off, review individually (orange)**

> Each of these removes a feature you may use. I list the "what you give up"
> for each.

**5. Tier 4 — major impact, not recommended by default (red)**

> I do not recommend these unless you have a specific need. They are listed
> for completeness only.

**6. Question**

> Reply with one of: `Tier 1`, `Tiers 1+2`, `Tiers 1+2+3`, or name the
> individual surface IDs you want closed. Reply `none` to produce a report
> of what could be changed without changing anything.

---

Rules for the model presenting this gate:

- Never apply a change in the same turn you present the gate.
- Never bundle an unapproved surface with an approved tier.
- Flag every IRREVERSIBLE change explicitly.
- If the user declines a surface, record it as DECLINED and move on — do not
  re-present it.
