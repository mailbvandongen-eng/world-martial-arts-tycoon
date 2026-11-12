# Phase B: fighting at the centre (place version 19)

## What is new

- **Fight engine** (`src/shared/Modules/Bout.lua`): every bout is simulated exchange by
  exchange with the scoring of its discipline and played back move by move.
  - Karate kumite: yuko 1 / waza-ari 2 / ippon 3, 8-point lead or time, senshu on a tie.
  - Taekwondo, kung fu, Krav Maga: point fighting, 12-point gap.
  - Boxing, kickboxing, Muay Thai, MMA: 3 rounds, knockdowns, KO, judges' decision 10-9.
  - Judo: waza-ari / ippon (two waza-ari = ippon). BJJ and wrestling: points, submission or fall ends it.
  - Sumo: clashes until oshidashi / yorikiri.
  - Kata: two performers, five judges' flags. Exam kata: three judges' marks.
- **Competition hall** in every academy (left of the reception, door on the first walkway):
  tatami with the fighting area and AKA/AO lines, judges' table, stands, banners, scoreboard.
  Fighters (red and blue belts in karate), a referee who signals every point and judges who
  raise flags are drawn on every client; the wall scoreboard and a small on-screen board
  (when you are near) show names, score, round/time and the referee's call.
- **Sparring** (Students → Sparring): two of your students fight; both gain XP, the winner more.
  Win/loss record per student.
- **Belt exams**: students no longer get their next belt automatically. With enough XP they become
  *exam-ready*. The exam is a kata judged by three judges (pass mark rises per rank) and, from the
  third rank on, a kumite against an examiner. Pass = new belt + reputation; fail = retry after 90 s.
  *Exam day* examines up to six ready students one after another. A ready student who waits six
  classes is examined by the sensei automatically (so idle play still progresses).
- **Kumite yourself** (Training or Students → Kumite yourself): you are placed on the red mark of
  your hall; a rival fighter attacks. Answer each attack (high block, mid block, low block, punch on
  an opening) at the right moment. 8-point lead wins. Each win makes the next opponent faster
  (levels 1–20). Rewards: cash, XP, karate mastery, reputation.
- **Tournaments are fought for real**: every bracket match has a full bout that ends with the
  bracket's winner; the featured match (yours if you entered) is fought in the arena with
  scoreboard. New *Kata Open* tournament; the karate championship is kumite.
- Missions (kumite win, sparring, exams), 5 achievements, developer-menu section *Competition hall*.

## Test status

- **Automated (127,598 checks):** bout engine for all 12 disciplines (finishes, valid moves, time
  order, replayed scoreboard equals the result, stronger fighter wins 60–95 %, forced bracket
  winners); sparring, cooldowns, exam pass/fail, exam fee, kata + kumite from rank 3, kumite scoring
  (perfect answers win, nothing loses, wrong answers score for the opponent, faster at higher level,
  early-finish timing), old saves get the new fields; existing simulation still promotes students.
- **Technically checked:** static checker (actions, remotes, notify kinds, requires), render of the
  hall with a posed bout (`docs/images/competition_hall.png`).
- **Not yet played in Roblox:** client playback (BoutController), the kumite screen on a phone,
  teleport onto the mat, scoreboard text on the wall, arena playback.
