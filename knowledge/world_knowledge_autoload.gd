# world_knowledge_autoload.gd
# Autoload singleton that provides access to world knowledge.
# This loads the canonical truth archive on game start.
extends Node

var knowledge: WorldKnowledgeResource


func _ready() -> void:
	_initialize_knowledge()


func _initialize_knowledge() -> void:
	# Load the world knowledge resource
	# In production, this would load from a .tres file
	knowledge = WorldKnowledgeResource.new()
	_populate_default_facts()


func _populate_default_facts() -> void:
	# Create sample facts for demonstration
	# In production, these would come from data files
	
	# Location facts
	var blacksmith_loc: FactResource = FactResource.new()
	blacksmith_loc.fact_id = 1
	blacksmith_loc.tags = ["location", "blacksmith", "trade", "market"]
	blacksmith_loc.raw_content = "the blacksmith | is located in | the Market District"
	knowledge.facts[1] = blacksmith_loc
	
	var tavern_loc: FactResource = FactResource.new()
	tavern_loc.fact_id = 2
	tavern_loc.tags = ["location", "tavern", "social", "gates"]
	tavern_loc.raw_content = "The Rusty Sword tavern | stands near | the city gates"
	knowledge.facts[2] = tavern_loc
	
	var temple_loc: FactResource = FactResource.new()
	temple_loc.fact_id = 3
	temple_loc.tags = ["location", "temple", "religious", "hill"]
	temple_loc.raw_content = "the Temple of Dawn | overlooks the city from | the eastern hill"
	knowledge.facts[3] = temple_loc
	
	# People facts
	var king_name: FactResource = FactResource.new()
	king_name.fact_id = 4
	king_name.tags = ["person", "king", "royalty", "politics"]
	king_name.raw_content = "the King | is named | Aldric III"
	knowledge.facts[4] = king_name
	
	var captain_name: FactResource = FactResource.new()
	captain_name.fact_id = 5
	captain_name.tags = ["person", "captain", "guard", "military"]
	captain_name.raw_content = "the Captain of the Guard | is | Helena Ironhand"
	knowledge.facts[5] = captain_name
	
	var merchant_guild: FactResource = FactResource.new()
	merchant_guild.fact_id = 6
	merchant_guild.tags = ["person", "merchant", "guild", "trade"]
	merchant_guild.raw_content = "the Merchant Guild | is led by | Master Tobias"
	knowledge.facts[6] = merchant_guild
	
	# Lore facts
	var great_war: FactResource = FactResource.new()
	great_war.fact_id = 7
	great_war.tags = ["history", "war", "lore", "past"]
	great_war.raw_content = "The Great War | ended | one hundred years ago"
	knowledge.facts[7] = great_war
	
	var dragon_legend: FactResource = FactResource.new()
	dragon_legend.fact_id = 8
	dragon_legend.tags = ["legend", "dragon", "lore", "magic"]
	dragon_legend.raw_content = "the last dragon | was slain by | the First King"
	knowledge.facts[8] = dragon_legend
	
	# Secret fact (for testing restricted knowledge)
	var king_illness: FactResource = FactResource.new()
	king_illness.fact_id = 9
	king_illness.tags = ["secret", "king", "illness", "politics"]
	king_illness.raw_content = "King Aldric | suffers from | a wasting sickness"
	knowledge.facts[9] = king_illness
	
	# === GEOGRAPHY & ECONOMY ===

	# Northern Border
	var whispering_woods: FactResource = FactResource.new()
	whispering_woods.fact_id = 12
	whispering_woods.tags = ["location", "geography", "north", "forest"]
	whispering_woods.raw_content = "the Whispering Woods | lie to | the north of the city"
	knowledge.facts[12] = whispering_woods

	# Currency
	var currency_fact: FactResource = FactResource.new()
	currency_fact.fact_id = 13
	currency_fact.tags = ["economy", "trade", "gold", "market"]
	currency_fact.raw_content = "Gold Crowns | are | the official currency of the realm"
	knowledge.facts[13] = currency_fact

	# Iron Mine
	var iron_mine: FactResource = FactResource.new()
	iron_mine.fact_id = 14
	iron_mine.tags = ["location", "resource", "industrial", "mountains"]
	iron_mine.raw_content = "the Deep-Iron Mine | produces | most of the city's metal"
	knowledge.facts[14] = iron_mine

	# === FACTIONS & CONFLICT ===

	# Mage Academy
	var mage_academy: FactResource = FactResource.new()
	mage_academy.fact_id = 15
	mage_academy.tags = ["person", "wizard", "academy", "magic"]
	mage_academy.raw_content = "Archmage Thalric | leads | the Academy of Unseen Arts"
	knowledge.facts[15] = mage_academy

	# Faction Rivalry
	var faction_rivalry: FactResource = FactResource.new()
	faction_rivalry.fact_id = 16
	faction_rivalry.tags = ["politics", "conflict", "temple", "academy"]
	faction_rivalry.raw_content = "the Temple of Dawn | distrusts | the Academy of Unseen Arts"
	knowledge.facts[16] = faction_rivalry

	# === QUEST HOOKS & HIDDEN KNOWLEDGE ===

	# Thieves Guild Rumor
	var thieves_guild: FactResource = FactResource.new()
	thieves_guild.fact_id = 17
	thieves_guild.tags = ["secret", "thieves", "underground", "crime"]
	thieves_guild.raw_content = "the Thieves Guild | meets in | the sewers beneath the fountain"
	knowledge.facts[17] = thieves_guild

	# Forbidden Artifact
	var moon_shard: FactResource = FactResource.new()
	moon_shard.fact_id = 18
	moon_shard.tags = ["lore", "artifact", "forbidden", "magic"]
	moon_shard.raw_content = "the Moon Shard | is hidden within | the King’s private vault"
	knowledge.facts[18] = moon_shard

	# Impending Threat
	var goblin_scouts: FactResource = FactResource.new()
	goblin_scouts.fact_id = 19
	goblin_scouts.tags = ["rumor", "danger", "goblins", "war"]
	goblin_scouts.raw_content = "Goblin scouts | have been spotted near | the western farms"
	knowledge.facts[19] = goblin_scouts
	
	var village_marsh_edge: FactResource = FactResource.new()
	village_marsh_edge.fact_id = 20
	village_marsh_edge.tags = ["village", "geography", "local"]
	village_marsh_edge.raw_content = "The village | stands where | marsh hardens into usable ground"
	knowledge.facts[20] = village_marsh_edge


	var river_changes_course: FactResource = FactResource.new()
	river_changes_course.fact_id = 21
	river_changes_course.tags = ["river", "geography", "local"]
	river_changes_course.raw_content = "The river | changes its course | after hard winters"
	knowledge.facts[21] = river_changes_course


	var ancient_road: FactResource = FactResource.new()
	ancient_road.fact_id = 22
	ancient_road.tags = ["road", "history", "local"]
	ancient_road.raw_content = "The main road | is older than | the village itself"
	knowledge.facts[22] = ancient_road


	# --- Local history ---

	var north_end_fire: FactResource = FactResource.new()
	north_end_fire.fact_id = 23
	north_end_fire.tags = ["history", "village", "disaster"]
	north_end_fire.raw_content = "A fire | once destroyed | the north end of the village"
	knowledge.facts[23] = north_end_fire


	# --- Customs & social norms ---

	var guests_fed_first: FactResource = FactResource.new()
	guests_fed_first.fact_id = 24
	guests_fed_first.tags = ["custom", "hospitality", "social"]
	guests_fed_first.raw_content = "Guests | are fed before | they are questioned"
	knowledge.facts[24] = guests_fed_first


	var elders_memory_role: FactResource = FactResource.new()
	elders_memory_role.fact_id = 25
	elders_memory_role.tags = ["elders", "custom", "authority"]
	elders_memory_role.raw_content = "Elders | are valued for | memory rather than authority"
	knowledge.facts[25] = elders_memory_role

	# === NPC IDENTITY FACTS ===
	
	# Old Marcus identity
	var marcus_identity: FactResource = FactResource.new()
	marcus_identity.fact_id = 10
	marcus_identity.tags = ["identity", "self", "old marcus", "marcus", "person"]
	marcus_identity.raw_content = "I | am | Old Marcus, a veteran of the city watch"
	knowledge.facts[10] = marcus_identity
	
	# Archivist-7 identity
	var archivist_identity: FactResource = FactResource.new()
	archivist_identity.fact_id = 11
	archivist_identity.tags = ["identity", "self", "archivist-7", "archivist", "person"]
	archivist_identity.raw_content = "I | am | Archivist-7, a knowledge repository system"
	knowledge.facts[11] = archivist_identity




func get_fact(fact_id: int) -> FactResource:
	return knowledge.get_fact(fact_id)


func get_facts_by_tag(tag: String) -> Array[FactResource]:
	return knowledge.get_facts_by_tag(tag)
