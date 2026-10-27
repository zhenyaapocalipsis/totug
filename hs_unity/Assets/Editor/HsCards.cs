// Панель «Карты Tyrants» справа в окне HS Legendaries: уникальные карты по колодам, полная карта
// и миниатюра, назначение на карту эффекта, выбранного в списке HS (кнопка «Карты Tyrants»).
//
// Уникальные — одна копия в полуколоде (engine/godot/data/cards/half_decks.json), картинки —
// engine/godot/assets/cards_pixel и cards_mini. Уже подобранные эффекты — таблицы CARD_MAP.md.
// Назначения владельца — hs_unity/data/hs_assign.tsv (в git): по ним Claude запекает эффект
// (назначение важнее строки CARD_MAP).
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;

[Serializable]
public class HsCards
{
    class Card { public string id, name, cost, deck; }
    class Deck { public string key, name; public readonly List<Card> cards = new List<Card>(); }
    // строка CARD_MAP: легендарка HS и сделана ли карта
    class Pick { public string hsId, hsName; public bool done; }
    // назначение владельца
    class Assign { public string hsId, hsName, kind, date; }

    static string Root => Path.GetFullPath(Path.Combine(Application.dataPath, ".."));
    static string Game => Path.GetFullPath(Path.Combine(Root, "..", "engine", "godot"));
    static string AssignPath => Path.Combine(Root, "data", "hs_assign.tsv");

    static List<Deck> decks;
    static readonly Dictionary<string, Card> byId = new Dictionary<string, Card>();
    static readonly Dictionary<string, Pick> picks = new Dictionary<string, Pick>();
    static readonly Dictionary<string, Assign> assigns = new Dictionary<string, Assign>();
    // id карты HS -> карты Tyrants, у которых этот эффект (назначение или CARD_MAP)
    static readonly Dictionary<string, List<string>> users = new Dictionary<string, List<string>>();
    static string loadErr = "";

    [SerializeField] string selId = "";
    [SerializeField] List<string> closed = new List<string>();
    string search = "";
    Vector2 scroll;
    readonly Dictionary<string, Texture2D> texs = new Dictionary<string, Texture2D>();
    GUIStyle rowStyle, headStyle, boldWrap;

    public void Free()
    {
        foreach (var t in texs.Values) if (t != null) UnityEngine.Object.DestroyImmediate(t);
        texs.Clear();
    }

    static void Load()
    {
        decks = new List<Deck>();
        byId.Clear();
        picks.Clear();
        assigns.Clear();
        loadErr = "";
        var names = new Dictionary<string, (string name, string cost)>();
        var cardsPath = Path.Combine(Game, "data", "cards", "cards.json");
        var halfPath = Path.Combine(Game, "data", "cards", "half_decks.json");
        if (!File.Exists(cardsPath) || !File.Exists(halfPath)) { loadErr = "Нет " + halfPath; Users(); return; }
        foreach (Match m in Regex.Matches(File.ReadAllText(cardsPath),
                     @"""card_id"":\s*(\d+),\s*""name"":\s*""((?:[^""\\]|\\.)*)"",\s*""cost"":\s*(null|\d+)"))
            if (!names.ContainsKey(m.Groups[1].Value))
                names[m.Groups[1].Value] = (Regex.Unescape(m.Groups[2].Value), m.Groups[3].Value == "null" ? "" : m.Groups[3].Value);
        foreach (Match m in Regex.Matches(File.ReadAllText(halfPath),
                     @"""(\w+)"":\s*\{\s*""name"":\s*""([^""]*)""[^{}]*""copies"":\s*\{([^}]*)\}"))
        {
            var d = new Deck { key = m.Groups[1].Value, name = m.Groups[2].Value.Replace(" Half-Deck", "") };
            foreach (Match c in Regex.Matches(m.Groups[3].Value, @"""(\d+)"":\s*(\d+)"))
            {
                if (c.Groups[2].Value != "1") continue;
                var id = c.Groups[1].Value;
                var nc = names.TryGetValue(id, out var v) ? v : (id, "");
                var card = new Card { id = id, name = nc.Item1, cost = nc.Item2, deck = d.name };
                d.cards.Add(card);
                byId[id] = card;
            }
            d.cards.Sort((a, b2) => string.Compare(a.name, b2.name, StringComparison.OrdinalIgnoreCase));
            if (d.cards.Count > 0) decks.Add(d);
        }
        var mapPath = Path.Combine(Root, "CARD_MAP.md");
        if (File.Exists(mapPath))
            foreach (var line in File.ReadLines(mapPath))
            {
                var m = Regex.Match(line, @"^\|\s*[^|]*\((\d{5})\)\s*\|\s*([^|]*?)\s*\(([A-Za-z0-9_]+)\)\s*\|");
                if (m.Success) picks[m.Groups[1].Value] = new Pick { hsId = m.Groups[3].Value, hsName = m.Groups[2].Value, done = line.Contains("СДЕЛАНО") };
            }
        if (File.Exists(AssignPath))
            foreach (var line in File.ReadLines(AssignPath).Skip(1))
            {
                var s = line.Split('\t');
                if (s.Length >= 7) assigns[s[0]] = new Assign { hsId = s[3], hsName = s[4], kind = s[5], date = s[6] };
            }
        Users();
    }

    static void Users()
    {
        users.Clear();
        foreach (var c in byId.Values)
        {
            var hs = assigns.TryGetValue(c.id, out var a) ? a.hsId : picks.TryGetValue(c.id, out var p) ? p.hsId : null;
            if (hs == null) continue;
            if (!users.TryGetValue(hs, out var l)) users[hs] = l = new List<string>();
            l.Add(c.name);
        }
    }

    static void Save()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(AssignPath));
        var lines = new List<string> { "card_id\tcard\tdeck\ths_id\ths_name\tkind\tdate" };
        foreach (var d in decks)
            foreach (var c in d.cards)
                if (assigns.TryGetValue(c.id, out var a))
                    lines.Add($"{c.id}\t{c.name}\t{d.key}\t{a.hsId}\t{a.hsName}\t{a.kind}\t{a.date}");
        File.WriteAllLines(AssignPath, lines);
        Users();
    }

    // карты Tyrants с эффектом этой легендарки HS (id и повторы того же спелла), для HS Legendaries
    public static string AssignedTo(string id, string also, string prefix)
    {
        if (decks == null) Load();
        if (users.Count == 0) return "";
        var who = new[] { id }.Concat(also.Split(", ")).Where(x => x != "" && users.ContainsKey(x)).SelectMany(x => users[x]).Distinct().ToList();
        return who.Count == 0 ? "" : prefix + string.Join(", ", who);
    }

    static HsBrowser Browser => Resources.FindObjectsOfTypeAll<HsBrowser>().FirstOrDefault();

    Texture2D Tex(string dir, string id)
    {
        var key = dir + "/" + id;
        if (texs.TryGetValue(key, out var t)) return t;
        var path = Path.Combine(Game, "assets", dir, id + ".png");
        if (File.Exists(path))
        {
            t = new Texture2D(2, 2) { hideFlags = HideFlags.HideAndDontSave };
            t.LoadImage(File.ReadAllBytes(path));
            t.filterMode = FilterMode.Point;
        }
        return texs[key] = t;
    }

    List<Card> Visible() => decks.Where(d => !closed.Contains(d.key)).SelectMany(d => d.cards).Where(Match).ToList();
    bool Match(Card c) => search == "" || c.name.IndexOf(search, StringComparison.OrdinalIgnoreCase) >= 0 || c.id.Contains(search);

    void DoAssign(Card c, HsBrowser.Entry e)
    {
        assigns[c.id] = new Assign { hsId = e.id, hsName = e.name, kind = e.kind, date = DateTime.Now.ToString("yyyy-MM-dd") };
        Save();
    }

    // панель справа в окне HS Legendaries (отдельное окно Unity на экране 300% ставило за край)
    public void Draw(HsBrowser b, float width, float height)
    {
        if (decks == null) Load();
        rowStyle ??= new GUIStyle(EditorStyles.label) { padding = new RectOffset(18, 4, 1, 1) };
        headStyle ??= new GUIStyle(EditorStyles.foldout) { fontStyle = FontStyle.Bold };
        boldWrap ??= new GUIStyle(EditorStyles.wordWrappedLabel) { fontStyle = FontStyle.Bold };
        byId.TryGetValue(selId, out var sel);
        var bcur = b.Cur;

        var ev = Event.current;
        if (ev.type == EventType.KeyDown && !EditorGUIUtility.editingTextField &&
            (ev.keyCode == KeyCode.Return || ev.keyCode == KeyCode.KeypadEnter) && sel != null && bcur != null)
        {
            DoAssign(sel, bcur);
            ev.Use();
        }

        using (new EditorGUILayout.HorizontalScope(EditorStyles.toolbar))
        {
            search = EditorGUILayout.TextField(search, EditorStyles.toolbarSearchField, GUILayout.Width(110));
            GUILayout.Label($" {byId.Count} карт, ● {assigns.Count}", EditorStyles.miniLabel);
            GUILayout.FlexibleSpace();
            if (GUILayout.Button("Свернуть", EditorStyles.toolbarButton)) closed = decks.Select(d => d.key).ToList();
            if (GUILayout.Button("Обновить", EditorStyles.toolbarButton)) { Load(); Free(); }
        }
        if (loadErr != "") { EditorGUILayout.HelpBox(loadErr, MessageType.Error); return; }

        using (new EditorGUILayout.HorizontalScope())
        {
            // колоды и их уникальные карты; ● — назначено здесь, ✓ — сделано по CARD_MAP
            scroll = EditorGUILayout.BeginScrollView(scroll, GUILayout.Width(200));
            foreach (var d in decks)
            {
                var cards = d.cards.Where(Match).ToList();
                if (search != "" && cards.Count == 0) continue;
                bool open = !closed.Contains(d.key) || search != "";
                int nDone = d.cards.Count(c => picks.TryGetValue(c.id, out var p) && p.done), nAs = d.cards.Count(c => assigns.ContainsKey(c.id));
                bool now = EditorGUILayout.Foldout(open, $"{d.name}   {d.cards.Count}" + (nDone > 0 ? $"  ✓{nDone}" : "") + (nAs > 0 ? $"  ●{nAs}" : ""), true, headStyle);
                if (now != open && search == "") { if (now) closed.Remove(d.key); else closed.Add(d.key); }
                if (!now) continue;
                foreach (var c in cards)
                {
                    var r = GUILayoutUtility.GetRect(200f, 18f, GUILayout.ExpandWidth(true));
                    if (c == sel) EditorGUI.DrawRect(r, new Color(0.17f, 0.36f, 0.53f));
                    var old = GUI.contentColor;
                    string mark = assigns.ContainsKey(c.id) ? "●" : picks.TryGetValue(c.id, out var p) && p.done ? "✓" : "";
                    GUI.contentColor = mark == "●" ? new Color(0.45f, 1f, 0.5f) : mark == "✓" ? new Color(1f, 1f, 1f, 0.55f) : old;
                    if (GUI.Button(r, $"{mark} {c.name}" + (c.cost != "" ? $"   {c.cost}" : ""), rowStyle)) selId = c.id;
                    GUI.contentColor = old;
                }
            }
            EditorGUILayout.EndScrollView();

            using (new EditorGUILayout.VerticalScope())
            {
                if (sel == null) { GUILayout.Label("  Выбери карту в списке колод", EditorStyles.boldLabel); return; }
                GUILayout.Label($"{sel.name}   {sel.deck}   {(sel.cost != "" ? "стоимость " + sel.cost : "")}   {sel.id}", EditorStyles.boldLabel);
                // полная карта 176×254 и миниатюра 58×84 — целым масштабом, без размытия
                var full = Tex("cards_pixel", sel.id);
                var mini = Tex("cards_mini", sel.id);
                float avW = width - 210f, avH = height - 200f;
                int s = Mathf.Max(1, Mathf.FloorToInt(Mathf.Min(avH / 254f, (avW - 20f) / (176f + 58f))));
                using (new EditorGUILayout.HorizontalScope())
                {
                    var fr = GUILayoutUtility.GetRect(176f * s, 254f * s, GUILayout.ExpandWidth(false));
                    if (full != null) GUI.DrawTexture(fr, full, ScaleMode.ScaleToFit);
                    else GUI.Label(fr, "нет cards_pixel/" + sel.id + ".png");
                    GUILayout.Space(12f);
                    var mr = GUILayoutUtility.GetRect(58f * s, 84f * s, GUILayout.ExpandWidth(false));
                    if (mini != null) GUI.DrawTexture(mr, mini, ScaleMode.ScaleToFit);
                }

                GUILayout.Space(6f);
                assigns.TryGetValue(sel.id, out var a);
                picks.TryGetValue(sel.id, out var pk);
                if (pk != null)
                    GUILayout.Label($"CARD_MAP: {pk.hsName} ({pk.hsId}) — {(pk.done ? "сделано" : "подобрано, не запечено")}", EditorStyles.wordWrappedLabel);
                GUILayout.Label(a != null ? $"Назначено: {a.hsName} ({a.hsId}), {a.date}" : "Назначено: —", a != null ? boldWrap : EditorStyles.wordWrappedLabel);
                GUI.enabled = bcur != null;
                if (GUILayout.Button(bcur != null ? $"Назначить: {bcur.name}  [Enter]" : "Выбери эффект слева", GUILayout.Height(26)))
                    DoAssign(sel, bcur);
                using (new EditorGUILayout.HorizontalScope())
                {
                    GUI.enabled = a != null;
                    if (GUILayout.Button("Снять", GUILayout.Height(22))) { assigns.Remove(sel.id); Save(); }
                    var showId = a?.hsId ?? pk?.hsId;
                    GUI.enabled = showId != null && b != null;
                    if (GUILayout.Button("Показать эффект", GUILayout.Height(22)) && !b.Show(showId))
                        b.ShowNotification(new GUIContent($"{showId} нет в списке HS Legendaries"));
                    GUI.enabled = true;
                }
                if (bcur != null)
                {
                    // эффект без повторов: уже занят другой картой
                    var who = AssignedTo(bcur.id, bcur.also, "").Split(", ").Where(n => n != "" && n != sel.name).ToList();
                    if (who.Count > 0) EditorGUILayout.HelpBox($"{bcur.name} уже у: {string.Join(", ", who)}", MessageType.Warning);
                }
                GUILayout.FlexibleSpace();
                GUILayout.Label("Enter — назначить выбранный эффект. ● назначено, ✓ сделано. Файл: hs_unity/data/hs_assign.tsv", EditorStyles.wordWrappedMiniLabel);
            }
        }
    }

    // проверка: -executeMethod HsCards.Dump -hsc-out <файл> — колоды, картинки, CARD_MAP
    public static void Dump()
    {
        var a = Environment.GetCommandLineArgs();
        int k = Array.IndexOf(a, "-hsc-out");
        Load();
        var res = new List<string> { $"ошибка: {loadErr}", $"уникальных {byId.Count}, CARD_MAP {picks.Count}, назначено {assigns.Count}" };
        foreach (var d in decks)
            res.Add($"{d.key} {d.name}: {d.cards.Count}, без картинки {d.cards.Count(c => !File.Exists(Path.Combine(Game, "assets", "cards_pixel", c.id + ".png")))}, " +
                    $"без мини {d.cards.Count(c => !File.Exists(Path.Combine(Game, "assets", "cards_mini", c.id + ".png")))}, без CARD_MAP {d.cards.Count(c => !picks.ContainsKey(c.id))}, " +
                    $"без имени {d.cards.Count(c => c.name == c.id)} | {string.Join(", ", d.cards.Select(c => c.name + " " + c.cost))}");
        File.WriteAllLines(a[k + 1], res);
    }

    // снимок окна с панелью карт: -executeMethod HsCards.Shot -hsc-out <png> -hsc-card <id> -hsc-hs <id HS> [-hsc-assign 1]
    public static void Shot()
    {
        var a = Environment.GetCommandLineArgs();
        string Arg(string n) { int k = Array.IndexOf(a, "-hsc-" + n); return k >= 0 && k + 1 < a.Length ? a[k + 1] : ""; }
        HsBrowser.Open();
        var b = Browser;
        var w = b.Cards;
        w.selId = Arg("card");
        double at = EditorApplication.timeSinceStartup + 3, shotAt = 0;
        bool shown = false;
        EditorApplication.CallbackFunction step = null;
        step = () =>
        {
            var now = EditorApplication.timeSinceStartup;
            if (!shown && now > at - 2) { b.Show(Arg("hs")); shown = true; }
            if (now < at) return;
            if (shotAt == 0)
            {
                if (Arg("assign") == "1" && b.Cur != null) w.DoAssign(byId[w.selId], b.Cur);
                b.Repaint();
                shotAt = now + 0.5;
                return;
            }
            if (now < shotAt) return;
            EditorApplication.update -= step;
            var r = b.position;
            var px = UnityEditorInternal.InternalEditorUtility.ReadScreenPixel(r.position, (int)r.width, (int)r.height);
            var t = new Texture2D((int)r.width, (int)r.height, TextureFormat.RGB24, false);
            t.SetPixels(px);
            File.WriteAllBytes(Arg("out"), t.EncodeToPNG());
            File.WriteAllText(Arg("out") + ".txt", $"browser {b.position} docked {b.docked}");
            EditorApplication.Exit(0);
        };
        EditorApplication.update += step;
    }
}
