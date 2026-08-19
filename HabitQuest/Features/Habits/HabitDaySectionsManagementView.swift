import SwiftUI

struct HabitDaySectionsManagementView: View {
    @Environment(\.habitQuestEnvironment) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var customSections: [HabitDaySection] = []
    @State private var presentedEditor: HabitDaySectionEditorDraft?
    @State private var loadErrorMessage: String?
    @State private var showingDeleteConfirmation = false
    @State private var sectionPendingDeletion: HabitDaySection?

    var body: some View {
        NavigationStack {
            ZStack {
                HabitQuestScreenBackground()

                ScrollView {
                    VStack(spacing: HabitQuestDesignSystem.Spacing.lg) {
                        headerCard
                        if let loadErrorMessage {
                            errorCard(message: loadErrorMessage)
                        }
                        builtInSectionsCard
                        customSectionsCard
                    }
                    .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                    .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                    .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Day Sections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HabitQuestDesignSystem.Palette.background(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        presentedEditor = HabitDaySectionEditorDraft.newSection()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("Add section"))
                }
            }
            .task {
                loadSections()
            }
            .sheet(item: $presentedEditor) { draft in
                HabitDaySectionEditorView(
                    draft: draft,
                    onCancel: {
                        presentedEditor = nil
                    },
                    onSave: { updatedSection in
                        save(updatedSection)
                        presentedEditor = nil
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
            }
            .confirmationDialog(
                "Delete this section?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete section", role: .destructive) {
                    if let sectionPendingDeletion {
                        delete(sectionPendingDeletion)
                    }
                }
                Button("Cancel", role: .cancel) {
                    sectionPendingDeletion = nil
                }
            } message: {
                Text("This only removes the custom section. Habits assigned to it will keep their assignment until you change it.")
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text("Shape your routines")
                .font(HabitQuestDesignSystem.Typography.title2)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text("Built-in sections stay available for a quick structure. Custom sections can be added when you want HabitQuest to match your day more closely.")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var builtInSectionsCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("Built-in sections")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                ForEach(HabitDaySectionCatalog.builtInSections) { section in
                    sectionRow(section)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var customSectionsCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Custom sections")
                        .font(HabitQuestDesignSystem.Typography.headline)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                    Text("These stay local and remain available if Premium is restored later.")
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }

                Spacer(minLength: 0)

                Button {
                    presentedEditor = HabitDaySectionEditorDraft.newSection(order: nextOrderValue)
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .habitQuestGlassButtonStyle()
            }

            if customSections.isEmpty {
                Text("No custom sections yet.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            } else {
                VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    ForEach(customSections.sorted(by: { $0.order < $1.order })) { section in
                        Button {
                            presentedEditor = HabitDaySectionEditorDraft(section: section)
                        } label: {
                            sectionRow(section)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Edit") {
                                presentedEditor = HabitDaySectionEditorDraft(section: section)
                            }

                            Button("Delete", role: .destructive) {
                                sectionPendingDeletion = section
                                showingDeleteConfirmation = true
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
            Label("Could not load sections", systemImage: "exclamationmark.triangle")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
            Text(message)
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private func sectionRow(_ section: HabitDaySection) -> some View {
        HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
            Circle()
                .fill(HabitQuestDesignSystem.Palette.accent(for: colorScheme).opacity(0.16))
                .frame(width: 38, height: 38)
                .overlay(
                    Text(section.displayIcon)
                        .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(section.displayTitle)
                        .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                    Spacer(minLength: 0)
                    Text("#\(section.order)")
                        .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                }

                if let notes = section.contextualNotes, !notes.isEmpty {
                    Text(notes)
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HabitQuestDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                        .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                )
        )
    }

    private var nextOrderValue: Int {
        (customSections.map(\.order).max() ?? HabitDaySectionCatalog.builtInSections.count - 1) + 1
    }

    private func loadSections() {
        do {
            customSections = try environment.habitDaySectionStore.loadSections()
            loadErrorMessage = nil
        } catch {
            customSections = []
            loadErrorMessage = error.localizedDescription
        }
    }

    private func save(_ section: HabitDaySection) {
        do {
            try environment.habitDaySectionStore.upsertSection(section)
            loadSections()
        } catch {
            loadErrorMessage = error.localizedDescription
        }
    }

    private func delete(_ section: HabitDaySection) {
        do {
            var sections = try environment.habitDaySectionStore.loadSections()
            sections.removeAll { $0.id == section.id }
            try environment.habitDaySectionStore.saveSections(sections)
            loadSections()
            sectionPendingDeletion = nil
        } catch {
            loadErrorMessage = error.localizedDescription
        }
    }
}

private struct HabitDaySectionEditorDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var order: Int
    var icon: String
    var notes: String
    var isActive: Bool
    var usesTimeMetadata: Bool
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    init(section: HabitDaySection) {
        id = section.id
        name = section.name
        order = section.order
        icon = section.icon ?? ""
        notes = section.contextualNotes ?? ""
        isActive = section.isActive
        usesTimeMetadata = section.timeMetadata != nil
        startHour = section.timeMetadata?.start.hour ?? 9
        startMinute = section.timeMetadata?.start.minute ?? 0
        endHour = section.timeMetadata?.end.hour ?? 11
        endMinute = section.timeMetadata?.end.minute ?? 0
    }

    static func newSection(order: Int = 0) -> HabitDaySectionEditorDraft {
        HabitDaySectionEditorDraft(
            section: HabitDaySection(
                name: "New section",
                order: order,
                icon: "circle",
                timeMetadata: nil,
                contextualNotes: nil,
                isActive: true,
                period: nil
            )
        )
    }

    func makeSection() -> HabitDaySection {
        HabitDaySection(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            order: order,
            icon: icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : icon,
            timeMetadata: usesTimeMetadata ? HabitDaySectionTimeMetadata(
                start: HabitClockTime(hour: startHour, minute: startMinute),
                end: HabitClockTime(hour: endHour, minute: endMinute)
            ) : nil,
            contextualNotes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            isActive: isActive,
            period: nil
        )
    }
}

private struct HabitDaySectionEditorView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var draft: HabitDaySectionEditorDraft
    let onCancel: () -> Void
    let onSave: (HabitDaySection) -> Void

    init(draft: HabitDaySectionEditorDraft, onCancel: @escaping () -> Void, onSave: @escaping (HabitDaySection) -> Void) {
        _draft = State(initialValue: draft)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HabitQuestScreenBackground()

                ScrollView {
                    VStack(spacing: HabitQuestDesignSystem.Spacing.lg) {
                        headerCard
                        formCard
                    }
                    .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                    .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                    .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Edit Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HabitQuestDesignSystem.Palette.background(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft.makeSection())
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text("Custom section")
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
            Text("Keep the section calm and specific.")
                .font(HabitQuestDesignSystem.Typography.title2)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
            Text("This lives locally and can be changed later without affecting your habit history.")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            TextField("Section name", text: $draft.name)
                .habitQuestInputField()
            TextField("Icon or emoji", text: $draft.icon)
                .habitQuestInputField()

            Stepper(value: $draft.order, in: 0...99) {
                Text("Order \(draft.order)")
                    .font(HabitQuestDesignSystem.Typography.callout)
            }

            Toggle("Active", isOn: $draft.isActive)
                .tint(HabitQuestDesignSystem.Palette.accent(for: colorScheme))

            Toggle("Use time range", isOn: $draft.usesTimeMetadata)
                .tint(HabitQuestDesignSystem.Palette.accent(for: colorScheme))

            if draft.usesTimeMetadata {
                HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    DatePicker("Start", selection: bindingForTime(hour: $draft.startHour, minute: $draft.startMinute), displayedComponents: [.hourAndMinute])
                    DatePicker("End", selection: bindingForTime(hour: $draft.endHour, minute: $draft.endMinute), displayedComponents: [.hourAndMinute])
                }
                .datePickerStyle(.compact)
            }

            TextEditor(text: $draft.notes)
                .frame(minHeight: 90)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                        .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                )
                .background(
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                        .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private func bindingForTime(hour: Binding<Int>, minute: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.calendar = Calendar.current
                components.hour = hour.wrappedValue
                components.minute = minute.wrappedValue
                return components.date ?? .now
            },
            set: { newValue in
                let calendar = Calendar.current
                hour.wrappedValue = calendar.component(.hour, from: newValue)
                minute.wrappedValue = calendar.component(.minute, from: newValue)
            }
        )
    }
}
