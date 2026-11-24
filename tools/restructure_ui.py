from pathlib import Path
base=Path(r'D:\cha\boxing-current\scripts\ui')
def edit(name,changes):
 p=base/name;s=p.read_text('utf-8')
 for a,b in changes:
  if a not in s:raise Exception(name+' missing: '+a[:75])
  s=s.replace(a,b,1)
 p.write_text(s,'utf-8')
 print('CHANGED',name,len(changes))
edit('reference_training_view.gd',[
('grid.add_theme_constant_override("v_separation", 7)','grid.add_theme_constant_override("v_separation", 11)'),
('var frame := _panel(grid, INK, GOLD_DARK, 6)','var frame := _panel(grid, INK, GOLD_DARK, 10)'),
('var content := _column(frame, 2)','var content := _column(frame, 6)'),
('var description := _label(content, str(CARD_COPY.get(id, "")), 10, WHITE)\n    description.custom_minimum_size.y = 29','var description := _label(content, str(CARD_COPY.get(id, "")), 11, MUTED)\n    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n    description.max_lines_visible = 2\n    description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS'),
('var effect_box := _column(_panel(content, Color("#080f18ee"), GOLD_DARK, 4), 1)','var effect_box := _column(_panel(content, Color("#101b28"), Color("#43515e"), 6), 4)'),
('choose.size_flags_horizontal = Control.SIZE_SHRINK_CENTER','choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL'),
('choose.custom_minimum_size.x = 134','choose.custom_minimum_size.x = 0\n    choose.custom_minimum_size.y = 49')
])
edit('reference_offers_view.gd',[
('var content := _column(card, 5)','var content := _column(card, 9)'),
('portrait_frame.custom_minimum_size.x = 111','portrait_frame.custom_minimum_size.x = 104'),
('var info := _column(row, 2)','var info := _column(row, 5)'),
('var rewards := _row(_panel(info, INK, Color("#5c4b35"), 4), 4)','var rewards := _row(_panel(info, Color("#101b28"), UI.GOLD_DARK, 8), 8)'),
('var buttons := _row(info, 6)','var buttons := _row(info, 8)'),
('accept.name = "FightOfferSelect_" + id','accept.name = "FightOfferSelect_" + id\n    accept.custom_minimum_size.y = 52'),
('inspect.name = "FightOfferAnalyze_" + id','inspect.name = "FightOfferAnalyze_" + id\n    inspect.custom_minimum_size.y = 52')
])
edit('reference_creation_view.gd',[
('var content := _column(card, 4)','var content := _column(card, 8)'),
('thumbnail.custom_minimum_size = Vector2(76, 74)','thumbnail.custom_minimum_size = Vector2(84, 88)'),
('var info := _column(row, 1)','var info := _column(row, 4)'),
('var description := _label(info, str(style.get("description", "")), 11, PAPER, null, true)','var description := _label(info, str(style.get("description", "")), 12, MUTED, null, true)\n    description.max_lines_visible = 3'),
])
