import { Controller } from "@hotwired/stimulus"

/**
 * Modal Controller - Dialog/overlay management with keyboard support
 *
 * Usage:
 *   <div data-controller="modal">
 *     <button data-action="click->modal#open">Open Modal</button>
 *
 *     <div data-modal-target="overlay" class="hidden fixed inset-0 bg-black/50 z-40"
 *          data-action="click->modal#close"></div>
 *
 *     <div data-modal-target="dialog" class="hidden fixed inset-0 z-50 flex items-center justify-center">
 *       <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
 *         <h2>Modal Title</h2>
 *         <p>Modal content here</p>
 *         <button data-action="click->modal#close">Close</button>
 *       </div>
 *     </div>
 *   </div>
 *
 * Features:
 *   - ESC key closes the modal
 *   - Click outside (on overlay) closes the modal
 *   - Prevents body scroll when open
 *   - Optional form state persistence
 */
export default class extends Controller {
  static targets = ["overlay", "dialog"]
  static values = {
    open: { type: Boolean, default: false },
    persistForm: { type: Boolean, default: false }
  }

  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)

    // Restore form state if enabled
    if (this.persistFormValue) {
      this.restoreFormState()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
    this.enableBodyScroll()
  }

  open() {
    this.openValue = true
  }

  close() {
    // Save form state before closing if enabled
    if (this.persistFormValue) {
      this.saveFormState()
    }
    this.openValue = false
  }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.toggle("hidden", !this.openValue)
    }

    if (this.hasDialogTarget) {
      this.dialogTarget.classList.toggle("hidden", !this.openValue)
    }

    if (this.openValue) {
      this.disableBodyScroll()
    } else {
      this.enableBodyScroll()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape" && this.openValue) {
      this.close()
    }
  }

  disableBodyScroll() {
    document.body.style.overflow = "hidden"
  }

  enableBodyScroll() {
    document.body.style.overflow = ""
  }

  // Form state persistence helpers
  saveFormState() {
    const form = this.element.querySelector("form")
    if (!form) return

    const formData = new FormData(form)
    const state = {}
    formData.forEach((value, key) => {
      state[key] = value
    })

    try {
      sessionStorage.setItem(this.formStateKey, JSON.stringify(state))
    } catch (e) {
      console.warn("Failed to save form state:", e)
    }
  }

  restoreFormState() {
    const form = this.element.querySelector("form")
    if (!form) return

    try {
      const savedState = sessionStorage.getItem(this.formStateKey)
      if (!savedState) return

      const state = JSON.parse(savedState)
      Object.entries(state).forEach(([key, value]) => {
        const field = form.elements[key]
        if (field) {
          field.value = value
        }
      })
    } catch (e) {
      console.warn("Failed to restore form state:", e)
    }
  }

  clearFormState() {
    sessionStorage.removeItem(this.formStateKey)
  }

  get formStateKey() {
    return `modal-form-state-${this.element.id || "default"}`
  }
}
