# CodeBar — Product objective and outside research

Written 2026-08-12. A snapshot, not a living document: the code changes daily,
but the outside world it describes — the FY2027 release, the V28 phase-in, what
the competing tools do — moves on its own schedule. Re-check before acting on
anything here, and record what you find rather than editing this in place.

Everything below the objective came from web research, not from the repo. Where
a claim has not been verified by downloading the file in question, it says so.

## The objective

Never written down anywhere, so here it is, reconstructed from
[README.md](../README.md) and [ARCHITECTURE.md](ARCHITECTURE.md):

> Fast clinical code lookup as a system-wide reflex — ⌥⌘C, type, Return, the
> code is on the clipboard — backed by the complete official releases, working
> offline, with the clinician's own data on a lifecycle separate from the code
> index.

Three constraints follow from decisions already made, and any feature should be
judged against them before it is judged on merit:

1. **No network at lookup time.** Sandboxed, no permission prompts, nothing about
   a patient leaves the machine. This is a property to defend, not an accident of
   scope.
2. **The publisher's data is authoritative; CodeBar does not make clinical
   judgements.** [Abbreviations](../README.md#your-own-shorthand) expand to
   *words*, never to codes, for exactly this reason. So does the refusal to
   promote *unspecified* codes by rule.
3. **Derived and user data never mix.** Two SQLite files, opposite lifecycles.

## Findings

Ordered by value, not by effort.

### 1. FY2027 lands on 1 October 2026, and replace semantics will orphan pins

CMS posted the FY2027 ICD-10-CM files in June 2026: **190 new, 30 deleted, 4
revised**, effective for encounters from 1 October 2026, spanning 33 clinical
topics across nearly every chapter.

`"mode": "replace"` is the right semantics — a release is the complete set for
its year — but the consequence has not been designed for. Those 30 deleted codes
disappear from `codes.sqlite` while `library.sqlite` still holds pins, list
memberships and notes pointing at them. The two databases cannot see each other,
which is the point of the split, so nothing currently notices.

| Work | Why |
|---|---|
| Reconcile orphans after import | A pinned code that no longer exists should read *retired in FY2027*, not vanish. CMS ships an **addendum** and a **conversion table** with the release — a retired→successor map, already in the download |
| A "what changed this year" view | The changeover is the one calendar event that sends coders looking. ~224 changes is browsable. It is a diff of two order files, which `import_icd10_cms.py` already parses |
| Show which release is installed | Nothing today says FY2026, or that a code was valid last year and is not today. Dates of service before 1 October still need the old set |

The only item here with an external deadline.

### 2. The frequency data that "CodeBar does not have" appears to exist

The repo's own conclusion on ranking was that weighting by real usage frequency
would be *correct, and needs data CodeBar does not have*. That is the one
conclusion the research contradicts — see [known limits](../README.md#known-limits)
for where the ranking question currently rests.

- **AHRQ HCUP** publishes annual discharge counts for every individual ICD-10-CM
  code in the *Data Elements* section of the NIS documentation — free, no data
  use agreement. HCUPnet's interactive tool dropped per-code queries; the counts
  moved into the documentation files. **Not verified by download.** It is also
  inpatient-only, so it will over-weight admitted conditions against an
  outpatient-leaning set.
- **CMS's 2026 risk-adjustment ICD-10 mappings** are a public download, and mark
  which codes carry payment weight. A different signal, but a usable proxy for
  the codes clinicians are under pressure to get right.

**Why this reopens a closed question narrowly.** Ranking within a family
was closed on the finding that N18.1, N18.31, N18.32 and N18.5 tie to two decimal
places, leaving `LENGTH(code), code` as the tiebreak. That closure is correct
about relevance and stays correct. But the tiebreak it leaves in place is
arbitrary, and swapping *only the tiebreak* for a frequency weight:

- changes nothing about BM25, and so cannot regress the queries that already rank
  correctly;
- does not promote *unspecified* by rule — the objection that killed that idea in
  phase 7 — it promotes what is actually billed, which is a measurement;
- is not the code-length heuristic, which was measured and found worse than
  nothing. **Do not retry that one.**
- fixes cold start, which pinning cannot: the first search on a fresh install has
  no usage history to rank on.

Shape it like everything else: an optional weights file keyed on system + code,
imported the way a code set is, so an unweighted install behaves exactly as it
does today.

### 3. Specificity is where the denials are

The denial literature converges on three causes. All three are *lookup-time*
problems, all three are structural rather than clinical, and the data for all
three is in files already parsed.

| Cause | What CodeBar could do | Source data |
|---|---|---|
| Unspecified overuse — payers flag it as insufficient medical necessity | Badge the unspecified sibling; show the specific ones beside it | Tabular XML |
| Missing 7th character — an invalid code, rejected at the front-end edit level with no human review | Decline to copy a stub; offer the initial/subsequent/sequela picker inline | Tabular XML extensions |
| Laterality mismatch — automatic edit failure | Surface left/right/bilateral siblings as a chooser | Descriptions + hierarchy |

This is the `Excludes 1` idea carried one step further, and it stays inside
constraint 2: it re-presents CMS's own structural rules rather than deciding what
the patient has. A tool that stops you copying an incomplete code is a different
product from a tool that finds codes quickly.

### 4. Risk adjustment

V28 is at **100% phase-in for payment year 2026**; V24 is retired. 115 payment
categories, and roughly **7,903 of 74,719 billable codes carry RAF weight**. The
crosswalk is a free CMS download.

A per-code badge and a "risk-adjusting only" filter. Small surface, large
audience — every commercial tool leads with it, because it is the second question
after *what is the code*.

### 5. Where the competition is, and is not

The field is web tools (icd10data, ICDList, AAPC Codify) and App Store reference
apps (CodeIQ, ICD 10 2026, Unbound). A search specifically for menu-bar, Alfred
or Raycast ICD-10 tools returned **nothing**, which supports the current bet.

- **Worth taking**: a Raycast or Alfred extension, and Shortcuts / App Intents.
  The same index, almost no new surface, and it meets people where they already
  type.
- **Parity gap the competitors advertise**: cross-device sync of favourites and
  folders. Raises the priority of the iCloud item already carried forward.
- **Worth refusing**: AI natural-language → code, as icdcodes.ai and others do.
  It needs the network, breaks constraint 1, and puts the app in the business of
  the clinical judgement constraint 2 exists to avoid.

### 6. Smaller items the research supports

- **User-editable synonyms** — already a known gap. Competing tools advertise
  ~140 abbreviations against the 23 compiled in, and a file beats a rebuild.
- **The SNOMED ↔ ICD-10-CM crosswalk is closer than the roadmap assumes.** NLM
  publishes the map, and both terminologies are free for US use. It needs a UMLS
  account, not a commercial licence.
- **AHRQ CCSR** groups ICD-10-CM into clinical categories, free. A second
  navigation axis alongside chapters, and the grouping layer any "related codes"
  feature would want.

## If only three

1. The FY2027 changeover — it has a date on it.
2. The frequency-weighted tiebreak — reopens the best-documented open problem in
   the repo, narrowly, with data that turns out to exist.
3. The 7th-character and laterality guard — the thing that makes it a coding tool
   rather than a search box.

## Sources

- [CMS posts the FY 2027 ICD-10-CM update](https://www.ahcancal.org/News-and-Communications/Blog/Pages/CMS-Posts-FY-2027-ICD-10-CM-Update-Effective-Oct.-1.aspx)
- [FY 2027 ICD-10-CM code updates — AGS Health](https://www.agshealth.com/blog/fy-2027-icd-10-cm-code-updates-what-coders-and-revenue-cycle-teams-need-to-know/)
- [ICD-10 — CMS](https://www.cms.gov/medicare/coding-billing/icd-10-codes)
- [HCUPnet data tools — AHRQ](https://datatools.ahrq.gov/hcupnet/)
- [HCUP NIS introduction — per-code counts live in Data Elements](https://hcup-us.ahrq.gov/db/nation/nis/NIS_Introduction_2018.jsp)
- [HCUP research tools, including CCSR](https://hcup-us.ahrq.gov/tools_software.jsp)
- [2026 model software / ICD-10 mappings — CMS](https://www.cms.gov/medicare/payment/medicare-advantage-rates-statistics/risk-adjustment/2026-model-software-icd-10-mappings)
- [SNOMED CT to ICD-10-CM map — NLM](https://www.nlm.nih.gov/research/umls/mapping_projects/snomedct_to_icd10cm.html)
- [Top 10 ICD-10 coding errors that cause claim denials in 2026](https://www.viaante.com/resource-center/blogs/icd-10-coding-errors-claim-denials/)
- [Why unspecified ICD-10 codes get claims denied](https://www.medicalbillersandcoders.com/article/why-unspecified-icd-10-codes-get-claims-denied.html)
- [ICD-10 to HCC mapping, V28 crosswalk — HCC Buddy](https://hccbuddy.com/icd10-to-hcc)
- [What is HCC coding — ICD10Source](https://icd10source.com/what-is-hcc-coding)
- [CodeIQ, ICD-10 coding tool — Mac App Store](https://apps.apple.com/us/app/codeiq-icd-10-coding-tool/id6760373031)
- [ICDcodes.ai — how it works](https://icdcodes.ai/how-it-works)
- [icd10data.com](https://www.icd10data.com/)
