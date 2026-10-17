import os
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, cm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_number(num_pages)
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)

    def draw_page_number(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#718096"))
        page_text = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(A4[0] - 1.5 * cm, 1.2 * cm, page_text)
        self.drawString(1.5 * cm, 1.2 * cm, "Task Manager App • MVVM Architecture & Codebase Guide")
        self.setStrokeColor(colors.HexColor("#E2E8F0"))
        self.setLineWidth(0.5)
        self.line(1.5 * cm, 1.6 * cm, A4[0] - 1.5 * cm, 1.6 * cm)
        self.restoreState()

def create_pdf(filename="Task_Manager_MVVM_Architecture_Guide.pdf"):
    doc = SimpleDocTemplate(
        filename,
        pagesize=A4,
        leftMargin=1.5 * cm,
        rightMargin=1.5 * cm,
        topMargin=1.8 * cm,
        bottomMargin=2.0 * cm,
    )

    styles = getSampleStyleSheet()

    # Custom styles
    primary_color = colors.HexColor("#6B5800")
    secondary_color = colors.HexColor("#FBE64E")
    dark_gray = colors.HexColor("#2D3748")

    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=20,
        leading=24,
        textColor=primary_color,
        spaceAfter=4,
    )

    subtitle_style = ParagraphStyle(
        'DocSubTitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=10.5,
        leading=14,
        textColor=colors.HexColor("#4A5568"),
        spaceAfter=12,
    )

    h1_style = ParagraphStyle(
        'SectionH1',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=13,
        leading=17,
        textColor=dark_gray,
        spaceBefore=14,
        spaceAfter=6,
        keepWithNext=True,
    )

    h2_style = ParagraphStyle(
        'SectionH2',
        parent=styles['Heading3'],
        fontName='Helvetica-Bold',
        fontSize=10.5,
        leading=14,
        textColor=primary_color,
        spaceBefore=10,
        spaceAfter=4,
        keepWithNext=True,
    )

    body_style = ParagraphStyle(
        'BodyDark',
        parent=styles['BodyText'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=12,
        textColor=dark_gray,
        spaceAfter=6,
    )

    body_bold = ParagraphStyle(
        'BodyBold',
        parent=body_style,
        fontName='Helvetica-Bold',
    )

    bullet_style = ParagraphStyle(
        'BulletStyle',
        parent=body_style,
        leftIndent=12,
        firstLineIndent=-8,
        spaceAfter=3,
    )

    code_style = ParagraphStyle(
        'CodeStyle',
        parent=body_style,
        fontName='Courier',
        fontSize=8,
        leading=10.5,
        textColor=colors.HexColor("#C53030"),
    )

    table_header = ParagraphStyle(
        'TableHeader',
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        textColor=colors.HexColor("#1A202C"),
    )

    table_cell = ParagraphStyle(
        'TableCell',
        fontName='Helvetica',
        fontSize=8,
        leading=10.5,
        textColor=dark_gray,
    )

    table_cell_bold = ParagraphStyle(
        'TableCellBold',
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=10.5,
        textColor=primary_color,
    )

    callout_style = ParagraphStyle(
        'CalloutText',
        parent=body_style,
        fontName='Helvetica-Oblique',
        fontSize=8.5,
        leading=12.5,
        textColor=colors.HexColor("#744210"),
    )

    story = []

    # Header Banner Card
    banner_content = [
        [
            Paragraph("<b>TASK MANAGER APP</b> — Codebase & Architecture Guide", title_style),
        ],
        [
            Paragraph("Complete Breakdown of MVVM Structure, Folder Roles, File Connections & Data Flow", subtitle_style),
        ],
        [
            Paragraph("<b>Stack:</b> Flutter 3 • Dart • Firebase Firestore & FCM • Provider • GoRouter &nbsp;&nbsp;|&nbsp;&nbsp; <b>Status:</b> 100% Tested & Verified", body_style),
        ]
    ]
    banner_table = Table(banner_content, colWidths=[A4[0] - 3.0 * cm])
    banner_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#FFFDF0")),
        ('BOX', (0,0), (-1,-1), 1.5, colors.HexColor("#E2D03B")),
        ('PADDING', (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,-1), (-1,-1), 8),
    ]))
    story.append(banner_table)
    story.append(Spacer(1, 10))

    # SECTION 1
    story.append(Paragraph("1. The Big Picture: MVVM Architecture", h1_style))
    story.append(Paragraph(
        "Yeh application <b>MVVM (Model - View - ViewModel) + Repository Pattern</b> follow karti hai. "
        "Iska basic rule hai ki <b>UI (Screens/Widgets) bilkul 'Dumb'</b> rahegi aur sara business logic, "
        "state management aur text parsing <b>ViewModels</b> me rahega.", body_style
    ))

    # Architecture Flow Box
    arch_flow = [
        [
            Paragraph("<b>Firebase Firestore</b><br/><font size=7 color='#718096'>Cloud Database</font>", table_header),
            Paragraph("◄►", table_header),
            Paragraph("<b>TaskRepository</b><br/><font size=7 color='#718096'>Data Access Layer</font>", table_header),
            Paragraph("◄►", table_header),
            Paragraph("<b>ViewModels</b><br/><font size=7 color='#718096'>State & Logic</font>", table_header),
            Paragraph("◄►", table_header),
            Paragraph("<b>Views & Screens</b><br/><font size=7 color='#718096'>UI Coordinator & Widgets</font>", table_header),
        ]
    ]
    t_arch = Table(arch_flow, colWidths=[2.6*cm, 0.7*cm, 3.2*cm, 0.7*cm, 3.2*cm, 0.7*cm, 4.4*cm])
    t_arch.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (0,0), colors.HexColor("#FEEBC8")),
        ('BACKGROUND', (2,0), (2,0), colors.HexColor("#EBF8FF")),
        ('BACKGROUND', (4,0), (4,0), colors.HexColor("#FEFCBF")),
        ('BACKGROUND', (6,0), (6,0), colors.HexColor("#C6F6D5")),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('PADDING', (0,0), (-1,-1), 6),
        ('BOX', (0,0), (-1,-1), 0.5, colors.HexColor("#CBD5E0")),
    ]))
    story.append(t_arch)
    story.append(Spacer(1, 8))

    story.append(Paragraph("<b>Char Mukhya Layers:</b>", body_style))
    story.append(Paragraph("• <b>1. Model Layer:</b> Data classes jo schema define karti hain (e.g. <code>Task</code>, <code>FloatingSheetType</code>).", bullet_style))
    story.append(Paragraph("• <b>2. Repository Layer:</b> Firebase Firestore se data fetch aur save karta hai. Iska UI se koi direct relation nahi hota.", bullet_style))
    story.append(Paragraph("• <b>3. ViewModel Layer:</b> State aur Business logic hold karta hai (ChangeNotifier use karke). Tasks filter karna, sorting, mention state sab yahan hota hai.", bullet_style))
    story.append(Paragraph("• <b>4. View Layer:</b> User interface (UI). ViewModel ke data ko render karta hai aur user clicks ko ViewModel ke pass bhejta hai.", bullet_style))

    story.append(Spacer(1, 6))

    # SECTION 2
    story.append(Paragraph("2. Folder Breakdown (Kaunsa Folder kya karta hai?)", h1_style))
    folder_data = [
        [Paragraph("Folder Path", table_header), Paragraph("Layer", table_header), Paragraph("Description & Main Responsibility", table_header)],
        [Paragraph("<code>lib/routes/</code>", code_style), Paragraph("Navigation", table_cell_bold), Paragraph("GoRouter rules. Route <code>/</code> par MapScreen ko ViewModels inject karta hai.", table_cell)],
        [Paragraph("<code>lib/services/</code>", code_style), Paragraph("Services", table_cell_bold), Paragraph("Firebase Messaging (FCM), Home widget service, aur web shortcut handlers.", table_cell)],
        [Paragraph("<code>map_screen/models/</code>", code_style), Paragraph("Model", table_cell_bold), Paragraph("<code>Task</code> class, <code>FloatingSheetType</code> enum, aur quick date options.", table_cell)],
        [Paragraph("<code>map_screen/repositories/</code>", code_style), Paragraph("Repository", table_cell_bold), Paragraph("<code>TaskRepository</code>: Firestore se CRUD operations (watchTasks, addTask, updateTask, deleteTask).", table_cell)],
        [Paragraph("<code>map_screen/services/</code>", code_style), Paragraph("Services", table_cell_bold), Paragraph("Task assignment push notifications aur Share/PDF print services.", table_cell)],
        [Paragraph("<code>map_screen/utils/</code>", code_style), Paragraph("Utils", table_cell_bold), Paragraph("<code>task_mention_parser.dart</code> (@, -, !, * shortcuts), date formatter, task constants.", table_cell)],
        [Paragraph("<code>map_screen/viewmodels/</code>", code_style), Paragraph("ViewModel", table_cell_bold), Paragraph("<code>MapScreenViewModel</code> (tasks list, sort, search, selection) aur <code>AddTaskViewModel</code>.", table_cell)],
        [Paragraph("<code>map_screen/screens/</code>", code_style), Paragraph("View Coordinator", table_cell_bold), Paragraph("<code>map_screen.dart</code> (Clean coordinator ~267 lines) aur <code>task_detail_page.dart</code>.", table_cell)],
        [Paragraph("<code>map_screen/screens/views/</code>", code_style), Paragraph("View Sub-modules", table_cell_bold), Paragraph("AppBar, TabViews (8 tabs), AddTaskBottomSheet composer, FloatingMetadataSheet dropdown.", table_cell)],
        [Paragraph("<code>map_screen/screens/dialogs/</code>", code_style), Paragraph("Dialogs", table_cell_bold), Paragraph("Shortcuts help dialog, zoom slider, notifications modal, delete confirmation.", table_cell)],
        [Paragraph("<code>map_screen/screens/widgets/</code>", code_style), Paragraph("Atomic Widgets", table_cell_bold), Paragraph("Reusable tiles (<code>MapTaskListItem</code>, <code>SheetOptionButton</code>, metadata badges).", table_cell)],
    ]
    t_folder = Table(folder_data, colWidths=[4.2*cm, 2.5*cm, 8.8*cm])
    t_folder.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#EDF2F7")),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#CBD5E0")),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('PADDING', (0,0), (-1,-1), 4.5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor("#F8FAFC")]),
    ]))
    story.append(t_folder)

    story.append(PageBreak())

    # SECTION 3
    story.append(Paragraph("3. File-by-File Catalog (Kaunsi File me kya Code hai?)", h1_style))
    story.append(Paragraph("Refactoring ke baad har ek file ki single responsibility fix kar di gayi hai:", body_style))

    file_catalog = [
        [Paragraph("File Name", table_header), Paragraph("Role & Lines", table_header), Paragraph("Key Methods & Code Details", table_header)],
        [
            Paragraph("<code>map_screen.dart</code>", code_style),
            Paragraph("<b>Coordinator</b><br/>~267 lines", table_cell),
            Paragraph("Screen skeleton. AppBar, Search bar, TabBar (8 tabs) aur Add Task FAB ko assemble karta hai. ViewModel se data listen karke UI updates trigger karta hai.", table_cell)
        ],
        [
            Paragraph("<code>map_screen_viewmodel.dart</code>", code_style),
            Paragraph("<b>ViewModel</b><br/>~620 lines", table_cell),
            Paragraph("Central state: <code>tasks</code>, <code>listenForTasks()</code>, <code>addTask()</code>, <code>toggleTaskDone()</code>, <code>sectionsForWork()</code>, multi-selection state, sort/group/zoom filters.", table_cell)
        ],
        [
            Paragraph("<code>add_task_viewmodel.dart</code>", code_style),
            Paragraph("<b>ViewModel</b><br/>~120 lines", table_cell),
            Paragraph("Task creation form state: <code>priority</code>, <code>deadline</code>, <code>assignees</code>, draggable button order (SharedPreferences me save/load), <code>submitTask()</code>.", table_cell)
        ],
        [
            Paragraph("<code>task_repository.dart</code>", code_style),
            Paragraph("<b>Repository</b><br/>~140 lines", table_cell),
            Paragraph("Firestore calls: <code>watchTasks()</code> (realtime snapshot stream), <code>addTask()</code>, <code>updateTask()</code>, <code>deleteTask()</code>, loadClients, loadAssignees.", table_cell)
        ],
        [
            Paragraph("<code>task_mention_parser.dart</code>", code_style),
            Paragraph("<b>Utility</b><br/>~90 lines", table_cell),
            Paragraph("Text shortcuts parsing: <code>parseMention()</code> (@, -, !, *, +, #, ^), <code>matchesSearchQuery()</code> (fuzzy search), <code>removeMentionToken()</code>.", table_cell)
        ],
        [
            Paragraph("<code>add_task_bottom_sheet.dart</code>", code_style),
            Paragraph("<b>View Component</b><br/>~700 lines", table_cell),
            Paragraph("Bottom sheet composer: Autocomplete mentions popup, metadata button pills bar, keyboard focus management (<code>refocusComposer</code>), task submit button.", table_cell)
        ],
        [
            Paragraph("<code>floating_metadata_sheet.dart</code>", code_style),
            Paragraph("<b>View Overlay</b><br/>~410 lines", table_cell),
            Paragraph("Dropdown overlay menu: Dynamic coordinate positioning, search filter in options, custom date picker integration, single/multi-select support.", table_cell)
        ],
        [
            Paragraph("<code>map_screen_tab_views.dart</code>", code_style),
            Paragraph("<b>View Component</b><br/>~315 lines", table_cell),
            Paragraph("8 Tab Views: MyDay, MyWork, Assign (openAssigneeOnTap), AllWork, Done, Overdue, Pending, GroupBy. Har task tile ka click aur selection handle karta hai.", table_cell)
        ],
        [
            Paragraph("<code>map_screen_app_bar.dart</code>", code_style),
            Paragraph("<b>View Component</b><br/>~120 lines", table_cell),
            Paragraph("Dual mode AppBar: Normal Mode (Notification badge count, Search toggle, More options) aur Multi-select Mode (Delete selected tasks, Selected count, Cancel).", table_cell)
        ],
        [
            Paragraph("<code>map_screen_toolbar_menu.dart</code>", code_style),
            Paragraph("<b>View Component</b><br/>~125 lines", table_cell),
            Paragraph("More options popup: Sort by dialog, Group by dialog, View type dialog, Zoom slider dialog, Add to home screen shortcut, Share list, Print PDF.", table_cell)
        ],
        [
            Paragraph("<code>assignee_tasks_view.dart</code>", code_style),
            Paragraph("<b>View Screen</b><br/>~105 lines", table_cell),
            Paragraph("Kisi specific assignee ke assigned tasks ko <code>MyWorkView</code> format (Urgent, Today, Tomorrow) me render karta hai.", table_cell)
        ],
        [
            Paragraph("<code>task_metadata_badges.dart</code>", code_style),
            Paragraph("<b>Widget</b><br/>~45 lines", table_cell),
            Paragraph("Task tiles ke niche <code>@Assignee</code>, <code>#ClientName</code>, <code>+WorkType</code> ke badges draw karta hai.", table_cell)
        ],
    ]
    t_catalog = Table(file_catalog, colWidths=[4.2*cm, 2.5*cm, 8.8*cm])
    t_catalog.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#EDF2F7")),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#CBD5E0")),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('PADDING', (0,0), (-1,-1), 4),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor("#F8FAFC")]),
    ]))
    story.append(t_catalog)

    story.append(Spacer(1, 10))

    # SECTION 4
    story.append(Paragraph("4. Data Flow: Kaunsi File Kisse Connect Hai?", h1_style))

    story.append(Paragraph("<b>Scenario A: App Launch hone par Data Load ka Flow</b>", h2_style))
    story.append(Paragraph("1. <code>main.dart</code> app initialize karta hai aur <code>AppRouter</code> call hota hai.", bullet_style))
    story.append(Paragraph("2. <code>app_router.dart</code> home route par <code>MapScreenViewModel</code> create karke <code>MapScreen</code> ko provide karta hai.", bullet_style))
    story.append(Paragraph("3. <code>MapScreen</code> ki <code>didChangeDependencies()</code> me <code>viewModel.listenForTasks(authVM)</code> start hota hai.", bullet_style))
    story.append(Paragraph("4. <code>MapScreenViewModel</code> direct <code>TaskRepository.watchTasks()</code> se Firestore snapshot stream start karta hai.", bullet_style))
    story.append(Paragraph("5. Firestore se tasks aate hain -> ViewModel user role check karke filter karta hai (<code>isTaskVisibleToUser</code>).", bullet_style))
    story.append(Paragraph("6. ViewModel <code>notifyListeners()</code> call karta hai -> <code>MapScreenTabViews</code> automatically render ho jati hai.", bullet_style))

    story.append(Paragraph("<b>Scenario B: Naya Task Add hone ka Flow</b>", h2_style))
    story.append(Paragraph("1. User <code>+</code> button dabata hai -> <code>AddTaskBottomSheet.show(context)</code> bottom sheet open karta hai.", bullet_style))
    story.append(Paragraph("2. User type karta hai <code>'Meeting @Aman !Today'</code> -> <code>task_mention_parser.dart</code> shortcuts detect karta hai.", bullet_style))
    story.append(Paragraph("3. Metadata values <code>AddTaskViewModel</code> me save hoti hain.", bullet_style))
    story.append(Paragraph("4. User <b>Send</b> icon dabata hai -> <code>addVm.submitTask(...)</code> call hota hai.", bullet_style))
    story.append(Paragraph("5. Yeh <code>mapViewModel.addTask(...)</code> ko call karta hai, jo <code>TaskRepository.addTask(task)</code> se Firestore me save karta hai.", bullet_style))
    story.append(Paragraph("6. Saath hi <code>task_assignment_notification_service.dart</code> assignee ko push notification bhej deta hai.", bullet_style))

    story.append(PageBreak())

    # SECTION 5
    story.append(Paragraph("5. 'Ye Hume Kaise Pata Chalega?' (Code Tracing Guide)", h1_style))
    story.append(Paragraph("Agar aage chalkar aapko codebase me koi nayi cheez trace karni ho ya debugging karni ho, toh yeh 4 golden rules follow karein:", body_style))

    tracing_content = [
        [
            Paragraph("<b>Rule 1: Top Imports Dekho</b>", table_cell_bold),
            Paragraph("Kisi bhi file ke top par <code>import ...</code> dekhein. Agar kisi view file me <code>import '../viewmodels/map_screen_viewmodel.dart'</code> hai, toh iska seedha matlab hai ki yeh UI file ViewModel se judi hui hai.", table_cell)
        ],
        [
            Paragraph("<b>Rule 2: Provider Calls Dhundho</b>", table_cell_bold),
            Paragraph("File me <code>Provider.of&lt;ViewModelName&gt;(context)</code> ya <code>context.watch()</code> search karein. Jiss ViewModel ka naam likha hai, UI usi se data le rahi hai aur wahi uski state ka source hai.", table_cell)
        ],
        [
            Paragraph("<b>Rule 3: F12 / Ctrl+Click (Go to Definition)</b>", table_cell_bold),
            Paragraph("VS Code me kisi bhi function ya variable par <code>F12</code> dabane par editor seedhe us file par le jata hai jahan wo function define hai. <code>Shift + F12</code> se pata chalta hai ki wo pure project me kahan-kahan use ho raha hai.", table_cell)
        ],
        [
            Paragraph("<b>Rule 4: AppRouter Check Karein</b>", table_cell_bold),
            Paragraph("Nayi screen ka connection samajhne ke liye <code>lib/routes/app_router.dart</code> dekhein. Wahan saaf dikhta hai ki kaunsa Route kis Screen ko open karta hai aur usme kaunse ViewModels pass kiye gaye hain.", table_cell)
        ],
    ]
    t_tracing = Table(tracing_content, colWidths=[4.5*cm, 11.0*cm])
    t_tracing.setStyle(TableStyle([
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#CBD5E0")),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('PADDING', (0,0), (-1,-1), 6),
        ('ROWBACKGROUNDS', (0,0), (-1,-1), [colors.white, colors.HexColor("#F8FAFC")]),
    ]))
    story.append(t_tracing)
    story.append(Spacer(1, 14))

    # SECTION 6
    story.append(Paragraph("6. Interview & Team Presentation Pitch (Cheat Sheet)", h1_style))
    pitch_text = (
        "\"Humara Task Manager project ek clean <b>MVVM (Model-View-ViewModel) + Repository Pattern</b> par architected hai. "
        "Data layer me <b>TaskRepository</b> Firestore backend se real-time streams handle karta hai. "
        "Business logic <b>MapScreenViewModel</b> aur <b>AddTaskViewModel</b> me encapsulated hai jo state, role-based filtering, "
        "aur mention shortcuts (@, -, !, *) manage karte hain. "
        "View layer ko humne completely modular rakha hai jahan <b>MapScreen</b> sirf ek lightweight coordinator hai (~267 lines), "
        "aur saare 8 UI tabs, floating overlays, aur task composers standalone widgets ke roop me clean aur reusable hain.\""
    )
    pitch_box = [
        [Paragraph("<b>Ready-to-Speak Pitch:</b>", table_header)],
        [Paragraph(pitch_text, callout_style)]
    ]
    t_pitch = Table(pitch_box, colWidths=[15.5*cm])
    t_pitch.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#FFFDF0")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#D69E2E")),
        ('PADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(t_pitch)

    # Build PDF
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"PDF successfully created: {filename}")

if __name__ == "__main__":
    create_pdf()
