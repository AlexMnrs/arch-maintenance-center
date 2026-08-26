--!nonstrict

local Bytes = require("./lib/bytes.luau")
local Diagnosis = require("./lib/diagnosis.luau")
local Settings = require("./lib/settings.luau")
local Updates = require("./lib/updates.luau")

local snapshot = noctalia.state.get("snapshot")
local open = false
local view = "overview"
local tr = noctalia.tr

local function rounded(value)
  return tostring(math.floor((tonumber(value) or 0) + 0.5))
end

local function moduleValue(name)
  return snapshot ~= nil and snapshot.modules ~= nil and snapshot.modules[name] or nil
end

local function formatDateTime(value)
  if type(value) ~= "number" then
    return tr("status.time_unavailable")
  end
  local seconds = math.floor(value / 1000)
  return noctalia.formatTime(noctalia.dateFormat(), seconds)
    .. " · "
    .. noctalia.formatTime(noctalia.timeFormat(), seconds)
end

local function healthPresentation()
  if snapshot == nil or snapshot.health == nil then
    return "shield-exclamation", "surface_variant", "on_surface_variant", tr("status.loading"), tr("global.waiting")
  end

  local health = snapshot.health
  if snapshot.refreshing == true and type(snapshot.collectedAtMs) ~= "number" then
    return "shield-search", "surface_variant", "on_surface_variant", tr("global.checking"), tr("global.checking_detail")
  end

  local detail = nil
  local glyph = "shield-check"
  local fill = "primary_container"
  local color = "on_primary_container"
  local title = tr("global.healthy")
  if health.severity == "critical" then
    local key = health.issueCount == 1 and "global.issue_one" or "global.issues"
    glyph, fill, color, title = "shield-x", "error_container", "on_error_container", tr("global.critical")
    detail = tr(key, { count = health.issueCount })
  elseif health.severity == "warning" then
    local key = health.issueCount == 1 and "global.issue_one" or "global.issues"
    glyph, fill, color, title = "shield-exclamation", "tertiary_container", "on_tertiary_container", tr("global.attention")
    detail = tr(key, { count = health.issueCount })
  elseif health.complete ~= true then
    glyph, fill, color, title = "shield-exclamation", "surface_variant", "on_surface_variant", tr("global.incomplete")
  elseif (tonumber(health.maintenanceCount) or 0) > 0 then
    local key = health.maintenanceCount == 1 and "global.maintenance_one" or "global.maintenance"
    glyph, fill, color, title = "tool", "surface_variant", "on_surface_variant", tr("global.maintenance_available")
    detail = tr(key, { count = health.maintenanceCount })
  else
    detail = tr("global.no_issues")
  end

  if health.complete ~= true then
    local names = {}
    for _, name in ipairs(type(health.unavailableModules) == "table" and health.unavailableModules or {}) do
      table.insert(names, tr("module." .. name))
    end
    local incompleteDetail = #names > 0
      and tr("global.unavailable_modules", { modules = table.concat(names, ", ") })
      or tr(
        health.unavailableCount == 1 and "global.unavailable_one" or "global.unavailable",
        { count = health.unavailableCount }
      )
    detail = detail ~= nil and detail .. " " .. incompleteDetail or incompleteDetail
  end
  return glyph, fill, color, title, detail or tr("global.no_issues")
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
      ui.label({ text = detail, fontSize = 12, color = color, maxLines = 2 }),
    }),
  })
end

local function card(id, title, glyph, color, children)
  local body = {
    ui.row({ gap = 10, align = "center" }, {
      ui.glyph({ name = glyph, size = 22, color = color }),
      ui.label({ text = title, fontSize = 15, fontWeight = "bold", flexGrow = 1 }),
      ui.glyph({ name = "chevron-right", size = 18, color = "on_surface_variant" }),
    }),
  }
  for _, child in ipairs(children) do
    table.insert(body, child)
  end
  return ui.column({
    key = "card-" .. id,
    gap = 9,
    padding = 14,
    fill = "surface_variant/0.28",
    border = "outline/0.45",
    borderWidth = 1,
    radius = 10,
    minHeight = 126,
    flexGrow = 1,
    onClick = function()
      view = id
      render()
    end,
  }, body)
end

local function unavailableCard(id, title, glyph, message)
  return card(id, title, glyph, "on_surface_variant", {
    ui.label({ text = message, color = "on_surface_variant", maxLines = 3 }),
  })
end

local function updatesCard()
  local module = moduleValue("updates")
  if module == nil then
    return unavailableCard("updates", tr("module.updates"), "package", tr("status.loading"))
  elseif module.state == "unavailable" then
    return unavailableCard("updates", tr("module.updates"), "package", tr("updates.missing_checkupdates"))
  elseif module.state ~= "ready" then
    local message = module.detail == "collection_deadline" and tr("updates.deadline")
      or (module.detail == "command_timed_out" and tr("updates.timeout") or tr("updates.error"))
    return unavailableCard("updates", tr("module.updates"), "package", message)
  end

  local data = module.data or {}
  local count = tonumber(data.count) or 0
  local color = module.severity == "warning" and "tertiary" or "primary"
  local detail = type(data.lastUpgradeMs) == "number"
    and tr("updates.last_upgrade_at", { time = formatDateTime(data.lastUpgradeMs) })
    or tr("updates.last_upgrade_unknown")
  return card("updates", tr("module.updates"), "package", color, {
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
  local module = moduleValue("services")
  if module == nil then
    return unavailableCard("services", tr("module.services"), "server", tr("status.loading"))
  elseif module.state ~= "ready" then
    return unavailableCard("services", tr("module.services"), "server", tr("services.error"))
  end

  local data = module.data or {}
  local count = tonumber(data.count) or 0
  local partial = module.complete == false
  local color = count > 0 and "tertiary" or (partial and "on_surface_variant" or "primary")
  return card("services", tr("module.services"), "server", color, {
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
  })
end

local function diskCard()
  local module = moduleValue("disk")
  if module == nil then
    return unavailableCard("disk", tr("module.disk"), "database", tr("status.loading"))
  elseif module.state ~= "ready" then
    return unavailableCard("disk", tr("module.disk"), "database", tr("disk.error"))
  end

  local percent = tonumber(module.data and module.data.usagePercent) or 0
  local color = module.severity == "critical" and "error"
    or (module.severity == "warning" and "tertiary" or "primary")
  local cleanup = moduleValue("cleanup")
  local orphanText = nil
  if cleanup ~= nil and cleanup.state == "ready" then
    local orphans = cleanup.data and cleanup.data.orphans
    local orphanCount = orphans and orphans.state == "ready" and tonumber(orphans.data and orphans.data.count) or 0
    if orphanCount > 0 then
      orphanText = orphanCount == 1 and tr("cleanup.orphans_one") or tr("cleanup.orphans", { count = orphanCount })
    end
  end
  local children = {
    ui.label({ text = tr("disk.used", { percent = rounded(percent) }), fontSize = 21, fontWeight = "bold", color = color }),
    ui.label({ text = tr("disk.root_filesystem"), fontSize = 11, color = "on_surface_variant" }),
  }
  if orphanText ~= nil then
    table.insert(children, ui.label({ text = orphanText, fontSize = 10, color = "on_surface_variant" }))
  elseif cleanup ~= nil and (cleanup.state ~= "ready" or cleanup.complete == false) then
    table.insert(children, ui.label({ text = tr("cleanup.error"), fontSize = 10, color = "on_surface_variant", maxLines = 2 }))
  end
  return card("disk", tr("module.disk"), "database", color, children)
end

local function logsCard()
  local module = moduleValue("logs")
  if module == nil then
    return unavailableCard("logs", tr("module.logs"), "file-alert", tr("status.loading"))
  elseif module.state ~= "ready" then
    return unavailableCard("logs", tr("module.logs"), "file-alert", tr("logs.error"))
  end

  local data = module.data or {}
  local count = tonumber(data.count) or 0
  local color = count > 0 and "secondary" or (module.complete == false and "on_surface_variant" or "primary")
  local title = count == 0 and tr("logs.clear")
    or (data.truncated == true and tr("logs.events_truncated") or (count == 1 and tr("logs.event_one") or tr("logs.events", { count = count })))
  return card("logs", tr("module.logs"), "file-alert", color, {
    ui.label({ text = title, fontSize = 18, fontWeight = "bold", color = color }),
    ui.label({
      text = module.complete == false and tr("logs.scope_partial") or tr("logs.since_boot"),
      fontSize = 10,
      color = "on_surface_variant",
      maxLines = 2,
    }),
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

local function detailTitle()
  return tr("module." .. view)
end

local function detailState(module, unavailableMessage, errorMessage)
  if module == nil then
    return ui.label({ text = tr("status.loading"), color = "on_surface_variant" })
  elseif module.state == "unavailable" then
    return ui.label({ text = unavailableMessage, color = "on_surface_variant", maxLines = 4 })
  elseif module.state ~= "ready" then
    return ui.label({ text = errorMessage, color = "on_surface_variant", maxLines = 4 })
  end
  return nil
end

local function updateDetail()
  local module = moduleValue("updates")
  local state = detailState(module, tr("updates.missing_checkupdates"), tr("updates.error"))
  if state ~= nil then
    return { state }
  end

  local data = module.data or {}
  local count = tonumber(data.count) or 0
  local children = {
    ui.label({
      text = count == 0 and tr("updates.current")
        or (count == 1 and tr("updates.pending_one") or tr("updates.pending", { count = count })),
      fontSize = 22,
      fontWeight = "bold",
      color = module.severity == "warning" and "tertiary" or "primary",
    }),
    ui.label({ text = tr("updates.checked_at", { time = formatDateTime(module.checkedAtMs) }), color = "on_surface_variant", fontSize = 11 }),
    ui.label({
      text = type(data.lastUpgradeMs) == "number"
        and tr("updates.last_upgrade_at", { time = formatDateTime(data.lastUpgradeMs) })
        or tr("updates.last_upgrade_unknown"),
      color = "on_surface_variant",
      fontSize = 11,
    }),
  }
  if count > 0 then
    table.insert(children, ui.separator({ thickness = 1, color = "outline/0.35", spacing = 4 }))
    table.insert(children, ui.label({ text = tr("updates.available_packages"), fontSize = 14, fontWeight = "bold" }))
    for _, package in ipairs(type(data.packages) == "table" and data.packages or {}) do
      table.insert(children, ui.row({ key = "package-" .. package.name, gap = 8, align = "center" }, {
        ui.label({ text = package.name, fontWeight = "bold", flexGrow = 1, maxLines = 1 }),
        ui.label({
          text = tostring(package.installedVersion) .. " → " .. tostring(package.availableVersion),
          color = "on_surface_variant",
          fontSize = 11,
          maxLines = 1,
        }),
      }))
    end
    if data.packagesTruncated == true then
      local remaining = math.max(0, count - #(data.packages or {}))
      table.insert(children, ui.label({ text = tr("updates.more_packages", { count = remaining }), color = "on_surface_variant", fontSize = 11 }))
    end
    table.insert(children, ui.separator({ thickness = 1, color = "outline/0.35", spacing = 4 }))
    table.insert(children, ui.label({ text = tr("updates.upgrade_command"), fontSize = 13, fontWeight = "bold" }))
    table.insert(children, ui.label({ text = Updates.upgradeCommand(), fontFamily = "monospace", color = "on_surface_variant" }))
    table.insert(children, ui.label({ text = tr("updates.upgrade_warning"), color = "tertiary", fontSize = 11, maxLines = 3 }))
  end
  return children
end

local function servicesDetail()
  local module = moduleValue("services")
  local state = detailState(module, tr("services.error"), tr("services.error"))
  if state ~= nil then
    return { state }
  end

  local data = module.data or {}
  local count = tonumber(data.count) or 0
  local children = {
    ui.label({
      text = count == 0 and tr("services.healthy")
        or (count == 1 and tr("services.failed_one") or tr("services.failed", { count = count })),
      fontSize = 22,
      fontWeight = "bold",
      color = count > 0 and "tertiary" or "primary",
    }),
    ui.label({
      text = module.complete == false and tr("services.user_scope_unavailable") or tr("services.scopes_checked"),
      color = "on_surface_variant",
      fontSize = 11,
    }),
  }
  if count > 0 then
    table.insert(children, ui.separator({ thickness = 1, color = "outline/0.35", spacing = 4 }))
    for _, unit in ipairs(type(data.units) == "table" and data.units or {}) do
      table.insert(children, ui.column({ key = "unit-" .. unit.scope .. "-" .. unit.name, gap = 2, paddingV = 4 }, {
        ui.label({
          text = (unit.scope == "user" and tr("services.user_prefix") or tr("services.system_prefix")) .. unit.name,
          fontWeight = "bold",
          maxLines = 1,
        }),
        ui.label({ text = unit.description or "", color = "on_surface_variant", fontSize = 11, maxLines = 2 }),
      }))
    end
    if data.unitsTruncated == true then
      local remaining = math.max(0, count - #(data.units or {}))
      table.insert(children, ui.label({ text = tr("services.more_units", { count = remaining }), color = "on_surface_variant", fontSize = 11 }))
    end
  end
  return children
end

local function cleanupSignal(children, title, item, formatter)
  if item ~= nil and item.state == "ready" then
    table.insert(children, ui.row({ gap = 8, align = "center" }, {
      ui.label({ text = title, flexGrow = 1 }),
      ui.label({ text = formatter(item.data or {}), color = "on_surface_variant", fontSize = 11, maxLines = 1 }),
    }))
  else
    table.insert(children, ui.row({ gap = 8, align = "center" }, {
      ui.label({ text = title, flexGrow = 1 }),
      ui.label({ text = tr("status.unavailable"), color = "on_surface_variant", fontSize = 11 }),
    }))
  end
end

local function diskDetail()
  local module = moduleValue("disk")
  local state = detailState(module, tr("disk.error"), tr("disk.error"))
  if state ~= nil then
    return { state }
  end

  local data = module.data or {}
  local total = tonumber(data.totalBytes) or 0
  local available = tonumber(data.availableBytes) or 0
  local used = math.max(0, total - available)
  local children = {
    ui.label({ text = tr("disk.root_filesystem"), fontSize = 14, fontWeight = "bold" }),
    ui.label({
      text = tr("disk.used_of_total", { used = Bytes.format(used), total = Bytes.format(total) }),
      fontSize = 22,
      fontWeight = "bold",
      color = module.severity == "critical" and "error" or (module.severity == "warning" and "tertiary" or "primary"),
    }),
    ui.label({ text = tr("disk.available", { available = Bytes.format(available) }), color = "on_surface_variant", fontSize = 11 }),
  }
  local cleanup = moduleValue("cleanup")
  if cleanup ~= nil then
    table.insert(children, ui.separator({ thickness = 1, color = "outline/0.35", spacing = 4 }))
    table.insert(children, ui.label({ text = tr("cleanup.title"), fontSize = 14, fontWeight = "bold" }))
    local cleanupData = cleanup.data or {}
    if cleanup.state == "ready" then
      cleanupSignal(children, tr("cleanup.cache"), cleanupData.cache, function(value)
        return Bytes.format(tonumber(value.bytes) or -1)
      end)
      cleanupSignal(children, tr("cleanup.orphans_label"), cleanupData.orphans, function(value)
        local count = tonumber(value.count) or 0
        return count == 1 and tr("cleanup.orphans_one") or tr("cleanup.orphans", { count = count })
      end)
      cleanupSignal(children, tr("cleanup.journal"), cleanupData.journal, function(value)
        return Bytes.format(tonumber(value.bytes) or -1)
      end)
      local orphans = cleanupData.orphans
      if orphans ~= nil and orphans.state == "ready" and tonumber(orphans.data and orphans.data.count) > 0 then
        table.insert(children, ui.label({ text = tr("cleanup.orphan_packages"), fontSize = 12, fontWeight = "bold" }))
        for _, name in ipairs(type(orphans.data.packages) == "table" and orphans.data.packages or {}) do
          table.insert(children, ui.label({ text = name, fontFamily = "monospace", color = "on_surface_variant", fontSize = 11, maxLines = 1 }))
        end
        if orphans.data.truncated == true then
          local remaining = math.max(0, (tonumber(orphans.data.count) or 0) - #(orphans.data.packages or {}))
          table.insert(children, ui.label({ text = tr("cleanup.more_orphans", { count = remaining }), color = "on_surface_variant", fontSize = 11 }))
        end
      end
    else
      table.insert(children, ui.label({ text = tr("cleanup.error"), color = "on_surface_variant" }))
      cleanupSignal(children, tr("cleanup.cache"), cleanupData.cache, function(value)
        return Bytes.format(tonumber(value.bytes) or -1)
      end)
      cleanupSignal(children, tr("cleanup.orphans_label"), cleanupData.orphans, function(value)
        local count = tonumber(value.count) or 0
        return count == 1 and tr("cleanup.orphans_one") or tr("cleanup.orphans", { count = count })
      end)
      cleanupSignal(children, tr("cleanup.journal"), cleanupData.journal, function(value)
        return Bytes.format(tonumber(value.bytes) or -1)
      end)
    end
  end
  return children
end

local function logsDetail()
  local module = moduleValue("logs")
  local state = detailState(module, tr("logs.error"), tr("logs.error"))
  if state ~= nil then
    return { state }
  end

  local data = module.data or {}
  local count = tonumber(data.count) or 0
  local children = {
    ui.label({
      text = count == 0 and tr("logs.clear")
        or (data.truncated == true and tr("logs.events_truncated") or (count == 1 and tr("logs.event_one") or tr("logs.events", { count = count }))),
      fontSize = 22,
      fontWeight = "bold",
      color = count > 0 and "secondary" or "primary",
    }),
    ui.label({
      text = module.complete == false and tr("logs.scope_partial") or tr("logs.since_boot"),
      color = "on_surface_variant",
      fontSize = 11,
    }),
  }
  if count > 0 then
    table.insert(children, ui.separator({ thickness = 1, color = "outline/0.35", spacing = 4 }))
    for index, event in ipairs(type(data.events) == "table" and data.events or {}) do
      local time = type(event.timestampMs) == "number"
        and noctalia.formatTime(noctalia.timeFormat(), math.floor(event.timestampMs / 1000))
        or tr("status.time_unavailable")
      table.insert(children, ui.column({ key = "log-" .. tostring(index), gap = 2, paddingV = 4 }, {
        ui.row({ gap = 8, align = "center" }, {
          ui.label({ text = time, fontFamily = "monospace", fontSize = 11, color = "on_surface_variant" }),
          ui.label({
            text = (event.scope == "user" and tr("logs.user_prefix") or tr("logs.system_prefix")) .. tostring(event.source),
            fontWeight = "bold",
            fontSize = 11,
            maxLines = 1,
          }),
        }),
        ui.label({ text = tostring(event.message), color = "on_surface_variant", fontSize = 11, maxLines = 3 }),
      }))
    end
  end
  return children
end

local function overviewBody()
  local refreshing = snapshot ~= nil and snapshot.refreshing == true
  local statusLine = refreshing
    and (type(snapshot.collectedAtMs) == "number" and tr("status.refreshing") or tr("status.initial_check"))
    or lastUpdated()
  return {
    banner(),
    ui.label({ text = statusLine, fontSize = 10, color = "on_surface_variant", textAlign = "end" }),
    ui.row({ gap = 12, align = "stretch" }, { updatesCard(), servicesCard() }),
    ui.row({ gap = 12, align = "stretch" }, { diskCard(), logsCard() }),
  }
end

local function detailBody()
  if view == "updates" then
    return updateDetail()
  elseif view == "services" then
    return servicesDetail()
  elseif view == "disk" then
    return diskDetail()
  end
  return logsDetail()
end

local function actions()
  if view == "overview" then
    return ui.row({ gap = 8, justify = "end", paddingH = 18, paddingV = 8 }, {
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
  end

  local children = {
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
  }
  local updates = moduleValue("updates")
  if view == "updates" and updates ~= nil and updates.state == "ready"
    and (tonumber(updates.data and updates.data.count) or 0) > 0
  then
    table.insert(children, ui.button({
      text = tr("action.copy_upgrade"),
      glyph = "clipboard",
      fontSize = 12,
      controlSize = "sm",
      contentAlign = "center",
      variant = "outline",
      flexGrow = 1,
      onClick = "onCopyUpgrade",
    }))
  end
  return ui.row({ gap = 8, justify = "end", paddingH = 18, paddingV = 8 }, children)
end

function render()
  local refreshing = snapshot ~= nil and snapshot.refreshing == true
  local title = view == "overview" and tr("panel.title") or detailTitle()
  local headerChildren = {}
  if view == "overview" then
    table.insert(headerChildren, ui.glyph({ name = "shield-check", size = 25, color = "on_surface" }))
  else
    table.insert(headerChildren, ui.button({
      glyph = "arrow-left",
      variant = "ghost",
      controlSize = "sm",
      tooltip = tr("action.back"),
      onClick = "onBackClicked",
    }))
  end
  table.insert(headerChildren, ui.label({ text = title, fontSize = 19, fontWeight = "bold", flexGrow = 1 }))
  table.insert(headerChildren, ui.button({
    glyph = "refresh",
    variant = "ghost",
    controlSize = "sm",
    enabled = not refreshing,
    tooltip = refreshing and tr("status.refreshing") or tr("action.refresh"),
    onClick = "onRefreshClicked",
  }))

  local bodyChildren = view == "overview" and overviewBody() or detailBody()
  local body = ui.scroll({ gap = 12, paddingH = 18, paddingV = 14, flexGrow = 1, align = "stretch" }, bodyChildren)
  panel.render(ui.column({ gap = 0, fill = "surface", flexGrow = 1, align = "stretch" }, {
    ui.row({ align = "center", gap = 12, paddingH = 18, paddingV = 11 }, headerChildren),
    ui.separator({ thickness = 1, color = "outline/0.35" }),
    body,
    ui.separator({ thickness = 1, color = "outline/0.35" }),
    actions(),
  }))
end

function onOpen(_context)
  open = true
  view = "overview"
  render()
end

function onClose()
  open = false
end

function onBackClicked()
  view = "overview"
  render()
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

function onCopyUpgrade()
  if noctalia.copyToClipboard(Updates.upgradeCommand(), "text/plain") then
    noctalia.notify(tr("panel.title"), tr("action.upgrade_copied"))
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
