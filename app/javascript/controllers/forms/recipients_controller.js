import { Controller } from "@hotwired/stimulus"

// The notification email's recipients (form_emails/recipients): a Name and
// Email row each. Add puts an empty row at the end, focused; Remove takes a
// row out, or empties the last one, so there's always a row to fill in.
export default class extends Controller {
  static targets = [ "list", "row", "template" ]

  add() {
    const row = this.templateTarget.content.firstElementChild.cloneNode(true)
    this.listTarget.append(row)
    row.querySelector("input")?.focus()
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-forms--recipients-target='row']")
    if (this.rowTargets.length > 1) row.remove()
    else row.querySelectorAll("input").forEach(input => { input.value = "" })
  }
}
