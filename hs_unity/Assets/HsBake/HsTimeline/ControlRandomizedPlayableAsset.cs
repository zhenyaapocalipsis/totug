// Клип дорожки ControlRandomizedTrack (Hearthstone): поля те же, что у ControlPlayableAsset
// (sourceGameObject, updateParticle, active, postPlayback…), у HS ещё случайное зерно частиц.
using UnityEngine.Timeline;

namespace Hearthstone.Timeline
{
    public class ControlRandomizedPlayableAsset : ControlPlayableAsset { }
}
