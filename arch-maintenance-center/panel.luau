--!nonstrict

local Diagnosis = require("./lib/diagnosis.luau")
local Settings = require("./lib/settings.luau")

local snapshot = noctalia.state.get("snapshot")
local open = false
local tr = noctalia.tr

local function rounded(value)
  return tostring(math.floor((tonumber(value) or 0) + 0.5))
end

local function healthPresentation()
  if snapshot == nil or snapshot.health == nil then
    return "shield-exclamation", "surface_variant", "on_surface_variant", tr("status.loading"), tr("global.waiting")
  end

  local health = snapshot.health
  if snapshot.refreshing == true and type(snapshot.collectedAtMs) ~= "number" then
    return "shield-search", "surface_variant", "on_surface_variant", tr("global.checking"), tr("global.checking_detail")
  end
  if health.severity == "critical" then
    local key = health.issueCount == 1 and "global.issue_one" or "global.issues"
    return "shield-x", "error_container", "on_error_container", tr("global.critical"), tr(key, { count = health.issueCount })
  elseif health.severity == "warning" then
    local key = health.issueCount == 1 and "global.issue_one" or "global.issues"
    return "shield-exclamation", "tertiary_container", "on_tertiary_container", tr("global.attention"), tr(key, { count = health.issueCount })
  elseif health.complete ~= true then
    local names = {}
    for _, name in ipairs(type(health.unavailableModules) == "table" and health.unavailableModules or {}) do
      table.insert(names, tr("module." .. name))
    end
    local detail = #names > 0
      and tr("global.unavailable_modules", { modules = table.concat(names, ", ") })
      or tr(
        health.unavailableCount == 1 and "global.unavailable_one" or "global.unavailable",
        { count = health.unavailableCount }
      )
    return "shield-exclamation", "surface_variant", "on_surface_variant", tr("global.incomplete"), detail
  end
  return "shield-check", "primary_container", "on_primary_container", tr("global.healthy"), tr("global.no_issues")
end

local function banner()
  local glyph, fill, color, title, detail = healthPresentation()
  return ui.row({
    gap = 14,
    align = "center",
    paddingH = 18,
    paddingV = 14,
    fill = fill,
    radius = 12,
  }, {
    ui.glyph({ name = glyph, size = 30, color = color }),
    ui.column({ gap = 3, flexGrow = 1 }, {
      ui.label({ text = title, fontSize = 17, fontWeight = "bold", color = color }),
      ui.label({ text = detail, fontSize = 12, color = color }),
    }),
  })
end

local function card(title, glyph, color, children)
  local body = {
    ui.row({ gap = 10, align = "center" }, {
      ui.glyph({ name = glyph, size = 22, color = color }),
      ui.label({ text = title, fontSize = 15, fontWeight = "bold", flexGrow = 1 }),
    }),
  }
  for _, child in ipairs(children) do
    table.insert(body, child)
  end
  return ui.column({
    gap = 9,
    padding = 14,
    fill = "surface_variant/0.28",
    border = "outline/0.45",
    borderWidth = 1,
    radius = 10,
    minHeight = 126,
    flexGrow = 1,
  }, body)
end

local function unavailableCard(title, glyph, message)
  return card(title, glyph, "on_surface_variant", {
    ui.label({ text = message, color = "on_surface_variant", maxLines = 3 }),
  })
end

local function updatesCard()
  local module = snapshot and snapshot.modules and snapshot.modules.updates or nil
  if module == nil then
    return unavailableCard(tr("module.updates"), "package", tr("status.loading"))
  elseif module.state == "unavailable" then
    return unavailableCard(tr("module.updates"), "package", tr("updates.missing_checkupdates"))
  elseif module.state ~= "ready" then
    local message = module.detail == "collection_deadline" and tr("updates.deadline")
      or (module.detail == "command_timed_out" and tr("updates.timeout") or tr("updates.error"))
    return unavailableCard(tr("module.updates"), "package", message)
  end

  local data = module.data or {}
  local count = tonumber(data.count) or 0
  local color = module.severity == "warning" and "tertiary" or "primary"
  local detail = type(data.daysSinceLastUpgrade) == "number"
    and tr("updates.last_upgrade", { days = data.daysSinceLastUpgrade })
    or tr("updates.last_upgrade_unknown")
  return card(tr("module.updates"), "package", color, {
    ui.label({
      text = count == 0 and tr("updates.current")
        or (count == 1 and tr("updates.pending_one") or tr("updates.pending", { count = count })),
      fontSize = 21,
      fontWeight = "bold",
      color = color,
    }),
    ui.label({ text = detail, fontSize = 11, color = "on_surface_variant", maxLines = 2 }),
  })
end

local function servicesCard()
  local module = snapshot and snapshot.modules and snapshot.modules.services or nil
  if module == nil then
    return unavailableCard(tr("module.services"), "server", tr("status.loading"))
  elseif module.state ~= "ready" then
    return unavailableCard(tr("module.services"), "server", tr("services.error"))
  end

  local data = module.data or {}
  local count = tonumber(data.count) or 0
  local partial = module.complete == false
  local color = count > 0 and "tertiary" or (partial and "on_surface_variant" or "primary")
  local children = {
    ui.label({
      text = count == 0 and (partial and tr("services.system_healthy") or tr("services.healthy"))
        or (count == 1 and tr("services.failed_one") or tr("services.failed", { count = count })),
      fontSize = 18,
      fontWeight = "bold",
      color = color,
    }),
    ui.label({
      text = partial and tr("services.user_scope_unavailable") or tr("services.scopes_checked"),
      fontSize = 10,
      color = "on_surface_variant",
      maxLines = 2,
    }),
  }
  for index, unit in ipairs(type(data.units) == "table" and data.units or {}) do
    if index > 3 then
      break
    end
    table.insert(children, ui.label({
      text = (unit.scope == "user" and tr("services.user_prefix") or tr("services.system_prefix")) .. unit.name,
      fontSize = 10,
      color = "on_surface_variant",
      maxLines = 1,
    }))
  end
  return card(tr("module.services"), "server", color, children)
end

local function diskCard()
  local module = snapshot and snapshot.modules and snapshot.modules.disk or nil
  if module == nil then
    return unavailableCard(tr("module.disk"), "database", tr("status.loading"))
  elseif module.state ~= "ready" then
    return unavailableCard(tr("module.disk"), "database", tr("disk.error"))
  end

  local percent = tonumber(module.data and module.data.usagePercent) or 0
  local color = module.severity == "critical" and "error"
    or (module.severity == "warning" and "tertiary" or "primary")
  local source = module.data and module.data.source == "noctalia" and tr("disk.source_noctalia") or tr("disk.source_df")
  return card(tr("module.disk"), "database", color, {
    ui.label({ text = tr("disk.used", { percent = rounded(percent) }), fontSize = 21, fontWeight = "bold", color = color }),
    ui.label({ text = tr("disk.root_filesystem"), fontSize = 11, color = "on_surface_variant" }),
    ui.label({ text = source, fontSize = 10, color = "on_surface_variant" }),
  })
end

local function lastUpdated()
  if snapshot == nil or type(snapshot.collectedAtMs) ~= "number" then
    return tr("status.never_updated")
  end
  return tr("status.last_updated", {
    time = noctalia.formatTime(noctalia.timeFormat(), math.floor(snapshot.collectedAtMs / 1000)),
    interval = Settings.refreshIntervalMinutes(noctalia.getConfig("refresh_interval_minutes")),
  })
end

function render()
  local refreshing = snapshot ~= nil and snapshot.refreshing == true
  local header = ui.row({ align = "center", gap = 12, paddingH = 18, paddingV = 11 }, {
    ui.glyph({ name = "shield-check", size = 25, color = "on_surface" }),
    ui.label({ text = tr("panel.title"), fontSize = 19, fontWeight = "bold", flexGrow = 1 }),
    ui.button({
      glyph = "refresh",
      variant = "ghost",
      controlSize = "sm",
      enabled = not refreshing,
      tooltip = refreshing and tr("status.refreshing") or tr("action.refresh"),
      onClick = "onRefreshClicked",
    }),
  })

  local statusLine = refreshing
    and (type(snapshot.collectedAtMs) == "number" and tr("status.refreshing") or tr("status.initial_check"))
    or lastUpdated()
  local body = ui.column({ gap = 12, paddingH = 18, paddingV = 14, flexGrow = 1 }, {
    banner(),
    ui.label({ text = statusLine, fontSize = 10, color = "on_surface_variant", textAlign = "end" }),
    ui.row({ gap = 12, align = "stretch" }, { updatesCard(), servicesCard() }),
    diskCard(),
  })

  local actions = ui.row({ gap = 8, justify = "end", paddingH = 18, paddingV = 8 }, {
    ui.button({
      text = tr("action.copy_diagnosis"),
      glyph = "clipboard",
      fontSize = 12,
      controlSize = "sm",
      contentAlign = "center",
      variant = "outline",
      flexGrow = 1,
      onClick = "onCopyDiagnosis",
    }),
    ui.button({
      text = tr("action.copy_commands"),
      glyph = "terminal-2",
      fontSize = 12,
      controlSize = "sm",
      contentAlign = "center",
      variant = "outline",
      flexGrow = 1,
      onClick = "onCopyCommands",
    }),
  })

  panel.render(ui.column({ gap = 0, fill = "surface", flexGrow = 1, align = "stretch" }, {
    header,
    ui.separator({ thickness = 1, color = "outline/0.35" }),
    body,
    ui.separator({ thickness = 1, color = "outline/0.35" }),
    actions,
  }))
end

function onOpen(_context)
  open = true
  render()
end

function onClose()
  open = false
end

function onRefreshClicked()
  noctalia.state.set("refresh_request", noctalia.nowMs())
end

function onCopyDiagnosis()
  if noctalia.copyToClipboard(Diagnosis.format(snapshot), "text/plain") then
    noctalia.notify(tr("panel.title"), tr("action.diagnosis_copied"))
  else
    noctalia.notifyError(tr("panel.title"), tr("action.copy_failed"))
  end
end

function onCopyCommands()
  if noctalia.copyToClipboard(Diagnosis.commands(snapshot), "text/plain") then
    noctalia.notify(tr("panel.title"), tr("action.commands_copied"))
  else
    noctalia.notifyError(tr("panel.title"), tr("action.copy_failed"))
  end
end

noctalia.state.watch("snapshot", function(value)
  snapshot = value
  if open then
    render()
  end
end)
