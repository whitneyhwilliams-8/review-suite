// ============================================================================
//  Review Suite — configuration
//  This is the ONLY file you need to edit to point the suite at your own
//  Supabase project and repo. Every page loads it before its own script.
// ============================================================================
window.APP = {
  // 1) Supabase ▸ Project Settings ▸ API
  //    "Project URL" and the "anon / public" key.
  supabaseUrl: 'https://bqolaviomurcbfxsdfgn.supabase.co',
  supabaseKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJxb2xhdmlvbXVyY2JmeHNkZmduIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY2OTk3MjYsImV4cCI6MjEwMjI3NTcyNn0.qyNpJ6_oxvNxmeSiQ2hRtyjr9Zy3lAfI4l2Z8Op4kKg',

  // 2) The live-URL review proxy. After you deploy the edge function
  //    (supabase-function-review.ts) as a function named "review", this is:
  //    https://YOUR-PROJECT.supabase.co/functions/v1/review
  //    Leave as-is if you filled in supabaseUrl above and named the function "review".
  proxyUrl: 'https://bqolaviomurcbfxsdfgn.supabase.co/functions/v1/review',

  // 3) Public URL of review-overlay.js once this repo is on GitHub Pages, e.g.
  //    https://YOUR-GH-USER.github.io/YOUR-REPO/review-overlay.js
  overlayUrl: 'https://whitneyhwilliams-8.github.io/review-suite/review-overlay.js',

  // 4) Cosmetic — the name shown in the top-left of every page.
  brand: {
    name: 'Whack Review'
  }
};

// Fill any element with class="brandmark" with the brand name (replaces the old logo image).
document.addEventListener('DOMContentLoaded', function () {
  var n = (window.APP && window.APP.brand && window.APP.brand.name) || 'Review Studio';
  Array.prototype.forEach.call(document.querySelectorAll('.brandmark'), function (el) { el.textContent = n; });
});
