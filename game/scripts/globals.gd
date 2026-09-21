extends Node
## Globals: save data, i18n, cars, upgrades, level loading

const SAVE_PATH := "user://boghi_save.json"

var coins: int = 0
var plate_name: String = "بوقی"
var selected_car: int = 0
var upgrades := {"engine": 0, "tire": 0, "turbo": 0}
var unlocked_car := [true, false, false]
var level_stars := {}  # id -> stars
var season = null      # parsed season json

const CARS := [
        {
                "id": "boghi", "name": "بوقی", "en": "Boghi",
                "desc": "متعادل و بامزه — ستاره روی کاپوت!",
                "tex": "res://assets/sprites/boghi_side.png",
                "jump": 1.0, "accel": 1.0, "tough": 1.0, "price": 0
        },
        {
                "id": "sharare", "name": "شراره", "en": "Sharare",
                "desc": "شتاب بالا، کمی عصبانی!",
                "tex": "res://assets/sprites/sharare_side.png",
                "jump": 0.85, "accel": 1.18, "tough": 0.9, "price": 900
        },
        {
                "id": "zabib", "name": "زبید", "en": "Zabib",
                "desc": "وانت آبی مهربون، مقاوم به ضربه",
                "tex": "res://assets/sprites/zabib_side.png",
                "jump": 0.95, "accel": 0.9, "tough": 1.35, "price": 1500
        },
]

const UPGRADES := [
        {"id": "engine", "name": "موتور", "desc": "سرعت بیشتر", "costs": [120, 260, 520]},
        {"id": "tire", "name": "لاستیک", "desc": "پرش بلندتر", "costs": [100, 220, 450]},
        {"id": "turbo", "name": "توربو", "desc": "بوست طولانی‌تر", "costs": [140, 300, 600]},
]

const I18N := {
        "play": {"fa": "بازی", "en": "Play"},
        "garage": {"fa": "کارگاه", "en": "Garage"},
        "levels": {"fa": "مأموریت‌ها", "en": "Missions"},
        "back": {"fa": "برگشت", "en": "Back"},
        "plate_hint": {"fa": "اسم روی پلاک:", "en": "Name on plate:"},
        "coins": {"fa": "سکه", "en": "Coins"},
        "select": {"fa": "انتخاب", "en": "Select"},
        "selected": {"fa": "انتخاب شد", "en": "Selected"},
        "buy": {"fa": "خرید", "en": "Buy"},
        "engine": {"fa": "موتور", "en": "Engine"},
        "tire": {"fa": "لاستیک", "en": "Tire"},
        "turbo": {"fa": "توربو", "en": "Turbo"},
        "max": {"fa": "ماکزیمم", "en": "Max"},
        "jump": {"fa": "پرش", "en": "JUMP"},
        "boost": {"fa": "توربو", "en": "TURBO"},
        "paused": {"fa": "توقف", "en": "Paused"},
        "resume": {"fa": "ادامه", "en": "Resume"},
        "menu": {"fa": "منو", "en": "Menu"},
        "win": {"fa": "آفرین! مأموریت انجام شد", "en": "Mission Complete!"},
        "lose": {"fa": "آخ! دوباره امتحان کن", "en": "Oops! Try again"},
        "next": {"fa": "مرحله بعد", "en": "Next"},
        "retry": {"fa": "دوباره", "en": "Retry"},
        "reward": {"fa": "جایزه", "en": "Reward"},
        "mission": {"fa": "مأموریت", "en": "Mission"},
        "type_race": {"fa": "برس به خط پایان!", "en": "Reach the finish!"},
        "type_collect": {"fa": "سکه جمع کن!", "en": "Collect coins!"},
        "type_taxi": {"fa": "مسافر برسون!", "en": "Deliver passengers!"},
        "type_challenge": {"fa": "چالش ویژه!", "en": "Special challenge!"},
        "locked": {"fa": "قفله! قبلیو ببر", "en": "Locked! Win previous"},
}

func L(key: String) -> String:
        if I18N.has(key):
                return I18N[key]["fa"]
        return key

func _ready() -> void:
        load_save()
        season = load_season()

func load_season() -> Dictionary:
        var f := FileAccess.open("res://data/season1_tehran.json", FileAccess.READ)
        if f == null:
                push_error("season file missing")
                return {}
        var data = JSON.parse_string(f.get_as_text())
        if data == null:
                push_error("season json broken")
                return {}
        return data

func get_level(id: int) -> Dictionary:
        if season == null or not season.has("levels"):
                return {}
        for lv in season["levels"]:
                if int(lv["id"]) == id:
                        return lv
        return {}

func level_unlocked(id: int) -> bool:
        if id <= 1:
                return true
        return level_stars.has(id - 1)

func save_game() -> void:
        var data := {
                "coins": coins,
                "plate_name": plate_name,
                "selected_car": selected_car,
                "upgrades": upgrades,
                "unlocked_car": unlocked_car,
                "level_stars": level_stars,
        }
        var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
        if f:
                f.store_string(JSON.stringify(data))
                f.close()

func load_save() -> void:
        if not FileAccess.file_exists(SAVE_PATH):
                return
        var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
        if f == null:
                return
        var data = JSON.parse_string(f.get_as_text())
        if data == null:
                return
        coins = int(data.get("coins", 0))
        plate_name = str(data.get("plate_name", "بوقی"))
        selected_car = int(data.get("selected_car", 0))
        var up = data.get("upgrades", {})
        for k in ["engine", "tire", "turbo"]:
                upgrades[k] = int(up.get(k, 0))
        var uc = data.get("unlocked_car", [true, false, false])
        for i in 3:
                unlocked_car[i] = bool(uc[i]) if i < uc.size() else false
        unlocked_car[0] = true
        var ls = data.get("level_stars", {})
        level_stars.clear()
        for k in ls:
                level_stars[int(k)] = int(ls[k])
        f.close()

func car_stats() -> Dictionary:
        var c = CARS[selected_car]
        return {
                "jump": float(c["jump"]) * (1.0 + 0.10 * upgrades["tire"]),
                "accel": float(c["accel"]) * (1.0 + 0.08 * upgrades["engine"]),
                "tough": float(c["tough"]),
                "turbo": 1.2 + 0.5 * upgrades["turbo"],
        }

func add_coins(n: int) -> void:
        coins += n
        save_game()

func buy_car(i: int) -> bool:
        if unlocked_car[i]:
                return false
        var price := int(CARS[i]["price"])
        if coins >= price:
                coins -= price
                unlocked_car[i] = true
                selected_car = i
                save_game()
                return true
        return false

func upgrade_cost(uid: String) -> int:
        for u in UPGRADES:
                if u["id"] == uid:
                        var lvl: int = upgrades[uid]
                        if lvl >= 3:
                                return -1
                        return int(u["costs"][lvl])
        return -1

func do_upgrade(uid: String) -> bool:
        var cost := upgrade_cost(uid)
        if cost < 0 or coins < cost:
                return false
        coins -= cost
        upgrades[uid] += 1
        save_game()
        return true

func set_stars(level_id: int, stars: int) -> void:
        var old := int(level_stars.get(level_id, 0))
        level_stars[level_id] = max(old, stars)
        save_game()
