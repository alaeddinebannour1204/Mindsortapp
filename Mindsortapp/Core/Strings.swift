//
//  Strings.swift
//  Mindsortapp
//
//  Centralized localization strings for en, de, fr, es.
//

import Foundation

enum L {
    /// App-level languages (used for UI).
    static let appLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("de", "Deutsch"),
        ("fr", "Français"),
        ("es", "Español")
    ]

    /// Look up a translation for the given key and language code.
    /// Falls back to English, then returns the raw key.
    static func t(_ key: String, lang: String) -> String {
        let langPrefix = String(lang.prefix(2))
        return translations[key]?[langPrefix] ?? translations[key]?["en"] ?? key
    }

    // MARK: - Translation table

    private static let translations: [String: [String: String]] = [

        // ── Auth ────────────────────────────────────────────────

        "auth.tagline": [
            "en": "Speak naturally. Your thoughts sort themselves.",
            "de": "Sprich natürlich. Deine Gedanken ordnen sich selbst.",
            "fr": "Parlez naturellement. Vos pensées se classent d'elles-mêmes.",
            "es": "Habla con naturalidad. Tus pensamientos se organizan solos."
        ],
        "auth.email": [
            "en": "Email",
            "de": "E-Mail",
            "fr": "E-mail",
            "es": "Correo electrónico"
        ],
        "auth.password": [
            "en": "Password",
            "de": "Passwort",
            "fr": "Mot de passe",
            "es": "Contraseña"
        ],
        "auth.signIn": [
            "en": "Sign In",
            "de": "Anmelden",
            "fr": "Se connecter",
            "es": "Iniciar sesión"
        ],
        "auth.signUp": [
            "en": "Sign Up",
            "de": "Registrieren",
            "fr": "S'inscrire",
            "es": "Crear cuenta"
        ],
        "auth.switchToSignIn": [
            "en": "Already have an account? Sign In",
            "de": "Bereits ein Konto? Anmelden",
            "fr": "Vous avez déjà un compte ? Se connecter",
            "es": "¿Ya tienes cuenta? Iniciar sesión"
        ],
        "auth.switchToSignUp": [
            "en": "Don't have an account? Sign Up",
            "de": "Kein Konto? Registrieren",
            "fr": "Pas de compte ? S'inscrire",
            "es": "¿No tienes cuenta? Crear cuenta"
        ],

        // ── Common ──────────────────────────────────────────────

        "common.error": [
            "en": "Error",
            "de": "Fehler",
            "fr": "Erreur",
            "es": "Error"
        ],
        "common.ok": [
            "en": "OK",
            "de": "OK",
            "fr": "OK",
            "es": "OK"
        ],
        "common.cancel": [
            "en": "Cancel",
            "de": "Abbrechen",
            "fr": "Annuler",
            "es": "Cancelar"
        ],
        "common.save": [
            "en": "Save",
            "de": "Speichern",
            "fr": "Enregistrer",
            "es": "Guardar"
        ],
        "common.delete": [
            "en": "Delete",
            "de": "Löschen",
            "fr": "Supprimer",
            "es": "Eliminar"
        ],
        "common.close": [
            "en": "Close",
            "de": "Schließen",
            "fr": "Fermer",
            "es": "Cerrar"
        ],
        "common.rename": [
            "en": "Rename",
            "de": "Umbenennen",
            "fr": "Renommer",
            "es": "Renombrar"
        ],
        "common.undo": [
            "en": "Undo",
            "de": "Rückgängig",
            "fr": "Annuler",
            "es": "Deshacer"
        ],
        "common.loading": [
            "en": "Loading…",
            "de": "Laden…",
            "fr": "Chargement…",
            "es": "Cargando…"
        ],
        "common.search": [
            "en": "Search",
            "de": "Suchen",
            "fr": "Rechercher",
            "es": "Buscar"
        ],
        "common.settings": [
            "en": "Settings",
            "de": "Einstellungen",
            "fr": "Réglages",
            "es": "Ajustes"
        ],
        "common.name": [
            "en": "Name",
            "de": "Name",
            "fr": "Nom",
            "es": "Nombre"
        ],

        // ── Home ────────────────────────────────────────────────

        "home.syncing": [
            "en": "Syncing...",
            "de": "Synchronisiere...",
            "fr": "Synchronisation...",
            "es": "Sincronizando..."
        ],
        "home.syncFailed": [
            "en": "Sync failed — pull to retry",
            "de": "Sync fehlgeschlagen — zum Wiederholen ziehen",
            "fr": "Échec de la synchro — tirez pour réessayer",
            "es": "Error de sincronización — desliza para reintentar"
        ],
        "home.searchThoughts": [
            "en": "Search thoughts...",
            "de": "Gedanken suchen...",
            "fr": "Rechercher des pensées...",
            "es": "Buscar pensamientos..."
        ],
        "home.inbox": [
            "en": "Inbox",
            "de": "Eingang",
            "fr": "Boîte de réception",
            "es": "Bandeja de entrada"
        ],
        "home.uncategorized": [
            "en": "uncategorized",
            "de": "unkategorisiert",
            "fr": "non classé(s)",
            "es": "sin categoría"
        ],
        "home.createCategory": [
            "en": "Create category",
            "de": "Kategorie erstellen",
            "fr": "Créer une catégorie",
            "es": "Crear categoría"
        ],
        "home.newCategory": [
            "en": "New Category",
            "de": "Neue Kategorie",
            "fr": "Nouvelle catégorie",
            "es": "Nueva categoría"
        ],
        "home.categoryName": [
            "en": "Category name",
            "de": "Kategoriename",
            "fr": "Nom de la catégorie",
            "es": "Nombre de la categoría"
        ],
        "home.renameCategory": [
            "en": "Rename Category",
            "de": "Kategorie umbenennen",
            "fr": "Renommer la catégorie",
            "es": "Renombrar categoría"
        ],
        "home.deleteConfirmMessage": [
            "en": "This will delete the category and all its thoughts. This cannot be undone.",
            "de": "Die Kategorie und alle Gedanken werden gelöscht. Dies kann nicht rückgängig gemacht werden.",
            "fr": "La catégorie et toutes ses pensées seront supprimées. Cette action est irréversible.",
            "es": "Se eliminará la categoría y todos sus pensamientos. Esta acción no se puede deshacer."
        ],

        // ── Search ──────────────────────────────────────────────

        "search.byMeaning": [
            "en": "Search by meaning",
            "de": "Nach Bedeutung suchen",
            "fr": "Rechercher par sens",
            "es": "Buscar por significado"
        ],
        "search.hint": [
            "en": "Type a few words or a short sentence, then tap search.",
            "de": "Gib einige Wörter oder einen kurzen Satz ein, dann tippe auf Suchen.",
            "fr": "Tapez quelques mots ou une courte phrase, puis appuyez sur rechercher.",
            "es": "Escribe unas palabras o una frase corta y toca buscar."
        ],

        // ── Category Detail ─────────────────────────────────────

        "category.default": [
            "en": "Category",
            "de": "Kategorie",
            "fr": "Catégorie",
            "es": "Categoría"
        ],
        "category.noThoughts": [
            "en": "No thoughts yet",
            "de": "Noch keine Gedanken",
            "fr": "Aucune pensée pour l'instant",
            "es": "Aún no hay pensamientos"
        ],
        "category.inboxHint": [
            "en": "New recordings will appear here until they are categorized.",
            "de": "Neue Aufnahmen erscheinen hier, bis sie kategorisiert werden.",
            "fr": "Les nouveaux enregistrements apparaîtront ici jusqu'à leur classement.",
            "es": "Las nuevas grabaciones aparecerán aquí hasta que se categoricen."
        ],
        "category.addHint": [
            "en": "Tap + or use the mic to add a new thought.",
            "de": "Tippe auf + oder nutze das Mikrofon, um einen neuen Gedanken hinzuzufügen.",
            "fr": "Appuyez sur + ou utilisez le micro pour ajouter une pensée.",
            "es": "Toca + o usa el micrófono para añadir un pensamiento."
        ],
        "category.entryDeleted": [
            "en": "Entry deleted",
            "de": "Eintrag gelöscht",
            "fr": "Entrée supprimée",
            "es": "Entrada eliminada"
        ],

        // ── Record ──────────────────────────────────────────────

        "record.newThought": [
            "en": "New thought",
            "de": "Neuer Gedanke",
            "fr": "Nouvelle pensée",
            "es": "Nuevo pensamiento"
        ],
        "record.recording": [
            "en": "Recording…",
            "de": "Aufnahme…",
            "fr": "Enregistrement…",
            "es": "Grabando…"
        ],
        "record.preparing": [
            "en": "Preparing…",
            "de": "Vorbereiten…",
            "fr": "Préparation…",
            "es": "Preparando…"
        ],
        "record.thoughtSaved": [
            "en": "Thought saved!",
            "de": "Gedanke gespeichert!",
            "fr": "Pensée enregistrée !",
            "es": "¡Pensamiento guardado!"
        ],
        "record.permissionNeeded": [
            "en": "Permission needed",
            "de": "Berechtigung erforderlich",
            "fr": "Autorisation requise",
            "es": "Se necesita permiso"
        ],
        "record.openSettings": [
            "en": "Open Settings",
            "de": "Einstellungen öffnen",
            "fr": "Ouvrir les réglages",
            "es": "Abrir ajustes"
        ],
        "record.permissionMessage": [
            "en": "Microphone and speech recognition are required to record thoughts. Enable them in Settings.",
            "de": "Mikrofon und Spracherkennung werden zum Aufnehmen benötigt. Aktiviere sie in den Einstellungen.",
            "fr": "Le microphone et la reconnaissance vocale sont nécessaires. Activez-les dans les réglages.",
            "es": "Se necesitan el micrófono y el reconocimiento de voz. Actívalos en Ajustes."
        ],
        "record.noSpeech": [
            "en": "No speech detected. Try again.",
            "de": "Keine Sprache erkannt. Versuche es erneut.",
            "fr": "Aucune parole détectée. Réessayez.",
            "es": "No se detectó voz. Inténtalo de nuevo."
        ],
        "record.notSignedIn": [
            "en": "Not signed in.",
            "de": "Nicht angemeldet.",
            "fr": "Non connecté.",
            "es": "No has iniciado sesión."
        ],
        "record.languageLabel": [
            "en": "Recording language",
            "de": "Aufnahmesprache",
            "fr": "Langue d'enregistrement",
            "es": "Idioma de grabación"
        ],

        // ── Settings ────────────────────────────────────────────

        "settings.account": [
            "en": "Account",
            "de": "Konto",
            "fr": "Compte",
            "es": "Cuenta"
        ],
        "settings.userId": [
            "en": "User ID",
            "de": "Benutzer-ID",
            "fr": "Identifiant",
            "es": "ID de usuario"
        ],
        "settings.unknown": [
            "en": "Unknown",
            "de": "Unbekannt",
            "fr": "Inconnu",
            "es": "Desconocido"
        ],
        "settings.preferences": [
            "en": "Preferences",
            "de": "Einstellungen",
            "fr": "Préférences",
            "es": "Preferencias"
        ],
        "settings.appLanguage": [
            "en": "App language",
            "de": "App-Sprache",
            "fr": "Langue de l'app",
            "es": "Idioma de la app"
        ],
        "settings.recordingLanguage": [
            "en": "Recording language",
            "de": "Aufnahmesprache",
            "fr": "Langue d'enregistrement",
            "es": "Idioma de grabación"
        ],
        "settings.signOut": [
            "en": "Sign Out",
            "de": "Abmelden",
            "fr": "Se déconnecter",
            "es": "Cerrar sesión"
        ],
        "settings.signOutConfirm": [
            "en": "Sign out?",
            "de": "Abmelden?",
            "fr": "Se déconnecter ?",
            "es": "¿Cerrar sesión?"
        ],
        "settings.signOutMessage": [
            "en": "Your data is saved on the server. You can sign back in anytime.",
            "de": "Deine Daten sind auf dem Server gespeichert. Du kannst dich jederzeit wieder anmelden.",
            "fr": "Vos données sont sauvegardées sur le serveur. Vous pouvez vous reconnecter à tout moment.",
            "es": "Tus datos están guardados en el servidor. Puedes volver a iniciar sesión en cualquier momento."
        ],

        // ── Record Button ───────────────────────────────────────

        "recordButton.stop": [
            "en": "Stop recording",
            "de": "Aufnahme beenden",
            "fr": "Arrêter l'enregistrement",
            "es": "Detener grabación"
        ],
        "recordButton.start": [
            "en": "Start recording",
            "de": "Aufnahme starten",
            "fr": "Démarrer l'enregistrement",
            "es": "Iniciar grabación"
        ],
        "recordButton.stopHint": [
            "en": "Stops and saves your thought",
            "de": "Beendet und speichert deinen Gedanken",
            "fr": "Arrête et enregistre votre pensée",
            "es": "Detiene y guarda tu pensamiento"
        ],
        "recordButton.startHint": [
            "en": "Begins voice recording",
            "de": "Startet die Sprachaufnahme",
            "fr": "Démarre l'enregistrement vocal",
            "es": "Inicia la grabación de voz"
        ],

        // ── Entry Card ──────────────────────────────────────────

        "entry.title": [
            "en": "Title",
            "de": "Titel",
            "fr": "Titre",
            "es": "Título"
        ],
        "entry.untitled": [
            "en": "Untitled",
            "de": "Ohne Titel",
            "fr": "Sans titre",
            "es": "Sin título"
        ],
        "entry.empty": [
            "en": "Empty note",
            "de": "Leere Notiz",
            "fr": "Note vide",
            "es": "Nota vacía"
        ],
        "entry.tapToEdit": [
            "en": "Tap to edit",
            "de": "Zum Bearbeiten tippen",
            "fr": "Appuyez pour modifier",
            "es": "Toca para editar"
        ],

        // ── Category Card ───────────────────────────────────────

        "categoryCard.new": [
            "en": "NEW",
            "de": "NEU",
            "fr": "NOUVEAU",
            "es": "NUEVO"
        ],
        "categoryCard.thoughts": [
            "en": "thoughts",
            "de": "Gedanken",
            "fr": "pensées",
            "es": "pensamientos"
        ],

        // ── Undo Toast ──────────────────────────────────────────

        "undo.hint": [
            "en": "Restores the deleted entry",
            "de": "Stellt den gelöschten Eintrag wieder her",
            "fr": "Restaure l'entrée supprimée",
            "es": "Restaura la entrada eliminada"
        ],
        "undo.available": [
            "en": "Undo available.",
            "de": "Rückgängig verfügbar.",
            "fr": "Annulation disponible.",
            "es": "Deshacer disponible."
        ],

        // ── Search Bar ──────────────────────────────────────────

        "searchBar.clear": [
            "en": "Clear search",
            "de": "Suche löschen",
            "fr": "Effacer la recherche",
            "es": "Borrar búsqueda"
        ],

        // ── Root / Config Error ─────────────────────────────────

        "config.notConfigured": [
            "en": "Supabase not configured",
            "de": "Supabase nicht konfiguriert",
            "fr": "Supabase non configuré",
            "es": "Supabase no configurado"
        ],
        "config.instructions": [
            "en": "Set SUPABASE_URL and SUPABASE_ANON_KEY in Edit Scheme → Run → Environment Variables.",
            "de": "Setze SUPABASE_URL und SUPABASE_ANON_KEY unter Schema bearbeiten → Ausführen → Umgebungsvariablen.",
            "fr": "Définissez SUPABASE_URL et SUPABASE_ANON_KEY dans Modifier le schéma → Exécuter → Variables d'environnement.",
            "es": "Configura SUPABASE_URL y SUPABASE_ANON_KEY en Editar esquema → Ejecutar → Variables de entorno."
        ],
    ]
}
