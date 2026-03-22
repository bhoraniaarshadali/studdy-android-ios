# Studdy 📚

An AI-powered exam platform for teachers and students. Teachers can create exams from PDF syllabi using AI, and students can take exams with a clean, anti-cheat interface.

---

## 🚀 Features

### Teacher Side
- **AI MCQ Generation** — Upload a PDF or paste text, AI generates MCQs automatically
- **PDF Text Extraction** — Powered by KIE.AI (Gemini Flash), extracts content from any PDF
- **Question Review** — Edit, delete, or manually add questions before publishing
- **Result Modes** — Choose Instant (auto-show result) or Manual (teacher publishes results)
- **Exam Timer** — Set duration (e.g. 30/60/90 min) or time window (e.g. 9AM–11AM)
- **Exam Publishing** — Generate 6-digit code + QR code for students to join
- **QR Sharing** — Share QR code as image via any app
- **Teacher Dashboard** — View all exams, student count, timer status
- **Exam Detail** — Leaderboard, publish results, per-student response review
- **Student Response Viewer** — See exactly which option each student selected

### Student Side
- **Flexible Join** — Enter exam code manually or scan QR code
- **Gallery QR Scan** — Pick QR image from gallery if camera not available
- **Enrollment Based** — Students identified by enrollment number (no password needed)
- **Student Dashboard** — View upcoming exams and past results
- **Exam Interface** — Clean MCQ UI with previous/next navigation
- **Auto Submit** — Exam auto-submits when timer runs out
- **Timer Warnings** — Alerts at 5 minutes and 1 minute remaining
- **Result Review** — Detailed answer review showing correct/wrong per question
- **Submitted Exam Block** — Cannot attempt same exam twice
- **Persistent Login** — Stay logged in until manual logout (coming soon)

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Android + iOS) |
| Database | Supabase (PostgreSQL) |
| AI / MCQ Generation | KIE.AI — Gemini Flash 3 |
| PDF Processing | KIE.AI Gemini multimodal |
| QR Code | qr_flutter |
| QR Scanner | mobile_scanner |
| File Picker | file_picker |
| Image Picker | image_picker |
| Screenshot | screenshot |
| Share | share_plus |
| Local Storage | shared_preferences |

---

## 🗄️ Database Schema (Supabase)

### exams
| Column | Type | Description |
|---|---|---|
| id | uuid | Primary key |
| code | text | 6-digit unique exam code |
| title | text | Exam title |
| questions | jsonb | Array of MCQ questions |
| result_mode | text | instant or manual |
| results_published | bool | Whether results are visible |
| timer_mode | text | none, duration, or window |
| duration_minutes | int4 | Minutes allowed (duration mode) |
| window_start | timestamptz | Exam window start time |
| window_end | timestamptz | Exam window end time |
| created_at | timestamptz | Creation timestamp |

### results
| Column | Type | Description |
|---|---|---|
| id | uuid | Primary key |
| exam_code | text | Reference to exam |
| enrollment_number | text | Student identifier |
| score | int4 | Correct answers count |
| total | int4 | Total questions |
| answers | jsonb | Student's selected answers |
| created_at | timestamptz | Submission timestamp |

### students
| Column | Type | Description |
|---|---|---|
| id | uuid | Primary key |
| enrollment_number | text | Unique student identifier |
| created_at | timestamptz | Registration timestamp |

---

## 📱 App Flow

### Teacher Flow
1. Open app → Teacher
2. Dashboard → Create Exam
3. Upload PDF or paste content
4. Set questions count, options, difficulty
5. Set result mode (Instant/Manual)
6. Set timer (None/Duration/Window)
7. Generate MCQs with AI
8. Review and edit questions
9. Publish → Get 6-digit code + QR
10. Share QR/code with students
11. Monitor results in Dashboard → Exam Detail

### Student Flow
1. Open app → Student
2. Enter exam code (or scan QR)
3. Enter enrollment number
4. Auto-detected: new or existing student
5. Dashboard shows upcoming + past exams
6. Start exam → Answer MCQs
7. Submit (or auto-submit on timeout)
8. View result (instant or wait for teacher)

---

## 🔧 Setup

### Prerequisites
- Flutter SDK
- Android Studio / VS Code
- Supabase account
- KIE.AI API key

### Installation
1. Clone the repo:
   git clone https://github.com/bhoraniaarshadali/studdy-android-ios.git

2. Install dependencies:
   flutter pub get

3. Update API keys in:
   - lib/services/kie_ai_service.dart (KIE.AI key)
   - lib/main.dart (Supabase URL + anon key)

4. Run the app:
   flutter run

---

## 📋 Roadmap

- [ ] Persistent login (shared_preferences)
- [ ] Anti-cheat (fullscreen lock, tab switch detection)
- [ ] Teacher auth (proper login/signup)
- [ ] Export results (PDF/Excel)
- [ ] Push notifications (exam reminders)
- [ ] Dark mode
- [ ] Multiple teachers support
- [ ] Question bank

---

## 👨💻 Developer

Arshad ali Bhorania
GitHub: bhoraniaarshadali

---