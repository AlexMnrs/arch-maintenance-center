--!nonstrict

local snapshot = noctalia.state.get("snapshot")
local tr = noctalia.tr

local function presentation()
  if snapshot == nil or snapshot.health == nil then
    return "shield-exclamation", "…", tr("status.loading")
  end

  local health = snapshot.health
  local suffix = snapshot.refreshing and "\n" .. tr("status.refreshing") or ""
  if health.severity == "critical" then
    local key = health.issueCount == 1 and "widget.critical_one" or "widget.critical"
    return "shield-x", tostring(health.issueCount), tr(key, { count = health.issueCount }) .. suffix
  elseif health.severity == "warning" then
    local key = health.issueCount == 1 and "widget.attention_one" or "widget.attention"
    return "shield-exclamation", tostring(health.issueCount), tr(key, { count = health.issueCount }) .. suffix
  elseif health.complete ~= true then
    local key = health.unavailableCount == 1 and "widget.incomplete_one" or "widget.incomplete"
    return "shield-exclamation", "!", tr(key, { count = health.unavailableCount }) .. suffix
  elseif (tonumber(health.maintenanceCount) or 0) > 0 then
    local key = health.maintenanceCount == 1 and "widget.maintenance_one" or "widget.maintenance"
    return "tool", tostring(health.maintenanceCount), tr(key, { count = health.maintenanceCount }) .. suffix
  end
  return "shield-check", "", tr("widget.healthy") .. suffix
end

local function render()
  local glyph, text, tooltip = presentation()
  barWidget.setGlyph(glyph)
  barWidget.setText(text)
  barWidget.setTooltip(tooltip)
  barWidget.setVisible(true)
end

noctalia.state.watch("snapshot", function(value)
  snapshot = value
  render()
end)

function onClick()
  noctalia.togglePanel("alexmnrs/arch-maintenance-center:dashboard")
end

function onRightClick()
  noctalia.state.set("refresh_request", noctalia.nowMs())
end

render()
