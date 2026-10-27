// Просмотр эффектов розыгрыша всех легендарок Hearthstone прямо в Unity, без запекания:
// владелец листает список, эффект играет вживую с камеры доски HS (как HsRender), лучшие —
// в избранное. Меню Tyrants → HS Legendaries.
//
// Список — hs_unity/render/hs_gallery.tsv (`hsx gallery`, GUIDE §0 п.1): строки «b <бандл>»
// (номер = порядок), затем card_id, имя, вид (CustomSummon…), guid спелла, номера бандлов,
// номер карты в базе HS (по нему дополнения сортируются по дате выхода).
// Избранное — hs_unity/data/hs_favorites.tsv (в git), просмотренные — hs_unity/render/hs_seen.txt.
// Проверка без окна — Test (Unity -batchmode -executeMethod HsBrowser.Test -hsb-cards … -hsb-out …).
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;
using UnityEngine.Playables;
using UnityEngine.Rendering;

public class HsBrowser : EditorWindow
{
    const string Win = "C:/Games/Hearthstone/Data/Win";
    // наборы 2024+ (GUIDE §1: только свежие анимации)
    static readonly string[] Fresh = { "VAC", "TOY", "GDB", "TLC", "DINO", "EDR", "TIME", "CATA", "BE" };
    // сетки жетона и контуры миньона HS (имена — как в cand.sh, без узлов-контейнеров)
    static readonly Regex TokenRx = new Regex(@"TokenGlow|MinionEdgeGlow|MinionShell|MinionGlow|Mesh_FlashGlow|Nightmare|Card_InPlay|TokenHider|Test_Minion");
    const string Mark = "HSB ";

    public class Entry
    {
        public string id, name, kind, guid, set;
        public int[] deps;
        // db — номер карты в базе HS, order — место дополнения по дате выхода
        public int db, order;
        // id карт с тем же спеллом (повторы убраны из списка)
        public string also = "";
        public string Key => id + "\t" + kind;
    }

    static string Root => Path.GetFullPath(Path.Combine(Application.dataPath, ".."));
    static string GalleryPath => Path.Combine(Root, "render", "hs_gallery.tsv");
    static string FavPath => Path.Combine(Root, "data", "hs_favorites.tsv");
    static string SeenPath => Path.Combine(Root, "render", "hs_seen.txt");

    readonly List<string> bundleNames = new List<string>();
    readonly List<Entry> all = new List<Entry>();
    List<Entry> shown = new List<Entry>();
    // ключ (id + вид) -> строка файла избранного
    readonly SortedDictionary<string, string> favs = new SortedDictionary<string, string>();
    readonly HashSet<string> seen = new HashSet<string>();
    string[] setNames = { "Все" };
    string search = "";
    int setIdx;
    bool unseenOnly, hideToken = true;
    [SerializeField] bool hideUsed;
    // 0 — все, 1 — только избранное, 2 — без избранного
    int favMode;
    // 0 — дополнения от первого к последнему, 1 — от последнего, 2 — по имени
    int sortIdx;
    static readonly string[] Sorts = { "Выход: старые → новые", "Выход: новые → старые", "По имени" };
    // названия дополнений по коду карты (неизвестные — только код)
    static readonly Dictionary<string, string> SetNames = new Dictionary<string, string>
    {
        ["EX1"] = "Classic", ["NEW1"] = "Classic", ["FP1"] = "Naxxramas", ["GVG"] = "Goblins vs Gnomes",
        ["BRM"] = "Blackrock Mountain", ["AT"] = "The Grand Tournament", ["LOE"] = "League of Explorers",
        ["OG"] = "Whispers of the Old Gods", ["KAR"] = "One Night in Karazhan", ["CFM"] = "Mean Streets of Gadgetzan",
        ["UNG"] = "Journey to Un'Goro", ["ICC"] = "Knights of the Frozen Throne", ["LOOT"] = "Kobolds & Catacombs",
        ["GIL"] = "The Witchwood", ["BOT"] = "The Boomsday Project", ["GILA"] = "Monster Hunt", ["TRL"] = "Rastakhan's Rumble",
        ["TB"] = "Tavern Brawl", ["DAL"] = "Rise of Shadows", ["ULD"] = "Saviors of Uldum", ["DALA"] = "Dalaran Heist",
        ["DRG"] = "Descent of Dragons", ["YOD"] = "Galakrond's Awakening", ["BT"] = "Ashes of Outland",
        ["SCH"] = "Scholomance Academy", ["DMF"] = "Darkmoon Faire", ["YOP"] = "Darkmoon Races",
        ["BAR"] = "Forged in the Barrens", ["CORE"] = "Core", ["CS3"] = "Core", ["WC"] = "Wailing Caverns",
        ["LETL"] = "Mercenaries", ["SW"] = "United in Stormwind", ["DED"] = "Deadmines", ["AV"] = "Alterac Valley",
        ["VAN"] = "Classic (2021)", ["Story"] = "Book of Heroes", ["ONY"] = "Onyxia's Lair",
        ["TSC"] = "Voyage to the Sunken City", ["TID"] = "Throne of the Tides", ["REV"] = "Murder at Castle Nathria",
        ["RLK"] = "March of the Lich King", ["MAW"] = "Maw and Disorder", ["BOM"] = "Book of Mercenaries",
        ["ETC"] = "Festival of Legends", ["JAM"] = "Audiopocalypse", ["TTN"] = "TITANS", ["BG"] = "Battlegrounds",
        ["WW"] = "Showdown in the Badlands", ["YOG"] = "Fall of Ulduar", ["DEEP"] = "Delve into Deepholm",
        ["TOY"] = "Whizbang's Workshop", ["WON"] = "Caverns of Time", ["VAC"] = "Perils in Paradise",
        ["GDB"] = "The Great Dark Beyond", ["SC"] = "Heroes of StarCraft", ["EDR"] = "Into the Emerald Dream",
        ["TLC"] = "The Lost City of Un'Goro", ["TIME"] = "Across the Timeways",
    };
    int speedIdx = 2;
    static readonly float[] Speeds = { 0.25f, 0.5f, 1f };
    Entry cur;
    Vector2 scroll;

    readonly Dictionary<string, AssetBundle> loaded = new Dictionary<string, AssetBundle>();
    HsRender.Live live;
    readonly List<HsRender.Live> lives = new List<HsRender.Live>();
    Camera cam;
    RenderTexture rt;
    double startT;
    float t, len = 4f;
    bool playing = true, dirty;
    string status = "";
    // префабы-кандидаты из зависимостей обёртки (для Test)
    string innerInfo = "";
    static bool prepared;
    // панель уникальных карт Tyrants справа (назначение эффекта на карту)
    [SerializeField] HsCards cards = new HsCards();
    [SerializeField] bool showCards = true;
    public HsCards Cards => cards;

    [MenuItem("Tyrants/HS Legendaries")]
    public static void Open()
    {
        var w = GetWindow<HsBrowser>("HS Legendaries");
        w.minSize = new Vector2(900, 480);
        // место под панель карт; положение окна не трогать (на экране 300% Unity путает координаты)
        var p = w.position;
        if (w.showCards && !w.docked && p.width < 1240f) w.position = new Rect(p.x, p.y, 1240f, Mathf.Max(p.height, 600f));
        w.Focus();
    }

    void OnEnable()
    {
        // после перекомпиляции бандлы и спрятанные объекты прошлого окна остаются — убрать
        AssetBundle.UnloadAllAssetBundles(true);
        foreach (var g in Resources.FindObjectsOfTypeAll<GameObject>())
            if (g != null && g.transform.parent == null && g.scene.IsValid() && g.name.StartsWith(Mark)) DestroyImmediate(g);
        if (!prepared)
        {
            if (PlayerSettings.colorSpace != ColorSpace.Gamma) PlayerSettings.colorSpace = ColorSpace.Gamma;
            HsRender.EnsureTimeFeature();
            prepared = true;
        }
        HsRender.Quiet = true;
        Load();
        EditorApplication.update += Tick;
    }

    void OnDisable()
    {
        EditorApplication.update -= Tick;
        cards.Free();
        Clear(true);
        HsRender.Quiet = false;
    }

    void Load()
    {
        all.Clear();
        bundleNames.Clear();
        if (!File.Exists(GalleryPath))
        {
            status = "Нет списка " + GalleryPath + " — собрать: hsx gallery (GUIDE §0 п.1)";
            shown = new List<Entry>();
            return;
        }
        foreach (var line in File.ReadLines(GalleryPath))
        {
            if (line.StartsWith("b ")) { bundleNames.Add(line.Substring(2)); continue; }
            var s = line.Split('\t');
            if (s.Length < 6) continue;
            all.Add(new Entry
            {
                id = s[0], name = s[1].Trim('"'), kind = s[2], guid = s[3], set = s[0].Split('_')[0],
                deps = s[4].Split(',').Select(int.Parse).ToArray(), db = int.Parse(s[5]),
            });
        }
        // повторы (тот же спелл: переиздания CORE/VAN, Galakrond t2/t3, потасовки TB…) — одна
        // строка, самая поздняя карта (владелец); остальные id — в поиске
        var uniq = all.GroupBy(e => e.guid).Select(g =>
        {
            var first = g.OrderByDescending(e => e.db).First();
            first.also = string.Join(", ", g.Where(e => e != first).Select(e => e.id));
            return first;
        }).ToList();
        all.Clear();
        all.AddRange(uniq);
        // порядок выхода дополнений: номер карты в базе HS растёт с каждым дополнением —
        // дополнение стоит по самой ранней своей карте
        var sets = all.GroupBy(e => e.set).OrderBy(g => g.Min(e => e.db)).ToList();
        for (int i = 0; i < sets.Count; i++) foreach (var e in sets[i]) e.order = i;
        setNames = new[] { $"Все ({all.Count})", $"Свежие 2024+ ({all.Count(e => Fresh.Contains(e.set))})" }
            .Concat(sets.Select(g => $"{g.Key}{(SetNames.TryGetValue(g.Key, out var nm) ? " — " + nm : "")} ({g.Count()})")).ToArray();
        favs.Clear();
        if (File.Exists(FavPath))
            foreach (var line in File.ReadLines(FavPath).Skip(1))
            {
                var s = line.Split('\t');
                if (s.Length >= 3) favs[s[0] + "\t" + s[2]] = line;
            }
        seen.Clear();
        if (File.Exists(SeenPath)) seen.UnionWith(File.ReadLines(SeenPath));
        Refilter();
    }

    // назначение в панели карт меняет, какие эффекты заняты
    public void UsedChanged() { if (hideUsed) { Refilter(); Repaint(); } }
    public bool HideUsed { get => hideUsed; set { hideUsed = value; Refilter(); Repaint(); } }

    void Refilter()
    {
        string set = setIdx >= 2 ? setNames[setIdx].Split(' ')[0] : null;
        shown = all.Where(e =>
            (setIdx != 1 || Fresh.Contains(e.set)) && (set == null || e.set == set) &&
            (favMode == 0 || favs.ContainsKey(e.Key) == (favMode == 1)) && (!unseenOnly || !seen.Contains(e.Key)) &&
            (!hideUsed || HsCards.AssignedTo(e.id, e.also, "") == "") &&
            (search == "" || e.name.IndexOf(search, StringComparison.OrdinalIgnoreCase) >= 0 ||
             e.id.IndexOf(search, StringComparison.OrdinalIgnoreCase) >= 0 ||
             e.also.IndexOf(search, StringComparison.OrdinalIgnoreCase) >= 0)).ToList();
        int dir = sortIdx == 1 ? -1 : 1;
        shown.Sort((a, b) =>
        {
            int c = sortIdx == 2 ? 0 : dir * a.order.CompareTo(b.order);
            return c != 0 ? c : string.Compare(a.name, b.name, StringComparison.OrdinalIgnoreCase);
        });
    }

    void ToggleFav(Entry e)
    {
        if (!favs.Remove(e.Key)) favs[e.Key] = $"{e.id}\t{e.name}\t{e.kind}\t{e.set}";
        Directory.CreateDirectory(Path.GetDirectoryName(FavPath));
        File.WriteAllLines(FavPath, new[] { "card_id\tname\tkind\tset" }.Concat(favs.Values));
        if (favMode != 0) Refilter();
    }

    // открыть недостающие бандлы карты, поставить эффект в точку посадки
    void Select(Entry e, bool markSeen = true)
    {
        Clear(false);
        cur = e;
        var t0 = EditorApplication.timeSinceStartup;
        var need = new HashSet<string>(e.deps.Select(i => bundleNames[i]));
        // бандлы остаются открытыми до закрытия окна (каждый открывается один раз — у карт
        // одного набора они почти общие); память прошлого эффекта освобождается
        Resources.UnloadUnusedAssets();
        int failed = 0;
        foreach (var f in need)
        {
            if (loaded.ContainsKey(f)) continue;
            var b = AssetBundle.LoadFromFile(Path.Combine(Win, f));
            if (b != null) loaded[f] = b; else failed++;
        }
        HsRender.Bundles.Clear();
        HsRender.Bundles.AddRange(loaded.Values);
        GameObject prefab = null;
        foreach (var b in loaded.Values)
            if (b.Contains(e.guid)) { prefab = b.LoadAsset<GameObject>(e.guid); break; }
        if (prefab == null) { status = $"Префаб {e.guid} не найден (бандлов {loaded.Count}, не загрузилось {failed})"; return; }
        var spec = new HsRender.Layer { prefab = e.guid, usePos = true, pos = new[] { -7.59f, 0f, -7.01f } };
        innerInfo = "";
        // Timeline ведёт аниматоры (клипы контроллеров бывают чужие); без Timeline — самый длинный клип
        if (prefab.GetComponentsInChildren<PlayableDirector>(true).Length > 0) spec.clip = "timeline";
        // обёртка (*_Super, у героев *_FX; у рыцарей смерти ICC в ней лишь лиана): сам спелл —
        // корневой префаб из её зависимостей, если в нём рендереров больше, чем в обёртке
        var cands = EditorUtility.CollectDependencies(new UnityEngine.Object[] { prefab }).OfType<GameObject>()
            .Where(g => g != prefab && g.transform.parent == null)
            .OrderByDescending(g => g.GetComponentsInChildren<Renderer>(true).Length).ToList();
        innerInfo = string.Join(", ", cands.Select(g => $"{g.name} {g.GetComponentsInChildren<Renderer>(true).Length}"));
        var inner = cands.FirstOrDefault();
        if (inner != null && inner.GetComponentsInChildren<Renderer>(true).Length > prefab.GetComponentsInChildren<Renderer>(true).Length)
        {
            spec.spell = inner.name;
            spec.clip = inner.GetComponentsInChildren<PlayableDirector>(true).Length > 0 ? "timeline" : "";
        }
        live = HsRender.Spawn(spec);
        if (live == null) { status = "Не вышло: " + HsRender.Last; return; }
        live.root.name = Mark + live.root.name;
        foreach (var tr in live.root.GetComponentsInChildren<Transform>(true)) tr.gameObject.hideFlags = HideFlags.HideAndDontSave;
        // спелл по FSM (Onyxia): корень выключен, его включает код HS — включить узлы-контейнеры
        var nodes = live.root.GetComponentsInChildren<Transform>(true);
        if (!nodes.Any(tr => tr.gameObject.activeInHierarchy && tr.GetComponent<Renderer>() != null))
            foreach (var tr in nodes)
                if (!tr.gameObject.activeSelf && tr.GetComponent<Renderer>() == null && tr.GetComponent<ParticleSystem>() == null)
                    tr.gameObject.SetActive(true);
        // жетон HS: только его сетки (в узлах OnToken / Token_Root у старых карт — весь эффект)
        if (hideToken)
            foreach (var tr in nodes.Where(tr => TokenRx.IsMatch(tr.name)))
                foreach (var r in tr.GetComponentsInChildren<Renderer>(true))
                    if (r is MeshRenderer || r is SkinnedMeshRenderer) r.enabled = false;
        lives.Add(live);
        // длина петли: Timeline и клипы + хвост
        float end = 0f;
        foreach (var d in live.dirs) end = Mathf.Max(end, (float)d.duration);
        foreach (var c in live.clips) end = Mathf.Max(end, c.at + c.clip.length);
        len = end > 0f ? Mathf.Clamp(end + 0.6f, 2.5f, 12f) : 5f;
        if (cam == null)
        {
            cam = HsRender.MakeCamera();
            cam.name = Mark + "cam";
            cam.gameObject.hideFlags = HideFlags.HideAndDontSave;
            cam.backgroundColor = new Color(0.07f, 0.07f, 0.09f);
            cam.allowHDR = false;
            rt = new RenderTexture(1280, 720, 24, RenderTextureFormat.ARGB32);
            cam.targetTexture = rt;
            cam.aspect = 16f / 9f;
        }
        var n = live.root.GetComponentsInChildren<Renderer>(true).Length;
        status = $"{prefab.name}{(spec.spell != "" ? " → " + spec.spell : "")}: бандлов {loaded.Count}" + (failed > 0 ? $" (не загрузилось {failed})" : "") +
            $", рендереров {n}{(n == 0 ? " — пусто" : "")}, {len:0.#} с, загрузка {EditorApplication.timeSinceStartup - t0:0.0} с";
        if (markSeen && seen.Add(e.Key)) File.AppendAllLines(SeenPath, new[] { e.Key });
        Restart();
    }

    void Restart()
    {
        startT = EditorApplication.timeSinceStartup;
        t = 0f;
        playing = true;
        dirty = true;
    }

    void Clear(bool everything)
    {
        if (live != null && live.root != null) DestroyImmediate(live.root);
        live = null;
        lives.Clear();
        HsTimeFeature.time = -1f;
        if (!everything) return;
        if (cam != null) DestroyImmediate(cam.gameObject);
        if (rt != null) { rt.Release(); DestroyImmediate(rt); }
        foreach (var b in loaded.Values) if (b != null) b.Unload(true);
        loaded.Clear();
        HsRender.Bundles.Clear();
    }

    void Render()
    {
        if (live == null || cam == null) return;
        HsRender.Pose(lives, t);
        HsTimeFeature.time = t;
        HsTimeFeature.delta = 1f / 60f;
        cam.Render();
        HsTimeFeature.time = -1f;
    }

    void Tick()
    {
        if (live == null) return;
        if (playing)
        {
            t = (float)((EditorApplication.timeSinceStartup - startT) * Speeds[speedIdx]);
            if (t > len) Restart();
            dirty = true;
        }
        if (!dirty) return;
        dirty = false;
        Render();
        Repaint();
    }

    void Step(int d)
    {
        if (shown.Count == 0) return;
        int i = Mathf.Clamp((cur == null ? -1 : shown.IndexOf(cur)) + d, 0, shown.Count - 1);
        Select(shown[i]);
        ScrollTo(i);
    }

    // для окна карт: выбранный эффект и переход к эффекту по id карты HS (в т.ч. из «Тот же эффект»)
    public Entry Cur => cur;
    public string KindOf(string id) => all.FirstOrDefault(e => e.id == id || e.also.Split(", ").Contains(id))?.kind ?? "";
    public bool Show(string id)
    {
        var e = all.FirstOrDefault(x => x.id == id) ?? all.FirstOrDefault(x => x.also.Split(", ").Contains(id));
        if (e == null) return false;
        if (!shown.Contains(e)) { search = ""; setIdx = 0; favMode = 0; unseenOnly = false; hideUsed = false; Refilter(); }
        Select(e);
        ScrollTo(shown.IndexOf(e));
        Repaint();
        return true;
    }

    void ScrollTo(int i)
    {
        // строка в поле списка
        float y = i * RowH, h = position.height - 60f;
        if (y < scroll.y) scroll.y = y;
        else if (y + RowH > scroll.y + h) scroll.y = y + RowH - h;
    }

    const float RowH = 20f, ListW = 320f;
    GUIStyle rowStyle, starStyle;

    void OnGUI()
    {
        rowStyle ??= new GUIStyle(EditorStyles.label) { padding = new RectOffset(4, 4, 2, 2) };
        starStyle ??= new GUIStyle(EditorStyles.label) { fontSize = 15, alignment = TextAnchor.MiddleCenter };
        var ev = Event.current;
        if (ev.type == EventType.KeyDown)
        {
            bool typing = EditorGUIUtility.editingTextField;
            if (ev.keyCode == KeyCode.DownArrow) { Step(1); ev.Use(); }
            else if (ev.keyCode == KeyCode.UpArrow) { Step(-1); ev.Use(); }
            else if (!typing && (ev.keyCode == KeyCode.Space || ev.keyCode == KeyCode.F) && cur != null) { ToggleFav(cur); ev.Use(); }
            else if (!typing && ev.keyCode == KeyCode.R && cur != null) { Restart(); ev.Use(); }
        }

        using (new EditorGUILayout.HorizontalScope(EditorStyles.toolbar))
        {
            EditorGUI.BeginChangeCheck();
            search = EditorGUILayout.TextField(search, EditorStyles.toolbarSearchField, GUILayout.Width(140));
            setIdx = EditorGUILayout.Popup(setIdx, setNames, EditorStyles.toolbarPopup, GUILayout.Width(140));
            sortIdx = EditorGUILayout.Popup(sortIdx, Sorts, EditorStyles.toolbarPopup, GUILayout.Width(140));
            favMode = EditorGUILayout.Popup(favMode, new[] { "★: все", $"★: только избранное ({favs.Count})", "★: без избранного" }, EditorStyles.toolbarPopup, GUILayout.Width(120));
            unseenOnly = GUILayout.Toggle(unseenOnly, "Не смотрел", EditorStyles.toolbarButton);
            hideUsed = GUILayout.Toggle(hideUsed, "Скрыть занятые", EditorStyles.toolbarButton);
            if (EditorGUI.EndChangeCheck()) Refilter();
            GUILayout.FlexibleSpace();
        }
        // вторая строка — окно бывает узким (рядом окно карт)
        using (new EditorGUILayout.HorizontalScope(EditorStyles.toolbar))
        {
            GUILayout.Label($"  {shown.Count} из {all.Count}, просмотрено {seen.Count}", EditorStyles.miniLabel);
            GUILayout.FlexibleSpace();
            showCards = GUILayout.Toggle(showCards, "Карты Tyrants", EditorStyles.toolbarButton);
            EditorGUI.BeginChangeCheck();
            hideToken = GUILayout.Toggle(hideToken, "Прятать жетон HS", EditorStyles.toolbarButton);
            if (EditorGUI.EndChangeCheck() && cur != null) Select(cur, false);
            GUILayout.Label("Скорость", EditorStyles.miniLabel);
            speedIdx = EditorGUILayout.Popup(speedIdx, new[] { "×0.25", "×0.5", "×1" }, EditorStyles.toolbarPopup, GUILayout.Width(60));
        }

        using (new EditorGUILayout.HorizontalScope())
        {
            // список: рисуются только видимые строки
            scroll = EditorGUILayout.BeginScrollView(scroll, GUILayout.Width(ListW));
            var area = GUILayoutUtility.GetRect(ListW - 20f, shown.Count * RowH);
            int first = Mathf.Max(0, (int)(scroll.y / RowH)), last = Mathf.Min(shown.Count, first + (int)(position.height / RowH) + 2);
            for (int i = first; i < last; i++)
            {
                var e = shown[i];
                var r = new Rect(area.x, area.y + i * RowH, area.width, RowH);
                if (e == cur) EditorGUI.DrawRect(r, new Color(0.17f, 0.36f, 0.53f));
                bool fav = favs.ContainsKey(e.Key);
                var old = GUI.contentColor;
                GUI.contentColor = fav ? new Color(1f, 0.82f, 0.2f) : new Color(1f, 1f, 1f, 0.3f);
                if (GUI.Button(new Rect(r.x, r.y, 22f, RowH), fav ? "★" : "☆", starStyle)) ToggleFav(e);
                GUI.contentColor = seen.Contains(e.Key) && e != cur ? new Color(1f, 1f, 1f, 0.5f) : old;
                GUI.Label(new Rect(r.x + 22f, r.y + 2f, 46f, RowH), e.set, EditorStyles.miniLabel);
                var label = e.name + "   " + e.id + (e.kind != "CustomSummon" ? "  (" + e.kind.Replace("CustomSummon", "").Replace("Custom", "") + ")" : "") +
                    (e.also != "" ? $"   +{e.also.Split(',').Length}" : "") + HsCards.AssignedTo(e.id, e.also, "   → ");
                if (GUI.Button(new Rect(r.x + 66f, r.y, r.width - 66f, RowH), label, rowStyle)) Select(e);
                GUI.contentColor = old;
            }
            EditorGUILayout.EndScrollView();

            float cw = showCards ? Mathf.Clamp(position.width * 0.4f, 430f, 640f) : 0f;
            using (new EditorGUILayout.VerticalScope(GUILayout.Width(position.width - ListW - cw - 8f)))
            {
                var box = GUILayoutUtility.GetRect(100f, 100f, GUILayout.ExpandWidth(true), GUILayout.ExpandHeight(true));
                float w = Mathf.Min(box.width, box.height * 16f / 9f), h = w * 9f / 16f;
                var view = new Rect(box.x + (box.width - w) / 2f, box.y + (box.height - h) / 2f, w, h);
                EditorGUI.DrawRect(view, new Color(0.07f, 0.07f, 0.09f));
                if (rt != null && live != null) GUI.DrawTexture(view, rt, ScaleMode.ScaleToFit, false);
                else GUI.Label(view, cur == null ? "  Выбери карту слева (↑↓ — листать)" : "", EditorStyles.boldLabel);

                if (cur != null)
                    using (new EditorGUILayout.HorizontalScope())
                    {
                        bool fav = favs.ContainsKey(cur.Key);
                        if (GUILayout.Button(fav ? "★ В избранном" : "☆ В избранное", GUILayout.Width(130), GUILayout.Height(24))) ToggleFav(cur);
                        GUILayout.Label($"{cur.name}  {cur.id}", EditorStyles.boldLabel, GUILayout.Height(24));
                        GUILayout.FlexibleSpace();
                        if (GUILayout.Button(playing ? "Пауза" : "Играть", GUILayout.Width(70), GUILayout.Height(24)))
                        {
                            playing = !playing;
                            startT = EditorApplication.timeSinceStartup - t / Speeds[speedIdx];
                        }
                        if (GUILayout.Button("Заново (R)", GUILayout.Width(90), GUILayout.Height(24))) Restart();
                    }
                using (new EditorGUILayout.HorizontalScope())
                {
                    EditorGUI.BeginChangeCheck();
                    var nt = EditorGUILayout.Slider(t, 0f, len);
                    if (EditorGUI.EndChangeCheck()) { t = nt; playing = false; dirty = true; }
                }
                GUILayout.Label(status, EditorStyles.wordWrappedMiniLabel);
                if (cur != null && cur.also != "") GUILayout.Label("Тот же эффект: " + cur.also, EditorStyles.wordWrappedMiniLabel);
                if (cur != null && HsCards.AssignedTo(cur.id, cur.also, "") != "") GUILayout.Label("Назначен на карту: " + HsCards.AssignedTo(cur.id, cur.also, ""), EditorStyles.boldLabel);
                GUILayout.Label("↑↓ — следующая/предыдущая, Пробел или F — избранное, R — заново. Избранное: hs_unity/data/hs_favorites.tsv", EditorStyles.miniLabel);
            }
            if (showCards)
            {
                using (new EditorGUILayout.VerticalScope(GUILayout.Width(cw)))
                    cards.Draw(this, cw, position.height - 40f);
            }
        }
    }

    Texture2D shotTex => tex ??= new Texture2D(1280, 720, TextureFormat.RGB24, false);
    Texture2D tex;

    // кадр окна в shotTex; доля точек, заметно отличных от фона (каждая 4-я по обеим осям)
    float Grab()
    {
        RenderTexture.active = rt;
        shotTex.ReadPixels(new Rect(0, 0, 1280, 720), 0, 0);
        RenderTexture.active = null;
        var px = shotTex.GetPixels32();
        var bg = (Color32)cam.backgroundColor;
        int hit = 0, n = 0;
        for (int y = 0; y < 720; y += 4)
            for (int x = 0; x < 1280; x += 4, n++)
            {
                var c = px[y * 1280 + x];
                if (Math.Abs(c.r - bg.r) + Math.Abs(c.g - bg.g) + Math.Abs(c.b - bg.b) > 40) hit++;
            }
        return (float)hit / n;
    }

    // проверка в настоящем окне (Unity без -batchmode): -hsb-cards ID,ID — каждая карта
    // играет 1.5 с как по клику, доля экрана с эффектом — в smoke.txt; Unity закрывается сам
    public static void Smoke()
    {
        var a = Environment.GetCommandLineArgs();
        string Arg(string n) { int k = Array.IndexOf(a, "-hsb-" + n); return k >= 0 && k + 1 < a.Length ? a[k + 1] : ""; }
        var outDir = Arg("out");
        Directory.CreateDirectory(outDir);
        var ids = Arg("cards").Split(',');
        var w = GetWindow<HsBrowser>();
        var res = new List<string>();
        int i = -1;
        double next = 0;
        EditorApplication.CallbackFunction step = null;
        step = () =>
        {
            if (EditorApplication.timeSinceStartup < next) return;
            if (i >= 0)
                res.Add($"{ids[i]}\t{(w.live != null && w.rt != null ? w.Grab().ToString("0.0000") : "-")}\t{w.status}");
            if (++i >= ids.Length)
            {
                File.WriteAllLines(Path.Combine(outDir, "smoke.txt"), res);
                EditorApplication.update -= step;
                EditorApplication.Exit(0);
                return;
            }
            var e = w.all.FirstOrDefault(x => x.id == ids[i]);
            if (e != null) w.Select(e, false);
            else { w.Clear(false); w.status = "нет в списке"; }
            next = EditorApplication.timeSinceStartup + 1.5;
        };
        EditorApplication.update += step;
    }

    // проверка без окна: -hsb-cards ID,ID — кадры 0.5/1.5/2.5 с в PNG; all — все карты подряд
    // (с -hsb-from N, -hsb-to M): сколько экрана занимает эффект (лучший кадр — JPG), в progress.txt
    public static void Test()
    {
        var a = Environment.GetCommandLineArgs();
        string Arg(string n) { int i = Array.IndexOf(a, "-hsb-" + n); return i >= 0 && i + 1 < a.Length ? a[i + 1] : ""; }
        var outDir = Arg("out");
        Directory.CreateDirectory(outDir);
        var w = CreateInstance<HsBrowser>();
        var tex = w.shotTex;
        float Shot(float s)
        {
            w.t = s;
            w.Render();
            return w.Grab();
        }
        try
        {
            if (Arg("cards") == "all")
            {
                int from = int.TryParse(Arg("from"), out var f0) ? f0 : 0;
                var list = w.all.OrderBy(x => x.order).ThenBy(x => x.id).ToList();
                int to = int.TryParse(Arg("to"), out var t0) ? Math.Min(t0, list.Count) : list.Count;
                for (int i = from; i < to; i++)
                {
                    var e = list[i];
                    w.Select(e, false);
                    string line = $"{i}\t{e.id}\t{e.kind}\t";
                    if (w.live != null)
                    {
                        float best = 0f, at = 0f;
                        for (float s = 0.25f; s <= w.len; s += 0.25f)
                        {
                            float v = Shot(s);
                            if (v > best) { best = v; at = s; }
                        }
                        if (best > 0f)
                        {
                            Shot(at);
                            File.WriteAllBytes(Path.Combine(outDir, $"{e.id}_{e.kind}.jpg"), tex.EncodeToJPG(70));
                        }
                        line += $"{best:0.0000}\t{at:0.00}\t";
                    }
                    else line += "-\t-\t";
                    File.AppendAllText(Path.Combine(outDir, "progress.txt"), line + w.status + "\n");
                }
                return;
            }
            var log = new List<string>();
            foreach (var id in Arg("cards").Split(','))
            {
                var e = w.all.FirstOrDefault(x => x.id == id);
                if (e == null) { log.Add(id + ": нет в списке"); continue; }
                w.Select(e, false);
                log.Add(id + ": " + w.status);
                if (w.innerInfo != "") log.Add("  обёртка: " + w.innerInfo);
                if (w.live == null) continue;
                foreach (var s in new[] { 0.5f, 1.5f, 2.5f })
                {
                    log.Add($"  {s:0.0} с: {Shot(s):0.0000}");
                    File.WriteAllBytes(Path.Combine(outDir, $"{id}_{s:0.0}.png"), tex.EncodeToPNG());
                }
                // где рендереры (пустой кадр: всё выключено или вне камеры)
                foreach (var r in w.live.root.GetComponentsInChildren<Renderer>(true))
                    log.Add($"    {r.name} active={r.gameObject.activeInHierarchy} enabled={r.enabled} visible={r.isVisible} " +
                        $"center={r.bounds.center} size={r.bounds.size} {r.GetType().Name} " +
                        string.Join(",", r.sharedMaterials.Where(m => m != null).Select(m => m.shader.name + (m.shader.isSupported ? "" : "!"))));
            }
            File.WriteAllLines(Path.Combine(outDir, "test.txt"), log);
        }
        catch (Exception ex) { File.AppendAllText(Path.Combine(outDir, "progress.txt"), "ERROR " + ex + "\n"); }
        finally { DestroyImmediate(w); }
    }
}
