#!/usr/bin/env python3
"""Generate and verify Shared/Helpers/Preprocessing/BlueprintContract.lua from .vscode/schema.json."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SCHEMA_PATH = REPO_ROOT / ".vscode" / "schema.json"
DEFAULT_OUTPUT_PATH = (
    REPO_ROOT
    / "Mod Configuration Menu"
    / "Mods"
    / "BG3MCM"
    / "ScriptExtender"
    / "Lua"
    / "Shared"
    / "Helpers"
    / "Preprocessing"
    / "BlueprintContract.lua"
)

ALLOWED_OBJECT_KEYWORDS = {
    "type",
    "properties",
    "required",
    "additionalProperties",
    "markdownDescription",
    "description",
    "default",
    "examples",
    "$comment",
}

ALLOWED_NON_OPTION_OBJECT_KEYWORDS = ALLOWED_OBJECT_KEYWORDS | {
    "$schema",
    "allOf",
    "anyOf",
    "definitions",
}

ALLOWED_OPTION_LEAF_KEYWORDS = {
    "$ref",
    "type",
    "minimum",
    "maximum",
    "exclusiveMinimum",
    "exclusiveMaximum",
    "minItems",
    "maxItems",
    "minLength",
    "maxLength",
    "items",
    "default",
    "markdownDescription",
    "description",
    "properties",
    "required",
    "additionalProperties",
}

LUA_IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
LUA_KEYWORDS = {
    "and",
    "break",
    "do",
    "else",
    "elseif",
    "end",
    "false",
    "for",
    "function",
    "goto",
    "if",
    "in",
    "local",
    "nil",
    "not",
    "or",
    "repeat",
    "return",
    "then",
    "true",
    "until",
    "while",
}


class ContractError(Exception):
    """Raised when .vscode/schema.json violates contract extraction invariants."""


def resolve_ref(root: dict[str, Any], node: dict[str, Any]) -> dict[str, Any]:
    """Resolve local #/definitions/... references."""
    seen: set[str] = set()
    current = node
    while "$ref" in current:
        ref = current["$ref"]
        if not isinstance(ref, str) or not ref.startswith("#/definitions/"):
            raise ContractError(f"Unsupported $ref '{ref}'; only local #/definitions/... refs are supported.")
        if ref in seen:
            raise ContractError(f"Cyclic $ref detected: {ref}")
        seen.add(ref)
        def_name = ref[len("#/definitions/") :]
        definitions = root.get("definitions", {})
        if def_name not in definitions:
            raise ContractError(f"Missing definition '{def_name}' referenced by '{ref}'.")
        current = definitions[def_name]
    if not isinstance(current, dict):
        raise ContractError(f"Resolved schema node is not an object: {current!r}")
    return current


def check_keywords(node: dict[str, Any], allowed: set[str], context: str) -> None:
    unknown = set(node.keys()) - allowed
    if unknown:
        raise ContractError(f"Unrecognized keyword(s) {sorted(unknown)} in {context}.")


def extract_object_keys(
    root: dict[str, Any], node: dict[str, Any], context: str, require_closed: bool = True
) -> list[str]:
    if "$ref" in node and set(node.keys()) - {"$ref", "markdownDescription", "description"}:
        raise ContractError(f"Unsupported sibling keyword(s) next to $ref in {context}: {sorted(node.keys())}")
    resolved = resolve_ref(root, node)
    check_keywords(resolved, ALLOWED_NON_OPTION_OBJECT_KEYWORDS, context)
    if resolved.get("type") != "object":
        raise ContractError(f"Expected object schema for {context}.")
    if require_closed and resolved.get("additionalProperties") is not False:
        raise ContractError(f"{context} must set additionalProperties=false.")
    props = resolved.get("properties")
    if not isinstance(props, dict):
        raise ContractError(f"Expected object 'properties' for {context}.")
    return sorted(props.keys())


def extract_oneof_consts(node: dict[str, Any], context: str) -> list[str]:
    one_of = node.get("oneOf")
    if not isinstance(one_of, list) or not one_of:
        raise ContractError(f"Expected non-empty 'oneOf' array for {context}.")
    values: list[str] = []
    for entry in one_of:
        if not isinstance(entry, dict) or not isinstance(entry.get("const"), str):
            raise ContractError(f"Expected string 'const' in {context}.oneOf entry: {entry!r}")
        values.append(entry["const"])
    return sorted(set(values))


def extract_option_type(root: dict[str, Any], prop_schema: dict[str, Any], context: str) -> str:
    resolved = resolve_ref(root, prop_schema)
    check_keywords(resolved, ALLOWED_OPTION_LEAF_KEYWORDS, context)
    schema_type = resolved.get("type")
    if isinstance(schema_type, list):
        if len(schema_type) == 1 and isinstance(schema_type[0], str):
            schema_type = schema_type[0]
        else:
            raise ContractError(f"Unsupported multi-type {schema_type!r} in {context}.")
    if not isinstance(schema_type, str):
        raise ContractError(f"Missing string 'type' in {context}.")
    return schema_type


def extract_contract(schema: dict[str, Any]) -> dict[str, Any]:
    definitions = schema.get("definitions")
    if not isinstance(definitions, dict):
        raise ContractError("Schema missing top-level 'definitions' object.")

    for required_def in (
        "Tab",
        "Section",
        "Setting",
        "TopLevelHandles",
        "TabHandles",
        "SectionHandles",
        "SettingHandles",
        "VisibilityCondition",
        "Condition",
        "EventButtonOptions",
    ):
        if required_def not in definitions:
            raise ContractError(f"Missing required definition '{required_def}'.")

    setting_def = definitions["Setting"]
    setting_props = setting_def.get("properties", {})
    setting_types = extract_oneof_consts(setting_props.get("Type", {}), "Setting.properties.Type")

    condition_def = definitions["Condition"]
    condition_props = condition_def.get("properties", {})
    visible_if_operators = extract_oneof_consts(
        condition_props.get("Operator", {}), "Condition.properties.Operator"
    )

    setting_all_of = setting_def.get("allOf")
    if not isinstance(setting_all_of, list):
        raise ContractError("Setting.allOf must be an array.")

    branches_by_type: dict[str, dict[str, Any]] = {}
    for branch in setting_all_of:
        if not isinstance(branch, dict):
            continue
        check_keywords(branch, {"if", "then", "else"}, "Setting.allOf branch")
        if_clause = branch.get("if")
        then_clause = branch.get("then")
        if not isinstance(if_clause, dict) or not isinstance(then_clause, dict):
            raise ContractError(f"Setting.allOf branch must have 'if' and 'then' objects: {branch!r}")
        check_keywords(if_clause, {"properties", "required"}, "Setting.allOf 'if' clause")
        if_required = if_clause.get("required")
        if not isinstance(if_required, list) or "Type" not in if_required:
            raise ContractError(f"Setting.allOf 'if' branch must require 'Type': {if_clause!r}")
        if_props = if_clause.get("properties", {})
        if not isinstance(if_props, dict) or set(if_props.keys()) != {"Type"}:
            raise ContractError(f"Setting.allOf 'if' properties must contain only 'Type': {if_clause!r}")
        type_node = if_props["Type"]
        if not isinstance(type_node, dict) or set(type_node.keys()) != {"const"}:
            raise ContractError(f"Setting.allOf 'if.properties.Type' must contain only 'const': {if_clause!r}")
        type_const = type_node["const"]
        if not isinstance(type_const, str):
            raise ContractError(f"Setting.allOf 'if' branch must specify string Type.const: {if_clause!r}")
        check_keywords(then_clause, {"properties", "required"}, f"Setting.allOf 'then' for '{type_const}'")
        if type_const in branches_by_type:
            raise ContractError(f"Duplicate Setting.allOf branch for Type '{type_const}'.")
        branches_by_type[type_const] = then_clause

    missing_types = sorted(set(setting_types) - set(branches_by_type.keys()))
    if missing_types:
        raise ContractError(f"Setting.Type value(s) missing Setting.allOf branch: {missing_types}")
    extra_types = sorted(set(branches_by_type.keys()) - set(setting_types))
    if extra_types:
        raise ContractError(f"Setting.allOf branch(es) for unknown Setting.Type: {extra_types}")

    options_by_type: dict[str, list[str]] = {}
    required_options_by_type: dict[str, list[str]] = {}
    option_types_by_type: dict[str, dict[str, str]] = {}

    for setting_type in setting_types:
        then_clause = branches_by_type[setting_type]
        options_node = then_clause.get("properties", {}).get("Options")
        if not isinstance(options_node, dict):
            raise ContractError(f"Setting.allOf branch for '{setting_type}' missing properties.Options.")
        if "$ref" in options_node and set(options_node.keys()) != {"$ref"}:
            raise ContractError(
                f"Setting.allOf Options for '{setting_type}' has unsupported sibling keyword(s) next to $ref: "
                f"{sorted(options_node.keys())}"
            )
        resolved_opts = resolve_ref(schema, options_node)
        check_keywords(resolved_opts, ALLOWED_OBJECT_KEYWORDS, f"Options for '{setting_type}'")
        if resolved_opts.get("type") != "object":
            raise ContractError(f"Options for '{setting_type}' must have type='object'.")
        if resolved_opts.get("additionalProperties") is not False:
            raise ContractError(f"Options for '{setting_type}' must set additionalProperties=false.")

        opt_props = resolved_opts.get("properties", {})
        if not isinstance(opt_props, dict):
            raise ContractError(f"Options.properties for '{setting_type}' must be an object.")

        options_by_type[setting_type] = sorted(opt_props.keys())
        opt_types: dict[str, str] = {}
        for opt_key in sorted(opt_props.keys()):
            opt_types[opt_key] = extract_option_type(
                schema, opt_props[opt_key], f"Options.{opt_key} for '{setting_type}'"
            )
        option_types_by_type[setting_type] = opt_types

        req_opts = resolved_opts.get("required", [])
        if not isinstance(req_opts, list) or any(not isinstance(k, str) for k in req_opts):
            raise ContractError(f"Options.required for '{setting_type}' must be a string array.")
        if req_opts:
            required_options_by_type[setting_type] = sorted(req_opts)

    section_def = definitions["Section"]
    section_options = section_def.get("properties", {}).get("Options")
    if not isinstance(section_options, dict):
        raise ContractError("Section.properties.Options is missing.")

    setting_handles_props = definitions["SettingHandles"].get("properties", {})
    eb_handles = setting_handles_props.get("EventButtonHandles")
    if not isinstance(eb_handles, dict):
        raise ContractError("SettingHandles.properties.EventButtonHandles is missing.")
    confirm_handles = eb_handles.get("properties", {}).get("ConfirmDialogHandles")
    if not isinstance(confirm_handles, dict):
        raise ContractError("EventButtonHandles.properties.ConfirmDialogHandles is missing.")

    eb_opts_props = definitions["EventButtonOptions"].get("properties", {})
    confirm_dialog = eb_opts_props.get("ConfirmDialog")
    icon_def = eb_opts_props.get("Icon")
    if not isinstance(confirm_dialog, dict) or not isinstance(icon_def, dict):
        raise ContractError("EventButtonOptions.ConfirmDialog or EventButtonOptions.Icon is missing.")
    icon_size = icon_def.get("properties", {}).get("Size")
    if not isinstance(icon_size, dict):
        raise ContractError("EventButtonOptions.Icon.Size is missing.")

    allowed_keys = {
        "Root": extract_object_keys(schema, schema, "Root"),
        "Tab": extract_object_keys(schema, definitions["Tab"], "Tab"),
        "Section": extract_object_keys(schema, section_def, "Section"),
        "SectionOptions": extract_object_keys(schema, section_options, "SectionOptions"),
        "Setting": extract_object_keys(schema, setting_def, "Setting"),
        "TopLevelHandles": extract_object_keys(schema, definitions["TopLevelHandles"], "TopLevelHandles"),
        "TabHandles": extract_object_keys(schema, definitions["TabHandles"], "TabHandles"),
        "SectionHandles": extract_object_keys(schema, definitions["SectionHandles"], "SectionHandles"),
        "SettingHandles": extract_object_keys(schema, definitions["SettingHandles"], "SettingHandles"),
        "EventButtonHandles": extract_object_keys(schema, eb_handles, "EventButtonHandles"),
        "ConfirmDialogHandles": extract_object_keys(schema, confirm_handles, "ConfirmDialogHandles"),
        "VisibleIf": extract_object_keys(schema, definitions["VisibilityCondition"], "VisibleIf"),
        "VisibleIfCondition": extract_object_keys(schema, condition_def, "VisibleIfCondition"),
        "ConfirmDialog": extract_object_keys(schema, confirm_dialog, "ConfirmDialog"),
        "Icon": extract_object_keys(schema, icon_def, "Icon"),
        "IconSize": extract_object_keys(schema, icon_size, "IconSize"),
        "OptionsByType": options_by_type,
    }

    return {
        "SettingTypes": setting_types,
        "VisibleIfOperators": visible_if_operators,
        "AllowedKeys": allowed_keys,
        "RequiredOptionsByType": required_options_by_type,
        "OptionTypesByType": option_types_by_type,
    }


def lua_key(key: str) -> str:
    if LUA_IDENT_RE.match(key) and key not in LUA_KEYWORDS:
        return key
    return f"[{json.dumps(key)}]"


def format_lua_set(keys: list[str], indent: int) -> list[str]:
    if not keys:
        return ["{}"]
    pad = " " * indent
    lines = ["{"]
    for key in keys:
        lines.append(f"{pad}{lua_key(key)} = true,")
    lines.append(" " * (indent - 4) + "}")
    return lines


def format_lua_string_array(items: list[str], indent: int) -> list[str]:
    if not items:
        return ["{}"]
    pad = " " * indent
    lines = ["{"]
    for item in items:
        lines.append(f"{pad}{json.dumps(item)},")
    lines.append(" " * (indent - 4) + "}")
    return lines


def render_lua(contract: dict[str, Any]) -> str:
    lines: list[str] = [
        "-- AUTO-GENERATED by scripts/sync_blueprint_contract.py from .vscode/schema.json. Do not edit by hand.",
        "",
        "---@class BlueprintContract",
        "BlueprintContract = {",
    ]

    lines.append("    SettingTypes = " + format_lua_set(contract["SettingTypes"], 8)[0])
    lines.extend(format_lua_set(contract["SettingTypes"], 8)[1:-1])
    lines.append("    },")

    lines.append("    VisibleIfOperators = " + format_lua_set(contract["VisibleIfOperators"], 8)[0])
    lines.extend(format_lua_set(contract["VisibleIfOperators"], 8)[1:-1])
    lines.append("    },")

    lines.append("    AllowedKeys = {")
    allowed = contract["AllowedKeys"]
    for scope in sorted(k for k in allowed.keys() if k != "OptionsByType"):
        set_lines = format_lua_set(allowed[scope], 12)
        if len(set_lines) == 1:
            lines.append(f"        {lua_key(scope)} = {set_lines[0]},")
        else:
            lines.append(f"        {lua_key(scope)} = {set_lines[0]}")
            lines.extend(set_lines[1:-1])
            lines.append("        },")

    lines.append("        OptionsByType = {")
    for setting_type in sorted(allowed["OptionsByType"].keys()):
        set_lines = format_lua_set(allowed["OptionsByType"][setting_type], 16)
        if len(set_lines) == 1:
            lines.append(f"            {lua_key(setting_type)} = {set_lines[0]},")
        else:
            lines.append(f"            {lua_key(setting_type)} = {set_lines[0]}")
            lines.extend(set_lines[1:-1])
            lines.append("            },")
    lines.append("        },")
    lines.append("    },")

    lines.append("    RequiredOptionsByType = {")
    for setting_type in sorted(contract["RequiredOptionsByType"].keys()):
        arr_lines = format_lua_string_array(contract["RequiredOptionsByType"][setting_type], 12)
        lines.append(f"        {lua_key(setting_type)} = {arr_lines[0]}")
        lines.extend(arr_lines[1:-1])
        lines.append("        },")
    lines.append("    },")

    lines.append("    OptionTypesByType = {")
    for setting_type in sorted(contract["OptionTypesByType"].keys()):
        opt_map = contract["OptionTypesByType"][setting_type]
        if not opt_map:
            lines.append(f"        {lua_key(setting_type)} = {{}},")
        else:
            lines.append(f"        {lua_key(setting_type)} = {{")
            for opt_key in sorted(opt_map.keys()):
                lines.append(f"            {lua_key(opt_key)} = {json.dumps(opt_map[opt_key])},")
            lines.append("        },")
    lines.append("    },")

    lines.extend(["}", "", "return BlueprintContract", ""])
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA_PATH, help="Path to .vscode/schema.json")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_PATH, help="Path to BlueprintContract.lua")
    parser.add_argument("--check", action="store_true", help="Verify BlueprintContract.lua is up to date")
    args = parser.parse_args(argv)

    try:
        schema = json.loads(args.schema.read_text(encoding="utf-8"))
        contract = extract_contract(schema)
        rendered = render_lua(contract)
    except (OSError, json.JSONDecodeError, ContractError) as exc:
        print(f"sync_blueprint_contract: error: {exc}", file=sys.stderr)
        return 1

    if args.check:
        if not args.output.exists():
            print(f"sync_blueprint_contract: missing generated file: {args.output}", file=sys.stderr)
            return 1
        existing = args.output.read_bytes().decode("utf-8").replace("\r\n", "\n")
        if existing != rendered:
            print(
                f"sync_blueprint_contract: {args.output} is out of date. Run: python scripts/sync_blueprint_contract.py",
                file=sys.stderr,
            )
            return 1
        return 0

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(rendered.encode("utf-8"))
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
