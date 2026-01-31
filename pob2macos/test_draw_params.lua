#!/usr/bin/env luajit
--
-- DrawImage パラメータテスト
-- 描画関数に渡されるパラメータを検証
--

print("=== DrawImage Parameter Test ===")
print("")

-- テスト用の DrawImage インターセプター
local draw_calls = {}
local original_DrawImage = nil

function intercept_DrawImage()
    if not original_DrawImage then
        original_DrawImage = _G.DrawImage
    end

    _G.DrawImage = function(imageHandle, left, top, width, height, tcLeft, tcTop, tcRight, tcBottom)
        local call_info = {
            handle = imageHandle,
            handle_type = type(imageHandle),
            has_handle = (type(imageHandle) == "table" and imageHandle._handle ~= nil),
            pos = {left = left, top = top},
            size = {width = width, height = height},
            tex_coords = {
                left = tcLeft or 0.0,
                top = tcTop or 0.0,
                right = tcRight or 1.0,
                bottom = tcBottom or 1.0
            }
        }

        table.insert(draw_calls, call_info)

        -- 元の関数を呼び出し
        if original_DrawImage then
            original_DrawImage(imageHandle, left, top, width, height, tcLeft, tcTop, tcRight, tcBottom)
        end
    end
end

function analyze_draw_calls()
    print("Total DrawImage calls: " .. #draw_calls)
    print("")

    local issues = {}

    for i, call in ipairs(draw_calls) do
        local problems = {}

        -- ハンドルチェック
        if call.handle == nil then
            table.insert(problems, "handle is nil")
        elseif call.handle_type == "table" and not call.has_handle then
            table.insert(problems, "handle table has no _handle field")
        end

        -- 位置とサイズチェック
        if not call.pos.left or not call.pos.top then
            table.insert(problems, "position is nil")
        end
        if not call.size.width or not call.size.height then
            table.insert(problems, "size is nil")
        end
        if call.size.width and call.size.width <= 0 then
            table.insert(problems, "width <= 0")
        end
        if call.size.height and call.size.height <= 0 then
            table.insert(problems, "height <= 0")
        end

        -- テクスチャ座標チェック
        local tc = call.tex_coords
        if tc.left > 100 or tc.top > 100 or tc.right > 100 or tc.bottom > 100 then
            table.insert(problems, string.format("tex coords very large: (%.1f,%.1f,%.1f,%.1f)",
                tc.left, tc.top, tc.right, tc.bottom))
        end

        if #problems > 0 then
            table.insert(issues, {
                call_num = i,
                problems = problems,
                call_info = call
            })
        end
    end

    -- 問題を報告
    if #issues > 0 then
        print("⚠️  Found " .. #issues .. " calls with potential issues:")
        print("")

        for _, issue in ipairs(issues) do
            print("Call #" .. issue.call_num .. ":")
            for _, prob in ipairs(issue.problems) do
                print("  - " .. prob)
            end
            local c = issue.call_info
            print(string.format("    pos=(%.1f,%.1f) size=(%.1f,%.1f) tc=(%.3f,%.3f,%.3f,%.3f)",
                c.pos.left or 0, c.pos.top or 0,
                c.size.width or 0, c.size.height or 0,
                c.tex_coords.left, c.tex_coords.top,
                c.tex_coords.right, c.tex_coords.bottom))
            print("")
        end
    else
        print("✅ All DrawImage calls have valid parameters")
    end

    -- 統計
    print("")
    print("=== Statistics ===")
    local nil_handles = 0
    local large_tex_coords = 0

    for _, call in ipairs(draw_calls) do
        if call.handle == nil then
            nil_handles = nil_handles + 1
        end
        local tc = call.tex_coords
        if tc.left > 1.5 or tc.top > 1.5 or tc.right > 1.5 or tc.bottom > 1.5 then
            large_tex_coords = large_tex_coords + 1
        end
    end

    print("Nil handles: " .. nil_handles .. " (" .. string.format("%.1f%%", nil_handles/#draw_calls*100) .. ")")
    print("Large texture coordinates (>1.5): " .. large_tex_coords .. " (" .. string.format("%.1f%%", large_tex_coords/#draw_calls*100) .. ")")
end

-- エクスポート
return {
    intercept = intercept_DrawImage,
    analyze = analyze_draw_calls,
    get_calls = function() return draw_calls end,
    clear = function() draw_calls = {} end
}
