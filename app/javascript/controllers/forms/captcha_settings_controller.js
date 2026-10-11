import { Controller } from "@hotwired/stimulus"

// Settings › Forms' spam protection: only the chosen provider's keys and
// options show (the page draws them that way; this follows the select).
export default class extends Controller {
  static targets = [ "provider", "group" ]

  show() {
    const provider = this.providerTarget.value
    this.groupTargets.forEach(group => { group.hidden = group.dataset.provider !== provider })
  }
}
