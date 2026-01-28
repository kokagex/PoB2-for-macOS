"""
高額部品抽出ツール - メインエントリーポイント

Google Sheets APIを使用して高額部品を抽出するツール
"""

import tkinter as tk
from ui import PartsExtractorUI
import config


def main():
    """アプリケーションを初期化して実行"""
    root = tk.Tk()
    root.title(config.APP_NAME)
    root.geometry(f"{config.DEFAULT_WINDOW_WIDTH}x{config.DEFAULT_WINDOW_HEIGHT}")

    app = PartsExtractorUI(root)
    root.mainloop()


if __name__ == "__main__":
    main()
