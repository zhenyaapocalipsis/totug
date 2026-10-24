using System.Text.RegularExpressions;
using AssetsTools.NET;
using AssetsTools.NET.Extra;
using AssetsTools.NET.Texture;

// hsx probe <bundle>                     - type tree flag, class counts, first containers
// hsx dump <bundle> <out.txt> [maxArr]   - every MonoBehaviour / TextAsset field tree
// hsx where <WinDir> <guid|cardId>...    - which bundle holds the asset
// hsx summons <WinDir> <out.tsv>         - every CardDef with a custom summon / spawn spell
// hsx cards <dbf.unity3d> <out.tsv>      - cardId, dbId, enUS name, rarity, type
// hsx extract <WinDir> <outDir> <cardId>... - all effects of a card: dumps, PNG, audio
var mode = args[0];
var am = new AssetsManager();

IEnumerable<(AssetsFileInstance inst, string name)> Open(string path)
{
    var bun = am.LoadBundleFile(path, true);
    var dirs = bun.file.BlockAndDirInfo.DirectoryInfos;
    for (int i = 0; i < dirs.Count; i++)
    {
        if (!bun.file.IsAssetsFile(i)) continue;
        yield return (am.LoadAssetsFileFromBundle(bun, i, false), dirs[i].Name);
    }
}

(Dictionary<string, string> cat, Dictionary<string, string> cards) LoadCatalog(string dir)
{
    var cat = new Dictionary<string, string>();
    var cards = new Dictionary<string, string>();
    foreach (var (inst, _) in Open(Path.Combine(dir, "asset_manifest.unity3d")))
        foreach (var info in inst.file.GetAssetsOfType(AssetClassID.MonoBehaviour))
        {
            var bf = am.GetBaseField(inst, info);
            var n = bf["m_Name"].AsString;
            if (n == "base_assets_catalog")
            {
                var names = bf["m_bundleNames.Array"].Children.Select(c => c.AsString).ToList();
                foreach (var a in bf["m_assets.Array"].Children)
                    cat[a["guid"].AsString] = names[a["bundleId"].AsInt];
            }
            else if (n == "cards_map")
            {
                var k = bf["map.keys.Array"].Children; var v = bf["map.values.Array"].Children;
                for (int i = 0; i < k.Count; i++) cards[k[i].AsString] = v[i].AsString;
            }
        }
    // installed locale catalogs: base (enUS) guid -> localized guid in a local bundle
    foreach (var lp in Directory.GetFiles(dir, "asset_manifest_*.unity3d"))
        foreach (var (inst, _) in Open(lp))
            foreach (var info in inst.file.GetAssetsOfType(AssetClassID.MonoBehaviour))
            {
                var bf = am.GetBaseField(inst, info);
                if (bf["m_assets"].IsDummy || bf["m_bundleNames"].IsDummy) continue;
                var names = bf["m_bundleNames.Array"].Children.Select(c => c.AsString).ToList();
                foreach (var a in bf["m_assets.Array"].Children)
                {
                    var lg = a["guid"].AsString;
                    cat[lg] = names[a["bundleId"].AsInt];
                    if (!a["baseGuid"].IsDummy) cards["@" + a["baseGuid"].AsString] = lg;
                }
            }
    return (cat, cards);
}

// CRC32 (IEEE) of a UTF-8 string — how Unity hashes animation binding paths and property names
static uint Crc32(string s)
{
    uint crc = 0xFFFFFFFF;
    foreach (var b in System.Text.Encoding.UTF8.GetBytes(s))
    {
        crc ^= b;
        for (int k = 0; k < 8; k++) crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320u : crc >> 1;
    }
    return ~crc;
}

static void DumpField(StreamWriter w, AssetTypeValueField f, int depth, int maxArr = 12)
{
    var pad = new string(' ', depth * 2);
    var v = f.Value;
    string val = v == null ? "" : v.ValueType switch
    {
        AssetValueType.String => " = \"" + f.AsString + "\"",
        AssetValueType.ByteArray => $" = <bytes {f.AsByteArray.Length}>",
        AssetValueType.Array => $" [{f.Children.Count}]",
        _ => " = " + v.AsObject
    };
    w.WriteLine($"{pad}{f.FieldName}{val}");
    int n = 0;
    foreach (var c in f.Children)
    {
        if (++n > maxArr) { w.WriteLine($"{pad}  ..."); break; }
        DumpField(w, c, depth + 1, maxArr);
    }
}

if (mode == "probe")
{
    foreach (var (inst, name) in Open(args[1]))
    {
        var f = inst.file;
        Console.WriteLine($"{name} ver={f.Metadata.UnityVersion} typetree={f.Metadata.TypeTreeEnabled} objs={f.AssetInfos.Count}");
        foreach (var g in f.AssetInfos.GroupBy(a => a.TypeId).OrderByDescending(g => g.Count()))
            Console.WriteLine($"  {(AssetClassID)g.Key}: {g.Count()}");
        foreach (var info in f.GetAssetsOfType(AssetClassID.AssetBundle))
        {
            var bf = am.GetBaseField(inst, info);
            foreach (var c in bf["m_Container.Array"].Children.Take(int.MaxValue))
                Console.WriteLine("  C " + c["first"].AsString);
        }
        foreach (var info in f.GetAssetsOfType(AssetClassID.GameObject).Take(15))
            Console.WriteLine("  GO " + am.GetBaseField(inst, info)["m_Name"].AsString);
    }
}
else if (mode == "variant")
{
    // hsx variant <bundle> <shader> <KW1,KW2,...> <out.txt> - the fragment program with exactly these keywords
    // (stereo keywords ignored): its disassembly and its parameter blob (names + numbers)
    var want = new HashSet<string>(args[3].Split(',', StringSplitOptions.RemoveEmptyEntries));
    using var w = new StreamWriter(args[4]);
    foreach (var (inst, _) in Open(args[1]))
        foreach (var info in inst.file.GetAssetsOfType(AssetClassID.Shader))
        {
            var sh = am.GetBaseField(inst, info);
            if (sh["m_ParsedForm.m_Name"].AsString != args[2]) continue;
            var blob = sh["compressedBlob.Array"].AsByteArray;
            var o0 = sh["offsets.Array"].Children[0]; var c0 = sh["compressedLengths.Array"].Children[0]; var d0 = sh["decompressedLengths.Array"].Children[0];
            uint U(AssetTypeValueField f) => f["Array"].IsDummy ? f.AsUInt : f["Array"].Children[0].AsUInt;
            var data = new byte[U(d0)];
            K4os.Compression.LZ4.LZ4Codec.Decode(blob, (int)U(o0), (int)U(c0), data, 0, data.Length);
            int count = BitConverter.ToInt32(data, 0);
            (int off, int len) Entry(int i) => (BitConverter.ToInt32(data, 4 + i * 12), BitConverter.ToInt32(data, 8 + i * 12));
            var kwNames = sh["m_ParsedForm.m_KeywordNames.Array"].Children.Select(c => c.AsString).ToList();
            int passNo = 0;
            foreach (var pass in sh["m_ParsedForm.m_SubShaders.Array"].Children[0]["m_Passes.Array"].Children)
            {
                foreach (var progName in new[] { "progVertex", "progFragment" }) {
                var pf = pass[progName];
                var plats = pf["m_PlayerSubPrograms.Array"].Children;
                var pbis = pf["m_ParameterBlobIndices.Array"].Children;
                for (int pl = 0; pl < plats.Count; pl++)
                {
                    var subs = plats[pl]["Array"].Children;
                    for (int s = 0; s < subs.Count; s++)
                    {
                        var kws = subs[s]["m_KeywordIndices.Array"].Children.Select(c => kwNames[c.AsUShort]).Where(k => !k.Contains("STEREO")).ToHashSet();
                        if (!kws.SetEquals(want)) continue;
                        int bi = (int)subs[s]["m_BlobIndex"].AsUInt;
                        int pi = pl < pbis.Count && s < pbis[pl]["Array"].Children.Count ? (int)pbis[pl]["Array"].Children[s].AsUInt : -1;
                        w.WriteLine($"=== {progName} pass {passNo} '{pass["m_Name"].AsString}' platform {pl} sub {s} blob {bi} params {pi} keywords {string.Join(",", kws)}");
                        var (off, len) = Entry(bi);
                        for (int k = off; k + 32 < off + len; k++)
                            if (data[k] == 'D' && data[k + 1] == 'X' && data[k + 2] == 'B' && data[k + 3] == 'C')
                            {
                                int size = BitConverter.ToInt32(data, k + 24);
                                w.WriteLine(Dx.Disassemble(data[k..(k + size)]));
                                break;
                            }
                        if (pi >= 0)
                        {
                            var (po, pln) = Entry(pi);
                            w.WriteLine($"--- parameter blob ({pln} bytes) raw int32:");
                            for (int q = po; q + 4 <= po + pln; q += 4) w.Write(BitConverter.ToInt32(data, q) + (data[q] >= 32 && data[q] < 127 ? "/" + (char)data[q] + (char)data[q+1] + (char)data[q+2] + (char)data[q+3] : "") + " ");
                            w.WriteLine();
                            int k = po;
                            while (k < po + pln)
                            {
                                int sl = BitConverter.ToInt32(data, k);
                                if (sl > 1 && sl < 64 && k + 4 + sl <= po + pln && data[k + 4] == '_' || (sl > 1 && sl < 64 && k + 4 + sl <= po + pln && char.IsLetter((char)data[k + 4]) && data.Skip(k + 4).Take(sl).All(b => b >= 32 && b < 127)))
                                {
                                    var str = System.Text.Encoding.ASCII.GetString(data, k + 4, sl);
                                    int after = k + 4 + ((sl + 3) & ~3);
                                    var ints = Enumerable.Range(0, 6).Select(q => after + q * 4 + 4 <= po + pln ? BitConverter.ToInt32(data, after + q * 4) : 0);
                                    w.WriteLine($"  {str}  {string.Join(" ", ints)}");
                                    k = after;
                                }
                                else k += 4;
                            }
                        }
                    }
                }
                }
                passNo++;
            }
        }
}
else if (mode == "shaders")
{
    // hsx shaders <bundle> [name <outDir>] - list shaders; with a name: every DXBC program disassembled
    foreach (var (inst, _) in Open(args[1]))
        foreach (var info in inst.file.GetAssetsOfType(AssetClassID.Shader))
        {
            var sh = am.GetBaseField(inst, info);
            var nm = sh["m_ParsedForm.m_Name"].AsString;
            var blob = sh["compressedBlob.Array"].AsByteArray ?? Array.Empty<byte>();
            if (args.Length < 4) { Console.WriteLine($"{nm}  blob={blob.Length}"); continue; }
            if (nm != args[2]) continue;
            Directory.CreateDirectory(args[3]);
            using (var pw = new StreamWriter(Path.Combine(args[3], "parsed_form.txt")))
                DumpField(pw, sh["m_ParsedForm"], 0, args.Length > 4 ? int.Parse(args[4]) : 40);
            var offs = sh["offsets.Array"].Children; var clens = sh["compressedLengths.Array"].Children; var dlens = sh["decompressedLengths.Array"].Children;
            int n = 0;
            for (int pl = 0; pl < offs.Count; pl++)
            {
                // per platform: array of segments (Unity 2019.3+): offsets[pl].Array of uint
                var oa = offs[pl]["Array"].IsDummy ? new List<AssetTypeValueField> { offs[pl] } : offs[pl]["Array"].Children;
                var ca = clens[pl]["Array"].IsDummy ? new List<AssetTypeValueField> { clens[pl] } : clens[pl]["Array"].Children;
                var da = dlens[pl]["Array"].IsDummy ? new List<AssetTypeValueField> { dlens[pl] } : dlens[pl]["Array"].Children;
                for (int sgm = 0; sgm < oa.Count; sgm++)
                {
                    int o = (int)oa[sgm].AsUInt, cl = (int)ca[sgm].AsUInt, dl = (int)da[sgm].AsUInt;
                    if (cl <= 0 || o + cl > blob.Length) continue;
                    var outb = new byte[dl];
                    int got = K4os.Compression.LZ4.LZ4Codec.Decode(blob, o, cl, outb, 0, dl);
                    File.WriteAllBytes(Path.Combine(args[3], $"plat{pl}_seg{sgm}.bin"), outb);
                    for (int k = 0; k + 32 < got; k++)
                    {
                        if (outb[k] != 'D' || outb[k + 1] != 'X' || outb[k + 2] != 'B' || outb[k + 3] != 'C') continue;
                        int size = BitConverter.ToInt32(outb, k + 24);
                        if (size <= 0 || k + size > got) continue;
                        var dx = new byte[size];
                        Array.Copy(outb, k, dx, 0, size);
                        File.WriteAllText(Path.Combine(args[3], $"p{n:000}_plat{pl}_seg{sgm}_at{k}.asm"), Dx.Disassemble(dx));
                        n++;
                        k += size - 1;
                    }
                }
            }
            Console.WriteLine($"{nm}: {n} DXBC programs -> {args[3]}");
        }
}
else if (mode == "cameras")
{
    // hsx cameras <WinDir> <glob> - every Camera: object path, world position / rotation, fov
    foreach (var path in Directory.GetFiles(args[1], args[2]))
    {
        try
        {
            foreach (var (inst, _) in Open(path))
                foreach (var info in inst.file.GetAssetsOfType(AssetClassID.Camera))
                {
                    var cam = am.GetBaseField(inst, info);
                    long goId = cam["m_GameObject.m_PathID"].AsLong;
                    var names = new List<string>();
                    var world = System.Numerics.Matrix4x4.Identity;
                    long g = goId;
                    for (int guard = 0; guard < 64 && g != 0; guard++)
                    {
                        var gf = am.GetBaseField(inst, inst.file.GetAssetInfo(g));
                        names.Insert(0, gf["m_Name"].AsString);
                        var tri = inst.file.GetAssetInfo(gf["m_Component.Array"].Children[0]["component.m_PathID"].AsLong);
                        if (tri == null) break;
                        var tf = am.GetBaseField(inst, tri);
                        var p = tf["m_LocalPosition"]; var q = tf["m_LocalRotation"]; var s = tf["m_LocalScale"];
                        var local = System.Numerics.Matrix4x4.CreateScale(s["x"].AsFloat, s["y"].AsFloat, s["z"].AsFloat)
                            * System.Numerics.Matrix4x4.CreateFromQuaternion(new System.Numerics.Quaternion(q["x"].AsFloat, q["y"].AsFloat, q["z"].AsFloat, q["w"].AsFloat))
                            * System.Numerics.Matrix4x4.CreateTranslation(p["x"].AsFloat, p["y"].AsFloat, p["z"].AsFloat);
                        world = world * local;
                        long father = tf["m_Father.m_PathID"].AsLong;
                        if (father == 0) break;
                        g = am.GetBaseField(inst, inst.file.GetAssetInfo(father))["m_GameObject.m_PathID"].AsLong;
                    }
                    var fwd = System.Numerics.Vector3.TransformNormal(new System.Numerics.Vector3(0, 0, 1), world);
                    var up = System.Numerics.Vector3.TransformNormal(new System.Numerics.Vector3(0, 1, 0), world);
                    Console.WriteLine($"{Path.GetFileName(path)} | {string.Join("/", names)} | pos=({world.M41:0.###},{world.M42:0.###},{world.M43:0.###}) fwd=({fwd.X:0.###},{fwd.Y:0.###},{fwd.Z:0.###}) up=({up.X:0.###},{up.Y:0.###},{up.Z:0.###}) fov={cam["field of view"].AsFloat:0.##} ortho={cam["orthographic"].AsBool} near={cam["near clip plane"].AsFloat} far={cam["far clip plane"].AsFloat} depth={cam["m_Depth"].AsFloat}");
                }
        }
        catch (Exception e) { Console.WriteLine($"ERR {Path.GetFileName(path)}: {e.Message}"); }
        am.UnloadAll(true);
    }
}
else if (mode == "dump")
{
    int maxArr = args.Length > 3 ? int.Parse(args[3]) : 50;
    using var w = new StreamWriter(args[2]);
    foreach (var (inst, name) in Open(args[1]))
        foreach (var info in inst.file.AssetInfos)
        {
            var t = (AssetClassID)info.TypeId;
            if (t is not (AssetClassID.MonoBehaviour or AssetClassID.TextAsset)) continue;
            w.WriteLine($"=== {t} path={info.PathId}");
            try { DumpField(w, am.GetBaseField(inst, info), 0, maxArr); }
            catch (Exception e) { w.WriteLine("ERR " + e.Message); }
        }
}
else if (mode == "fields")
{
    // hsx fields <dll> <substring> : types whose fields/methods contain the substring, with all their fields
    using var fs = File.OpenRead(args[1]);
    using var pe = new System.Reflection.PortableExecutable.PEReader(fs);
    var md = System.Reflection.Metadata.PEReaderExtensions.GetMetadataReader(pe);
    foreach (var th in md.TypeDefinitions)
    {
        var td = md.GetTypeDefinition(th);
        var fields = td.GetFields().Select(f => md.GetFieldDefinition(f)).Select(f => md.GetString(f.Name)).ToList();
        var methods = td.GetMethods().Select(m => md.GetString(md.GetMethodDefinition(m).Name)).ToList();
        if (!fields.Concat(methods).Any(n => n.Contains(args[2]))) continue;
        Console.WriteLine($"{md.GetString(td.Namespace)}.{md.GetString(td.Name)}");
        Console.WriteLine("  fields: " + string.Join(", ", fields));
        Console.WriteLine("  methods: " + string.Join(", ", methods.Take(80)));
    }
}
else if (mode == "il")
{
    // hsx il <dll> <TypeName> : IL of every method of the type, with constants, strings and call targets
    using var fs = File.OpenRead(args[1]);
    using var pe = new System.Reflection.PortableExecutable.PEReader(fs);
    var md = System.Reflection.Metadata.PEReaderExtensions.GetMetadataReader(pe);
    var ops = new Dictionary<short, System.Reflection.Emit.OpCode>();
    foreach (var f in typeof(System.Reflection.Emit.OpCodes).GetFields())
        if (f.GetValue(null) is System.Reflection.Emit.OpCode oc) ops[oc.Value] = oc;
    string Tok(int tok)
    {
        var h = System.Reflection.Metadata.Ecma335.MetadataTokens.EntityHandle(tok);
        try
        {
            switch (h.Kind)
            {
                case System.Reflection.Metadata.HandleKind.MethodDefinition:
                    { var m = md.GetMethodDefinition((System.Reflection.Metadata.MethodDefinitionHandle)h); return md.GetString(md.GetTypeDefinition(m.GetDeclaringType()).Name) + "::" + md.GetString(m.Name); }
                case System.Reflection.Metadata.HandleKind.MemberReference:
                    {
                        var m = md.GetMemberReference((System.Reflection.Metadata.MemberReferenceHandle)h);
                        string parent = m.Parent.Kind == System.Reflection.Metadata.HandleKind.TypeReference ? md.GetString(md.GetTypeReference((System.Reflection.Metadata.TypeReferenceHandle)m.Parent).Name)
                            : m.Parent.Kind == System.Reflection.Metadata.HandleKind.TypeDefinition ? md.GetString(md.GetTypeDefinition((System.Reflection.Metadata.TypeDefinitionHandle)m.Parent).Name) : "?";
                        return parent + "::" + md.GetString(m.Name);
                    }
                case System.Reflection.Metadata.HandleKind.FieldDefinition:
                    return md.GetString(md.GetFieldDefinition((System.Reflection.Metadata.FieldDefinitionHandle)h).Name);
                case System.Reflection.Metadata.HandleKind.TypeReference:
                    return md.GetString(md.GetTypeReference((System.Reflection.Metadata.TypeReferenceHandle)h).Name);
                case System.Reflection.Metadata.HandleKind.TypeDefinition:
                    return md.GetString(md.GetTypeDefinition((System.Reflection.Metadata.TypeDefinitionHandle)h).Name);
                case System.Reflection.Metadata.HandleKind.MethodSpecification:
                    return Tok(System.Reflection.Metadata.Ecma335.MetadataTokens.GetToken(md.GetMethodSpecification((System.Reflection.Metadata.MethodSpecificationHandle)h).Method)) + "<>";
            }
        }
        catch { }
        return $"tok{tok:x8}";
    }
    foreach (var th in md.TypeDefinitions)
    {
        var td = md.GetTypeDefinition(th);
        if (md.GetString(td.Name) != args[2] && !md.GetString(td.Name).StartsWith(args[2] + "+")) continue;
        foreach (var mh in td.GetMethods())
        {
            var m = md.GetMethodDefinition(mh);
            Console.WriteLine($"== {md.GetString(m.Name)}");
            if (m.RelativeVirtualAddress == 0) continue;
            var body = System.Reflection.Metadata.PEReaderExtensions.GetMethodBody(pe, m.RelativeVirtualAddress);
            var il = body.GetILBytes()!;
            int p = 0;
            while (p < il.Length)
            {
                short code = il[p] == 0xFE ? (short)(0xFE00 | il[p + 1]) : il[p];
                p += il[p] == 0xFE ? 2 : 1;
                if (!ops.TryGetValue(code, out var op)) { Console.WriteLine($"  ?{code:x}"); break; }
                string arg = "";
                switch (op.OperandType)
                {
                    case System.Reflection.Emit.OperandType.InlineNone: break;
                    case System.Reflection.Emit.OperandType.ShortInlineI: arg = ((sbyte)il[p]).ToString(); p += 1; break;
                    case System.Reflection.Emit.OperandType.ShortInlineVar: arg = il[p].ToString(); p += 1; break;
                    case System.Reflection.Emit.OperandType.ShortInlineBrTarget: arg = ((sbyte)il[p]).ToString(); p += 1; break;
                    case System.Reflection.Emit.OperandType.InlineVar: arg = BitConverter.ToInt16(il, p).ToString(); p += 2; break;
                    case System.Reflection.Emit.OperandType.InlineI: arg = BitConverter.ToInt32(il, p).ToString(); p += 4; break;
                    case System.Reflection.Emit.OperandType.InlineBrTarget: arg = BitConverter.ToInt32(il, p).ToString(); p += 4; break;
                    case System.Reflection.Emit.OperandType.ShortInlineR: arg = BitConverter.ToSingle(il, p).ToString(System.Globalization.CultureInfo.InvariantCulture); p += 4; break;
                    case System.Reflection.Emit.OperandType.InlineR: arg = BitConverter.ToDouble(il, p).ToString(System.Globalization.CultureInfo.InvariantCulture); p += 8; break;
                    case System.Reflection.Emit.OperandType.InlineI8: arg = BitConverter.ToInt64(il, p).ToString(); p += 8; break;
                    case System.Reflection.Emit.OperandType.InlineString:
                        arg = "\"" + md.GetUserString(System.Reflection.Metadata.Ecma335.MetadataTokens.UserStringHandle(BitConverter.ToInt32(il, p) & 0xFFFFFF)) + "\""; p += 4; break;
                    case System.Reflection.Emit.OperandType.InlineSwitch: { int n = BitConverter.ToInt32(il, p); p += 4 + 4 * n; arg = $"switch[{n}]"; break; }
                    default: arg = Tok(BitConverter.ToInt32(il, p)); p += 4; break;
                }
                Console.WriteLine($"  {op.Name} {arg}");
            }
        }
    }
}
else if (mode == "deps")
{
    // hsx deps <WinDir> <cabmap.tsv> <out.txt> CAB-... : bundle files a CAB needs (closure over externals),
    // plus the AssetBundle containers of the first one
    var cabMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    foreach (var l in File.ReadLines(args[2])) { var s = l.Split('\t'); cabMap[s[0]] = s[1]; }
    var todo = new Queue<string>(args.Skip(4));
    var seenCab = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    var files = new List<string>();
    using var w = new StreamWriter(args[3]);
    bool first = true;
    while (todo.Count > 0)
    {
        var cab = todo.Dequeue();
        if (!seenCab.Add(cab)) continue;
        if (!cabMap.TryGetValue(cab, out var bf)) { w.WriteLine("? " + cab); continue; }
        if (!files.Contains(bf)) files.Add(bf);
        var bun = am.LoadBundleFile(Path.Combine(args[1], bf), true);
        var dirs = bun.file.BlockAndDirInfo.DirectoryInfos;
        for (int di = 0; di < dirs.Count; di++)
        {
            var name = dirs[di].Name;
            if (!name.Equals(cab, StringComparison.OrdinalIgnoreCase)) continue;
            AssetsFileInstance inst;
            try { inst = am.LoadAssetsFileFromBundle(bun, di, false); }
            catch (Exception e) { w.WriteLine($"unreadable {cab} ({bf}): {e.Message}"); continue; }
            foreach (var ex in inst.file.Metadata.Externals)
            {
                var p = ex.PathName;
                var c = p.Contains('/') ? p[(p.LastIndexOf('/') + 1)..] : p;
                if (c.StartsWith("CAB-", StringComparison.OrdinalIgnoreCase)) todo.Enqueue(c);
                else w.WriteLine("ext " + p);
            }
            if (first)
                foreach (var info in inst.file.GetAssetsOfType(AssetClassID.AssetBundle))
                    foreach (var c in am.GetBaseField(inst, info)["m_Container.Array"].Children)
                        w.WriteLine("container " + c["first"].AsString);
        }
        first = false;
    }
    foreach (var f in files) w.WriteLine("bundle " + f);
    Console.WriteLine($"bundles {files.Count}, cabs {seenCab.Count}");
}
else if (mode == "where")
{
    var (cat, cards) = LoadCatalog(args[1]);
    foreach (var q in args.Skip(2))
    {
        var g = q;
        if (cards.TryGetValue(q, out var cv)) { Console.Write(q + " -> " + cv + " "); g = cv.Split(':')[1]; }
        Console.WriteLine(g + " -> " + (cat.TryGetValue(g, out var b) ? b : "?"));
    }
}
else if (mode == "summons")
{
    string[] keys = { "m_CustomSummonSpellPath", "m_GoldenCustomSummonSpellPath", "m_DiamondCustomSummonSpellPath",
                      "m_CustomSpawnSpellPath", "m_GoldenCustomSpawnSpellPath", "m_DiamondCustomSpawnSpellPath" };
    using var w = new StreamWriter(args[2]);
    foreach (var path in Directory.GetFiles(args[1], "carddef_*.unity3d"))
    {
        var bn = Path.GetFileName(path);
        try
        {
            foreach (var (inst, _) in Open(path))
                foreach (var info in inst.file.GetAssetsOfType(AssetClassID.MonoBehaviour))
                {
                    var cf = am.GetBaseField(inst, info);
                    if (cf["m_CustomSummonSpellPath"].IsDummy) continue;
                    var hits = keys.Where(k => !cf[k].IsDummy && cf[k].AsString != "").ToList();
                    if (hits.Count == 0) continue;
                    var go = am.GetBaseField(inst, inst.file.GetAssetInfo(cf["m_GameObject.m_PathID"].AsLong));
                    foreach (var k in hits)
                        w.WriteLine($"{go["m_Name"].AsString}\t{k}\t{cf[k].AsString}\t{bn}");
                }
        }
        catch (Exception e) { w.WriteLine($"ERR\t{bn}\t{e.Message}"); }
        am.UnloadAll(true);
    }
}
else if (mode == "cards")
{
    var recs = new Dictionary<string, List<AssetTypeValueField>>();
    foreach (var (inst, _) in Open(args[1]))
        foreach (var info in inst.file.GetAssetsOfType(AssetClassID.MonoBehaviour))
        {
            var bf = am.GetBaseField(inst, info);
            var n = bf["m_Name"].AsString;
            if (n is "CARD" or "CARD_TAG") recs[n] = bf["Records.Array"].Children;
        }
    var tags = new Dictionary<(int, int), int>();
    foreach (var r in recs["CARD_TAG"])
        tags[(r["m_cardId"].AsInt, r["m_tagId"].AsInt)] = r["m_tagValue"].AsInt;
    using var w = new StreamWriter(args[2]);
    foreach (var r in recs["CARD"])
    {
        int id = r["m_ID"].AsInt;
        var nm = r["m_name.m_locValues.Array"];
        string name = nm.IsDummy || nm.Children.Count == 0 ? "" : nm.Children[0].AsString;
        int T(int t) => tags.TryGetValue((id, t), out var v) ? v : -1;
        w.WriteLine($"{r["m_noteMiniGuid"].AsString}\t{id}\t{name}\t{T(203)}\t{T(202)}\t{T(183)}");
    }
}
else if (mode == "extract")
{
    var win = args[1];
    var outRoot = args[2];
    var (cat, cardMap) = LoadCatalog(win);

    // CAB name -> bundle file, built once from bundle headers
    var cabMapPath = Path.Combine(AppContext.BaseDirectory, "cabmap.tsv");
    if (!File.Exists(cabMapPath))
    {
        using var cw = new StreamWriter(cabMapPath);
        foreach (var p in Directory.GetFiles(win, "*.unity3d"))
        {
            try
            {
                var b = am.LoadBundleFile(p, false);
                foreach (var d in b.file.BlockAndDirInfo.DirectoryInfos) cw.WriteLine(d.Name + "\t" + Path.GetFileName(p));
                am.UnloadBundleFile(b);
            }
            catch { }
        }
    }
    var cabMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    foreach (var l in File.ReadLines(cabMapPath)) { var s = l.Split('\t'); cabMap[s[0]] = s[1]; }

    var bundles = new Dictionary<string, BundleFileInstance>();
    var files = new Dictionary<string, AssetsFileInstance?>(StringComparer.OrdinalIgnoreCase);
    var guidMap = new Dictionary<string, (AssetsFileInstance inst, long pathId)>();
    var indexed = new HashSet<string>();
    var scriptNames = new Dictionary<string, string>();

    // localized bundles: catalog names enUS, the install may hold another locale
    var locales = Directory.GetFiles(win, "asset_manifest_*.unity3d")
        .Select(p => Path.GetFileNameWithoutExtension(p).Replace("asset_manifest_", "")).ToList();
    BundleFileInstance? B(string file)
    {
        if (bundles.TryGetValue(file, out var b)) return b;
        var path = Path.Combine(win, file);
        if (!File.Exists(path))
            path = locales.Select(l => Path.Combine(win, file.Replace("_enus", "_" + l))).FirstOrDefault(File.Exists) ?? "";
        b = path == "" ? null : am.LoadBundleFile(path, true);
        bundles[file] = b!;
        return b;
    }
    AssetsFileInstance? F(string cab)
    {
        if (files.TryGetValue(cab, out var f)) return f;
        f = null;
        if (cabMap.TryGetValue(cab, out var bfile))
        {
            var b = B(bfile);
            var dirs = b?.file.BlockAndDirInfo.DirectoryInfos;
            int idx = dirs?.FindIndex(d => string.Equals(d.Name, cab, StringComparison.OrdinalIgnoreCase)) ?? -1;
            if (idx >= 0 && b!.file.IsAssetsFile(idx)) f = am.LoadAssetsFileFromBundle(b, idx, false);
        }
        files[cab] = f;
        return f;
    }
    (AssetsFileInstance inst, AssetFileInfo info)? R(AssetsFileInstance inst, int fileId, long pathId)
    {
        if (pathId == 0) return null;
        var target = inst;
        if (fileId != 0)
        {
            var exts = inst.file.Metadata.Externals;
            if (fileId - 1 >= exts.Count) return null;
            target = F(Path.GetFileName(exts[fileId - 1].PathName));
            if (target == null) return null;
        }
        var info = target.file.GetAssetInfo(pathId);
        return info == null ? null : (target, info);
    }
    (AssetsFileInstance inst, long pathId)? G(string guid)
    {
        if (cardMap.TryGetValue("@" + guid, out var localized)) guid = localized;
        if (guidMap.TryGetValue(guid, out var hit)) return hit;
        if (!cat.TryGetValue(guid, out var bfile) || !indexed.Add(bfile)) return null;
        var b = B(bfile);
        if (b == null) return null;
        foreach (var d in b.file.BlockAndDirInfo.DirectoryInfos)
        {
            var f = F(d.Name);
            if (f == null) continue;
            foreach (var abi in f.file.GetAssetsOfType(AssetClassID.AssetBundle))
                foreach (var c in am.GetBaseField(f, abi)["m_Container.Array"].Children)
                    guidMap[c["first"].AsString] = (f, c["second.asset.m_PathID"].AsLong);
        }
        return guidMap.TryGetValue(guid, out hit) ? hit : null;
    }
    string ScriptName(AssetsFileInstance inst, AssetTypeValueField mb)
    {
        var s = mb["m_Script"];
        if (s.IsDummy) return "?";
        var r = R(inst, s["m_FileID"].AsInt, s["m_PathID"].AsLong);
        if (r == null) return "?";
        var key = r.Value.inst.name + ":" + r.Value.info.PathId;
        if (!scriptNames.TryGetValue(key, out var n))
            scriptNames[key] = n = am.GetBaseField(r.Value.inst, r.Value.info)["m_ClassName"].AsString;
        return n;
    }
    string AssetName(AssetsFileInstance inst, AssetFileInfo info)
    {
        var t = (AssetClassID)info.TypeId;
        if (t is AssetClassID.Texture2D or AssetClassID.Mesh) // avoid reading big payloads twice
        {
            var bf0 = am.GetBaseField(inst, info);
            return bf0["m_Name"].AsString;
        }
        var bf = am.GetBaseField(inst, info);
        if (!bf["m_Name"].IsDummy && bf["m_Name"].AsString != "") return bf["m_Name"].AsString;
        if (t == AssetClassID.MonoBehaviour) return "<" + ScriptName(inst, bf) + ">";
        if (!bf["m_GameObject"].IsDummy)
        {
            var go = R(inst, bf["m_GameObject.m_FileID"].AsInt, bf["m_GameObject.m_PathID"].AsLong);
            if (go != null) return "on GO '" + am.GetBaseField(go.Value.inst, go.Value.info)["m_Name"].AsString + "'";
        }
        if (t == AssetClassID.Shader && !bf["m_ParsedForm.m_Name"].IsDummy) return bf["m_ParsedForm.m_Name"].AsString;
        return "";
    }
    static string Safe(string s) => Regex.Replace(s, @"[^A-Za-z0-9_\-\.]+", "_");

    var strRef = new Regex(@"^(.+)\.([A-Za-z0-9]+):([0-9a-f]{32})$");

    foreach (var cardArg in args.Skip(3))
    {
        // "EX1_298=Ragnaros" -> folder EX1_298_Ragnaros
        var cardId = cardArg.Split('=')[0];
        if (!cardMap.TryGetValue(cardId, out var cdef)) { Console.WriteLine($"{cardId}: no CardDef"); continue; }
        var cardDir = Path.Combine(outRoot, Safe(cardArg.Replace('=', '_')));
        Directory.CreateDirectory(cardDir);
        using var index = new StreamWriter(Path.Combine(cardDir, "index.txt"));
        var prefabFolders = new Dictionary<string, string>();   // guid -> folder
        var pending = new Queue<(string guid, string name, string from)>();
        // prefabs reached through an object reference (not a "name.prefab:guid" string)
        var directRefs = new Dictionary<string, (AssetsFileInstance inst, long pathId)?>();
        int counter = 0;
        int nTex = 0, nAudio = 0, nClip = 0, nPs = 0;

        string FolderFor(string guid, string name)
        {
            if (!prefabFolders.TryGetValue(guid, out var f))
            {
                prefabFolders[guid] = f = $"{counter++:00}_{Safe(name)}";
                pending.Enqueue((guid, name, ""));
            }
            return f;
        }

        // one folder per prefab; components dumped in hierarchy.txt, referenced assets exported beside it
        void ExtractPrefab(string guid, string name, string folder)
        {
            var dir = Path.Combine(cardDir, folder);
            Directory.CreateDirectory(dir);
            var g = guid.StartsWith("ref:") ? directRefs[guid] : G(guid);
            if (g == null) { index.WriteLine($"{folder}: NOT FOUND {name}:{guid}"); return; }
            var (pinst, rootId) = g.Value;
            var visited = new HashSet<string>();
            var queue = new Queue<(AssetsFileInstance, AssetFileInfo)>();
            var children = new List<string>();
            StreamWriter? refs = null, mats = null;
            bool isCardDef = folder.StartsWith("00_");

            void Walk(StreamWriter w, AssetsFileInstance inst, AssetTypeValueField f, int depth, int maxArr, string path)
            {
                var pad = new string(' ', depth * 2);
                var v = f.Value;
                // PPtr: resolve, describe, queue
                if (f.Children.Count == 2 && f.Children[0].FieldName == "m_FileID" && f.Children[1].FieldName == "m_PathID")
                {
                    long pid = f.Children[1].AsLong;
                    if (pid == 0) { w.WriteLine($"{pad}{f.FieldName} = null"); return; }
                    var r = R(inst, f.Children[0].AsInt, pid);
                    if (r == null) { w.WriteLine($"{pad}{f.FieldName} -> unresolved({f.Children[0].AsInt},{pid})"); return; }
                    var t = (AssetClassID)r.Value.info.TypeId;
                    string nm = "";
                    try { nm = AssetName(r.Value.inst, r.Value.info); } catch { }
                    w.WriteLine($"{pad}{f.FieldName} -> {t} '{nm}' #{r.Value.info.PathId}");
                    queue.Enqueue(r.Value);
                    return;
                }
                string val = v == null ? "" : v.ValueType switch
                {
                    AssetValueType.String => " = \"" + f.AsString + "\"",
                    AssetValueType.ByteArray => $" = <bytes {f.AsByteArray.Length}>",
                    AssetValueType.Array => $" [{f.Children.Count}]",
                    _ => " = " + v.AsObject
                };
                w.WriteLine($"{pad}{f.FieldName}{val}");
                if (v != null && v.ValueType == AssetValueType.String)
                {
                    var m = strRef.Match(f.AsString);
                    bool follow = !isCardDef || path.Contains("Spell") || path.Contains("Effect") || path.Contains("m_PortraitTexturePath");
                    if (m.Success && follow)
                    {
                        if (m.Groups[2].Value == "prefab")
                        {
                            var cf = FolderFor(m.Groups[3].Value, m.Groups[1].Value);
                            children.Add($"{path} -> {cf}");
                            w.WriteLine($"{pad}  (=> folder {cf})");
                        }
                        else
                        {
                            var gg = G(m.Groups[3].Value);
                            if (gg != null)
                            {
                                var info = gg.Value.inst.file.GetAssetInfo(gg.Value.pathId);
                                if (info != null) queue.Enqueue((gg.Value.inst, info));
                            }
                        }
                    }
                }
                int n = 0;
                foreach (var c in f.Children)
                {
                    if (++n > maxArr) { w.WriteLine($"{pad}  ... ({f.Children.Count} total)"); break; }
                    Walk(w, inst, c, depth + 1, maxArr, path + "." + c.FieldName);
                }
            }

            // PlayMaker FSM -> readable state list with actions and their parameters (the effect's timeline)
            string PName(AssetsFileInstance inst, AssetTypeValueField pp)
            {
                if (pp.IsDummy || pp["m_PathID"].AsLong == 0) return "null";
                var r = R(inst, pp["m_FileID"].AsInt, pp["m_PathID"].AsLong);
                if (r == null) return "?";
                try { return $"{(AssetClassID)r.Value.info.TypeId}'{AssetName(r.Value.inst, r.Value.info)}'"; } catch { return "?"; }
            }
            string Compact(AssetsFileInstance inst, AssetTypeValueField f)
            {
                if (f.IsDummy) return "?";
                if (f.Children.Count == 2 && f.Children[0].FieldName == "m_FileID") return PName(inst, f);
                if (f.Value != null && f.Value.ValueType != AssetValueType.Array)
                    return f.Value.ValueType == AssetValueType.String ? "\"" + f.AsString + "\"" : Convert.ToString(f.Value.AsObject, System.Globalization.CultureInfo.InvariantCulture) ?? "";
                if (!f["ownerOption"].IsDummy)
                    return f["ownerOption"].AsInt == 0 ? "Owner" : Compact(inst, f["gameObject"]);
                if (!f["useVariable"].IsDummy && f["useVariable"].AsBool && !f["name"].IsDummy && f["name"].AsString != "")
                    return "$" + f["name"].AsString;
                foreach (var key in new[] { "value", "objectReference", "boolValue", "intValue", "floatValue", "stringValue", "vector3Value", "colorValue" })
                    if (!f[key].IsDummy) return Compact(inst, f[key]);
                if (!f["m_Curve"].IsDummy)
                    return "curve[" + string.Join(" ", f["m_Curve.Array"].Children.Select(k => $"{k["time"].AsFloat:0.##}:{k["value"].AsFloat:0.##}")) + "]";
                if (f.Children.Count is > 0 and <= 4 && f.Children.All(c => c.Value != null && c.Value.ValueType == AssetValueType.Float))
                    return "(" + string.Join(", ", f.Children.Select(c => c.AsFloat.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture))) + ")";
                if (!f["eventTarget"].IsDummy) return "target" + f["target"].AsInt;
                return "{" + string.Join(",", f.Children.Take(4).Select(c => c.FieldName + "=" + Compact(inst, c))) + "}";
            }
            // Unity Timeline (PlayableDirector) -> readable track list: clip times, what each clip drives
            void DecodeTimeline(AssetsFileInstance inst, AssetTypeValueField dir_, string goName)
            {
                var ta = R(inst, dir_["m_PlayableAsset.m_FileID"].AsInt, dir_["m_PlayableAsset.m_PathID"].AsLong);
                if (ta == null) return;
                var (tinst, tinfo) = ta.Value;
                var tl = am.GetBaseField(tinst, tinfo);
                var exposed = new Dictionary<string, string>();
                foreach (var e in dir_["m_ExposedReferences.m_References.Array"].Children)
                    exposed[e["first"].Value?.AsObject?.ToString() ?? e["first"].Children.FirstOrDefault()?.Value?.AsObject?.ToString() ?? "?"] = PName(inst, e["second"]);
                var bindings = new Dictionary<long, string>();
                foreach (var b in dir_["m_SceneBindings.Array"].Children)
                    bindings[b["key.m_PathID"].AsLong] = PName(inst, b["value"]);
                using var w = new StreamWriter(Path.Combine(dir, $"timeline_{Safe(goName)}.txt"));
                w.WriteLine($"Timeline '{tl["m_Name"].AsString}' on GO '{goName}' (director wrap={dir_["m_WrapMode"].AsInt})");
                w.WriteLine("Each clip: [start .. end] seconds. Control = turns a GameObject (its particles) on for that span.");
                void Track(AssetTypeValueField pp, int depth)
                {
                    var tr = R(tinst, pp["m_FileID"].AsInt, pp["m_PathID"].AsLong);
                    if (tr == null) return;
                    var (rinst, rinfo) = tr.Value;
                    var tf = am.GetBaseField(rinst, rinfo);
                    var pad = new string(' ', depth * 2);
                    var bound = bindings.TryGetValue(rinfo.PathId, out var bv) ? $"  bound to {bv}" : "";
                    w.WriteLine($"{pad}TRACK {ScriptName(rinst, tf)} '{tf["m_Name"].AsString}'{(tf["m_Muted"].AsBool ? " (muted)" : "")}{bound}");
                    foreach (var c in tf["m_Clips.Array"].Children)
                    {
                        double s = c["m_Start"].AsDouble, d = c["m_Duration"].AsDouble;
                        var line = $"{pad}  [{s:0.###} .. {s + d:0.###}] '{c["m_DisplayName"].AsString}'";
                        var ar = R(rinst, c["m_Asset.m_FileID"].AsInt, c["m_Asset.m_PathID"].AsLong);
                        if (ar != null)
                        {
                            var af = am.GetBaseField(ar.Value.inst, ar.Value.info);
                            var parts = new List<string> { ScriptName(ar.Value.inst, af) };
                            foreach (var f in af.Children.Skip(4))
                            {
                                if (!f["exposedName"].IsDummy)
                                {
                                    var en = f["exposedName"].Value?.AsObject?.ToString() ?? f["exposedName"].Children.FirstOrDefault()?.Value?.AsObject?.ToString() ?? "?";
                                    parts.Add($"{f.FieldName}={(exposed.TryGetValue(en, out var ev) ? ev : PName(ar.Value.inst, f["defaultValue"]))}");
                                }
                                else parts.Add($"{f.FieldName}={Compact(ar.Value.inst, f)}");
                            }
                            line += "  " + string.Join("  ", parts);
                        }
                        w.WriteLine(line);
                    }
                    foreach (var ch in tf["m_Children.Array"].Children) Track(ch, depth + 1);
                }
                foreach (var pp in tl["m_Tracks.Array"].Children) Track(pp, 0);
            }
            var fsmCount = 0;
            void DecodeFsm(AssetsFileInstance inst, AssetTypeValueField mb, string goName)
            {
                var fsm = mb["fsm"];
                var inv = System.Globalization.CultureInfo.InvariantCulture;
                using var w = new StreamWriter(Path.Combine(dir, $"fsm_{fsmCount++:00}_{Safe(goName)}.txt"));
                w.WriteLine($"FSM '{fsm["name"].AsString}' on GO '{goName}'   start state: '{fsm["startState"].AsString}'");
                w.WriteLine("(Each STATE runs its actions top to bottom at once; 'on EVENT -> X' jumps when the event fires, e.g. FINISHED after a Wait.)");
                var vars = fsm["variables"];
                if (!vars.IsDummy)
                    foreach (var arr in vars.Children)
                        foreach (var v in arr["Array"].IsDummy ? new List<AssetTypeValueField>() : arr["Array"].Children)
                            if (!v["name"].IsDummy) w.WriteLine($"  var {arr.FieldName.Replace("Variables", "")} {v["name"].AsString} = {Compact(inst, v["value"])}");
                foreach (var tr in fsm["globalTransitions.Array"].IsDummy ? new List<AssetTypeValueField>() : fsm["globalTransitions.Array"].Children)
                    w.WriteLine($"  global: on {tr["fsmEvent.name"].AsString} -> '{tr["toState"].AsString}'");
                foreach (var st in fsm["states.Array"].Children)
                {
                    w.WriteLine();
                    w.WriteLine($"STATE '{st["name"].AsString}'");
                    foreach (var tr in st["transitions.Array"].Children)
                        w.WriteLine($"  on {tr["fsmEvent.name"].AsString} -> '{tr["toState"].AsString}'");
                    var ad = st["actionData"];
                    var names = ad["actionNames.Array"].Children;
                    var starts = ad["actionStartIndex.Array"].Children.Select(c => c.AsInt).ToList();
                    var types = ad["paramDataType.Array"].Children.Select(c => c.AsInt).ToList();
                    var pnames = ad["paramName.Array"].Children.Select(c => c.AsString).ToList();
                    var poss = ad["paramDataPos.Array"].Children.Select(c => c.AsInt).ToList();
                    var bytes = ad["byteData.Array"].AsByteArray ?? Array.Empty<byte>();
                    var enabled = ad["actionEnabled.Array"].AsByteArray ?? Array.Empty<byte>();
                    AssetTypeValueField L(string n, int p) { var a = ad[n + ".Array"]; return !a.IsDummy && p < a.Children.Count ? a.Children[p] : a; }
                    for (int i = 0; i < names.Count; i++)
                    {
                        var an = names[i].AsString; an = an[(an.LastIndexOf('.') + 1)..];
                        int s = starts[i], e = i + 1 < starts.Count ? starts[i + 1] : types.Count;
                        var ps = new List<string>();
                        for (int j = s; j < e && j < types.Count; j++)
                        {
                            int p = poss[j];
                            string val = types[j] switch
                            {
                                // PlayMaker ParamDataType
                                0 or 6 or 7 => p + 4 <= bytes.Length ? BitConverter.ToInt32(bytes, p).ToString() : "?",
                                1 => p < bytes.Length ? (bytes[p] != 0).ToString() : "?",
                                2 => p + 4 <= bytes.Length ? BitConverter.ToSingle(bytes, p).ToString("0.###", inv) : "?",
                                3 => Compact(inst, L("stringParams", p)),
                                23 => "event:" + Compact(inst, L("stringParams", p)),
                                4 or 8 or 9 or 10 or 11 or 34 => "(" + string.Join(", ", Enumerable.Range(0, types[j] switch { 8 => 2, 9 => 3, _ => 4 })
                                        .Where(k => p + k * 4 + 4 <= bytes.Length).Select(k => BitConverter.ToSingle(bytes, p + k * 4).ToString("0.###", inv))) + ")",
                                5 or 27 => Compact(inst, L("unityObjectParams", p)),
                                14 or 22 => Compact(inst, L("animationCurveParams", p)),
                                15 => Compact(inst, L("fsmFloatParams", p)),
                                16 => Compact(inst, L("fsmIntParams", p)),
                                17 => Compact(inst, L("fsmBoolParams", p)),
                                18 => Compact(inst, L("fsmStringParams", p)),
                                19 => Compact(inst, L("fsmGameObjectParams", p)),
                                20 => Compact(inst, L("fsmOwnerDefaultParams", p)),
                                21 => Compact(inst, L("functionCallParams", p)),
                                24 or 32 or 33 => Compact(inst, L("fsmObjectParams", p)),
                                25 => Compact(inst, L("fsmColorParams", p)),
                                28 => Compact(inst, L("fsmVector3Params", p)),
                                30 => Compact(inst, L("fsmRectParams", p)),
                                31 => Compact(inst, L("fsmEventTargetParams", p)),
                                35 => Compact(inst, L("fsmQuaternionParams", p)),
                                36 => Compact(inst, L("fsmPropertyParams", p)),
                                37 => Compact(inst, L("fsmVector2Params", p)),
                                38 => Compact(inst, L("fsmTemplateControlParams", p)),
                                39 => Compact(inst, L("fsmVarParams", p)),
                                41 => Compact(inst, L("fsmArrayParams", p)),
                                42 => Compact(inst, L("fsmEnumParams", p)),
                                _ => $"<t{types[j]}@{p}>"
                            };
                            ps.Add(Environment.GetEnvironmentVariable("HSX_RAW") == "1" ? $"{pnames[j]}#{types[j]}@{p}" : $"{pnames[j]}={val}");
                        }
                        var off = i < enabled.Length && enabled[i] == 0 ? " (disabled)" : "";
                        w.WriteLine($"  {i + 1}. {an}{off}  {string.Join("  ", ps)}");
                    }
                }
            }

            // property names of the materials met in this prefab (to resolve animated material curves)
            var matNames = new HashSet<string>();
            var jnodes = new System.Text.Json.Nodes.JsonArray();

            // AnimationClip baked into a MuscleClip (streamed / dense / constant curves, bindings by CRC32 hashes)
            // -> anim/<clip>.json: every curve sampled at 30 fps with its object path and property name
            void DecodeClip(AssetTypeValueField clip, string outPath)
            {
                var mc = clip["m_MuscleClip.m_Clip.data"];
                if (mc.IsDummy) return;
                // hash -> path of every GameObject relative to every ancestor (the animator's object is unknown)
                var paths = new Dictionary<uint, string> { [Crc32("")] = "" };
                var names = jnodes.Select(n => (string)n!["name"]!).ToList();
                var parents = jnodes.Select(n => (int)n!["parent"]!).ToList();
                for (int i = 0; i < names.Count; i++)
                {
                    var rel = names[i];
                    paths[Crc32(rel)] = rel;
                    for (int a = parents[i]; a >= 0; a = parents[a])
                    {
                        if (parents[a] < 0) break;
                        rel = names[a] + "/" + rel;
                        paths[Crc32(rel)] = rel;
                    }
                }
                var attrs = new Dictionary<uint, string>();
                void A(string s) { attrs[Crc32(s)] = s; attrs[Crc32("material." + s)] = "material." + s; }
                foreach (var s in new[] { "m_IsActive", "m_Enabled", "m_LocalPosition", "m_LocalScale", "m_Color", "m_SortingOrder" }) A(s);
                foreach (var m in matNames)
                {
                    A(m);
                    foreach (var sfx in new[] { ".r", ".g", ".b", ".a", ".x", ".y", ".z", ".w" }) A(m + sfx);
                    foreach (var sfx in new[] { ".x", ".y", ".z", ".w" }) A(m + "_ST" + sfx);
                }
                foreach (var c in new[] { "m_Color", "m_LocalPosition", "m_LocalScale", "m_LocalEulerAnglesHint" })
                    foreach (var sfx in new[] { ".r", ".g", ".b", ".a", ".x", ".y", ".z" }) A(c + sfx);

                var streamed = mc["m_StreamedClip.data.Array"].Children.Select(c => c.AsUInt).ToArray();
                int sCount = (int)mc["m_StreamedClip.curveCount"].AsUInt;
                var dense = mc["m_DenseClip"];
                int dCount = dense.IsDummy ? 0 : (int)dense["m_CurveCount"].AsUInt;
                var dSamples = dense.IsDummy ? new float[0] : dense["m_SampleArray.Array"].Children.Select(c => c.AsFloat).ToArray();
                float dRate = dense.IsDummy ? 0 : dense["m_SampleRate"].AsFloat;
                float dBegin = dense.IsDummy ? 0 : dense["m_BeginTime"].AsFloat;
                int dFrames = dense.IsDummy ? 0 : dense["m_FrameCount"].AsInt;
                var consts = mc["m_ConstantClip.data.Array"].Children.Select(c => c.AsFloat).ToArray();

                // streamed keys: per curve a list of (time, c0..c3)
                var keys = new List<(float t, float a, float b, float c, float d)>[sCount];
                for (int i = 0; i < sCount; i++) keys[i] = new();
                int p = 0;
                while (p + 1 < streamed.Length)
                {
                    float time = BitConverter.UInt32BitsToSingle(streamed[p++]);
                    int n = (int)streamed[p++];
                    for (int k = 0; k < n && p + 4 < streamed.Length + 1; k++)
                    {
                        int idx = (int)streamed[p++];
                        float c0 = BitConverter.UInt32BitsToSingle(streamed[p++]), c1 = BitConverter.UInt32BitsToSingle(streamed[p++]);
                        float c2 = BitConverter.UInt32BitsToSingle(streamed[p++]), c3 = BitConverter.UInt32BitsToSingle(streamed[p++]);
                        if (idx >= 0 && idx < sCount) keys[idx].Add((time, c0, c1, c2, c3));
                    }
                }
                float length = clip["m_MuscleClip.m_StopTime"].IsDummy ? 1f : clip["m_MuscleClip.m_StopTime"].AsFloat;
                float Eval(int curve, float t)
                {
                    if (curve < sCount)
                    {
                        var ks = keys[curve];
                        if (ks.Count == 0) return 0;
                        var k = ks[0];
                        foreach (var kk in ks) { if (kk.t <= t) k = kk; else break; }
                        float x = t - Math.Max(k.t, -1e30f) ;
                        if (k.t < -1e30f) x = t;
                        return ((k.a * x + k.b) * x + k.c) * x + k.d;
                    }
                    curve -= sCount;
                    if (curve < dCount)
                    {
                        int f = Math.Clamp((int)MathF.Floor((t - dBegin) * dRate), 0, Math.Max(dFrames - 1, 0));
                        int at = f * dCount + curve;
                        return at < dSamples.Length ? dSamples[at] : 0;
                    }
                    curve -= dCount;
                    return curve < consts.Length ? consts[curve] : 0;
                }
                var outCurves = new System.Text.Json.Nodes.JsonArray();
                int ci = 0;
                foreach (var b in clip["m_ClipBindingConstant.genericBindings.Array"].Children)
                {
                    uint ph = b["path"].AsUInt, at = b["attribute"].AsUInt;
                    int type = b["typeID"].AsInt;
                    int comps = 1;
                    string attr;
                    if (type == 4) { comps = at == 2 ? 4 : 3; attr = at switch { 1 => "position", 2 => "rotation", 3 => "scale", 4 => "euler", _ => $"t{at}" }; }
                    else if (attrs.TryGetValue(at, out var an)) attr = an;
                    else
                    {
                        // material property: low 28 bits = CRC32(name), top 4 bits = component (0-3) or kind (8 = float)
                        var low = at & 0x0FFFFFFF;
                        var hit = matNames.Concat(matNames.Select(m => m + "_ST")).FirstOrDefault(m => (Crc32(m) & 0x0FFFFFFF) == low);
                        uint top = at >> 28;
                        attr = hit == null ? $"#{at}" : top < 4 ? $"{hit}.{"xyzw"[(int)top]}" : top == 8 ? hit : $"{hit}#{top}";
                    }
                    for (int k = 0; k < comps; k++, ci++)
                    {
                        var vals = new System.Text.Json.Nodes.JsonArray();
                        for (float t = 0; t <= length + 1e-4f; t += 1f / 30f) vals.Add(Math.Round(Eval(ci, t), 4));
                        outCurves.Add(new System.Text.Json.Nodes.JsonObject
                        {
                            ["path"] = paths.TryGetValue(ph, out var pn) ? pn : $"#{ph}",
                            ["type"] = type, ["attr"] = comps > 1 ? $"{attr}.{"xyzw"[k]}" : attr,
                            ["values"] = vals,
                        });
                    }
                }
                File.WriteAllText(outPath, new System.Text.Json.Nodes.JsonObject
                {
                    ["length"] = length, ["fps"] = 30, ["curves"] = outCurves,
                }.ToJsonString());
            }

            // Mesh vertex data (uncompressed meshes): positions, uv0, uv1, colors, triangles (small meshes only)
            void MeshGeometry(AssetsFileInstance inst, AssetTypeValueField m, System.Text.Json.Nodes.JsonObject o)
            {
                var vd = m["m_VertexData"];
                int vc = (int)vd["m_VertexCount"].AsUInt;
                if (vc == 0 || vc > 20000) return;
                byte[] data = vd["m_DataSize"].AsByteArray ?? Array.Empty<byte>();
                if (data.Length == 0 && !m["m_StreamData.path"].IsDummy && m["m_StreamData.path"].AsString != "")
                {
                    var src = Path.GetFileName(m["m_StreamData.path"].AsString);
                    var bun = inst.parentBundle;
                    var dirs = bun.file.BlockAndDirInfo.DirectoryInfos;
                    int idx = dirs.FindIndex(d => d.Name == src);
                    if (idx >= 0)
                    {
                        var rdr = bun.file.DataReader;
                        rdr.Position = dirs[idx].Offset + (long)m["m_StreamData.offset"].AsULong;
                        data = rdr.ReadBytes((int)m["m_StreamData.size"].AsUInt);
                    }
                }
                if (data.Length == 0) return;
                var chans = vd["m_Channels.Array"].Children.Select(c => (stream: (int)c["stream"].AsByte, offset: (int)c["offset"].AsByte,
                    format: (int)c["format"].AsByte, dim: c["dimension"].AsByte & 0xF)).ToList();
                int[] fsize = { 4, 2, 1, 1, 2, 2, 1, 1, 2, 2, 4, 4 };
                int streams = chans.Max(c => c.stream) + 1;
                var sOff = new int[streams]; var sStride = new int[streams];
                int off = 0;
                for (int s = 0; s < streams; s++)
                {
                    sStride[s] = chans.Where(c => c.stream == s && c.dim > 0).Sum(c => c.dim * fsize[c.format]);
                    sOff[s] = off;
                    off += vc * sStride[s];
                    off = (off + 15) & ~15;
                }
                float Read(int ch, int v, int k)
                {
                    var c = chans[ch];
                    int at = sOff[c.stream] + v * sStride[c.stream] + c.offset + k * fsize[c.format];
                    return c.format switch
                    {
                        0 => BitConverter.ToSingle(data, at),
                        1 => (float)BitConverter.ToHalf(data, at),
                        2 => data[at] / 255f,
                        3 => Math.Max((sbyte)data[at] / 127f, -1f),
                        4 => BitConverter.ToUInt16(data, at) / 65535f,
                        5 => Math.Max(BitConverter.ToInt16(data, at) / 32767f, -1f),
                        6 => data[at], 7 => (sbyte)data[at], 8 => BitConverter.ToUInt16(data, at), 9 => BitConverter.ToInt16(data, at),
                        10 => BitConverter.ToUInt32(data, at), _ => BitConverter.ToInt32(data, at),
                    };
                }
                System.Text.Json.Nodes.JsonArray Chan(int ch, int dims)
                {
                    var a = new System.Text.Json.Nodes.JsonArray();
                    for (int v = 0; v < vc; v++)
                        for (int k = 0; k < dims; k++) a.Add(Math.Round(Read(ch, v, k), 4));
                    return a;
                }
                // channels: 0 position, 3 color, 4 uv0, 5 uv1
                if (chans.Count > 0 && chans[0].dim >= 3) o["verts"] = Chan(0, 3);
                if (chans.Count > 3 && chans[3].dim >= 4) o["colors"] = Chan(3, 4);
                if (chans.Count > 4 && chans[4].dim >= 2) o["uv"] = Chan(4, 2);
                if (chans.Count > 5 && chans[5].dim >= 2) o["uv1"] = Chan(5, 2);
                var ib = m["m_IndexBuffer.Array"].AsByteArray ?? m["m_IndexBuffer.Array"].Children.Select(c => (byte)c.AsUInt).ToArray();
                bool i32 = m["m_IndexFormat"].AsInt == 1;
                var tris = new System.Text.Json.Nodes.JsonArray();
                foreach (var sm in m["m_SubMeshes.Array"].Children)
                {
                    if (sm["topology"].AsInt != 0) continue;
                    int first = (int)sm["firstByte"].AsUInt, count = (int)sm["indexCount"].AsUInt;
                    int bv = sm["baseVertex"].IsDummy ? 0 : (int)sm["baseVertex"].AsUInt;
                    for (int k = 0; k < count; k++)
                        tris.Add(bv + (i32 ? (int)BitConverter.ToUInt32(ib, first + k * 4) : BitConverter.ToUInt16(ib, first + k * 2)));
                }
                o["tris"] = tris;
            }

            // fx.json: node tree with transforms, particle systems, renderers + materials (for the Godot player)
            var jparents = new List<int>();
            System.Text.Json.Nodes.JsonNode? J(AssetsFileInstance inst, AssetTypeValueField f)
            {
                if (f.Children.Count == 2 && f.Children[0].FieldName == "m_FileID") return PName(inst, f);
                var v = f.Value;
                if (v != null)
                {
                    switch (v.ValueType)
                    {
                        case AssetValueType.String: return f.AsString;
                        case AssetValueType.Bool: return f.AsBool;
                        case AssetValueType.Float or AssetValueType.Double:
                        {
                            double d = f.AsDouble;
                            return double.IsFinite(d) ? Math.Round(d, 5) : 0.0;
                        }
                        case AssetValueType.ByteArray: return $"<bytes {f.AsByteArray.Length}>";
                        case AssetValueType.Array:
                        {
                            var a = new System.Text.Json.Nodes.JsonArray();
                            foreach (var c in f.Children.Take(1024)) a.Add(J(inst, c));
                            return a;
                        }
                        case AssetValueType.UInt64: return (double)f.AsULong;
                        default: return f.AsLong;
                    }
                }
                if (f.Children.Count == 1 && f.Children[0].FieldName == "Array") return J(inst, f.Children[0]);
                var o = new System.Text.Json.Nodes.JsonObject();
                foreach (var c in f.Children) o[c.FieldName] = J(inst, c);
                return o;
            }
            string TexName(AssetsFileInstance inst, AssetTypeValueField pp)
            {
                if (pp.IsDummy || pp["m_PathID"].AsLong == 0) return "";
                var r = R(inst, pp["m_FileID"].AsInt, pp["m_PathID"].AsLong);
                return r == null ? "?" : AssetName(r.Value.inst, r.Value.info);
            }
            System.Text.Json.Nodes.JsonNode? MatJson(AssetsFileInstance inst, AssetTypeValueField pp)
            {
                if (pp["m_PathID"].AsLong == 0) return null;
                var r = R(inst, pp["m_FileID"].AsInt, pp["m_PathID"].AsLong);
                if (r == null) return "?";
                var (mi, minfo) = r.Value;
                var bf = am.GetBaseField(mi, minfo);
                var o = new System.Text.Json.Nodes.JsonObject { ["name"] = bf["m_Name"].AsString, ["shader"] = TexName(mi, bf["m_Shader"]) };
                foreach (var arr in new[] { "m_TexEnvs", "m_Floats", "m_Colors", "m_Ints" })
                    if (!bf["m_SavedProperties." + arr].IsDummy)
                        foreach (var e in bf["m_SavedProperties." + arr + ".Array"].Children) matNames.Add(e["first"].AsString);
                var tex = new System.Text.Json.Nodes.JsonObject();
                foreach (var e in bf["m_SavedProperties.m_TexEnvs.Array"].Children)
                {
                    var tn = TexName(mi, e["second.m_Texture"]);
                    if (tn == "") continue;
                    tex[e["first"].AsString] = new System.Text.Json.Nodes.JsonObject
                    {
                        ["tex"] = tn, ["scale"] = J(mi, e["second.m_Scale"]), ["offset"] = J(mi, e["second.m_Offset"]),
                    };
                }
                o["tex"] = tex;
                var fl = new System.Text.Json.Nodes.JsonObject();
                foreach (var e in bf["m_SavedProperties.m_Floats.Array"].Children) fl[e["first"].AsString] = Math.Round(e["second"].AsDouble, 5);
                o["floats"] = fl;
                var co = new System.Text.Json.Nodes.JsonObject();
                foreach (var e in bf["m_SavedProperties.m_Colors.Array"].Children) co[e["first"].AsString] = J(mi, e["second"]);
                o["colors"] = co;
                if (!bf["m_CustomRenderQueue"].IsDummy) o["queue"] = bf["m_CustomRenderQueue"].AsInt;
                var kw = new System.Text.Json.Nodes.JsonArray();
                if (!bf["m_ValidKeywords"].IsDummy)
                    foreach (var k in bf["m_ValidKeywords.Array"].Children) kw.Add(k.AsString);
                else if (!bf["m_ShaderKeywords"].IsDummy)
                    foreach (var k in bf["m_ShaderKeywords"].AsString.Split(' ', StringSplitOptions.RemoveEmptyEntries)) kw.Add(k);
                o["keywords"] = kw;
                return o;
            }
            System.Text.Json.Nodes.JsonNode? MeshJson(AssetsFileInstance inst, AssetTypeValueField pp)
            {
                if (pp["m_PathID"].AsLong == 0) return null;
                var r = R(inst, pp["m_FileID"].AsInt, pp["m_PathID"].AsLong);
                if (r == null) return "?";
                var bf = am.GetBaseField(r.Value.inst, r.Value.info);
                var o = new System.Text.Json.Nodes.JsonObject
                {
                    ["name"] = bf["m_Name"].AsString, ["center"] = J(r.Value.inst, bf["m_LocalAABB.m_Center"]), ["extent"] = J(r.Value.inst, bf["m_LocalAABB.m_Extent"]),
                };
                try { MeshGeometry(r.Value.inst, bf, o); } catch (Exception e) { o["geomError"] = e.Message; }
                return o;
            }

            using (var w = new StreamWriter(Path.Combine(dir, "hierarchy.txt")))
            {
                w.WriteLine($"# {name}  guid={guid}  file={pinst.name}");
                void Go(AssetsFileInstance inst, long goId, int depth)
                {
                    var goInfo = inst.file.GetAssetInfo(goId);
                    if (goInfo == null) return;
                    visited.Add(inst.name + ":" + goId);
                    var go = am.GetBaseField(inst, goInfo);
                    var pad = new string(' ', depth * 2);
                    w.WriteLine($"{pad}GO '{go["m_Name"].AsString}' active={go["m_IsActive"].AsBool} layer={go["m_Layer"].AsInt}");
                    var kids = new List<long>();
                    var jn = new System.Text.Json.Nodes.JsonObject
                    {
                        ["name"] = go["m_Name"].AsString, ["depth"] = depth, ["active"] = go["m_IsActive"].AsBool,
                        ["parent"] = jparents.Count > depth - 1 && depth > 0 ? jparents[depth - 1] : -1,
                    };
                    int myIndex = jnodes.Count;
                    jnodes.Add(jn);
                    while (jparents.Count <= depth) jparents.Add(-1);
                    jparents[depth] = myIndex;
                    foreach (var comp in go["m_Component.Array"].Children)
                    {
                        long cid = comp["component.m_PathID"].AsLong;
                        var ci = inst.file.GetAssetInfo(cid);
                        if (ci == null) continue;
                        visited.Add(inst.name + ":" + cid);
                        var t = (AssetClassID)ci.TypeId;
                        var cf = am.GetBaseField(inst, ci);
                        var label = t == AssetClassID.MonoBehaviour ? "MB " + ScriptName(inst, cf) : t.ToString();
                        if (t == AssetClassID.ParticleSystem) nPs++;
                        w.WriteLine($"{pad}  [{label}]");
                        if (t == AssetClassID.PlayableDirector)
                        {
                            try { DecodeTimeline(inst, cf, go["m_Name"].AsString); }
                            catch (Exception e) { index.WriteLine($"{folder}: timeline decode ERR {e.Message}"); }
                        }
                        if (label == "MB PlayMakerFSM")
                        {
                            try { DecodeFsm(inst, cf, go["m_Name"].AsString); }
                            catch (Exception e) { index.WriteLine($"{folder}: FSM decode ERR {e.Message}"); }
                        }
                        try
                        {
                            switch (t)
                            {
                                case AssetClassID.Transform or AssetClassID.RectTransform:
                                    jn["pos"] = J(inst, cf["m_LocalPosition"]); jn["rot"] = J(inst, cf["m_LocalRotation"]); jn["scale"] = J(inst, cf["m_LocalScale"]);
                                    break;
                                case AssetClassID.ParticleSystem:
                                {
                                    var ps = new System.Text.Json.Nodes.JsonObject();
                                    foreach (var f in cf.Children)
                                    {
                                        if (f.FieldName is "m_GameObject") continue;
                                        if (!f["enabled"].IsDummy && !f["enabled"].AsBool && f.FieldName != "InitialModule") continue;
                                        ps[f.FieldName] = J(inst, f);
                                    }
                                    if (!cf["ShapeModule.m_Mesh"].IsDummy && cf["ShapeModule.m_Mesh.m_PathID"].AsLong != 0)
                                        ps["shapeMesh"] = MeshJson(inst, cf["ShapeModule.m_Mesh"]);
                                    jn["ps"] = ps;
                                    break;
                                }
                                case AssetClassID.ParticleSystemRenderer or AssetClassID.MeshRenderer or AssetClassID.SkinnedMeshRenderer or AssetClassID.TrailRenderer or AssetClassID.LineRenderer or AssetClassID.SpriteRenderer:
                                {
                                    var r = new System.Text.Json.Nodes.JsonObject { ["type"] = t.ToString() };
                                    foreach (var fn in new[] { "m_Enabled", "m_RenderMode", "m_SortingFudge", "m_SortingOrder", "m_LengthScale", "m_VelocityScale",
                                                              "m_CameraVelocityScale", "m_MinParticleSize", "m_MaxParticleSize", "m_RenderAlignment", "m_Pivot", "m_Flip",
                                                              "m_Mesh", "m_Sprite", "m_Color", "m_Size" })
                                        if (!cf[fn].IsDummy) r[fn] = J(inst, cf[fn]);
                                    var mats = new System.Text.Json.Nodes.JsonArray();
                                    foreach (var m in cf["m_Materials.Array"].Children) mats.Add(MatJson(inst, m));
                                    r["materials"] = mats;
                                    jn["renderer"] = r;
                                    break;
                                }
                                case AssetClassID.MeshFilter:
                                    jn["mesh"] = MeshJson(inst, cf["m_Mesh"]);
                                    break;
                                case AssetClassID.Animation:
                                {
                                    var clips = new System.Text.Json.Nodes.JsonArray();
                                    foreach (var c in cf["m_Animations.Array"].Children) clips.Add(PName(inst, c));
                                    jn["animation"] = new System.Text.Json.Nodes.JsonObject { ["clip"] = PName(inst, cf["m_Animation"]), ["clips"] = clips, ["playAutomatically"] = cf["m_PlayAutomatically"].AsBool };
                                    break;
                                }
                                case AssetClassID.MonoBehaviour:
                                {
                                    var sn = ScriptName(inst, cf);
                                    if (sn is "PlayMakerFSM" or "Spell" or "SoundDef") break;
                                    var mbs = jn["scripts"] as System.Text.Json.Nodes.JsonObject ?? new System.Text.Json.Nodes.JsonObject();
                                    var o = new System.Text.Json.Nodes.JsonObject();
                                    foreach (var f in cf.Children.Skip(4)) o[f.FieldName] = J(inst, f);
                                    mbs[sn] = o;
                                    jn["scripts"] = mbs;
                                    break;
                                }
                            }
                        }
                        catch (Exception e) { index.WriteLine($"{folder}: json ERR {t}: {e.Message}"); }
                        if (t is AssetClassID.Transform or AssetClassID.RectTransform)
                        {
                            foreach (var fn in new[] { "m_LocalPosition", "m_LocalRotation", "m_LocalScale" })
                                w.WriteLine($"{pad}    {fn} = {string.Join(", ", cf[fn].Children.Select(c => c.AsFloat.ToString("0.###")))}");
                            foreach (var ch in cf["m_Children.Array"].Children)
                            {
                                var tr = inst.file.GetAssetInfo(ch["m_PathID"].AsLong);
                                if (tr != null) kids.Add(am.GetBaseField(inst, tr)["m_GameObject.m_PathID"].AsLong);
                            }
                        }
                        else
                        {
                            foreach (var f in cf.Children)
                            {
                                if (f.FieldName is "m_GameObject" or "m_Script" or "m_ObjectHideFlags" or "m_CorrespondingSourceObject" or "m_PrefabInstance" or "m_PrefabAsset") continue;
                                Walk(w, inst, f, depth + 2, 64, f.FieldName);
                            }
                        }
                    }
                    foreach (var k in kids) Go(inst, k, depth + 1);
                }
                var rootInfo = pinst.file.GetAssetInfo(rootId);
                if (rootInfo != null && (AssetClassID)rootInfo.TypeId == AssetClassID.GameObject) Go(pinst, rootId, 0);
                else if (rootInfo != null) queue.Enqueue((pinst, rootInfo));
            }
            if (jnodes.Count > 0)
                File.WriteAllText(Path.Combine(dir, "fx.json"), new System.Text.Json.Nodes.JsonObject { ["name"] = name, ["nodes"] = jnodes }
                    .ToJsonString());

            // referenced assets
            while (queue.Count > 0)
            {
                var (inst, info) = queue.Dequeue();
                var key = inst.name + ":" + info.PathId;
                if (!visited.Add(key)) continue;
                var t = (AssetClassID)info.TypeId;
                try
                {
                    var bf = am.GetBaseField(inst, info);
                    string nm = bf["m_Name"].IsDummy ? "" : bf["m_Name"].AsString;
                    switch (t)
                    {
                        case AssetClassID.Texture2D:
                        {
                            var td = Path.Combine(dir, "textures"); Directory.CreateDirectory(td);
                            var tf = TextureFile.ReadTextureFile(bf);
                            var data = tf.FillPictureData(inst);
                            var png = Path.Combine(td, Safe(nm) + ".png");
                            File.AppendAllText(Path.Combine(td, "colorspace.tsv"),
                                Safe(nm) + "\t" + (bf["m_ColorSpace"].IsDummy ? -1 : bf["m_ColorSpace"].AsInt) + "\t" + (TextureFormat)tf.m_TextureFormat + "\n");
                            if (data != null && data.Length > 0 && tf.DecodeTextureImage(data, png, ImageExportType.Png, 100)) nTex++;
                            else File.WriteAllText(png + ".txt", $"format {(TextureFormat)tf.m_TextureFormat} {tf.m_Width}x{tf.m_Height} not decoded");
                            break;
                        }
                        case AssetClassID.AudioClip:
                        {
                            var ad = Path.Combine(dir, "audio"); Directory.CreateDirectory(ad);
                            var src = bf["m_Resource.m_Source"].AsString;
                            long off = bf["m_Resource.m_Offset"].AsLong, size = bf["m_Resource.m_Size"].AsLong;
                            var bun = inst.parentBundle;
                            var dirs = bun.file.BlockAndDirInfo.DirectoryInfos;
                            int idx = dirs.FindIndex(d => d.Name == Path.GetFileName(src));
                            if (idx < 0 && cabMap.TryGetValue(Path.GetFileName(src), out var rb))
                            {
                                bun = B(rb)!; dirs = bun.file.BlockAndDirInfo.DirectoryInfos;
                                idx = dirs.FindIndex(d => d.Name == Path.GetFileName(src));
                            }
                            if (idx >= 0)
                            {
                                var rdr = bun.file.DataReader;
                                rdr.Position = dirs[idx].Offset + off;
                                File.WriteAllBytes(Path.Combine(ad, Safe(nm) + ".fsb"), rdr.ReadBytes((int)size));
                                nAudio++;
                            }
                            break;
                        }
                        case AssetClassID.AnimationClip:
                        {
                            var cd = Path.Combine(dir, "anim"); Directory.CreateDirectory(cd);
                            using var w = new StreamWriter(Path.Combine(cd, Safe(nm) + ".txt"));
                            Walk(w, inst, bf, 0, 4000, "clip");
                            nClip++;
                            try { DecodeClip(bf, Path.Combine(cd, Safe(nm) + ".json")); }
                            catch (Exception e) { index.WriteLine($"{folder}: clip decode ERR {nm}: {e.Message}"); }
                            break;
                        }
                        case AssetClassID.Material:
                        {
                            mats ??= new StreamWriter(Path.Combine(dir, "materials.txt"));
                            mats.WriteLine($"=== Material '{nm}'");
                            Walk(mats, inst, bf, 0, 128, "mat");
                            break;
                        }
                        case AssetClassID.MonoScript or AssetClassID.Shader or AssetClassID.Mesh or AssetClassID.Font:
                            break;
                        default:
                        {
                            // a GameObject / component of another prefab: extract that prefab (from its root)
                            long goId = t == AssetClassID.GameObject ? info.PathId
                                : (!bf["m_GameObject"].IsDummy ? bf["m_GameObject.m_PathID"].AsLong : 0);
                            if (goId != 0)
                            {
                                long root = goId;
                                for (int guard = 0; guard < 64; guard++)
                                {
                                    var gf = am.GetBaseField(inst, inst.file.GetAssetInfo(root));
                                    var trInfo = inst.file.GetAssetInfo(gf["m_Component.Array"].Children[0]["component.m_PathID"].AsLong);
                                    var father = trInfo == null ? 0 : am.GetBaseField(inst, trInfo)["m_Father.m_PathID"].AsLong;
                                    if (father == 0) break;
                                    root = am.GetBaseField(inst, inst.file.GetAssetInfo(father))["m_GameObject.m_PathID"].AsLong;
                                }
                                if (!(inst == pinst && root == rootId))
                                {
                                    var refKey = $"ref:{inst.name}:{root}";
                                    directRefs[refKey] = (inst, root);
                                    var rn = am.GetBaseField(inst, inst.file.GetAssetInfo(root))["m_Name"].AsString;
                                    children.Add($"(object ref) -> {FolderFor(refKey, rn)}");
                                }
                                break;
                            }
                            if (t is AssetClassID.Transform) break;
                            refs ??= new StreamWriter(Path.Combine(dir, "refs.txt"));
                            refs.WriteLine($"=== {t} '{(t == AssetClassID.MonoBehaviour ? ScriptName(inst, bf) + " " : "")}{nm}'");
                            Walk(refs, inst, bf, 0, 256, "ref");
                            break;
                        }
                    }
                }
                catch (Exception e) { index.WriteLine($"{folder}: ERR {t} #{info.PathId}: {e.Message}"); }
            }
            refs?.Dispose(); mats?.Dispose();
            index.WriteLine($"{folder}  ({name})");
            foreach (var c in children) index.WriteLine($"    {c}");
        }

        var parts = cdef.Split(':');
        FolderFor(parts[1], "CardDef_" + parts[0].Replace(".prefab", ""));
        while (pending.Count > 0 && counter < 400)
        {
            var (g, n, _) = pending.Dequeue();
            ExtractPrefab(g, n, prefabFolders[g]);
        }
        Console.WriteLine($"{cardId}: prefabs {prefabFolders.Count}, particle systems {nPs}, textures {nTex}, clips {nClip}, audio {nAudio}");
        am.UnloadAll(true);
        bundles.Clear(); files.Clear(); guidMap.Clear(); indexed.Clear(); scriptNames.Clear();
    }
}

static class Dx
{
    [System.Runtime.InteropServices.ComImport, System.Runtime.InteropServices.Guid("8BA5FB08-5195-40e2-AC58-0D989C3A0102"),
     System.Runtime.InteropServices.InterfaceType(System.Runtime.InteropServices.ComInterfaceType.InterfaceIsIUnknown)]
    interface ID3DBlob
    {
        [System.Runtime.InteropServices.PreserveSig] IntPtr GetBufferPointer();
        [System.Runtime.InteropServices.PreserveSig] UIntPtr GetBufferSize();
    }

    [System.Runtime.InteropServices.DllImport("d3dcompiler_47.dll")]
    static extern int D3DDisassemble(byte[] src, UIntPtr size, uint flags, string? comments, out ID3DBlob blob);

    public static string Disassemble(byte[] dxbc)
    {
        int hr = D3DDisassemble(dxbc, (UIntPtr)dxbc.Length, 0, null, out var blob);
        if (hr != 0 || blob == null) return $"// D3DDisassemble failed 0x{hr:X}";
        return System.Runtime.InteropServices.Marshal.PtrToStringAnsi(blob.GetBufferPointer(), (int)blob.GetBufferSize()) ?? "";
    }
}
