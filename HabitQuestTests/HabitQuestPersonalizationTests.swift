import XCTest
@testable import HabitQuest

final class HabitQuestPersonalizationTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "HabitQuestPersonalizationTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        XCTAssertNotNil(defaults)
    }

    override func tearDown() {
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFreeAccessFallsBackToStandardAppearanceWhileKeepingSavedPremiumSelection() {
        let store = HabitQuestPersonalizationStore(userDefaults: defaults, accessState: .free)

        store.updateThemeVariant(.ember)
        store.updateAccentPalette(.ocean)
        store.updateCardAppearance(.glassier)
        store.updateCompletionEffectStyle(.orbital)
        store.updateHapticStyle(.expressive)
        store.updateSoundStyle(.glass)
        store.updateProgressionCosmeticStyle(.orb)
        store.updateAppIcon(.dusk)

        XCTAssertEqual(store.selection.themeVariant, .ember)
        XCTAssertEqual(store.selection.accentPalette, .ocean)
        XCTAssertEqual(store.selection.cardAppearance, .glassier)
        XCTAssertEqual(store.selection.appIcon, .dusk)

        XCTAssertEqual(store.effectiveThemeVariant, .standard)
        XCTAssertEqual(store.effectiveAccentPalette, .amber)
        XCTAssertEqual(store.effectiveCardAppearance, .standard)
        XCTAssertEqual(store.effectiveCompletionEffectStyle, .subtle)
        XCTAssertEqual(store.effectiveHapticStyle, .balanced)
        XCTAssertEqual(store.effectiveSoundStyle, .silent)
        XCTAssertEqual(store.effectiveProgressionCosmeticStyle, .minimal)
        XCTAssertEqual(store.effectiveAppIcon, .defaultIcon)

        store.update(accessState: .premium)

        XCTAssertEqual(store.effectiveThemeVariant, .ember)
        XCTAssertEqual(store.effectiveAccentPalette, .ocean)
        XCTAssertEqual(store.effectiveCardAppearance, .glassier)
        XCTAssertEqual(store.effectiveCompletionEffectStyle, .orbital)
        XCTAssertEqual(store.effectiveHapticStyle, .expressive)
        XCTAssertEqual(store.effectiveSoundStyle, .glass)
        XCTAssertEqual(store.effectiveProgressionCosmeticStyle, .orb)
        XCTAssertEqual(store.effectiveAppIcon, .dusk)
    }

    func testTrialToFreePreservesPremiumSelectionAndFallsBackTemporarily() {
        let store = HabitQuestPersonalizationStore(userDefaults: defaults, accessState: .trial)

        store.updateThemeVariant(.dawn)
        store.updateAccentPalette(.ocean)
        store.updateCardAppearance(.framed)
        store.updateCompletionEffectStyle(.luminous)
        store.updateHapticStyle(.expressive)
        store.updateSoundStyle(.glass)
        store.updateProgressionCosmeticStyle(.orb)
        store.updateAppIcon(.ember)

        store.update(accessState: .free)

        XCTAssertEqual(store.selection.themeVariant, .dawn)
        XCTAssertEqual(store.selection.accentPalette, .ocean)
        XCTAssertEqual(store.selection.cardAppearance, .framed)
        XCTAssertEqual(store.selection.appIcon, .ember)

        XCTAssertEqual(store.effectiveThemeVariant, .standard)
        XCTAssertEqual(store.effectiveAccentPalette, .amber)
        XCTAssertEqual(store.effectiveCardAppearance, .standard)
        XCTAssertEqual(store.effectiveCompletionEffectStyle, .subtle)
        XCTAssertEqual(store.effectiveHapticStyle, .balanced)
        XCTAssertEqual(store.effectiveSoundStyle, .silent)
        XCTAssertEqual(store.effectiveProgressionCosmeticStyle, .minimal)
        XCTAssertEqual(store.effectiveAppIcon, .defaultIcon)

        store.update(accessState: .premium)

        XCTAssertEqual(store.effectiveThemeVariant, .dawn)
        XCTAssertEqual(store.effectiveAccentPalette, .ocean)
        XCTAssertEqual(store.effectiveCardAppearance, .framed)
        XCTAssertEqual(store.effectiveCompletionEffectStyle, .luminous)
        XCTAssertEqual(store.effectiveHapticStyle, .expressive)
        XCTAssertEqual(store.effectiveSoundStyle, .glass)
        XCTAssertEqual(store.effectiveProgressionCosmeticStyle, .orb)
        XCTAssertEqual(store.effectiveAppIcon, .ember)
    }

    func testPremiumSelectionsPersistAcrossStoreReloads() {
        do {
            let store = HabitQuestPersonalizationStore(userDefaults: defaults, accessState: .premium)
            store.updateThemeVariant(.dawn)
            store.updateAccentPalette(.sage)
            store.updateCardAppearance(.framed)
            store.updateCompletionEffectStyle(.luminous)
            store.updateHapticStyle(.minimal)
            store.updateSoundStyle(.soft)
            store.updateProgressionCosmeticStyle(.halo)
            store.updateAppIcon(.ember)
        }

        let reloadedStore = HabitQuestPersonalizationStore(userDefaults: defaults, accessState: .premium)

        XCTAssertEqual(reloadedStore.selection.themeVariant, .dawn)
        XCTAssertEqual(reloadedStore.selection.accentPalette, .sage)
        XCTAssertEqual(reloadedStore.selection.cardAppearance, .framed)
        XCTAssertEqual(reloadedStore.selection.completionEffectStyle, .luminous)
        XCTAssertEqual(reloadedStore.selection.hapticStyle, .minimal)
        XCTAssertEqual(reloadedStore.selection.soundStyle, .soft)
        XCTAssertEqual(reloadedStore.selection.progressionCosmeticStyle, .halo)
        XCTAssertEqual(reloadedStore.selection.appIcon, .ember)
    }

    func testExpiredPremiumRestoresSavedSelectionAfterRelaunchAndResubscribe() {
        do {
            let store = HabitQuestPersonalizationStore(userDefaults: defaults, accessState: .premium)
            store.updateThemeVariant(.ember)
            store.updateAccentPalette(.sage)
            store.updateCardAppearance(.glassier)
            store.updateCompletionEffectStyle(.orbital)
            store.updateHapticStyle(.minimal)
            store.updateSoundStyle(.soft)
            store.updateProgressionCosmeticStyle(.halo)
            store.updateAppIcon(.dusk)
            store.update(accessState: .free)
            XCTAssertEqual(store.effectiveThemeVariant, .standard)
            XCTAssertEqual(store.effectiveAppIcon, .defaultIcon)
        }

        let relaunch = HabitQuestPersonalizationStore(userDefaults: defaults, accessState: .free)
        XCTAssertEqual(relaunch.selection.themeVariant, .ember)
        XCTAssertEqual(relaunch.selection.accentPalette, .sage)
        XCTAssertEqual(relaunch.effectiveThemeVariant, .standard)
        XCTAssertEqual(relaunch.effectiveAppIcon, .defaultIcon)

        relaunch.update(accessState: .premium)
        XCTAssertEqual(relaunch.effectiveThemeVariant, .ember)
        XCTAssertEqual(relaunch.effectiveAccentPalette, .sage)
        XCTAssertEqual(relaunch.effectiveAppIcon, .dusk)
    }

    func testPremiumEntitlementServiceForwardsAccessStateToPersonalizationStore() {
        let store = HabitQuestPersonalizationStore(userDefaults: defaults, accessState: .free)
        let service = PremiumEntitlementService(accessState: .free, personalizationStore: store)

        XCTAssertEqual(store.accessState, .free)
        XCTAssertFalse(store.canUsePremiumPersonalization)

        service.update(accessState: .trial)

        XCTAssertEqual(store.accessState, .trial)
        XCTAssertTrue(store.canUsePremiumPersonalization)
    }
}
