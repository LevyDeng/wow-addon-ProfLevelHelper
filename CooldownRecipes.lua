-- 有冷却的配方：法术ID = 冷却秒数。用于插件过滤带CD专业配方（推荐时若玩家选项排除CD，则跳过这些spellID）。
-- 数据来源：Wowhead WotLK 3.3.5、evowow、社区验证。时光服几乎一致，熔炼泰坦神铁CD 3.3.5已移除（若保留解注）。
-- 炼金转化共享20h CD；研究/棱镜20h；附魔球2天；裁缝布4天；璀璨琉璃3天。
-- 插件用法：遍历TradeSkill时，检查recipeSpellID是否在表中，过滤或提示CD。
ProfLevelHelper_CooldownRecipes = {
	-- 附魔（2天CD，172800秒）
	[28028] = 172800,   -- 虚空之球<grok-card data-id="c740d4" data-type="citation_card" data-plain-type="render_inline_citation" ></grok-card><grok-card data-id="aa2042" data-type="citation_card" data-plain-type="render_inline_citation" ></grok-card>
	[28029] = 172800,   -- 万色之球

	-- 珠宝加工（20h/72h CD）
	[62242] = 72000,    -- 冰冻棱镜 (Icy Prism)<grok-card data-id="e7f175" data-type="citation_card" data-plain-type="render_inline_citation" ></grok-card><grok-card data-id="f57c5b" data-type="citation_card" data-plain-type="render_inline_citation" ></grok-card>
	[58481] = 259200,   -- 璀璨琉璃 (Brilliant Glass，72h)

	-- 铭文研究（20h CD）
	[61288] = 72000,    -- 次级铭文研究 (Minor Inscription Research)<grok-card data-id="62d649" data-type="citation_card" data-plain-type="render_inline_citation" ></grok-card><grok-card data-id="e4831b" data-type="citation_card" data-plain-type="render_inline_citation" ></grok-card>
	[61177] = 72000,    -- 北诺兰德铭文研究 (Northrend Inscription Research)<grok-card data-id="bf186b" data-type="citation_card" data-plain-type="render_inline_citation" ></grok-card>

	-- 炼金（20h CD，共享；研究+所有转化）
	[60893] = 72000,    -- 北诺兰德炼金研究 (Northrend Alchemy Research)data-type="citation_card" data-plain-type="render_inline_citation" ></grok-card>
	-- 永恒元素互转8种（共享CD，全列以防遗漏）
	[60896] = 72000,    -- 永恒空气转大地
	[60902] = 72000,    -- 永恒空气转之水
	[60906] = 72000,    -- 永恒大地转空气
	[60955] = 72000,    -- 永恒大地转暗影
	[60904] = 72000,    -- 永恒火焰转之水
	[60977] = 72000,    -- 永恒生命转火焰
	[60983] = 72000,    -- 永恒生命转暗影
	[60909] = 72000,    -- 永恒暗影转大地

	-- 熔炼（3.3.5 CD移除，时光服若保留则解注）
	-- [55208] = 72000,   -- 熔炼泰坦神铁 (Smelt Titansteel)<grok-card data-id="d22274" data-type="citation_card" data-plain-type="render_inline_citation" ></grok-card><grok-card data-id="fde82e" data-type="citation_card" data-plain-type="render_inline_citation" ></grok-card>
}