// Время шейдеров (_Time и родственные) для запекания: URP в редакторе берёт реальное
// время, и между кадрами запекания оно прыгает на доли секунды — текстуры с прокруткой
// по _Time (огонь FX/CommonFX _SCROLLING_ON) рябят. Эта функция рендера перед
// отрисовкой ставит время кадра (HsTimeFeature.time) — как в игре на 60 к/с.
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class HsTimeFeature : ScriptableRendererFeature
{
    // время кадра, с; < 0 — не трогать (обычная работа редактора)
    public static float time = -1f;
    public static float delta = 1f / 60f;

    class Pass : ScriptableRenderPass
    {
        class Data { public float t, dt; }

        static void Apply(CommandBuffer cmd, float t, float dt)
        {
            cmd.SetGlobalVector("_Time", new Vector4(t / 20f, t, t * 2f, t * 3f));
            cmd.SetGlobalVector("_SinTime", new Vector4(Mathf.Sin(t / 8f), Mathf.Sin(t / 4f), Mathf.Sin(t / 2f), Mathf.Sin(t)));
            cmd.SetGlobalVector("_CosTime", new Vector4(Mathf.Cos(t / 8f), Mathf.Cos(t / 4f), Mathf.Cos(t / 2f), Mathf.Cos(t)));
            cmd.SetGlobalVector("unity_DeltaTime", new Vector4(dt, 1f / dt, dt, 1f / dt));
            cmd.SetGlobalVector("_TimeParameters", new Vector4(t, Mathf.Sin(t), Mathf.Cos(t), 0f));
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            if (time < 0f) return;
            using var builder = renderGraph.AddUnsafePass<Data>("HsTime", out var data);
            data.t = time;
            data.dt = delta;
            builder.AllowGlobalStateModification(true);
            builder.AllowPassCulling(false);
            builder.SetRenderFunc((Data d, UnsafeGraphContext ctx) => Apply(CommandBufferHelpers.GetNativeCommandBuffer(ctx.cmd), d.t, d.dt));
        }
    }

    Pass pass;

    public override void Create()
    {
        pass = new Pass { renderPassEvent = RenderPassEvent.BeforeRenderingOpaques };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (time >= 0f) renderer.EnqueuePass(pass);
    }
}
