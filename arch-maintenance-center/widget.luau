--!nonstrict

local snapshot = noctalia.state.get("snapshot")
local tr = noctalia.tr

local function fixtureId()
  local source = type(snapshot) == "table" and snapshot.source or nil
  return type(source) == "table"
    and source.kind == "fixture"
    and type(source.fixtureId) == "string"
    and source.fixtureId
    or nil
end

local function markedTooltip(value)
  local id = fixtureId()
  if id == nil then
    return value
  end
  return tr("widget.demo", { fixture = tr("developer.fixtures." .. id) }) .. "\n" .. value
end

local function presentation()
  if snapshot == nil or snapshot.health == nil then
    return "shield-exclamation", "…", tr("status.loading")
  end

  local platform = type(snapshot.platform) == "table" and snapshot.platform or nil
  if platform == nil or platform.state == "checking" then
    return "shield-search", "…", markedTooltip(tr("widget.platform_checking"))
  elseif platform.state == "unsupported" then
    return "shield-x", "!", markedTooltip(tr("widget.platform_unsupported"))
  elseif platform.state ~= "supported" or platform.id ~= "arch" then
    return "shield-exclamation", "!", markedTooltip(tr("widget.platform_error"))
  end

  local health = snapshot.health
  local suffix = snapshot.refreshing and "\n" .. tr("status.refreshing") or ""
  if snapshot.refreshing == true and type(snapshot.collectedAtMs) ~= "number" then
    return "shield-search", "…", markedTooltip(tr("status.loading"))
  end
  if health.severity == "critical" then
    local key = health.issueCount == 1 and "widget.critical_one" or "widget.critical"
    return "shield-x", tostring(health.issueCount), markedTooltip(tr(key, { count = health.issueCount }) .. suffix)
  elseif health.severity == "warning" then
    local key = health.issueCount == 1 and "widget.attention_one" or "widget.attention"
    return "shield-exclamation", tostring(health.issueCount), markedTooltip(tr(key, { count = health.issueCount }) .. suffix)
  elseif health.complete ~= true then
    local key = health.unavailableCount == 1 and "widget.incomplete_one" or "widget.incomplete"
    return "shield-exclamation", "!", markedTooltip(tr(key, { count = health.unavailableCount }) .. suffix)
  elseif (tonumber(health.recommendationCount) or 0) > 0 then
    local key = health.recommendationCount == 1 and "widget.recommendation_one" or "widget.recommendations"
    return "tool", tostring(health.recommendationCount), markedTooltip(tr(key, { count = health.recommendationCount }) .. suffix)
  end
  return "shield-check", "", markedTooltip(tr("widget.healthy") .. suffix)
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
