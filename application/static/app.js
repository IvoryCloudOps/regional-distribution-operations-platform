// Minimal vanilla JS for the New Order form (add line items) and report export buttons.

document.addEventListener("DOMContentLoaded", function () {
  var addButton = document.getElementById("add-line-item");
  if (addButton) {
    addButton.addEventListener("click", function () {
      var template = document.getElementById("line-item-template");
      var container = document.getElementById("line-items");
      container.appendChild(template.content.cloneNode(true));
    });
  }

  var exportButtons = document.querySelectorAll(".export-btn");
  var resultEl = document.getElementById("export-result");
  exportButtons.forEach(function (btn) {
    btn.addEventListener("click", function () {
      var reportType = btn.getAttribute("data-report");
      resultEl.textContent = "Generating " + reportType + " report...";
      fetch("/reports/export/" + reportType, { method: "POST" })
        .then(function (resp) { return resp.json(); })
        .then(function (data) {
          if (data.download_url) {
            resultEl.innerHTML = 'Report ready: <a href="' + data.download_url + '">Download CSV</a> (link valid 1 hour)';
          } else {
            resultEl.textContent = "Export failed: " + (data.error || "unknown error");
          }
        })
        .catch(function () {
          resultEl.textContent = "Export request failed.";
        });
    });
  });
});
