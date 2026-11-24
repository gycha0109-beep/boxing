from pathlib import Path
base=Path(r'D:\cha\boxing-current\scripts\ui')
def patch(name,rules):
 p=base/name;s=p.read_text('utf-8')
 for a,b in rules:
  if a not in s:raise RuntimeError(name+' MISSING '+a[:95])
  s=s.replace(a,b,1)
 p.write_text(s,'utf-8');print('OK',name,len(rules))
patch('reference_profile_view.gd',[
('portrait_panel.custom_minimum_size = Vector2(153, 256)','portrait_panel.custom_minimum_size = Vector2(132, 222)'),
('portrait.custom_minimum_size = Vector2(148, 250)','portrait.custom_minimum_size = Vector2(128, 218)'),
('var content := _panel(row, PANEL, GOLD, 7)','var content := _panel(row, PANEL, GOLD, 10)'),
('row.add_theme_constant_override("separation", 4)\n    parent.add_child(row)','row.add_theme_constant_override("separation", 7)\n    parent.add_child(row)'),
('k.custom_minimum_size.x = 61','k.custom_minimum_size.x = 56'),
('line.custom_minimum_size.y = 24','line.custom_minimum_size.y = 30'),
('var effect := _label(effect_row, str(STAT_EFFECT_SUMMARY.get(id, "")), 9, MUTED)','var effect := _label(effect_row, str(STAT_EFFECT_SUMMARY.get(id, "")), 11, MUTED)')
])
patch('reference_career_record.gd',[
('var row := _row(self, 6)\n    var record := _metric(row','var row := _row(self, 9)\n    var record := _metric(row'),
('var panel := _panel(row, 6)','var panel := _panel(row, 9)'),
('var content := _column(panel, 1)','var content := _column(panel, 4)'),
('var grid := GridContainer.new()\n    grid.columns = 3','var grid := GridContainer.new()\n    grid.columns = 2'),
('grid.add_theme_constant_override("h_separation", 4)','grid.add_theme_constant_override("h_separation", 8)'),
('grid.add_theme_constant_override("v_separation", 4)','grid.add_theme_constant_override("v_separation", 8)'),
('_center(_label(lines, TITLES[key], 12, UI.GOLD_BRIGHT if earned or next else MUTED','_center(_label(lines, TITLES[key], 13, UI.GOLD_BRIGHT if earned or next else MUTED')
])
patch('reference_equipment_shop.gd',[
('var body := _column(card, 4)','var body := _column(card, 8)'),
('picture.custom_minimum_size = Vector2(63, 50)','picture.custom_minimum_size = Vector2(75, 65)'),
('var names := _column(top, 1)','var names := _column(top, 4)'),
('if not upgrade.is_empty():\n        _label(top, _money(int(upgrade["price"])), 15, UI.GOLD_BRIGHT, bold_font).vertical_alignment = VERTICAL_ALIGNMENT_CENTER',
 'if not upgrade.is_empty():\n        var price := _label(names, "구매가  " + _money(int(upgrade["price"])), 14, UI.GOLD_BRIGHT, bold_font)\n        price.name = "EquipmentPrice_" + slot'),
('var effect := _column(_panel(body, 4), 1)','var effect := _column(_panel(body, 7), 5)'),
('var actions := _row(body, 7)','var actions := _row(body, 10)'),
('buy.custom_minimum_size = Vector2(105, 47)','buy.custom_minimum_size = Vector2(120, 49)')
])
patch('reference_career_event_view.gd',[
('var panel := _column(_panel(self), 4)','var panel := _column(_panel(self), 9)'),
('var row := _row(parent, 6)\n    Art.result_icon(row, icon)','var row := _row(parent, 8)\n    row.custom_minimum_size.y = 36\n    Art.result_icon(row, icon)'),
('var text := _label(row, caption, 12, UI.GOLD_BRIGHT, bold_font)','var text := _label(row, caption, 13, UI.GOLD_BRIGHT, bold_font)'),
('badge.custom_minimum_size.x = 66','badge.custom_minimum_size.x = 72')
])
patch('reference_battle_view.gd',[
('var panel := _panel(self, INK, edge, 5)','var panel := _panel(self, INK, edge, 8)'),
('var panel := _panel(self, Color("#220f13"), Color("#cc6452"), 5)','var panel := _panel(self, Color("#220f13"), Color("#cc6452"), 8)'),
('var detail := _column(row, 1)','var detail := _column(row, 4)'),
('var row := _row(self, 4)\n    row.name = "V19FightActions"','var row := _row(self, 5)\n    row.name = "V19FightActions"')
])
# Tutorial coach floats at top, never directly under the focused action and not hiding the CTA.
patch('first_cycle_spotlight.gd',[
('    var y := 76.0\n    if rect.size.y > 5.0:\n        if rect.end.y + height + 20.0 < size.y - 60.0:\n            y = rect.end.y + 14.0\n        else:\n            y = rect.position.y - height - 14.0',
 '''    var y := 76.0
    if rect.size.y > 5.0:
        # Anchor coaching to the opposite screen region from the selected control.
        # The old placement immediately beside the card concealed neighbouring choices.
        y = 76.0 if rect.get_center().y > size.y * 0.40 else size.y - height - 95.0'''),
('var background := Color(0.015, 0.025, 0.045, 0.63)','var background := Color(0.015, 0.025, 0.045, 0.47)')
])
