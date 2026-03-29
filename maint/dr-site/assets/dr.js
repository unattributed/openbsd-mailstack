document.addEventListener("DOMContentLoaded", function () {
  const current = document.body.getAttribute("data-page");
  document.querySelectorAll("nav a[data-page]").forEach(function (link) {
    if (link.getAttribute("data-page") === current) {
      link.setAttribute("aria-current", "page");
      link.style.fontWeight = "700";
    }
  });
});
