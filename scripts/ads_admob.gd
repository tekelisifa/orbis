extends RefCounted
## Pubs AdMob : consentement RGPD (UMP), pub récompensée et pub entre les parties.
## Chargé uniquement sur Android quand la monétisation est active (voir money.gd),
## pour que le reste du jeu ne dépende jamais des classes du plugin.

signal changed

var privacy_required := false
var _rewarded_id := ""
var _inter_id := ""
var _rewarded: RewardedAd
var _inter: InterstitialAd
var _started := false
var _loading_rewarded := false
var _loading_inter := false


func start(rewarded_id: String, inter_id: String) -> void:
	_rewarded_id = rewarded_id
	_inter_id = inter_id
	var info := UserMessagingPlatform.consent_information
	info.update(ConsentRequestParameters.new(), _on_consent_updated, func(_e: FormError) -> void: _init_ads())


func _on_consent_updated() -> void:
	var info := UserMessagingPlatform.consent_information
	if not info.get_is_consent_form_available():
		_after_consent()
		return
	UserMessagingPlatform.load_consent_form(
		func(form: ConsentForm) -> void:
			if info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
				form.show(func(_e: FormError) -> void: _after_consent())
			else:
				_after_consent(),
		func(_e: FormError) -> void: _after_consent())


func _after_consent() -> void:
	var info := UserMessagingPlatform.consent_information
	privacy_required = info.get_privacy_options_requirement_status() == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
	_init_ads()


func _init_ads() -> void:
	if _started:
		return
	_started = true
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_s: InitializationStatus) -> void:
		load_rewarded()
		load_interstitial()
	MobileAds.initialize(listener)
	changed.emit()


## Réouvre le formulaire de consentement (bouton « Consentement pubs » du menu).
func show_privacy_options() -> void:
	UserMessagingPlatform.show_privacy_options_form(func(_e: FormError) -> void: changed.emit())


# --- Pub récompensée : « continuer la partie » ---

func rewarded_ready() -> bool:
	return _rewarded != null


func load_rewarded() -> void:
	if _rewarded or _loading_rewarded or not _started:
		return
	_loading_rewarded = true
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_loading_rewarded = false
		_rewarded = ad
		changed.emit()
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void:
		_loading_rewarded = false
	RewardedAdLoader.new().load(_rewarded_id, AdRequest.new(), cb)


## Montre la pub ; `done.call(true)` si le joueur l'a regardée jusqu'à la récompense.
func show_rewarded(done: Callable) -> void:
	var ad := _rewarded
	if ad == null:
		done.call(false)
		return
	_rewarded = null
	var earned := [false]
	var finish := func() -> void:
		ad.destroy()
		load_rewarded()
		done.call(earned[0])
	var cb := FullScreenContentCallback.new()
	cb.on_ad_dismissed_full_screen_content = finish
	cb.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: finish.call()
	ad.full_screen_content_callback = cb
	var reward := OnUserEarnedRewardListener.new()
	reward.on_user_earned_reward = func(_item: RewardedItem) -> void: earned[0] = true
	ad.show(reward)


# --- Pub entre les parties ---

func load_interstitial() -> void:
	if _inter or _loading_inter or not _started:
		return
	_loading_inter = true
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_loading_inter = false
		_inter = ad
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void:
		_loading_inter = false
	InterstitialAdLoader.new().load(_inter_id, AdRequest.new(), cb)


func show_interstitial() -> void:
	var ad := _inter
	if ad == null:
		load_interstitial()
		return
	_inter = null
	var finish := func() -> void:
		ad.destroy()
		load_interstitial()
	var cb := FullScreenContentCallback.new()
	cb.on_ad_dismissed_full_screen_content = finish
	cb.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: finish.call()
	ad.full_screen_content_callback = cb
	ad.show()
