# Competitor Review — Smart Academic Advisor

Review date: 2026-10-15

## Product direction

The app should be a practical, Persian-first study companion rather than a generic chatbot. Its near-term advantage should be simple tools that work offline and keep a learner's information on their own device. AI answers remain optional and must be clearly labeled when unavailable.

## What competitors do well

| Product | Useful pattern | What we should learn |
|---|---|---|
| [MyStudyLife](https://mystudylife.com/tour/) | Tasks, exam countdowns, grades, progress overview, focus timer and reminders | Tie study tasks to exam dates and show a learner what is coming next. |
| [Khan Academy](https://support.khanacademy.org/hc/en-us/articles/360007253831-Using-self-paced-practice-and-Mastery-in-the-classroom) | Progress and mastery tracking | Eventually show progress by subject/topic, not only a list of completed tasks. |
| [Quizlet](https://help.quizlet.com/hc/en-us/articles/25946589648013-Studying-with-Practice-Tests) | Practice tests from study material and flashcards | A later feature could turn a student's own notes into review questions, but only with reliable content/AI and clear limitations. |
| [Gajino](https://play.google.com/store/apps/details?hl=fa&id=ir.gaj.gajino) | Online courses, test banks, exam reports and ranking | Iranian learners value practice and feedback, but building a verified content bank is a separate, larger project. |
| [Quiz Center](https://quizcenter.ir/) | Timed tests and performance analysis | Topic-level analysis is valuable after the app has trustworthy question content and recorded answers. |
| [Virtual major-selection guide from Iran's National Organization of Educational Testing](https://blog.taraz.org/wp-content/uploads/2025/08/vijeh-nameh-1404-01.pdf) | Uses current candidate information alongside prior-year placement data and cautions that old-year data may change | Major-selection guidance must distinguish current official facts from historical estimates and must never promise admission. |

## Implemented from this review

- **Exam tracker:** locally stores exam name/date, shows a countdown, optionally records a score from 0–20, and calculates the average of recorded scores.
- **Focus timer:** a 25-minute timer with start, pause and reset, available without internet.\n- **Subject progress log:** record study minutes and a self-rated confidence score per subject; see total study time, session count and per-subject average confidence. Records are stored locally and can be cleared.
- Existing local task planner, completion state, study-method self-assessment and on-device notes remain available.

## Recommended next steps

1. **Subject progress log:** allow learners to record study time and self-rated confidence per subject; show a simple trend before attempting advanced analytics.
2. **Study plan linked to exam dates:** split a large exam into small revision tasks and keep the plan adjustable by the learner.
3. **Interest and values worksheet for major selection:** help compare interests, strengths, priorities, constraints and work environments. Label it as reflection—not a validated personality or aptitude test.
4. **Practice questions:** only after a properly sourced content set or a safely deployed AI service exists. Track incorrect answers by topic and encourage review rather than claiming a rank without valid comparison data.
5. **Optional reminders:** implement local notifications only after testing permissions, Android battery restrictions and behavior on real devices.
6. **Parent/guardian mode:** consider only with clear consent, privacy boundaries and age-appropriate data handling.

## Do not build yet

- Social leaderboards, friend leagues and competitive rankings: they add accounts, moderation, backend and privacy costs before the core study loop is proven.
- Automated admission probability based on unsupported or stale data.
- A personality/aptitude test marketed as a scientific diagnosis.
- Cloud accounts/sync until the privacy policy, server operations and deletion flow are ready.

## Current limitations

- Exam records, scores, notes and tasks are stored locally on the device; they do not sync across devices.
- The AI backend is not publicly deployed yet. Without a configured backend URL and provider key, guidance uses the offline rules.
- The focus timer does not yet issue notifications when the app is in the background.
- A passing CI run and successful debug APK build are required before treating the current code as verified; a debug APK is not a signed store release.
