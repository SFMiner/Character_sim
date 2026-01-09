# character_profile.gd
# Static character definition. Shared across instances of same character.
# Defines voice, not decision-making (that comes later via extension points).
class_name CharacterProfile
extends Resource

@export var character_name: String = ""

## "human" = natural speech patterns
## "llm" = structured output, hedging, policy-style refusals
@export var character_type: String = "human"

## "terse", "medium", "verbose"
@export var verbosity: String = "medium"

## 0.0 = speaks with certainty
## 1.0 = maximum hedging and uncertainty markers
@export var hedge_intensity: float = 0.5

## Topics this character will not discuss (triggers refusal skeleton)
@export var forbidden_topics: Array[String] = []

## Skeleton IDs this character prefers (weighted higher in selection)
@export var preferred_skeletons: Array[String] = []

## EXTENSION POINT: Personality traits (add when boring)
# @export var warmth: float = 0.0           # -1 to 1, affects friendliness
# @export var assertiveness: float = 0.0    # -1 to 1, affects directness
# @export var conscientiousness: float = 0.0 # -1 to 1, affects precision
# @export var curiosity: float = 0.0        # -1 to 1, affects engagement
# @export var risk_tolerance: float = 0.0   # -1 to 1, affects caution
# @export var stability: float = 0.0        # -1 to 1, affects consistency
# @export var values: Dictionary = {}       # value_name -> weight (float)
