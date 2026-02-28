#!/usr/bin/env python3
"""Google Search Console データ取得・分析スクリプト"""

import json
import csv
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
from google.oauth2 import service_account
from googleapiclient.discovery import build

# 設定
CREDENTIALS_FILE = os.path.expanduser("~/.config/gsc-credentials.json")
SITE_URL = "https://mononikki.com/"
OUTPUT_DIR = Path(__file__).parent.parent / "gsc-data"

SCOPES = ["https://www.googleapis.com/auth/webmasters.readonly"]


def get_service():
    credentials = service_account.Credentials.from_service_account_file(
        CREDENTIALS_FILE, scopes=SCOPES
    )
    return build("searchconsole", "v1", credentials=credentials)


def fetch_performance(service, start_date, end_date, dimensions):
    """検索パフォーマンスデータを取得"""
    request = {
        "startDate": start_date,
        "endDate": end_date,
        "dimensions": dimensions,
        "rowLimit": 1000,
    }
    response = service.searchanalytics().query(siteUrl=SITE_URL, body=request).execute()
    return response.get("rows", [])


def fetch_index_status(service):
    """インデックス登録状況を取得"""
    try:
        response = service.sitemaps().list(siteUrl=SITE_URL).execute()
        return response.get("sitemap", [])
    except Exception as e:
        print(f"  サイトマップ情報取得エラー: {e}")
        return []


def save_csv(rows, dimensions, filepath):
    """CSVファイルに保存"""
    filepath.parent.mkdir(parents=True, exist_ok=True)
    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        header = dimensions + ["clicks", "impressions", "ctr", "position"]
        writer.writerow(header)
        for row in rows:
            keys = row.get("keys", [])
            data = keys + [
                row.get("clicks", 0),
                row.get("impressions", 0),
                round(row.get("ctr", 0) * 100, 2),
                round(row.get("position", 0), 1),
            ]
            writer.writerow(data)


def print_summary(rows, label, dim_name):
    """サマリーを表示"""
    print(f"\n{'='*60}")
    print(f" {label} (上位10件)")
    print(f"{'='*60}")

    if not rows:
        print("  データなし")
        return

    sorted_rows = sorted(rows, key=lambda r: r.get("impressions", 0), reverse=True)
    print(f"  {'　' if dim_name == 'query' else ''}{dim_name:<50} clicks  impr   CTR   pos")
    print(f"  {'-'*80}")
    for row in sorted_rows[:10]:
        key = row["keys"][0]
        clicks = row.get("clicks", 0)
        impressions = row.get("impressions", 0)
        ctr = round(row.get("ctr", 0) * 100, 1)
        position = round(row.get("position", 0), 1)
        print(f"  {key:<50} {clicks:>5}  {impressions:>5}  {ctr:>5}%  {position:>5}")


def main():
    print("Google Search Console データ取得")
    print("=" * 60)

    # 期間設定（過去28日間）
    end_date = (datetime.now() - timedelta(days=3)).strftime("%Y-%m-%d")
    start_date = (datetime.now() - timedelta(days=30)).strftime("%Y-%m-%d")
    print(f"期間: {start_date} 〜 {end_date}")

    service = get_service()
    today = datetime.now().strftime("%Y%m%d")

    # 1. クエリ別データ
    print("\nクエリ別データを取得中...")
    query_rows = fetch_performance(service, start_date, end_date, ["query"])
    save_csv(query_rows, ["query"], OUTPUT_DIR / f"queries_{today}.csv")
    print_summary(query_rows, "検索クエリ別パフォーマンス", "query")

    # 2. ページ別データ
    print("\nページ別データを取得中...")
    page_rows = fetch_performance(service, start_date, end_date, ["page"])
    save_csv(page_rows, ["page"], OUTPUT_DIR / f"pages_{today}.csv")
    print_summary(page_rows, "ページ別パフォーマンス", "page")

    # 3. 日別データ
    print("\n日別データを取得中...")
    date_rows = fetch_performance(service, start_date, end_date, ["date"])
    save_csv(date_rows, ["date"], OUTPUT_DIR / f"dates_{today}.csv")
    print_summary(date_rows, "日別パフォーマンス", "date")

    # 4. デバイス別データ
    print("\nデバイス別データを取得中...")
    device_rows = fetch_performance(service, start_date, end_date, ["device"])
    save_csv(device_rows, ["device"], OUTPUT_DIR / f"devices_{today}.csv")
    print_summary(device_rows, "デバイス別パフォーマンス", "device")

    # 5. サイトマップ情報
    print("\nサイトマップ情報を取得中...")
    sitemaps = fetch_index_status(service)
    if sitemaps:
        print(f"\n{'='*60}")
        print(f" サイトマップ情報")
        print(f"{'='*60}")
        for sm in sitemaps:
            print(f"  URL: {sm.get('path', 'N/A')}")
            print(f"  最終送信日: {sm.get('lastSubmitted', 'N/A')}")
            print(f"  最終ダウンロード: {sm.get('lastDownloaded', 'N/A')}")
            print(f"  ステータス: {sm.get('isPending', False) and '保留中' or '処理済み'}")
            for content in sm.get("contents", []):
                print(f"  タイプ: {content.get('type', 'N/A')}, 送信数: {content.get('submitted', 'N/A')}, インデックス数: {content.get('indexed', 'N/A')}")
            print()

    # 全体サマリー
    total_clicks = sum(r.get("clicks", 0) for r in query_rows)
    total_impressions = sum(r.get("impressions", 0) for r in query_rows)
    avg_ctr = (total_clicks / total_impressions * 100) if total_impressions > 0 else 0
    avg_position = sum(r.get("position", 0) * r.get("impressions", 0) for r in query_rows) / total_impressions if total_impressions > 0 else 0

    print(f"\n{'='*60}")
    print(f" 全体サマリー ({start_date} 〜 {end_date})")
    print(f"{'='*60}")
    print(f"  合計クリック数:   {total_clicks}")
    print(f"  合計表示回数:     {total_impressions}")
    print(f"  平均CTR:          {avg_ctr:.1f}%")
    print(f"  平均掲載順位:     {avg_position:.1f}")
    print(f"  ユニーククエリ数: {len(query_rows)}")
    print(f"  表示ページ数:     {len(page_rows)}")
    print(f"\nCSV出力先: {OUTPUT_DIR}")

    print("\n完了!")


if __name__ == "__main__":
    main()