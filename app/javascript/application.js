// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Mobile menu toggle
document.addEventListener('turbo:load', () => {
  const menuToggle = document.getElementById('mobileMenuToggle')
  const headerNav = document.getElementById('headerNav')

  if (menuToggle && headerNav) {
    menuToggle.addEventListener('click', () => {
      menuToggle.classList.toggle('active')
      headerNav.classList.toggle('active')
    })

    // Close menu when clicking outside
    document.addEventListener('click', (e) => {
      if (!menuToggle.contains(e.target) && !headerNav.contains(e.target)) {
        menuToggle.classList.remove('active')
        headerNav.classList.remove('active')
      }
    })

    // Close menu on nav link click
    const navLinks = headerNav.querySelectorAll('.nav-link')
    navLinks.forEach(link => {
      link.addEventListener('click', () => {
        menuToggle.classList.remove('active')
        headerNav.classList.remove('active')
      })
    })
  }

  // Form validation enhancements
  const forms = document.querySelectorAll('form[data-validate]')
  forms.forEach(form => {
    form.addEventListener('submit', (e) => {
      const requiredFields = form.querySelectorAll('[required]')
      let isValid = true

      requiredFields.forEach(field => {
        if (!field.value.trim()) {
          isValid = false
          field.classList.add('field-error')

          // Add error message if not exists
          if (!field.nextElementSibling?.classList.contains('error-message')) {
            const errorMsg = document.createElement('span')
            errorMsg.className = 'error-message'
            errorMsg.textContent = 'This field is required'
            field.parentNode.insertBefore(errorMsg, field.nextSibling)
          }
        } else {
          field.classList.remove('field-error')
          field.nextElementSibling?.classList.contains('error-message') &&
            field.nextElementSibling.remove()
        }
      })

      if (!isValid) {
        e.preventDefault()
      }
    })

    // Clear errors on input
    const inputs = form.querySelectorAll('input, textarea, select')
    inputs.forEach(input => {
      input.addEventListener('input', () => {
        input.classList.remove('field-error')
        input.nextElementSibling?.classList.contains('error-message') &&
          input.nextElementSibling.remove()
      })
    })
  })

  // Button loading states
  const loadingButtons = document.querySelectorAll('[data-loading]')
  loadingButtons.forEach(button => {
    button.addEventListener('click', () => {
      if (!button.disabled) {
        button.classList.add('loading')
        button.disabled = true
      }
    })
  })

  // Enhanced Searchable Select Functionality
  function initializeSearchableSelects() {
    const searchableSelects = document.querySelectorAll('.searchable-select')
    
    searchableSelects.forEach(select => {
      // Store original options
      const originalOptions = Array.from(select.options).map(option => ({
        value: option.value,
        text: option.text,
        selected: option.selected
      }))

      // Add visual feedback on focus
      select.addEventListener('focus', () => {
        select.classList.add('filtering')
      })

      select.addEventListener('blur', () => {
        select.classList.remove('filtering')
      })

      // Remove problematic input event - select elements don't support text input
      // The searchable functionality will be handled by the browser's native behavior
      
      // Reset search on selection
      select.addEventListener('change', () => {
        if (select.value) {
          select.classList.remove('filtering')
        }
      })
    })
  }

  // Initialize all functionality
  initializeSearchableSelects()

  // Auto-dismiss flash messages after 4 seconds
  const flashContainer = document.querySelector('.flash-container');
  if (flashContainer) {
    setTimeout(() => {
      flashContainer.style.transition = 'opacity 0.5s';
      flashContainer.style.opacity = '0';
      setTimeout(() => flashContainer.remove(), 500);
    }, 4000);
  }
})
