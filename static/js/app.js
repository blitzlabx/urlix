/**
 * Urlix frontend
 * Creator: Blitz (blitzlabx)
 */

(function () {
  "use strict";

  const form = document.getElementById("analyze-form");
  const input = document.getElementById("url-input");
  const btn = document.getElementById("submit-btn");
  const btnLabel = btn.querySelector(".btn-label");
  const spinner = btn.querySelector(".btn-spinner");
  const results = document.getElementById("results");
  const resultContent = document.getElementById("result-content");
  const errorBox = document.getElementById("error-box");
  const copyBtn = document.getElementById("copy-json");

  let lastJson = null;

  function setLoading(on) {
    btn.disabled = on;
    spinner.classList.toggle("hidden", !on);
    btnLabel.textContent = on ? "Analyzing" : "Analyze";
  }

  function showError(msg) {
    errorBox.textContent = msg;
    errorBox.classList.remove("hidden");
    results.classList.add("hidden");
  }

  function hideError() {
    errorBox.classList.add("hidden");
  }

  function statusClass(code) {
    if (code >= 200 && code < 300) return "status-2xx";
    if (code >= 300 && code < 400) return "status-3xx";
    if (code >= 400 && code < 500) return "status-4xx";
    return "status-5xx";
  }

  function esc(s) {
    if (s == null) return "";
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function render(data) {
    const d = data.data || data;
    lastJson = data;

    let html = "";

    // Overview
    html += '<div class="card"><h4>Overview</h4><dl class="kv">';
    html += `<dt>Input URL</dt><dd>${esc(d.input_url)}</dd>`;
    html += `<dt>Final URL</dt><dd>${esc(d.final_url)}</dd>`;
    html += `<dt>Status</dt><dd><span class="status-badge ${statusClass(d.status_code)}">${esc(d.status_code)}</span></dd>`;
    html += `<dt>Content-Type</dt><dd>${esc(d.content_type || "—")}</dd>`;
    html += `<dt>Title</dt><dd>${esc(d.title || "—")}</dd>`;
    html += `<dt>Description</dt><dd>${esc(d.description || "—")}</dd>`;
    html += `<dt>Canonical</dt><dd>${esc(d.canonical_url || "—")}</dd>`;
    html += `<dt>Body size</dt><dd>${esc(d.body_size_bytes != null ? d.body_size_bytes + " bytes" : "—")}</dd>`;
    if (d.timing && d.timing.total_seconds != null) {
      html += `<dt>Total time</dt><dd>${Number(d.timing.total_seconds).toFixed(3)} s</dd>`;
    }
    html += `<dt>Redirect hops</dt><dd>${esc(d.hops != null ? d.hops : "—")}</dd>`;
    html += "</dl></div>";

    // Parsed structure
    if (d.parsed) {
      const p = d.parsed;
      html += '<div class="card"><h4>URL structure</h4><dl class="kv">';
      html += `<dt>Scheme</dt><dd>${esc(p.scheme)}</dd>`;
      html += `<dt>Hostname</dt><dd>${esc(p.hostname)}</dd>`;
      html += `<dt>Port</dt><dd>${esc(p.port)}</dd>`;
      html += `<dt>Path</dt><dd>${esc(p.path)}</dd>`;
      html += `<dt>Query</dt><dd>${esc(p.query || "—")}</dd>`;
      html += `<dt>Fragment</dt><dd>${esc(p.fragment || "—")}</dd>`;
      if (p.username) html += `<dt>Username</dt><dd>${esc(p.username)}</dd>`;
      html += "</dl>";

      if (p.query_params && Object.keys(p.query_params).length) {
        html += '<table class="headers-table" style="margin-top:0.75rem"><thead><tr><th>Param</th><th>Value</th></tr></thead><tbody>';
        for (const [k, v] of Object.entries(p.query_params)) {
          const val = Array.isArray(v) ? v.join(", ") : v;
          html += `<tr><td>${esc(k)}</td><td>${esc(val)}</td></tr>`;
        }
        html += "</tbody></table>";
      }
      html += "</div>";
    }

    // Redirect chain
    if (d.redirect_chain && d.redirect_chain.length) {
      html += '<div class="card"><h4>Redirect chain</h4><ul class="chain">';
      d.redirect_chain.forEach(function (hop) {
        html += "<li>";
        html += `<span class="hop-num">#${esc(hop.hop)}</span>`;
        html += `<span class="status-badge ${statusClass(hop.status)}">${esc(hop.status)}</span>`;
        html += `<span>${esc(hop.url)}</span>`;
        if (hop.timing_seconds != null) {
          html += `<span class="muted">${Number(hop.timing_seconds).toFixed(3)}s</span>`;
        }
        html += "</li>";
      });
      html += "</ul></div>";
    }

    // Security headers
    if (d.security_headers) {
      const sh = d.security_headers;
      const keys = Object.keys(sh).filter(function (k) { return sh[k]; });
      if (keys.length) {
        html += '<div class="card"><h4>Security headers</h4><table class="headers-table"><tbody>';
        keys.forEach(function (k) {
          html += `<tr><th>${esc(k)}</th><td>${esc(sh[k])}</td></tr>`;
        });
        html += "</tbody></table></div>";
      }
    }

    // Response headers
    if (d.headers && Object.keys(d.headers).length) {
      html += '<div class="card"><h4>Response headers</h4><table class="headers-table"><thead><tr><th>Header</th><th>Value</th></tr></thead><tbody>';
      const sorted = Object.keys(d.headers).sort();
      sorted.forEach(function (k) {
        html += `<tr><th>${esc(k)}</th><td>${esc(d.headers[k])}</td></tr>`;
      });
      html += "</tbody></table></div>";
    }

    // Issues
    if (d.issues && d.issues.length) {
      html += '<div class="card"><h4>Issues</h4><ul class="chain">';
      d.issues.forEach(function (iss) {
        html += `<li><strong>${esc(iss.type)}</strong> — ${esc(iss.message)}</li>`;
      });
      html += "</ul></div>";
    }

    resultContent.innerHTML = html;
    results.classList.remove("hidden");
  }

  form.addEventListener("submit", async function (e) {
    e.preventDefault();
    hideError();
    const url = (input.value || "").trim();
    if (!url) {
      showError("Please enter a URL.");
      return;
    }

    setLoading(true);
    try {
      const res = await fetch("/api/v1/analyze?url=" + encodeURIComponent(url), {
        method: "GET",
        headers: { Accept: "application/json" },
      });
      const body = await res.json();

      if (!res.ok || body.success === false) {
        const msg =
          (body.error && body.error.message) ||
          body.message ||
          "Request failed (" + res.status + ")";
        showError(msg);
        lastJson = body;
        return;
      }

      render(body);
    } catch (err) {
      showError("Network error: " + (err.message || "failed to reach API"));
    } finally {
      setLoading(false);
    }
  });

  copyBtn.addEventListener("click", function () {
    if (!lastJson) return;
    const text = JSON.stringify(lastJson, null, 2);
    navigator.clipboard.writeText(text).then(
      function () {
        copyBtn.textContent = "Copied";
        setTimeout(function () {
          copyBtn.textContent = "Copy JSON";
        }, 1500);
      },
      function () {
        copyBtn.textContent = "Copy failed";
        setTimeout(function () {
          copyBtn.textContent = "Copy JSON";
        }, 1500);
      }
    );
  });
})();
