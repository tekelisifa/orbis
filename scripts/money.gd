extends Node
## Monétisation : pub récompensée « continuer », pub toutes les 3 parties, achat « sans pub ».
##
## Interrupteur : orbis/monetisation/active dans project.godot.
## - L'APK de test (debug) l'active toujours, avec les identifiants de test Google.
## - Sur PC en debug, tout est simulé (pas de vraie pub) pour tester l'interface.
## - L'achat « sans pub » retire les pubs entre les parties et rend « continuer » gratuit.

signal changed

const TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"
const TEST_INTER := "ca-app-pub-3940256099942544/1033173712"
const GAMES_BETWEEN_ADS := 3

var enabled := false
var simulated := false
## Prix affiché de l'achat « sans pub » (ex. « 2,99 € »), vide tant qu'il n'est pas connu.
var price := ""

var _ads: RefCounted
var _billing: BillingClient
var _product := ""
var _product_ready := false
var _games := 0


func _ready() -> void:
	var active := OS.is_debug_build() or bool(ProjectSettings.get_setting("orbis/monetisation/active", false))
	if not active:
		return
	_product = str(ProjectSettings.get_setting("orbis/monetisation/remove_ads_product", "sans_pub"))
	if OS.get_name() == "Android":
		enabled = true
		_start_ads()
		_start_billing()
	elif OS.is_debug_build():
		enabled = true
		simulated = true
		price = "2,99 €"
		_product_ready = true


func _start_ads() -> void:
	var debug := OS.is_debug_build()
	var rewarded := TEST_REWARDED if debug else str(ProjectSettings.get_setting("orbis/monetisation/rewarded_id", ""))
	var inter := TEST_INTER if debug else str(ProjectSettings.get_setting("orbis/monetisation/interstitial_id", ""))
	_ads = load("res://scripts/ads_admob.gd").new()
	_ads.changed.connect(changed.emit)
	_ads.start(rewarded, inter)


# --- Continuer la partie ---

func can_continue() -> bool:
	if not enabled:
		return false
	return Save.no_ads or simulated or (_ads != null and _ads.rewarded_ready())


## `done.call(true)` si le joueur a droit à sa deuxième chance.
func request_continue(done: Callable) -> void:
	if Save.no_ads or simulated:
		done.call(true)
	elif _ads:
		_ads.show_rewarded(done)
	else:
		done.call(false)


## À appeler quand le joueur relance une partie ou revient au menu après une défaite.
func after_game() -> void:
	if not enabled or Save.no_ads:
		return
	_games += 1
	if _games % GAMES_BETWEEN_ADS == 0 and _ads:
		_ads.show_interstitial()


# --- Confidentialité ---

func open_privacy_policy() -> void:
	OS.shell_open(str(ProjectSettings.get_setting("orbis/monetisation/privacy_url", "")))


func privacy_options_required() -> bool:
	return _ads != null and _ads.privacy_required


func show_privacy_options() -> void:
	if _ads:
		_ads.show_privacy_options()


# --- Achat « sans pub » ---

func can_buy() -> bool:
	return enabled and not Save.no_ads and _product_ready


func buy() -> void:
	if simulated:
		_unlock()
		return
	if _billing == null:
		return
	if not _billing.is_ready():
		_billing.start_connection()
		return
	_billing.purchase(_product)


func _start_billing() -> void:
	_billing = BillingClient.new()
	add_child(_billing)
	_billing.connected.connect(_on_billing_connected)
	_billing.query_product_details_response.connect(_on_product_details)
	_billing.query_purchases_response.connect(_on_purchases)
	_billing.on_purchase_updated.connect(_on_purchases)
	_billing.start_connection()


func _on_billing_connected() -> void:
	_billing.query_product_details(PackedStringArray([_product]), BillingClient.ProductType.INAPP)
	# Restaure l'achat (réinstallation, nouveau téléphone).
	_billing.query_purchases(BillingClient.ProductType.INAPP)


func _on_product_details(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		return
	for details: Dictionary in result.get("product_details", []):
		if str(details.get("product_id", "")) != _product:
			continue
		var offers = details.get("one_time_purchase_offer_details_list")
		if offers is Array and not offers.is_empty():
			price = str(offers[0].get("formatted_price", ""))
		_product_ready = true
		changed.emit()


func _on_purchases(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		return
	for purchase: Dictionary in result.get("purchases", []):
		if not (_product in Array(purchase.get("product_ids", []))):
			continue
		if int(purchase.get("purchase_state", 0)) != BillingClient.PurchaseState.PURCHASED:
			continue
		_unlock()
		# Sans accusé de réception sous 3 jours, Google rembourse automatiquement.
		if not bool(purchase.get("is_acknowledged", false)):
			_billing.acknowledge_purchase(str(purchase.get("purchase_token", "")))


func _unlock() -> void:
	if Save.no_ads:
		return
	Save.no_ads = true
	Save.store()
	changed.emit()
