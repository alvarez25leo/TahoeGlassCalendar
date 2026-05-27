import SwiftUI
import CoreGraphics

struct QuickEventComposerView: View {
    let initialDate: Date
    let editingEvent: CalendarEventItem?
    let calendars: [CalendarSource]
    let defaultCalendarID: String?
    let errorMessage: String?
    let onCancel: () -> Void
    let onSave: (NewEventDraft) async -> Bool

    private var isEditing: Bool { editingEvent != nil }

    @State private var title: String = ""
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var isAllDay: Bool = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var selectedCalendarID: String = ""
    @State private var isSaving: Bool = false
    @State private var showCalendarPicker: Bool = false
    @FocusState private var titleFocused: Bool

    private let workCalendar: Calendar = CalendarDateUtils.mondayFirstCalendar()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(CalendarTheme.subtleDividerOpacity)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: CalendarTheme.stackSpacing) {
                    titleField
                    locationField
                    dateSection
                    calendarSection
                    notesField
                }
                .padding(.horizontal, CalendarTheme.fieldPaddingH)
                .padding(.vertical, CalendarTheme.modalPaddingV)
            }

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .accessibilityLabel("Error: \(errorMessage)")
                }
                .padding(.horizontal, CalendarTheme.modalPaddingH)
                .padding(.bottom, CalendarTheme.tightSpacing)
            }

            Divider().opacity(CalendarTheme.subtleDividerOpacity)
            footer
        }
        .frame(width: CalendarTheme.modalWidth, height: CalendarTheme.modalHeight)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: CalendarTheme.modalCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CalendarTheme.modalCornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(CalendarTheme.popoverBorderOpacity), lineWidth: CalendarTheme.borderStrokeWidth)
        )
        .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isEditing ? "Editar evento" : "Nuevo evento")
        .onAppear {
            if let event = editingEvent {
                title = event.title
                location = event.location ?? ""
                notes = event.notes ?? ""
                isAllDay = event.isAllDay
                startDate = event.startDate
                endDate = event.endDate
                // Buscar calendario por título (eventIdentifier es el ID del evento,
                // no del calendario; usamos el título como heurística).
                if let match = calendars.first(where: { $0.title == event.calendarTitle }) {
                    selectedCalendarID = match.id
                } else {
                    selectedCalendarID = defaultCalendarID ?? calendars.first?.id ?? ""
                }
            } else {
                startDate = initialDate
                endDate = workCalendar.date(byAdding: .hour, value: 1, to: initialDate) ?? initialDate
                selectedCalendarID = defaultCalendarID ?? calendars.first?.id ?? ""
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                titleFocused = true
                headerIconBounce += 1
            }
        }
    }

    // MARK: - Background (Liquid Glass)

    @ViewBuilder
    private var panelBackground: some View {
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: CalendarTheme.modalCornerRadius, style: .continuous)
                )
        } else {
            Color.clear.background(.regularMaterial)
        }
    }

    // MARK: - Header

    @State private var headerIconBounce: Int = 0

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: isEditing ? "pencil.circle.fill" : "plus.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(selectedColor)
                .symbolEffect(.bounce, value: headerIconBounce)
                .contentTransition(.symbolEffect(.replace))

            Text(isEditing ? "Editar evento" : "Nuevo evento")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Text(headerDateString)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, CalendarTheme.modalPaddingH)
        .padding(.vertical, CalendarTheme.modalPaddingV)
    }

    private var headerDateString: String {
        DateFormatters.selectedDateLong.string(from: startDate)
    }

    // MARK: - Fields

    private var titleField: some View {
        TextField("Título", text: $title)
            .textFieldStyle(.plain)
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, CalendarTheme.fieldPaddingH)
            .padding(.vertical, CalendarTheme.fieldPaddingV + 1)
            .background(fieldBackground)
            .overlay(
                RoundedRectangle(cornerRadius: CalendarTheme.fieldCornerRadius, style: .continuous)
                    .stroke(
                        titleFocused ? selectedColor.opacity(0.65) : .clear,
                        lineWidth: CalendarTheme.focusStrokeWidth
                    )
                    .animation(CalendarTheme.microAnimation, value: titleFocused)
            )
            .focused($titleFocused)
            .submitLabel(.done)
            .onSubmit { Task { await save() } }
            .accessibilityLabel("Título del evento")
            .disabled(isSaving)
    }

    private var locationField: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.circle")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            TextField("Agregar ubicación", text: $location)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .accessibilityLabel("Ubicación")
                .disabled(isSaving)
        }
        .padding(.horizontal, CalendarTheme.fieldPaddingH)
        .padding(.vertical, CalendarTheme.fieldPaddingV)
        .background(fieldBackground)
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isAllDay.animation(.easeInOut(duration: 0.15))) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Todo el día")
                        .font(.system(size: 12))
                }
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

            if isAllDay {
                allDayDateRow
            } else {
                timedDateRows
            }
        }
        .padding(.horizontal, CalendarTheme.fieldPaddingH)
        .padding(.vertical, CalendarTheme.fieldPaddingV)
        .background(fieldBackground)
        .disabled(isSaving)
    }

    private var allDayDateRow: some View {
        HStack(spacing: 8) {
            DatePicker("Inicio", selection: $startDate, displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
                .font(.system(size: 12))
                .onChange(of: startDate) { _, newValue in
                    if endDate < newValue { endDate = newValue }
                }

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            DatePicker("Fin", selection: $endDate, in: startDate..., displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
                .font(.system(size: 12))
        }
    }

    private var timedDateRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Inicio")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 38, alignment: .leading)

                DatePicker(
                    "Inicio",
                    selection: $startDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .font(.system(size: 12))
                .onChange(of: startDate) { _, newValue in
                    if endDate < newValue {
                        endDate = workCalendar.date(byAdding: .hour, value: 1, to: newValue) ?? newValue
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Text("Fin")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 38, alignment: .leading)

                DatePicker(
                    "Fin",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .font(.system(size: 12))

                Spacer(minLength: 0)
            }
        }
    }

    private var calendarSection: some View {
        let selected = calendars.first(where: { $0.id == selectedCalendarID })
        return Button {
            showCalendarPicker.toggle()
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(colorOf(selected))
                    .frame(width: 10, height: 10)

                Text(selected?.title ?? "Selecciona calendario")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)

                if let source = selected?.sourceTitle, !source.isEmpty {
                    Text("· \(source)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, CalendarTheme.fieldPaddingH)
            .padding(.vertical, CalendarTheme.fieldPaddingV)
            .background(fieldBackground)
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .accessibilityLabel("Calendario seleccionado: \(selected?.title ?? "ninguno")")
        .accessibilityHint("Doble click para cambiar de calendario")
        .popover(isPresented: $showCalendarPicker, arrowEdge: .top) {
            calendarPickerPopover
        }
    }

    private struct SourceGroup: Identifiable {
        let id: String
        let calendars: [CalendarSource]
    }

    private var calendarSourceGroups: [SourceGroup] {
        let grouped = Dictionary(grouping: calendars, by: { $0.sourceTitle })
        return grouped
            .map { SourceGroup(id: $0.key, calendars: $0.value) }
            .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    private var calendarPickerPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(calendarSourceGroups) { group in
                if !group.id.isEmpty {
                    Text(group.id.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 2)
                }
                ForEach(group.calendars) { cal in
                    Button {
                        selectedCalendarID = cal.id
                        showCalendarPicker = false
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(cgColor: cal.color ?? defaultColor))
                                .frame(width: 9, height: 9)
                            Text(cal.title)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)
                            Spacer()
                            if cal.id == selectedCalendarID {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minWidth: 220)
        .padding(.vertical, 4)
    }

    private var notesField: some View {
        ZStack(alignment: .topLeading) {
            if notes.isEmpty {
                Text("Notas, URL…")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, CalendarTheme.fieldPaddingH)
                    .padding(.vertical, CalendarTheme.fieldPaddingV + 3)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            TextEditor(text: $notes)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, CalendarTheme.fieldPaddingH - 4)
                .padding(.vertical, CalendarTheme.tightSpacing)
                .accessibilityLabel("Notas del evento")
                .disabled(isSaving)
        }
        .frame(height: 52)
        .background(fieldBackground)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(action: onCancel) {
                Text("Cancelar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, CalendarTheme.modalPaddingH)
                    .frame(height: CalendarTheme.capsuleHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(scale: 0.94))
            .background(buttonCapsule(tint: nil))
            .keyboardShortcut(.cancelAction)

            Button {
                Task { await save() }
            } label: {
                HStack(spacing: 6) {
                    if isSaving {
                        ProgressView().controlSize(.small).scaleEffect(0.6)
                    }
                    Text(isEditing ? "Guardar" : "Crear")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .frame(height: CalendarTheme.capsuleHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(scale: 0.94))
            .background(buttonCapsule(tint: selectedColor))
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.55)
            .animation(.easeInOut(duration: 0.2), value: canSave)
        }
        .padding(.horizontal, CalendarTheme.modalPaddingH)
        .padding(.vertical, CalendarTheme.modalPaddingV)
    }

    @ViewBuilder
    private func buttonCapsule(tint: Color?) -> some View {
        if #available(macOS 26.0, *) {
            if let tint {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.regular.tint(tint).interactive(), in: Capsule())
            } else {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.regular.interactive(), in: Capsule())
            }
        } else {
            Capsule().fill(tint ?? Color.primary.opacity(0.08))
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !selectedCalendarID.isEmpty
            && !isSaving
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }

        let draft = NewEventDraft(
            title: title,
            location: location,
            notes: notes,
            startDate: isAllDay ? workCalendar.startOfDay(for: startDate) : startDate,
            endDate: isAllDay ? (workCalendar.date(byAdding: .day, value: 1, to: workCalendar.startOfDay(for: endDate)) ?? endDate) : endDate,
            isAllDay: isAllDay,
            calendarID: selectedCalendarID
        )
        _ = await onSave(draft)
    }

    private var selectedColor: Color {
        if let cal = calendars.first(where: { $0.id == selectedCalendarID }) {
            return Color(cgColor: cal.color ?? defaultColor)
        }
        return .accentColor
    }

    private func colorOf(_ cal: CalendarSource?) -> Color {
        Color(cgColor: cal?.color ?? defaultColor)
    }

    private var defaultColor: CGColor {
        CalendarTheme.defaultEventCGColor
    }

    @ViewBuilder
    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: CalendarTheme.fieldCornerRadius, style: .continuous)
            .fill(Color.primary.opacity(CalendarTheme.fieldFillOpacity))
    }
}
