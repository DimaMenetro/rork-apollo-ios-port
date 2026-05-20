//
//  SubjectStore.swift
//  ApolloEngine
//
//  Lightweight @Observable wrapper around ModelContext for batch ops + haptics.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

@Observable
final class SubjectStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func createSubject(name: String) -> Subject {
        let s = Subject(name: name)
        context.insert(s)
        try? context.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        return s
    }

    func delete(_ subject: Subject) {
        context.delete(subject)
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func save() {
        try? context.save()
    }

    func touch(_ subject: Subject) {
        subject.updatedAt = Date()
        try? context.save()
    }
}

@MainActor
private struct SubjectStoreKey: EnvironmentKey {
    static let defaultValue: SubjectStore? = nil
}

extension EnvironmentValues {
    var subjectStore: SubjectStore? {
        get { self[SubjectStoreKey.self] }
        set { self[SubjectStoreKey.self] = newValue }
    }
}
