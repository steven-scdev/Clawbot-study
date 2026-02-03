Workforce Product Requirements Document
Document Type: Product Specification (Non-Technical)
Audience: Frontend Engineer, Backend Engineer, QA
Version: 1.0
Last Updated: February 3, 2026

How to Read This Document
This document defines what we're building and what success looks like — not how to build it. Engineers should use their judgment on implementation using the OpenClaw codebase.
For each feature, you'll find:

User Story — Who wants what and why
Success Outcome — What does "done" look like from the user's perspective
Experience Quality — How should it feel to use
Acceptance Criteria — Testable requirements
Edge Cases — Things that could go wrong and how to handle them


Part 1: Product Principles
The Core Experience We're Creating
Mental Model: "I have a team of AI employees who do real work for me."
Not: A chatbot. Not an AI assistant. Not a tool suite.
Key Qualities:
QualityWhat It MeansAnti-PatternProfessionalFeels like managing real employeesFeels like talking to a botEfficientGet work done fast, minimal frictionLots of back-and-forth, confusionTransparentAlways know what's happeningBlack box, no visibilityTrustworthyOutputs are reliable, usableOutputs need heavy editingRespectfulValues user's time and intelligencePatronizing, verbose, slow
The 5-Phase Workflow
Every task follows this flow. Users should internalize this quickly.
BRIEF → CLARIFY → PLAN → EXECUTE → REVIEW

Brief — User describes what they need
Clarify — Employee asks smart questions (if needed)
Plan — Employee shows their approach
Execute — Work happens with visible progress
Review — User sees output, can request changes

Success Metrics (How We'll Know It's Working)
MetricTargetWhy It MattersTime to first output< 5 minutes for simple tasksUsers feel immediate valueTask completion rate> 90%Employees reliably deliverUser intervention rate< 2 clarifications per taskQuestions are smart, not repetitiveOutput usability> 80% used without editingOutputs are truly readyReturn usage> 60% return within weekProduct is genuinely useful

Part 2: Phase 1 — Foundation (Emma End-to-End)
Goal
One employee (Emma, Web Builder) working completely, delivering a real website.
Why Emma First

Most tangible output (visible website)
Fastest "wow" moment
Tests the complete workflow
Validates our architecture


Feature 1.1: App Launch & Connection
User Story

As a user, when I open the app, I want to immediately see my workforce ready to work, so I can start assigning tasks.

Success Outcome
User opens app → sees their employees → can start working within 3 seconds.
Experience Quality

Instant — App feels ready immediately
Alive — Employees feel present and available
Clear — User knows exactly what they can do

Acceptance Criteria
#CriteriaHow to Test1App opens to main window showing employee sidebarLaunch app, observe2Employees appear within 2 seconds of launchLaunch app, time it3Each employee shows name, emoji, title, and statusVisual inspection4Connection status is visible somewhere (subtle)Look for indicator5If gateway not running, user sees helpful messageStop gateway, launch app6App window has sensible default size and positionLaunch on various screens
Edge Cases
SituationExpected BehaviorGateway not runningShow friendly message: "Starting your workforce..." with option to retryGateway takes long to respondShow subtle loading state, don't block UIConnection drops mid-useShow reconnecting indicator, auto-reconnect, resume stateFirst time launchSame experience, no onboarding friction

Feature 1.2: Employee Selection
User Story

As a user, I want to select an employee to assign them a task.

Success Outcome
User clicks Emma → Task input area appears → User knows what Emma can do.
Experience Quality

Responsive — Selection feels instant
Informative — User understands Emma's capabilities
Inviting — User is encouraged to describe their task

Acceptance Criteria
#CriteriaHow to Test1Clicking employee highlights them in sidebarClick each employee2Content area changes to show task input for selected employeeClick, observe3Employee's name, emoji, and specialty shown prominentlyVisual inspection4Brief description of what this employee doesRead the description5Selection persists until user selects different employeeClick away, click back6Can switch employees freely before starting a taskClick between employees
Edge Cases
SituationExpected BehaviorEmployee is busy with another taskShow "busy" indicator, user can still queue new taskUser clicks same employee twiceNo change (already selected)User has active task and clicks different employeeShow active task, ask if they want to switch view

Feature 1.3: Task Briefing (Input)
User Story

As a user, I want to describe what I need Emma to build in my own words, and optionally attach relevant files.

Success Outcome
User types description → Optionally attaches files → Clicks "Start" → Task is submitted.
Experience Quality

Freeform — User can describe naturally, no rigid format
Helpful — Placeholder text suggests what to include
Easy attachment — Drag-drop or click to add files
Confident — User feels their request will be understood

Acceptance Criteria
#CriteriaHow to Test1Large text area for task description (at least 5 lines visible)Visual inspection2Placeholder text gives helpful exampleCheck placeholder3Can type freely with no character limit shownType long description4"Start Task" or "Assign to Emma" button visibleLook for button5Button disabled until description has contentTry clicking with empty6Can attach files by clicking buttonClick attach, select file7Can attach files by dragging onto the viewDrag file onto area8Attached files shown with name and remove optionAttach, observe, remove9Can attach foldersAttach folder10Submitting shows loading stateClick submit, observe
Edge Cases
SituationExpected BehaviorUser submits empty descriptionButton should be disabled, or show inline errorUser attaches very large file (>100MB)Show warning, suggest alternativesUser attaches unsupported file typeAccept anyway (employee will handle or ask)Submission fails (network error)Show error message, preserve input, allow retryUser navigates away before submittingPreserve draft? (decide: yes/no, document decision)

Feature 1.4: Clarification Questions
User Story

As a user, when Emma needs more information to do the work well, I want her to ask me smart, specific questions rather than guessing or asking vague questions.

Success Outcome
Emma asks 2-4 specific questions → User answers quickly via checkboxes/buttons → Task proceeds.
Experience Quality

Smart — Questions feel intelligent and relevant
Fast — Answering takes seconds, not minutes
Structured — Not freeform chat, but clear options
Progressive — Only asks what's needed, when needed

Acceptance Criteria
#CriteriaHow to Test1Clarification view shows who is asking (Emma)Visual inspection2Questions are displayed one at a time or as clear listSubmit task, observe3Multiple choice questions show as radio buttons or checkboxesObserve question types4Options are clear and helpful (not generic)Read the options5Text input questions show appropriate placeholderIf text question, check6Required questions are markedLook for required indicator7Cannot proceed without answering required questionsTry to skip required8"Continue" button submits answersClick continue9If more questions needed, they appear (multi-round)May need specific test case10User can go back to edit their briefLook for back option
Question Quality Standards
QualityGood ExampleBad ExampleSpecific"What pages do you need? (select all)""Tell me more"Actionable"Do you have a logo? [Yes, I'll upload] [No, suggest one]""Do you have brand assets?"Bounded3-5 options to choose fromOpen-ended text for everythingContextualQuestions relate to what user said in briefGeneric questions for all tasks
Edge Cases
SituationExpected BehaviorNo clarification neededSkip directly to plan or executionUser provides incomplete answersShow which questions still need answersUser wants to change their briefProvide way to go back and editEmployee asks follow-up questionsHandle gracefully, show as continuation

Feature 1.5: Plan Presentation
User Story

As a user, I want to see Emma's plan before she starts working, so I can catch misunderstandings early.

Success Outcome
Emma shows plan → User understands approach → User approves or provides feedback.
Experience Quality

Transparent — User sees exactly what will happen
Confident — Plan seems reasonable and complete
Controllable — User can approve, modify, or reject
Quick — Reviewing plan takes < 30 seconds

Acceptance Criteria
#CriteriaHow to Test1Plan shown after clarification (or after brief if no clarification)Complete clarification2Plan includes summary of what will be builtRead plan3Plan shows key steps/componentsLook for structure4Estimated time shownLook for time estimate5"Approve" or "Start" button to proceedLook for button6Way to provide feedback or request changes to planLook for feedback option7Can go back to modify brief or answersLook for back option
Edge Cases
SituationExpected BehaviorUser rejects planProvide text input for feedback, generate new planPlan is very longScrollable, but summary visible without scrollingUser approves very quickly (didn't read)Allow, their choiceEmployee can't make a plan (insufficient info)Return to clarification with specific questions

Feature 1.6: Execution Progress
User Story

As a user, while Emma is working, I want to see what she's doing so I trust that work is happening and can catch issues early.

Success Outcome
User sees progress bar → Activity log updates → Preview shows work-in-progress → User feels informed but not overwhelmed.
Experience Quality

Alive — Something is always happening/updating
Informative — User understands what's being done
Non-blocking — User can do other things while waiting
Trustworthy — Progress feels real, not fake

Acceptance Criteria
#CriteriaHow to Test1Progress indicator shows overall completion (percentage or bar)Submit task, observe2Current activity shown in text ("Building hero section...")Watch during execution3Activity log shows completed steps with timestampsObserve log4New activities appear without page refreshWatch for updates5Completed steps show checkmark or similar indicatorVisual inspection6Current step shows spinner or "working" indicatorVisual inspection7Future steps shown as pendingVisual inspection8Preview pane shows work (for Emma: website preview)Look for preview9Preview updates periodically during workWatch preview change10"Cancel" option availableLook for cancel button11Cancel requires confirmationClick cancel, observe
Preview Requirements by Employee
EmployeePreview TypeUpdate FrequencyEmma (Web)Live website in embedded browserEvery major componentDavid (Decks)Current slide thumbnailEvery slide completedSarah (Research)Outline/draft textEvery sectionMaya (Visual)Image thumbnails as generatedEach imageMarcus (Data)Chart previewsEach visualization
Edge Cases
SituationExpected BehaviorTask takes very long (>10 min)Show encouraging message, maybe notification when doneProgress seems stuckAfter 60s no update, show "still working..." messageError occurs during executionShow error message, offer retry or cancelUser wants to cancelConfirm, then clean up any partial workUser closes app during executionTask continues, shows progress when app reopenedPreview fails to loadShow placeholder, don't block progress display

Feature 1.7: Output Review
User Story

As a user, when Emma finishes, I want to see the completed work and easily access/use it.

Success Outcome
Work complete → User sees output → Can open, download, or request changes → Output is ready to use.
Experience Quality

Celebratory — Completion feels like an accomplishment
Clear — Output is prominently displayed
Actionable — User knows exactly how to use it
Flexible — Easy to request changes if needed

Acceptance Criteria
#CriteriaHow to Test1Clear indication task is completeVisual inspection2Output preview prominently displayedLook for preview3For websites: live URL shown and clickableClick URL4For files: file location shownLook for path5"Open" button launches output in appropriate appClick open6"Show in Finder" reveals file locationClick reveal7Way to request changes/revisionsLook for feedback option8Revision request accepts text descriptionType revision request9After revision request, returns to execution phaseSubmit revision, observe10Way to mark task as fully complete/acceptedLook for complete button
Output Delivery Standards
EmployeePrimary OutputWhere It LivesHow to OpenEmmaLive websiteDeployed URL + local source codeBrowser for site, Finder for codeDavidPresentation~/Workforce/outputs/*.pptxPowerPoint/KeynoteSarahResearch report~/Workforce/outputs/*.md or *.pdfPreview or browserMayaImages~/Workforce/outputs/*.pngPreview or FinderMarcusAnalysis + data~/Workforce/outputs/*.xlsx + *.pdfExcel + Preview
Edge Cases
SituationExpected BehaviorDeployment fails (Emma)Show error, offer to just provide codeOutput file is largeStill works, just takes moment to openUser requests many revisionsAllow, but maybe suggest starting fresh after 3+Output has errors (broken links, etc.)Should be caught by quality checks before deliveryUser never marks completeFine, task stays in "completed" state

Feature 1.8: Task History (Minimal for Phase 1)
User Story

As a user, I want to see my recent tasks so I can revisit outputs or continue previous work.

Success Outcome
User can see recent tasks → Can view outputs from completed tasks → Can reference previous work.
Experience Quality

Accessible — Easy to find past work
Organized — Clear what each task was
Useful — Can actually use past outputs

Acceptance Criteria (Minimal for Phase 1)
#CriteriaHow to Test1Somewhere to see list of tasks (tab, section, or bottom panel)Look for task list2Tasks show employee, brief summary, and statusCheck task list3Clicking completed task shows its outputsClick completed task4Active task shown with progressCheck active task5Can navigate from task list to task detailClick task, observe
Edge Cases
SituationExpected BehaviorMany tasks (50+)Paginate or virtual scroll, don't slow downTask from long agoStill accessible, outputs still openableOutput file was deletedShow message "file not found", offer info

Part 3: Phase 2 — Core Employees
Goal
Add David (Decks), Sarah (Research), Alex (Writing), and Marcus (Data) — the employees that share the most infrastructure with Emma.
Shared Foundation
All employees use the same 5-phase workflow. The differences are:

Clarification questions (specific to domain)
Execution behavior (what work looks like)
Output type and preview (different renderers)


Feature 2.1: David — Deck Maker
User Story

As a user, I want David to create professional presentations so I don't have to spend hours in PowerPoint.

Success Outcome
User describes deck → David creates it → User downloads PPTX that looks professional and tells their story.
Clarification Questions (Examples)
QuestionTypeOptionsWhat is this deck for?Single choiceInvestor pitch, Sales proposal, Team presentation, Educational, OtherHow long should it be?Single choice5-10 slides, 10-15 slides, 15-20 slidesWhat tone?Single choiceFormal/corporate, Casual/friendly, Technical/detailedDo you have brand assets (logo, colors)?Single choiceYes (upload), No (suggest something)
Execution Experience

Activity: "Outlining narrative structure... Creating title slide... Building problem slide..."
Preview: Slide thumbnails that appear as each is created
User can see slide count growing

Output Experience

Gallery view of all slides (thumbnail strip + large preview)
Can click through slides
"Download PPTX" button
"Download PDF" button (optional)
Revision: "Make slide 4 simpler" works on specific slide

Quality Standards (What Makes a Good Deck)

Clear narrative flow (problem → solution → evidence → ask)
Consistent styling across all slides
No slide has too much text (max 6 bullet points, short sentences)
All text is readable (minimum font sizes respected)
Images/charts are relevant and clear
Speaker notes included for each slide


Feature 2.2: Sarah — Deep Researcher
User Story

As a user, I want Sarah to research topics and synthesize findings so I get insights, not just links.

Success Outcome
User asks research question → Sarah researches → User gets comprehensive report with sources.
Clarification Questions (Examples)
QuestionTypeOptionsWhat's the depth you need?Single choiceQuick overview (5 min), Standard research (15 min), Deep dive (30 min)Any specific sources to prioritize?Multiple choiceAcademic papers, News/media, Industry reports, Company sources, AllWhat format for the report?Single choiceExecutive summary, Detailed report, Bullet points
Execution Experience

Activity: "Searching academic sources... Reading industry analysis... Found 12 relevant sources... Synthesizing findings..."
Preview: Outline appears first, then sections fill in
User sees research happening (sources being consulted)

Output Experience

Rendered report (markdown or PDF preview)
Executive summary at top
Sections with findings
Sources listed with links
"Download PDF" and "Download Markdown" buttons
Can ask follow-up: "Go deeper on section 3"

Quality Standards (What Makes Good Research)

All claims have cited sources
Sources are credible (not random blogs)
Conflicting viewpoints acknowledged
Clear distinction between facts and analysis
Executive summary captures key insights
Actionable conclusions or recommendations


Feature 2.3: Alex — Content Writer
User Story

As a user, I want Alex to write polished content so I get professional copy without struggling to write.

Success Outcome
User describes content need → Alex writes → User gets ready-to-publish content.
Clarification Questions (Examples)
QuestionTypeOptionsWhat type of content?Single choiceBlog post, Email, Social media, Landing page copy, Press releaseTarget audience?Text input(freeform)Tone?Single choiceProfessional, Casual, Authoritative, Friendly, UrgentLength?Single choiceShort (<500 words), Medium (500-1000), Long (1000+)SEO keywords?Text input(optional, freeform)
Execution Experience

Activity: "Researching topic... Creating outline... Writing introduction... Writing body..."
Preview: Text appears as written, paragraph by paragraph
User sees document growing

Output Experience

Rendered text (markdown preview)
Word count shown
"Copy to clipboard" button
"Download as .md" / "Download as .docx" buttons
Revision: "Make the intro punchier"

Quality Standards (What Makes Good Content)

Matches requested tone consistently
No grammatical errors
Clear structure with logical flow
Compelling opening hook
Strong call-to-action (if appropriate)
SEO optimized (if keywords provided)


Feature 2.4: Marcus — Data Analyst
User Story

As a user, I want Marcus to analyze my data and tell me what it means, not just show me numbers.

Success Outcome
User uploads data → Marcus analyzes → User gets insights, visualizations, and recommendations.
Clarification Questions (Examples)
QuestionTypeOptionsWhat do you want to understand?Text input(freeform, or leave blank for general analysis)What kind of output?Multiple choiceKey insights summary, Detailed report, Interactive charts, Updated spreadsheetAny specific metrics to focus on?Text input(optional, freeform)
Execution Experience

Activity: "Reading data file... Found 3,847 rows and 12 columns... Cleaning data... Analyzing trends... Creating visualizations..."
Preview: Charts appear as created, insights text appears

Output Experience

Summary insights at top (3-5 key findings)
Charts/visualizations displayed
Detailed analysis below
"Download Report (PDF)" button
"Download Enhanced Spreadsheet" button (with formulas)
Can ask follow-up: "Why did Q3 drop?"

Quality Standards (What Makes Good Analysis)

Data correctly parsed and understood
Insights are actionable, not just descriptive
Visualizations are clear and properly labeled
Statistical claims are sound
Anomalies and outliers explained
Recommendations tied to data


Part 4: Phase 3 — Media Employees
Goal
Add Maya (Visual), Ryan (Video), and Luna (Audio) — employees that primarily use external generation APIs.
Key Difference from Phase 2
These employees rely heavily on external AI services (image generation, video generation, voice synthesis). The user experience focuses on:

Selection — Multiple options to choose from
Iteration — Easy to regenerate or adjust
Variations — Different versions of the same concept


Feature 3.1: Maya — Visual Designer
User Story

As a user, I want Maya to create professional images so I get visuals without learning design tools.

Success Outcome
User describes visual need → Maya generates options → User selects and downloads ready-to-use images.
Clarification Questions (Examples)
QuestionTypeOptionsWhat are these images for?Single choiceSocial media, Website, Presentation, Marketing, OtherWhich platforms/sizes?Multiple choiceTwitter (1200×675), LinkedIn (1200×627), Instagram square (1080×1080), Instagram story (1080×1920), CustomStyle direction?Single choiceModern/minimal, Bold/vibrant, Professional/corporate, Playful/creativeDo you have brand colors?Single choiceYes (enter hex), No (suggest based on industry)
Execution Experience

Activity: "Generating variations... Creating version 1... Creating version 2..."
Preview: Images appear one by one as generated (like Midjourney)
Loading placeholder for images in progress

Output Experience (Unique to Maya)
Gallery Selection View:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│   Maya created 4 variations. Select the ones you want:                       │
│                                                                              │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│   │              │  │              │  │              │  │              │    │
│   │  [Image 1]   │  │  [Image 2]   │  │  [Image 3]   │  │  [Image 4]   │    │
│   │              │  │              │  │              │  │              │    │
│   │  ☑️ Selected │  │  ☐ Select   │  │  ☑️ Selected │  │  ☐ Select   │    │
│   └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │ Adjustments: "Make the text bigger on selected images"               │  │
│   └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│   [Regenerate All]  [Adjust Selected]  [Download Selected]                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
Interaction Model

Click image to toggle selection
Click to enlarge single image
"Regenerate All" creates 4 new options
"Adjust Selected" takes text input and regenerates those
"Download Selected" saves all selected in all requested sizes

Quality Standards (What Makes Good Images)

Correct dimensions for each platform
Text is readable (proper contrast, size)
No artifacts or weird AI glitches
Consistent style across variations
Brand colors applied correctly
Professional composition


Feature 3.2: Luna — Audio Producer
User Story

As a user, I want Luna to create voiceovers and audio so I get professional sound without a studio.

Success Outcome
User provides script/need → Luna generates audio → User downloads ready-to-use audio file.
Clarification Questions (Examples)
QuestionTypeOptionsWhat type of audio?Single choiceVoiceover, Background music, Podcast intro, Sound effectFor voiceover — Voice style?Single choiceProfessional/authoritative, Warm/friendly, Energetic/upbeat, Calm/soothingFor voiceover — Gender?Single choiceMale, Female, No preferenceFor music — Mood?Single choiceUpbeat/energetic, Calm/ambient, Corporate/professional, Dramatic/cinematicLength?Single choiceShort (<30s), Medium (30-60s), Long (1-3 min)
Execution Experience

Activity: "Generating voice options... Creating audio..."
For voiceover: Show script with progress
For music: Show waveform building

Output Experience (Unique to Luna)
Voice Selection (if voiceover):
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│   Luna created 3 voice options:                                              │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ Voice A: "Sarah" — Warm, professional                                │   │
│   │ ▶️ [Play sample]                               ○ Select              │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ Voice B: "Michael" — Authoritative, clear                            │   │
│   │ ▶️ [Play sample]                               ● Selected            │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ Voice C: "Emma" — Energetic, friendly                                │   │
│   │ ▶️ [Play sample]                               ○ Select              │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   [Generate with selected voice]                                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
Audio Review:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │   ▶️  ▁▂▃▄▅▆▇█▇▆▅▄▃▂▁▂▃▄▅▆▇█▇▆▅▄▃▂▁  (waveform visualization)      │   │
│   │       0:00 ━━━━━━━━●━━━━━━━━━━━━ 1:24                               │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   Script with timestamps:                                                    │
│   [0:00] "Welcome to the future of small business..."                        │
│   [0:15] "Our platform helps you automate..."                                │
│                                                                              │
│   [Adjust: "Make the CTA more energetic"]                                    │
│                                                                              │
│   [Regenerate]  [Download MP3]  [Download WAV]                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
Quality Standards (What Makes Good Audio)

Clear, intelligible speech (for voiceover)
Appropriate pacing and emphasis
No clipping or distortion
Proper audio levels (broadcast standard)
Natural-sounding (not robotic)
Matches requested mood/tone


Feature 3.3: Ryan — Video Creator
User Story

As a user, I want Ryan to create videos so I can have video content without learning editing.

Success Outcome
User describes video need → Ryan creates it → User downloads ready-to-share video.
Clarification Questions (Examples)
QuestionTypeOptionsWhat type of video?Single choiceExplainer, Social media ad, Product demo, Testimonial-style, EducationalLength?Single choiceShort (15-30s), Medium (30-60s), Long (1-3 min)Aspect ratio?Single choiceLandscape (16:9), Square (1:1), Vertical (9:16)Include voiceover?Single choiceYes (AI voice), Yes (I'll provide), NoMusic?Single choiceYes (suggest), Yes (I'll provide), No
Execution Experience

Activity: "Writing script... Creating storyboard... Generating scene 1... Generating scene 2..."
Preview: Storyboard frames appear first, then video preview
Progress shows scene-by-scene

Output Experience (Unique to Ryan)
Storyboard Review (before full generation):
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│   Ryan's storyboard for your video:                                          │
│                                                                              │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│   │  Scene 1 │ │  Scene 2 │ │  Scene 3 │ │  Scene 4 │ │  Scene 5 │          │
│   │  Hook    │→│  Problem │→│  Solution│→│  Features│→│  CTA     │          │
│   │  (5s)    │ │  (10s)   │ │  (15s)   │ │  (20s)   │ │  (10s)   │          │
│   └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
│                                                                              │
│   Script preview:                                                            │
│   Scene 1: "Tired of spending hours on tasks that should take minutes?"      │
│   Scene 2: ...                                                               │
│                                                                              │
│   [Edit storyboard]  [Approve and generate video]                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
Video Review:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │                       [VIDEO PLAYER]                                 │   │
│   │                                                                      │   │
│   │                  ▶️  ━━━━━━━━●━━━━━━━━━━  0:42 / 1:00               │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   Scene timeline (click to edit specific scene):                             │
│   ┌─────┬─────────┬───────────────┬─────────────┬─────┐                     │
│   │Hook │ Problem │   Solution    │   Features  │ CTA │                     │
│   └─────┴─────────┴───────────────┴─────────────┴─────┘                     │
│                                                                              │
│   [Revise scene]  [Regenerate all]  [Download MP4]                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
Quality Standards (What Makes Good Video)

Clear narrative/story
Good pacing (no dead air, not rushed)
Text is readable on all backgrounds
Audio levels consistent
Smooth transitions
Works without sound (captions)
Correct aspect ratio and resolution


Part 5: Cross-Cutting Experiences
Feature 5.1: Error Handling
Philosophy
Errors should be helpful, not scary. User should always have a clear next action.
Error Types and Responses
Error TypeUser MessageActions OfferedConnection lost"Connection to your workforce was interrupted"Retry, Check gatewayTask failed"Emma ran into an issue: [specific error]"Retry, Modify brief, CancelGeneration failed (API)"Maya couldn't generate that image. This sometimes happens with complex requests."Try again, Simplify requestFile not found"The output file couldn't be found. It may have been moved."Regenerate, Show last locationTimeout"This is taking longer than expected"Keep waiting, Cancel
Error UX Requirements

Never show technical error messages to user
Always explain in human terms
Always offer at least one action
Preserve user's input so they can retry easily


Feature 5.2: Notifications
Philosophy
Keep users informed without being annoying.
Notification Rules
EventWhen App is FocusedWhen App is BackgroundTask completedUpdate UI onlySystem notificationTask failedShow in-app alertSystem notificationNeeds input (clarification mid-task)Show in-app promptSystem notificationProgress milestone (50%, etc.)Update UI onlyNone
System Notification Content

Title: "{Employee name} finished your task"
Body: Brief summary of what was done
Click: Opens app to that task


Feature 5.3: Settings
User Story

As a user, I want to configure where outputs are saved and which folders my employees can access.

Settings Needed (Phase 1)
SettingDefaultDescriptionOutput folder~/Workforce/outputsWhere completed files are savedShared foldersNoneFolders employees can read fromAuto-approve deploymentsAsk each timeWhether Emma deploys without asking
Settings UX

Accessible from app menu (Workforce > Settings) and keyboard shortcut (Cmd+,)
Changes apply immediately
Folder selection uses native file picker


Feature 5.4: Keyboard Navigation & Shortcuts
Essential Shortcuts
ActionShortcutNew taskCmd+NSettingsCmd+,Cancel current taskCmd+.Switch to employee 1-8Cmd+1 through Cmd+8Focus task inputCmd+L
Keyboard Navigation

Tab moves between interactive elements
Enter submits/confirms
Escape cancels/closes
Arrow keys navigate lists


Part 6: Quality Assurance Checklist
Before Each Release
Functional Tests

 Can complete full task with Emma (brief → output)
 All clarification question types work (single, multiple, text)
 Progress updates appear during execution
 Output files are created in correct location
 Output files open in correct application
 Revision requests work
 Task cancellation works
 Multiple tasks can be queued

Connection Tests

 App connects to gateway on launch
 App handles gateway not running
 App reconnects after connection drop
 App resumes task state after reconnection

Edge Case Tests

 Very long task description (1000+ characters)
 Rapid clicking doesn't break state
 Closing window during task (task continues)
 Reopening app shows task in correct state
 Empty/missing output folder
 File with same name already exists

Experience Tests

 All text is readable (contrast, size)
 No layout breaks at minimum window size
 Loading states appear when appropriate
 Error messages are helpful
 Time from click to response < 200ms for UI actions


Part 7: Glossary
TermDefinitionEmployeeAn AI specialist with a specific skill (Emma, David, etc.)TaskA unit of work assigned to an employeeBriefThe user's description of what they needClarificationQuestions the employee asks to understand the task betterPlanThe employee's proposed approach before startingExecutionThe phase where work is being doneOutputThe deliverable(s) produced by completed workRevisionA request to modify completed workGatewayThe backend service that runs employeesPhaseOne of the 5 stages: Brief, Clarify, Plan, Execute, Review

Part 8: Open Questions (For PM Decision)
These are product decisions that need to be made during implementation:

Draft preservation: If user types a brief but navigates away, should we save the draft?

Recommendation: Yes, save locally, restore when they return


Parallel tasks: Can user start a new task while another is running?

Recommendation: Yes, show both in task list


Task limits: Is there a maximum number of concurrent tasks?

Recommendation: Start with 3, can increase later


Revision limits: How many times can user request revisions?

Recommendation: Unlimited, but suggest "start fresh" after 3


Output retention: How long do we keep output files?

Recommendation: Indefinitely (user's files), but they can delete


Offline mode: What happens if user has no internet?

Recommendation: Show error, most features require internet



Document these decisions when made, and update this spec accordingly.

Summary: What Success Looks Like
Week 1 Success

User can open app, see Emma, describe a task, answer questions, watch progress, and get a deployed website
The whole experience takes < 5 minutes for a simple landing page
User says "that was easy" or "wow, that actually works"

Week 2 Success

User can use Emma, David, Sarah, Alex, and Marcus
Each employee feels competent at their specialty
Outputs are genuinely useful without heavy editing

Week 3+ Success

All 8 employees working
Users return because it saves them real time
Outputs are high enough quality to use professionally

The Feeling We're Creating

"I have a team that handles the work I don't want to do, and they're actually good at it."
