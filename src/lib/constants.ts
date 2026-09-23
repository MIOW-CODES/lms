/**
 * Curated baseline options for the creatable department/specialization dropdowns.
 *
 * These are only *seeds*: the admin teacher forms and the teacher settings page
 * merge them with the distinct `profiles.department` values already stored in the
 * database, so any custom department an admin has typed before still appears.
 * Admins can always add a brand-new value inline via `CreatableSelect`.
 */
export const DEFAULT_DEPARTMENTS = [
  "Mathematics",
  "Science",
  "English",
  "Technology & Livelihood Education (TLE)",
  "Social Studies (Araling Panlipunan)",
  "Filipino",
  "MAPEH",
  "Computer Studies",
  "Values Education / EsP",
  "Senior High School (SHS) Faculty",
  "College of Education (CED) Faculty",
];

/**
 * Curated baseline options for the creatable student-section dropdowns.
 *
 * Merged with the distinct `profiles.section` values already in the database so
 * admins can pick an existing section or type a brand-new one inline.
 */
export const DEFAULT_STUDENT_SECTIONS = [
  "Rizal",
  "Bonifacio",
  "Mabini",
  "Luna",
  "Del Pilar",
  "Aguinaldo",
  "Silang",
  "Jacinto",
  "Gomez",
  "Burgos",
  "Zamora",
  "Lapu-Lapu",
];

/** Sentinel used in component state to mean "no section filter applied". */
export const ALL_SECTIONS_VALUE = "all";

/** Label of the reset option shown in a section filter dropdown. */
export const ALL_SECTIONS_LABEL = "All sections";

/**
 * Normalize a raw dropdown value into a section-filter state value. An empty
 * value (cleared) or the reset label both map to {@link ALL_SECTIONS_VALUE};
 * every other value passes through unchanged.
 */
export function resolveSectionFilter(value: string): string {
  return !value || value === ALL_SECTIONS_LABEL ? ALL_SECTIONS_VALUE : value;
}
