"""
村の天気予報・掲示板ツール
メインエントリーポイント

このモジュールは、ユーザーインターフェース（CLI）を提供し、
weather モジュールと bulletin モジュールを統合管理する。
"""

import sys
from weather import Weather
from bulletin import Bulletin


class VillageTool:
    """
    村のツール統合クラス

    天気予報と掲示板機能をまとめて管理する。
    """

    def __init__(self):
        """初期化処理"""
        self.weather = Weather()
        self.bulletin = Bulletin()

    def display_menu(self):
        """
        メニュー表示

        ユーザーに対して、実行可能な機能を表示する。
        """
        print("\n===== 村のツール =====")
        print("1. 天気予報を見る")
        print("2. 掲示板にメッセージを投稿")
        print("3. 掲示板のメッセージを見る")
        print("4. 終了")
        print("====================")

    def run_weather(self):
        """
        天気予報機能の実行

        ユーザーが入力した都市名に対して、
        架空の天気予報を生成・表示する。
        """
        city = input("都市名を入力してください: ")
        forecast_data = self.weather.forecast(city)
        self.weather.display_forecast(forecast_data)

    def run_bulletin(self):
        """
        掲示板機能の実行

        メッセージの投稿と一覧表示機能を提供する。
        """
        print("\n===== 掲示板メニュー =====")
        print("1. メッセージを投稿")
        print("2. メッセージを見る")
        print("3. 戻る")
        print("======================")

        choice = input("選択 (1-3): ")

        if choice == "1":
            author = input("投稿者名を入力してください: ")
            message = input("メッセージを入力してください: ")
            self.bulletin.post_message(author, message)
            print("メッセージが投稿されました！")
        elif choice == "2":
            self.bulletin.display_messages()
        elif choice == "3":
            pass
        else:
            print("無効な選択です")

    def main_loop(self):
        """
        メインループ

        ユーザーの操作入力を受け取り、適切な処理を実行する。
        終了コマンドまでループを継続する。
        """
        while True:
            self.display_menu()
            choice = input("選択 (1-4): ")

            if choice == "1":
                self.run_weather()
            elif choice == "2":
                author = input("投稿者名を入力してください: ")
                message = input("メッセージを入力してください: ")
                self.bulletin.post_message(author, message)
                print("メッセージが投稿されました！")
            elif choice == "3":
                self.bulletin.display_messages()
            elif choice == "4":
                print("終了します。さようなら！")
                break
            else:
                print("無効な選択です。もう一度選択してください。")


def main():
    """
    エントリーポイント

    プログラムの起動時に実行される関数。
    VillageTool インスタンスを生成し、メインループを開始する。
    """
    tool = VillageTool()
    tool.main_loop()


if __name__ == "__main__":
    main()
