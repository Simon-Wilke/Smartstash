//
//  CategoryIconMapping.swift
//  SimpleBudgetManager
//
//  Created by Simon Wilke on 12/8/24.
//

// CategoryIconMapping.swift

import Foundation

// This is the shared category-to-icon mapping
struct CategoryIconMapping {
    static let mapping: [String: String] = [
        // Food-related categories
        "food": "🍎",          // General food category
        "culver's": "🍎",      // Specific restaurant
        "chipotle": "🍎",      // Chipotle
        "mcdonald's": "🍎",    // McDonald's
        "pasta": "🍎",         // Pasta
        "pizza": "🍎",         // Pizza
        "restaurant": "🍎",    // Restaurant
        "groceries": "🍎",     // Groceries
        "whole foods": "🍎",   // Whole Foods
        "trader joe's": "🍎",  // Trader Joe's

        // Celebration-related categories
        "party": "🎉",          // Party
        "event": "🎉",          // Event
        "wedding": "🎉",        // Wedding
        "new year": "🎉",       // New Year
        "graduation": "🎉",     // Graduation
        "anniversary": "🎉",    // Anniversary

        // Housing-related categories
        "rent": "🏠",           // Rent
        "mortgage": "🏠",       // Mortgage
        "housing": "🏠",        // Housing
        "home": "🏠",           // Home
        "apartment": "🏠",      // Apartment
        "landlord": "🏠",       // Landlord
        "real estate": "🏠",    // Real Estate
        "utility": "🏠",        // Utility

        // Gift-related categories
        "gift": "🎁",           // Gift
        "holiday": "🎁",        // Holiday
        "christmas": "🎁",      // Christmas
        "birthday": "🎁",       // Birthday
        "present": "🎁",        // Present
        "treat": "🎁",          // Treat
        "special": "🎁",        // Special gift
        "gifting": "🎁",        // Gifting

        // Payment-related categories
        "credit": "💳",         // Credit
        "payment": "💳",        // Payment
        "bill": "💳",           // Bill
        "debt": "💳",           // Debt
        "subscription": "💳",   // Subscription


        // Shopping-related categories
        "shopping": "🛒",       // Shopping
        // Groceries
        "clothes": "🛒",        // Clothing
        "electronics": "🛒",    // Electronics
        "store": "🛒",          // Store
        "mall": "🛒",           // Mall
        "walmart": "🛒",        // Walmart
        "best buy": "🛒",       // Best Buy
        "target": "🛒",         // Target
        "ebay": "🛒",           // eBay

        // Transportation-related categories
        "car": "🚗",            // Car
        "transport": "🚗",      // Transport
        "gas": "🚗",            // Gas
        "fuel": "🚗",           // Fuel
        "ride": "🚗",           // Ride
        "uber": "🚗",           // Uber
        "lyft": "🚗",           // Lyft
        "taxi": "🚗",           // Taxi


        // Banking-related categories
        "bank": "🏦",           // Bank
        "savings": "🏦",        // Savings
        "loan": "🏦",           // Loan
        "checking": "🏦",       // Checking
        "investment": "🏦",     // Investment
        "atm": "🏦",            // ATM
        "credit card": "🏦",    // Credit card
        "finance": "🏦",
        "check": "🏦",

        // Footwear-related categories using a single shoe emoji
        "shoes": "👟",
        "clothing": "👟",
        "sneakers": "👟",
        "athletic": "👟",
        "running shoes": "👟",
        "joggers": "👟",
        "trainers": "👟",
        "boots": "👟",
        "hiking boots": "👟",
        "work boots": "👟",
        "cleats": "👟",
        "soccer cleats": "👟",
        "football cleats": "👟",
        "basketball shoes": "👟",
        "sandals": "👟",
        "flip flops": "👟",
        "loafers": "👟",
        "formal shoes": "👟",
        "heels": "👟",
        "high heels": "👟",
        "stilettos": "👟",
        "pumps": "👟",
        "slippers": "👟",
        "crocs": "👟",
        "moccasins": "👟",

        // Popular brands & models
        "uggs": "👟",           // Uggs brand
        "ugg boots": "👟",
        "air max": "👟",        // Nike Air Max
        "jordans": "👟",        // Air Jordans
        "yeezy": "👟",          // Adidas Yeezy
        "converse": "👟",       // Converse All-Stars
        "vans": "👟",           // Vans skate shoes
        "new balance": "👟",    // New Balance
        "reebok": "👟",         // Reebok
        "puma": "👟",           // Puma
        "asics": "👟",          // Asics running shoes
        "fila": "👟",           // Fila sneakers
        "under armour": "👟",   // Under Armour shoes

        // Slang & niche terms
        "kicks": "👟",         // Slang for sneakers
        "runners": "👟",       // Another term for running shoes
        "slides": "👟",        // Slide sandals
        "chucks": "👟",        // Converse Chuck Taylors
        "foam runners": "👟",  // Yeezy Foam Runners
        "skate shoes": "👟",   // Skateboarding shoes
        "high tops": "👟",     // High-top sneakers
        "lows": "👟",          // Low-top sneakers
        "mid tops": "👟",      // Mid-top sneakers
        "trail shoes": "👟",   // Trail running shoes
        
        "coffee": "☕",
        "starbucks": "☕",
        "caribou": "☕",
        "cafe": "☕",
        "espresso": "☕",
        "latte": "☕",
        "cappuccino": "☕",
        "macchiato": "☕",
        "americano": "☕",
        "mocha": "☕",
        "cold brew": "☕",
        "nitro coffee": "☕",
        "iced coffee": "☕",
        "frappuccino": "☕",
        "drip coffee": "☕",
        "brew": "☕",
        "roast": "☕",
        "barista": "☕",
        "java": "☕",
        "caffeine": "☕",
        "morning brew": "☕",

        
        
        "amazon": "amazon_logo",
        "disney": "newdisney_logo",
        "disney+": "newdisney_logo",
        "disney plus": "newdisney_logo",
        "apple music": "apple_music_logo",
        "spotify": "spotify_logo",
        "peleton": "peletonlogo_logo",
        "netflix": "netflix_logo",
        "adobe": "adobecloud_logo",
    ]
}
