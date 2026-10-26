# WorkinAI

A local-first worksheet studio built with Flutter and Material 3.

Type a subject and a revision area, and WorkinAI asks a local LLM (or Gemini) to design a
complete, printable worksheet — including extra pages when the content needs them, a mix of
written, multiple-choice and matching questions, and diagram or working space. Learners can then
type answers, handwrite or draw on the page, print or download a PDF, check their answers, and ask
an AI to review the finished work. AI review marks typed answers with any text model; when the page
contains drawings, a vision-capable model can also inspect the page images. Profiles keep every
worksheet, score and answer separate, with a read-only parent view across all profiles.

Everything is stored in the browser. Worksheet requests go directly from the browser to the AI
server you configure; there is no WorkinAI backend.

## Features

- **AI worksheet designer** — subject, revision area, level, extra instructions and a question
  counter (1–20). Questions can be short written answers, longer responses, A/B/C multiple choice
  or matching cards. The AI can also add key terms and diagram/working blocks. Gemini can choose
  the page layout; local models produce the question set and WorkinAI lays it out over up to 4 A4
  pages.
- **Generating studio** — a full-screen progress view with live stages, elapsed time, rotating tips
  and a paper preview while the model works, plus retry and built-in recovery if it fails.
- **Built-in generator** — a ready-made worksheet for when no AI is configured or the server is
  unreachable.
- **Type or draw** — answer fields with ruled lines, plus a pen, five colours, an eraser, undo and
  clear for handwriting and diagrams.
- **Answer checking** — compares numeric answers, model answers and keyword alternatives, checks
  A/B/C choices and typed matching pairs, shows correct/try-again/review badges and keeps a score
  per worksheet.
- **AI review** — sends the typed answers as structured data to any text model, shows per-question
  feedback and can apply the AI's marks with one tap. If the page has drawings, a vision-capable
  model is also sent the page images; if it cannot read them, WorkinAI retries text-only and says
  that handwriting was not marked.
- **Print and PDF** — captures each page and creates a multi-page A4 PDF, ready to print or
  download.
- **Profiles, not folders** — each person has their own worksheets and scores. Switch profiles from
  the top bar.
- **Parent view** — every profile, worksheet, score, typed answer, expected answer, mark and piece
  of AI feedback in one read-only summary.
- **Material 3 theming** — light, dark or system, with a choice of seed colours.

## Requirements

- Flutter 3.47 or newer (Dart 3.13+)
- Python 3 for the Windows launcher / local static server
- A local OpenAI-compatible LLM server and/or a Gemini API key (both optional — the built-in
  generator works offline)

## Run it

### Windows launcher

1. Build the web app once (the launcher does this automatically if `build/web` is missing):
   ```bat
   flutter pub get
   flutter build web --release --no-web-resources-cdn
   ```
2. Double-click `run_workinai.bat`.

A local server starts on a free loopback port and your default browser opens WorkinAI. Close the
console window to stop the server.

### Flutter development server

```bat
flutter pub get
flutter run -d web-server --web-port 8080
```

Then open `http://127.0.0.1:8080/`.

### Manual static server

```bat
flutter build web --release --no-web-resources-cdn
python serve_workinai.py
```

## Connect a local LLM

Open **Settings → AI provider → Local server** and enter:

- **Server URL** — the base URL of an OpenAI-compatible API, for example
  `http://localhost:1234/v1` (LM Studio), `http://localhost:11434/v1` (Ollama) or
  `http://192.168.1.20:1234/v1` for another computer on the network.
- **Model name** — whatever your server has loaded, for example `deepseek-r1:1.5b` (Ollama),
  `qwen2.5-7b-instruct`, or a model you have loaded in LM Studio.
- **API key** — only if your server requires one.

Use **Test connection** to check the URL, model and network before generating. Reasoning models
such as `deepseek-r1` think before they answer, so the test can take 20–40 seconds; the generating
screen shows elapsed time and progress stages.

### Ollama quick start

```bat
ollama pull deepseek-r1:1.5b
ollama serve
```

Then use `http://localhost:11434/v1` and the model name `deepseek-r1:1.5b`. Recent Ollama versions
allow browser requests from localhost by default. If your browser blocks the request, set
`OLLAMA_ORIGINS=*` in the environment before starting Ollama and reload WorkinAI.

Small models are quick to download but variable in quality; they can take 30–120 seconds for six
questions and occasionally produce a weak or inaccurate question. A larger local model such as
`qwen2.5:7b-instruct` or a capable Gemini model gives better subject accuracy. WorkinAI requests
JSON mode from local OpenAI-compatible servers and will retry without it if a server rejects that
option.

The server must:

1. Accept `POST /v1/chat/completions` with the OpenAI request shape.
2. Allow requests from the WorkinAI page (CORS). For a browser app this is essential.
   - LM Studio: enable CORS in the local server settings.
   - Ollama: recent versions allow localhost origins; otherwise set `OLLAMA_ORIGINS=*` in the
     environment before starting `ollama serve`, or set the equivalent allowed-origins option.
3. Text-only models such as `deepseek-r1:1.5b` can generate worksheets and mark typed answers. Page
   images are only sent when the worksheet contains drawings; to have handwriting and diagrams
   marked, load a vision-capable model such as `llava` or a Qwen vision model and select it before
   requesting a review. If the model rejects images, WorkinAI automatically retries with typed
   answers only and explains that handwriting was not marked.

If the browser reports a CORS error, the server is running but is not allowing the page's origin.
The app shows the server's error message where possible.

## Gemini (optional)

Open **Settings → AI provider → Gemini**, add an API key from Google AI Studio, and choose a model
(default: `gemini-2.5-flash`). The key is stored only in this browser's local storage. Gemini
requests go directly to Google.

## Using worksheets

1. Pick the active profile (top bar) or add a new one.
2. Enter a subject and revision area, choose the number of questions, and select
   **Generate with AI** or **Built-in**.
3. In the editor:
   - **Type** — click an answer line and type. For multiple choice, tap the A/B/C card. For
     matching, draw lines between the columns or type pairs such as `1-B, 2-C, 3-A`.
   - **Draw** — choose **Draw**, pick a pen colour, then draw or write over the page. Use the
     eraser, undo or clear-drawing button as needed.
   - **Check** — marks numeric/model answers, choices and matching pairs, and flags open-ended
     questions for review.
   - **AI review** — checks the typed answers with your configured model. If the page has drawings
     and the model supports vision, it also reviews the page images; otherwise it explains that
     handwriting was not marked.
   - **Print** or **More → Download PDF** — captures every page as a clean A4 PDF.
4. Go back to the studio to see the saved score and page count. Open **Parent view** to inspect all
   profiles and answers.

Answers, marks, drawings, profiles, theme and AI settings are saved automatically in
`localStorage` under `workinai_state_v2`.

## Project layout

```
lib/
  main.dart                 Material 3 themes and app shell
  app_state.dart            local persistence, profiles, theme and AI settings
  models.dart               worksheet, page, section, block, stroke and review models
  ai_service.dart           OpenAI-compatible and Gemini requests, JSON parsing, text/vision review
  fallback_generator.dart   built-in worksheet generator
  screens/
    home_screen.dart        builder, question counter, profiles and history
    generating_screen.dart  live AI generation progress, retry and recovery
    worksheet_screen.dart   editor, drawing, checking, AI review and PDF export
    settings_screen.dart    appearance, AI configuration, data reset
    parent_screen.dart      read-only progress view across profiles
test/                       widget and generator tests
web/                        web shell and manifest
mockup.html                 approved early HTML design reference
```

## Tests

```bat
flutter analyze
flutter test
```

## Notes and limits

- Worksheet layouts are capped at 4 pages and 24 questions, and AI prompts ask for at most five
  questions per page so answers fit on A4. Local models return a flat question set that WorkinAI
  paginates automatically; Gemini can lay out the pages itself.
- Small local models can be inaccurate or inconsistent. Check the generated answer key before
  relying on it, or use a larger model for better results.
- Answer checking is deliberately simple and local: numeric equivalents, exact/normalised model
  answers, keyword matches, choice letters and typed matching pairs. Open-ended answers and
  unreadable work are marked **Review** until a person or the AI reviews them.
- AI review always checks typed answers. It only sends page images when the page contains drawing
  strokes, and only a vision-capable model can mark handwriting, drawn lines or diagrams. Text-only
  models cannot see the page, and the app says so in the review note.
- Printing captures the on-screen page, so keep the browser zoom at 100% for the clearest output.
- Clearing site data in the browser deletes profiles and worksheets. Use **Settings → Reset all**
  to do this intentionally.
