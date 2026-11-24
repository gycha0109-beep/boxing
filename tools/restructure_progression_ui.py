from pathlib import Path
p=Path(r'D:\cha\boxing-current\scripts\main_v18_release.gd')
s=p.read_text('utf-8')
a=s.index('func _render_gym_fund_intro() -> void:')
b=s.index('func _open_gym_fund_shop() -> void:',a)
s=s[:a]+'''func _render_gym_fund_intro() -> void:
    _v17_section_heading("3경기 달성 · 체육관 공동 모금", "선수 육성에 투자할 새로운 선택지가 열렸습니다.")
    var highlight := _v17_panel(body, true)
    highlight.add_theme_constant_override("separation", 10)
    var eyebrow := _v17_eyebrow(highlight, "NEW CAREER MILESTONE")
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var amount := _v17_title(highlight, "+25,000원", 33)
    amount.add_theme_color_override("font_color", V17_GOLD)
    amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var summary := _v17_copy(highlight, "3경기를 마친 선수를 위해 체육관 공동 모금이 도착했습니다.", false)
    summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var detail := _v17_panel(body, false)
    _v17_title(detail, "새롭게 열린 기능", 18)
    _v17_copy(detail, "장비 구매와 체육관 시설 투자를 통해 앞으로의 훈련 효율을 개선할 수 있습니다.", false)
    _v17_copy(detail, "지금 살펴볼 수도 있고, 이후 상점에서 다시 확인할 수도 있습니다.", true)
    var shop_button := _v17_gold_button("체육관 투자 살펴보기")
    shop_button.name = "GymFundOpenShop"
    shop_button.custom_minimum_size.y = 54
    shop_button.pressed.connect(_open_gym_fund_shop)
    body.add_child(shop_button)
    var skip_button := _v17_dark_button("나중에 확인하기")
    skip_button.name = "GymFundSkipShop"
    skip_button.custom_minimum_size.y = 48
    skip_button.pressed.connect(_skip_gym_fund_shop)
    body.add_child(skip_button)

''' +s[b:]
a=s.index('func _render_career_decision() -> void:')
b=s.index('\nfunc ',a+5) if '\nfunc ' in s[a+5:] else len(s)
block=s[a:b]
# Preserve champion branch, enhance season contract list only.
start=block.index('    var choices := VBoxContainer.new()')
block=block[:start]+'''    var choices := VBoxContainer.new()
    choices.name = "SeasonContractChoices"
    choices.add_theme_constant_override("separation", 10)
    body.add_child(choices)
    for id: String in GameState.League.CONTRACTS:
        var contract: Dictionary = GameState.League.CONTRACTS[id]
        var rate := roundi(GameState.League.contract_rate(GameState.state, id) * 100)
        var panel := _v17_panel(choices, false)
        panel.add_theme_constant_override("separation", 7)
        var headline := HBoxContainer.new()
        headline.add_theme_constant_override("separation", 10)
        panel.add_child(headline)
        var name_label := _v17_title(headline, str(contract.name), 18)
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var multiplier := _v17_title(headline, "%d%%" % rate, 21)
        multiplier.add_theme_color_override("font_color", V17_GOLD)
        _v17_copy(panel, str(contract.detail), true)
        var button := _v17_gold_button("이 계약 선택")
        button.name = "Contract_" + id
        button.custom_minimum_size.y = 48
        button.pressed.connect(func():
            if GameState.sign_contract(id):
                _render_phase()
        )
        panel.add_child(button)
'''
s=s[:a]+block+s[b:]
# Sponsor offers: keep existing business calculations but improve spacing and visual hierarchy.
start=s.index('func _render_sponsorship_decision() -> void:')
end=s.index('func _choose_sponsor(',start)
block=s[start:end]
block=block.replace('var section := _v17_panel(body, false)\n        _v17_title(section, str(offer.get("name", "스폰서")), 20)',
 '''var section := _v17_panel(body, false)
        section.add_theme_constant_override("separation", 9)
        var sponsor_title := _v17_title(section, str(offer.get("name", "스폰서")), 20)
        sponsor_title.add_theme_color_override("font_color", V17_GOLD)''')
block=block.replace('var decline := _v17_gold_button(', 'var decline := _v17_dark_button(')
s=s[:start]+block+s[end:]
p.write_text(s,'utf-8')
print('Restructured milestone, season contract selection, sponsor hierarchy')
