--!nonstrict


local snapshot = noctalia.state.get("snapshot")
local tr = noctalia.tr


local function presentation()
  if snapshot == nil or snapshot.health == nil then
    return "shield-exclamation", "…", tr("status.loading")
  end

  local platform = type(snapshot.platform) == "table" and snapshot.platform or nil
  if platform == nil or platform.state == "checking" then
    return "shield-search", "…", tr("widget.platform_checking")
  elseif platform.state == "unsupported" then
    return "shield-x", "!", tr("widget.platform_unsupported")
  elseif platform.state ~= "supported" or platform.id ~= "arch" then
    return "shield-exclamation", "!", tr("widget.platform_error")
  end

  local health = snapshot.health
  local suffix = snapshot.refreshing and "\n" .. tr("status.refreshing") or ""
  if snapshot.refreshing == true and type(snapshot.collectedAtMs) ~= "number" then
    return "shield-search", "…", tr("status.loading")
  end
  if health.severity == "critical" then
    local key = health.issueCount == 1 and "widget.critical_one" or "widget.critical"
    return "shield-x", tostring(health.issueCount), tr(key, { count = health.issueCount }) .. suffix
  elseif health.severity == "warning" then
    local key = health.issueCount == 1 and "widget.attention_one" or "widget.attention"
    return "shield-exclamation", tostring(health.issueCount), tr(key, { count = health.issueCount }) .. suffix
  elseif health.complete ~= true then
    local key = health.unavailableCount == 1 and "widget.incomplete_one" or "widget.incomplete"
    return "shield-exclamation", "!", tr(key, { count = health.unavailableCount }) .. suffix
  elseif (tonumber(health.recommendationCount) or 0) > 0 then
    local key = health.recommendationCount == 1 and "widget.recommendation_one" or "widget.recommendations"
    return "tool", tostring(health.recommendationCount), tr(key, { count = health.recommendationCount }) .. suffix
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
