from pathlib import Path
p=Path(__file__).resolve().parents[1]/'scripts/ui/reference_title_view.gd'
s=p.read_text(encoding='utf-8')
changes=[
('"TitleGoldHeader", 0, 205','"TitleGoldHeader", 0, 113'),
('"TitleArenaBackground", 194, 432','"TitleArenaBackground", 170, 362'),
('"TitleBoxerForeground", 229, 356','"TitleBoxerForeground", 181, 333'),
('fade_layer.offset_top = 552','fade_layer.offset_top = 461'),
('fade_layer.offset_bottom = 630','fade_layer.offset_bottom = 538'),
('shade.offset_top = 176','shade.offset_top = 109'),
('shade.offset_bottom = 244','shade.offset_bottom = 184'),
('"TWELVE COUNT", 40, UI.GOLD_BRIGHT, 150, 57','"TWELVE COUNT", 40, UI.GOLD_BRIGHT, 112, 52'),
('"BOXING CAREER ROGUELITE", 12, PAPER, 206, 23','"BOXING CAREER ROGUELITE", 11, PAPER, 162, 20'),
('"데뷔전부터 세계 타이틀전까지", 20, UI.GOLD_BRIGHT, 579, 31','"데뷔전부터 세계 타이틀전까지", 20, UI.GOLD_BRIGHT, 504, 32'),
('"복서를 만들고 커리어를 이어가라", 13, PAPER, 609, 24','"복서를 만들고 커리어를 이어가라", 13, PAPER, 534, 25'),
('"TitleStartPlate", 654, 76','"TitleStartPlate", 570, 78'),
('"TitleNewCareer", 660, 63','"TitleNewCareer", 576, 65'),
('"TitleResumePlate", 743, 55','"TitleResumePlate", 654, 59'),
('"TitleContinue", 746, 50','"TitleContinue", 658, 52'),
('"TitleLegacyBelt", 821, 112','"TitleLegacyBelt", 742, 190'),
('save_caption, 10, MUTED, 804, 17','save_caption, 11, MUTED, 716, 23'),
('"저장된 커리어가 없습니다", 12, MUTED, 804, 17','"저장된 커리어가 없습니다", 12, MUTED, 716, 23')]
for a,b in changes:
 if a not in s: raise ValueError('not found '+a)
 s=s.replace(a,b,1)
anchor='    var title := _cover_label(cover, "TWELVE COUNT"'
panel='''    var title_panel := ColorRect.new()
    title_panel.name = "TitleMastheadPanel"
    title_panel.color = Color(0.012, 0.018, 0.029, 0.95)
    title_panel.anchor_right = 1.0
    title_panel.offset_top = 107
    title_panel.offset_bottom = 185
    title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cover.add_child(title_panel)
    for line_y in [107, 183]:
        var accent := ColorRect.new()
        accent.name = "TitleMastheadGoldRule"
        accent.color = Color("#bc8e4d")
        accent.anchor_right = 1
        accent.offset_top = line_y
        accent.offset_bottom = line_y + 2
        accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
        cover.add_child(accent)

'''
if panel not in s: s=s.replace(anchor,panel+anchor,1)
p.write_text(s,encoding='utf-8')
print('Rebalanced',len(changes),'placements')
