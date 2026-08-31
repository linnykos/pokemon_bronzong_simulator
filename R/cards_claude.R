# Card database for the Bronzong turn-1/turn-2 simulator.
#
# Every row is transcribed from the corresponding file in docs/cards/, which in
# turn records the primary source and verification date. Do not edit a value
# here without editing the card file too -- docs/cards/ is the source of truth
# and this table is only the machine-readable projection of it.
#
# Only the attributes that bear on the target event are modelled. Attacks other
# than the three that matter (Evolution Jammer, Run Around, Itchy Pollen) are
# omitted deliberately, as are Weakness and Resistance: nothing in the measured
# window reads them. See docs/03a_card_playbook.md.

#' Build the card database
#'
#' Returns the static table of every card appearing in any decklist in
#' `decklists/`, plus the imported candidate cards. One row per printing.
#'
#' Note that `MEE-005` and `SVE-005` are two printings of the same basic Psychic
#' Energy. Both appear here because decklists cite both, but
#' \code{canonical_card_id()} folds the former onto the latter, and every rule
#' in the simulator must operate on canonical ids.
#'
#' @returns A data frame with one row per printing and the columns:
#'   \describe{
#'     \item{card_id}{character, `"SET-NNN"`, zero-padded to three digits.}
#'     \item{name}{character, the printed name. Not unique: three different
#'       cards are named `"Bronzor"`.}
#'     \item{category}{character, one of `"pokemon"`, `"trainer"`, `"energy"`.}
#'     \item{subtype}{character. Trainers: `"item"`, `"supporter"`, `"stadium"`,
#'       `"tool"`. Energy: `"basic"`, `"special"`. Pokemon: `NA`.}
#'     \item{stage}{character, `"basic"`, `"stage1"`, `"stage2"`, or `NA`.}
#'     \item{evolves_from}{character, the printed "Evolves from" name, or `NA`.}
#'     \item{hp}{integer, or `NA` for non-Pokemon. Read by Buddy-Buddy Poffin.}
#'     \item{ptype}{character, the Pokemon's type, or `NA`. Read by Telepathic
#'       Psychic Energy's search and by its attach trigger.}
#'     \item{retreat}{integer retreat cost, or `NA`.}
#'     \item{has_ability}{logical. Salvatore may only fetch a card with no
#'       Abilities, so this is load-bearing, not decorative.}
#'     \item{has_rule_box}{logical. Poke Pad may only fetch a Pokemon without
#'       one.}
#'     \item{energy_provided}{character, `"P"`, `"C"`, `"D"`, or `""` for a
#'       non-Energy card. Only `"P"` pays Evolution Jammer. Enriching Energy is
#'       `"C"` and basic Darkness Energy is `"D"`, and **neither can pay it**,
#'       however much an Energy card in hand looks like sub-goal D solved.}
#'     \item{shuffles}{logical, whether resolving the card shuffles the deck.
#'       Read by the belief state to invalidate known deck ordering.}
#'   }
#' @export
build_card_database <- function(){
  card_df <- .card_rows()

  stopifnot(!anyDuplicated(card_df$card_id),
            all(card_df$category %in% c("pokemon", "trainer", "energy")),
            all(card_df$energy_provided %in% c("P", "C", "D", "")))

  # A Pokemon row must carry a stage, and only a Pokemon row may. The two
  # checks are separate because a typo in `category` would otherwise pass one.
  is_pokemon_vec <- card_df$category == "pokemon"
  stopifnot(all(!is.na(card_df$stage[is_pokemon_vec])),
            all(is.na(card_df$stage[!is_pokemon_vec])))

  card_df
}

#' Fold a printing onto its canonical card
#'
#' Two printings of one card are the same card for every game and
#' deck-construction purpose, so the policy should never have to know which one a
#' decklist happened to cite.
#'
#' Two aliases exist: basic Psychic Energy (`MEE-005` onto `SVE-005`) and
#' Buddy-Buddy Poffin (`MEG-167` onto `TEF-144`). **Dusclops PRE 36 / SFA 19 and
#' the four Bronzor printings are deliberately NOT aliased**: the Bronzor are
#' genuinely different cards (different HP and type, and therefore different
#' search legality), and the two Dusclops are kept separate only because nothing
#' in the simulator distinguishes them anyway -- every rule that reads them
#' matches on name.
#'
#' @param card_id_vec character vector of card ids.
#'
#' @returns A character vector of the same length, with alternate printings
#'   replaced by their canonical id.
#' @export
canonical_card_id <- function(card_id_vec){
  stopifnot(is.character(card_id_vec))

  alias_vec <- c("MEE-005" = "SVE-005", "MEG-167" = "TEF-144")
  idx_vec <- match(card_id_vec, names(alias_vec))
  card_id_vec[!is.na(idx_vec)] <- alias_vec[idx_vec[!is.na(idx_vec)]]

  card_id_vec
}

#' Look up card rows by id
#'
#' @param card_df the card database from \code{build_card_database()}.
#' @param card_id_vec character vector of card ids, canonical or not.
#'
#' @returns A data frame with one row per element of `card_id_vec`, in the same
#'   order. Errors rather than returning `NA` rows if any id is unknown, because
#'   a silent `NA` here propagates into every downstream rule as a false
#'   negative.
#' @export
lookup_card <- function(card_df, card_id_vec){
  stopifnot(is.data.frame(card_df), is.character(card_id_vec))

  canonical_vec <- canonical_card_id(card_id_vec)
  idx_vec <- match(canonical_vec, card_df$card_id)

  if(anyNA(idx_vec)){
    stop("unknown card id(s): ",
         paste0(unique(canonical_vec[is.na(idx_vec)]), collapse = ", "))
  }

  card_df[idx_vec, , drop = FALSE]
}

#' Is each card a Basic Pokemon?
#'
#' @param card_df the card database.
#' @param card_id_vec character vector of card ids.
#'
#' @returns A logical vector.
#' @export
is_basic_pokemon <- function(card_df, card_id_vec){
  row_df <- lookup_card(card_df, card_id_vec)

  row_df$category == "pokemon" & row_df$stage == "basic"
}

#' Does each card provide Psychic energy?
#'
#' The single most error-prone predicate in the project: Enriching Energy is an
#' Energy card that does NOT satisfy it, and treating all Energy as `[P]` would
#' silently overstate every decklist's consistency.
#'
#' @param card_df the card database.
#' @param card_id_vec character vector of card ids.
#'
#' @returns A logical vector.
#' @export
is_psychic_source <- function(card_df, card_id_vec){
  row_df <- lookup_card(card_df, card_id_vec)

  row_df$energy_provided == "P"
}

# ---------------------------------------------------------------------------
# The table itself.
# ---------------------------------------------------------------------------

#' The literal card rows
#'
#' Split out from \code{build_card_database()} so the validation there reads
#' separately from the data. Transcribed from docs/cards/.
#'
#' @returns A data frame; see \code{build_card_database()} for the columns.
#' @noRd
.card_rows <- function(){
  # Columns, in order: card_id, name, category, subtype, stage, evolves_from,
  # hp, ptype, retreat, has_ability, has_rule_box, energy_provided, shuffles
  row_list <- list(
    # -- Pokemon: the Bronzong line ----------------------------------------
    # Three distinct cards are named "Bronzor". TEF 68 is Psychic and 80 HP, so
    # Telepathic Psychic Energy can find it but Buddy-Buddy Poffin (<= 70 HP)
    # cannot; the two Metal printings are the reverse. See docs/02_cards.md.
    c("TEF-068", "Bronzor", "pokemon", NA, "basic", NA,
      "80", "psychic", "3", "FALSE", "FALSE", "", "FALSE"),
    c("PRE-066", "Bronzor", "pokemon", NA, "basic", NA,
      "70", "metal", "1", "FALSE", "FALSE", "", "FALSE"),
    c("SSP-126", "Bronzor", "pokemon", NA, "basic", NA,
      "60", "metal", "1", "FALSE", "FALSE", "", "FALSE"),
    # The fourth Bronzor, and the one that fetches worst: 80 HP puts it over
    # Poffin's cap AND it is Metal, so neither Poffin nor Telepathic can reach
    # it. decklist7 and decklist8 pair it with TEF 68, also 80 HP, so Poffin
    # cannot fetch a Bronzor at all in either list.
    c("PBL-063", "Bronzor", "pokemon", NA, "basic", NA,
      "80", "metal", "3", "FALSE", "FALSE", "", "FALSE"),
    # Evolution Jammer is an ATTACK costing [P], not an Ability. Bronzong having
    # no Ability is what makes it a legal Salvatore target.
    c("TEF-069", "Bronzong", "pokemon", NA, "stage1", "Bronzor",
      "110", "psychic", "3", "FALSE", "FALSE", "", "FALSE"),

    # -- Pokemon: the Dusknoir line ----------------------------------------
    c("PRE-035", "Duskull", "pokemon", NA, "basic", NA,
      "60", "psychic", "1", "FALSE", "FALSE", "", "FALSE"),
    c("PRE-036", "Dusclops", "pokemon", NA, "stage1", "Duskull",
      "90", "psychic", "2", "TRUE", "FALSE", "", "FALSE"),
    c("PRE-037", "Dusknoir", "pokemon", NA, "stage2", "Dusclops",
      "160", "psychic", "3", "TRUE", "FALSE", "", "FALSE"),
    # Identical to PRE 36 in every field, including Cursed Blast. Kept as its own
    # row rather than aliased because the two are separate printings the
    # decklists cite separately; every rule that matters matches on NAME, so the
    # section 4.3 rung-5 escape works from either.
    c("SFA-019", "Dusclops", "pokemon", NA, "stage1", "Duskull",
      "90", "psychic", "2", "TRUE", "FALSE", "", "FALSE"),

    # -- Pokemon: the Lopunny line and other Basics ------------------------
    c("PFL-083", "Buneary", "pokemon", NA, "basic", NA,
      "70", "colorless", "1", "FALSE", "FALSE", "", "FALSE"),
    c("PFL-084", "Mega Lopunny ex", "pokemon", NA, "stage1", "Buneary",
      "330", "colorless", "1", "FALSE", "TRUE", "", "FALSE"),
    # Mega Kangaskhan ex is a BASIC despite the name; no Kangaskhan is needed.
    c("MEG-104", "Mega Kangaskhan ex", "pokemon", NA, "basic", NA,
      "300", "colorless", "3", "TRUE", "TRUE", "", "FALSE"),
    c("POR-062", "Meowth ex", "pokemon", NA, "basic", NA,
      "170", "colorless", "1", "TRUE", "TRUE", "", "FALSE"),
    c("SSP-076", "Latias ex", "pokemon", NA, "basic", NA,
      "210", "psychic", "2", "TRUE", "TRUE", "", "FALSE"),
    c("TEF-078", "Flutter Mane", "pokemon", NA, "basic", NA,
      "90", "psychic", "1", "TRUE", "FALSE", "", "FALSE"),
    # Itchy Pollen is an attack, so Budew cannot use it on a first player's
    # turn 1. Budew itself has no Ability.
    c("ASC-016", "Budew", "pokemon", NA, "basic", NA,
      "30", "grass", "0", "FALSE", "FALSE", "", "FALSE"),
    # Adrena-Brain moves damage counters, which is inert for a metric that ends
    # on turn 2 -- but Munkidori is a Basic [P] Pokemon, so it IS a legal
    # Telepathic Psychic Energy search target and a want-list filler. At 110 HP
    # it is over Poffin's cap.
    c("TWM-095", "Munkidori", "pokemon", NA, "basic", NA,
      "110", "psychic", "1", "TRUE", "FALSE", "", "FALSE"),
    # Blissey ex evolves from CHANSEY, and no decklist runs one -- so in
    # decklist7 and decklist8 there is no legal way to put it into play at all.
    # A dead card in both, which is a decklist question rather than a policy one.
    c("TWM-134", "Blissey ex", "pokemon", NA, "stage1", "Chansey",
      "300", "colorless", "4", "TRUE", "TRUE", "", "FALSE"),
    # Trading Places is an ATTACK costing [C], not an Ability: pokemon.com and
    # Bulbapedia both say so and limitlesstcg is wrong, which is the third time
    # this project has caught that exact mis-rendering. So has_ability is FALSE,
    # and the switch is Run Around's shape rather than a free rung on the
    # section 4.3 ladder. At 70 HP it is a legal Poffin target.
    c("JTG-120", "Dunsparce", "pokemon", NA, "basic", NA,
      "70", "colorless", "1", "FALSE", "FALSE", "", "FALSE"),
    # Run Away Draw genuinely IS an Ability -- confirmed against a second source
    # because its own sibling above was mis-rendered the other way.
    c("TEF-129", "Dudunsparce", "pokemon", NA, "stage1", "Dunsparce",
      "140", "colorless", "3", "TRUE", "FALSE", "", "FALSE"),

    # -- Trainers: Supporters ----------------------------------------------
    c("MEG-119", "Lillie's Determination", "trainer", "supporter", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "TRUE"),
    c("WHT-084", "Hilda", "trainer", "supporter", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "TRUE"),
    c("TEF-145", "Ciphermaniac's Codebreaking", "trainer", "supporter", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "TRUE"),
    c("MEG-114", "Boss's Orders", "trainer", "supporter", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "FALSE"),
    c("TEF-160", "Salvatore", "trainer", "supporter", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "TRUE"),
    c("JTG-146", "Brock's Scouting", "trainer", "supporter", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "TRUE"),
    c("SSP-187", "Surfer", "trainer", "supporter", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "FALSE"),
    # Gwynn does NOT shuffle, which makes it the only draw Supporter that is safe
    # while a Ciphermaniac's stack is pending.
    c("PBL-078", "Gwynn", "trainer", "supporter", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "FALSE"),

    # -- Trainers: Items ---------------------------------------------------
    c("MEG-125", "Rare Candy", "trainer", "item", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "FALSE"),
    c("MEG-130", "Switch", "trainer", "item", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "FALSE"),
    c("MEG-131", "Ultra Ball", "trainer", "item", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "TRUE"),
    c("POR-081", "Poke Pad", "trainer", "item", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "TRUE"),
    c("TEF-144", "Buddy-Buddy Poffin", "trainer", "item", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "TRUE"),
    # The MEG reprint of the same card; canonical_card_id() folds it onto TEF 144
    # so every rule sees one card. Present as a row because decklist7 and
    # decklist8 cite this printing.
    c("MEG-167", "Buddy-Buddy Poffin", "trainer", "item", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "TRUE"),
    c("ASC-196", "Night Stretcher", "trainer", "item", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "FALSE"),
    c("CRI-082", "Special Red Card", "trainer", "item", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "FALSE"),
    c("BLK-084", "Pokegear 3.0", "trainer", "item", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "TRUE"),

    # -- Trainers: Stadiums ------------------------------------------------
    c("ASC-197", "Nighttime Mine", "trainer", "stadium", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "FALSE"),
    c("TWM-153", "Jamming Tower", "trainer", "stadium", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "FALSE"),
    c("TWM-149", "Festival Grounds", "trainer", "stadium", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "FALSE"),
    c("MEG-122", "Mystery Garden", "trainer", "stadium", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "FALSE"),
    # Risky Ruins damages OUR Bench as much as anyone's -- "any player" includes
    # this one, and every Basic these lists bench is non-[D]. Section 4.2 step 7
    # declines a Stadium that is disruptive to us, so it is never played.
    c("MEG-127", "Risky Ruins", "trainer", "stadium", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "", "FALSE"),

    # -- Energy ------------------------------------------------------------
    # SVE 5 and MEE 5 are the same card; canonical_card_id() folds MEE onto SVE.
    c("SVE-005", "Psychic Energy", "energy", "basic", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "P", "FALSE"),
    c("MEE-005", "Psychic Energy", "energy", "basic", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "P", "FALSE"),
    c("POR-088", "Telepathic Psychic Energy", "energy", "special", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "P", "TRUE"),
    # Enriching Energy provides [C]. It is NOT a [P] source and cannot pay for
    # Evolution Jammer, however much it looks like it should.
    c("SSP-191", "Enriching Energy", "energy", "special", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "C", "FALSE"),
    # Basic Darkness Energy provides [D], which pays a [C] cost but NOT the [P]
    # Evolution Jammer needs. decklist7 and decklist8 run it for Munkidori's
    # Adrena-Brain, an Ability that is inert for this metric -- so every copy is
    # a card that cannot advance sub-goal D.
    c("MEE-007", "Darkness Energy", "energy", "basic", NA, NA,
      NA, NA, NA, "FALSE", "FALSE", "D", "FALSE")
  )

  char_mat <- do.call(rbind, row_list)
  colnames(char_mat) <- c("card_id", "name", "category", "subtype", "stage",
                          "evolves_from", "hp", "ptype", "retreat",
                          "has_ability", "has_rule_box", "energy_provided",
                          "shuffles")

  data.frame(card_id = char_mat[, "card_id"],
             name = char_mat[, "name"],
             category = char_mat[, "category"],
             subtype = char_mat[, "subtype"],
             stage = char_mat[, "stage"],
             evolves_from = char_mat[, "evolves_from"],
             hp = as.integer(char_mat[, "hp"]),
             ptype = char_mat[, "ptype"],
             retreat = as.integer(char_mat[, "retreat"]),
             has_ability = as.logical(char_mat[, "has_ability"]),
             has_rule_box = as.logical(char_mat[, "has_rule_box"]),
             energy_provided = char_mat[, "energy_provided"],
             shuffles = as.logical(char_mat[, "shuffles"]),
             stringsAsFactors = FALSE)
}
