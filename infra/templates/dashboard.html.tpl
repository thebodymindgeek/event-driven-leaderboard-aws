<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Leaderboard Dashboard</title>
    <style>
      body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; margin: 24px; }
      .row { display: flex; gap: 16px; align-items: center; flex-wrap: wrap; margin-bottom: 12px; }
      .pill { padding: 6px 10px; border: 1px solid #ddd; border-radius: 999px; font-size: 12px; }
      table { width: 100%; border-collapse: collapse; margin-top: 12px; }
      th, td { padding: 10px; border-bottom: 1px solid #eee; text-align: left; }
      th { position: sticky; top: 0; background: #fff; }
      .muted { color: #666; font-size: 12px; }
      .error { color: #b00020; white-space: pre-wrap; background: #fff5f5; border: 1px solid #ffd0d0; padding: 12px; border-radius: 8px; }
      input { padding: 8px 10px; width: min(900px, 100%); border: 1px solid #ddd; border-radius: 8px; }
      button { padding: 8px 10px; border: 1px solid #ddd; border-radius: 8px; background: #fff; cursor: pointer; }
      button:disabled { opacity: 0.6; cursor: not-allowed; }
    </style>
  </head>
  <body>
    <h1>Global Leaderboard</h1>

    <div class="row">
      <label>
        <div class="muted">Leaderboard API URL (Lambda Function URL)</div>
        <input id="apiUrl" placeholder="https://YOUR_FUNCTION_URL/" />
      </label>
      <button id="saveBtn">Save</button>
      <button id="refreshBtn">Refresh now</button>
      <span class="pill" id="statusPill">idle</span>
    </div>

    <div class="row">
      <span class="pill">Auto-refresh: <span id="refreshEvery">5</span>s</span>
      <span class="pill">Last updated: <span id="lastUpdated">—</span></span>
      <span class="pill">Top size: <span id="topSize">—</span></span>
    </div>

    <div id="errorBox" class="error" style="display:none;"></div>

    <table>
      <thead>
        <tr>
          <th style="width:80px;">Rank</th>
          <th style="width:140px;">Employee</th>
          <th style="width:140px;">Points</th>
          <th style="width:160px;">Completed</th>
          <th>Last Activity</th>
        </tr>
      </thead>
      <tbody id="tbody"></tbody>
    </table>

    <script>
      const DEFAULT_REFRESH_SECONDS = 5;

      // Injected by Terraform at deploy-time
      const DEFAULT_FUNCTION_URL = "${get_leaderboard_url}";

      const LS_KEY = "leaderboard_api_url";

      const apiUrlInput = document.getElementById("apiUrl");
      const saveBtn = document.getElementById("saveBtn");
      const refreshBtn = document.getElementById("refreshBtn");
      const statusPill = document.getElementById("statusPill");
      const lastUpdatedEl = document.getElementById("lastUpdated");
      const topSizeEl = document.getElementById("topSize");
      const tbody = document.getElementById("tbody");
      const errorBox = document.getElementById("errorBox");
      document.getElementById("refreshEvery").textContent = DEFAULT_REFRESH_SECONDS;

      function setStatus(text) {
        statusPill.textContent = text;
      }

      function showError(errText) {
        errorBox.style.display = "block";
        errorBox.textContent = errText;
      }

      function clearError() {
        errorBox.style.display = "none";
        errorBox.textContent = "";
      }

      function renderTable(top) {
        tbody.innerHTML = "";
        for (const row of top) {
          const tr = document.createElement("tr");

          const tdRank = document.createElement("td");
          tdRank.textContent = row.rank ?? "";
          tr.appendChild(tdRank);

          const tdEmp = document.createElement("td");
          tdEmp.textContent = row.employee_id ?? "";
          tr.appendChild(tdEmp);

          const tdPoints = document.createElement("td");
          tdPoints.textContent = row.total_points ?? 0;
          tr.appendChild(tdPoints);

          const tdCompleted = document.createElement("td");
          tdCompleted.textContent = row.total_completed ?? 0;
          tr.appendChild(tdCompleted);

          const tdLast = document.createElement("td");
          tdLast.textContent = row.last_updated ?? "";
          tr.appendChild(tdLast);

          tbody.appendChild(tr);
        }
      }

      function effectiveUrl() {
        const fromInput = (apiUrlInput.value || "").trim();
        if (fromInput) return fromInput;

        const saved = (localStorage.getItem(LS_KEY) || "").trim();
        if (saved) return saved;

        return (DEFAULT_FUNCTION_URL || "").trim();
      }

      async function fetchLeaderboard() {
        const url = effectiveUrl();
        if (!url) {
          showError("No API URL available. Provide one, or ensure Terraform injected DEFAULT_FUNCTION_URL.");
          return;
        }

        clearError();
        setStatus("fetching…");
        refreshBtn.disabled = true;

        try {
          const res = await fetch(url, { method: "GET" });
          const text = await res.text();

          if (!res.ok) {
            throw new Error(`HTTP $${res.status}\n\n$${text}`);
          }

          const data = JSON.parse(text);

          // Expected shape: { leaderboard_id, as_of, generated_at, top_size, top: [...] }
          lastUpdatedEl.textContent = data.generated_at || "—";
          topSizeEl.textContent = data.top_size ?? (data.top ? data.top.length : "—");
          renderTable(data.top || []);

          setStatus("ok");
        } catch (err) {
          setStatus("error");
          showError(String(err));
        } finally {
          refreshBtn.disabled = false;
        }
      }

      function loadSavedUrl() {
        const saved = localStorage.getItem(LS_KEY);
        if (saved) apiUrlInput.value = saved;
      }

      saveBtn.addEventListener("click", () => {
        localStorage.setItem(LS_KEY, (apiUrlInput.value || "").trim());
        fetchLeaderboard();
      });

      refreshBtn.addEventListener("click", fetchLeaderboard);

      loadSavedUrl();

      // Helpful UX: if nothing saved, prefill with the injected default
      if (!apiUrlInput.value) apiUrlInput.value = DEFAULT_FUNCTION_URL;

      fetchLeaderboard();
      setInterval(fetchLeaderboard, DEFAULT_REFRESH_SECONDS * 1000);
    </script>
  </body>
</html>
