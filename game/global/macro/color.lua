-- 颜色相关的宏定义

local string = string
local sformat = string.format

-- ANSI真彩色序列的颜色码
ANSI_COLORS = {
	white	= "#ffffff",
	blue	= "#2438CB",
	pink	= "#e603e6",
	red		= "#e50000",
	green 	= "#1b5523",
	yellow	= "#ff8a00",
}


--[[
解释：RGB的16进制颜色码 转换 成可以在 日志里使用的 ANSI 转义序列
	颜色码格式 #RRGGBB (RR表示红色、GG表示绿色、BB表示蓝色。且范围均是 00-FF)

	第一步：把十六进制拆成 RGB 十进制值（例如：#fe6cb7）
		fe 的十进制为 254、6c 的十进制为 108、b7 的十进制为 183

	第二步：拼成 ANSI 真彩色序列
		ANSI 真彩色序列格式
			前景色（文字颜色）：[38;2;R;G;Bm
			背景色（底色）：[48;2;R;G;Bm

	#fe6cb7 转换成 前景色 [38;2;254;108;183m
	#fe6cb7 转换成 背景色 [48;2;254;108;183m
]]
-- 日志相关颜色
LOG_COLORS = {}
LOG_COLOR_FMT = "[38;2;%s;48;2;%sm"		-- 字色、背景色格式
local RGB_REG = "^#(%w%w)(%w%w)(%w%w)"
for name, rgb in pairs(ANSI_COLORS) do
	local rr, gg, bb = rgb:match(RGB_REG)
	if not rr or not gg or not bb then
		error(string.format("ANSI_COLORS name:[%s] value[%s] error!", name, rgb))
	end
	LOG_COLORS[name] = sformat("%s;%s;%s", tonumber(rr, 0x10), tonumber(gg, 0x10), tonumber(bb, 0x10))
end

LOG_NORMAL = sformat(LOG_COLOR_FMT, LOG_COLORS.white, LOG_COLORS.green)		-- 一般日志
LOG_WARNING = sformat(LOG_COLOR_FMT, LOG_COLORS.white, LOG_COLORS.yellow)	-- 警告日志
LOG_ERROR = sformat(LOG_COLOR_FMT, LOG_COLORS.white, LOG_COLORS.red)		-- 错误日志
LOG_EVENT = sformat(LOG_COLOR_FMT, LOG_COLORS.white, LOG_COLORS.blue)		-- 事件日志
LOG_MEM = sformat(LOG_COLOR_FMT, LOG_COLORS.red, LOG_COLORS.white)			-- 内存报警日志



-- -- 若远程连接终端太老不支持，则可以降级到256色号
-- -- 粗糙但快速的 256 色近似（0-15 标准色，16-231 是 6x6x6 色块）
-- local function RgbTo256(r, g, b)
--     if r == g and g == b then
--         -- 灰度色阶 232-255
--         if r == 0 then return 16 end
--         if r == 255 then return 231 end
--         return 232 + math.floor(r / 10.63)
--     end
--     -- 6x6x6 色块
--     local ir = math.floor(r / 51.2 + 0.5)
--     local ig = math.floor(g / 51.2 + 0.5)
--     local ib = math.floor(b / 51.2 + 0.5)
--     return 16 + 36 * ir + 6 * ig + ib
-- end


