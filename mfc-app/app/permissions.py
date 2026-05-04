"""Permission registry: all available permission keys with human descriptions."""

# Master list of all permissions in the application.
# Format: "key": ("Group label", "Human description")
PERMISSIONS: dict[str, tuple[str, str]] = {
    # ─── Posts (news feed) ───
    "posts.create": ("Příspěvky", "Vytvářet příspěvky"),
    "posts.delete_own": ("Příspěvky", "Mazat vlastní příspěvky"),
    "posts.delete_any": ("Příspěvky", "Mazat cizí příspěvky"),
    "posts.pin": ("Příspěvky", "Připínat příspěvky nahoru"),

    # ─── Events (calendar) ───
    "events.create": ("Události", "Vytvářet události (tréninky, turnaje, srazy)"),
    "events.update_own": ("Události", "Upravit vlastní události"),
    "events.update_any": ("Události", "Upravit cizí události"),
    "events.delete_own": ("Události", "Smazat vlastní události"),
    "events.delete_any": ("Události", "Smazat cizí události"),

    # ─── Groups & chat ───
    "groups.create": ("Skupiny", "Vytvářet skupiny"),
    "groups.delete_any": ("Skupiny", "Smazat libovolnou skupinu"),
    "groups.add_member_any": ("Skupiny", "Přidávat členy do libovolné skupiny"),
    "groups.remove_member_any": ("Skupiny", "Odebírat členy z libovolné skupiny"),

    # ─── Messages (chat) ───
    "messages.send": ("Zprávy", "Posílat zprávy v chatu"),
    "messages.delete_own": ("Zprávy", "Mazat vlastní zprávy"),
    "messages.delete_any": ("Zprávy", "Mazat cizí zprávy"),

    # ─── Upload ───
    "upload.image": ("Soubory", "Nahrávat obrázky"),

    # ─── User management ───
    "users.list": ("Uživatelé", "Zobrazit seznam všech uživatelů"),
    "users.update_role": ("Uživatelé", "Měnit role ostatních uživatelů"),
    "users.deactivate": ("Uživatelé", "Aktivovat / deaktivovat uživatele"),
    "users.delete": ("Uživatelé", "Mazat uživatele"),

    # ─── Roles management ───
    "roles.manage": ("Role", "Vytvářet, upravovat a mazat role + jejich oprávnění"),
}


# Default permissions assigned to seed roles (applied only on first start, when role doesn't exist).
DEFAULT_ROLE_PERMISSIONS: dict[str, list[str]] = {
    # Admin = vše. Kontrolováno při seedu i runtime — admin role vždy obsahuje VŠECHNY permissions.
    "admin": list(PERMISSIONS.keys()),

    # Captain = může moderovat obsah, vytvářet události a skupiny, ale nemůže spravovat uživatele/role
    "captain": [
        "posts.create", "posts.delete_own", "posts.delete_any", "posts.pin",
        "events.create", "events.update_own", "events.update_any",
        "events.delete_own", "events.delete_any",
        "groups.create", "groups.add_member_any", "groups.remove_member_any",
        "messages.send", "messages.delete_own", "messages.delete_any",
        "upload.image",
        "users.list",
    ],

    # Member = běžný uživatel — vlastní obsah, RSVP, chat
    "member": [
        "posts.create", "posts.delete_own",
        "events.update_own", "events.delete_own",
        "messages.send", "messages.delete_own",
        "upload.image",
    ],
}


# System roles that cannot be deleted via API (only their permissions can be edited, except admin which always has all)
SYSTEM_ROLES = {"admin", "member"}


def is_valid_permission(key: str) -> bool:
    return key in PERMISSIONS
