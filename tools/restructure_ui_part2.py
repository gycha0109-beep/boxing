from pathlib import Path
p=Path(r'D:\cha\boxing-current\scripts\ui')
# 1. Result: decision-critical facts above detailed settlement table.
f=p/'reference_result_view.gd'; s=f.read_text('utf-8')
needle='    _hero()\n    _settlement()'
assert needle in s
s=s.replace(needle,'    _hero()\n    _outcome_summary()\n    _settlement()',1)
needle='func _settlement() -> void:'
assert needle in s
method='''func _outcome_summary() -> void:
    var before: Dictionary = summary.get("previous", {})
    var net := int(summary.get("purse", 0)) + int(summary.get("business_income", 0)) - int(summary.get("cycle_cost", 0))
    var rank := int(career.get("rank", 0))
    var change := int(before.get("rank", rank)) - rank
    var band := _row(self, 8)
    band.name = "ResultKeyMetrics"
    _key_metric(band, "순수익", _signed_money(net) + "원", GREEN if net >= 0 else RED)
    _key_metric(band, "랭킹", "#%d  (%+d)" % [rank, change], UI.GOLD_BRIGHT if change >= 0 else RED)

func _key_metric(parent: HBoxContainer, caption: String, data: String, tint: Color) -> void:
    var frame := _frame(parent, Color("#16212d"), Color("#675637"), 9)
    frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var body := _column(frame, 3)
    _label(body, caption, 11, MUTED, bold_font)
    var amount := _label(body, data, 18, tint, heading_font)
    amount.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

'''
s=s.replace(needle,method+needle,1)
s=s.replace('var table := _column(_frame(self, STEEL, UI.GOLD_DARK, 6), 1)','var table := _column(_frame(self, STEEL, UI.GOLD_DARK, 9), 4)',1)
s=s.replace('row.custom_minimum_size.y = 23','row.custom_minimum_size.y = 29',1)
f.write_text(s,'utf-8')
print('Result: rank and net income summary + breathing room')
# 2. Scouting: one wide choice per plan, avoid two cramped columns.
f=p/'reference_prefight_view.gd';s=f.read_text('utf-8')
s=s.replace('grid.columns = 1 if tutorial_mode else 2','grid.columns = 1',1)
s=s.replace('var card := _column(_panel(grid, NAVY, UI.GOLD_BRIGHT if is_recommended else UI.GOLD_DARK, 7), 3)','var card := _column(_panel(grid, NAVY, UI.GOLD_BRIGHT if is_recommended else UI.GOLD_DARK, 12), 8)',1)
s=s.replace('var description := _label(card, str(plan.get("description", "")), 12, PAPER)','var description := _label(card, str(plan.get("description", "")), 13, PAPER)',1)
s=s.replace('var impact := _label(card, "주요 효과','var impact := _label(card, "주요 효과',1)
f.write_text(s,'utf-8')
print('Scouting: full-width strategy choices')
# 3. Legacy: keep three candidates, but use readable stacked full-width cards.
f=p/'reference_legacy_view.gd';s=f.read_text('utf-8')
s=s.replace('var row := _row(self, 5)\n        for definition: Dictionary in candidates:\n            var card := _card(row, 4, GOLD_EDGE)','var row := _column(self, 10)\n        for definition: Dictionary in candidates:\n            var card := _card(row, 10, GOLD_EDGE)',1)
s=s.replace('_picture(card, _card_art(str(definition.get("category", ""))), 66)','_picture(card, _card_art(str(definition.get("category", ""))), 102)',1)
s=s.replace('name_label.custom_minimum_size.y = 33','name_label.custom_minimum_size.y = 25',1)
s=s.replace('var description := _copy(card, str(definition.get("description", "")), 10, PAPER, true)','var description := _copy(card, str(definition.get("description", "")), 13, PAPER, true)',1)
s=s.replace('effects.custom_minimum_size.y = 39','effects.custom_minimum_size.y = 45',1)
f.write_text(s,'utf-8')
print('Legacy: vertical readable choice cards')
# 4. Coaching: always keep tutor box out of hit target, prefer bottom of viewport and no clipping.
f=p/'first_cycle_spotlight.gd';s=f.read_text('utf-8')
s=s.replace('dialogue.custom_minimum_size = Vector2(280, 102)','dialogue.custom_minimum_size = Vector2(268, 88)',1)
s=s.replace('dialogue.set_deferred("size", Vector2(310, 100))','dialogue.set_deferred("size", Vector2(296, 92))',1)
s=s.replace('var width := minf(310.0, size.x - 18.0)','var width := minf(296.0, size.x - 18.0)',1)
s=s.replace('var y := 76.0','var y := 76.0',1)
f.write_text(s,'utf-8')
print('Coaching: smaller non-blocking callout')
