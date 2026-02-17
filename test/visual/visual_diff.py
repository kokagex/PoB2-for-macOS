#!/usr/bin/env python3
"""
visual_diff.py - pob2 ビジュアル回帰テスト用画像比較ツール

依存: pip install Pillow scikit-image numpy
"""

import sys
import argparse
import numpy as np
from pathlib import Path
from typing import Optional, Dict, Any
from PIL import Image


def load_image(path: str) -> np.ndarray:
    """画像をRGBA numpy配列としてロード"""
    img = Image.open(path).convert("RGBA")
    return np.array(img, dtype=np.float64)


def pixel_diff(
    img_a: np.ndarray,
    img_b: np.ndarray,
    threshold: float = 5.0
) -> Dict[str, Any]:
    """ピクセル単位の差分解析"""
    if img_a.shape != img_b.shape:
        return {
            "match": False,
            "error": f"Size mismatch: {img_a.shape} vs {img_b.shape}",
            "diff_percentage": 100.0,
            "rmse": float("inf"),
        }

    diff = np.abs(img_a - img_b)
    max_channel_diff = np.max(diff, axis=2)
    changed_pixels = np.sum(max_channel_diff > threshold)
    total_pixels = max_channel_diff.size

    diff_pct = (changed_pixels / total_pixels) * 100.0
    rmse = np.sqrt(np.mean(diff ** 2))

    return {
        "match": diff_pct < 0.1,
        "diff_percentage": round(float(diff_pct), 4),
        "changed_pixels": int(changed_pixels),
        "total_pixels": int(total_pixels),
        "rmse": round(float(rmse), 4),
        "max_diff": round(float(np.max(diff)), 2),
    }


def compute_ssim(img_a: np.ndarray, img_b: np.ndarray) -> float:
    """SSIM (Structural Similarity Index) を計算。戻り値: 0.0〜1.0"""
    try:
        from skimage.metrics import structural_similarity as ssim
    except ImportError:
        print("WARNING: scikit-image not installed, skipping SSIM", file=sys.stderr)
        return -1.0

    if img_a.shape != img_b.shape:
        return 0.0

    rgb_a = img_a[:, :, :3]
    rgb_b = img_b[:, :, :3]

    score = ssim(
        rgb_a, rgb_b,
        channel_axis=2,
        data_range=255.0,
        win_size=7,
    )
    return round(float(score), 6)


def generate_diff_image(
    img_a: np.ndarray,
    img_b: np.ndarray,
    output_path: str,
    amplify: float = 10.0
) -> None:
    """差分を強調した画像を生成"""
    if img_a.shape != img_b.shape:
        return

    diff = np.abs(img_a - img_b)
    amplified = np.clip(diff * amplify, 0, 255).astype(np.uint8)
    amplified[:, :, 3] = 255

    Image.fromarray(amplified).save(output_path)


def compare_images(
    baseline_path: str,
    actual_path: str,
    diff_output: Optional[str] = None,
    pixel_threshold: float = 5.0,
    ssim_threshold: float = 0.98,
    diff_pct_threshold: float = 0.1,
) -> Dict[str, Any]:
    """2つの画像を比較し結果を返す"""
    img_a = load_image(baseline_path)
    img_b = load_image(actual_path)

    pixel_result = pixel_diff(img_a, img_b, threshold=pixel_threshold)
    ssim_score = compute_ssim(img_a, img_b)

    passed = (
        pixel_result["diff_percentage"] <= diff_pct_threshold
        and (ssim_score >= ssim_threshold or ssim_score < 0)
    )

    result = {
        "passed": passed,
        "baseline": baseline_path,
        "actual": actual_path,
        "pixel_diff": pixel_result,
        "ssim": ssim_score,
        "thresholds": {
            "pixel": pixel_threshold,
            "ssim": ssim_threshold,
            "diff_pct": diff_pct_threshold,
        },
    }

    if diff_output and img_a.shape == img_b.shape:
        generate_diff_image(img_a, img_b, diff_output)
        result["diff_image"] = diff_output

    return result


def main():
    parser = argparse.ArgumentParser(description="pob2 Visual Regression Test")
    parser.add_argument("baseline", help="Baseline (expected) image path")
    parser.add_argument("actual", help="Actual (test) image path")
    parser.add_argument("--diff", help="Output path for diff image", default=None)
    parser.add_argument("--pixel-threshold", type=float, default=5.0,
                        help="Per-channel pixel diff threshold (0-255)")
    parser.add_argument("--ssim-threshold", type=float, default=0.98,
                        help="SSIM pass threshold (0.0-1.0)")
    parser.add_argument("--diff-pct", type=float, default=0.1,
                        help="Max allowed diff percentage")
    parser.add_argument("--json", action="store_true", help="Output as JSON")

    args = parser.parse_args()

    result = compare_images(
        args.baseline,
        args.actual,
        diff_output=args.diff,
        pixel_threshold=args.pixel_threshold,
        ssim_threshold=args.ssim_threshold,
        diff_pct_threshold=args.diff_pct,
    )

    if args.json:
        import json
        print(json.dumps(result, indent=2))
    else:
        status = "PASS" if result["passed"] else "FAIL"
        print(f"[{status}] {args.baseline} vs {args.actual}")
        print(f"  Pixel diff: {result['pixel_diff']['diff_percentage']}%"
              f" ({result['pixel_diff']['changed_pixels']} pixels)")
        print(f"  RMSE: {result['pixel_diff']['rmse']}")
        print(f"  SSIM: {result['ssim']}")
        if not result["passed"]:
            sys.exit(1)


if __name__ == "__main__":
    main()
