#!/usr/bin/env python3
"""Google Analytics 4 データ取得・分析スクリプト"""

import os
import csv
from datetime import datetime, timedelta
from pathlib import Path
from google.analytics.data_v1beta import BetaAnalyticsDataClient
from google.analytics.data_v1beta.types import (
    RunReportRequest, DateRange, Dimension, Metric, OrderBy, FilterExpression, Filter
)

# 設定
CREDENTIALS_FILE = os.path.expanduser("~/.config/gsc-credentials.json")
PROPERTY_ID = "525421819"
OUTPUT_DIR = Path(__file__).parent.parent / "ga4-data"

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = CREDENTIALS_FILE


def get_client():
    return BetaAnalyticsDataClient()


def run_report(client, dimensions, metrics, date_range, order_by=None, dim_filter=None, limit=50):
    """GA4 レポートを実行"""
    request = RunReportRequest(
        property=f"properties/{PROPERTY_ID}",
        dimensions=[Dimension(name=d) for d in dimensions],
        metrics=[Metric(name=m) for m in metrics],
        date_ranges=[DateRange(start_date=date_range[0], end_date=date_range[1])],
        limit=limit,
    )
    if order_by:
        request.order_bys = order_by
    if dim_filter:
        request.dimension_filter = dim_filter

    return client.run_report(request)


def save_csv(response, dimensions, metrics, filepath):
    """CSV に保存"""
    filepath.parent.mkdir(parents=True, exist_ok=True)
    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        header = dimensions + metrics
        writer.writerow(header)
        for row in response.rows:
            data = [dv.value for dv in row.dimension_values] + [mv.value for mv in row.metric_values]
            writer.writerow(data)


def print_table(response, title, dimensions, metrics, col_widths=None):
    """テーブル表示"""
    print(f"\n{'='*70}")
    print(f" {title}")
    print(f"{'='*70}")

    if not response.rows:
        print("  データなし")
        return

    if not col_widths:
        col_widths = [50] + [10] * len(metrics)

    # ヘッダー
    header = dimensions + metrics
    header_str = "  "
    for i, h in enumerate(header):
        w = col_widths[i] if i < len(col_widths) else 10
        header_str += f"{h:<{w}}" if i == 0 else f"{h:>{w}}"
    print(header_str)
    print(f"  {'-'*sum(col_widths)}")

    for row in response.rows:
        line = "  "
        for i, dv in enumerate(row.dimension_values):
            w = col_widths[i] if i < len(col_widths) else 10
            val = dv.value
            # URLを短縮
            val = val.replace("https://mononikki.com", "")
            if len(val) > w - 2:
                val = val[:w-5] + "..."
            line += f"{val:<{w}}"
        for j, mv in enumerate(row.metric_values):
            idx = len(row.dimension_values) + j
            w = col_widths[idx] if idx < len(col_widths) else 10
            line += f"{mv.value:>{w}}"
        print(line)


def main():
    print("Google Analytics 4 データ取得")
    print("=" * 70)

    # 期間設定
    end_date = "yesterday"
    start_date = "28daysAgo"
    print(f"期間: 過去28日間")

    client = get_client()
    today = datetime.now().strftime("%Y%m%d")
    date_range = (start_date, end_date)

    # --- 1. ページ別 PV ---
    print("\nページ別データを取得中...")
    dims = ["pagePath"]
    mets = ["screenPageViews", "activeUsers", "averageSessionDuration", "engagementRate"]
    order = [OrderBy(metric=OrderBy.MetricOrderBy(metric_name="screenPageViews"), desc=True)]
    resp_pages = run_report(client, dims, mets, date_range, order_by=order)
    save_csv(resp_pages, dims, mets, OUTPUT_DIR / f"pages_{today}.csv")
    print_table(resp_pages, "ページ別パフォーマンス (PV順)", dims, mets,
                col_widths=[45, 8, 8, 10, 10])

    # --- 2. 流入元 ---
    print("\n流入元データを取得中...")
    dims2 = ["sessionSource", "sessionMedium"]
    mets2 = ["sessions", "activeUsers", "engagementRate"]
    order2 = [OrderBy(metric=OrderBy.MetricOrderBy(metric_name="sessions"), desc=True)]
    resp_source = run_report(client, dims2, mets2, date_range, order_by=order2)
    save_csv(resp_source, dims2, mets2, OUTPUT_DIR / f"sources_{today}.csv")
    print_table(resp_source, "流入元別パフォーマンス", ["source", "medium"], mets2,
                col_widths=[25, 15, 10, 10, 10])

    # --- 3. デバイス別 ---
    print("\nデバイス別データを取得中...")
    dims3 = ["deviceCategory"]
    mets3 = ["sessions", "activeUsers", "screenPageViews", "averageSessionDuration"]
    resp_device = run_report(client, dims3, mets3, date_range)
    save_csv(resp_device, dims3, mets3, OUTPUT_DIR / f"devices_{today}.csv")
    print_table(resp_device, "デバイス別パフォーマンス", dims3, mets3,
                col_widths=[20, 10, 10, 10, 10])

    # --- 4. 日別推移 ---
    print("\n日別推移を取得中...")
    dims4 = ["date"]
    mets4 = ["sessions", "activeUsers", "screenPageViews"]
    order4 = [OrderBy(dimension=OrderBy.DimensionOrderBy(dimension_name="date"), desc=False)]
    resp_daily = run_report(client, dims4, mets4, date_range, order_by=order4, limit=31)
    save_csv(resp_daily, dims4, mets4, OUTPUT_DIR / f"daily_{today}.csv")
    print_table(resp_daily, "日別推移", dims4, mets4,
                col_widths=[15, 10, 10, 10])

    # --- 5. 外部リンククリック（アフィリエイト） ---
    print("\n外部リンククリックを取得中...")
    dims5 = ["linkUrl"]
    mets5 = ["eventCount"]
    order5 = [OrderBy(metric=OrderBy.MetricOrderBy(metric_name="eventCount"), desc=True)]
    click_filter = FilterExpression(
        filter=Filter(
            field_name="eventName",
            string_filter=Filter.StringFilter(value="click", match_type=Filter.StringFilter.MatchType.EXACT),
        )
    )
    try:
        resp_links = run_report(client, dims5, mets5, date_range, order_by=order5, dim_filter=click_filter)
        save_csv(resp_links, dims5, mets5, OUTPUT_DIR / f"outbound_clicks_{today}.csv")
        print_table(resp_links, "外部リンククリック (上位)", dims5, mets5,
                    col_widths=[55, 10])
    except Exception as e:
        print(f"  外部リンクデータ取得エラー: {e}")

    # --- 全体サマリー ---
    mets_total = ["sessions", "activeUsers", "screenPageViews", "averageSessionDuration", "engagementRate", "bounceRate"]
    resp_total = run_report(client, [], mets_total, date_range)

    print(f"\n{'='*70}")
    print(f" 全体サマリー (過去28日間)")
    print(f"{'='*70}")
    if resp_total.rows:
        vals = resp_total.rows[0].metric_values
        print(f"  セッション数:       {vals[0].value}")
        print(f"  アクティブユーザー: {vals[1].value}")
        print(f"  ページビュー数:     {vals[2].value}")
        avg_dur = float(vals[3].value)
        print(f"  平均セッション時間: {int(avg_dur//60)}分{int(avg_dur%60)}秒")
        print(f"  エンゲージメント率: {float(vals[4].value)*100:.1f}%")
        print(f"  直帰率:             {float(vals[5].value)*100:.1f}%")
    else:
        print("  データなし（GA4設定直後のため、明日以降にデータが蓄積されます）")

    print(f"\nCSV出力先: {OUTPUT_DIR}")
    print("\n完了!")


if __name__ == "__main__":
    main()