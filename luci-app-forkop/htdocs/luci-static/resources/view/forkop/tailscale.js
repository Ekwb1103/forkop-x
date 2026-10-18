"use strict";
"require baseclass";
"require form";
"require fs";
"require poll";
"require ui";

function createTailscaleContent(section) {
  const option = section.option(form.DummyValue, "_native_tailscale");
  option.rawhtml = true;
  option.cfgvalue = () => {
    let busy = false, latest = {}, mounted = false;
    const key = E("input", { type: "text", autocomplete: "off", style: "width:100%;max-width:480px" });
    const state = E("strong", {}, "Проверка состояния…");
    const indicator = E("span", { "aria-hidden": "true", style: "width:10px;height:10px;border-radius:50%;background:#94a3b8;flex:none" });
    const status = E("span", { role: "status", "aria-live": "polite", style: "display:inline-flex;align-items:center;gap:9px;padding:6px 12px;border:1px solid currentColor;border-radius:999px;color:#94a3b8" }, [indicator, state]);
    function setStatus(text, kind) {
      const color = ({ connected: "#22c55e", disconnected: "#94a3b8", connecting: "#f59e0b", reconnecting: "#f59e0b", error: "#ef4444" })[kind] || "#94a3b8";
      state.textContent = text;
      status.style.color = color;
      indicator.style.backgroundColor = color;
    }
    const details = E("p");
    const logs = E("pre", { style: "max-height:240px;overflow:auto;white-space:pre-wrap;overflow-wrap:anywhere;margin-top:12px", "aria-live":"polite" }, "Событий пока нет.");
    const logPanel = E("details", { style:"margin-top:20px" }, [E("summary", { style:"cursor:pointer" }, "Логи соединения"), logs]);
    const connect = E("button", { type: "button", class: "cbi-button cbi-button-apply" }, "Подключить");
    const disconnect = E("button", { type: "button", class: "cbi-button" }, "Отключить");
    const ssh = E("input", { type: "checkbox" });
    const lan = E("input", { type: "checkbox" });
    const lanStatus = E("p");
    const admin = E("a", { href: "https://login.tailscale.com/admin/machines", target: "_blank", rel: "noopener noreferrer", style: "display:none" }, "Открыть панель Tailscale");
    const labels = { disconnected: "Отключено", connecting: "Подключение…", reconnecting: "Восстановление соединения…", connected: "Подключено", error: "Ошибка подключения", unavailable: "Обновите Xrust для нативного Tailscale" };
    function render(data) {
      latest = data;
      const entries = Array.isArray(data.events) ? data.events : [];
      const text = entries.length ? entries.map(entry => "[" + new Date(entry.time * 1000).toLocaleString("ru-RU") + "] " + entry.message).join("\n") : "Событий пока нет.";
      if (logs.textContent !== text) { logs.textContent = text; logs.scrollTop = logs.scrollHeight; }
      setStatus(data.available ? (labels[data.state] || "Состояние неизвестно") : data.version_supported === false ? "Требуется Forkop 2.3.4 или новее" : data.rust_selected === false ? "Доступно только при выбранном Xrust" : labels.unavailable, data.available ? data.state : "unavailable");
      details.textContent = data.message || (data.ip ? "Tailscale IP: " + data.ip : "");
      connect.disabled = busy || !data.available || data.state === "connected" || data.state === "connecting";
      disconnect.disabled = busy || !data.available || data.state === "disconnected";
      key.disabled = busy || !data.available || data.state === "connected";
      ssh.disabled = busy || !data.ssh_available;
      ssh.title = data.ssh_available ? "" : "Требуется Xrust 0.0.17 или новее";
      ssh.checked = Boolean(data.ssh_enabled);
      lan.disabled = busy || !data.available;
      lan.checked = Boolean(data.lan_enabled);
      const routes = (data.lan_routes || []).join(", ");
      lanStatus.textContent = !data.lan_enabled ? "Устройства в локальной сети недоступны." : data.state !== "connected" ? "Локальная сеть: " + routes + ". Ожидаем подключения." : !data.lan_ready ? "Не удалось настроить доступ к локальной сети." : data.routes_approved ? "Доступ к локальной сети включён: " + routes : "Сеть " + routes + " ожидает одобрения. В панели Tailscale откройте этот роутер → Edit route settings и разрешите маршрут.";
      admin.style.display = data.lan_enabled && data.state === "connected" && !data.routes_approved ? "inline-block" : "none";
    }
    async function request(action, args = []) {
      const result = await fs.exec("/usr/bin/forkop", ["tailscale_native_" + action, ...args]);
      if (result.code !== 0) throw new Error("Не удалось выполнить действие Tailscale");
      return JSON.parse(result.stdout);
    }
    async function refresh() {
      if (root.isConnected) mounted = true;
      else if (mounted) { poll.remove(refresh); return; }
      if (busy) return;
      try { render(await request("status")); }
      catch (error) { setStatus("Не удалось получить состояние", "error"); }
    }
    async function act(action, args = []) {
      if (busy) return;
      if (action === "connect" && !key.value.trim() && !latest.saved_identity) {
        ui.addNotification(null, E("p", {}, "Введите ключ Tailscale")); return;
      }
      busy = true; render(latest);
      try {
        if (action === "connect") {
          await fs.write("/var/run/forkop/ui-state/tailscale-auth-input", key.value.trim(), 384);
          key.value = "";
        }
        const data = await request(action, args);
        if (data.state === "error") ui.addNotification(null, E("p", {}, data.message || "Не удалось подключиться"));
        busy = false; render(data);
      } catch (error) {
        if (action === "connect") await fs.remove("/var/run/forkop/ui-state/tailscale-auth-input").catch(() => {});
        ui.addNotification(null, E("p", {}, error.message));
      } finally { busy = false; render(latest); }
    }
    connect.addEventListener("click", () => act("connect"));
    disconnect.addEventListener("click", () => act("disconnect"));
    ssh.addEventListener("change", () => act("ssh", [ssh.checked ? "1" : "0"]));
    lan.addEventListener("change", () => act("lan", [lan.checked ? "1" : "0"]));
    const root = E("div", { class: "cbi-section" }, [
      E("style", {}, "#cbi-forkop-tailscale_native > h3 { display: none; }"),
      E("h3", {}, "Удалённый доступ"),
      E("p", {}, "Введите ключ своей сети Tailscale."),
      E("p", {}, [status]), details,
      E("label", {}, ["Ключ подключения", E("br"), key]),
      E("p", { style: "display:flex;gap:12px;flex-wrap:wrap;margin-top:16px" }, [connect, disconnect]),
      E("hr"), E("p", {}, [E("label", { title: "Разрешает подключаться к SSH роутера через Tailscale по порту 22." }, [ssh, " Разрешить SSH"])]), E("label", {}, [lan, " Разрешить доступ к локальной сети"]), lanStatus, admin,
      logPanel,
    ]);
    poll.add(refresh, 3); refresh();
    return root;
  };
}
return baseclass.extend({ createTailscaleContent });
