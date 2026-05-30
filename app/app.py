#!/usr/bin/env python3
import argparse
import html
import json
import os
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


APP_ROOT = Path(__file__).resolve().parent
DATA_DIR = APP_ROOT / "data"


def load_json(name, fallback):
    path = DATA_DIR / name
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        return fallback


def utc_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")


def status_class(value):
    normalized = str(value).lower()
    if normalized in {"delayed", "at risk", "maintenance"}:
        return "warn"
    if normalized in {"critical", "customs hold"}:
        return "bad"
    return "ok"


def esc(value):
    return html.escape(str(value), quote=True)


def render_rows(items, columns):
    rows = []
    for item in items:
        cells = []
        for key, label in columns:
            value = item.get(key, "")
            if key in {"status", "risk"}:
                cells.append(f'<td><span class="pill {status_class(value)}">{esc(value)}</span></td>')
            else:
                cells.append(f"<td>{esc(value)}</td>")
        rows.append("<tr>" + "".join(cells) + "</tr>")
    headers = "".join(f"<th>{esc(label)}</th>" for _, label in columns)
    return f"<table><thead><tr>{headers}</tr></thead><tbody>{''.join(rows)}</tbody></table>"


def build_model(shipment_filter=""):
    vehicles = load_json("vehicles.json", [])
    shipments = load_json("shipments.json", [])
    warehouses = load_json("warehouses.json", [])
    latest_gps = load_json("latest_gps.json", [])

    if shipment_filter:
        shipments = [
            shipment
            for shipment in shipments
            if shipment_filter.lower() in shipment.get("shipment_id", "").lower()
            or shipment_filter.lower() in shipment.get("customer", "").lower()
        ]

    active = sum(1 for vehicle in vehicles if vehicle.get("status") == "in_transit")
    delayed = sum(1 for shipment in shipments if shipment.get("status") == "delayed")
    customs_hold = sum(1 for shipment in shipments if shipment.get("risk") == "customs hold")

    return {
        "vehicles": vehicles,
        "shipments": shipments,
        "warehouses": warehouses,
        "latest_gps": latest_gps,
        "active": active,
        "delayed": delayed,
        "customs_hold": customs_hold,
    }


def render_dashboard(query):
    model = build_model(query.get("q", [""])[0].strip())
    vehicle_rows = render_rows(
        model["vehicles"],
        [
            ("vehicle_id", "Truck"),
            ("plate", "Plate"),
            ("driver", "Driver"),
            ("route", "Route"),
            ("status", "Status"),
            ("fuel_efficiency_l_100km", "L/100km"),
        ],
    )
    shipment_rows = render_rows(
        model["shipments"],
        [
            ("shipment_id", "Shipment"),
            ("customer", "Customer"),
            ("origin", "Origin"),
            ("destination", "Destination"),
            ("eta", "ETA"),
            ("status", "Status"),
            ("risk", "Risk"),
        ],
    )
    warehouse_rows = render_rows(
        model["warehouses"],
        [
            ("warehouse_id", "Warehouse"),
            ("city", "City"),
            ("utilization_percent", "Utilization"),
            ("open_orders", "Open Orders"),
            ("sync_status", "Sync"),
        ],
    )
    gps_rows = render_rows(
        model["latest_gps"],
        [
            ("vehicle_id", "Truck"),
            ("timestamp_iso", "Timestamp"),
            ("latitude", "Latitude"),
            ("longitude", "Longitude"),
            ("speed_kph", "Speed"),
            ("shipment_id", "Shipment"),
        ],
    )

    search_value = esc(query.get("q", [""])[0])
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Fleet Operations Portal</title>
  <style>
    :root {{
      color-scheme: light;
      --ink: #172033;
      --muted: #5c667a;
      --line: #d9dfeb;
      --panel: #ffffff;
      --soft: #eef3f8;
      --blue: #1f5eff;
      --green: #147a46;
      --amber: #9a5b00;
      --red: #b42318;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: Arial, Helvetica, sans-serif;
      background: #f5f7fb;
      color: var(--ink);
    }}
    header {{
      background: #18243a;
      color: #fff;
      padding: 22px 28px;
    }}
    header h1 {{ margin: 0; font-size: 24px; letter-spacing: 0; }}
    header p {{ margin: 6px 0 0; color: #cbd6ea; }}
    main {{ max-width: 1180px; margin: 0 auto; padding: 24px; }}
    .summary {{
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 14px;
      margin-bottom: 22px;
    }}
    .metric, section {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
    }}
    .metric {{ padding: 16px; }}
    .metric span {{ display: block; color: var(--muted); font-size: 13px; }}
    .metric strong {{ display: block; margin-top: 8px; font-size: 28px; }}
    section {{ margin-top: 18px; overflow: hidden; }}
    section h2 {{
      margin: 0;
      padding: 14px 16px;
      font-size: 17px;
      background: var(--soft);
      border-bottom: 1px solid var(--line);
    }}
    table {{ width: 100%; border-collapse: collapse; }}
    th, td {{
      padding: 11px 12px;
      border-bottom: 1px solid var(--line);
      text-align: left;
      font-size: 14px;
      vertical-align: top;
    }}
    th {{ color: var(--muted); font-size: 12px; text-transform: uppercase; }}
    tr:last-child td {{ border-bottom: 0; }}
    .pill {{
      display: inline-block;
      min-width: 76px;
      padding: 4px 8px;
      border-radius: 999px;
      font-size: 12px;
      text-align: center;
      background: #e7f6ef;
      color: var(--green);
    }}
    .pill.warn {{ background: #fff1d6; color: var(--amber); }}
    .pill.bad {{ background: #ffe8e5; color: var(--red); }}
    form {{
      display: flex;
      gap: 8px;
      margin: 0 0 18px;
    }}
    input, button {{
      height: 40px;
      border-radius: 6px;
      border: 1px solid var(--line);
      font-size: 14px;
    }}
    input {{ flex: 1; padding: 0 12px; }}
    button {{
      padding: 0 14px;
      background: var(--blue);
      color: white;
      border-color: var(--blue);
      cursor: pointer;
    }}
    footer {{ margin-top: 24px; color: var(--muted); font-size: 13px; }}
    @media (max-width: 760px) {{
      main {{ padding: 14px; }}
      .summary {{ grid-template-columns: repeat(2, minmax(0, 1fr)); }}
      table {{ display: block; overflow-x: auto; }}
      form {{ flex-direction: column; }}
    }}
  </style>
</head>
<body>
  <header>
    <h1>Fleet Operations Portal</h1>
    <p>Includes data of: shipments, vehicles, warehouses, and latest GPS telemetry.</p>
  </header>
  <main>
    <form method="get" action="/">
      <input name="q" value="{search_value}" placeholder="Search shipment ID or customer">
      <button type="submit">Search</button>
    </form>
    <div class="summary">
      <div class="metric"><span>Fleet Size</span><strong>{len(model["vehicles"])}</strong></div>
      <div class="metric"><span>Active Trucks</span><strong>{model["active"]}</strong></div>
      <div class="metric"><span>Delayed Shipments</span><strong>{model["delayed"]}</strong></div>
      <div class="metric"><span>Customs Holds</span><strong>{model["customs_hold"]}</strong></div>
    </div>
    <section><h2>Vehicle Status</h2>{vehicle_rows}</section>
    <section><h2>Customer Shipment Tracking</h2>{shipment_rows}</section>
    <section><h2>Warehouse Synchronization</h2>{warehouse_rows}</section>
    <section><h2>Latest GPS Readings</h2>{gps_rows}</section>
    <footer>Generated at {utc_now()} from sample data installed with the EC2 portal.</footer>
  </main>
</body>
</html>"""


class FleetHandler(BaseHTTPRequestHandler):
    server_version = "FleetPortal/1.0"

    def send_body(self, status, body, content_type="text/html; charset=utf-8"):
        encoded = body.encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", content_type)
        self.send_header("content-length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self):
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        if parsed.path == "/health":
            self.send_body(200, json.dumps({"status": "ok", "time": utc_now()}), "application/json")
            return
        if parsed.path == "/api/status":
            self.send_body(200, json.dumps(build_model(), indent=2), "application/json")
            return
        if parsed.path == "/":
            self.send_body(200, render_dashboard(query))
            return
        self.send_body(404, "not found", "text/plain; charset=utf-8")

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)


def main():
    parser = argparse.ArgumentParser(description="Fleet Portal")
    parser.add_argument("--host", default=os.environ.get("PORTAL_HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("PORTAL_PORT", "8080")))
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), FleetHandler)
    print(f"Fleet portal listening on http://{args.host}:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
