/**
 * Maps place categories (from place-types.ts) to human-readable activity labels.
 * Mirrors the intent of PlaceActivityMapping.swift but keyed by ~19 categories
 * rather than ~500 individual primary_types.
 */
const categoryActivityMap: Record<string, string> = {
  "Automotive":              "Vehicle Services",
  "Business":                "Working",
  "Culture":                 "Visiting",
  "Education":               "Studying",
  "Entertainment/Recreation":"Leisure",
  "Facilities":              "Using Facilities",
  "Finance":                 "Banking",
  "Food and Drink":          "Eating/Drinking",
  "Geographical Areas":      "Visiting",
  "Government":              "Government Services",
  "Health and Wellness":     "Healthcare",
  "Housing":                 "Visiting",
  "Home":                    "Residing",
  "Lodging":                 "Staying",
  "Natural Features":        "Outdoors",
  "Places of Worship":       "Worshipping",
  "Services":                "Errands",
  "Shopping":                "Shopping",
  "Sports":                  "Exercising",
  "Transportation":          "Commuting",
};

export const getActivityForCategory = (category: string): string => {
  return categoryActivityMap[category] ?? "Visiting";
};
