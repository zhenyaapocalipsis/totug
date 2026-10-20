// Запекание эффектов Hearthstone в кадры для игры (Godot, HsPlay).
//
// Unity рисует оригинальные префабы HS из бандлов игры его же шейдерами, частицами и
// Timeline — с камеры доски HS. Кадр рисуется дважды, на чёрном и белом фоне: из пары
// восстанавливаются цвет (premultiplied) и непрозрачность, затем кадр уменьшается вдвое
// (1920x1080 -> 960x540, сетка игры) и пишется PNG; рядом meta.json.
//
//   Unity.exe -batchmode -quit -projectPath hs_unity -executeMethod HsRender.Run
//     -hsr-win <Hearthstone/Data/Win> -hsr-recipe <recipes/имя.json> -hsr-out <папка>
//     [-hsr-mode bake|probe] [-hsr-frames 0,10,20]   (только эти кадры — для проверки)
//
// Рецепт (JSON): deps (список бандлов от `hsx deps`), fps, len, space (gamma|linear),
// ldr (8-битный буфер, как у HS), layers[] — префабы: prefab (guid в каталоге HS),
// spell (имя корня спелла, если префаб — обёртка), at (секунда старта), pos/usePos,
// only (оставить одно поддерево), place/usePlace (куда поставить only), scale, clip (имя
// клипа аниматора; пусто — самый длинный), hide[] (пути от корня, не рисовать),
// measure[] (пути: в лог — прямоугольник на экране 960x540);
// textures[] — замены текстур HS своими (name — имя текстуры HS, file — PNG).
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using UnityEditor;
using UnityEngine;
using UnityEngine.Playables;
using UnityEngine.Rendering;

public static class HsRender
{
    [Serializable] public class TexSwap { public string name; public string file; }

    [Serializable]
    public class Layer
    {
        public string prefab;
        public string spell = "";
        public float at;
        public float[] pos = new float[3];
        public bool usePos;
        public string only = "";
        public float[] place = new float[3];
        public bool usePlace;
        public float scale = 1f;
        public string clip = "";
        // клипы аниматора по очереди (состояния FSM): name, at — секунда от начала слоя
        public ClipAt[] clips = new ClipAt[0];
        // секунда (от начала слоя), когда частицы перестают рождаться (ParticleStopAction); < 0 — никогда
        public float stopAt = -1f;
        public string[] hide = new string[0];
        public string[] measure = new string[0];
        // узлы, которые игра кладёт ПОД карту (своя дорожка кадров u###.png)
        public string[] under = new string[0];
        public MatSet[] mats = new MatSet[0];
        // сдвиг узлов в мире (позиция которых не анимирована): node, by [x, y, z]
        public Move[] move = new Move[0];
        // узлы, частицы которых не рисовать (всё поддерево; сетки остаются)
        public string[] hidePS = new string[0];
        // частицы под своей дорожкой HS (ControlRandomizedTrack — без кода игры Timeline
        // её не играет): node, start, end — секунды от начала слоя
        public Control[] controls = new Control[0];
    }

    [Serializable]
    public class Control
    {
        public string node;
        public float start;
        public float end;
    }

    [Serializable]
    public class ClipAt
    {
        public string name;
        public float at;
    }

    [Serializable]
    public class Move
    {
        public string node;
        public float[] by = new float[3];
    }

    // правка свойства материала узла: value для float, color (rgba) для цвета
    [Serializable]
    public class MatSet
    {
        public string node;
        public string prop;
        public float value;
        public float[] color = new float[0];
    }

    [Serializable]
    public class Recipe
    {
        public string deps;
        public int fps = 20;
        public float len = 4.6f;
        public string space = "gamma";
        public bool ldr = true;
        public Layer[] layers = new Layer[0];
        public TexSwap[] textures = new TexSwap[0];
    }

    // слой в сцене: корень, его директоры, аниматоры с клипами и «свои» частицы
    class Live
    {
        public Layer spec;
        public GameObject root;
        public PlayableDirector[] dirs;
        public (GameObject go, AnimationClip clip, float at)[] clips;
        public ParticleSystem[] loose;
        public Renderer[] under = new Renderer[0];
        public (GameObject go, ParticleSystem[] ps, float start, float end)[] controls = new (GameObject, ParticleSystem[], float, float)[0];
    }

    // камера доски HS (BoardCameras/Main Camera)
    static readonly Vector3 CamPos = new Vector3(-7.795f, 19.598f, -5.965f);
    static readonly Vector3 CamFwd = new Vector3(0f, -0.998f, 0.056f);
    static readonly Vector3 CamUp = new Vector3(0f, 0.056f, 0.998f);
    const float CamFov = 34.87f;
    const int W = 1920, H = 1080;

    static readonly List<AssetBundle> Bundles = new List<AssetBundle>();
    static readonly StringBuilder log = new StringBuilder();

    static string Arg(string name, string def = "")
    {
        var a = Environment.GetCommandLineArgs();
        int i = Array.IndexOf(a, "-hsr-" + name);
        return i >= 0 && i + 1 < a.Length ? a[i + 1] : def;
    }

    static void Log(string s)
    {
        log.AppendLine(s);
        Debug.Log("[hsr] " + s);
    }

    static Vector3 V(float[] a) => new Vector3(a[0], a[1], a[2]);

    public static void Run()
    {
        var outDir = Arg("out");
        Directory.CreateDirectory(outDir);
        try
        {
            var recipePath = Arg("recipe");
            var recipe = JsonUtility.FromJson<Recipe>(File.ReadAllText(recipePath));
            var space = recipe.space == "gamma" ? ColorSpace.Gamma : ColorSpace.Linear;
            if (PlayerSettings.colorSpace != space) PlayerSettings.colorSpace = space;
            Log("color space " + QualitySettings.activeColorSpace);
            EnsureTimeFeature();
            Main(recipe, Path.GetDirectoryName(Path.GetFullPath(recipePath)), outDir);
        }
        catch (Exception e) { Log("ERROR " + e); }
        finally
        {
            File.WriteAllText(Path.Combine(outDir, "hsr_log.txt"), log.ToString());
            foreach (var b in Bundles) b.Unload(true);
            Bundles.Clear();
        }
    }

    // время шейдеров = время кадра (HsTimeFeature) — во всех рендерерах URP проекта
    static void EnsureTimeFeature()
    {
        foreach (var guid in AssetDatabase.FindAssets("t:UniversalRendererData"))
        {
            var path = AssetDatabase.GUIDToAssetPath(guid);
            if (!path.StartsWith("Assets/")) continue;
            var data = AssetDatabase.LoadAssetAtPath<UnityEngine.Rendering.Universal.UniversalRendererData>(path);
            if (data == null || data.rendererFeatures.Any(f => f is HsTimeFeature)) continue;
            var feature = ScriptableObject.CreateInstance<HsTimeFeature>();
            feature.name = "HsTime";
            AssetDatabase.AddObjectToAsset(feature, data);
            data.rendererFeatures.Add(feature);
            data.SetDirty();
            EditorUtility.SetDirty(data);
            AssetDatabase.SaveAssets();
            Log("time feature added to " + path);
        }
    }

    static void Main(Recipe recipe, string baseDir, string outDir)
    {
        var win = Arg("win");
        int failed = 0;
        foreach (var line in File.ReadAllLines(Path.Combine(baseDir, recipe.deps)))
        {
            if (!line.StartsWith("bundle ")) continue;
            var b = AssetBundle.LoadFromFile(Path.Combine(win, line.Substring(7).Trim()));
            if (b != null) Bundles.Add(b); else failed++;
        }
        Log($"bundles loaded {Bundles.Count}, failed {failed}");

        var lives = new List<Live>();
        foreach (var spec in recipe.layers)
        {
            var live = Spawn(spec);
            if (live == null) return;
            lives.Add(live);
        }
        SwapTextures(recipe, baseDir, lives);
        var cam = MakeCamera();
        if (Arg("mode", "bake") == "probe")
        {
            foreach (var l in lives) Probe(l, outDir);
            return;
        }
        Bake(recipe, lives, cam, outDir);
    }

    static Live Spawn(Layer spec)
    {
        GameObject prefab = null;
        foreach (var b in Bundles)
            if (b.Contains(spec.prefab)) { prefab = b.LoadAsset<GameObject>(spec.prefab); break; }
        if (prefab == null) { Log("prefab not found " + spec.prefab); return null; }
        // обёртка (Super) ссылается на сам спелл — он загружен вместе с ней
        var src = prefab;
        if (spec.spell != "")
        {
            src = Resources.FindObjectsOfTypeAll<GameObject>()
                .FirstOrDefault(g => g.name == spec.spell && g.transform.parent == null && !g.scene.IsValid());
            if (src == null) { Log("spell not found " + spec.spell); return null; }
        }
        var go = UnityEngine.Object.Instantiate(src);
        go.name = src.name;
        if (spec.usePos) go.transform.position = V(spec.pos);
        Log($"layer {go.name} at {spec.at}");

        foreach (var p in spec.hide)
        {
            var t = go.transform.Find(p);
            if (t != null) t.gameObject.SetActive(false); else Log("hide: not found " + p);
        }
        Transform focus = go.transform;
        if (spec.only != "")
        {
            focus = go.transform.Find(spec.only);
            if (focus == null) { Log("only: not found " + spec.only); return null; }
            // всё, что не на пути к focus и не под ним, выключается
            for (var t = focus; t != go.transform; t = t.parent)
                foreach (Transform sib in t.parent)
                    if (sib != t) sib.gameObject.SetActive(false);
            if (spec.usePlace) focus.position = V(spec.place);
            focus.localScale *= spec.scale;
        }

        foreach (var mv in spec.move)
        {
            var t = go.transform.Find(mv.node);
            if (t != null) t.position += V(mv.by); else Log("move: not found " + mv.node);
        }
        foreach (var ms in spec.mats)
        {
            var t = go.transform.Find(ms.node);
            var r = t ? t.GetComponent<Renderer>() : null;
            if (r == null) { Log("mats: not found " + ms.node); continue; }
            var m = r.material;  // свой экземпляр, общий материал бандла не трогаем
            if (ms.color.Length == 4) m.SetColor(ms.prop, new Color(ms.color[0], ms.color[1], ms.color[2], ms.color[3]));
            else m.SetFloat(ms.prop, ms.value);
        }
        var live = new Live { spec = spec, root = go };
        live.under = spec.under.Select(p => go.transform.Find(p)).Where(t => t != null)
            .SelectMany(t => t.GetComponentsInChildren<Renderer>(true)).ToArray();
        live.dirs = focus.GetComponentsInChildren<PlayableDirector>(true);
        foreach (var d in live.dirs)
        {
            d.timeUpdateMode = DirectorUpdateMode.Manual;
            d.playOnAwake = false;
            d.RebuildGraph();
        }
        var clips = new List<(GameObject, AnimationClip, float)>();
        foreach (var an in focus.GetComponentsInChildren<Animator>(true))
        {
            var cs = an.runtimeAnimatorController ? an.runtimeAnimatorController.animationClips : new AnimationClip[0];
            Log($"animator {an.name}: " + string.Join(", ", cs.Select(c => $"{c.name} {c.length:0.###}s")));
            an.enabled = false;
            if (spec.clips.Length > 0)
            {
                // состояния аниматора по сценарию (FSM): клип с секунды at от начала слоя
                foreach (var ca in spec.clips)
                {
                    var c = cs.FirstOrDefault(x => x.name == ca.name);
                    if (c != null) clips.Add((an.gameObject, c, ca.at)); else Log("clip not found " + ca.name);
                }
                continue;
            }
            var clip = spec.clip != "" ? cs.FirstOrDefault(c => c.name == spec.clip) : cs.OrderByDescending(c => c.length).FirstOrDefault();
            if (clip != null) clips.Add((an.gameObject, clip, 0f));
        }
        live.clips = clips.ToArray();
        // частицы, которыми не управляет Timeline, проигрываются с начала слоя; зерно
        // случайности постоянное, иначе каждый кадр — другой набор частиц
        live.loose = focus.GetComponentsInChildren<ParticleSystem>(true)
            .Where(p => p.GetComponentInParent<PlayableDirector>(true) == null).ToArray();
        uint seed = 1;
        foreach (var p in focus.GetComponentsInChildren<ParticleSystem>(true))
        {
            p.Stop(false, ParticleSystemStopBehavior.StopEmittingAndClear);
            p.useAutoRandomSeed = false;
            p.randomSeed = 7919u * seed++;
        }
        foreach (var p in spec.hidePS)
        {
            var t = go.transform.Find(p);
            if (t == null) { Log("hidePS: not found " + p); continue; }
            foreach (var r in t.GetComponentsInChildren<ParticleSystemRenderer>(true)) r.enabled = false;
        }
        var ctl = new List<(GameObject, ParticleSystem[], float, float)>();
        foreach (var c in spec.controls)
        {
            var t = go.transform.Find(c.node);
            if (t == null) { Log("controls: not found " + c.node); continue; }
            ctl.Add((t.gameObject, t.GetComponentsInChildren<ParticleSystem>(true), c.start, c.end));
        }
        live.controls = ctl.ToArray();
        return live;
    }

    static void SwapTextures(Recipe recipe, string baseDir, List<Live> lives)
    {
        if (recipe.textures.Length == 0) return;
        var mine = new Dictionary<string, Texture2D>();
        foreach (var s in recipe.textures)
        {
            var tex = new Texture2D(2, 2, TextureFormat.RGBA32, true, false);
            tex.LoadImage(File.ReadAllBytes(Path.Combine(baseDir, s.file)));
            tex.filterMode = FilterMode.Trilinear;
            tex.wrapMode = TextureWrapMode.Clamp;
            tex.Apply(true);
            tex.name = s.name + "_own";
            mine[s.name] = tex;
        }
        int swapped = 0;
        foreach (var l in lives)
            foreach (var r in l.root.GetComponentsInChildren<Renderer>(true))
                foreach (var m in r.sharedMaterials)
                {
                    if (m == null) continue;
                    foreach (var prop in m.GetTexturePropertyNames())
                    {
                        var t = m.GetTexture(prop);
                        if (t != null && mine.TryGetValue(t.name, out var own))
                        {
                            own.wrapMode = t.wrapMode;
                            m.SetTexture(prop, own);
                            swapped++;
                        }
                    }
                }
        Log($"textures swapped {swapped}");
    }

    static Camera MakeCamera()
    {
        var cam = new GameObject("HsCam").AddComponent<Camera>();
        cam.transform.position = CamPos;
        cam.transform.rotation = Quaternion.LookRotation(CamFwd, CamUp);
        cam.fieldOfView = CamFov;
        cam.nearClipPlane = 0.3f;
        cam.farClipPlane = 500f;
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.aspect = (float)W / H;
        return cam;
    }

    static void Pose(List<Live> lives, double t)
    {
        foreach (var l in lives)
        {
            double tau = t - l.spec.at;
            bool on = tau >= 0;
            if (l.root.activeSelf != on) l.root.SetActive(on);
            if (!on) continue;
            foreach (var d in l.dirs) { d.time = tau; d.Evaluate(); }
            // у каждого аниматора — последний начавшийся клип
            foreach (var g in l.clips.GroupBy(c => c.go))
            {
                var cur = g.Where(c => c.at <= tau).OrderBy(c => c.at).LastOrDefault();
                if (cur.clip != null) cur.clip.SampleAnimation(g.Key, (float)Math.Min(tau - cur.at, cur.clip.length));
            }
            // свои дорожки HS: объект включён только на своём отрезке, частицы — с его начала
            foreach (var (cgo, cps, s0, s1) in l.controls)
            {
                bool act = tau >= s0 && tau < s1;
                if (cgo.activeSelf != act) cgo.SetActive(act);
                if (!act) continue;
                foreach (var p in cps) p.Simulate((float)(tau - s0), false, true, true);
            }
            foreach (var p in l.loose)
            {
                float stop = l.spec.stopAt;
                if (stop < 0f || tau <= stop) { p.Simulate((float)tau, false, true, true); continue; }
                // частицы родились до stopAt, дальше только живут (ParticleStopAction)
                p.Simulate(stop, false, true, true);
                p.Stop(false, ParticleSystemStopBehavior.StopEmitting);
                p.Simulate((float)tau - stop, false, false, true);
            }
        }
    }

    static void Measure(List<Live> lives, Camera cam, int frame)
    {
        foreach (var l in lives)
            foreach (var path in l.spec.measure)
            {
                var t = l.root.transform.Find(path);
                var r = t ? t.GetComponent<Renderer>() : null;
                if (t != null && r == null)
                {
                    // узел без сетки — точка его позиции на экране 960x540
                    var p = cam.WorldToScreenPoint(t.position);
                    Log($"measure f{frame} {path}: point {p.x / 2:0.#}, {(H - p.y) / 2:0.#}");
                    continue;
                }
                if (r == null) continue;
                var b = r.bounds;
                float x0 = 1e9f, y0 = 1e9f, x1 = -1e9f, y1 = -1e9f;
                for (int k = 0; k < 8; k++)
                {
                    var c = b.center + Vector3.Scale(b.extents, new Vector3((k & 1) * 2 - 1, (k >> 1 & 1) * 2 - 1, (k >> 2) * 2 - 1));
                    var s = cam.WorldToScreenPoint(c);
                    // экран 960x540, y вниз
                    x0 = Mathf.Min(x0, s.x / 2); x1 = Mathf.Max(x1, s.x / 2);
                    y0 = Mathf.Min(y0, (H - s.y) / 2); y1 = Mathf.Max(y1, (H - s.y) / 2);
                }
                Log($"measure f{frame} {path}: x {x0:0.#}..{x1:0.#}  y {y0:0.#}..{y1:0.#}  ({x1 - x0:0.#} x {y1 - y0:0.#})");
            }
    }

    static void Bake(Recipe recipe, List<Live> lives, Camera cam, string outDir)
    {
        cam.allowHDR = !recipe.ldr;
        var rt = new RenderTexture(W, H, 24, recipe.ldr ? RenderTextureFormat.ARGB32 : RenderTextureFormat.ARGBHalf);
        cam.targetTexture = rt;
        var fmt = recipe.ldr ? TextureFormat.RGBA32 : TextureFormat.RGBAFloat;
        var black = new Texture2D(W, H, fmt, false, true);
        var white = new Texture2D(W, H, fmt, false, true);
        var png = new Texture2D(W / 2, H / 2, TextureFormat.RGBA32, false, true);
        int n = Mathf.CeilToInt(recipe.len * recipe.fps);
        var only = Arg("frames", "");
        var pick = only == "" ? null : new HashSet<int>(only.Split(',').Select(int.Parse));
        // -hsr-from N: дозапечь с кадра N (после сбоя)
        int from = int.Parse(Arg("from", "0"));
        var all = lives.SelectMany(l => l.root.GetComponentsInChildren<Renderer>(true)).ToArray();
        var underAll = new HashSet<Renderer>(lives.SelectMany(l => l.under));
        var underFrames = new List<int>();
        void Save(string file)
        {
            png.SetPixels32(Shot(cam, rt, black, white, file));
            // без Apply: EncodeToPNG читает пиксели из памяти, выгрузка в видеопамять не нужна
            File.WriteAllBytes(Path.Combine(outDir, file), png.EncodeToPNG());
        }
        for (int i = 0; i <= n; i++)
        {
            if (pick != null && !pick.Contains(i) || i < from) continue;
            Pose(lives, (double)i / recipe.fps);
            HsTimeFeature.time = (float)i / recipe.fps;
            HsTimeFeature.delta = 1f / recipe.fps;
            if (i % 10 == 0) Measure(lives, cam, i);
            // дорожка «над картой»: всё, кроме узлов under
            var shown = all.Where(r => r.enabled && r.gameObject.activeInHierarchy).ToArray();
            var under = shown.Where(underAll.Contains).ToArray();
            foreach (var r in under) r.enabled = false;
            Save($"f{i:000}.png");
            foreach (var r in under) r.enabled = true;
            // дорожка «под картой»: только узлы under
            if (under.Length > 0)
            {
                var rest = shown.Where(r => !underAll.Contains(r)).ToArray();
                foreach (var r in rest) r.enabled = false;
                Save($"u{i:000}.png");
                foreach (var r in rest) r.enabled = true;
                underFrames.Add(i);
            }
        }
        // дорожка «под картой» — по файлам в папке: запекание можно доделывать по частям
        var unders = Directory.GetFiles(outDir, "u*.png").Select(p => Path.GetFileNameWithoutExtension(p).Substring(1))
            .Select(int.Parse).OrderBy(x => x);
        File.WriteAllText(Path.Combine(outDir, "meta.json"),
            "{\"fps\": " + recipe.fps + ", \"frames\": " + (n + 1) + ", \"premultiplied\": true, \"under\": [" +
            string.Join(", ", unders) + "]}\n");
        HsTimeFeature.time = -1f;
        Log($"frames {n + 1}");
    }


    // кадр на чёрном и белом фоне -> premultiplied-цвет и непрозрачность, 2x2 -> 1 пиксель
    static Color32[] Shot(Camera cam, RenderTexture rt, Texture2D black, Texture2D white, string name)
    {
        foreach (var (bg, tx) in new[] { (Color.black, black), (Color.white, white) })
        {
            cam.backgroundColor = bg;
            cam.Render();
            RenderTexture.active = rt;
            tx.ReadPixels(new Rect(0, 0, W, H), 0, 0);
            RenderTexture.active = null;
        }
        var pb = black.GetPixels();
        var pw = white.GetPixels();
        var po = new Color32[W / 2 * (H / 2)];
        int nans = 0;
        for (int y = 0; y < H / 2; y++)
            for (int x = 0; x < W / 2; x++)
            {
                float r = 0, g = 0, bl = 0, a = 0;
                for (int dy = 0; dy < 2; dy++)
                    for (int dx = 0; dx < 2; dx++)
                    {
                        int k = (y * 2 + dy) * W + x * 2 + dx;
                        var cb = pb[k];
                        var cw = pw[k];
                        if (float.IsNaN(cb.r + cb.g + cb.b + cw.r + cw.g + cw.b)) { nans++; continue; }
                        r += cb.r; g += cb.g; bl += cb.b;
                        a += 1f - ((cw.r - cb.r) + (cw.g - cb.g) + (cw.b - cb.b)) / 3f;
                    }
                Color32 c32 = new Color(Mathf.Clamp01(r / 4), Mathf.Clamp01(g / 4), Mathf.Clamp01(bl / 4), Mathf.Clamp01(a / 4));
                // чисто аддитивный пиксель — альфа 1/255: игра сжимает кадры WebP с потерями
                // (альфа без потерь) и не рисует пиксели с нулевой альфой — там только шум
                if (c32.a == 0 && (c32.r | c32.g | c32.b) != 0) c32.a = 1;
                po[y * (W / 2) + x] = c32;
            }
        if (nans > 0) Log($"{name}: NaN samples {nans}");
        return po;
    }

    static void Probe(Live l, string outDir)
    {
        var sb = new StringBuilder();
        foreach (var t in l.root.GetComponentsInChildren<Transform>(true))
        {
            var names = t.GetComponents<Component>().Select(c => c == null ? "<missing>" : c.GetType().Name);
            sb.AppendLine($"{t.name}  active={t.gameObject.activeInHierarchy}  [{string.Join(", ", names)}]");
            var r = t.GetComponent<Renderer>();
            if (r != null)
                foreach (var m in r.sharedMaterials.Where(m => m != null))
                    sb.AppendLine($"    mat {m.name} shader={m.shader.name} supported={m.shader.isSupported} tex=[" +
                        string.Join(" ", m.GetTexturePropertyNames().Select(p => m.GetTexture(p)).Where(x => x != null).Select(x => x.name)) + "]");
        }
        File.AppendAllText(Path.Combine(outDir, "probe.txt"), $"=== {l.root.name}\n" + sb);
        Log("probe " + l.root.name);
    }
}
