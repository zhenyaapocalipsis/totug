// Дорожка Timeline из кода Hearthstone: в игре — пустой наследник TrackAsset, клипы —
// ControlRandomizedPlayableAsset. Класс с тем же именем и пространством имён Unity связывает
// с префабами HS из бандлов, и дорожка играет как стандартная Control (частицы и включение
// узлов) — без неё эффекты новых наборов пустые (HsBrowser) и нужны `controls` в рецептах.
using UnityEngine.Timeline;

namespace Hearthstone.Timeline
{
    [TrackClipType(typeof(ControlRandomizedPlayableAsset), false)]
    public class ControlRandomizedTrack : ControlTrack { }
}
