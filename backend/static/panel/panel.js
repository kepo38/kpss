/**
 * HEDEF Kamu — içerik paneli (sidebar, flash, mobil menü)
 */
(function () {
  'use strict';

  function initSidebar() {
    var toggle = document.querySelector('[data-sidebar-toggle]');
    var layout = document.querySelector('.layout');
    if (!toggle || !layout) return;

    toggle.addEventListener('click', function () {
      layout.classList.toggle('sidebar-open');
      toggle.setAttribute(
        'aria-expanded',
        layout.classList.contains('sidebar-open') ? 'true' : 'false'
      );
    });

    document.addEventListener('click', function (e) {
      if (!layout.classList.contains('sidebar-open')) return;
      var sidebar = document.querySelector('.sidebar');
      if (sidebar && !sidebar.contains(e.target) && !toggle.contains(e.target)) {
        layout.classList.remove('sidebar-open');
        toggle.setAttribute('aria-expanded', 'false');
      }
    });
  }

  function initFlashDismiss() {
    document.querySelectorAll('.flash[data-auto-dismiss]').forEach(function (el) {
      window.setTimeout(function () {
        el.classList.add('is-hiding');
        window.setTimeout(function () {
          el.remove();
        }, 320);
      }, 5200);
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    initSidebar();
    initFlashDismiss();
  });
})();
