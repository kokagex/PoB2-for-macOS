-- Game versions
---Default target version for unknown builds and builds created before 3.0.0.
legacyTargetVersion = "0_1"
---Default target for new builds and target to convert legacy builds to.
liveTargetVersion = "0_4"

-- Skill tree versions
---Added for convenient indexing of skill tree versions.
---@type string[]
treeVersionList = { "0_1", "0_2", "0_3", "0_4" }
--- Always points to the latest skill tree version.
latestTreeVersion = treeVersionList[#treeVersionList]
---Tree version where multiple skill trees per build were introduced to PoBC.
defaultTreeVersion = treeVersionList[2]
---Display, comparison and export data for all supported skill tree versions.
---@type table<string, {display: string, num: number, url: string}>
treeVersions = {
	["0_1"] = {
		display = "0.1 (PoE2)",
		num = 0.01,
		url = "",
	},
	["0_2"] = {
		display = "0.2 (PoE2)",
		num = 0.02,
		url = "",
	},
	["0_3"] = {
		display = "0.3 (PoE2)",
		num = 0.03,
		url = "",
	},
	["0_4"] = {
		display = "0.4 (PoE2)",
		num = 0.04,
		url = "",
	},
}

---Mapping PoEPlanner.com version when importing trees from there (https://cdn.poeplanner.com/json/versions.json)
poePlannerVersions = { }
