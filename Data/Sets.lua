-- GENERATED FILE - do not edit by hand.
-- Source: Battle.net Game Data API, namespace static-1.60.1_70399-forever-eu, locale en_US
-- Regenerate with: pwsh tools/Export-Sets.ps1
local _, ns = ...

local sets = {
    [141] = {
        name = "Volcanic Armor",
        items = { 15053, 15054, 15055 },
        effects = { { count = 3, text = "5% chance of dealing 30 to 50 Fire damage on a successful melee attack." } },
    },
    [142] = {
        name = "Stormshroud Armor",
        items = { 15056, 15057, 15058, 21278 },
        effects = { { count = 2, text = "10% chance of dealing 15 to 25 Nature damage on a successful melee attack." }, { count = 3, text = "4% chance on melee attack of restoring 30 energy." }, { count = 4, text = "+14 Attack Power." } },
    },
    [143] = {
        name = "Devilsaur Armor",
        items = { 15062, 15063 },
        effects = { { count = 2, text = "Improves your chance to hit by 2.0%." } },
    },
    [144] = {
        name = "Ironfeather Armor",
        items = { 15066, 15067 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 20." } },
    },
    [221] = {
        name = "Garb of Thero-shan",
        items = { 7950, 7948, 7952, 7951, 7953, 7949 },
        effects = { { count = 6, text = "Improves your chance to get a critical strike with melee attacks by 1.0%." } },
    },
    [281] = {
        name = "Champion's Battlegear",
        items = { 272478, 272477, 272481, 272479, 272637, 272480 },
        effects = { { count = 2, text = "+40 Attack Power." }, { count = 4, text = "Reduces the cooldown of your Intercept ability by 5 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [282] = {
        name = "Lieutenant Commander's Battlegear",
        items = { 272717, 272716, 272740, 272739, 272741, 272738 },
        effects = { { count = 2, text = "+40 Attack Power." }, { count = 4, text = "Reduces the cooldown of your Intercept ability by 5 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [301] = {
        name = "Champion's Earthshaker",
        items = { 272485, 272609, 272488, 272625, 272489, 272647 },
        effects = { { count = 2, text = "+40 Attack Power." }, { count = 4, text = "Improves your chance to get a critical strike with all Shock spells by 2%." }, { count = 6, text = "+20 Stamina." } },
    },
    [321] = {
        name = "Imperial Plate",
        items = { 12424, 12426, 12425, 12422, 12427, 12429, 12428, 250589 },
        effects = { { count = 2, text = "Increased Defense +7." }, { count = 3, text = "Improves your chance to hit by 1.0%." }, { count = 4, text = "Imperial discipline prevents your movement speed from being reduced below 80%." }, { count = 5, text = "+20 Strength." }, { count = 6, text = "Improves your chance to get a critical strike by 1.0%." } },
    },
    [341] = {
        name = "Champion's Regalia",
        items = { 16485, 16487, 16491, 16490, 16489, 16492 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Reduces the cooldown of your Blink spell by 1.5 sec." }, { count = 6, text = "+15 Stamina." } },
    },
    [342] = {
        name = "Champion's Raiment",
        items = { 17616, 17617, 17612, 17611, 17613, 17610 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Increases the duration of your Psychic Scream spell by 1 sec." }, { count = 6, text = "+15 Stamina." } },
    },
    [343] = {
        name = "Lieutenant Commander's Regalia",
        items = { 272722, 272703, 272701, 272723, 272724, 272725 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Reduces the cooldown of your Blink spell by 1.5 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [344] = {
        name = "Lieutenant Commander's Raiment",
        items = { 272816, 272812, 272810, 272815, 272817, 272814 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Increases the duration of your Psychic Scream spell by 1 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [345] = {
        name = "Champion's Threads",
        items = { 272643, 272549, 272630, 272552, 272553, 272548 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Reduces the casting time of your Immolate spell by 0.2  sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [346] = {
        name = "Lieutenant Commander's Threads",
        items = { 272800, 272796, 272794, 272657, 272801, 272671 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Reduces the casting time of your Immolate spell by 0.2  sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [347] = {
        name = "Champion's Vestments",
        items = { 16498, 16499, 16505, 16508, 16506, 16507 },
        effects = { { count = 2, text = "Increases your chance to parry an attack by 1%." }, { count = 4, text = "Reduces the cooldown of your Gouge ability by 1 sec." }, { count = 6, text = "+15 Stamina." } },
    },
    [348] = {
        name = "Lieutenant Commander's Vestments",
        items = { 272708, 272704, 272728, 272726, 272729, 272727 },
        effects = { { count = 2, text = "+40 Attack Power." }, { count = 4, text = "Reduces the cooldown of your Gouge ability by 1 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [361] = {
        name = "Champion's Pursuit",
        items = { 272495, 272496, 272492, 272490, 272640 },
        effects = { { count = 2, text = "+20 Agility." }, { count = 4, text = "Reduces the cooldown of your Concussive Shot by 1 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [362] = {
        name = "Lieutenant Commander's Pursuit",
        items = { 272715, 272713, 272735, 272734, 272736, 272737 },
        effects = { { count = 2, text = "+20 Agility." }, { count = 4, text = "Reduces the cooldown of your Concussive Shot by 1 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [381] = {
        name = "Lieutenant Commander's Sanctuary",
        items = { 272709, 272705, 272731, 272730, 272732, 272733 },
        effects = { { count = 2, text = "+40 Attack Power." }, { count = 4, text = "Increases your movement speed by 15% while in Bear, Cat, or Travel Form.  Only active outdoors." }, { count = 6, text = "+20 Stamina." } },
    },
    [382] = {
        name = "Champion's Sanctuary",
        items = { 272614, 272462, 272470, 272472, 272469, 272471 },
        effects = { { count = 2, text = "+40 Attack Power." }, { count = 4, text = "Increases your movement speed by 15% while in Bear, Cat, or Travel Form.  Only active outdoors." }, { count = 6, text = "+20 Stamina." } },
    },
    [383] = {
        name = "Warlord's Battlegear",
        items = { 272513, 272510, 272508, 272506, 272509, 272507 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Reduces the cooldown of your Intercept ability by 5 sec." }, { count = 6, text = "+40 Attack Power." } },
    },
    [384] = {
        name = "Field Marshal's Battlegear",
        items = { 272793, 272792, 272788, 272786, 272789, 272787 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Reduces the cooldown of your Intercept ability by 5 sec." }, { count = 6, text = "+40 Attack Power." } },
    },
    [386] = {
        name = "Warlord's Earthshaker",
        items = { 272539, 272538, 272544, 272542, 272545, 272543 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with all Shock spells by 2%." }, { count = 6, text = "+40 Attack Power." } },
    },
    [387] = {
        name = "Warlord's Regalia",
        items = { 272500, 272505, 272504, 272499, 272501, 272498 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Reduces the cooldown of your Blink spell by 1.5 sec." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." } },
    },
    [388] = {
        name = "Field Marshal's Regalia",
        items = { 272752, 272749, 272746, 272751, 272753, 272750 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Reduces the cooldown of your Blink spell by 1.5 sec." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." } },
    },
    [389] = {
        name = "Field Marshal's Raiment",
        items = { 272821, 272824, 272823, 272819, 272820, 272818 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Increases the duration of your Psychic Scream spell by 1 sec." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." } },
    },
    [390] = {
        name = "Warlord's Raiment",
        items = { 272576, 272572, 272570, 272577, 272574, 272575 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Increases the duration of your Psychic Scream spell by 1 sec." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." } },
    },
    [391] = {
        name = "Warlord's Threads",
        items = { 272560, 272556, 272554, 272561, 272558, 272559 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Reduces the casting time of your Immolate spell by 0.2  sec." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." } },
    },
    [392] = {
        name = "Field Marshal's Threads",
        items = { 272805, 272808, 272807, 272803, 272804, 272802 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Reduces the casting time of your Immolate spell by 0.2  sec." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." } },
    },
    [393] = {
        name = "Warlord's Vestments",
        items = { 272525, 272523, 272529, 272528, 272527, 272526 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Reduces the cooldown of your Gouge ability by 1 sec." }, { count = 6, text = "+40 Attack Power." } },
    },
    [394] = {
        name = "Field Marshal's Vestments",
        items = { 272763, 272755, 272765, 272762, 272766, 272764 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Reduces the cooldown of your Gouge ability by 1 sec." }, { count = 6, text = "+40 Attack Power." } },
    },
    [395] = {
        name = "Field Marshal's Pursuit",
        items = { 272772, 272771, 272776, 272775, 272777, 272774 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Reduces the cooldown of your Concussive Shot by 1 sec." }, { count = 6, text = "+20 Agility." } },
    },
    [396] = {
        name = "Warlord's Pursuit",
        items = { 272536, 272534, 272532, 272530, 272533, 272531 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Reduces the cooldown of your Concussive Shot by 1 sec." }, { count = 6, text = "+20 Agility." } },
    },
    [397] = {
        name = "Field Marshal's Sanctuary",
        items = { 272757, 272768, 272759, 272761, 272758, 272760 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Increases your movement speed by 15% while in Bear, Cat, or Travel Form.  Only active outdoors." }, { count = 6, text = "+40 Attack Power." } },
    },
    [398] = {
        name = "Warlord's Sanctuary",
        items = { 272520, 272519, 272517, 272514, 272516, 272515 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Increases your movement speed by 15% while in Bear, Cat, or Travel Form.  Only active outdoors." }, { count = 6, text = "+40 Attack Power." } },
    },
    [401] = {
        name = "Lieutenant Commander's Aegis",
        items = { 273363, 273365, 272853, 272852, 272855, 272854 },
        effects = { { count = 2, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." }, { count = 4, text = "Reduces the cooldown of your Hammer of Justice by 10 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [402] = {
        name = "Field Marshal's Aegis",
        items = { 273329, 273330, 273333, 273331, 273334, 273332 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Reduces the cooldown of your Hammer of Justice by 10 sec." }, { count = 6, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." } },
    },
    [421] = {
        name = "Bloodvine Garb",
        items = { 19682, 19683, 19684 },
        effects = { { count = 3, text = "Improves your chance to get a critical strike with spells by 2.0%." } },
    },
    [441] = {
        name = "Primal Batskin",
        items = { 19685, 19687, 19686 },
        effects = { { count = 3, text = "Minor increase to running and swimming speed. Does not stack with similar effects." } },
    },
    [442] = {
        name = "Blood Tiger Harness",
        items = { 19688, 19689 },
        effects = { { count = 2, text = "Improves your chance to get a critical strike with melee attacks by 1.0%." } },
    },
    [443] = {
        name = "Bloodsoul Embrace",
        items = { 19690, 19691, 19692 },
        effects = { { count = 3, text = "Restores 12 mana per 5 sec." } },
    },
    [444] = {
        name = "The Darksoul",
        items = { 19693, 19694, 19695 },
        effects = { { count = 3, text = "Increased Defense +20." } },
    },
    [467] = {
        name = "The Highlander's Resolution",
        items = { 20041, 20048, 20057 },
        effects = { { count = 2, text = "+5 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with melee attacks by 1.0%." } },
    },
    [468] = {
        name = "The Highlander's Resolve",
        items = { 20042, 20049, 20058 },
        effects = { { count = 2, text = "+5 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with melee attacks by 1.0%." } },
    },
    [469] = {
        name = "The Highlander's Determination",
        items = { 20043, 20050, 20055 },
        effects = { { count = 2, text = "+5 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with melee attacks by 1.0%." } },
    },
    [470] = {
        name = "The Highlander's Fortitude",
        items = { 20044, 20051, 20056 },
        effects = { { count = 2, text = "+5 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with spells by 1.0%." } },
    },
    [471] = {
        name = "The Highlander's Purpose",
        items = { 20052, 20045, 20059 },
        effects = { { count = 2, text = "+5 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with melee attacks by 1.0%." } },
    },
    [472] = {
        name = "The Highlander's Will",
        items = { 20053, 20046, 20060 },
        effects = { { count = 2, text = "+5 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with spells by 1.0%." } },
    },
    [473] = {
        name = "The Highlander's Intent",
        items = { 20054, 20047, 20061 },
        effects = { { count = 2, text = "+5 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with spells by 1.0%." } },
    },
    [474] = {
        name = "Vindicator's Battlegear",
        items = { 19951, 19577, 19824, 19823, 19822 },
        effects = { { count = 2, text = "Increases your chance to block attacks with a shield by 2%." }, { count = 3, text = "Decreases the cooldown of Intimidating Shout by 15 sec." }, { count = 5, text = "Decrease the rage cost of Whirlwind by 3." } },
    },
    [475] = {
        name = "Freethinker's Armor",
        items = { 19952, 19588, 19827, 19826, 19825 },
        effects = { { count = 2, text = "Restores 4 mana per 5 sec." }, { count = 3, text = "Reduces the casting time of your Holy Light spell by 0.1 sec." }, { count = 5, text = "Increases the duration of all Blessings by 10%." } },
    },
    [476] = {
        name = "Augur's Regalia",
        items = { 19609, 19956, 19830, 19829, 19828 },
        effects = { { count = 2, text = "Restores 4 mana per 5 sec." }, { count = 3, text = "Improves the duration of your Frost Shock spell by 1 sec." }, { count = 5, text = "Increase the range of your Lightning Bolt spell by 5 yds." } },
    },
    [477] = {
        name = "Predator's Armor",
        items = { 19621, 19953, 19833, 19832, 19831 },
        effects = { { count = 2, text = "+20 Attack Power." }, { count = 3, text = "Decreases the cooldown of Concussive Shot by 1 sec." }, { count = 5, text = "Increases the duration of Serpent Sting by 3 sec." } },
    },
    [478] = {
        name = "Madcap's Outfit",
        items = { 19617, 19954, 19836, 19835, 19834 },
        effects = { { count = 2, text = "+20 Attack Power." }, { count = 3, text = "Decreases the cooldown of Blind by 20 sec." }, { count = 5, text = "Decrease the energy cost of Eviscerate and Rupture by 5." } },
    },
    [479] = {
        name = "Haruspex's Garb",
        items = { 19613, 19955, 19840, 19839, 19838 },
        effects = { { count = 2, text = "Restores 4 mana per 5 sec." }, { count = 3, text = "Increases the duration of Faerie Fire by 5 sec." }, { count = 5, text = "Increases the critical hit chance of your Starfire spell 3%." } },
    },
    [480] = {
        name = "Confessor's Raiment",
        items = { 19594, 19958, 19843, 19842, 19841 },
        effects = { { count = 2, text = "Increases healing done by spells and effects by up to 22." }, { count = 3, text = "Increase the range of your Smite and Holy Fire spells by 5 yds." }, { count = 5, text = "Reduces the casting time of your Mind Control spell by 0.5 sec." } },
    },
    [481] = {
        name = "Demoniac's Threads",
        items = { 19605, 19957, 19848, 19849, 20033 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 12." }, { count = 3, text = "Increases the damage of Corruption by 2%." }, { count = 5, text = "Decreases the cooldown of Death Coil by 15%." } },
    },
    [482] = {
        name = "Illusionist's Attire",
        items = { 19601, 19959, 19846, 19845, 20034 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 12." }, { count = 3, text = "Decreases the mana cost of Arcane Intellect and Arcane Brilliance by 5%." }, { count = 5, text = "Reduces the casting time of your Flamestrike spell by 0.5 sec." } },
    },
    [483] = {
        name = "The Defiler's Determination",
        items = { 20158, 20154, 20150 },
        effects = { { count = 2, text = "+5 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with melee attacks by 1.0%." } },
    },
    [484] = {
        name = "The Defiler's Fortitude",
        items = { 20195, 20199, 20203 },
        effects = { { count = 2, text = "+5 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with melee attacks by 1.0%." } },
    },
    [485] = {
        name = "The Defiler's Intent",
        items = { 20176, 20159, 20163 },
        effects = { { count = 2, text = "+5 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with spells by 1.0%." } },
    },
    [486] = {
        name = "The Defiler's Purpose",
        items = { 20186, 20190, 20194 },
        effects = { { count = 2, text = "+5 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with melee attacks by 1.0%." } },
    },
    [487] = {
        name = "The Defiler's Resolution",
        items = { 20204, 20208, 20212 },
        effects = { { count = 2, text = "+5 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with melee attacks by 1.0%." } },
    },
    [488] = {
        name = "The Defiler's Will",
        items = { 20167, 20171, 20175 },
        effects = { { count = 2, text = "+5 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with spells by 1.0%." } },
    },
    [489] = {
        name = "Black Dragon Mail",
        items = { 15050, 15052, 15051 },
        effects = { { count = 2, text = "Improves your chance to hit by 1.0%." }, { count = 3, text = "Improves your chance to get a critical strike with melee attacks by 2.0%." } },
    },
    [490] = {
        name = "Green Dragon Mail",
        items = { 15045, 15046, 20296 },
        effects = { { count = 2, text = "Restores 3 mana per 5 sec." }, { count = 3, text = "Allows 15% of your Mana regeneration to continue while casting." } },
    },
    [491] = {
        name = "Blue Dragon Mail",
        items = { 15048, 20295, 15049 },
        effects = { { count = 2, text = "+4 All Resistances." }, { count = 3, text = "Increases damage and healing done by magical spells and effects by up to 28." } },
    },
    [492] = {
        name = "Twilight Trappings",
        items = { 20406, 20408, 20407 },
        effects = { { count = 3, text = "Bestows the wearer with the evil aura of a Twilight's Hammer cultist." } },
    },
    [493] = {
        name = "Genesis Raiment",
        items = { 21355, 21353, 21354, 21356, 21357 },
        effects = { { count = 3, text = "Increased Defense +15." }, { count = 5, text = "Reduces the cooldown of Rebirth by 10 minutes." } },
    },
    [494] = {
        name = "Symbols of Unending Life",
        items = { 21408, 21409, 21407 },
        effects = { { count = 3, text = "Your finishing moves now refund 30 energy on a Miss, Dodge, Block, or Parry." } },
    },
    [495] = {
        name = "Battlegear of Unyielding Strength",
        items = { 21394, 21392, 21393 },
        effects = { { count = 3, text = "-2 rage cost to Intercept." } },
    },
    [496] = {
        name = "Conqueror's Battlegear",
        items = { 21331, 21329, 21333, 21332, 21330 },
        effects = { { count = 3, text = "Decreases the rage cost of all Warrior shouts by 35%." }, { count = 5, text = "Increase the Slow effect and damage of Thunder Clap by 50%." } },
    },
    [497] = {
        name = "Deathdealer's Embrace",
        items = { 21359, 21360, 21361, 21362, 21364 },
        effects = { { count = 3, text = "Reduces the cooldown of your Evasion ability by -1 min." }, { count = 5, text = "15% increased damage to your Eviscerate ability." } },
    },
    [498] = {
        name = "Emblems of Veiled Shadows",
        items = { 21405, 21406, 21404 },
        effects = { { count = 3, text = "-10 energy cost for your Slice and Dice ability." } },
    },
    [499] = {
        name = "Doomcaller's Attire",
        items = { 21337, 21338, 21335, 21334, 21336 },
        effects = { { count = 3, text = "5% increased damage on your Immolate spell." }, { count = 5, text = "Reduces the mana cost of Shadow Bolt by 15%." } },
    },
    [500] = {
        name = "Implements of Unspoken Names",
        items = { 21416, 21417, 21418 },
        effects = { { count = 3, text = "5% increased damage from your summoned pets' melee attacks and damage spells." } },
    },
    [501] = {
        name = "Stormcaller's Garb",
        items = { 21372, 21373, 21374, 21375, 21376 },
        effects = { { count = 3, text = "Your Lightning Bolt, Chain Lightning, and Shock spells have a 20% chance to grant up to 50 Nature damage to spells for 8 sec." }, { count = 5, text = "-0.4 seconds on the casting time of your Chain Heal spell." } },
    },
    [502] = {
        name = "Gift of the Gathering Storm",
        items = { 21400, 21398, 21399 },
        effects = { { count = 3, text = "Increases the chain target damage multiplier of your Chain Lightning spell by 5%." } },
    },
    [503] = {
        name = "Enigma Vestments",
        items = { 21344, 21347, 21346, 21343, 21345 },
        effects = { { count = 3, text = "Your Blizzard spell has a 30% chance to be uninterruptible." }, { count = 5, text = "Grants +5% increased spell hit chance for 20 sec when one of your spells is resisted." } },
    },
    [504] = {
        name = "Trappings of Vaulted Secrets",
        items = { 21414, 21413, 21415 },
        effects = { { count = 3, text = "15% increase to the total damage absorbed by Mana Shield." } },
    },
    [505] = {
        name = "Avenger's Battlegear",
        items = { 21389, 21387, 21388, 21390, 21391 },
        effects = { { count = 3, text = "Increases the duration of your Judgements by 20%." }, { count = 5, text = "Increases damage and healing done by magical spells and effects by up to 71." } },
    },
    [506] = {
        name = "Battlegear of Eternal Justice",
        items = { 21397, 21395, 21396 },
        effects = { { count = 3, text = "20% chance to regain 100 mana when you cast a Judgement." } },
    },
    [507] = {
        name = "Garments of the Oracle",
        items = { 21349, 21350, 21348, 21352, 21351 },
        effects = { { count = 3, text = "20% chance that your heals on others will also heal you 10% of the amount healed." }, { count = 5, text = "Increases the duration of your Renew spell by 3 sec." } },
    },
    [508] = {
        name = "Finery of Infinite Wisdom",
        items = { 21410, 21411, 21412 },
        effects = { { count = 3, text = "Increases the damage of your Shadow Word: Pain spell by 5%." } },
    },
    [509] = {
        name = "Striker's Garb",
        items = { 21366, 21365, 21370, 21368, 21367 },
        effects = { { count = 3, text = "Reduces the cost of your Arcane Shots by 10%." }, { count = 5, text = "Reduces the cooldown of your Rapid Fire ability by 2 minutes." } },
    },
    [510] = {
        name = "Trappings of the Unseen Path",
        items = { 21403, 21401, 21402 },
        effects = { { count = 3, text = "Increases your pet's damage by 3%." } },
    },
    [511] = {
        name = "Battlegear of Heroism",
        items = { 21994, 21995, 21996, 21997, 21998, 21999, 22000, 22001 },
        effects = { { count = 2, text = "+8 All Resistances." }, { count = 4, text = "Chance on melee attack to heal you for 88 to 132." }, { count = 6, text = "+40 Attack Power." }, { count = 8, text = "+200 Armor." } },
    },
    [512] = {
        name = "Darkmantle Armor",
        items = { 22002, 22003, 22004, 22005, 22006, 22007, 22008, 22009 },
        effects = { { count = 2, text = "+8 All Resistances." }, { count = 4, text = "Chance on melee attack to restore 20 Energy." }, { count = 6, text = "+40 Attack Power." }, { count = 8, text = "+200 Armor." } },
    },
    [513] = {
        name = "Feralheart Raiment",
        items = { 22106, 22107, 22108, 22109, 22110, 22111, 22112, 22113 },
        effects = { { count = 2, text = "+8 All Resistances." }, { count = 4, text = "When struck in combat has a chance of returning 300 mana, 10 rage, or 40 energy to the wearer. " }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 15." }, { count = 8, text = "+200 Armor." } },
    },
    [514] = {
        name = "Vestments of the Virtuous",
        items = { 22078, 22079, 22080, 22081, 22082, 22083, 22084, 22085 },
        effects = { { count = 2, text = "+8 All Resistances." }, { count = 4, text = "When struck in combat has a 2% chance of shielding the wearer in a protective shield which will absorb 488 damage. Can only occur once every 60 sec." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 8, text = "+200 Armor." } },
    },
    [515] = {
        name = "Beastmaster Armor",
        items = { 22010, 22011, 22061, 22013, 22015, 22016, 22017, 22060 },
        effects = { { count = 2, text = "+8 All Resistances." }, { count = 4, text = "Your normal ranged attacks have a 4% chance of restoring 200 mana." }, { count = 6, text = "+40 Attack Power." }, { count = 8, text = "+200 Armor." } },
    },
    [516] = {
        name = "Soulforge Armor",
        items = { 22086, 22087, 22088, 22089, 22090, 22091, 22092, 22093 },
        effects = { { count = 2, text = "+8 All Resistances." }, { count = 4, text = "Chance on melee attack to increase your damage and healing done by magical spells and effects by up to 65 for 10 sec." }, { count = 6, text = "+40 Attack Power." }, { count = 8, text = "+200 Armor." } },
    },
    [517] = {
        name = "Sorcerer's Regalia",
        items = { 22062, 22063, 22064, 22065, 22066, 22067, 22068, 22069 },
        effects = { { count = 2, text = "+8 All Resistances." }, { count = 4, text = "When struck in combat has a 2% chance of freezing the attacker in place for 3 sec. Can only occur once every 60 sec." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 8, text = "+200 Armor." } },
    },
    [518] = {
        name = "Deathmist Raiment",
        items = { 22070, 22071, 22072, 22073, 22074, 22075, 22076, 22077 },
        effects = { { count = 2, text = "+8 All Resistances." }, { count = 4, text = "When struck in combat has a 2% chance of causing the attacker to flee in terror for 2 sec. Can only occur once every 60 sec." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 8, text = "+200 Armor." } },
    },
    [519] = {
        name = "The Five Thunders",
        items = { 22095, 22096, 22097, 22098, 22099, 22100, 22101, 22102 },
        effects = { { count = 2, text = "+8 All Resistances." }, { count = 4, text = "Chance on spell cast to increase your damage and healing by up to 65 for 10 sec." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 8, text = "+200 Armor." } },
    },
    [521] = {
        name = "Dreamwalker Raiment",
        items = { 22492, 22494, 22493, 22490, 22489, 22491, 22488, 22495, 23064 },
        effects = { { count = 2, text = "Your Rejuvenation ticks have a chance to restore 60 mana, 8 energy, or 2 rage to your target." }, { count = 4, text = "Reduces the mana cost of your Healing Touch, Regrowth, Rejuvenation,  and Tranquility spells by 3%." }, { count = 6, text = "Your initial cast and Regrowth ticks will increase the maximum health of your target by up to 50, stacking up to 7 times." }, { count = 8, text = "On Healing Touch critical hits, you regain 30% of the mana cost of the spell." } },
    },
    [522] = {
        name = "Champion's Vestments",
        items = { 272467, 272608, 272476, 272473, 272475, 272474 },
        effects = { { count = 2, text = "+40 Attack Power." }, { count = 4, text = "Reduces the cooldown of your Gouge ability by 1 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [523] = {
        name = "Dreadnaught's Battlegear",
        items = { 22423, 22416, 22421, 22422, 22418, 22417, 22419, 22420, 23059 },
        effects = { { count = 2, text = "Increases the damage done by your Revenge ability by 75." }, { count = 4, text = "Improves your chance to hit with Taunt and Challenging Shout by 5%." }, { count = 6, text = "Improves your chance to hit with Sunder Armor, Heroic Strike, Revenge, and Shield Slam by 5%." }, { count = 8, text = "When your health drops below 20%, for the next 5 seconds healing spells cast on you help you to Cheat Death, increasing healing done by up to 160." } },
    },
    [524] = {
        name = "Bonescythe Armor",
        items = { 22483, 22476, 22481, 22478, 22477, 22479, 22480, 22482, 23060 },
        effects = { { count = 2, text = "Your normal melee swings have a chance to Invigorate you, healing you for 90 to 110." }, { count = 4, text = "Your Backstab, Sinister Strike, and Hemorrhage critical hits cause you to regain 5 energy." }, { count = 6, text = "Reduces the threat from your Backstab, Sinister Strike, Hemorrhage, and Eviscerate abilities." }, { count = 8, text = "Your Eviscerate has a chance per combo point to reveal a flaw in your opponent's armor, granting a 100% critical hit chance for your next Backstab, Sinister Strike, or Hemorrhage." } },
    },
    [525] = {
        name = "Vestments of Faith",
        items = { 22518, 22519, 22514, 22517, 22513, 22512, 22516, 22515, 23061 },
        effects = { { count = 2, text = "Reduces the mana cost of your Renew spell by 12%." }, { count = 4, text = "On Greater Heal critical hits, your target will gain Armor of Faith, absorbing up to 500 damage." }, { count = 6, text = "Reduces the threat from your healing spells." }, { count = 8, text = "Each spell you cast can trigger an Epiphany, increasing your mana regeneration by 24 for 30 sec." } },
    },
    [526] = {
        name = "Frostfire Regalia",
        items = { 22502, 22503, 22498, 22501, 22497, 22496, 22500, 22499, 23062 },
        effects = { { count = 2, text = "Reduces cooldown on your Evocation by 1 minute." }, { count = 4, text = "Gives your Mage Armor a chance when struck by a harmful spell to increase resistance against that school of magic by 35 for 30 sec." }, { count = 6, text = "Your damage spells have a chance to cause your target to take up to 200 increased damage from subsequent spells." }, { count = 8, text = "Your damage spells have a chance to displace you, causing the next spell cast to generate no threat." } },
    },
    [527] = {
        name = "The Earthshatterer",
        items = { 22468, 22470, 22469, 22466, 22465, 22467, 22464, 22471, 23065 },
        effects = { { count = 2, text = "Reduces the mana cost of your totem spells by 12%." }, { count = 4, text = "Increases the mana gained from your Mana Spring totems by 25%." }, { count = 6, text = "Your Healing Wave and Lesser Healing Wave spells have a chance to imbue your target with Totemic Power." }, { count = 8, text = "Your Lightning Shield spell also grants you 15 mana per 5 sec. while active." } },
    },
    [528] = {
        name = "Redemption Armor",
        items = { 22430, 22431, 22426, 22428, 22427, 22429, 22425, 22424, 23066 },
        effects = { { count = 2, text = "Increases the amount healed by your Judgement of Light by 20." }, { count = 4, text = "Reduces cooldown on your Lay on Hands by 12 min." }, { count = 6, text = "Your Flash of Light and Holy Light spells have a chance to imbue your target with Holy Power." }, { count = 8, text = "Your Cleanse spell also heals the target for 200." } },
    },
    [529] = {
        name = "Plagueheart Raiment",
        items = { 22510, 22511, 22506, 22509, 22505, 22504, 22508, 22507, 23063 },
        effects = { { count = 2, text = "Your Shadow Bolts now have a chance to heal you for 270 to 330." }, { count = 4, text = "Increases damage caused by your Corruption by 12%." }, { count = 6, text = "Your spell critical hits generate 25% less threat.  In addition, Corruption, Immolate, Curse of Agony, and Siphon Life generate 25% less threat." }, { count = 8, text = "Reduces health cost of your Life Tap by 12%." } },
    },
    [530] = {
        name = "Cryptstalker Armor",
        items = { 22440, 22442, 22441, 22438, 22437, 22439, 22436, 22443, 23067 },
        effects = { { count = 2, text = "Increases the duration of your Rapid Fire by 4 secs." }, { count = 4, text = "Increases Attack Power by 50 for both you and your pet." }, { count = 6, text = "Your ranged critical hits cause an Adrenaline Rush, granting you 50 mana." }, { count = 8, text = "Reduces the mana cost of your Multi-Shot and Aimed Shot by 20." } },
    },
    [533] = {
        name = "Battlegear of Undead Slaying",
        items = { 23078 },
        effects = { { count = 3, text = "Increases your damage against undead by 2%." } },
    },
    [534] = {
        name = "Undead Slayer's Armor",
        items = { 23081 },
        effects = { { count = 3, text = "Increases your damage against undead by 2%." } },
    },
    [535] = {
        name = "Garb of the Undead Slayer",
        items = { 23082 },
        effects = { { count = 3, text = "Increases your damage against undead by 2%." } },
    },
    [536] = {
        name = "Regalia of Undead Cleansing",
        items = { 23084 },
        effects = { { count = 3, text = "Increases your damage against undead by 2%." } },
    },
    [537] = {
        name = "Champion's Battlearmor",
        items = { 22868, 22858, 22872, 22873, 23244, 23243 },
        effects = { { count = 2, text = "+40 Attack Power." }, { count = 4, text = "Reduces the cooldown of your Intercept ability by 5 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [538] = {
        name = "Champion's Stormcaller",
        items = { 22857, 22867, 22876, 22887, 23259, 23260 },
        effects = { { count = 2, text = "+40 Attack Power." }, { count = 4, text = "Improves your chance to get a critical strike with all Shock spells by 2%." }, { count = 6, text = "+20 Stamina." } },
    },
    [539] = {
        name = "Champion's Refuge",
        items = { 272464, 272606, 272627, 272626, 272642, 272641 },
        effects = { { count = 2, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." }, { count = 4, text = "Increases your movement speed by 15% while in Bear, Cat, or Travel Form.  Only active outdoors." }, { count = 6, text = "+20 Stamina." } },
    },
    [540] = {
        name = "Champion's Investiture",
        items = { 22869, 22859, 22882, 22885, 23261, 23262 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Increases the duration of your Psychic Scream spell by 1 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [541] = {
        name = "Champion's Dreadgear",
        items = { 22865, 22855, 23255, 23256, 22881, 22884 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Reduces the casting time of your Immolate spell by 0.2  sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [542] = {
        name = "Champion's Arcanum",
        items = { 22870, 22860, 23263, 23264, 22883, 22886 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Reduces the cooldown of your Blink spell by 1.5 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [543] = {
        name = "Champion's Pursuance",
        items = { 22843, 22862, 23251, 23252, 22874, 22875 },
        effects = { { count = 2, text = "+20 Agility." }, { count = 4, text = "Reduces the cooldown of your Concussive Shot by 1 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [544] = {
        name = "Lieutenant Commander's Redoubt",
        items = { 23272, 23273, 23274, 23275, 23276, 23277 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Reduces the cooldown of your Hammer of Justice by 10 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [545] = {
        name = "Lieutenant Commander's Battlearmor",
        items = { 23300, 23301, 23286, 23287, 23314, 23315 },
        effects = { { count = 2, text = "+40 Attack Power." }, { count = 4, text = "Reduces the cooldown of your Intercept ability by 5 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [546] = {
        name = "Champion's Regalia",
        items = { 272459, 272455, 272453, 272458, 272680, 272457 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Reduces the cooldown of your Blink spell by 1.5 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [547] = {
        name = "Lieutenant Commander's Dreadgear",
        items = { 23296, 23297, 23282, 23283, 23310, 23311 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Reduces the casting time of your Immolate spell by 0.2  sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [548] = {
        name = "Lieutenant Commander's Guard",
        items = { 23298, 23299, 23284, 23285, 23312, 23313 },
        effects = { { count = 2, text = "+40 Attack Power." }, { count = 4, text = "Reduces the cooldown of your Gouge ability by 1 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [549] = {
        name = "Champion's Raiment",
        items = { 272564, 272569, 272568, 272563, 272565, 272562 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Increases the duration of your Psychic Scream spell by 1 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [550] = {
        name = "Lieutenant Commander's Pursuance",
        items = { 23292, 23293, 23278, 23279, 23306, 23307 },
        effects = { { count = 2, text = "+20 Agility." }, { count = 4, text = "Reduces the cooldown of your Concussive Shot by 1 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [551] = {
        name = "Lieutenant Commander's Refuge",
        items = { 273377, 273379, 273373, 273380, 273375, 273374 },
        effects = { { count = 2, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." }, { count = 4, text = "Increases your movement speed by 15% while in Bear, Cat, or Travel Form.  Only active outdoors." }, { count = 6, text = "+20 Stamina." } },
    },
    [1968] = {
        name = "Blessed Plate",
        items = { 250594, 250593, 250592, 250591, 250590, 250588, 250587, 250586 },
        effects = { { count = 2, text = "+10 Shadow Resistance." }, { count = 3, text = "+20 Strength." }, { count = 4, text = "All party members within 30 yds are blessed, restoring 20 health every 5 sec." }, { count = 5, text = "Improves your chance to hit by 2.0%." }, { count = 6, text = "Increases damage done by Holy spells and effects by up to 29." } },
    },
    [1972] = {
        name = "Stormcloth Regalia",
        items = { 10010, 10011, 10020, 10032, 10038, 10039 },
        effects = { { count = 3, text = "+10 Spirit." }, { count = 6, text = "Increases healing done by spells and effects by up to 22 and damage done by spells and effects by up to 8." } },
    },
    [2071] = {
        name = "Teachings of the Furbolgs",
        items = { 21326, 268873 },
        effects = { { count = 2, text = "Your attacks have a chance to increase your Attack Power by 40 and your healing spells have a chance to increase your Intellect by 20 for 15 sec." } },
    },
    [2072] = {
        name = "Champion's Investiture",
        items = { 272634, 272619, 272611, 272663, 272650, 272649 },
        effects = { { count = 2, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." }, { count = 4, text = "Increases the duration of your Psychic Scream spell by 1 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [2073] = {
        name = "Warlord's Investiture",
        items = { 273435, 273431, 273429, 273436, 273433, 273434 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Increases the duration of your Psychic Scream spell by 1 sec." }, { count = 6, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." } },
    },
    [2074] = {
        name = "Field Marshal's Investiture",
        items = { 273424, 273427, 273426, 273422, 273423, 273421 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Increases the duration of your Psychic Scream spell by 1 sec." }, { count = 6, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." } },
    },
    [2075] = {
        name = "Lieutenant Commander's Investiture",
        items = { 273448, 273445, 273443, 273447, 272678, 272677 },
        effects = { { count = 2, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." }, { count = 4, text = "Increases the duration of your Psychic Scream spell by 1 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [2076] = {
        name = "Warlord's Refuge",
        items = { 273419, 273418, 273416, 273413, 273415, 273414 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Increases your movement speed by 15% while in Bear, Cat, or Travel Form.  Only active outdoors." }, { count = 6, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." } },
    },
    [2077] = {
        name = "Field Marshal's Refuge",
        items = { 273399, 273404, 273401, 273403, 273400, 273402 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Increases your movement speed by 15% while in Bear, Cat, or Travel Form.  Only active outdoors." }, { count = 6, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." } },
    },
    [2078] = {
        name = "Field Marshal's Wildhide",
        items = { 273391, 273396, 273393, 273395, 273392, 273394 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Increases your movement speed by 15% while in Bear, Cat, or Travel Form.  Only active outdoors." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." } },
    },
    [2079] = {
        name = "Warlord's Wildhide",
        items = { 273411, 273410, 273408, 273405, 273407, 273406 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Increases your movement speed by 15% while in Bear, Cat, or Travel Form.  Only active outdoors." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." } },
    },
    [2080] = {
        name = "Champion's Wildhide",
        items = { 273382, 273383, 273385, 273384, 273387, 273386 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Increases your movement speed by 15% while in Bear, Cat, or Travel Form.  Only active outdoors." }, { count = 6, text = "+20 Stamina." } },
    },
    [2081] = {
        name = "Lieutenant Commander's Wildhide",
        items = { 273368, 273370, 272656, 273371, 272670, 272669 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Increases your movement speed by 15% while in Bear, Cat, or Travel Form.  Only active outdoors." }, { count = 6, text = "+20 Stamina." } },
    },
    [2082] = {
        name = "Champion's Aegis",
        items = { 274256, 274258, 274245, 274244, 274247, 274246 },
        effects = { { count = 2, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." }, { count = 4, text = "Reduces the cooldown of your Hammer of Justice by 10 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [2083] = {
        name = "Warlord's Aegis",
        items = { 274250, 274251, 274254, 274252, 274255, 274253 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Reduces the cooldown of your Hammer of Justice by 10 sec." }, { count = 6, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." } },
    },
    [2084] = {
        name = "Champion's Vindication",
        items = { 274227, 274226, 274232, 274230, 274233, 274231 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Reduces the cooldown of your Hammer of Justice by 10 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [2085] = {
        name = "Warlord's Vindication",
        items = { 274236, 274237, 274240, 274238, 274241, 274239 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Reduces the cooldown of your Hammer of Justice by 10 sec." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." } },
    },
    [2086] = {
        name = "Lieutenant Commander's Vindication",
        items = { 272719, 272718, 272744, 272742, 272745, 272743 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Reduces the cooldown of your Hammer of Justice by 10 sec." }, { count = 6, text = "+20 Stamina." } },
    },
    [2087] = {
        name = "Field Marshal's Vindication",
        items = { 272780, 272781, 272784, 272782, 272785, 272783 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Reduces the cooldown of your Hammer of Justice by 10 sec." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." } },
    },
    [2088] = {
        name = "Lieutenant Commander's Earthshaker",
        items = { 274177, 274192, 274180, 274194, 274181, 274196 },
        effects = { { count = 2, text = "+40 Attack Power." }, { count = 4, text = "Improves your chance to get a critical strike with all Shock spells by 2%." }, { count = 6, text = "+20 Stamina." } },
    },
    [2089] = {
        name = "Field Marshal's Earthshaker",
        items = { 274184, 274183, 274189, 274187, 274190, 274188 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with all Shock spells by 2%." }, { count = 6, text = "+40 Attack Power." } },
    },
    [2090] = {
        name = "Champion's Wartide",
        items = { 273358, 273355, 273359, 273357, 273360, 273356 },
        effects = { { count = 2, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." }, { count = 4, text = "Improves your chance to get a critical strike with all Shock spells by 2%." }, { count = 6, text = "+20 Stamina." } },
    },
    [2091] = {
        name = "Warlord's Wartide",
        items = { 273345, 273344, 273350, 273348, 273351, 273349 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with all Shock spells by 2%." }, { count = 6, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." } },
    },
    [2092] = {
        name = "Lieutenant Commander's Wartide",
        items = { 274220, 274217, 274221, 274219, 274222, 274218 },
        effects = { { count = 2, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." }, { count = 4, text = "Improves your chance to get a critical strike with all Shock spells by 2%." }, { count = 6, text = "+20 Stamina." } },
    },
    [2093] = {
        name = "Field Marshal's Wartide",
        items = { 274207, 274206, 274212, 274210, 274213, 274211 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with all Shock spells by 2%." }, { count = 6, text = "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects." } },
    },
    [2094] = {
        name = "Champion's Thunderfist",
        items = { 272617, 272484, 272636, 272487, 272648, 272486 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Improves your chance to get a critical strike with all Shock spells by 2%." }, { count = 6, text = "+20 Stamina." } },
    },
    [2095] = {
        name = "Warlord's Thunderfist",
        items = { 273337, 273336, 273342, 273340, 273343, 273341 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with all Shock spells by 2%." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." } },
    },
    [2096] = {
        name = "Lieutenant Commander's Thunderfist",
        items = { 274193, 274176, 274195, 274179, 274197, 274178 },
        effects = { { count = 2, text = "Increases damage and healing done by magical spells and effects by up to 23." }, { count = 4, text = "Improves your chance to get a critical strike with all Shock spells by 2%." }, { count = 6, text = "+20 Stamina." } },
    },
    [2097] = {
        name = "Field Marshal's Thunderfist",
        items = { 274199, 274198, 274204, 274202, 274205, 274203 },
        effects = { { count = 2, text = "+20 Stamina." }, { count = 3, text = "Improves your chance to get a critical strike with all Shock spells by 2%." }, { count = 6, text = "Increases damage and healing done by magical spells and effects by up to 23." } },
    },
}

-- Reverse lookup: item ID -> set ID
local itemToSet = {}
for setID, set in pairs(sets) do
    for _, itemID in ipairs(set.items) do itemToSet[itemID] = setID end
end

ns.SetData = { Sets = sets, ItemToSet = itemToSet }
