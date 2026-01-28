"""
掲示板モジュール

このモジュールは、村人のメッセージ（祈り）を記録・管理する。
メッセージはファイルに永続化される。
"""

import json
from datetime import datetime
import os


class Bulletin:
    """
    掲示板クラス

    メッセージの投稿、保存、一覧表示を管理する。
    データ保存先: data/messages.json
    """

    # メッセージ保存ファイルのパス
    MESSAGE_FILE = "data/messages.json"

    def __init__(self):
        """初期化処理"""
        # data ディレクトリが存在しない場合は作成
        os.makedirs(os.path.dirname(self.MESSAGE_FILE), exist_ok=True)

    def load_messages(self):
        """
        ファイルからメッセージを読み込み

        Returns:
            list: メッセージリスト（JSON形式）
        """
        if not os.path.exists(self.MESSAGE_FILE):
            return []

        with open(self.MESSAGE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)

    def save_messages(self, messages):
        """
        メッセージをファイルに保存

        Args:
            messages (list): 保存するメッセージリスト
        """
        os.makedirs(os.path.dirname(self.MESSAGE_FILE), exist_ok=True)

        with open(self.MESSAGE_FILE, "w", encoding="utf-8") as f:
            json.dump(messages, f, ensure_ascii=False, indent=2)

    def post_message(self, author_name, message_text):
        """
        新しいメッセージを投稿

        Args:
            author_name (str): 投稿者名
            message_text (str): メッセージ本文
        """
        messages = self.load_messages()

        new_message = {
            "timestamp": datetime.now().isoformat(),
            "author": author_name,
            "message": message_text
        }

        messages.append(new_message)
        self.save_messages(messages)

    def get_messages(self):
        """
        全メッセージを取得

        Returns:
            list: メッセージリスト
        """
        return self.load_messages()

    def display_messages(self):
        """
        メッセージ一覧の表示

        保存されているメッセージを、投稿順に表示する。
        """
        messages = self.get_messages()

        print("\n===== 掲示板 =====")
        if not messages:
            print("メッセージはありません")
        else:
            for msg in messages:
                timestamp = msg["timestamp"]
                author = msg["author"]
                message = msg["message"]
                print(f"[{timestamp}] {author}: {message}")
        print("==================")
