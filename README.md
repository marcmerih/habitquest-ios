# HabitQuest

## Final Product Bible

**Platform:** iOS
**Product Category:** Habit Building / Wellness / Personal Productivity / Gamification
**Product Philosophy:** A meditative, wellness-focused Duolingo for everyday habits
**Primary Interface:** Native SwiftUI / Apple Liquid Glass
**Core Interaction:** Swipe-driven daily habit completion
**Business Model:** Freemium + HabitQuest Premium
**Persistence Philosophy:** Local-first
**Primary Product Goal:** Make consistency feel rewarding, calm, achievable and intrinsically motivating.

---

# 1. Product Vision

HabitQuest is a premium-feeling iOS habit-building application designed to make completing everyday habits, routines, chores, personal goals and wellness activities feel satisfying and rewarding.

The conceptual shorthand is:

> **Duolingo for habits, with the calmness of a wellness application and the interaction simplicity of Tinder.**

HabitQuest should combine:

* The progression and motivation of Duolingo.
* The clarity and polish of Apple Fitness.
* The calmness of a meditation/wellness application.
* The satisfying interaction model of card-based interfaces such as Tinder.
* Native iOS interaction patterns.
* Apple's Liquid Glass visual language.
* Lightweight RPG-inspired progression.
* Meaningful personal analytics.
* A non-punitive approach to missed habits.

HabitQuest should not feel like a spreadsheet, checklist, corporate productivity application or aggressive self-improvement system.

It should feel like a companion.

The user opens HabitQuest and immediately understands:

> **What should I do today?**

Everything else in the product exists to support that question.

---

# 2. Product Philosophy

HabitQuest is based around five fundamental principles.

## 2.1 Consistency Over Perfection

HabitQuest encourages users to return consistently rather than punishing them for imperfection.

Missing a habit should never make the user feel that they have "failed" HabitQuest.

The application should encourage:

> "Try again."

rather than:

> "You failed."

Streaks and statistics are important motivational systems, but they should not dominate the emotional experience.

---

## 2.2 Action Before Administration

Habit applications frequently become productivity databases.

HabitQuest should avoid this.

The primary application experience is not:

> Manage your habits.

It is:

> Do your habits.

Creating schedules, configuring reminders, analyzing statistics and editing metadata are supporting activities.

The Today experience remains the soul of HabitQuest.

---

# 3. Emotional Identity

HabitQuest should feel:

* Calm.
* Encouraging.
* Premium.
* Playful.
* Intentional.
* Modern.
* Tactile.
* Personal.
* Rewarding.
* Optimistic.

It should not feel:

* Stressful.
* Judgmental.
* Childish.
* Casino-like.
* Hypercompetitive.
* Corporate.
* Overloaded.
* Manipulative.
* Aggressively gamified.

Gamification exists to reinforce healthy behavior.

It should never become the product's personality.

---

# 4. Core Product Loop

The fundamental HabitQuest loop is:

**Plan → See → Act → Complete → Progress → Reflect → Return**

In practical terms:

1. The user creates habits.
2. HabitQuest determines which habits are relevant today.
3. Today's habits appear in the Today experience.
4. The user progresses through them using the swipe deck.
5. Completed habits generate satisfying visual and haptic feedback.
6. Delayed habits temporarily move out of the way.
7. Unfinished habits return later.
8. Completed habits contribute toward streaks, Momentum, XP and progression.
9. Analytics gradually reveal behavioral patterns.
10. The user returns the following day.

The experience should gradually move from:

> "I have a list of habits."

toward:

> "HabitQuest helps me move through my day."

---

# 5. Core Navigation

HabitQuest uses four primary bottom tabs:

1. **Today**
2. **Habits**
3. **Analytics**
4. **Profile**

The tab bar should use native iOS Liquid Glass styling.

Navigation should feel lightweight and immediately understandable.

---

# 6. Today

Today is the default application tab and the most important screen in HabitQuest.

Opening HabitQuest should generally bring the user directly into Today.

Today answers:

> **What should I focus on right now?**

The screen contains several interconnected concepts:

* Today's progress.
* Daily Rhythm.
* Today Deck.
* Daily Journey.
* Completed habits.
* Momentum.
* Contextual encouragement.

The screen should not become visually overloaded.

The swipe deck remains its primary interaction.

---

# 7. The Today Deck

The Today Deck is HabitQuest's signature interaction.

Today's incomplete habits are represented as a stack of cards.

Each card may display:

* Habit name.
* Habit icon.
* Habit category.
* Time/routine information.
* Current streak.
* Optional goal information.
* Optional reminder information.
* XP reward.
* Relevant contextual information.

The card itself should use Liquid Glass and feel physical without becoming excessively skeuomorphic.

---

# 8. Swipe Interaction

Two primary gestures control the deck.

## Swipe Right — Complete

Swiping a habit card right means:

> **Complete**

The card should respond progressively to the gesture.

As the card moves right:

* The completion state becomes increasingly visible.
* Appropriate visual feedback appears.
* Haptics reinforce the threshold.
* Releasing after crossing the threshold completes the habit.

Completion should feel satisfying but calm.

The completed habit is removed from the active deck.

Relevant systems update immediately:

* Daily progress.
* XP.
* Streak.
* Momentum.
* Analytics.
* Daily Journey.
* Achievement progress.

---

## Swipe Left — Not Now

Swiping left means:

> **Not Now**

It deliberately does **not** mean:

* Failed.
* Skipped permanently.
* Deleted.
* Missed.

The habit is temporarily deferred.

The application should use friendly language such as:

> Not Now

rather than punitive terminology.

The deferred card moves behind the remaining incomplete cards.

---

# 9. Multi-Pass Deferral

Deferral is deliberately temporary.

Consider today's initial queue:

**A → B → C → D**

The user swipes left on B.

The active sequence becomes:

**A → C → D → B**

If B is deferred again, it moves behind the remaining relevant cards again.

This creates a multi-pass system.

The user can move through easier or more immediately relevant habits without permanently abandoning another habit.

Eventually deferred habits return.

This is a central HabitQuest philosophy:

> **Not now does not mean never.**

---

# 10. End-of-Day Behavior

Incomplete habits remain unresolved until the day ends unless the underlying schedule determines otherwise.

At the daily rollover:

* Completed instances remain completed.
* Incomplete instances become historical incomplete instances.
* Tomorrow's relevant habit instances are generated.
* Deferral state resets.
* Daily progress resets.
* Streak and Momentum calculations update appropriately.

Historical data must remain intact.

---

# 11. Daily Rhythm

HabitQuest should understand that habits often belong to different parts of the day.

The Daily Rhythm concept organizes habits around natural daily periods.

Initial conceptual periods include:

* Morning.
* Afternoon.
* Evening.

HabitQuest Premium expands this considerably.

The objective is not simply categorization.

Daily Rhythm should make Today feel like a journey through the user's day.

For example:

**Morning**

* Make bed
* Vitamins
* Meditation

**Afternoon**

* Gym
* Walk

**Evening**

* Read
* Journal
* Stretch

As the day progresses, HabitQuest can subtly emphasize the most contextually relevant portion of the day.

---

# 12. Daily Journey

The Daily Journey is the higher-level visualization of today's progress.

Rather than only showing:

> 5 / 8 completed

HabitQuest should visually communicate movement through the day.

The Journey can gradually fill, progress or evolve as habits are completed.

It should reinforce:

> "I am making progress."

without requiring the user to interpret statistics.

Daily Journey should be visually calm and compatible with Liquid Glass.

---

# 13. Habit Management

The Habits tab is the control center for the user's habit system.

Users can:

* Create habits.
* Edit habits.
* Delete habits.
* Pause habits.
* Resume habits.
* Configure schedules.
* Configure reminders.
* View habit metadata.
* View individual habit history.
* Configure appearance/iconography.
* Configure goals.
* Configure routine/time information.

Habit management should remain secondary to Today.

---

# 14. Habit Creation

Creating a habit should feel simple initially while allowing deeper configuration.

A habit may contain:

* Name.
* Icon.
* Category.
* Description.
* Schedule.
* Start date.
* Optional end date.
* Reminder configuration.
* Routine/time-of-day association.
* Goal.
* Completion type.
* XP value.
* Active/paused state.
* Creation date.
* Historical metadata.

Advanced configuration should be progressively disclosed rather than overwhelming new users.

---

# 15. Scheduling

HabitQuest must support practical recurring habits.

Core Free scheduling should support common patterns such as:

* Every day.
* Selected weekdays.
* Weekly.
* Basic recurring schedules.

Users should not require Premium simply to create a functional recurring habit.

Premium adds advanced scheduling rather than removing ordinary scheduling from Free.

---

# 16. Notifications

HabitQuest supports functional habit reminders.

Notifications should feel supportive rather than demanding.

Examples:

> "A little time for reading?"

> "Your evening routine is waiting when you're ready."

Avoid guilt-based messages.

Users control notification permissions and relevant reminder settings.

Habit reminders and promotional Premium notifications must be treated as separate systems.

---

# 17. Completion Feedback

Habit completion should create one of HabitQuest's most satisfying micro-interactions.

Possible feedback includes:

* Card movement.
* Liquid Glass transformation.
* Subtle particles.
* Haptic feedback.
* XP animation.
* Progress animation.
* Streak acknowledgement.
* Momentum movement.
* Gentle sound.

Animations should be short and should never interrupt rapid habit completion.

Respect Reduce Motion.

---

# 18. Gamification Philosophy

HabitQuest borrows motivational principles from games without becoming a game that happens to contain habits.

Gamification includes:

* XP.
* Levels.
* Streaks.
* Momentum.
* Achievements.
* Progress milestones.
* Completion celebrations.
* Optional cosmetic rewards.

The hierarchy should remain:

**Healthy behavior → Progress → Reward**

not:

**Reward → Compulsion → Engagement**

---

# 19. XP

Completing habits awards XP.

XP provides persistent progression across HabitQuest.

XP can eventually reflect:

* Habit completion.
* Consistency.
* Milestones.
* Achievements.
* Special challenges.

The system should remain understandable.

Avoid complicated currencies.

HabitQuest should not launch with multiple virtual currencies.

---

# 20. Levels

XP contributes toward user levels.

Levels provide long-term progression beyond individual streaks.

The purpose of levels is psychological continuity.

Even if a streak breaks, the user's accumulated progress remains.

This prevents HabitQuest from communicating:

> "You lost everything."

---

# 21. Streaks

HabitQuest supports streaks because they are highly understandable motivational tools.

However, streaks should be presented carefully.

A streak represents consistency, not personal worth.

HabitQuest should avoid excessively dramatic streak-loss experiences.

Streak information can appear:

* On habit cards.
* In habit details.
* In Analytics.
* In Profile.
* During milestones.

---

# 22. Momentum

Momentum complements streaks.

Where a streak is binary:

> Did you maintain the sequence?

Momentum represents broader consistency.

A user who completes a habit six days out of seven should still feel successful.

Momentum therefore helps HabitQuest avoid one of the major psychological problems of traditional streak systems.

The application should communicate both:

**Streak = continuity**

and:

**Momentum = consistency**

This gives users more than one definition of success.

---

# 23. Achievements

Achievements recognize meaningful behavior.

Examples include:

* First habit completed.
* First perfect day.
* Seven-day consistency.
* 100 completions.
* First month using HabitQuest.
* Specific streak milestones.
* XP milestones.
* Habit-specific milestones.

Achievements should feel celebratory but not intrusive.

---

# 24. Analytics

Analytics transforms HabitQuest from a daily checklist into a behavioral-awareness tool.

The Analytics tab should help users understand:

> **How am I actually doing?**

The design should prioritize interpretation over raw numbers.

---

# 25. Free Analytics

Free users receive genuinely useful analytics.

Examples include:

* Current streaks.
* Basic completion rate.
* Weekly progress.
* Recent completion history.
* Basic XP/progression.
* Basic habit performance.

Free analytics must be sufficient to understand progress.

Premium should not be required simply to understand whether a habit is working.

---

# 26. HabitQuest Premium Analytics

Premium unlocks deeper behavioral intelligence.

Premium analytics should support:

* 30-day analysis.
* 90-day analysis.
* 365-day analysis.
* All-time history.
* Long-term consistency.
* Completion by weekday.
* Completion by time of day.
* Best-performing days.
* Lowest-performing days.
* Historical streak analysis.
* Longest streaks.
* Habit-specific trends.
* Month-over-month comparisons.
* Completion-rate trends.
* Consistency scoring.
* Routine performance.
* Long-term Momentum trends.

Eventually, HabitQuest Premium can provide cross-habit behavioral insights.

Example:

> "On days you complete Exercise, you are 18% more likely to complete Reading."

This should eventually become one of Premium's strongest differentiators.

---

# 27. Profile

Profile contains personal progression and application-level management.

It may include:

* User identity.
* Avatar/profile information.
* Level.
* XP.
* Achievement collection.
* Overall statistics.
* HabitQuest Premium.
* Notification settings.
* Appearance.
* Accessibility.
* Data management.
* Export.
* Privacy.
* Account management.
* Subscription management.
* About HabitQuest.

---

# 28. Onboarding

Onboarding should communicate HabitQuest through experience rather than lengthy explanation.

The user should understand:

1. What HabitQuest is.
2. Why it is different.
3. How the swipe deck works.
4. How habits work.
5. How progress works.
6. How reminders work.
7. Why notifications may be useful.

The user should ideally create at least one habit during onboarding.

Do not require excessive configuration before they can experience Today.

---

# 29. Authentication

HabitQuest should support an account/authentication layer where required by the final architecture.

Authentication must not become a barrier between the user and the product.

After initial authentication/account creation and onboarding, the user enters the main HabitQuest experience.

The first main-app entry is also the appropriate point to introduce the optional Premium trial.

---

# 30. Local-First Architecture

HabitQuest should remain fundamentally local-first.

Core habit data should live on-device using Apple's native persistence technologies, with SwiftData as the preferred persistence layer where appropriate.

Core functionality should not require a network connection.

Users should be able to:

* Open HabitQuest.
* View habits.
* Complete habits.
* Defer habits.
* Edit habits.
* Track progression.
* View locally available analytics.

without requiring continuous internet connectivity.

Cloud/account capabilities can evolve independently from the fundamental habit engine.

---

# 31. Data Model Philosophy

Habit definitions and daily habit occurrences should be distinct concepts.

A **Habit** describes the recurring rule.

A **HabitInstance** represents a particular scheduled occurrence.

For example:

Habit:

> Drink Vitamins — Every Day

Instances:

> August 16 — Completed
> August 17 — Pending
> August 18 — Pending

This separation is essential for:

* Historical analytics.
* Streaks.
* Daily scheduling.
* Deferral.
* Completion history.
* Editing schedules safely.

Historical instances should not be rewritten merely because the user later changes the habit.

---

# 32. Core Domain Models

The architecture should conceptually include models such as:

* User/Profile.
* Habit.
* HabitSchedule.
* HabitInstance.
* HabitCompletion.
* Reminder.
* DailyProgress.
* Streak.
* Momentum.
* XPState.
* Achievement.
* DailyJourney.
* Routine/DaySection.
* Reflection.
* SubscriptionState.
* PremiumFeature.
* NotificationPreference.

The exact Swift architecture may evolve, but product concepts should remain cleanly separated.

---

# 33. Apple Liquid Glass

HabitQuest should embrace Apple's Liquid Glass design language throughout the application.

Liquid Glass is not simply decoration.

It should define the application's visual identity.

Use it appropriately across:

* Navigation.
* Tab bar.
* Habit cards.
* Today Deck.
* Sheets.
* Modals.
* Controls.
* Analytics containers.
* Profile surfaces.
* Premium surfaces.
* Completion states.
* Contextual overlays.

Glass surfaces should remain readable and restrained.

Avoid stacking excessive translucent surfaces.

The application should feel native to modern iOS rather than like a web application recreated in SwiftUI.

---

# 34. Visual Hierarchy

HabitQuest should maintain generous spacing.

Use:

* Large typography where appropriate.
* Clear card hierarchy.
* Native SF Symbols where suitable.
* Rounded geometry.
* Subtle depth.
* Controlled translucency.
* Strong accessibility contrast.
* Calm backgrounds.

Avoid excessive gradients, glow and visual noise.

---

# 35. Motion

Motion communicates state.

Examples include:

* Swipe response.
* Card completion.
* Card deferral.
* XP gain.
* Achievement unlock.
* Daily Journey progression.
* Momentum changes.
* Sheet transitions.
* Tab transitions.

Motion should never exist merely because animation is possible.

Respect Reduce Motion throughout.

---

# 36. Accessibility

HabitQuest must be accessible from the beginning.

Support:

* VoiceOver.
* Dynamic Type.
* Reduce Motion.
* Increased Contrast.
* Appropriate accessibility labels.
* Large tap targets.
* Non-color-only status communication.
* Accessible swipe alternatives.
* Explicit accessibility actions for Today cards: Complete, Not Now, and Open Details.
* Accessible summaries for the Daily Journey visual and analytics charts.

Users unable or unwilling to swipe must be able to complete or defer habits using accessible buttons/actions.

## Accessibility Notes

HabitQuest is designed so no important state depends only on gesture direction, animation, haptics, or color. The app should always expose a readable fallback path through VoiceOver, buttons, and semantic copy.

Current known limitations for the MVP:

* The analytics charts are summarized for VoiceOver rather than exposing every plotted point individually.
* The Daily Journey remains primarily a decorative progress visualization, but it now exposes a semantic progress summary.
* Liquid Glass surfaces rely on native platform behavior, so the exact translucency can vary slightly across iOS versions and accessibility settings.
* Some motion remains in the sighted experience, but it is reduced or softened when Reduce Motion is enabled.

---

# 37. Privacy

Habit information can reveal extremely personal information.

HabitQuest should therefore collect as little unnecessary information as possible.

Analytics systems should avoid sending:

* Habit names.
* Reflection text.
* Personal notes.
* Sensitive user-generated content.

Behavioral telemetry should use abstract events wherever possible.

---

# 38. HabitQuest Free

HabitQuest follows a freemium model.

The Free version should be a genuinely excellent habit application.

It must not feel like a trial disguised as a product.

The following remain Free:

* Unlimited habits.
* Habit creation.
* Habit editing.
* Habit deletion.
* Habit pausing.
* Today.
* Today Deck.
* Swipe-right completion.
* Swipe-left Not Now.
* Multi-pass deferral.
* Basic scheduling.
* Basic reminders.
* Basic streaks.
* Momentum.
* XP.
* Levels.
* Core achievements.
* Basic analytics.
* Weekly progress.
* Core Daily Journey.
* Core Liquid Glass experience.
* Standard appearance.
* Core profile functionality.

HabitQuest should **not limit the number of habits simply to force subscription conversion.**

---

# 39. HabitQuest Premium Philosophy

HabitQuest Premium follows a simple proposition:

> **HabitQuest Free helps you track your habits. HabitQuest Premium helps HabitQuest organize, understand and personalize your life around them.**

Premium should provide:

* Greater organization.
* Greater intelligence.
* Greater personalization.
* Greater flexibility.
* Greater insight.

It should not provide basic usability.

A Free user should be able to say:

> "HabitQuest is a great habit tracker."

A Premium user should feel:

> "HabitQuest basically helps run my day."

---

# 40. Premium Structure

HabitQuest should initially have exactly two product states:

**Free**

and:

**HabitQuest Premium**

Do not create Premium / Pro / Ultimate tiers.

Premium can have different billing periods while sharing the same entitlement.

Initial billing options:

* HabitQuest Premium Monthly.
* HabitQuest Premium Annual.

Annual should be visually positioned as the recommended/better-value option.

Pricing should remain configurable through App Store Connect and StoreKit.

Never hard-code localized visible pricing into the application.

---

# 41. Premium — Advanced Daily Routines

Advanced Daily Rhythm functionality is Premium.

Premium users can organize habits into:

* Morning.
* Afternoon.
* Evening.

The architecture should additionally support custom sections such as:

* Morning Routine.
* Deep Work.
* Health.
* Lunch Break.
* After Work.
* Evening Reset.
* Before Bed.

Users can assign habits to sections and HabitQuest can use these sections to structure Today.

This is a particularly strong Premium feature because it improves organization without preventing Free users from completing habits.

---

# 42. Premium — Advanced Scheduling

Free retains ordinary recurring scheduling.

Premium unlocks advanced scheduling such as:

* Complex recurrence patterns.
* Flexible completion windows.
* Advanced weekday combinations.
* Time-of-day targeting.
* Routine-aware schedules.
* Future advanced recurrence options.

Advanced scheduling should evolve without requiring changes to the underlying entitlement architecture.

---

# 43. Premium — Advanced Reminders

Free users receive useful basic reminders.

Premium unlocks:

* Multiple reminders per habit.
* Reminder windows.
* Follow-up reminders.
* "Remind me again if incomplete."
* Advanced snooze behavior.
* Routine-aware reminders.
* Configurable reminder escalation.
* Future adaptive reminders.

Eventually HabitQuest can learn when users typically complete habits and suggest better reminder timing.

This future capability should be anticipated architecturally without prematurely implementing unnecessary AI.

---

# 44. Premium — Advanced Analytics

Advanced Analytics is one of HabitQuest Premium's primary value propositions.

Free shows useful recent progress.

Premium reveals deeper behavioral patterns.

Premium analytics include the extended capabilities defined earlier in this bible and should gradually evolve toward a personal behavior intelligence system.

---

# 45. Premium — Habit Reflections

Premium users can optionally attach reflections to habit completions.

Examples:

> "Felt much better after the run."

> "Only read for ten minutes, but starting was the important part."

> "Meditation was difficult today."

Reflections become part of the historical completion record.

They should remain private and local-first wherever possible.

Future HabitQuest intelligence may use reflections to provide deeper insights, subject to appropriate privacy design.

---

# 46. Premium — Personalization

Core HabitQuest should already look premium.

Do not intentionally make Free ugly.

Premium instead provides additional personalization.

Potential Premium customization includes:

* Additional Liquid Glass appearance variants.
* Additional accent styles.
* Premium app icons.
* Additional card styles.
* Additional completion animations.
* Additional haptic configurations.
* Additional sounds.
* Progression cosmetics.

Personalization gives frequent users another reason to subscribe without restricting functionality.

---

# 47. Premium — Advanced Widgets

Basic widgets may remain Free.

Premium can unlock advanced widgets including:

* Configurable habit widgets.
* Multiple habit widgets.
* Routine widgets.
* Progress widgets.
* Streak widgets.
* Advanced Today widgets.
* Custom habit selections.

Widget entitlement must respond gracefully if Premium expires.

---

# 48. Future Premium Intelligence

HabitQuest should reserve architectural space for future Premium intelligence.

Potential capabilities include:

* Behavioral correlations.
* Completion pattern detection.
* Smart reminder suggestions.
* Habit difficulty detection.
* Routine optimization.
* Habit recommendations.
* Weekly behavioral summaries.
* Personal consistency insights.
* Reflection analysis.

Do not add superficial AI merely to advertise an AI feature.

HabitQuest intelligence should only appear when sufficient behavioral history exists to make the output genuinely useful.

---

# 49. StoreKit Monetization

Digital Premium functionality must use Apple's In-App Purchase infrastructure through StoreKit.

Do not implement Premium subscriptions using Apple Pay.

Apple Pay and StoreKit serve different purposes.

HabitQuest Premium is a digital subscription unlocking application functionality and therefore belongs within Apple's subscription/In-App Purchase infrastructure.

Create a centralized:

`SubscriptionManager`

responsible for subscription state.

---

# 50. SubscriptionManager

SubscriptionManager should handle:

* Loading StoreKit products.
* Localized pricing.
* Purchasing.
* Transaction verification.
* Current entitlements.
* Transaction updates.
* Subscription expiration.
* Subscription renewal.
* Trial state.
* Introductory-offer eligibility.
* Restore Purchases.
* Billing-state changes.
* Foreground entitlement refresh.
* Subscription-management access.

Individual views should never implement their own StoreKit logic.

---

# 51. Premium Entitlement Architecture

Create a centralized Premium feature model.

Conceptually:

`PremiumFeature`

Possible cases include:

* advancedRoutines
* customDaySections
* advancedScheduling
* multipleReminders
* smartReminders
* advancedAnalytics
* longTermAnalytics
* habitInsights
* habitReflections
* advancedWidgets
* premiumThemes
* premiumAppIcons
* advancedCustomization
* advancedGamification

The application should expose functionality conceptually similar to:

`canAccess(_ feature: PremiumFeature)`

Do not scatter:

`if user.isPremium`

throughout the codebase.

The objective is to allow the product team to move individual capabilities between Free and Premium later without major refactoring.

---

# 52. Seven-Day Premium Trial

HabitQuest should offer an optional seven-day Premium introductory trial to eligible users.

This should use Apple's introductory subscription offer infrastructure.

StoreKit/App Store eligibility is authoritative.

Do not rely exclusively on a local:

`hasUsedTrial`

Boolean.

This prevents reinstall/account-state problems and ensures eligibility reflects Apple's subscription rules.

---

# 53. Initial Trial Experience

After:

* Authentication/account creation.
* Core onboarding.

and when the user enters the actual HabitQuest application for the first time, an eligible user may receive:

> **Try HabitQuest Premium free for 7 days**

The experience should briefly demonstrate Premium value.

Possible highlights:

* Build morning, afternoon and evening routines.
* Unlock smarter reminders.
* Discover deeper habit patterns.
* Personalize HabitQuest.
* Access advanced scheduling.

The screen must be easily dismissible.

Do not trap the user behind the trial screen.

---

# 54. Declining the Trial

Declining the introductory offer must not consume eligibility.

If the user chooses:

> Not Now

they enter HabitQuest Free.

Profile should continue to display:

> **Try Premium Free**

while StoreKit reports that the user remains eligible.

The user may therefore reconsider later.

---

# 55. Trial Already Used

After the introductory offer has been consumed, HabitQuest should no longer advertise:

> Free Trial

if StoreKit reports the user is no longer eligible.

Instead show:

> **Go Premium**

or:

> **Unlock HabitQuest Premium**

This avoids misleading users.

---

# 56. Active Trial

During an active trial:

* Premium functionality is fully unlocked.
* Profile indicates Premium Trial status.
* Subscription state is clearly communicated.
* HabitQuest should not display Premium upsells.
* Premium promotional notifications should not appear.

The experience should allow Premium to demonstrate its value naturally.

---

# 57. Premium Paywall

HabitQuest should have a reusable Premium paywall.

It should feel like part of HabitQuest rather than an external storefront.

The paywall should highlight major Premium benefits:

* Advanced routines.
* Smarter reminders.
* Advanced analytics.
* Advanced scheduling.
* Personalization.
* Habit insights.

Display:

* Monthly subscription.
* Annual subscription.
* Localized StoreKit pricing.
* Trial information when eligible.
* Subscribe CTA.
* Restore Purchases.
* Privacy Policy.
* Terms.
* Renewal information.
* Dismiss action where appropriate.

Never fabricate pricing or trial eligibility.

---

# 58. Contextual Upselling

Contextual Premium discovery should be the primary conversion mechanism.

Example:

A Free user selects:

**Analytics → 90 Days**

Instead of simply displaying:

> Premium Required

show a polished preview explaining:

> **Understand the patterns behind your progress**

with a preview of the analytical experience.

Another example:

The user attempts to add a second reminder.

HabitQuest explains:

> **Stay on track with flexible follow-ups and multiple reminders.**

The user can then open the Premium paywall.

This approach makes the value proposition contextual.

The user understands exactly why Premium could improve their experience.

---

# 59. Locked Feature Previews

Premium features can remain visible where useful.

Examples:

* 90-day analytics tab.
* Premium routine configuration.
* Multiple-reminder option.
* Premium themes.
* Advanced widgets.

Use understated Premium indicators.

Do not cover the application with lock icons.

The objective is:

> Discoverability.

not:

> Frustration.

---

# 60. Premium Promotion Frequency

HabitQuest must not become annoying.

Contextual paywalls caused by deliberately selecting Premium functionality can always appear.

Unsolicited Premium promotions should be rate-limited.

A reasonable initial rule is approximately:

> **Maximum one unsolicited Premium promotion every seven days.**

This should be configurable rather than hard-coded throughout the application.

Do not show unsolicited Premium promotions:

* During habit completion.
* Immediately following a missed habit.
* During negative feedback.
* Multiple times during the same session.
* To Premium subscribers.
* During an active Premium trial.

---

# 61. Premium Promotional Notifications

HabitQuest may optionally support occasional Premium promotional notifications.

These are separate from habit reminders.

They should:

* Respect notification permissions.
* Respect application-level promotional notification preferences.
* Be rare.
* Highlight a genuinely useful Premium capability.
* Deep-link into the relevant Premium explanation.
* Never interfere with habit reminders.

HabitQuest should never repeatedly send:

> Upgrade now!

Push notifications should primarily exist to support habits, not monetization.

---

# 62. Manage Subscription

Profile must include subscription management.

Possible states include:

### Eligible Free User

> HabitQuest Premium
> Try Premium Free

### Free User Without Trial Eligibility

> HabitQuest Premium
> Go Premium

### Active Trial

> HabitQuest Premium
> Premium Trial

### Subscriber

> HabitQuest Premium
> Manage Subscription

HabitQuest should use Apple's supported subscription-management interfaces.

Do not build a fake custom cancellation mechanism.

---

# 63. Restore Purchases

Users must be able to restore purchases.

Restore Purchases should be accessible from:

* Premium paywall.
* Subscription settings.

Entitlements should refresh following restoration.

---

# 64. Subscription Expiration

Premium expiration must never destroy user data.

If Premium expires:

* Preserve routines.
* Preserve custom day sections.
* Preserve reflections.
* Preserve advanced reminder configuration.
* Preserve analytics history.
* Preserve historical Premium-created data.

Premium-only editing/use may become unavailable.

If the user later resubscribes, their configuration should return.

Do not hold historical user data hostage.

---

# 65. Subscription State Changes

HabitQuest must react correctly when:

* Premium is purchased.
* Trial begins.
* Trial converts to paid.
* Subscription renews.
* Subscription expires.
* User cancels but retains access until the period ends.
* Billing issues occur.
* Purchases are restored.
* StoreKit sends a transaction update.
* The application returns to foreground.

The UI should update reactively without requiring an application restart.

---

# 66. Monetization Analytics

HabitQuest should understand its subscription funnel without collecting sensitive habit information.

Potential events:

* premium_paywall_viewed
* premium_feature_gate_viewed
* premium_trial_offered
* premium_trial_declined
* premium_trial_started
* premium_purchase_started
* premium_purchase_completed
* premium_purchase_cancelled
* premium_restore_started
* premium_restore_completed
* premium_manage_subscription_opened

Context can include abstract source information such as:

`analytics_90_day`

or:

`multiple_reminders`

Never include:

* Habit names.
* Reflection text.
* User notes.

---

# 67. Premium Design Language

Premium should feel sophisticated rather than gaudy.

Avoid:

* Excessive gold.
* Crowns everywhere.
* Diamonds.
* Fake scarcity.
* Countdown timers.
* SALE banners.
* Aggressive gradients.
* Repeated popups.

HabitQuest Premium should communicate:

> **A deeper version of HabitQuest.**

not:

> **A VIP casino membership.**

---

# 68. Settings

HabitQuest settings should include relevant controls for:

* Notifications.
* Habit reminders.
* Appearance.
* Haptics.
* Sounds.
* Accessibility.
* Data/export.
* Privacy.
* Account.
* Subscription.
* Restore Purchases.
* App information.

Settings should remain consistent with native iOS conventions.

For the MVP, the implemented settings experience should prioritize local reminders, quiet hours, appearance, onboarding replay, privacy, export/delete controls, and app information. Cloud, account, subscription, and restore-purchases controls remain intentionally absent until those systems exist.

---

# 69. Data Export

Users should eventually be able to export their habit history.

Export should reinforce the principle that the user's behavioral history belongs to them.

Possible export formats can be determined during implementation.

Export should not require users to surrender historical data to a cloud service.

---

# 70. Empty States

Empty states should feel intentional.

Examples:

No habits:

> **Your journey starts with one small habit.**

No remaining tasks:

> **You're done for today.**

No analytics history:

> **Your patterns will appear as you build your rhythm.**

Avoid sterile:

> No Data

messages wherever possible.

---

# 71. Completed Day

When all relevant habits are completed, HabitQuest should acknowledge the achievement.

The completion state may include:

* Daily Journey completion.
* XP summary.
* Momentum.
* Streak changes.
* Gentle celebration.
* Encouraging copy.

Avoid excessively elaborate celebration every single day.

The experience should remain peaceful.

---

# 72. Habit Templates

HabitQuest may provide starter habit templates.

Potential categories:

* Wellness.
* Fitness.
* Mindfulness.
* Learning.
* Productivity.
* Home.
* Sleep.
* Nutrition.
* Personal.

Templates accelerate onboarding but should never constrain custom habit creation.

---

# 73. Edge Cases

HabitQuest must gracefully handle:

* No habits.
* No habits scheduled today.
* All habits completed.
* All remaining habits deferred.
* Habit edited mid-day.
* Habit deleted mid-day.
* Habit paused mid-day.
* Application reopened after midnight.
* Time-zone change.
* Daylight-saving change.
* Notification permission denied.
* Subscription expires.
* StoreKit unavailable.
* Purchase canceled.
* Purchase fails.
* Restore finds nothing.
* Offline use.
* Corrupted or incomplete state.

The Today Deck must never enter an impossible interaction state.

---

# 74. Technical Foundation

HabitQuest should use modern native Apple technologies wherever practical.

Preferred stack:

* Swift.
* SwiftUI.
* SwiftData.
* StoreKit.
* UserNotifications.
* WidgetKit.
* Apple's native accessibility APIs.
* Native animation/haptic APIs.

Avoid unnecessary third-party dependencies.

HabitQuest should feel fundamentally native.

---

# 75. Service Architecture

Keep product logic separated from presentation.

Conceptual services/managers may include:

* HabitRepository.
* HabitSchedulingService.
* DailyInstanceGenerator.
* TodayDeckCoordinator.
* StreakService.
* MomentumService.
* XPService.
* AchievementService.
* AnalyticsService.
* NotificationManager.
* SubscriptionManager.
* PremiumEntitlementService.
* PremiumPromotionManager.
* ExportService.

SwiftUI views should not become the source of truth for business logic.

---

# 76. Testing

Testing should cover core behavioral rules.

High-priority test areas include:

* Habit recurrence.
* Daily instance generation.
* Completion.
* Deferral.
* Multi-pass deck ordering.
* Midnight rollover.
* Streak calculations.
* Momentum.
* XP.
* Schedule editing.
* Notifications.
* Premium entitlement.
* Trial eligibility.
* Subscription expiration.
* Restore Purchases.

StoreKit test configurations should represent:

* Free trial eligible.
* Trial declined.
* Active trial.
* Trial expired.
* Monthly subscriber.
* Annual subscriber.
* Expired subscriber.
* Restored subscriber.
* Failed purchase.
* Canceled purchase.

---

# 77. Product Priority

When implementation decisions conflict, prioritize in this order:

1. Today Deck quality.
2. Habit scheduling correctness.
3. Persistence correctness.
4. Completion correctness.
5. Deferral/multi-pass correctness.
6. Daily Rhythm.
7. Streaks and Momentum.
8. Daily Journey.
9. Notifications.
10. Analytics.
11. XP/progression.
12. Achievements.
13. Premium.
14. Cosmetic polish.

A beautiful analytics screen does not matter if today's habit queue is unreliable.

---

# 78. MVP Philosophy

The MVP should already feel like HabitQuest.

Do not interpret MVP as:

> ugly prototype containing every checkbox.

The initial release should establish the distinctive experience:

* Native Liquid Glass.
* Excellent Today Deck.
* Swipe completion.
* Not Now deferral.
* Reliable scheduling.
* Calm feedback.
* Streaks.
* Momentum.
* Daily Journey.
* Useful analytics.
* Progression.
* Premium-ready architecture.

Later versions can deepen the system.

---

# 79. Post-MVP Evolution

Potential future expansion includes:

* Smarter behavioral insights.
* Adaptive reminders.
* Weekly reviews.
* Habit correlations.
* Challenges.
* Deeper widgets.
* Apple Watch.
* HealthKit integrations.
* Siri/App Intents.
* Shortcuts.
* Calendar context.
* Additional progression systems.
* More sophisticated routines.
* Personal behavioral summaries.
* Carefully designed AI-assisted insights.

Each addition should pass one test:

> **Does this make maintaining healthy routines easier, more meaningful or more enjoyable?**

If not, it probably does not belong in HabitQuest.

---

# 80. Product Guardrails

HabitQuest should never become:

* A guilt engine.
* A notification spammer.
* A paywall maze.
* A gambling-style engagement system.
* An administrative database.
* An AI chatbot pretending to understand the user.
* A social network competing for attention.
* A product where Free users constantly encounter artificial limitations.

The application succeeds when users voluntarily return because completing their habits through HabitQuest feels better than tracking them elsewhere.

---

# 81. Monetization Guardrails

HabitQuest should never intentionally damage Free to make Premium attractive.

Do not:

* Limit Free users to an impractically small number of habits.
* Remove the core Today experience.
* Paywall ordinary habit completion.
* Paywall streaks entirely.
* Paywall basic analytics.
* Paywall ordinary notifications.
* Constantly display subscription prompts.
* Send frequent promotional pushes.
* Create fake urgency.
* Destroy Premium data after cancellation.
* Misrepresent trial eligibility.
* Hard-code App Store pricing.
* Use Apple Pay instead of StoreKit for Premium digital functionality.

Premium conversion should occur because users want **more HabitQuest**, not because HabitQuest Free becomes frustrating.

---

# 82. The HabitQuest Experience in One Day

A mature HabitQuest experience might look like this:

The user wakes up and receives a gentle reminder.

They open HabitQuest.

Today shows:

**Good morning.**

Their Daily Journey is beginning.

The first card appears:

> Vitamins
> Morning Routine
> 🔥 12 day streak

They swipe right.

A soft haptic responds.

The card clears.

XP rises subtly.

The next card:

> Meditate — 10 minutes

They are busy.

They swipe left.

> Not Now

The card quietly moves away.

Another habit appears.

Later, they return.

The meditation card eventually resurfaces.

This time they complete it.

During the afternoon they work through several more cards.

Their Daily Journey gradually fills.

In the evening they finish the final habit.

HabitQuest responds:

> **Day complete.**

Their Momentum increases.

Their streak continues.

Their XP progresses.

Nothing screams.

Nothing demands another session.

HabitQuest simply acknowledges:

> You showed up today.

Tomorrow, the journey begins again.

---

# 83. HabitQuest Premium Experience

A committed user gradually wants more.

They tap the 90-day Analytics view.

HabitQuest shows a preview:

> **Understand the patterns behind your progress.**

They discover that Premium can reveal long-term trends.

Another day they attempt to configure:

> Morning → Work → Evening Reset

HabitQuest explains that custom Daily Rhythm organization is available with Premium.

Later they want a second reminder for an important habit.

Again, Premium provides exactly the additional capability they now need.

At this point Premium does not feel like paying to remove arbitrary restrictions.

It feels like:

> **I use HabitQuest enough that the advanced version is genuinely useful to me.**

That is the intended conversion moment.

---

# 84. North-Star Product Principle

Every significant HabitQuest decision should ultimately be evaluated against one question:

> **Does this make it easier and more rewarding for someone to become the person they are trying to become through small, repeatable actions?**

HabitQuest should make everyday progress visible.

It should make starting easier.

It should make postponement recoverable.

It should make consistency rewarding.

It should make imperfection acceptable.

It should make long-term progress understandable.

And it should make opening a habit tracker feel less like checking a productivity database and more like continuing a personal journey.

---

# 85. Final Product Definition

HabitQuest is:

> **A calm, gamified, native iOS habit-building companion that transforms everyday routines into a satisfying daily journey. Users move through today's habits using an intuitive swipe-driven interface, build streaks and Momentum, earn persistent progression, understand their behavior through analytics, and gradually shape their day around intentional routines.**

The core experience remains genuinely useful for Free users.

HabitQuest Premium extends that experience with:

* Advanced Daily Rhythm and routines.
* Advanced scheduling.
* Smarter reminders.
* Deep behavioral analytics.
* Habit reflections.
* Advanced widgets.
* Personalization.
* Future behavioral intelligence.

The final product should occupy a space between:

**Habit Tracker × Wellness Companion × Personal Productivity × Lightweight RPG**

while remaining unmistakably native to iOS.

The defining feeling should be:

> **Calm progress.**

Not optimization for optimization's sake.

Not productivity guilt.

Not endless engagement.

Just the quiet satisfaction of repeatedly doing the things that matter.
