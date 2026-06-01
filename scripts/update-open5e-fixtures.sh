#!/usr/bin/env bash

set -euo pipefail

API_BASE="${OPEN5E_API_BASE:-https://api.open5e.com/v2}"
DOCUMENT_KEY="${OPEN5E_DOCUMENT_KEY:-}"
LIMIT="${OPEN5E_PAGE_LIMIT:-500}"
V1_API_BASE="${OPEN5E_V1_API_BASE:-https://api.open5e.com/v1}"
V1_DOCUMENT_SLUG="${OPEN5E_V1_DOCUMENT_SLUG:-wotc-srd}"
V1_AUGMENT="${OPEN5E_V1_AUGMENT:-auto}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MONSTERS_OUTPUT="${OPEN5E_MONSTERS_OUTPUT:-}"
SPELLS_OUTPUT="${OPEN5E_SPELLS_OUTPUT:-}"

require_tool() {
  local tool="$1"
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing required tool: ${tool}" >&2
    exit 1
  fi
}

fetch_all_results() {
  local url="$1"
  local all_file
  local next_file
  all_file="$(mktemp)"
  next_file="$(mktemp)"
  printf '[]\n' > "${all_file}"

  while [[ -n "${url}" && "${url}" != "null" ]]; do
    local page
    if ! page="$(curl -fsSL -H 'accept: application/json' "${url}")"; then
      echo "Failed to fetch ${url}" >&2
      rm -f "${all_file}" "${next_file}"
      return 1
    fi

    local page_results
    page_results="$(printf '%s' "${page}" | jq -c '.results')"

    jq -cs '.[0] + .[1]' "${all_file}" <(printf '%s\n' "${page_results}") > "${next_file}"
    mv "${next_file}" "${all_file}"
    url="$(printf '%s' "${page}" | jq -r '.next // empty')"
  done

  cat "${all_file}"
  rm -f "${all_file}" "${next_file}"
}

filter_monsters() {
  jq '
    map({
      name,
      size: (
        if (.size | type) == "object" then { name: .size.name }
        else .size
        end
      ),
      type: (
        if (.type | type) == "object" then { name: .type.name }
        else .type
        end
      ),
      subcategory,
      alignment,
      armor_class,
      armor_detail,
      hit_points,
      hit_dice,
      speed: ((.speed // {}) | {
        walk,
        swim,
        fly,
        burrow,
        climb,
        hover
      }),
      ability_scores,
      saving_throws,
      skill_bonuses,
      resistances_and_immunities: {
        damage_vulnerabilities_display: (.resistances_and_immunities.damage_vulnerabilities_display // ""),
        damage_resistances_display: (.resistances_and_immunities.damage_resistances_display // ""),
        damage_immunities_display: (.resistances_and_immunities.damage_immunities_display // ""),
        condition_immunities_display: (.resistances_and_immunities.condition_immunities_display // "")
      },
      passive_perception,
      normal_sight_range,
      darkvision_range,
      blindsight_range,
      tremorsense_range,
      truesight_range,
      languages: (
        if (.languages | type) == "object" then { as_string: .languages.as_string }
        else .languages
        end
      ),
      challenge_rating,
      traits: ((.traits // []) | map({
        name,
        desc,
        attack_bonus,
        damage_dice,
        damage_bonus
      })),
      actions: ((.actions // []) | map({
        name,
        desc,
        action_type,
        order_in_statblock,
        legendary_action_cost,
        limited_to_form,
        usage_limits
      })),
      group
    })
    | sort_by(.name)
  '
}

enrich_monsters_with_v1_usage_limits() {
  local v2_file="$1"
  local v1_file="$2"

  jq -n --slurpfile v2 "${v2_file}" --slurpfile v1 "${v1_file}" '
    def normalize_space:
      gsub("\\s+"; " ")
      | gsub("^\\s+|\\s+$"; "");

    def normalize_name:
      ascii_downcase
      | normalize_space;

    def base_action_name:
      gsub("\\s*\\([^)]*\\)\\s*$"; "")
      | normalize_name;

    def usage_from_v1_action_name:
      if test("\\(Recharge (?<roll>[0-9])(?:-6)?\\)$") then
        { type: "RECHARGE_ON_ROLL", param: (capture("\\(Recharge (?<roll>[0-9])(?:-6)?\\)$").roll | tonumber) }
      elif test("\\(Recharges after a Short or Long Rest\\)$") then
        { type: "RECHARGE_AFTER_REST" }
      elif test("\\((?<uses>[0-9]+)/day\\)$") then
        { type: "PER_DAY", param: (capture("\\((?<uses>[0-9]+)/day\\)$").uses | tonumber) }
      else
        null
      end;

    def v1_actions_for_monster($monster_name):
      ($v1[0] | map(select((.name // "" | normalize_name) == ($monster_name | normalize_name))) | first) as $monster
      | if $monster == null then
          []
        else
          (($monster.actions // []) + ($monster.reactions // []) + ($monster.legendary_actions // []))
          | map({
              name: (.name // ""),
              desc: (.desc // ""),
              usage: ((.name // "") | usage_from_v1_action_name)
            })
        end;

    def usage_for_action($monster_name; $action):
      (v1_actions_for_monster($monster_name)
        | map(select(.usage != null))
        | map(select(
            ((.desc | normalize_space) == (($action.desc // "") | normalize_space))
            or
            ((.name | base_action_name) == (($action.name // "") | base_action_name))
          ))
        | first
        | .usage);

    $v2[0]
    | map(
        . as $monster
        | .actions = ((.actions // []) | map(
            . as $action
            | if $action.usage_limits != null then
                .
              else
                .usage_limits = usage_for_action($monster.name; $action)
              end
          ))
      )
  '
}

filter_spells() {
  jq '
    map({
      name,
      desc,
      higher_level,
      range_text,
      range,
      verbal,
      somatic,
      material,
      material_specified,
      ritual,
      duration,
      concentration,
      casting_time,
      reaction_condition,
      level,
      school: (
        if (.school | type) == "object" then { name: .school.name }
        else .school
        end
      ),
      classes: ((.classes // []) | map({ name }))
    })
    | sort_by(.name)
  '
}

should_augment_v1_usage_limits() {
  local document_key="$1"

  case "${V1_AUGMENT}" in
  auto)
    [[ "${document_key}" == "srd-2014" ]]
    ;;
  true | TRUE | 1 | yes | YES)
    return 0
    ;;
  false | FALSE | 0 | no | NO)
    return 1
    ;;
  *)
    echo "Invalid OPEN5E_V1_AUGMENT value: ${V1_AUGMENT} (expected auto|true|false)" >&2
    exit 1
    ;;
  esac
}

default_output() {
  local type="$1"
  local document_key="$2"
  local edition="${document_key#srd-}"

  printf '%s\n' "${REPO_ROOT}/Sources/Compendium/Fixtures/${type}-${edition}.json"
}

update_fixtures() {
  local document_key="$1"
  local monsters_output="$2"
  local spells_output="$3"

  local monsters_url="${API_BASE}/creatures/?document__key=${document_key}&limit=${LIMIT}"
  local spells_url="${API_BASE}/spells/?document__key=${document_key}&limit=${LIMIT}"

  local raw_monsters
  local raw_spells
  raw_monsters="$(fetch_all_results "${monsters_url}")"
  raw_spells="$(fetch_all_results "${spells_url}")"

  if should_augment_v1_usage_limits "${document_key}"; then
    local v1_monsters_url="${V1_API_BASE}/monsters/?document__slug=${V1_DOCUMENT_SLUG}&limit=${LIMIT}"
    local raw_v1_monsters
    local v2_raw_file
    local v1_raw_file
    local merged_raw_file

    raw_v1_monsters="$(fetch_all_results "${v1_monsters_url}")"
    v2_raw_file="$(mktemp)"
    v1_raw_file="$(mktemp)"
    merged_raw_file="$(mktemp)"

    printf '%s\n' "${raw_monsters}" > "${v2_raw_file}"
    printf '%s\n' "${raw_v1_monsters}" > "${v1_raw_file}"

    enrich_monsters_with_v1_usage_limits "${v2_raw_file}" "${v1_raw_file}" > "${merged_raw_file}"
    filter_monsters < "${merged_raw_file}" > "${monsters_output}"
    rm -f "${v2_raw_file}" "${v1_raw_file}" "${merged_raw_file}"
  else
    printf '%s\n' "${raw_monsters}" | filter_monsters > "${monsters_output}"
  fi

  printf '%s\n' "${raw_spells}" | filter_spells > "${spells_output}"

  local monster_count
  local spell_count
  monster_count="$(jq 'length' "${monsters_output}")"
  spell_count="$(jq 'length' "${spells_output}")"

  echo "Updated ${document_key} fixtures:"
  echo "  monsters: ${monster_count} -> ${monsters_output}"
  echo "  spells:   ${spell_count} -> ${spells_output}"
}

main() {
  require_tool curl
  require_tool jq

  if [[ -n "${DOCUMENT_KEY}" ]]; then
    update_fixtures \
      "${DOCUMENT_KEY}" \
      "${MONSTERS_OUTPUT:-$(default_output monsters "${DOCUMENT_KEY}")}" \
      "${SPELLS_OUTPUT:-$(default_output spells "${DOCUMENT_KEY}")}"
    return
  fi

  if [[ -n "${MONSTERS_OUTPUT}" || -n "${SPELLS_OUTPUT}" ]]; then
    echo "OPEN5E_DOCUMENT_KEY is required when overriding fixture output paths." >&2
    exit 1
  fi

  update_fixtures \
    "srd-2014" \
    "$(default_output monsters srd-2014)" \
    "$(default_output spells srd-2014)"
  update_fixtures \
    "srd-2024" \
    "$(default_output monsters srd-2024)" \
    "$(default_output spells srd-2024)"
}

main "$@"
