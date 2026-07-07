#!/usr/bin/env python3
"""Import permitted AED data into the app's offline SQLite database.

Input formats:
- CSV with latitude/longitude columns
- JSON array of records
- GeoJSON FeatureCollection with Point geometries

The importer is intentionally conservative about access codes. It only stores a
literal cabinet code when the input marks the code as public/permitted.
Otherwise it stores "Call emergency services for code" for locked cabinets.

Data-source policy:
- Do not scrape AED websites.
- Do not use restricted datasets unless written permission exists.
- Do not create an app/service from UK The Circuit/BHF public downloads without
  express written consent.
- OpenStreetMap emergency=defibrillator imports must preserve ODbL attribution
  and downstream share-alike obligations.
- Local-authority open data must permit app/database redistribution.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


SCHEMA = """
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;

DROP TABLE IF EXISTS metadata;
DROP TABLE IF EXISTS aed_records;

CREATE TABLE metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE aed_records (
    id TEXT PRIMARY KEY,
    source TEXT NOT NULL,
    source_record_id TEXT,
    source_updated_at TEXT,
    imported_at TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    name TEXT,
    address TEXT,
    location_description TEXT,
    indoor_location TEXT,
    access_type TEXT NOT NULL,
    opening_hours_raw TEXT,
    is_currently_likely_accessible INTEGER,
    access_instructions TEXT,
    cabinet_code_instruction TEXT,
    phone TEXT,
    last_verified_at TEXT,
    confidence TEXT NOT NULL,
    notes TEXT,
    attribution_text TEXT,
    licence_text TEXT
);

CREATE INDEX idx_aed_records_lat_lon ON aed_records(latitude, longitude);
CREATE INDEX idx_aed_records_lon_lat ON aed_records(longitude, latitude);
CREATE INDEX idx_aed_records_source ON aed_records(source);
"""


INSERT_SQL = """
INSERT INTO aed_records (
    id, source, source_record_id, source_updated_at, imported_at,
    latitude, longitude, name, address, location_description,
    indoor_location, access_type, opening_hours_raw,
    is_currently_likely_accessible, access_instructions,
    cabinet_code_instruction, phone, last_verified_at,
    confidence, notes, attribution_text, licence_text
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
"""


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def blank_to_none(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def truthy(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"1", "true", "yes", "y", "public", "permitted"}


def coalesce(properties: dict[str, Any], *keys: str) -> Any:
    for key in keys:
        if key in properties and blank_to_none(properties[key]) is not None:
            return properties[key]
    return None


def read_records(path: Path) -> list[dict[str, Any]]:
    suffix = path.suffix.lower()
    if suffix == ".csv":
        with path.open(newline="", encoding="utf-8-sig") as handle:
            return [dict(row) for row in csv.DictReader(handle)]

    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)

    if isinstance(data, list):
        return data

    if isinstance(data, dict) and data.get("type") == "FeatureCollection":
        records: list[dict[str, Any]] = []
        for feature in data.get("features", []):
            if not isinstance(feature, dict):
                continue
            geometry = feature.get("geometry") or {}
            properties = dict(feature.get("properties") or {})
            if geometry.get("type") == "Point":
                coordinates = geometry.get("coordinates") or []
                if len(coordinates) >= 2:
                    properties["longitude"] = coordinates[0]
                    properties["latitude"] = coordinates[1]
            records.append(properties)
        return records

    raise ValueError(f"Unsupported input format: {path}")


def normalize_access_type(properties: dict[str, Any]) -> str:
    raw = blank_to_none(coalesce(properties, "access_type", "accessType", "access", "defibrillator:access"))
    opening_hours = (blank_to_none(coalesce(properties, "opening_hours", "openingHoursRaw")) or "").lower()
    locked = truthy(coalesce(properties, "locked", "cabinet_locked", "defibrillator:locked"))

    if raw:
        normalized = raw.strip().lower().replace("-", "_").replace(" ", "_")
        mapping = {
            "public24h": "public24h",
            "public_24h": "public24h",
            "24_7": "public24h",
            "publiclimitedhours": "publicLimitedHours",
            "public_limited_hours": "publicLimitedHours",
            "limited": "publicLimitedHours",
            "restricted": "restricted",
            "private": "restricted",
            "customers": "restricted",
            "no": "restricted",
            "lockedcabinet": "lockedCabinet",
            "locked_cabinet": "lockedCabinet",
            "unknown": "unknown",
            "yes": "publicLimitedHours",
            "public": "publicLimitedHours",
            "permissive": "publicLimitedHours",
        }
        if normalized in mapping:
            return mapping[normalized]

    if locked:
        return "lockedCabinet"
    if "24/7" in opening_hours or "00:00-24:00" in opening_hours:
        return "public24h"
    return "unknown"


def infer_likely_accessible(access_type: str, properties: dict[str, Any]) -> int | None:
    explicit = coalesce(properties, "is_currently_likely_accessible", "isCurrentlyLikelyAccessible", "likely_accessible")
    if explicit is not None:
        return 1 if truthy(explicit) else 0
    if access_type == "public24h":
        return 1
    if access_type == "restricted":
        return 0
    return None


def normalize_confidence(properties: dict[str, Any]) -> str:
    raw = blank_to_none(coalesce(properties, "confidence", "source_confidence", "quality"))
    if raw and raw.lower() in {"high", "medium", "low", "unknown"}:
        return raw.lower()
    return "unknown"


def cabinet_instruction(properties: dict[str, Any], access_type: str) -> str | None:
    code = blank_to_none(coalesce(properties, "cabinet_code", "cabinetCode", "defibrillator:code"))
    public = truthy(coalesce(properties, "cabinet_code_public", "cabinetCodePublic", "code_public", "codePublic"))
    explicit_instruction = blank_to_none(coalesce(properties, "cabinet_code_instruction", "cabinetCodeInstruction"))

    if explicit_instruction:
        return explicit_instruction
    if code and public:
        return f"Cabinet code: {code}"
    if code or access_type == "lockedCabinet":
        return "Call emergency services for code"
    return None


def stable_id(source: str, source_record_id: str | None, latitude: float, longitude: float, name: str | None) -> str:
    key = "|".join([source, source_record_id or "", f"{latitude:.7f}", f"{longitude:.7f}", name or ""])
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:32]


def normalize_record(
    properties: dict[str, Any],
    *,
    source: str,
    imported_at: str,
    attribution: str,
    licence: str,
) -> tuple[Any, ...] | None:
    lat_value = coalesce(properties, "latitude", "lat", "y")
    lon_value = coalesce(properties, "longitude", "lon", "lng", "x")
    if lat_value is None or lon_value is None:
        return None

    latitude = float(lat_value)
    longitude = float(lon_value)
    if not (-90 <= latitude <= 90 and -180 <= longitude <= 180):
        return None

    source_record_id = blank_to_none(coalesce(properties, "source_record_id", "sourceRecordID", "id", "@id", "osm_id"))
    name = blank_to_none(coalesce(properties, "name", "operator", "site_name"))
    access_type = normalize_access_type(properties)
    row_id = blank_to_none(coalesce(properties, "id", "uuid")) or stable_id(source, source_record_id, latitude, longitude, name)

    return (
        row_id,
        source,
        source_record_id,
        blank_to_none(coalesce(properties, "source_updated_at", "sourceUpdatedAt", "updated_at", "timestamp")),
        imported_at,
        latitude,
        longitude,
        name,
        blank_to_none(coalesce(properties, "address", "addr:full", "addr:street")),
        blank_to_none(coalesce(properties, "location_description", "locationDescription", "defibrillator:location", "description")),
        blank_to_none(coalesce(properties, "indoor_location", "indoorLocation", "indoor")),
        access_type,
        blank_to_none(coalesce(properties, "opening_hours_raw", "openingHoursRaw", "opening_hours")),
        infer_likely_accessible(access_type, properties),
        blank_to_none(coalesce(properties, "access_instructions", "accessInstructions", "access:description")),
        cabinet_instruction(properties, access_type),
        blank_to_none(coalesce(properties, "phone", "contact:phone")),
        blank_to_none(coalesce(properties, "last_verified_at", "lastVerifiedAt", "check_date")),
        normalize_confidence(properties),
        blank_to_none(coalesce(properties, "notes", "note")),
        blank_to_none(coalesce(properties, "attribution_text", "attributionText")) or attribution,
        blank_to_none(coalesce(properties, "licence", "license", "licence_text", "license_text")) or licence,
    )


def synthetic_performance_records(count: int) -> Iterable[dict[str, Any]]:
    """Deterministic synthetic UK-wide records for offline performance testing."""
    for index in range(count):
        lat_offset = ((index * 37) % 8_800) / 1_000
        lon_offset = ((index * 91) % 8_100) / 1_000
        access = ["public24h", "publicLimitedHours", "unknown", "lockedCabinet", "restricted"][index % 5]
        yield {
            "id": f"synthetic-perf-{index:06d}",
            "source_record_id": f"synthetic-perf-{index:06d}",
            "source_updated_at": "2024-01-15T00:00:00Z",
            "latitude": 49.85 + lat_offset,
            "longitude": -6.30 + lon_offset,
            "name": f"Synthetic AED {index:06d}",
            "address": "Synthetic performance grid, UK",
            "location_description": "Synthetic record for offline database performance testing",
            "access_type": access,
            "opening_hours_raw": "24/7" if access == "public24h" else None,
            "access_instructions": "Synthetic record. Replace with permitted real AED data before field use.",
            "cabinet_code_instruction": "Call emergency services for code" if access == "lockedCabinet" else None,
            "last_verified_at": "2024-01-15T00:00:00Z",
            "confidence": "unknown",
            "notes": "Synthetic development seed; not a real AED location.",
        }


def write_database(
    rows: list[tuple[Any, ...]],
    *,
    output: Path,
    dataset_id: str,
    region_id: str,
    version: str,
    source: str,
    attribution: str,
    licence: str,
    imported_at: str,
    reliability: str,
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    connection = sqlite3.connect(output)
    try:
        connection.executescript(SCHEMA)
        connection.executemany(INSERT_SQL, rows)

        source_dates = [row[3] for row in rows if row[3]]
        metadata = {
            "dataset_id": dataset_id,
            "region_id": region_id,
            "version": version,
            "source": source,
            "source_name": source,
            "attribution": attribution,
            "licence": licence,
            "imported_at": imported_at,
            "record_count": str(len(rows)),
            "source_updated_at_min": min(source_dates) if source_dates else "",
            "source_updated_at_max": max(source_dates) if source_dates else "",
            "source_updated_at": max(source_dates) if source_dates else "",
            "reliability": reliability,
            "schema_version": "1",
        }
        connection.executemany("INSERT INTO metadata(key, value) VALUES (?, ?)", metadata.items())
        connection.execute("PRAGMA user_version=1")
        connection.commit()
        connection.execute("VACUUM")
    finally:
        connection.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Import AED records into a local SQLite database.")
    parser.add_argument("input", type=Path, help="CSV, JSON, or GeoJSON input file")
    parser.add_argument("--output", type=Path, required=True, help="Output SQLite database path")
    parser.add_argument("--dataset-id", required=True, help="Stable dataset identifier, e.g. osm-aed")
    parser.add_argument("--region-id", required=True, help="Stable region/city identifier, e.g. london")
    parser.add_argument("--version", required=True, help="Monotonic pack version, e.g. 2026.07.07")
    parser.add_argument("--source", required=True, help="Human-readable data source name")
    parser.add_argument("--attribution", required=True, help="Attribution stored with each record")
    parser.add_argument("--licence", required=True, help="Redistribution licence, e.g. ODbL-1.0 or OGL-3.0")
    parser.add_argument("--reliability", default="unknown", help="Source reliability note, e.g. high, medium, low, unknown")
    parser.add_argument(
        "--synthetic-performance-count",
        type=int,
        default=0,
        help="Add deterministic synthetic records for offline performance testing",
    )
    args = parser.parse_args()

    imported_at = utc_now()
    raw_records = read_records(args.input)
    if args.synthetic_performance_count:
        raw_records.extend(synthetic_performance_records(args.synthetic_performance_count))

    rows = [
        row
        for record in raw_records
        if (
            row := normalize_record(
                record,
                source=args.source,
                imported_at=imported_at,
                attribution=args.attribution,
                licence=args.licence,
            )
        )
    ]

    if not rows:
        raise SystemExit("No valid AED records were imported.")

    write_database(
        rows,
        output=args.output,
        dataset_id=args.dataset_id,
        region_id=args.region_id,
        version=args.version,
        source=args.source,
        attribution=args.attribution,
        licence=args.licence,
        imported_at=imported_at,
        reliability=args.reliability,
    )
    print(f"Imported {len(rows)} AED records into {args.output}")


if __name__ == "__main__":
    main()
