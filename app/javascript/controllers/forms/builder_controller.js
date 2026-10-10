import { Controller } from "@hotwired/stimulus"

// Classes for the previews drawn here: a field as the site shows it.
const PREVIEW = {
  label: "text-sm font-medium text-gray-900",
  required: "text-red-600",
  help: "text-xs text-gray-500",
  choices: "flex flex-col gap-1.5",
  choice: "flex items-center gap-2 text-sm text-gray-700",
  file: "rounded-md border border-dashed border-gray-300 p-3.5 text-center text-sm text-gray-500",
  // Disabled for looking at, but not dimmed as base.css dims a disabled control.
  control: "w-full opacity-100",
  check: "opacity-100"
}

// The form builder (forms/edit), after Payload's form builder: the fields as
// rows previewing them, a palette that adds fields, and a sheet that edits
// the picked one (the dialog outlet).
//
// Each field is a card in the list and a settings block in the sheet,
// matched by its row key. The card holds the row's first input, so rows post
// in the list's order (FormFields reads them back in that order); the
// settings hold the rest, all posted, only the picked one shown. A card's
// preview is drawn here from its settings, as the site would render it.
export default class extends Controller {
  static targets = [ "canvas", "dropzone", "card", "empty", "panel", "settings", "settingsList", "sheetTitle",
                     "cardTemplate", "settingsTemplate", "submitPreview" ]
  static outlets = [ "dialog" ]

  connect() {
    this.cardTargets.forEach(card => this.#render(card.dataset.key))
    this.#refresh()
    this.canvasTarget.addEventListener("dragstart", this.#cardDragStart)
    this.dropzoneTarget.addEventListener("dragover", this.#dragOver)
    this.dropzoneTarget.addEventListener("drop", this.#drop)
    this.canvasTarget.addEventListener("dragend", this.dragEnd)
    // A required setting left blank sits in a hidden block; open it so the
    // browser can point at it.
    this.element.addEventListener("invalid", this.#invalid, true)
  }

  disconnect() {
    this.canvasTarget.removeEventListener("dragstart", this.#cardDragStart)
    this.dropzoneTarget.removeEventListener("dragover", this.#dragOver)
    this.dropzoneTarget.removeEventListener("drop", this.#drop)
    this.canvasTarget.removeEventListener("dragend", this.dragEnd)
    this.element.removeEventListener("invalid", this.#invalid, true)
  }

  // Sheet

  showTab(event) {
    this.panelTarget.dataset.tab = event.currentTarget.dataset.tab
  }

  // Closing the sheet lets go of the field.
  unpick() {
    this.picked = null
    this.cardTargets.forEach(card => card.classList.remove("form-card--picked"))
  }

  // A palette button: a new field of its type, at the end.
  add(event) {
    const { type, label } = event.currentTarget.dataset
    this.#insert(type, label, card => this.canvasTarget.append(card))
  }

  // Cards

  // A row, or its Settings button. A click on one of the row's other
  // buttons (its moves) is theirs.
  pick(event) {
    if (event.currentTarget.matches(".form-card") && event.target.closest("button")) return

    this.#pick(event.currentTarget.closest(".form-card").dataset.key)
  }

  moveUp(event) {
    const card = this.#card(event)
    card.previousElementSibling?.before(card)
  }

  moveDown(event) {
    const card = this.#card(event)
    card.nextElementSibling?.after(card)
  }

  duplicate(event) {
    const card = this.#card(event)
    const key = this.#newKey()
    const settings = this.#settings(card.dataset.key)

    const settingsCopy = this.#copy(settings, card.dataset.key, key)
    settings.after(settingsCopy)
    const cardCopy = this.#copy(card, card.dataset.key, key)
    card.after(cardCopy)

    settingsCopy.dataset.autoname = "false"
    const name = this.#field(settingsCopy, "name")
    name.value = this.#uniqueName(name.value, settingsCopy)
    this.#render(key)
    this.#pick(key)
  }

  remove(event) {
    const card = this.#card(event)
    const key = card.dataset.key
    if (this.picked === key) this.picked = null

    this.#settings(key)?.remove()
    card.remove()
    this.#refresh()
  }

  // Settings

  changed(event) {
    const settings = event.target.closest(".form-settings")
    if (!settings) return

    const role = event.target.dataset.role
    if (role === "name") settings.dataset.autoname = "false"
    if (role === "label" && settings.dataset.autoname === "true") {
      this.#field(settings, "name").value = this.#uniqueName(this.#slug(event.target.value), settings)
    }
    this.#render(settings.dataset.key)
  }

  submitLabel(event) {
    this.submitPreviewTarget.textContent = event.target.value || "Submit"
  }

  // Drag and drop: cards reorder; palette buttons drop in a new field.

  paletteDragStart(event) {
    this.dragging = { type: event.currentTarget.dataset.type, label: event.currentTarget.dataset.label }
    this.placeholder = document.createElement("li")
    this.placeholder.className = "form-card form-card--placeholder h-14 rounded-lg border-2 border-dashed"
    event.dataTransfer.effectAllowed = "copy"
    event.dataTransfer.setData("text/plain", "")
  }

  dragEnd = () => {
    this.dragged?.classList.remove("form-card--dragging")
    this.dragged = null
    this.dragging = null
    this.placeholder?.remove()
    this.placeholder = null
  }

  #cardDragStart = (event) => {
    const card = event.target.closest?.(".form-card")
    if (!card) return

    this.dragged = card
    card.classList.add("form-card--dragging")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", "")
  }

  #dragOver = (event) => {
    const moving = this.dragged || this.placeholder
    if (!moving) return

    event.preventDefault()
    const card = event.target.closest?.(".form-card")
    if (!card) {
      if (!moving.isConnected) this.canvasTarget.append(moving)
      return
    }
    if (card === moving) return

    const { top, height } = card.getBoundingClientRect()
    if (event.clientY < top + height / 2) card.before(moving)
    else card.after(moving)
  }

  #drop = (event) => {
    if (!this.dragging) return

    event.preventDefault()
    const { type, label } = this.dragging
    const placeholder = this.placeholder
    this.#insert(type, label, card => placeholder?.isConnected ? placeholder.replaceWith(card) : this.canvasTarget.append(card))
    this.dragEnd()
  }

  #invalid = (event) => {
    // A field's setting picks the field, which opens its sheet, on the tab
    // holding it; one in another closed sheet (the webhook's) opens that.
    const settings = event.target.closest(".form-settings")
    if (settings) {
      this.#pick(settings.dataset.key)
      this.panelTarget.dataset.tab = event.target.closest(".form-settings__tab").dataset.tab
    } else {
      const dialog = event.target.closest("dialog")
      if (dialog && !dialog.open) dialog.showModal()
    }
  }

  // Helpers

  #insert(type, label, place) {
    const key = this.#newKey()
    const card = this.#fromTemplate(this.cardTemplateTarget, key)
    const settings = this.#fromTemplate(this.settingsTemplateTarget, key)
    this.settingsListTarget.append(settings)

    settings.dataset.autoname = "true"
    this.#field(settings, "type").value = type
    this.#field(settings, "label").value = label
    this.#field(settings, "name").value = this.#uniqueName(this.#slug(label), settings)
    if (type === "select" || type === "radio") this.#field(settings, "options").value = "First choice\nSecond choice\nThird choice"

    place(card)
    this.#render(key)
    this.#pick(key)
    card.scrollIntoView({ block: "nearest", behavior: "smooth" })
  }

  #pick(key) {
    this.picked = key
    this.cardTargets.forEach(card => card.classList.toggle("form-card--picked", card.dataset.key === key))
    this.settingsTargets.forEach(settings => { settings.hidden = settings.dataset.key !== key })
    this.#titleSheet(key)
    if (!this.panelTarget.open) this.dialogOutlet.open()
    this.#refresh()
  }

  #titleSheet(key) {
    const settings = this.#settings(key)
    if (!settings || key !== this.picked) return

    const label = this.#field(settings, "label").value.trim() || "Untitled"
    this.sheetTitleTarget.textContent = `${label} · ${this.#typeLabel(settings)}`
  }

  #refresh() {
    this.emptyTarget.hidden = this.cardTargets.length > 0
  }

  #typeLabel(settings) {
    const select = this.#field(settings, "type")
    return select.selectedOptions[0]?.textContent || select.value
  }

  // The card's preview, from its settings: label, the input, description.
  #render(key) {
    const card = this.cardTargets.find(card => card.dataset.key === key)
    const settings = this.#settings(key)
    if (!card || !settings) return

    const value = role => this.#field(settings, role)?.value.trim() || ""
    const type = value("type")
    const required = this.#field(settings, "required")?.checked
    const preview = card.querySelector("[data-role=preview]")
    preview.replaceChildren()
    card.querySelector("[data-role=kind]").textContent = this.#typeLabel(settings)
    card.querySelector("[data-role=name]").textContent = value("name")
    this.#titleSheet(key)

    const label = this.#element("span", PREVIEW.label, value("label") || "Untitled")
    if (required) label.append(this.#element("span", PREVIEW.required, " *"))

    if (type === "checkbox") {
      const row = this.#element("span", PREVIEW.choice)
      row.append(this.#control("input", { type: "checkbox" }), label)
      preview.append(row)
    } else {
      preview.append(label)
      preview.append(this.#input(type, value, settings))
    }

    if (value("help")) preview.append(this.#element("span", PREVIEW.help, value("help")))
  }

  #input(type, value, settings) {
    const typed = value("options").split("\n").map(line => line.trim()).filter(Boolean)
      .map(line => (line.split(" | ")[1] || line.split(" | ")[0]).trim())
    // Choices from a collection come first; the preview names the collection in their place.
    const collection = this.#field(settings, "options_collection")
    const choices = collection?.value ? [`${collection.selectedOptions[0].textContent}…`, ...typed] : typed

    switch (type) {
      case "textarea":
        return this.#control("textarea", { rows: 3, placeholder: value("placeholder") }, value("default"))
      case "select": {
        const select = this.#control("select")
        select.append(this.#element("option", null, choices[0] || "—"))
        return select
      }
      case "radio": {
        const list = this.#element("span", PREVIEW.choices)
        choices.forEach(choice => {
          const row = this.#element("span", PREVIEW.choice)
          row.append(this.#control("input", { type: "radio" }), this.#element("span", null, choice))
          list.append(row)
        })
        return list
      }
      case "file": {
        const several = this.#field(settings, "multiple")?.checked
        return this.#element("span", PREVIEW.file, several ? "Choose files…" : "Choose a file…")
      }
      default:
        return this.#control("input", { type: "text", placeholder: value("placeholder"), value: value("default") })
    }
  }

  #control(tag, attributes = {}, text = "") {
    const control = document.createElement(tag)
    for (const [name, value] of Object.entries(attributes)) if (value !== "") control.setAttribute(name, value)
    control.className = tag === "input" && attributes.type !== "text" ? PREVIEW.check : PREVIEW.control
    if (text) control.textContent = text
    control.disabled = true
    control.tabIndex = -1
    return control
  }

  #element(tag, className, text = "") {
    const element = document.createElement(tag)
    if (className) element.className = className
    if (text) element.textContent = text
    return element
  }

  #fromTemplate(template, key) {
    const holder = document.createElement("div")
    holder.innerHTML = template.innerHTML.replaceAll("__KEY__", key)
    return holder.firstElementChild
  }

  // A copy of a card or settings block under a new key, with what was typed
  // into it (outerHTML carries only the values it was rendered with).
  #copy(element, oldKey, newKey) {
    const holder = document.createElement("div")
    holder.innerHTML = element.outerHTML.replaceAll(`[${oldKey}]`, `[${newKey}]`)
    const copy = holder.firstElementChild
    copy.dataset.key = newKey
    copy.classList.remove("form-card--picked")

    const from = element.querySelectorAll("input, select, textarea")
    copy.querySelectorAll("input, select, textarea").forEach((control, index) => {
      if (control.type === "checkbox") control.checked = from[index].checked
      else control.value = from[index].value
    })
    return copy
  }

  // A field name no other field has: "email", then "email_2", "email_3"…
  #uniqueName(base, except = null) {
    base = base || "field"
    const taken = new Set(this.settingsTargets.filter(settings => settings !== except)
      .map(settings => this.#field(settings, "name").value))
    if (!taken.has(base)) return base

    let n = 2
    while (taken.has(`${base}_${n}`)) n++
    return `${base}_${n}`
  }

  #slug(text) {
    return text.toLowerCase().normalize("NFKD").replace(/[̀-ͯ]/g, "")
      .replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "")
  }

  #card(event) {
    return event.currentTarget.closest(".form-card")
  }

  #settings(key) {
    return this.settingsTargets.find(settings => settings.dataset.key === key)
  }

  #field(settings, role) {
    return settings.querySelector(`[data-role="${role}"]`)
  }

  #newKey() {
    return "n" + Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
  }
}
