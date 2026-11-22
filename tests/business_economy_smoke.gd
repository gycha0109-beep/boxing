extends SceneTree

const Business = preload("res://scripts/core/boxing_business_service.gd")
var failures: Array[String] = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        printerr("ABORT: isolated test save directory is required")
        quit(2)
        return
    var game := root.get_node("GameState")
    _test_starter_support(game)
    _test_gate_threshold(game)
    _test_title_and_reputation_tiers(game)
    _test_contracts_and_renewal(game)
    _test_declines_and_save(game)
    _test_old_save_defaults(game)
    if failures.is_empty():
        print("PASS: three-bout starter fund and optional equipment-shop tutorial, title-gated attendance, five sponsor tiers, two contract styles, immediate offer, four-fight renewal, save and decline")
        quit(0)
    else:
        printerr("FAIL: ", failures)
        quit(1)

func _test_starter_support(game: Node) -> void:
    game.new_career("First boxer", "workhorse")
    var money_before := int(game.state.career.money)
    game.begin_boxer_creation()
    _check(bool(game.select_boxing_style("balanced").get("ok", false)), "boxer style selected")
    _check(bool(game.confirm_talent().get("ok", false)), "creation completed")
    _check(int(game.state.career.money) == money_before, "starter fund awarded prematurely on creation")
    _check(not bool(game.state.meta_state.get("starter_fund_claimed", false)), "starter grant marked paid too early")
    for event: Dictionary in game.events:
        _check(str(event.get("id", "")) != "local_sponsor", "starter fund must not appear as random fight event")
    for fights in [1, 2]:
        game.state.phase = "camp"
        game.state.career.fights = fights
        var early := int(game.state.career.money)
        game._maybe_award_gym_fund()
        _check(int(game.state.career.money) == early and game.state.phase == "camp", "grant must not occur before fight three")
    game.state.phase = "camp"
    game.state.career.fights = 3
    game._maybe_award_gym_fund()
    _check(int(game.state.career.money) == money_before + 25000, "third bout must award 25,000 exactly once")
    _check(str(game.state.phase) == "gym_fund_intro", "third bout must open shop introduction")
    _check(bool(game.state.meta_state.get("starter_fund_claimed", false)), "third bout grant marker not stored")
    _check(int(game.state.career_state.get("starter_fund_receipt", 0)) == 25000, "third bout receipt not stored")
    SaveService.save_game(game.state)
    var saved: Dictionary = SaveService.load_game()
    _check(str(saved.get("phase", "")) == "gym_fund_intro", "shop introduction must resume after save")
    _check(game.open_gym_fund_shop() and game.state.phase == "equipment_shop", "shop tutorial must open actual shop")
    _check(game.leave_equipment_shop() and game.state.phase == "camp", "shop tutorial must return to camp without purchase")
    var post := int(game.state.career.money)
    game._maybe_award_gym_fund()
    _check(int(game.state.career.money) == post and game.state.phase == "camp", "third bout reward duplicated on repeat")
    game.state.phase = "camp"
    game.state.career.fights = 4
    game._maybe_award_gym_fund()
    _check(int(game.state.career.money) == post, "starter grant duplicated on later fights")
    game.new_career("Second boxer", "workhorse")
    game.state.meta_state.generation = 2
    game.state.phase = "camp"
    game.state.career.fights = 3
    var next_before := int(game.state.career.money)
    game._maybe_award_gym_fund()
    _check(int(game.state.career.money) == next_before and game.state.phase == "camp", "new generation received starter grant")
    game.new_career("Skip test", "workhorse")
    game.state.phase = "camp"
    game.state.career.fights = 3
    game._maybe_award_gym_fund()
    _check(game.skip_gym_fund_shop() and game.state.phase == "camp", "shop introduction must be skippable")
    game.new_career("Equipment purchase", "workhorse")
    game.state.phase = "camp"
    game.state.career.fights = 3
    game._maybe_award_gym_fund()
    _check(game.open_gym_fund_shop(), "purchase path must open tutorial shop")
    var purchase: Dictionary = game.purchase_equipment("personal", "club_mouthguard")
    _check(bool(purchase.get("ok", false)), "funded player must be able to buy affordable starting equipment")
    _check(game.state.phase == "equipment_shop", "purchasing equipment must not immediately jump to next fight")
    _check(int(game.state.career.money) == 100000, "tutorial shop purchase charged wrong amount")
    _check(game.leave_equipment_shop() and game.state.phase == "fight_offer", "equipment purchase should advance only after player leaves shop")
    game.new_career("Old claim", "workhorse")
    game.state.meta_state["starter_fund_claimed"] = true
    game.state.career.fights = 3
    var already_paid := int(game.state.career.money)
    game._maybe_award_gym_fund()
    _check(int(game.state.career.money) == already_paid and game.state.phase == "camp", "previously paid save should not receive duplicate funding")

func _test_gate_threshold(game: Node) -> void:
    game.new_career("게이트 QA", "workhorse")
    var state: Dictionary = game.state
    state.career.reputation = 60
    var opponent := {"rank":1, "purse":500000, "title_kind":"district"}
    _check(int(Business.preview_bout(state, opponent).gate_share) == 0, "pre-title boxer received gate preview")
    var old_cash := int(state.career.money)
    var first: Dictionary = Business.settle_bout(state, opponent, "WIN_KO")
    _check(int(first.get("gate_share", -1)) == 0 and int(state.career.money) == old_cash, "first district win paid gate retroactively")
    _check(Business.settle_bout(state, opponent, "WIN_KO").is_empty(), "settlement paid twice for same bout")
    state.career.fights = 1
    state.career_state["ladder_titles"] = ["district"]
    _check(int(Business.preview_bout(state, opponent).gate_share) > 0, "post-title boxer got no gate share")
    var next: Dictionary = Business.settle_bout(state, opponent, "LOSS_DEC")
    _check(int(next.gate_share) > 0, "post-title gate settlement missing")
    _check(int(state.career.money) == old_cash + int(next.gate_share), "gate share not credited once")

func _test_title_and_reputation_tiers(game: Node) -> void:
    game.new_career("후원 등급 QA", "workhorse")
    var state: Dictionary = game.state
    state.career.reputation = 100
    _check(Business.eligible_sponsors(state).is_empty(), "reputation alone unlocked sponsor")
    var levels := [
        {"titles":["district"],"rep":100,"id":"local"},
        {"titles":["district", "regional"],"rep":11,"id":"local"},
        {"titles":["district", "regional"],"rep":12,"id":"regional"},
        {"titles":["district", "regional", "national"],"rep":28,"id":"national"},
        {"titles":["district", "regional", "national", "continental"],"rep":40,"id":"continental"},
        {"titles":["district", "regional", "national", "continental", "world_eliminator"],"rep":50,"id":"global"}
    ]
    for item: Dictionary in levels:
        state.career_state["ladder_titles"] = item.titles
        state.career.reputation = int(item.rep)
        var offers: Array = Business.eligible_sponsors(state)
        _check(not offers.is_empty() and str(offers[0].id) == str(item.id), "incorrect sponsor unlock: " + str(item.id))

func _test_contracts_and_renewal(game: Node) -> void:
    game.new_career("후원 계약 QA", "workhorse")
    var state: Dictionary = game.state
    state.career_state["ladder_titles"] = ["district"]
    state.career.reputation = 25
    state.career.fights = 3
    _check(Business.enter_offer_if_due(state), "first title did not immediately open sponsor offer")
    _check(str(state.phase) == "sponsor_offer", "sponsor offer phase not opened")
    _check(Business.sponsorship_offers(state).size() == 1, "district sponsor must be the only eligible tier")
    var offer: Dictionary = Business.SPONSORS.local
    var steady: Dictionary = Business.payment_for_style(offer, "steady", "WIN_KO")
    var performance: Dictionary = Business.payment_for_style(offer, "performance", "WIN_KO")
    _check(int(steady.total) == 20000 and int(performance.total) == 26000, "performance / stable bonus amounts incorrect")
    _check(int(Business.payment_for_style(offer, "steady", "LOSS_DEC").total) == 12000, "steady guarantee incorrect")
    _check(int(Business.payment_for_style(offer, "performance", "LOSS_DEC").total) == 6000, "performance loss payment incorrect")
    _check(Business.sign_sponsorship(state, "local", "performance"), "performance contract sign failed")
    _check(str(state.phase) == "camp", "sponsor sign did not resume the prior camp")
    _check(int(Business.sponsorship_status(state).sponsor.remaining_fights) == 4, "new sponsorship should start at four bouts")
    _check(not Business.sign_sponsorship(state, "global", "steady"), "existing contract could be replaced immediately")
    var opponent := {"rank":35, "purse":180000, "title_kind":""}
    for bout in range(4):
        var result: String = "WIN_KO" if bout == 0 else "LOSS_DEC"
        var invoice: Dictionary = Business.settle_bout(state, opponent, result)
        _check(int(invoice.sponsor_payment) == (26000 if bout == 0 else 6000), "sponsor paid incorrect per-fight amount")
        if bout == 0:
            _check(Business.settle_bout(state, opponent, result).is_empty(), "sponsor duplicated settlement")
        state.career.fights = int(state.career.fights) + 1
        if bout < 3:
            _check(bool(Business.sponsorship_status(state).active), "four-bout sponsor expired too soon")
    _check(not bool(Business.sponsorship_status(state).active), "sponsor not expired on fourth completed fight")
    _check(int(state.career_state.business_state.total_sponsor_income) == 44000, "total sponsor income wrong")
    state.phase = "camp"
    state.career_state["ladder_titles"] = ["district", "regional"]
    _check(Business.enter_offer_if_due(state), "sponsor renewal did not open immediately")
    _check(str(Business.sponsorship_offers(state)[0].id) == "regional", "renewal not upgraded after regional win")
    _check(Business.sign_sponsorship(state, "regional", "steady"), "renewal failed")
    _check(str(state.phase) == "camp", "sponsor renewal did not return to camp")
    state.career_state["ladder_titles"] = ["district", "regional", "national"]
    _check(not Business.should_offer(state), "new title prematurely cancelled an active agreement")

func _test_declines_and_save(game: Node) -> void:
    game.new_career("계약 거절 QA", "workhorse")
    var state: Dictionary = game.state
    state.career_state["ladder_titles"] = ["district"]
    state.career.reputation = 0
    state.career.fights = 4
    state.phase = "season_review"
    _check(Business.enter_offer_if_due(state), "offer not opened before season review")
    _check(str(state.career_state.business_state.offer_return_phase) == "season_review", "offer did not remember season review")
    SaveService.save_game(state)
    var restored: Dictionary = SaveService.load_game()
    _check(str(restored.phase) == "sponsor_offer", "sponsor offer not recovered after reload")
    _check(Business.decline_sponsorship(state), "sponsor decline rejected")
    _check(str(state.phase) == "season_review", "decline did not resume season review")
    _check(not Business.should_offer(state), "declined offer reappeared immediately")
    state.career.fights = 7
    _check(not Business.should_offer(state), "declined offer ignored 4-fight cooldown")
    state.career_state["ladder_titles"] = ["district", "regional"]
    _check(Business.should_offer(state), "new title did not unlock early reoffer")
    state.career_state["ladder_titles"] = ["district"]
    state.career.fights = 8
    _check(Business.enter_offer_if_due(state), "decline cooldown did not end")

func _test_old_save_defaults(game: Node) -> void:
    var state: Dictionary = game.state
    var career_state: Dictionary = state.career_state
    career_state.erase("business_state")
    Business.ensure_state(state)
    var result: Dictionary = Business.sponsorship_status(state)
    _check(int(result.total_gate_income) == 0 and int(result.total_sponsor_income) == 0, "old save defaults missing")
    _check(not bool(result.active), "old save acquired free sponsor")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
