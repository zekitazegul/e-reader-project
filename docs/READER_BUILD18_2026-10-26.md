# E-reader build 18 — 2026-10-26

Library scans prefer EPUB when the source MOBI/PRC has the same full filename
stem. Author and volume suffixes are preserved in matching. Existing verified
conversion fingerprints also hide the source if the EPUB has a different name.
Sources with no corresponding EPUB remain visible. Filtering is applied before
sorting and layout, so grid, list and counts agree. Original source files remain
on disk; no deletion is performed. History and annotations are preserved.

Validation covers source/EPUB ordering, PRC and case variants, distinct volumes,
missing converted files, renamed EPUBs with verified fingerprints, and reopening
the EPUB from the library after conversion without adding another copy.
