extends SceneTree
## تست مستقل BVAULT: self_test + رمزگشایی واقعی اپیزود ۱ + sha256 برای مقایسه با پایتون
func _init() -> void:
        var VA = load("res://scripts/asset_vault.gd")
        var st: bool = VA.self_test()
        print("SELFTEST:", st)
        var d: PackedByteArray = VA.open_bvault("res://data/story/episode_01.bvault")
        print("LEN:", d.size())
        var txt: String = d.get_string_from_utf8()
        print("HEAD:", txt.substr(0, 50))
        var json = JSON.parse_string(txt)
        print("JSON_OK:", json is Dictionary)
        if json is Dictionary:
                print("KEYS:", json.keys())
        var ch := HashingContext.new()
        ch.start(HashingContext.HASH_SHA256)
        ch.update(d)
        print("SHA256:", ch.finish().hex_encode())
        quit(0 if (st and json is Dictionary) else 1)
