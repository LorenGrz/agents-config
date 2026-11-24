#!/usr/bin/env -S python3 -I
"""orca-settings: las preferencias de Orca que se pueden publicar, entre la base de Orca y config/orca/settings.json.

  orca-settings.py export   escribe config/orca/settings.json desde la base de esta máquina
  orca-settings.py apply    aplica config/orca/settings.json sobre la base (con Orca cerrado)
  orca-settings.py diff     muestra qué cambiaría apply

Orca guarda sus preferencias en profile-state.db (documento "settings", content_hash = sha256 del JSON). Solo
se escribe con Orca cerrado: abierto, pisa la base con lo que tiene en memoria. Se exporta con una lista de
claves permitidas: cuentas, cookies, rutas de esta máquina, telemetría y semillas de atajos quedan afuera.
"""
import hashlib, json, os, re, sqlite3, subprocess, sys, time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCHIVO = os.path.join(REPO, 'config/orca/settings.json')
DATA = os.environ.get('ORCA_USER_DATA_PATH', os.path.expanduser('~/.config/orca'))

PERMITIDAS = re.compile(r'^(theme|pluginAppTheme.*|editorTheme.*|pluginIconTheme|leftSidebar.*|uiLanguage.*|appIcon|appFontFamily'
    r'|editor(?!.*Path).*|richMarkdown.*|markdown.*|primarySelection.*|terminal(?!Windows|.*Cwd).*|claudeCodeTheme.*'
    r'|windowBackgroundBlur|reduceVisualEffects|minimizeToTrayOnClose|showMenuBarIcon|openLinksInApp.*|localhostWorktreeLabelsEnabled'
    r'|agentDefaultSurface|nativeChat(?!ShellEnvironmentVariables).*|rightSidebarOpenByDefault|showGitIgnoredFiles|sourceControl.*'
    r'|showTitlebarAppName|show\w+Button|artifact\w+Enabled|agentSkillSharingEnabled|nestedWorkerMaxDepth.*|orchestration\w+Enabled'
    r'|showPinnedWorktreesInGroups|ctrlTabOrderMode|floatingTerminal(Enabled|TriggerLocation|DefaultedForAllUsers)'
    r'|notifications|diff\w+|combinedDiff\w+|promptCache\w+|defaultTuiAgent|disabledTuiAgents|pluginSystem\w+|disabledPlugins|pluginConsents'
    r'|claudeAgentTeams\w+|skip\w+Confirm|alwaysForceDelete\w+|defaultTaskViewPreset|defaultTaskSource|visibleTaskProviders.*'
    r'|agentDefaultArgs|agentPermission\w+|agentYoloDefaultsMigrated|agentStatusHooksEnabled|claudeSubagentNavigationEnabled'
    r'|agentWorkspaceTrust\w+|tabAutoGenerateTitle|confirmClosePinnedTab|editorPreviewTabsEnabled|keepComputerAwakeWhileAgentsRun'
    r'|experimental\w+|agentHibernationIdleMs|compactWorktreeCards|commitMessageAi|voice|voiceDictation\w+|workspaceCleanupPolicy'
    r'|worktreeVisibilityDefaults|nestWorkspaces|refreshLocalBaseRefOnWorktreeCreate|autoRenameBranch\w+|branchPrefix\w*'
    r'|jiraIssueKeyCasing|agentsSidebarMigratedFromExperimental|claudeOAuthUsageEnabled)$')
# Dentro de una clave permitida, lo que es de esta máquina o privado.
FUERA = {'notifications': ['customSoundPath'], 'voice': ['modelsDir', 'openAiApiKeyConfigured', 'microphoneDeviceId', 'microphoneDeviceLabel'],
         'commitMessageAi': ['discoveredModelsByAgent', 'discoveredModelsByAgentByHost', 'selectedModelByAgentByHost'],
         'sourceControlAi': ['discoveredModelsByAgent', 'discoveredModelsByAgentByHost', 'selectedModelByAgentByHost']}


def base():
    try:
        perfil = json.load(open(os.path.join(DATA, 'orca-profile-index.json'))).get('activeProfileId') or 'local-default'
    except (OSError, ValueError):
        perfil = 'local-default'
    db = os.path.join(DATA, 'profiles', perfil, 'profile-state.db')
    if not os.path.exists(db):
        sys.exit(f'no encuentro la base de Orca: {db} (abrí Orca una vez y cerralo)')
    return db

def leer(db):
    c = sqlite3.connect(f'file:{db}?mode=ro', uri=True)
    fila = c.execute("select payload from profile_state_documents where domain='settings'").fetchone()
    if not fila:
        sys.exit('la base no tiene el documento settings (abrí Orca una vez y cerralo)')
    return fila[0]

def exportar():
    s = json.loads(leer(base()))
    out = {}
    for k, v in s.items():
        if not PERMITIDAS.match(k):
            continue
        if isinstance(v, dict) and k in FUERA:
            v = {a: b for a, b in v.items() if a not in FUERA[k]}
        out[k] = v
    if 'workspaceDir' in s:  # dónde crea Orca los worktrees, relativo al home
        out['workspaceDir'] = s['workspaceDir'].replace(os.path.expanduser('~'), '~')
    with open(ARCHIVO, 'w') as f:
        f.write(json.dumps(out, indent=2, ensure_ascii=False, sort_keys=True) + '\n')
    print(f'{len(out)} preferencias en {ARCHIVO}')

def nuevo(actual):
    s = json.loads(actual)
    for k, v in json.load(open(ARCHIVO)).items():
        if k == 'workspaceDir':
            v = os.path.expanduser(v)
        s[k] = {**s[k], **v} if isinstance(v, dict) and isinstance(s.get(k), dict) else v
    return s

def orca_abierto():
    return subprocess.run(['pgrep', '-f', r'orca-ide/orca-ide\.js'], capture_output=True).returncode == 0

modo = sys.argv[1] if len(sys.argv) > 1 else '-h'
if modo == 'export':
    exportar()
elif modo in ('apply', 'diff'):
    db = base()
    actual = leer(db)
    antes, despues = json.loads(actual), nuevo(actual)
    cambios = sorted(k for k in despues if antes.get(k) != despues[k])
    if modo == 'diff' or not cambios:
        print(f'{len(cambios)} preferencias cambiarían' + (': ' + ', '.join(cambios) if cambios else ''))
        sys.exit(0)
    # Solo la base real la pisa un Orca abierto; una copia (ORCA_USER_DATA_PATH en otra carpeta) se escribe igual.
    if DATA == os.path.expanduser('~/.config/orca') and orca_abierto():
        sys.exit('Orca está abierto: cerralo y volvé a correr orca-settings.py apply')
    payload = json.dumps(despues, ensure_ascii=False, separators=(',', ':'))
    c = sqlite3.connect(db)
    c.execute(f"vacuum into '{db}.agents-config-bak'") if not os.path.exists(f'{db}.agents-config-bak') else None
    with c:
        c.execute("update profile_state_documents set payload=?, content_hash=?, revision=revision+1, updated_at=? where domain='settings'",
                  (payload, hashlib.sha256(payload.encode()).hexdigest(), int(time.time() * 1000)))
        c.execute("update profile_state_meta set value=cast(value as integer)+1 where key='revision'")
    print(f'{len(cambios)} preferencias aplicadas (respaldo: {db}.agents-config-bak)')
else:
    print(__doc__.strip())
