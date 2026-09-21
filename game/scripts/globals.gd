extends Node
## Globals: save data, i18n, cars, upgrades, level loading

const SAVE_PATH := "user://boghi_save.json"

var coins: int = 0
var plate_name: String = "بوقی"
var selected_car: int = 0
var upgrades := {"engine": 0, "tire": 0, "turbo": 0}
var unlocked_car: Array = []
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
                "id": "baran", "name": "باران", "en": "Baran",
                "desc": "وانت آبی مهربون — مقاوم به ضربه",
                "tex": "res://assets/sprites/baran_side.png",
                "jump": 0.95, "accel": 0.9, "tough": 1.35, "price": 1500
        },
        {
                "id": "sepand", "name": "سپند", "en": "Sepand",
                "desc": "کوچولوی خوش‌دل — سبک و چابک",
                "tex": "res://assets/sprites/sepand_side.png",
                "jump": 1.12, "accel": 0.95, "tough": 0.8, "price": 600
        },
        {
                "id": "shaparak", "name": "شاپرک", "en": "Shaparak",
                "desc": "پروانه‌ی شهر — پرش‌های شیرین",
                "tex": "res://assets/sprites/shaparak_side.png",
                "jump": 1.25, "accel": 0.9, "tough": 0.75, "price": 1200
        },
        {
                "id": "karvan", "name": "کاروان", "en": "Karvan",
                "desc": "مینی‌بوس سفرکرده — سنگین ولی مقاوم",
                "tex": "res://assets/sprites/karvan_side.png",
                "jump": 0.8, "accel": 0.85, "tough": 1.5, "price": 1800
        },
        {
                "id": "ezhdeha", "name": "اژدها", "en": "Ezhdeha",
                "desc": "شاسی‌بلند سرخِ چینی — نفس آتش!",
                "tex": "res://assets/sprites/ezhdeha_side.png",
                "jump": 1.05, "accel": 1.1, "tough": 1.2, "price": 2200
        },
        {
                "id": "arian", "name": "آریان", "en": "Arian",
                "desc": "سدان ملی — رویای همه‌ی ماشین‌ها!",
                "tex": "res://assets/sprites/arian_side.png",
                "jump": 1.0, "accel": 1.15, "tough": 1.1, "price": 2600
        },
        {
                "id": "shahin", "name": "شاهین", "en": "Shahin",
                "desc": "کوپه آلمانی — شاهِ سرعت",
                "tex": "res://assets/sprites/shahin_side.png",
                "jump": 0.9, "accel": 1.3, "tough": 1.0, "price": 3400
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
        for i in CARS.size():
                unlocked_car.append(false)
        unlocked_car[0] = true
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
        var uc = data.get("unlocked_car", [true])
        for i in unlocked_car.size():
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
