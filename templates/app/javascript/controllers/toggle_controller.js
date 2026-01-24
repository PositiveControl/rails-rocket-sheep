import { Controller } from "@hotwired/stimulus"

/**
 * Toggle Controller - Show/hide content with optional icon rotation
 *
 * Usage:
 *   <div data-controller="toggle" data-toggle-open-value="false">
 *     <button data-action="click->toggle#toggle">
 *       <span data-toggle-target="icon" class="transition-transform">▼</span>
 *       Toggle Content
 *     </button>
 *     <div data-toggle-target="content" class="hidden">
 *       Hidden content here
 *     </div>
 *   </div>
 *
 * With custom classes:
 *   <div data-controller="toggle"
 *        data-toggle-hidden-class="hidden"
 *        data-toggle-rotate-class="rotate-180">
 *     ...
 *   </div>
 */
export default class extends Controller {
  static targets = ["content", "icon"]
  static values = {
    open: { type: Boolean, default: false }
  }
  static classes = ["hidden", "rotate"]

  connect() {
    this.hiddenClass = this.hasHiddenClass ? this.hiddenClass : "hidden"
    this.rotateClass = this.hasRotateClass ? this.rotateClass : "rotate-180"
    this.updateVisibility()
  }

  toggle() {
    this.openValue = !this.openValue
  }

  open() {
    this.openValue = true
  }

  close() {
    this.openValue = false
  }

  openValueChanged() {
    this.updateVisibility()
  }

  updateVisibility() {
    this.contentTargets.forEach(el => {
      el.classList.toggle(this.hiddenClass, !this.openValue)
    })

    this.iconTargets.forEach(el => {
      el.classList.toggle(this.rotateClass, this.openValue)
    })
  }
}
