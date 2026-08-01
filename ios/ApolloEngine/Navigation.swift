//
//  Navigation.swift
//  ApolloEngine
//
//  Type-safe navigation destinations.
//

import SwiftUI

enum NavRoute: Hashable {
    case subject(String)        // landing detail (phase hub)
    case intake(String)         // evidence-stream editor
    case processing(String)
    case review(String)
    case dspReport(String)
    case esoteric(String)
    case unified(String)
}

enum AppTab: Hashable {
    case dashboard, reports, settings
}
