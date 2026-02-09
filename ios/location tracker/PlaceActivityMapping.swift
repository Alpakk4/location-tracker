//
//  PlaceActivityMapping.swift
//  location tracker
//
//  Maps Google Places API Table A primary_type values to broad activity labels.
//  Reference: https://developers.google.com/maps/documentation/places/web-service/place-types#table-a
//

import Foundation

struct PlaceActivityMapping {

    /// Returns the activity label for a given Google Places primary_type.
    static func activityLabel(for primaryType: String) -> String {
        return mapping[primaryType] ?? "Visiting"
    }

    // MARK: - Full Mapping Dictionary

    private static let mapping: [String: String] = {
        var m = [String: String]()

        // Automotive -> Vehicle Services
        let automotive = [
            "car_dealer", "car_rental", "car_repair", "car_wash",
            "electric_vehicle_charging_station", "gas_station", "parking", "rest_stop"
        ]
        for t in automotive { m[t] = "Vehicle Services" }

        // Business -> Working
        let business = ["corporate_office", "farm", "ranch"]
        for t in business { m[t] = "Working" }

        // Culture -> Visiting
        let culture = [
            "art_gallery", "art_studio", "auditorium", "cultural_landmark",
            "historical_place", "monument", "museum", "performing_arts_theater", "sculpture"
        ]
        for t in culture { m[t] = "Visiting" }

        // Education -> Studying
        let education = [
            "library", "preschool", "primary_school", "school",
            "secondary_school", "university"
        ]
        for t in education { m[t] = "Studying" }

        // Entertainment and Recreation -> Leisure
        let entertainment = [
            "adventure_sports_center", "amphitheatre", "amusement_center", "amusement_park",
            "aquarium", "banquet_hall", "barbecue_area", "botanical_garden", "bowling_alley",
            "casino", "childrens_camp", "comedy_club", "community_center", "concert_hall",
            "convention_center", "cultural_center", "cycling_park", "dance_hall", "dog_park",
            "event_venue", "ferris_wheel", "garden", "hiking_area", "historical_landmark",
            "internet_cafe", "karaoke", "marina", "movie_rental", "movie_theater",
            "national_park", "night_club", "observation_deck", "off_roading_area", "opera_house",
            "park", "philharmonic_hall", "picnic_ground", "planetarium", "plaza",
            "roller_coaster", "skateboard_park", "state_park", "tourist_attraction",
            "video_arcade", "visitor_center", "water_park", "wedding_venue", "wildlife_park",
            "wildlife_refuge", "zoo"
        ]
        for t in entertainment { m[t] = "Leisure" }

        // Facilities -> Using Facilities
        let facilities = ["public_bath", "public_bathroom", "stable"]
        for t in facilities { m[t] = "Using Facilities" }

        // Finance -> Banking
        let finance = ["accounting", "atm", "bank"]
        for t in finance { m[t] = "Banking" }

        // Food and Drink -> Eating/Drinking
        let foodAndDrink = [
            "acai_shop", "afghani_restaurant", "african_restaurant", "american_restaurant",
            "asian_restaurant", "bagel_shop", "bakery", "bar", "bar_and_grill",
            "barbecue_restaurant", "brazilian_restaurant", "breakfast_restaurant",
            "brunch_restaurant", "buffet_restaurant", "cafe", "cafeteria", "candy_store",
            "cat_cafe", "chinese_restaurant", "chocolate_factory", "chocolate_shop",
            "coffee_shop", "confectionery", "deli", "dessert_restaurant", "dessert_shop",
            "diner", "dog_cafe", "donut_shop", "fast_food_restaurant", "fine_dining_restaurant",
            "food_court", "french_restaurant", "greek_restaurant", "hamburger_restaurant",
            "ice_cream_shop", "indian_restaurant", "indonesian_restaurant", "italian_restaurant",
            "japanese_restaurant", "juice_shop", "korean_restaurant", "lebanese_restaurant",
            "meal_delivery", "meal_takeaway", "mediterranean_restaurant", "mexican_restaurant",
            "middle_eastern_restaurant", "pizza_restaurant", "pub", "ramen_restaurant",
            "restaurant", "sandwich_shop", "seafood_restaurant", "spanish_restaurant",
            "steak_house", "sushi_restaurant", "tea_house", "thai_restaurant",
            "turkish_restaurant", "vegan_restaurant", "vegetarian_restaurant",
            "vietnamese_restaurant", "wine_bar"
        ]
        for t in foodAndDrink { m[t] = "Eating/Drinking" }

        // Geographical Areas -> Visiting
        let geographical = [
            "administrative_area_level_1", "administrative_area_level_2",
            "country", "locality", "postal_code", "school_district"
        ]
        for t in geographical { m[t] = "Visiting" }

        // Government -> Government Services
        let government = [
            "city_hall", "courthouse", "embassy", "fire_station", "government_office",
            "local_government_office", "neighborhood_police_station", "police", "post_office"
        ]
        for t in government { m[t] = "Government Services" }

        // Health and Wellness -> Healthcare
        let health = [
            "chiropractor", "dental_clinic", "dentist", "doctor", "drugstore", "hospital",
            "massage", "medical_lab", "pharmacy", "physiotherapist", "sauna",
            "skin_care_clinic", "spa", "tanning_studio", "wellness_center", "yoga_studio"
        ]
        for t in health { m[t] = "Healthcare" }

        // Housing -> At Home
        let housing = [
            "apartment_building", "apartment_complex", "condominium_complex", "housing_complex"
        ]
        for t in housing { m[t] = "At Home" }

        // Lodging -> Staying
        let lodging = [
            "bed_and_breakfast", "budget_japanese_inn", "campground", "camping_cabin",
            "cottage", "extended_stay_hotel", "farmstay", "guest_house", "hostel", "hotel",
            "inn", "japanese_inn", "lodging", "mobile_home_park", "motel",
            "private_guest_room", "resort_hotel", "rv_park"
        ]
        for t in lodging { m[t] = "Staying" }

        // Natural Features -> Outdoors
        let natural = ["beach"]
        for t in natural { m[t] = "Outdoors" }

        // Places of Worship -> Worshipping
        let worship = ["church", "hindu_temple", "mosque", "synagogue"]
        for t in worship { m[t] = "Worshipping" }

        // Services -> Errands
        let services = [
            "astrologer", "barber_shop", "beautician", "beauty_salon", "body_art_service",
            "catering_service", "cemetery", "child_care_agency", "consultant",
            "courier_service", "electrician", "florist", "food_delivery", "foot_care",
            "funeral_home", "hair_care", "hair_salon", "insurance_agency", "laundry",
            "lawyer", "locksmith", "makeup_artist", "moving_company", "nail_salon",
            "painter", "plumber", "psychic", "real_estate_agency", "roofing_contractor",
            "storage", "summer_camp_organizer", "tailor",
            "telecommunications_service_provider", "tour_agency",
            "tourist_information_center", "travel_agency", "veterinary_care"
        ]
        for t in services { m[t] = "Errands" }

        // Shopping -> Shopping
        let shopping = [
            "asian_grocery_store", "auto_parts_store", "bicycle_store", "book_store",
            "butcher_shop", "cell_phone_store", "clothing_store", "convenience_store",
            "department_store", "discount_store", "electronics_store", "food_store",
            "furniture_store", "gift_shop", "grocery_store", "hardware_store",
            "home_goods_store", "home_improvement_store", "jewelry_store", "liquor_store",
            "market", "pet_store", "shoe_store", "shopping_mall", "sporting_goods_store",
            "store", "supermarket", "warehouse_store", "wholesaler"
        ]
        for t in shopping { m[t] = "Shopping" }

        // Sports -> Exercising
        let sports = [
            "arena", "athletic_field", "fishing_charter", "fishing_pond", "fitness_center",
            "golf_course", "gym", "ice_skating_rink", "playground", "ski_resort",
            "sports_activity_location", "sports_club", "sports_coaching", "sports_complex",
            "stadium", "swimming_pool"
        ]
        for t in sports { m[t] = "Exercising" }

        // Transportation -> Commuting
        let transportation = [
            "airport", "airstrip", "bus_station", "bus_stop", "ferry_terminal", "heliport",
            "international_airport", "light_rail_station", "park_and_ride", "subway_station",
            "taxi_stand", "train_station", "transit_depot", "transit_station", "truck_stop"
        ]
        for t in transportation { m[t] = "Commuting" }

        return m
    }()
}
